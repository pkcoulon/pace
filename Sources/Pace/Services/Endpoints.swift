import Foundation

enum Endpoints {
    // Claude — réutilisation du login Claude Code (OAuth)
    static let claudeOAuthUsage = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    static let anthropicBeta = "oauth-2025-04-20"

    // Claude — mode secours session key claude.ai
    static let claudeWebOrganizations = URL(string: "https://claude.ai/api/organizations")!
    static func claudeWebUsage(orgUUID: String) -> URL {
        URL(string: "https://claude.ai/api/organizations/\(orgUUID)/usage")!
    }

    // Codex (OpenAI)
    static let codexUsage = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    static let codexTokenRefresh = URL(string: "https://auth.openai.com/oauth/token")!
    static let codexClientID = "app_EMoamEEZ73f0CkXaXp7hrann"

    // Pages de statut (surveillance de panne)
    static let claudeStatus = URL(string: "https://status.claude.com/api/v2/summary.json")!
    static let codexStatus = URL(string: "https://status.openai.com/api/v2/summary.json")!
}

enum ISO8601 {
    nonisolated(unsafe) private static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) private static let withoutFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func date(from string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        return withFractional.date(from: string) ?? withoutFractional.date(from: string)
    }

    static func string(from date: Date) -> String {
        withFractional.string(from: date)
    }
}

enum PlanName {
    static func display(_ raw: String?) -> String? {
        guard let raw = raw?.lowercased(), !raw.isEmpty else { return nil }
        switch raw {
        case "max": return "Max"
        case "pro": return "Pro"
        case "prolite", "pro_lite": return "Pro"
        case "plus": return "Plus"
        case "team": return "Team"
        case "enterprise": return "Enterprise"
        case "free", "guest": return "Free"
        case "business": return "Business"
        default: return raw.prefix(1).uppercased() + raw.dropFirst()
        }
    }
}
