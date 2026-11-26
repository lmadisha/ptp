import Foundation

/// A state the watch reported, stamped with the watch's clock when it was sent (ADR-0013).
/// The application context and live messages travel separately, so the stamp decides which is newer.
public struct WatchReport: Sendable, Equatable {
    public let state: PTPState
    public let sentAt: Date

    public init(state: PTPState, sentAt: Date) {
        self.state = state
        self.sentAt = sentAt
    }

    /// A late report never overwrites a newer one.
    public func isNewer(than other: WatchReport?) -> Bool {
        guard let other else { return true }
        return sentAt > other.sentAt
    }

    /// Only a fresh Alarm sounds the siren; the caller passes only live messages, never the stored context.
    public func soundsSiren(at now: Date, config: DetectionConfig = .standard) -> Bool {
        state == .alarm && .seconds(now.timeIntervalSince(sentAt)) < config.sirenFreshness
    }
}
