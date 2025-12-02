import SwiftUI

@main
struct XCFrameworkGeneratorApp: App {
    @AppStorage("useMenuBarOnly") private var useMenuBarOnly: Bool = false

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var viewModel = GeneratorViewModel(
        xcodeProjService: XcodeProjService()
    )

    var body: some Scene {
        // Main window (only when not using menu bar only)
        WindowGroup("XCFramework Generator") {
           // if !useMenuBarOnly {
                ContentView()
                    .environmentObject(viewModel)
                    .opacity(useMenuBarOnly ? 0 : 1)
           // }
        }

        // Menu bar version
        MenuBarExtra(L10n.MenuBar.title, image: "MenuBarToolbox") {
            VStack(spacing: 8) {
                // Main content in menu bar mode
                ContentView()
                    .environmentObject(viewModel)
                    .frame(
                        width: useMenuBarOnly ? 700 : 0,
                        height: useMenuBarOnly ? 350 : 0
                    )
                    .opacity(useMenuBarOnly ? 1 : 0)

                Divider()

                // Compact footer
                VStack(spacing: 6) {
                    // Actions row
                    HStack(spacing: 8) {
                        Button(action: toggleMode) {
                            Label(
                                useMenuBarOnly ? "Switch to Dock" : "Switch to Menu Bar",
                                systemImage: useMenuBarOnly ? "dock.rectangle" : "menubar.rectangle"
                            )
                            .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .keyboardShortcut("m", modifiers: .command)

                        Spacer()

                        Button(role: .destructive) {
                            NSApp.terminate(nil)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                .frame(minWidth: 240)
            }
            .padding(.top, 8)
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .help) {
                Button("XCFramework Generator Help") {
                    openHelpWindow()
                }
                .keyboardShortcut("?", modifiers: [.command, .shift])
            }
        }
    }
    

    private func toggleMode() {
        useMenuBarOnly.toggle()
        appDelegate.updateActivationPolicy(menuBarOnly: useMenuBarOnly)
    }
    
    func openHelpWindow() {
        let helpWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false)

        helpWindow.center()
        helpWindow.title = "XCFramework Generator Help"
        helpWindow.isReleasedWhenClosed = false
        helpWindow.contentView = NSHostingView(rootView: SettingsView())
        helpWindow.makeKeyAndOrderFront(nil)
    }
}
