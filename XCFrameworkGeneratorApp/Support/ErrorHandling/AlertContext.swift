import Foundation

struct AlertContext: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let dismissButtonTitle: String

    static func success(message: String) -> AlertContext {
        AlertContext(
            title: NSLocalizedString("alert.success.title", comment: ""),
            message: message,
            dismissButtonTitle: NSLocalizedString("action.ok", comment: "")
        )
    }

    static func error(message: String) -> AlertContext {
        AlertContext(
            title: NSLocalizedString("alert.error.title", comment: ""),
            message: message,
            dismissButtonTitle: NSLocalizedString("action.ok", comment: "")
        )
    }
}
