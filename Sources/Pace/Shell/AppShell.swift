import AppKit
import SwiftUI

@MainActor
final class AppShell {
    private(set) static var shared: AppShell?

    private let store: UsageStore
    private let statusItem: StatusItemController
    private let panel: PanelController
    private let settingsWindow: SettingsWindowController

    init(store: UsageStore, settings: SettingsStore) {
        self.store = store
        panel = PanelController(content: PopoverView()
            .environmentObject(store)
            .environmentObject(settings))
        settingsWindow = SettingsWindowController(store: store, settings: settings)
        statusItem = StatusItemController(store: store, settings: settings)

        statusItem.onClick = { [weak self] anchor in
            self?.togglePanel(below: anchor)
        }
        panel.onVisibilityChange = { [weak self] visible in
            self?.statusItem.setHighlighted(visible)
            if visible {
                Task { await self?.store.refreshIfStale() }
            }
        }
        Self.shared = self
    }

    func togglePanel(below anchor: NSRect) {
        panel.toggle(below: anchor)
    }

    func showSettings(_ pane: SettingsPane? = nil) {
        panel.close()
        settingsWindow.show(pane)
    }
}
