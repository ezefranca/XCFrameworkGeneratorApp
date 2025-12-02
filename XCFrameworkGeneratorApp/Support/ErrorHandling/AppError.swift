import Foundation

enum AppError: Error {
    case projectNotLoaded
    case projectLoadFailed(url: URL, underlying: Error)
    case schemeNotFound(String)
    case buildDirectoryCreationFailed(url: URL, underlying: Error)
    case xcodebuildFailed(stepName: String, status: Int32, logTail: String)
    case missingSchemeSelection
}

extension AppError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .projectNotLoaded:
            return NSLocalizedString("error.projectNotLoaded.description", comment: "")
        case .projectLoadFailed(let url, _):
            let format = NSLocalizedString("error.projectLoadFailed.description", comment: "")
            return String(format: format, url.lastPathComponent)
        case .schemeNotFound(let scheme):
            let format = NSLocalizedString("error.schemeNotFound.description", comment: "")
            return String(format: format, scheme)
        case .buildDirectoryCreationFailed(let url, _):
            let format = NSLocalizedString("error.buildDirectoryCreationFailed.description", comment: "")
            return String(format: format, url.path)
        case .xcodebuildFailed(let stepName, let status, _):
            let format = NSLocalizedString("error.xcodebuildFailed.description", comment: "")
            return String(format: format, stepName, status)
        case .missingSchemeSelection:
            return NSLocalizedString("error.missingSchemeSelection.description", comment: "")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .projectNotLoaded:
            return NSLocalizedString("error.projectNotLoaded.recovery", comment: "")
        case .projectLoadFailed:
            return NSLocalizedString("error.projectLoadFailed.recovery", comment: "")
        case .schemeNotFound:
            return NSLocalizedString("error.schemeNotFound.recovery", comment: "")
        case .buildDirectoryCreationFailed:
            return NSLocalizedString("error.buildDirectoryCreationFailed.recovery", comment: "")
        case .xcodebuildFailed:
            return NSLocalizedString("error.xcodebuildFailed.recovery", comment: "")
        case .missingSchemeSelection:
            return NSLocalizedString("error.missingSchemeSelection.recovery", comment: "")
        }
    }
}

extension AppError {
    var alertContext: AlertContext {
        let description = [errorDescription, recoverySuggestion]
            .compactMap { $0 }
            .joined(separator: "\n\n")
        return .error(message: description)
    }
}
