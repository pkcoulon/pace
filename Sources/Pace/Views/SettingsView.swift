import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var sessionKey = SecretStore.get(SecretAccount.claudeSessionKey) ?? ""
    @State private var testResult: TestResult?
    @State private var isTesting = false

    private enum TestResult {
        case success(String)
        case failure(String)
    }

    var body: some View {
        Form {
            Section("Providers") {
                Toggle("Claude", isOn: $settings.claudeEnabled)
                Toggle("Codex", isOn: $settings.codexEnabled)
            }

            Section("Barre de menu") {
                if settings.claudeEnabled {
                    Picker("Claude affiche", selection: $settings.claudeBar) {
                        ForEach(BarWindow.allCases) { Text($0.label).tag($0) }
                    }
                }
                if settings.codexEnabled {
                    Picker("Codex affiche", selection: $settings.codexBar) {
                        ForEach(BarWindow.allCases) { Text($0.label).tag($0) }
                    }
                }
                Toggle("Afficher le rythme dans le popover", isOn: $settings.showPacing)
            }

            Section("Rafraîchissement") {
                Picker("Intervalle", selection: $settings.refreshMinutes) {
                    ForEach(SettingsStore.refreshChoices, id: \.self) { Text("\($0) min").tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Notifications") {
                LabeledContent("Fenêtre 5 h") {
                    ThresholdPair(warning: $settings.fiveHourWarning, critical: $settings.fiveHourCritical)
                }
                LabeledContent("Fenêtre hebdo") {
                    ThresholdPair(warning: $settings.weeklyWarning, critical: $settings.weeklyCritical)
                }
            }

            Section("Général") {
                Toggle("Lancer au démarrage", isOn: $settings.launchAtLogin)
                    .disabled(!LaunchAtLogin.isAvailable)
                if let error = settings.launchAtLoginError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }

            Section {
                SecureField("sk-ant-sid…", text: $sessionKey)
                HStack {
                    Button("Enregistrer") {
                        settings.setClaudeSessionKey(sessionKey)
                        testResult = nil
                    }
                    Button {
                        runTest()
                    } label: {
                        if isTesting { ProgressView().controlSize(.small) } else { Text("Tester") }
                    }
                    .disabled(isTesting || sessionKey.trimmingCharacters(in: .whitespaces).count < 20)
                    Spacer()
                }
                if let testResult {
                    switch testResult {
                    case .success(let message):
                        Label(message, systemImage: "checkmark.circle.fill")
                            .font(.caption).foregroundStyle(.green)
                    case .failure(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .font(.caption).foregroundStyle(.red)
                    }
                }
            } header: {
                Text("Session key Claude (mode secours)")
            } footer: {
                Text("Utilisée seulement si Claude Code n'est pas connecté. Stockée dans le Trousseau.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func runTest() {
        isTesting = true
        testResult = nil
        let key = sessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            let result = await ClaudeUsageProvider.testSessionKey(key)
            await MainActor.run {
                isTesting = false
                switch result {
                case .success(let message): testResult = .success(message)
                case .failure(let error): testResult = .failure(error.message)
                }
            }
        }
    }
}

private struct ThresholdPair: View {
    @Binding var warning: Int
    @Binding var critical: Int

    var body: some View {
        HStack(spacing: 12) {
            Stepper("Alerte \(warning)\u{202F}%", value: $warning, in: 50...99, step: 5)
                .fixedSize()
            Stepper("Critique \(critical)\u{202F}%", value: $critical, in: 50...100, step: 5)
                .fixedSize()
        }
    }
}
