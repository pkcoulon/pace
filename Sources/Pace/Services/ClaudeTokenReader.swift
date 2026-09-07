import Foundation
import Security
import OSLog

struct ClaudeOAuthCredential: Sendable {
    let accessToken: String
    let subscriptionType: String?
}

/// Lit le token OAuth déposé par Claude Code, sans jamais déclencher de prompt.
/// Ordre : SecItemCopyMatching silencieux → `/usr/bin/security` (watchdog 3 s)
/// → `~/.claude/.credentials.json`. Aucun token n'est loggé.
enum ClaudeTokenReader {
    static let service = "Claude Code-credentials"
    private static let logger = Logger(subsystem: "com.pierrickcoulon.Pace", category: "claude-token")

    /// Ordre choisi pour ne JAMAIS déclencher de dialogue d'accès au Trousseau :
    /// l'ACL de l'entrée `Claude Code-credentials` n'autorise que `/usr/bin/security`
    /// (binaire Apple), donc on passe par lui d'abord ; puis le fichier ; et en
    /// dernier recours `SecItemCopyMatching` en mode silencieux, qui échoue sans
    /// prompt plutôt que d'afficher le dialogue d'ACL.
    static func read() -> ClaudeOAuthCredential? {
        fromSecurityCLI() ?? fromCredentialsFile() ?? fromKeychainAPI()
    }

    private static func fromKeychainAPI() -> ClaudeOAuthCredential? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUISkip,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return parse(data)
    }

    private static func fromSecurityCLI() -> ClaudeOAuthCredential? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        task.arguments = ["find-generic-password", "-s", service, "-w"]
        let stdout = Pipe()
        task.standardOutput = stdout
        task.standardError = Pipe()
        do {
            try task.run()
        } catch {
            return nil
        }
        // Watchdog : sur macOS récent, `security` lancé depuis une app LSUIElement
        // peut se bloquer sur l'autorisation Keychain. On attend sur un thread de fond.
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            task.waitUntilExit()
            done.signal()
        }
        if done.wait(timeout: .now() + 3) == .timedOut {
            task.terminate()
            logger.info("security read timed out")
            return nil
        }
        guard task.terminationStatus == 0 else { return nil }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return parse(data)
    }

    private static func fromCredentialsFile() -> ClaudeOAuthCredential? {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
        guard let data = try? Data(contentsOf: path) else { return nil }
        return parse(data)
    }

    private static func parse(_ data: Data) -> ClaudeOAuthCredential? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = obj["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String,
              !token.isEmpty else {
            return nil
        }
        return ClaudeOAuthCredential(accessToken: token, subscriptionType: oauth["subscriptionType"] as? String)
    }
}

/// Version de Claude Code installée, pour le User-Agent `claude-code/x.y.z`.
enum ClaudeCodeVersion {
    static func detect() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let versionsDir = home.appendingPathComponent(".local/share/claude/versions")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: versionsDir.path)) ?? []
        let highest = names
            .filter { $0.first?.isNumber ?? false }
            .max { $0.compare($1, options: .numeric) == .orderedAscending }
        return highest ?? "0.0.0"
    }
}
