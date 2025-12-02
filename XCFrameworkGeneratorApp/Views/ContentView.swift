import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var viewModel: GeneratorViewModel
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
                        Text(viewModel.projectPath ?? NSLocalizedString("group.project.placeholder", comment: ""))
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(viewModel.projectPath == nil ? .secondary : .primary)
                        Text(L10n.Project.subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: openProject) {
                        Label(L10n.Actions.openProject, systemImage: "folder.badge.plus")
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
                Label(L10n.Project.title, systemImage: "shippingbox")
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
                Label(L10n.BuildConfiguration.title, systemImage: "gearshape")
            }

            HStack {
                if viewModel.logFileURL != nil {
                    Menu {
                        Button(action: viewModel.openLog) {
                            Label(L10n.Actions.openLog, systemImage: "doc.text.magnifyingglass")
                        }
                        Button(action: viewModel.exportLog) {
                            Label(L10n.Actions.exportLog, systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Label(L10n.Actions.buildLog, systemImage: "doc.text")
                    }
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }

                if let url = viewModel.outputDirectoryURL {
                    Button(action: { NSWorkspace.shared.activateFileViewerSelecting([url]) }) {
                        Label(L10n.Actions.revealInFinder, systemImage: "eye")
                    }
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }
                Spacer()
                Button(action: viewModel.generateXCFramework) {
                    Label(L10n.Actions.generate, systemImage: "hammer")
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
                VStack(alignment: .leading, spacing: 6) {
                    if viewModel.buildProgress.totalSteps > 0 {
                        ProgressView(value: Double(viewModel.buildProgress.currentStep), total: Double(viewModel.buildProgress.totalSteps)) {
                            Text(viewModel.buildProgress.label)
                                .font(.system(size: 8))
                                .fontDesign(.monospaced)
                        }
                        .progressViewStyle(.linear)
                    } else {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                    if !viewModel.lastLogLine.isEmpty {
                        Text(viewModel.lastLogLine.trimmingCharacters(in: .whitespacesAndNewlines))
                            .font(.system(size: 8))
                            .fontDesign(.monospaced)
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial)
                .cornerRadius(8)
                .padding(.bottom, 8)
                .padding(.horizontal, 8)
            }
        }
        .alert(item: $viewModel.alertContext) { context in
            Alert(
                title: Text(context.title),
                message: Text(context.message),
                dismissButton: .default(Text(context.dismissButtonTitle))
            )
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
                Text(L10n.App.title)
                    .font(.system(.title2, design: .rounded)).bold()
                Text(L10n.App.subtitle)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    func openProject() {
        let panel = NSOpenPanel()
        panel.treatsFilePackagesAsDirectories = false
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if #available(macOS 12.0, *) {
            // Use the official UTI for Xcode projects; filenameExtension sometimes fails for packages
            if let xcodeProjUTType = UTType("com.apple.xcode.project") {
                panel.allowedContentTypes = [xcodeProjUTType]
            } else {
                panel.allowedContentTypes = []
                panel.allowedFileTypes = ["xcodeproj"]
            }
        } else {
            panel.allowedFileTypes = ["xcodeproj"]
        }
        panel.title = NSLocalizedString("panel.projectPicker.title", comment: "")
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.loadProject(from: url)
        }
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    if url.pathExtension == "xcodeproj" || url.lastPathComponent.hasSuffix(".xcodeproj") {
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
