import Foundation

/// Persiste le dernier usage connu (données non secrètes) pour afficher quelque
/// chose immédiatement au lancement, avant le premier appel réseau. Jamais de
/// token ici : uniquement des pourcentages et des dates.
enum UsageCache {
    struct Snapshot: Codable {
        var usages: [ProviderID: ProviderUsage]
    }

    private static var fileURL: URL {
        AppSupport.directory.appendingPathComponent("usage-cache.json")
    }

    static func load() -> Snapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    static func save(_ snapshot: Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

enum AppSupport {
    static var directory: URL {
        let base = ProviderFactory.isMock ? nil : FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let dir = (base ?? FileManager.default.temporaryDirectory).appendingPathComponent("Pace", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
