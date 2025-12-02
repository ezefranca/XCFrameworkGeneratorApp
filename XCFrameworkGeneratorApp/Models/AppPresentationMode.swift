import SwiftUI

enum AppPresentationMode: String, CaseIterable, Identifiable {
    case window
    case menuBar

    static let storageKey = "app.presentation.mode"

    var id: String { rawValue }

    var localizedLabel: LocalizedStringKey {
        switch self {
        case .window:
            return LocalizedStringKey("settings.mode.window")
        case .menuBar:
            return LocalizedStringKey("settings.mode.menuBar")
        }
    }

    var localizedDescription: LocalizedStringKey {
        switch self {
        case .window:
            return LocalizedStringKey("settings.mode.window.detail")
        case .menuBar:
            return LocalizedStringKey("settings.mode.menuBar.detail")
        }
    }

    var systemImage: String {
        switch self {
        case .window:
            return "macwindow"
        case .menuBar:
            return "menubar.rectangle"
        }
    }

    var isSupported: Bool {
        switch self {
        case .window:
            return true
        case .menuBar:
            if #available(macOS 13.0, *) {
                return true
            } else {
                return false
            }
        }
    }
}
