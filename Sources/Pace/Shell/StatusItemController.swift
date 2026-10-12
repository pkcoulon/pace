import AppKit
import Combine

@MainActor
final class StatusItemController: NSObject {
    var onClick: ((NSRect) -> Void)?

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let store: UsageStore
    private let settings: SettingsStore
    private var cancellables: Set<AnyCancellable> = []
    private var appearanceObservation: NSKeyValueObservation?
    private var timer: Timer?

    init(store: UsageStore, settings: SettingsStore) {
        self.store = store
        self.settings = settings
        super.init()

        if let button = item.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseDown, .rightMouseDown])
            button.imagePosition = .imageOnly
            appearanceObservation = button.observe(\.effectiveAppearance) { [weak self] _, _ in
                Task { @MainActor in self?.render() }
            }
        }

        Publishers.Merge(store.objectWillChange, settings.objectWillChange)
            .debounce(for: .milliseconds(40), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated { self?.render() }
            }
            .store(in: &cancellables)

        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.render() }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        render()
    }

    func setHighlighted(_ highlighted: Bool) {
        item.button?.highlight(highlighted)
    }

    @objc private func clicked() {
        guard let button = item.button, let window = button.window else { return }
        onClick?(window.convertToScreen(button.convert(button.bounds, to: nil)))
    }

    private func render() {
        guard let button = item.button else { return }
        let dark = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let items = MenuBarComposer.items(store: store, settings: settings, now: Date())
        button.image = MenuBarRenderer.image(
            for: items,
            style: settings.menuBarStyle,
            highlightOnlyAlerts: settings.highlightOnlyAlerts,
            dark: dark
        )
        button.setAccessibilityLabel(MenuBarComposer.accessibilityLabel(items))
    }
}
