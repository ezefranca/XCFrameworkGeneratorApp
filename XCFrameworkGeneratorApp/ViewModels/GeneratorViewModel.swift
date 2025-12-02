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

    // Progress UI
    @Published var currentStep: Int = 0
    @Published var totalSteps: Int = 0
    @Published var currentStepLabel: String = ""
    @Published var lastLogLine: String = ""

    // MARK: - Dependencies

    private let xcodeProjService: XcodeProjService
    private lazy var xcFrameworkBuilder: XCFrameworkBuilder = {
        XCFrameworkBuilder(
            xcodeProjService: xcodeProjService,
            logHandler: { [weak self] line in
                DispatchQueue.main.async {
                    self?.lastLogLine = line.split(separator: "\n").last.map(String.init) ?? line
                }
            },
            progressHandler: { [weak self] current, total, label in
                DispatchQueue.main.async {
                    self?.currentStep = current
                    self?.totalSteps = total
                    self?.currentStepLabel = label
                }
            }
        )
    }()

    // MARK: - Init

    /// You must inject XcodeProjService, because XCFrameworkBuilder depends on it.
    init(xcodeProjService: XcodeProjService) {
        self.xcodeProjService = xcodeProjService
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
            return
        }

        isLoading = true
        notificationMessage = nil

        currentStep = 0
        totalSteps = 0
        currentStepLabel = ""
        lastLogLine = ""

        xcFrameworkBuilder.buildXCFramework(scheme: scheme.name) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false

                switch result {
                case .success(let url):
                    self.outputDirectoryURL = url
                    self.notificationMessage = "XCFramework generated successfully!"
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                    self.currentStepLabel = "Complete"
                case .failure(let error):
                    self.notificationMessage = "Error generating XCFramework: \(error.localizedDescription)"
                }
            }
        }
    }
}
