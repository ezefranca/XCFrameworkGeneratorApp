import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let useMenuBarOnly = UserDefaults.standard.bool(forKey: "useMenuBarOnly")
        updateActivationPolicy(menuBarOnly: useMenuBarOnly)
    }

    func updateActivationPolicy(menuBarOnly: Bool) {
        let policy: NSApplication.ActivationPolicy = menuBarOnly ? .accessory : .regular
        NSApp.setActivationPolicy(policy)

        // Bring to front if in dock mode
        if policy == .regular {
            NSApp.activate(ignoringOtherApps: true)
        }

        print("[AppDelegate] Switched to \(menuBarOnly ? "Menu Bar" : "Dock") mode.")
        NSApp.setActivationPolicy(menuBarOnly ? .accessory : .regular)
        if !menuBarOnly {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true) // Bring to front
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(nil)     // Unhide main window
            }
        }
    }
}
