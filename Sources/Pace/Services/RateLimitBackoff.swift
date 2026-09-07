import Foundation

/// Backoff sur 429. L'endpoint d'usage Claude limite dur et renvoie souvent
/// `Retry-After: 0`, au point de bloquer des heures. On honore un Retry-After
/// positif, sinon on suit une échelle 30 min → 1 h → 2 h → 4 h → 6 h.
enum RateLimitBackoff {
    static let ladder: [TimeInterval] = [30 * 60, 60 * 60, 2 * 3600, 4 * 3600, 6 * 3600]

    static func delay(attempt: Int, serverRetryAfter: TimeInterval?) -> TimeInterval {
        if let retry = serverRetryAfter, retry > 0 { return retry }
        let index = min(max(attempt - 1, 0), ladder.count - 1)
        return ladder[index]
    }
}
