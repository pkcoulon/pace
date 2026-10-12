import AppKit
import SwiftUI

@main
struct PaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    AppShell.shared?.showSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: UsageStore?
    private var shell: AppShell?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
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
}
