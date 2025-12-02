import Foundation

protocol BuildLogStoring: AnyObject {
    var currentLogURL: URL? { get }

    @discardableResult
    func startNewLog(for scheme: String) throws -> URL
    func append(_ line: String)
    func reset()
}

/// Persists build logs under ~/Library/Logs/XCFrameworkGeneratorApp using ISO8601 timestamps.
final class BuildLogStore: BuildLogStoring {
    private enum Constants {
        static let logsDirectoryComponent = "Logs/XCFrameworkGeneratorApp"
        static let fileQueueLabel = "com.ezefranca.xcframeworkgeneratorapp.logstore"
    }

    private let fileManager: FileManager
    private let queue: DispatchQueue
    private let logsDirectoryURL: URL
    private let isoFormatter: ISO8601DateFormatter

    private var fileHandle: FileHandle?
    private(set) var logURL: URL?

    var currentLogURL: URL? {
        queue.sync { logURL }
    }

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.queue = DispatchQueue(label: Constants.fileQueueLabel, qos: .utility)
        if let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first {
            self.logsDirectoryURL = libraryURL.appendingPathComponent(Constants.logsDirectoryComponent, isDirectory: true)
        } else {
            self.logsDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(Constants.logsDirectoryComponent, isDirectory: true)
        }
        self.isoFormatter = ISO8601DateFormatter()
        self.isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try? fileManager.createDirectory(at: logsDirectoryURL, withIntermediateDirectories: true)
    }

    deinit {
        queue.sync {
            fileHandle?.closeFile()
            fileHandle = nil
        }
    }

    @discardableResult
    func startNewLog(for scheme: String) throws -> URL {
        try fileManager.createDirectory(at: logsDirectoryURL, withIntermediateDirectories: true)
        let timestamp = isoFormatter.string(from: Date())
        let sanitizedScheme = Self.makeFileSystemSafeName(from: scheme)
        let fileName = "\(sanitizedScheme)-\(timestamp).log"
        let fileURL = logsDirectoryURL.appendingPathComponent(fileName, isDirectory: false)

        let header = """
        # XCFrameworkGeneratorApp Build Log
        # Scheme: \(scheme)
        # Started: \(timestamp)
        # Format: ISO8601 [LEVEL] [Component] Message
        #
        """
        try header.write(to: fileURL, atomically: true, encoding: .utf8)

        let handle = try FileHandle(forWritingTo: fileURL)
        try handle.seekToEnd()

        queue.sync {
            fileHandle?.closeFile()
            fileHandle = handle
            logURL = fileURL
        }

        return fileURL
    }

    func append(_ line: String) {
        guard !line.isEmpty else { return }

        queue.async { [weak self] in
            guard let self, let handle = self.fileHandle else { return }
            let lineWithBreak = line.hasSuffix("\n") ? line : line + "\n"
            if let data = lineWithBreak.data(using: .utf8) {
                handle.write(data)
            }
        }
    }

    func reset() {
        queue.sync {
            fileHandle?.closeFile()
            fileHandle = nil
            logURL = nil
        }
    }

    private static func makeFileSystemSafeName(from raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let joined = String(sanitized).replacingOccurrences(of: "--", with: "-")
        return joined.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            .isEmpty ? "scheme" : joined
    }
}
