import AppKit
import Combine
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var states: [ProviderID: ProviderState] = [:]
    @Published private(set) var statuses: [ProviderID: ProviderStatus] = [:]
    @Published private(set) var lastAttempt: Date?
    @Published private(set) var isRefreshing = false
    @Published private(set) var availableUpdate: AvailableUpdate?

    private static let minimumRefreshAge: TimeInterval = 60
    private static let wakeDelay: Duration = .seconds(5)

    private let settings: SettingsStore
    let history: UsageHistory
    private let providers: [ProviderID: any UsageProvider]
    private let notifications: NotificationService
    private let statusService = StatusService()
    private var retryAt: [ProviderID: Date] = [:]
    private var attemptedAt: [ProviderID: Date] = [:]
    private var consecutiveRateLimits: [ProviderID: Int] = [:]
    private var inFlight: Set<ProviderID> = [] {
        didSet { isRefreshing = !inFlight.isEmpty }
    }
    private var loop: Task<Void, Never>?
    private var statusLoop: Task<Void, Never>?
    private var wakeRefresh: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private var watchers: [DirectoryWatcher] = []

    init(settings: SettingsStore, providers: [any UsageProvider], notifications: NotificationService = NotificationService()) {
        self.settings = settings
        self.providers = Dictionary(uniqueKeysWithValues: providers.map { ($0.id, $0) })
        self.notifications = notifications
        self.history = UsageHistory()

        settings.$refreshMinutes
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in self?.restartLoop() }
            .store(in: &cancellables)

        settings.$enabledProviders
            .map { Set($0) }
            .scan((old: Set<ProviderID>(), new: Set<ProviderID>())) { ($0.new, $1) }
            .dropFirst()
            .sink { [weak self] change in
                guard let self else { return }
                notifications.cancelResetNotifications(for: Array(change.old.subtracting(change.new)))
                let added = change.new.subtracting(change.old)
                Task {
                    if self.settings.exportJSON { self.exportUsage() }
                    await self.refresh(force: false) { added.contains($0) }
                }
            }
            .store(in: &cancellables)

        settings.$credentialsRevision
            .dropFirst()
            .sink { [weak self] _ in Task { await self?.refresh(.claude) } }
            .store(in: &cancellables)

        settings.$notifyOnReset
            .dropFirst()
            .removeDuplicates()
            .filter { !$0 }
            .sink { [weak self] _ in self?.notifications.cancelResetNotifications(for: ProviderRegistry.all.map(\.id)) }
            .store(in: &cancellables)

        settings.$exportJSON
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] enabled in
                if enabled { self?.exportUsage() } else { UsageExporter.remove() }
            }
            .store(in: &cancellables)

        settings.$checkForUpdates
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in Task { await self?.checkForUpdate() } }
            .store(in: &cancellables)

        // Affiche immédiatement le dernier usage connu, avant le premier appel.
        if let snapshot = UsageCache.load() {
            for (id, usage) in snapshot.usages {
                states[id] = .loaded(usage)
            }
        }
    }

    func start() {
        notifications.requestAuthorization()
        startWatchers()
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didWakeNotification)
            .map { _ in () }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.scheduleWakeRefresh() }
            .store(in: &cancellables)
        restartLoop()
        startStatusLoop()
    }

    var lastRefresh: Date? {
        fetchDates.max()
    }

    var oldestFetchedAt: Date? {
        fetchDates.min()
    }

    var staleThreshold: TimeInterval {
        max(2 * Double(settings.refreshMinutes) * 60, 10 * 60)
    }

    func isStale(_ id: ProviderID, now: Date) -> Bool {
        guard let fetchedAt = states[id]?.usage?.fetchedAt else { return false }
        return now.timeIntervalSince(fetchedAt) > staleThreshold
    }

    func hasStaleData(now: Date) -> Bool {
        settings.enabledProviders.contains { isStale($0, now: now) }
    }

    func pacing(for id: ProviderID, slot: WindowSlot, now: Date) -> Pacing? {
        guard let window = states[id]?.usage?.window(slot)?.effective(at: now) else { return nil }
        let recentRate = slot == .short ? history.recentRate(for: id, slot: slot, window: window, now: now) : nil
        return PacingCalculator.evaluate(window, recentRate: recentRate, now: now)
    }

    private var fetchDates: [Date] {
        settings.enabledProviders.compactMap { states[$0]?.usage?.fetchedAt }
    }

    /// Surveille les pages de statut et les mises à jour, sur une cadence lente.
    private func startStatusLoop() {
        statusLoop?.cancel()
        statusLoop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await refreshStatuses()
                await checkForUpdate()
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }

    private func refreshStatuses() async {
        let pages = settings.enabledProviders.compactMap { id in
            ProviderRegistry.descriptor(for: id)?.statusPage.map { (id, $0) }
        }
        await withTaskGroup(of: (ProviderID, ProviderStatus).self) { group in
            for (id, page) in pages {
                group.addTask { [statusService] in (id, await statusService.fetch(page)) }
            }
            for await (id, status) in group {
                statuses[id] = status
            }
        }
    }

    private func checkForUpdate() async {
        guard settings.checkForUpdates else {
            availableUpdate = nil
            return
        }
        let update = await UpdateChecker.availableUpdate()
        availableUpdate = settings.checkForUpdates ? update : nil
    }

    /// Rafraîchit dès que les credentials de Claude Code ou de Codex changent sur disque.
    private func startWatchers() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let watched: [(directory: String, ids: Set<ProviderID>)] = [(".claude", [.claude, .zai]), (".codex", [.codex])]
        watchers = watched.compactMap { directory, ids in
            DirectoryWatcher(path: home.appendingPathComponent(directory).path) { [weak self] in
                Task { @MainActor in await self?.refreshIfStale(only: ids) }
            }
        }
    }

    private func scheduleWakeRefresh() {
        wakeRefresh?.cancel()
        wakeRefresh = Task { [weak self] in
            try? await Task.sleep(for: Self.wakeDelay)
            guard !Task.isCancelled, let self else { return }
            let now = Date()
            await refresh(force: false) { id in
                states[id]?.usage.map { now.timeIntervalSince($0.fetchedAt) >= Self.minimumRefreshAge } ?? true
            }
        }
    }

    func refresh(force: Bool = false) async {
        await refresh(force: force) { _ in true }
    }

    func refresh(_ id: ProviderID) async {
        await refresh(force: true) { $0 == id }
    }

    func refreshIfStale(only ids: Set<ProviderID>? = nil) async {
        let now = Date()
        await refresh(force: false) { id in
            guard ids?.contains(id) ?? true else { return false }
            return attemptedAt[id].map { now.timeIntervalSince($0) >= Self.minimumRefreshAge } ?? true
        }
    }

    private func refresh(force: Bool, when isDue: (ProviderID) -> Bool) async {
        let now = Date()
        let due = providers.filter { id, _ in
            guard settings.isEnabled(id), !inFlight.contains(id), isDue(id) else { return false }
            if force { return true }
            if let retry = retryAt[id], retry > now { return false }
            return true
        }
        guard !due.isEmpty else { return }
        inFlight.formUnion(due.keys)
        defer { inFlight.subtract(due.keys) }

        await withTaskGroup(of: (ProviderID, Result<ProviderUsage, ProviderError>).self) { group in
            for (id, provider) in due {
                group.addTask { (id, await Self.fetch(provider)) }
            }
            for await (id, result) in group {
                attemptedAt[id] = Date()
                apply(result, to: id)
            }
        }
        lastAttempt = Date()
        persistCache()
        if settings.exportJSON { exportUsage() }
    }

    private func persistCache() {
        var usages: [ProviderID: ProviderUsage] = [:]
        for (id, state) in states {
            if let usage = state.usage { usages[id] = usage }
        }
        UsageCache.save(UsageCache.Snapshot(usages: usages))
    }

    private func exportUsage() {
        UsageExporter.write(self, providers: settings.enabledProviders)
    }

    private nonisolated static func fetch(_ provider: any UsageProvider) async -> Result<ProviderUsage, ProviderError> {
        do {
            return .success(try await provider.fetchUsage())
        } catch let error as ProviderError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    private func apply(_ result: Result<ProviderUsage, ProviderError>, to id: ProviderID) {
        switch result {
        case .success(let usage):
            states[id] = .loaded(usage)
            retryAt[id] = nil
            consecutiveRateLimits[id] = 0
            history.record(usage, for: id)
            notifications.evaluate(
                id: id,
                usage: usage,
                settings: settings,
                shortPacing: pacing(for: id, slot: .short, now: Date())
            )
        case .failure(let error):
            states[id] = .failed(error, last: states[id]?.usage)
            if case .rateLimited(let retryAfter) = error {
                let attempt = (consecutiveRateLimits[id] ?? 0) + 1
                consecutiveRateLimits[id] = attempt
                retryAt[id] = Date().addingTimeInterval(
                    RateLimitBackoff.delay(attempt: attempt, serverRetryAfter: retryAfter)
                )
            }
        }
    }

    private func restartLoop() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await Task { await self.refresh() }.value
                try? await Task.sleep(for: settings.refreshInterval)
            }
        }
    }
}
