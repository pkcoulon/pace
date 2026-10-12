import AppKit

@main
@MainActor
enum PaceApp {
    private static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: UsageStore?
    private var shell: AppShell?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.mainMenu = mainMenu()
        let settings = SettingsStore()
        let store = UsageStore(settings: settings, providers: ProviderFactory.makeProviders())
        self.store = store

        if let directory = SnapshotExporter.requestedDirectory {
            Task {
                await store.refresh(force: true)
                SnapshotExporter.export(to: directory, store: store, settings: settings)
                NSApp.terminate(nil)
            }
            return
        }
        store.start()
        shell = AppShell(store: store, settings: settings)
    }

    @objc private func showSettings() {
        AppShell.shared?.showSettings()
    }

    private func mainMenu() -> NSMenu {
        let app = NSMenu()
        app.addItem(withTitle: String(localized: "Settings…"), action: #selector(showSettings), keyEquivalent: ",").target = self
        app.addItem(.separator())
        app.addItem(withTitle: String(localized: "Quit Pace"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let main = NSMenu()
        for submenu in [app, edit, window] {
            let item = NSMenuItem()
            item.submenu = submenu
            main.addItem(item)
        }
        return main
    }
}
