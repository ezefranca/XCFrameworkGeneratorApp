import Foundation
import XcodeProj

final class XCFrameworkBuilder {
    private let xcodeProjService: XcodeProjService
    private let logHandler: ((String) -> Void)
    private let progressHandler: ((Int, Int, String) -> Void)?

    init(xcodeProjService: XcodeProjService,
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

        let frameworkIOS = "\(archiveIOS).xcarchive/Products/Library/Frameworks/\(scheme).framework"
        let frameworkSim = "\(archiveSim).xcarchive/Products/Library/Frameworks/\(scheme).framework"
        let xcframeworkRelativePath = "\(buildRoot)/\(scheme).xcframework"
        let xcframeworkURL = projectDirURL.appendingPathComponent(xcframeworkRelativePath, isDirectory: true)

        let commands: [(label: String, args: [String])] = [
            ("Archive iOS", ["archive", "-project", projectPath, "-scheme", scheme, "-destination", "generic/platform=iOS", "-archivePath", archiveIOS, "SKIP_INSTALL=NO", "BUILD_LIBRARY_FOR_DISTRIBUTION=YES"]),
            ("Archive iOS Simulator", ["archive", "-project", projectPath, "-scheme", scheme, "-destination", "generic/platform=iOS Simulator", "-archivePath", archiveSim, "SKIP_INSTALL=NO", "BUILD_LIBRARY_FOR_DISTRIBUTION=YES"]),
            ("Create XCFramework", ["-create-xcframework", "-framework", frameworkIOS, "-framework", frameworkSim, "-output", xcframeworkRelativePath])
        ]
        let totalSteps = commands.count

        DispatchQueue.global(qos: .userInitiated).async {
            for (index, step) in commands.enumerated() {
                self.progressHandler?(index, totalSteps, step.label)
                self.log("➡️ \(step.label): xcodebuild \(step.args.joined(separator: " "))")
                let startedAt = Date()
                let result = Self.runXcodebuild(arguments: step.args, in: projectDirURL) { [weak self] line in
                    self?.log(line)
                }
                let elapsed = Date().timeIntervalSince(startedAt)
                self.log("✅ Finished \(step.label) in \(String(format: "%.1f", elapsed))s")
                switch result {
                case .success:
                    continue
                case .failure(let error):
                    DispatchQueue.main.async { completion(.failure(error)) }
                    return
                }
            }
            self.progressHandler?(totalSteps, totalSteps, "Complete")
            DispatchQueue.main.async { completion(.success(xcframeworkURL)) }
        }
    }

    private func log(_ message: String) {
        print("[XCFrameworkBuilder] \(message)")
        logHandler(message)
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
