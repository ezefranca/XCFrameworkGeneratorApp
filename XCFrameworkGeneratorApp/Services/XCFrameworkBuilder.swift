import Foundation
import XcodeProj

final class XCFrameworkBuilder {
    private let xcodeProjService: XcodeProjService
    private let logHandler: ((String) -> Void)

    /// `logHandler` is optional; if provided, every chunk of xcodebuild output is sent there.
    init(xcodeProjService: XcodeProjService,
         logHandler: @escaping ((String) -> Void)) {
        self.xcodeProjService = xcodeProjService
        self.logHandler = logHandler
    }

    func buildXCFramework(scheme: String,
                          completion: @escaping (Result<URL, Error>) -> Void) {
        guard xcodeProjService.project != nil,
              let projectPath = xcodeProjService.projectPath else {
            let error = NSError(
                domain: "XCFrameworkBuilder",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey:
                            "No project loaded. Please open an .xcodeproj first."]
            )
            completion(.failure(error))
            return
        }

        let available = Set(xcodeProjService.fetchSchemes())
        guard available.contains(scheme) else {
            let error = NSError(
                domain: "XCFrameworkBuilder",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey:
                            "Scheme \(scheme) not found in project."]
            )
            completion(.failure(error))
            return
        }

        let projectDirURL = URL(fileURLWithPath: projectPath).deletingLastPathComponent()
        let buildDir = "build"
        let archivesDir = "\(buildDir)/archives"
        let archiveBase = "\(archivesDir)/\(scheme)"
        let archiveIOS = "\(archiveBase)-iOS"
        let archiveSim = "\(archiveBase)-iOS-Simulator"

        let frameworkIOS = "\(archiveIOS).xcarchive/Products/Library/Frameworks/\(scheme).framework"
        let frameworkSim = "\(archiveSim).xcarchive/Products/Library/Frameworks/\(scheme).framework"
        let xcframeworkRelativePath = "\(buildDir)/\(scheme).xcframework"
        let xcframeworkURL = projectDirURL.appendingPathComponent(
            xcframeworkRelativePath,
            isDirectory: true
        )

        let commands: [[String]] = [
            [
                "archive",
                "-project", projectPath,
                "-scheme", scheme,
                "-destination", "generic/platform=iOS",
                "-archivePath", archiveIOS,
                "SKIP_INSTALL=NO",
                "BUILD_LIBRARY_FOR_DISTRIBUTION=YES"
            ],
            [
                "archive",
                "-project", projectPath,
                "-scheme", scheme,
                "-destination", "generic/platform=iOS Simulator",
                "-archivePath", archiveSim,
                "SKIP_INSTALL=NO",
                "BUILD_LIBRARY_FOR_DISTRIBUTION=YES"
            ],
            [
                "-create-xcframework",
                "-framework", frameworkIOS,
                "-framework", frameworkSim,
                "-output", xcframeworkRelativePath
            ]
        ]

        DispatchQueue.global(qos: .userInitiated).async {
            for (index, args) in commands.enumerated() {
                let commandLabel: String
                switch index {
                case 0: commandLabel = "📦 archive iOS"
                case 1: commandLabel = "📦 archive iOS Simulator"
                case 2: commandLabel = "🧰 create xcframework"
                default: commandLabel = "step \(index)"
                }

                self.log("➡️ Starting \(commandLabel): xcodebuild \(args.joined(separator: " "))")

                let startedAt = Date()
                let result = Self.runXcodebuild(
                    arguments: args,
                    in: projectDirURL,
                    logHandler: { [weak self] line in
                        self?.log(line)
                    }
                )
                let elapsed = Date().timeIntervalSince(startedAt)
                self.log("✅ Finished \(commandLabel) in \(String(format: "%.1f", elapsed))s")

                switch result {
                case .success:
                    continue
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
            }

            DispatchQueue.main.async {
                completion(.success(xcframeworkURL))
            }
        }
    }

    private func log(_ message: String) {
        // Console
        print("[XCFrameworkBuilder] \(message)")
        // UI hook
        logHandler(message)
    }

    // MARK: - Helpers

    private static func runXcodebuild(arguments: [String],
                                      in directory: URL,
                                      logHandler: @escaping (String) -> Void) -> Result<Void, Error> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = arguments
        process.currentDirectoryURL = directory

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let handle = pipe.fileHandleForReading

        // Stream output as it arrives
        handle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty,
                  let chunk = String(data: data, encoding: .utf8),
                  !chunk.isEmpty else { return }
            logHandler(chunk)
        }

        do {
            try process.run()
        } catch {
            handle.readabilityHandler = nil
            return .failure(error)
        }

        process.waitUntilExit()
        handle.readabilityHandler = nil

        let status = process.terminationStatus

        if status == 0 {
            return .success(())
        } else {
            let data = handle.readDataToEndOfFile()
            let tail = String(data: data, encoding: .utf8) ?? ""
            let error = NSError(
                domain: "XCFrameworkBuilder",
                code: Int(status),
                userInfo: [NSLocalizedDescriptionKey:
                    "xcodebuild failed with status \(status).\nLast output:\n\(tail)"]
            )
            return .failure(error)
        }
    }
}
