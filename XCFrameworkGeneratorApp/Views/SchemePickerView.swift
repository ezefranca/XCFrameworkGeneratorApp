import SwiftUI

struct SchemePickerView: View {
    @Binding var selectedScheme: SchemeOption?
    let schemes: [SchemeOption]

    var body: some View {
        Picker(L10n.BuildConfiguration.schemePicker, selection: $selectedScheme) {
            ForEach(schemes) { scheme in
                Text(scheme.name)
                    .tag(Optional(scheme))
            }
        }
        .pickerStyle(.menu)
    }
}
