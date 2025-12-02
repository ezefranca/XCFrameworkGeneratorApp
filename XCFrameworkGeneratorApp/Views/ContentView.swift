import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var viewModel: GeneratorViewModel
    @State private var showAlert = false
    @State private var isDropping = false

    var body: some View {
        VStack(spacing: 16) {
            header

            GroupBox {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.projectPath ?? "No project selected")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(viewModel.projectPath == nil ? .secondary : .primary)
                        Text("Select or drop an .xcodeproj to begin")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: openProject) {
                        Label("Open Project", systemImage: "folder.badge.plus")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .padding(8)
                .background(
                    ZStack {
                        if isDropping {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                .foregroundColor(.accentColor)
                                .transition(.opacity)
                        }
                    }
                )
            } label: {
                Label("Project", systemImage: "shippingbox")
            }

            GroupBox {
                HStack(spacing: 12) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 28)

                    SchemePickerView(
                        selectedScheme: $viewModel.selectedScheme,
                        schemes: viewModel.schemes
                    )
                    .disabled(viewModel.schemes.isEmpty)
                }
                .padding(8)
            } label: {
                Label("Build Configuration", systemImage: "gearshape")
            }

            HStack {
                if let url = viewModel.outputDirectoryURL {
                    Button(action: { NSWorkspace.shared.activateFileViewerSelecting([url]) }) {
                        Label("Reveal in Finder", systemImage: "eye")
                    }
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }
                Spacer()
                Button(action: viewModel.generateXCFramework) {
                    Label("Generate XCFramework", systemImage: "hammer")
                        .font(.headline)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.selectedScheme == nil || viewModel.isLoading)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 320)
        .overlay(alignment: .bottom) {
            if viewModel.isLoading {
                ProgressView("Working…")
                    .progressViewStyle(.circular)
                    .padding(.vertical, 8)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("XCFramework Generation"),
                message: Text(viewModel.notificationMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
        .onChange(of: viewModel.notificationMessage) { _, newValue in
            if newValue != nil { showAlert = true }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropping, perform: handleDrop(providers:))
    }
}

private extension ContentView {
    var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("XCFramework Generator")
                    .font(.system(.title2, design: .rounded)).bold()
                Text("Open your project, pick a scheme, and build a distributable XCFramework.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    func openProject() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["xcodeproj"]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Choose an Xcode Project"
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.loadProject(from: url)
        }
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        // Accept the first valid .xcodeproj file URL
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    if url.pathExtension == "xcodeproj" {
                        DispatchQueue.main.async {
                            viewModel.loadProject(from: url)
                        }
                    }
                }
                return true
            }
        }
        return false
    }
}
