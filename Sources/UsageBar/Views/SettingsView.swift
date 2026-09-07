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
                Picker("Chiffres affichés", selection: $settings.menuBarMode) {
                    ForEach(MenuBarMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }
            Section("Rafraîchissement") {
                Picker("Intervalle", selection: $settings.refreshMinutes) {
                    ForEach(SettingsStore.refreshChoices, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section("Notifications") {
                Stepper("Alerte à \(settings.warningThreshold)\u{202F}%", value: $settings.warningThreshold, in: 50...99, step: 5)
                Stepper("Alerte critique à \(settings.criticalThreshold)\u{202F}%", value: $settings.criticalThreshold, in: 50...100, step: 5)
            }
            Section("Général") {
                Toggle("Lancer au démarrage", isOn: $settings.launchAtLogin)
                    .disabled(!LaunchAtLogin.isAvailable)
                if let error = settings.launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
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
        .frame(width: 420)
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
