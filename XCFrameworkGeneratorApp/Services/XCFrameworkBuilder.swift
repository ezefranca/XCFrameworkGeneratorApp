import Foundation
import XcodeProj

final class XCFrameworkBuilder {
    private enum LogLevel: String {
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
        case debug = "DEBUG"
    }

    private static let logDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let xcodeProjService: XcodeProjServicing
    private let logHandler: ((String) -> Void)
    private let progressHandler: ((Int, Int, String) -> Void)?

    init(xcodeProjService: XcodeProjServicing,
         logHandler: @escaping ((String) -> Void),
         progressHandler: ((Int, Int, String) -> Void)? = nil) {
        self.xcodeProjService = xcodeProjService
        self.logHandler = logHandler
        self.progressHandler = progressHandler
    }

    func buildXCFramework(scheme: String,
                          completion: @escaping (Result<URL, Error>) -> Void) {
        guard xcodeProjService.project != nil,
              let projectPath = xcodeProjService.projectPath else {
            let error = NSError(domain: "XCFrameworkBuilder", code: 1, userInfo: [NSLocalizedDescriptionKey: "No project loaded. Please open an .xcodeproj first."])
            completion(.failure(error))
            return
        }

        let available = Set(xcodeProjService.fetchSchemes())
        guard available.contains(scheme) else {
            let error = NSError(domain: "XCFrameworkBuilder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Scheme \(scheme) not found in project."])
            completion(.failure(error))
            return
        }

        let projectDirURL = URL(fileURLWithPath: projectPath).deletingLastPathComponent()

        // Timestamped build root per run: build/runs/<scheme>-<yyyyMMdd-HHmmss>
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = df.string(from: Date())
        let buildRoot = "build/runs/\(scheme)-\(stamp)"

        do {
            try FileManager.default.createDirectory(at: projectDirURL.appendingPathComponent(buildRoot, isDirectory: true), withIntermediateDirectories: true)
        } catch {
            completion(.failure(error))
            return
        }

        let archivesDir = "\(buildRoot)/archives"
        let archiveBase = "\(archivesDir)/\(scheme)"
        let archiveIOS = "\(archiveBase)-iOS"
        let archiveSim = "\(archiveBase)-iOS-Simulator"

        // Total steps: 3 (Archive iOS, Archive iOS Simulator, Create XCFramework)
        let totalSteps = 3

        DispatchQueue.global(qos: .userInitiated).async {
            // STEP 1: Archive iOS
            self.progressHandler?(0, totalSteps, "Archive iOS")
            let iosArchiveArgs = ["archive", "-project", projectPath, "-scheme", scheme, "-destination", "generic/platform=iOS", "-archivePath", archiveIOS, "SKIP_INSTALL=NO", "BUILD_LIBRARY_FOR_DISTRIBUTION=YES"]
            self.log("Archive iOS command: xcodebuild \(iosArchiveArgs.joined(separator: " "))")
            let iosStarted = Date()
            switch Self.runXcodebuild(arguments: iosArchiveArgs, in: projectDirURL, output: { [weak self] chunk in
                self?.logCommandOutput(chunk, subsystem: "xcodebuild")
            }) {
            case .success:
                self.log("Archive iOS completed in \(String(format: "%.1f", Date().timeIntervalSince(iosStarted))) seconds")
            case .failure(let error):
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            // STEP 2: Archive iOS Simulator
            self.progressHandler?(1, totalSteps, "Archive iOS Simulator")
            let simArchiveArgs = ["archive", "-project", projectPath, "-scheme", scheme, "-destination", "generic/platform=iOS Simulator", "-archivePath", archiveSim, "SKIP_INSTALL=NO", "BUILD_LIBRARY_FOR_DISTRIBUTION=YES"]
            self.log("Archive iOS Simulator command: xcodebuild \(simArchiveArgs.joined(separator: " "))")
            let simStarted = Date()
            switch Self.runXcodebuild(arguments: simArchiveArgs, in: projectDirURL, output: { [weak self] chunk in
                self?.logCommandOutput(chunk, subsystem: "xcodebuild")
            }) {
            case .success:
                self.log("Archive iOS Simulator completed in \(String(format: "%.1f", Date().timeIntervalSince(simStarted))) seconds")
            case .failure(let error):
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            // Discover framework names inside each archive (product name may differ from scheme)
            let frameworkIOSPath = self.discoverFrameworkPath(archiveRoot: archiveIOS, scheme: scheme, baseURL: projectDirURL)
            let frameworkSimPath = self.discoverFrameworkPath(archiveRoot: archiveSim, scheme: scheme, baseURL: projectDirURL)

            guard FileManager.default.fileExists(atPath: projectDirURL.appendingPathComponent(frameworkIOSPath).path) else {
                let error = NSError(domain: "XCFrameworkBuilder", code: 3, userInfo: [NSLocalizedDescriptionKey: "iOS framework not found at \(frameworkIOSPath)"])
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard FileManager.default.fileExists(atPath: projectDirURL.appendingPathComponent(frameworkSimPath).path) else {
                let error = NSError(domain: "XCFrameworkBuilder", code: 4, userInfo: [NSLocalizedDescriptionKey: "Simulator framework not found at \(frameworkSimPath)"])
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            self.log("Resolved framework path for iOS: \(frameworkIOSPath)")
            self.log("Resolved framework path for Simulator: \(frameworkSimPath)")

            // STEP 3: Create XCFramework
            self.progressHandler?(2, totalSteps, "Create XCFramework")
            let xcframeworkRelativePath = "\(buildRoot)/\(scheme).xcframework"
            let xcframeworkArgs = ["-create-xcframework", "-framework", frameworkIOSPath, "-framework", frameworkSimPath, "-output", xcframeworkRelativePath]
            self.log("Create XCFramework command: xcodebuild \(xcframeworkArgs.joined(separator: " "))")
            let createStarted = Date()
            switch Self.runXcodebuild(arguments: xcframeworkArgs, in: projectDirURL, output: { [weak self] chunk in
                self?.logCommandOutput(chunk, subsystem: "xcodebuild")
            }) {
            case .success:
                self.log("XCFramework creation completed in \(String(format: "%.1f", Date().timeIntervalSince(createStarted))) seconds")
                self.progressHandler?(totalSteps, totalSteps, "Complete")
                let xcframeworkURL = projectDirURL.appendingPathComponent(xcframeworkRelativePath, isDirectory: true)
                DispatchQueue.main.async { completion(.success(xcframeworkURL)) }
            case .failure(let error):
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    private func discoverFrameworkPath(archiveRoot: String, scheme: String, baseURL: URL) -> String {
        let frameworksDirRelative = "\(archiveRoot).xcarchive/Products/Library/Frameworks"
        let frameworksDirURL = baseURL.appendingPathComponent(frameworksDirRelative, isDirectory: true)
        let fm = FileManager.default

        guard let items = try? fm.contentsOfDirectory(atPath: frameworksDirURL.path) else {
            log("Could not list frameworks directory (\(frameworksDirRelative)); defaulting to scheme name", level: .warning)
            return "\(frameworksDirRelative)/\(scheme).framework"
        }

        let frameworkItems = items.filter { $0.hasSuffix(".framework") }
        if frameworkItems.isEmpty {
            log("No .framework entries found in \(frameworksDirRelative); defaulting to scheme name", level: .warning)
            return "\(frameworksDirRelative)/\(scheme).framework"
        }

        // If there is exactly one framework, use it.
        if frameworkItems.count == 1, let only = frameworkItems.first {
            log("Found single framework '\(only)' in archive for scheme '\(scheme)'")
            return "\(frameworksDirRelative)/\(only)"
        }

        // Try exact match on scheme.framework
        let exactName = "\(scheme).framework"
        if frameworkItems.contains(exactName) {
            log("Using exact match framework '\(exactName)' for scheme '\(scheme)'")
            return "\(frameworksDirRelative)/\(exactName)"
        }

        // Attempt a sanitized match (remove trailing digits / spaces)
        let sanitized = sanitizeSchemeNameForProduct(scheme: scheme)
        let sanitizedCandidate = "\(sanitized).framework"
        if frameworkItems.contains(sanitizedCandidate) {
            log("Using sanitized match framework '\(sanitizedCandidate)' for scheme '\(scheme)' (sanitized value: '\(sanitized)')")
            return "\(frameworksDirRelative)/\(sanitizedCandidate)"
        }

        // Fallback: pick first alphabetically for determinism.
        let chosen = frameworkItems.sorted().first!
        log("Multiple frameworks found (\(frameworkItems.joined(separator: ", "))); none matched scheme '\(scheme)'. Using '\(chosen)'.", level: .warning)
        return "\(frameworksDirRelative)/\(chosen)"
    }

    private func sanitizeSchemeNameForProduct(scheme: String) -> String {
        // Common pattern: scheme ends with space + number (e.g., "MySDK 1") while product is "MySDK".
        // Remove any trailing space + digits sequence.
        let pattern = try? NSRegularExpression(pattern: "\\s+[0-9]+$", options: [])
        let range = NSRange(location: 0, length: scheme.utf16.count)
        if let pattern, pattern.firstMatch(in: scheme, options: [], range: range) != nil {
            return pattern.stringByReplacingMatches(in: scheme, options: [], range: range, withTemplate: "")
        }
        return scheme
    }

    private func log(_ message: String, level: LogLevel = .info, subsystem: String = "XCFrameworkBuilder") {
        let lines = message.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let timestamp = Self.logDateFormatter.string(from: Date())
            let formatted = "\(timestamp) [\(level.rawValue)] [\(subsystem)] \(trimmed)"
            logHandler(formatted)
        }
    }

    private func logCommandOutput(_ chunk: String, subsystem: String) {
        chunk.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).forEach { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            log(trimmed, level: .debug, subsystem: subsystem)
        }
    }

    private static func runXcodebuild(arguments: [String], in directory: URL, output: @escaping (String) -> Void) -> Result<Void, Error> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = arguments
        process.currentDirectoryURL = directory

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { fh in
            let data = fh.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return }
            output(chunk)
        }
        do { try process.run() } catch { handle.readabilityHandler = nil; return .failure(error) }
        process.waitUntilExit()
        handle.readabilityHandler = nil
        let status = process.terminationStatus
        if status == 0 { return .success(()) }
        let data = handle.readDataToEndOfFile()
        let tail = String(data: data, encoding: .utf8) ?? ""
        let error = NSError(domain: "XCFrameworkBuilder", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "xcodebuild failed with status \(status).\nLast output:\n\(tail)"])
        return .failure(error)
    }
}
