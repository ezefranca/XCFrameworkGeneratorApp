import Foundation
import Combine
import AppKit

final class GeneratorViewModel: ObservableObject {
    // MARK: - Published state

    @Published var schemes: [SchemeOption] = []
    @Published var selectedScheme: SchemeOption?
    @Published var isLoading: Bool = false
    @Published var notificationMessage: String?
    @Published var outputDirectoryURL: URL?
    @Published var buildProgress: BuildProgress = .idle
    @Published var lastLogLine: String = ""
    @Published var alertContext: AlertContext?
    @Published var logFileURL: URL?

    // MARK: - Dependencies

    private let xcodeProjService: XcodeProjServicing
    private let logStore: BuildLogStoring
    private lazy var xcFrameworkBuilder: XCFrameworkBuilder = {
        XCFrameworkBuilder(
            xcodeProjService: xcodeProjService,
            logHandler: { [weak self] line in
                self?.captureLog(line)
            },
            progressHandler: { [weak self] current, total, label in
                DispatchQueue.main.async {
                    self?.buildProgress = BuildProgress(currentStep: current, totalSteps: total, label: label)
                }
            }
        )
    }()

    // MARK: - Init

    /// You must inject XcodeProjService, because XCFrameworkBuilder depends on it.
    init(xcodeProjService: XcodeProjServicing, logStore: BuildLogStoring = BuildLogStore()) {
        self.xcodeProjService = xcodeProjService
        self.logStore = logStore
    }

    // MARK: - Derived state

    var projectPath: String? { xcodeProjService.projectPath }

    // MARK: - Public API

    func loadProject(from url: URL) {
        isLoading = true
        notificationMessage = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let success = self.xcodeProjService.loadProject(at: url.path)

            DispatchQueue.main.async {
                if success {
                    self.fetchSchemes()
                } else {
                    self.isLoading = false
                    self.notificationMessage = "Failed to open project at \(url.lastPathComponent)."
                    self.alertContext = AlertContext(title: "Error", message: self.notificationMessage ?? "", dismissButtonTitle: "OK")
                }
            }
        }
    }

    func fetchSchemes() {
        isLoading = true
        notificationMessage = nil

        // If this hits disk or parses a project, do it off the main thread.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let schemeNames = self.xcodeProjService.fetchSchemes()
            let options = schemeNames.map { SchemeOption(name: $0, id: $0) }

            DispatchQueue.main.async {
                self.schemes = options
                self.isLoading = false

                // Auto-select first scheme if none selected yet
                if self.selectedScheme == nil {
                    self.selectedScheme = options.first
                }
            }
        }
    }

    func generateXCFramework() {
        guard let scheme = selectedScheme else {
            notificationMessage = "Please select a scheme."
            alertContext = AlertContext(title: "Warning", message: notificationMessage ?? "", dismissButtonTitle: "OK")
            return
        }

        isLoading = true
        notificationMessage = nil
        buildProgress = .idle
        lastLogLine = ""

        do {
            logFileURL = try logStore.startNewLog(for: scheme.name)
        } catch {
            isLoading = false
            notificationMessage = "Unable to create log file."
            alertContext = AlertContext(
                title: "Logging Error",
                message: error.localizedDescription,
                dismissButtonTitle: "OK"
            )
            return
        }

        xcFrameworkBuilder.buildXCFramework(scheme: scheme.name) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false

                switch result {
                case .success(let url):
                    self.outputDirectoryURL = url
                    self.notificationMessage = "XCFramework generated successfully!"
                    self.buildProgress = BuildProgress(currentStep: self.buildProgress.totalSteps, totalSteps: self.buildProgress.totalSteps, label: "Complete")
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                case .failure(let error):
                    self.notificationMessage = "Error generating XCFramework: \(error.localizedDescription)"
                    self.alertContext = AlertContext(title: "Build Failed", message: self.notificationMessage ?? "", dismissButtonTitle: "OK")
                }
            }
        }
    }

    func openLog() {
        guard let logURL = logFileURL else { return }
        NSWorkspace.shared.open(logURL)
    }

    func exportLog() {
        guard let logURL = logFileURL else { return }

        let panel = NSSavePanel()
        panel.title = "Export Build Log"
        panel.nameFieldStringValue = logURL.lastPathComponent
        panel.allowedFileTypes = ["log"]

        if panel.runModal() == .OK, let destinationURL = panel.url {
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: logURL, to: destinationURL)
                NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
            } catch {
                alertContext = AlertContext(
                    title: "Export Failed",
                    message: "Unable to export log: \(error.localizedDescription)",
                    dismissButtonTitle: "OK"
                )
            }
        }
    }
}

private extension GeneratorViewModel {
    func captureLog(_ line: String) {
        logStore.append(line)
        DispatchQueue.main.async {
            self.lastLogLine = line.split(separator: "\n").last.map(String.init) ?? line
        }
    }
}
