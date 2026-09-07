import AppKit
import SwiftUI

@main
struct PaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings: SettingsStore
    @StateObject private var store: UsageStore

    init() {
        let settings = SettingsStore()
        let store = UsageStore(settings: settings, providers: ProviderFactory.makeProviders())
        _settings = StateObject(wrappedValue: settings)
        _store = StateObject(wrappedValue: store)
        if let directory = SnapshotExporter.requestedDirectory {
            Task { @MainActor in
                await store.refresh(force: true)
                SnapshotExporter.export(to: directory, store: store, settings: settings)
                NSApp.terminate(nil)
            }
        } else {
            store.start()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(store)
                .environmentObject(settings)
        } label: {
            MenuBarLabel(store: store, settings: settings)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
