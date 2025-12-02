import SwiftUI

struct SettingsView: View {
    @AppStorage(AppPresentationMode.storageKey)
    private var modeRawValue = AppPresentationMode.window.rawValue

    // Read-only computed value based on AppStorage
    private var selectedMode: AppPresentationMode {
        let stored = AppPresentationMode(rawValue: modeRawValue) ?? .window
        return stored.isSupported ? stored : .window
    }

    // Binding that writes directly to AppStorage
    private var selectedModeBinding: Binding<AppPresentationMode> {
        Binding(
            get: { selectedMode },
            set: { newValue in
                let final = newValue.isSupported ? newValue : .window
                modeRawValue = final.rawValue
            }
        )
    }

    private var availableModes: [AppPresentationMode] {
        AppPresentationMode.allCases.filter { $0.isSupported }
    }

    var body: some View {
        Form {
            Section(L10n.Settings.generalSectionTitle) {
                Picker(
                    L10n.Settings.presentationTitle,
                    selection: selectedModeBinding
                ) {
                    ForEach(availableModes) { mode in
                        Label(mode.localizedLabel, systemImage: mode.systemImage)
                            .tag(mode)
                    }
                }

                Text(L10n.Settings.presentationDescription)
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Text(selectedMode.localizedDescription)
                    .font(.footnote)
                    .foregroundColor(.secondary)

                if !AppPresentationMode.menuBar.isSupported {
                    Label(L10n.Settings.menuBarUnavailable, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}

#Preview {
    SettingsView()
}
