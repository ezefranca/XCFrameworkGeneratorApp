import Foundation
import XcodeProj

protocol XcodeProjServicing {
    var projectPath: String? { get }
    var project: XcodeProj? { get }
    func loadProject(at path: String) -> Bool
    func fetchSchemes() -> [String]
}

final class XcodeProjService: XcodeProjServicing {
    private(set) var projectPath: String?
    private(set) var project: XcodeProj?

    func loadProject(at path: String) -> Bool {
        do {
            let proj = try XcodeProj(pathString: path)
            self.project = proj
            self.projectPath = path
            return true
        } catch {
            print("[XcodeProjService] Failed to load project at \(path): \(error)")
            self.project = nil
            self.projectPath = nil
            return false
        }
    }

    func fetchSchemes() -> [String] {
        guard let projectPath else { return [] }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = ["-list", "-project", projectPath]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return [] }
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        guard let schemesMarker = output.range(of: "Schemes:") else { return [] }
        let afterMarker = output[schemesMarker.upperBound...]
        var result: [String] = []
        for raw in afterMarker.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { break }
            if line.hasSuffix(":") { break }
            result.append(line)
        }
        return result
    }
}
