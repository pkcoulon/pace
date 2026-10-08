import SwiftUI

struct ConnectorsSettingsTab: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: UsageStore
    @State private var detected: Set<ProviderID> = []
    @State private var storedKeys: Set<String> = []
    @State private var showsClaudeFallback = false

    private static let apiKeys: [ProviderID: (account: String, prompt: String, footnote: String)] = [
        .zai: (
            SecretAccount.zaiAPIKey,
            String(localized: "z.ai API key"),
            String(localized: "Optional if Claude Code already points to z.ai: Pace then reads its key.")
        ),
        .openRouter: (
            SecretAccount.openRouterAPIKey,
            "sk-or-…",
            String(localized: "Create a key at openrouter.ai/keys. With a spending limit, Pace shows a gauge.")
        ),
    ]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Form {
                ForEach(ProviderRegistry.all) { provider in
                    Section {
                        ConnectorRow(
                            provider: provider,
                            status: status(for: provider, now: context.date),
                            outage: store.statuses[provider.id].flatMap { $0.level.isProblem ? $0 : nil },
                            isOn: Binding(
                                get: { settings.isEnabled(provider.id) },
                                set: { settings.setEnabled(provider.id, $0) }
                            )
                        )
                        if settings.isEnabled(provider.id) {
                            credentials(for: provider)
                        }
                    } footer: {
                        if provider.id == ProviderRegistry.all.last?.id {
                            Text("Pace reuses the sign-ins already on your Mac, read-only. Keys pasted here stay in the Keychain.")
                        }
                    }
                }
            }
            .settingsPane(height: 560)
        }
        .onAppear {
            refreshCredentials()
            if case .notConfigured? = store.states[.claude]?.error { showsClaudeFallback = true }
            if settings.hasClaudeSessionKey { showsClaudeFallback = true }
        }
    }

    @ViewBuilder
    private func credentials(for provider: ProviderDescriptor) -> some View {
        if provider.id == .claude {
            DisclosureGroup(isExpanded: $showsClaudeFallback) {
                SecretKeyEditor(
                    prompt: "sk-ant-sid…",
                    footnote: String(localized: "Only used when Claude Code isn't signed in."),
                    isStored: settings.hasClaudeSessionKey,
                    save: { key in
                        settings.setClaudeSessionKey(key ?? "")
                        refreshCredentials()
                    },
                    test: { typed in
                        let key = typed.isEmpty ? SecretStore.get(SecretAccount.claudeSessionKey) ?? "" : typed
                        return await ClaudeUsageProvider.testSessionKey(key)
                    }
                )
                .padding(.vertical, 4)
            } label: {
                Label("Fallback: claude.ai session key", systemImage: "key")
            }
        } else if let key = Self.apiKeys[provider.id] {
            SecretKeyEditor(
                prompt: key.prompt,
                footnote: key.footnote,
                isStored: storedKeys.contains(key.account),
                save: { value in
                    SecretStore.set(value, account: key.account)
                    refreshCredentials()
                    Task { await store.refresh(provider.id) }
                }
            )
            .padding(.vertical, 4)
        }
    }

    private func refreshCredentials() {
        detected = Set(ProviderRegistry.all.filter { $0.isDetected() }.map(\.id))
        storedKeys = Set(Self.apiKeys.values.map(\.account).filter { SecretStore.get($0) != nil })
    }

    private func status(for provider: ProviderDescriptor, now: Date) -> ConnectorStatus {
        let id = provider.id
        guard settings.isEnabled(id) else {
            return detected.contains(id)
                ? ConnectorStatus(text: String(localized: "Detected, disabled"), icon: "circle", tint: .secondary)
                : ConnectorStatus(text: String(localized: "Not detected — \(provider.setupHint)"), icon: "circle.dashed", tint: .secondary)
        }
        let state = store.states[id] ?? .idle
        if let error = state.error {
            return error.isAuthFailure
                ? ConnectorStatus(text: error.message, icon: "xmark.circle.fill", tint: .red, isProblem: true)
                : ConnectorStatus(text: error.message, icon: "exclamationmark.triangle.fill", tint: .orange, isProblem: true)
        }
        guard let usage = state.usage else {
            return ConnectorStatus(text: String(localized: "Connecting…"), icon: "circle.dotted", tint: .secondary)
        }
        if store.isStale(id, now: now) {
            let age = UsageFormat.duration(now.timeIntervalSince(usage.fetchedAt))
            return ConnectorStatus(text: String(localized: "No update for \(age)"), icon: "clock.badge.exclamationmark", tint: .orange, isProblem: true)
        }
        let parts = [String(localized: "Connected"), usage.source, usage.plan].compactMap { $0 }
        return ConnectorStatus(text: parts.joined(separator: " · "), icon: "checkmark.circle.fill", tint: .green)
    }
}

private struct ConnectorStatus {
    var text: String
    var icon: String
    var tint: Color
    var isProblem = false
}

private struct ConnectorRow: View {
    let provider: ProviderDescriptor
    let status: ConnectorStatus
    let outage: ProviderStatus?
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            ProviderMonogram(provider: provider, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .font(.body.weight(.medium))
                Label {
                    Text(markdown(status.text))
                        .foregroundStyle(status.isProblem ? status.tint : .secondary)
                } icon: {
                    Image(systemName: status.icon)
                        .foregroundStyle(status.tint)
                }
                .font(.caption)
                .lineLimit(2)
                if let outage {
                    Label(outage.level.label + (outage.detail.map { " · \($0)" } ?? ""), systemImage: outage.level.icon)
                        .font(.caption)
                        .foregroundStyle(outage.level.color)
                }
            }
            Spacer(minLength: 8)
            Toggle(provider.displayName, isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }

    private func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

private struct SecretKeyEditor: View {
    let prompt: String
    let footnote: String
    let isStored: Bool
    let save: (String?) -> Void
    var test: ((String) async -> Result<String, ProviderError>)?

    @State private var key = ""
    @State private var result: Result<String, ProviderError>?
    @State private var isTesting = false

    private var trimmed: String {
        key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SecureField("Key", text: $key, prompt: isStored ? Text("Saved, paste a key to replace it") : Text(prompt))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(commit)
                Button("Save", action: commit)
                    .disabled(trimmed.isEmpty)
            }
            HStack(spacing: 8) {
                feedback
                Spacer(minLength: 8)
                if let test {
                    Button {
                        run(test)
                    } label: {
                        if isTesting { ProgressView().controlSize(.mini) } else { Text("Test") }
                    }
                    .disabled(isTesting || (trimmed.count < 20 && !isStored))
                }
                if isStored {
                    Button("Delete", role: .destructive) {
                        key = ""
                        result = nil
                        save(nil)
                    }
                }
            }
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var feedback: some View {
        switch result {
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failure(let error):
            Label(error.message, systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        case nil:
            if isStored {
                Label("Saved in the Keychain", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func commit() {
        guard !trimmed.isEmpty else { return }
        save(trimmed)
        key = ""
        result = nil
    }

    private func run(_ test: @escaping (String) async -> Result<String, ProviderError>) {
        isTesting = true
        result = nil
        let candidate = trimmed
        Task {
            let outcome = await test(candidate)
            isTesting = false
            result = outcome
        }
    }
}
