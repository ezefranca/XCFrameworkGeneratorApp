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
}
