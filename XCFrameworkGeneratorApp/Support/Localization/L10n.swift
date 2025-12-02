import SwiftUI

enum L10n {
    enum App {
        static let title = LocalizedStringKey("app.title")
        static let subtitle = LocalizedStringKey("app.subtitle")
    }

    enum Project {
        static let title = LocalizedStringKey("group.project.title")
        static let placeholder = LocalizedStringKey("group.project.placeholder")
        static let subtitle = LocalizedStringKey("group.project.subtitle")
    }

    enum BuildConfiguration {
        static let title = LocalizedStringKey("group.buildConfiguration.title")
        static let schemePicker = LocalizedStringKey("picker.scheme.title")
    }

    enum Actions {
        static let openProject = LocalizedStringKey("action.openProject")
        static let revealInFinder = LocalizedStringKey("action.revealInFinder")
        static let generate = LocalizedStringKey("action.generate")
        static let buildLog = LocalizedStringKey("action.log.menu")
        static let openLog = LocalizedStringKey("action.log.open")
        static let exportLog = LocalizedStringKey("action.log.export")
    }

    enum Alerts {
        static let successTitle = LocalizedStringKey("alert.success.title")
        static let errorTitle = LocalizedStringKey("alert.error.title")
    }

    enum Progress {
        static let archiveIOS = LocalizedStringKey("progress.archiveIOS")
        static let archiveSimulator = LocalizedStringKey("progress.archiveSimulator")
        static let createXCFramework = LocalizedStringKey("progress.createXCFramework")
        static let complete = LocalizedStringKey("progress.complete")
    }

    enum MenuBar {
        static let title = LocalizedStringKey("menubar.title")
    }

    enum Settings {
        static let generalSectionTitle = LocalizedStringKey("settings.section.general")
        static let presentationTitle = LocalizedStringKey("settings.mode.title")
        static let presentationDescription = LocalizedStringKey("settings.mode.description")
        static let menuBarUnavailable = LocalizedStringKey("settings.mode.menuBar.unavailable")
    }
}
