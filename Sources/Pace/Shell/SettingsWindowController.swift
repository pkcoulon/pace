import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private let tabs: SettingsTabViewController

    init(store: UsageStore, settings: SettingsStore) {
        let tabs = SettingsTabViewController()
        self.tabs = tabs
        for pane in SettingsPane.allCases {
            let host = NSHostingController(rootView: AnyView(
                pane.content
                    .environmentObject(settings)
                    .environmentObject(store)
                    .onSizeChange { [weak tabs] _ in
                        Task { @MainActor in tabs?.fitWindow(animated: true) }
                    }
            ))
            host.sizingOptions = []
            host.title = pane.title
            let item = NSTabViewItem(viewController: host)
            item.label = pane.title
            item.image = NSImage(systemSymbolName: pane.symbol, accessibilityDescription: pane.title)
            tabs.addTabViewItem(item)
        }
        tabs.tabStyle = .toolbar
        tabs.transitionOptions = [.crossfade, .allowUserInteraction]

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(_ pane: SettingsPane?) {
        if let pane {
            tabs.selectedTabViewItemIndex = pane.rawValue
        }
        if window?.isVisible != true {
            tabs.fitWindow(animated: false)
            window?.center()
        }
        NSApp.activate()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}

@MainActor
private final class SettingsTabViewController: NSTabViewController {
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        fitWindow(animated: true)
    }

    func fitWindow(animated: Bool) {
        guard let window = view.window,
              let host = tabView.selectedTabViewItem?.viewController as? NSHostingController<AnyView> else { return }
        let size = host.sizeThatFits(in: NSSize(width: 10_000, height: 10_000))
        guard size.width > 0, size.height > 0 else { return }
        let target = window.frameRect(forContentRect: NSRect(origin: .zero, size: size)).size
        guard target != window.frame.size else { return }
        var frame = window.frame
        frame.origin.y += frame.height - target.height
        frame.size = target
        window.setFrame(frame, display: true, animate: animated && window.isVisible)
    }
}
