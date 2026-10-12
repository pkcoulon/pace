import AppKit
import SwiftUI

@MainActor
final class PanelState: ObservableObject {
    @Published fileprivate(set) var isOpen = false
}

private final class PopoverPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct PanelRoot<Content: View>: View {
    @ObservedObject var state: PanelState
    let content: Content
    let onResize: (CGSize) -> Void

    var body: some View {
        content
            .environment(\.isPanelOpen, state.isOpen)
            .fixedSize()
            .onSizeChange(onResize)
    }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private static let cornerRadius: CGFloat = 22
    private static let gap: CGFloat = 6
    private static let screenMargin: CGFloat = 8

    var onVisibilityChange: ((Bool) -> Void)?

    private let state = PanelState()
    private let panel: PopoverPanel
    private let hosting: NSHostingController<AnyView>
    private let container = NSView()
    private var monitors: [Any] = []
    private var anchor: NSRect?
    private var lastClose = Date.distantPast
    private var isClosing = false

    var isOpen: Bool { panel.isVisible && !isClosing }

    init<Content: View>(content: Content) {
        hosting = NSHostingController(rootView: AnyView(EmptyView()))
        panel = PopoverPanel(
            contentRect: NSRect(x: 0, y: 0, width: Theme.Size.popoverWidth, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        super.init()
        hosting.rootView = AnyView(PanelRoot(state: state, content: content) { [weak self] _ in
            Task { @MainActor in self?.fitToContent(animated: true) }
        })
        hosting.sizingOptions = []

        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.delegate = self
        panel.contentView = makeBackground()

    }

    func toggle(below anchor: NSRect) {
        if isOpen {
            close()
        } else if Date().timeIntervalSince(lastClose) > 0.25 {
            open(below: anchor)
        }
    }

    func open(below anchor: NSRect) {
        self.anchor = anchor
        isClosing = false
        let size = contentSize
        let frame = targetFrame(for: size)
        panel.setFrame(frame.offsetBy(dx: 0, dy: 6), display: false)
        pinHosting(to: size)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        state.isOpen = true
        onVisibilityChange?(true)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(frame, display: true)
        }
        installMonitors()
    }

    func close() {
        guard panel.isVisible, !isClosing else { return }
        isClosing = true
        lastClose = Date()
        removeMonitors()
        onVisibilityChange?(false)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in self?.finishClose() }
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func finishClose() {
        guard isClosing else { return }
        panel.orderOut(nil)
        panel.alphaValue = 1
        isClosing = false
        state.isOpen = false
    }

    private var contentSize: NSSize {
        let size = hosting.sizeThatFits(in: NSSize(width: Theme.Size.popoverWidth, height: 10_000))
        return NSSize(width: size.width.rounded(.up), height: size.height.rounded(.up))
    }

    private func fitToContent(animated: Bool) {
        guard panel.isVisible, !isClosing else { return }
        let size = contentSize
        guard size.width > 0, size.height > 0 else { return }
        let frame = targetFrame(for: size)
        guard frame != panel.frame else { return }
        pinHosting(to: size)
        guard animated else {
            panel.setFrame(frame, display: true)
            panel.invalidateShadow()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.25, 1)
            panel.animator().setFrame(frame, display: true)
        } completionHandler: { [weak self] in
            Task { @MainActor in self?.panel.invalidateShadow() }
        }
    }

    private func pinHosting(to size: NSSize) {
        container.layoutSubtreeIfNeeded()
        hosting.view.frame = NSRect(x: 0, y: container.bounds.height - size.height, width: size.width, height: size.height)
    }

    private func targetFrame(for size: NSSize) -> NSRect {
        guard let anchor else { return NSRect(origin: panel.frame.origin, size: size) }
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(origin: .zero, size: size)
        let x = min(max(anchor.midX - size.width / 2, visible.minX + Self.screenMargin), visible.maxX - size.width - Self.screenMargin)
        let top = min(anchor.minY, visible.maxY) - Self.gap
        return NSRect(x: x.rounded(), y: (top - size.height).rounded(), width: size.width, height: size.height)
    }

    private func makeBackground() -> NSView {
        container.autoresizingMask = [.width, .height]
        hosting.view.autoresizingMask = [.minYMargin]
        container.addSubview(hosting.view)
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = Self.cornerRadius
            glass.contentView = container
            container.frame = glass.bounds
            return glass
        }
        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = Self.cornerRadius
        effect.layer?.cornerCurve = .continuous
        effect.layer?.masksToBounds = true
        container.frame = effect.bounds
        effect.addSubview(container)
        return effect
    }

    private func installMonitors() {
        removeMonitors()
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown], handler: { [weak self] _ in
            Task { @MainActor in self?.close() }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard event.keyCode == 53 else { return event }
            Task { @MainActor in self?.close() }
            return nil
        }) {
            monitors.append(local)
        }
    }

    private func removeMonitors() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }
}
