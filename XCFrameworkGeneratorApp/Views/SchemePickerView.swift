import SwiftUI

struct SchemePickerView: View {
    @State private var isLoading: Bool = false
    @Binding var selectedScheme: SchemeOption?
    let schemes: [SchemeOption]

    var body: some View {
        Picker("Scheme", selection: $selectedScheme) {
            ForEach(schemes) { scheme in
                Text(scheme.name)
                    .tag(Optional(scheme)) // tag must match Binding<SchemeOption?>
            }
        }
        .pickerStyle(.menu)
    }
}
