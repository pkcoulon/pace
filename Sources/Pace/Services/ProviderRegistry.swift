import SwiftUI

struct StatusPage: Sendable {
    let summaryURL: URL
    let componentMatchers: [String]
}

struct ProviderDescriptor: Sendable, Identifiable {
    let id: ProviderID
    let displayName: String
    let glyph: String
    let accent: Color
    let usagePageURL: URL
    let statusPage: StatusPage?
    let setupHint: String
    let isDetected: @Sendable () -> Bool
    let makeProvider: @Sendable () -> any UsageProvider
}

extension ProviderID {
    static let copilot = ProviderID(rawValue: "copilot")
    static let cursor = ProviderID(rawValue: "cursor")
    static let zai = ProviderID(rawValue: "zai")
    static let openRouter = ProviderID(rawValue: "openrouter")
}

enum ProviderRegistry {
    static let all: [ProviderDescriptor] = [
        ProviderDescriptor(
            id: .claude,
            displayName: "Claude",
            glyph: "C",
            accent: Color(red: 217 / 255, green: 119 / 255, blue: 87 / 255),
            usagePageURL: URL(string: "https://claude.ai/settings/usage")!,
            statusPage: StatusPage(summaryURL: Endpoints.claudeStatus, componentMatchers: ["claude", "anthropic"]),
            setupHint: String(localized: "Run `claude` or add a session key"),
            isDetected: {
                let home = FileManager.default.homeDirectoryForCurrentUser
                return FileManager.default.fileExists(atPath: home.appendingPathComponent(".claude").path)
                    || SecretStore.get(SecretAccount.claudeSessionKey) != nil
            },
            makeProvider: { ClaudeUsageProvider() }
        ),
        ProviderDescriptor(
            id: .codex,
            displayName: "Codex",
            glyph: "X",
            accent: Color(red: 16 / 255, green: 163 / 255, blue: 127 / 255),
            usagePageURL: URL(string: "https://chatgpt.com/#settings/Usage")!,
            statusPage: StatusPage(summaryURL: Endpoints.codexStatus, componentMatchers: ["chatgpt", "codex"]),
            setupHint: String(localized: "Run `codex login`"),
            isDetected: { CodexAuth.fileExists() },
            makeProvider: { CodexUsageProvider() }
        ),
        ProviderDescriptor(
            id: .copilot,
            displayName: "Copilot",
            glyph: "G",
            accent: Color(red: 137 / 255, green: 87 / 255, blue: 229 / 255),
            usagePageURL: URL(string: "https://github.com/settings/copilot")!,
            statusPage: StatusPage(summaryURL: Endpoints.copilotStatus, componentMatchers: ["copilot"]),
            setupHint: String(localized: "Run `gh auth login` or sign in to Copilot in your editor"),
            isDetected: { CopilotTokenReader.hasEditorConfig() },
            makeProvider: { CopilotUsageProvider() }
        ),
        ProviderDescriptor(
            id: .cursor,
            displayName: "Cursor",
            glyph: "U",
            accent: .primary,
            usagePageURL: URL(string: "https://cursor.com/dashboard?tab=usage")!,
            statusPage: StatusPage(summaryURL: Endpoints.cursorStatus, componentMatchers: ["ide", "cli", "cloud agents"]),
            setupHint: String(localized: "Sign in to the Cursor app"),
            isDetected: { CursorTokenReader.dbExists() },
            makeProvider: { CursorUsageProvider() }
        ),
        ProviderDescriptor(
            id: .zai,
            displayName: "z.ai",
            glyph: "Z",
            accent: Color(red: 232 / 255, green: 90 / 255, blue: 106 / 255),
            usagePageURL: URL(string: "https://z.ai/manage-apikey/coding-plan/personal/my-plan")!,
            statusPage: nil,
            setupHint: String(localized: "Paste your z.ai API key"),
            isDetected: { ZaiCredentialReader.isAvailable() },
            makeProvider: { ZaiUsageProvider() }
        ),
        ProviderDescriptor(
            id: .openRouter,
            displayName: "OpenRouter",
            glyph: "O",
            accent: Color(red: 100 / 255, green: 103 / 255, blue: 242 / 255),
            usagePageURL: URL(string: "https://openrouter.ai/settings/credits")!,
            statusPage: nil,
            setupHint: String(localized: "Paste a key from openrouter.ai/keys"),
            isDetected: { OpenRouterUsageProvider.hasKey() },
            makeProvider: { OpenRouterUsageProvider() }
        ),
    ]

    static func descriptor(for id: ProviderID) -> ProviderDescriptor? {
        all.first { $0.id == id }
    }
}
