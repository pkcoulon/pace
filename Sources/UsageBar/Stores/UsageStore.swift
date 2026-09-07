import Foundation
import Combine

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var states: [ProviderKind: ProviderState] = [:]
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var isRefreshing = false

    private let settings: SettingsStore
    private let providers: [ProviderKind: any UsageProvider]
    private let notifications: NotificationService
    private var retryAt: [ProviderKind: Date] = [:]
    private var consecutiveRateLimits: [ProviderKind: Int] = [:]
    private var loop: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private var watchers: [DirectoryWatcher] = []

    init(settings: SettingsStore, providers: [any UsageProvider], notifications: NotificationService = NotificationService()) {
        self.settings = settings
        self.providers = Dictionary(uniqueKeysWithValues: providers.map { ($0.kind, $0) })
        self.notifications = notifications

        settings.$refreshMinutes
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in self?.restartLoop() }
            .store(in: &cancellables)

        Publishers.Merge(settings.$claudeEnabled.dropFirst(), settings.$codexEnabled.dropFirst())
            .filter { $0 }
            .sink { [weak self] _ in self?.restartLoop() }
            .store(in: &cancellables)

        settings.$credentialsRevision
            .dropFirst()
            .sink { [weak self] _ in Task { await self?.refresh(force: true) } }
            .store(in: &cancellables)
    }

    func start() {
        notifications.requestAuthorization()
        startWatchers()
        restartLoop()
    }

    /// Rafraîchit dès que les credentials de Claude Code ou de Codex changent sur disque.
    private func startWatchers() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let directories = [home.appendingPathComponent(".claude").path, home.appendingPathComponent(".codex").path]
        watchers = directories.compactMap { path in
            DirectoryWatcher(path: path) { [weak self] in
                Task { @MainActor in await self?.refresh(force: true) }
            }
        }
    }

    func refresh(force: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let now = Date()
        let due = providers.filter { kind, _ in
            guard settings.isEnabled(kind) else { return false }
            if force { return true }
            if let retry = retryAt[kind], retry > now { return false }
            return true
        }

        await withTaskGroup(of: (ProviderKind, Result<ProviderUsage, ProviderError>).self) { group in
            for (kind, provider) in due {
                group.addTask { (kind, await Self.fetch(provider)) }
            }
            for await (kind, result) in group {
                apply(result, to: kind)
            }
        }
        lastRefresh = Date()
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

    private func apply(_ result: Result<ProviderUsage, ProviderError>, to kind: ProviderKind) {
        switch result {
        case .success(let usage):
            states[kind] = .loaded(usage)
            retryAt[kind] = nil
            consecutiveRateLimits[kind] = 0
            notifications.evaluate(kind: kind, usage: usage, thresholds: settings.notificationThresholds)
        case .failure(let error):
            states[kind] = .failed(error, last: states[kind]?.usage)
            if case .rateLimited(let retryAfter) = error {
                let attempt = (consecutiveRateLimits[kind] ?? 0) + 1
                consecutiveRateLimits[kind] = attempt
                let base = Double(settings.refreshMinutes * 60)
                let delay = retryAfter ?? min(base * pow(2, Double(attempt)), 30 * 60)
                retryAt[kind] = Date().addingTimeInterval(delay)
            }
        }
    }

    private func restartLoop() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await refresh()
                try? await Task.sleep(for: settings.refreshInterval)
            }
        }
    }
}
