import Foundation
import Observation
import PTPCore

@MainActor
@Observable
final class WatchSession {
    private static let armModeKey = "armMode"

    private let config = DetectionConfig.standard
    private var machine = PTPStateMachine(config: .standard)
    private let clock = ContinuousClock()
    private var armedAt: ContinuousClock.Instant?
    private var tickTask: Task<Void, Never>?

    private(set) var state: PTPState = .disarmed
    private(set) var distanceMeters: Float?
    private(set) var armMode: ArmMode?
    let keepAlive = KeepAlive()

    func arm(_ mode: ArmMode) {
        guard state == .disarmed else { return }
        armedAt = clock.now
        state = machine.handle(.arm(mode), at: .zero)
        armMode = mode
        UserDefaults.standard.set(mode == .event ? "event" : "normal", forKey: Self.armModeKey)
        // Extended runtime is provisional until Gate 0 picks the keep-alive mode (ADR-0004).
        keepAlive.startRuntime()

        tickTask = Task { [weak self, interval = config.tickInterval] in
            // The link-loss watchdog runs on the watch without reading from the phone.
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled, let self, let armedAt else { return }
                state = machine.tick(at: clock.now - armedAt)
            }
        }
    }

    func disarm() {
        handle(.disarm)
    }

    func iHaveIt() {
        handle(.iHaveIt)
    }

    func markAsLost() {
        handle(.markAsLost)
    }

    func observe(distance: Float?, source: ReadingSource) {
        guard let armedAt else { return }
        if source == .uwb { distanceMeters = distance }
        // Ranging also reports "no reading" (peer out of range, suspended). That is not a signal.
        guard source == .ble || distance != nil else { return }
        state = machine.observe(DistanceSample(meters: distance, source: source, time: clock.now - armedAt))
    }

    /// Lost is final for a session; this starts a new one.
    func reset() {
        guard state == .lost else { return }
        machine = PTPStateMachine(config: config)
        state = .disarmed
    }

    func restore() {
        switch UserDefaults.standard.string(forKey: Self.armModeKey) {
        case "normal": arm(.normal)
        case "event": arm(.event)
        default: break
        }
    }

    private func handle(_ action: OwnerAction) {
        guard let armedAt else { return }
        state = machine.handle(action, at: clock.now - armedAt)
        guard state == .disarmed || state == .lost else { return }
        tickTask?.cancel()
        tickTask = nil
        keepAlive.stop()
        UserDefaults.standard.removeObject(forKey: Self.armModeKey)
        self.armedAt = nil
        armMode = nil
        distanceMeters = nil
    }
}
