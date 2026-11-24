import Accessibility
import Foundation
import Observation
import PTPCore
import WatchKit

@MainActor
@Observable
final class WatchSession {
    private static let armModeKey = "armMode"
    private static let latchedKey = "latchedState"

    private let config = DetectionConfig.standard
    private var machine = PTPStateMachine(config: .standard)
    private let clock = ContinuousClock()
    private var armedAt: ContinuousClock.Instant?
    private var tickTask: Task<Void, Never>?
    private var alarmTask: Task<Void, Never>?
    private var lastActive: Duration = .zero

    private(set) var state: PTPState = .disarmed
    private(set) var distanceMeters: Float?
    private(set) var armMode: ArmMode?
    private(set) var secondsToAlarm: Int?
    var threshold: Float {
        armMode == .event ? config.eventAlertDistance : config.alertDistance
    }
    let keepAlive = KeepAlive()
    var isUnprotected: Bool { armedAt != nil && keepAlive.mode == .off }

    init() {
        keepAlive.onEnd = { [weak self] wasRunning in self?.keepAliveEnded(wasRunning: wasRunning) }
    }

    func appBecameActive() {
        if isUnprotected { keepAlive.startRuntime() }
    }

    func arm(_ mode: ArmMode) {
        guard state == .disarmed else { return }
        armedAt = clock.now
        lastActive = .zero
        machine.handle(.arm(mode), at: .zero)
        armMode = mode
        updateState(at: .zero)
        UserDefaults.standard.set(mode == .event ? "event" : "normal", forKey: Self.armModeKey)
        // Extended runtime is provisional until Gate 0 picks the keep-alive mode (ADR-0004).
        keepAlive.startRuntime()

        tickTask = Task { [weak self, interval = config.tickInterval] in
            #if DEBUG
            // Simulator evidence only, because Nearby Interaction cannot run there.
            // Launch argument only (`-demoDistance 9`), so a stored value can't mask signal loss later.
            let arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
            let demoDistance = (arguments["demoDistance"] as? String).flatMap(Float.init)
            #endif
            // The link-loss watchdog runs on the watch without reading from the phone.
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled, let self, let armedAt else { return }
                #if DEBUG
                if let demoDistance {
                    observe(distance: demoDistance, source: .uwb)
                }
                #endif
                let elapsed = self.elapsed(since: armedAt)
                machine.tick(at: elapsed)
                updateState(at: elapsed)
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
        let elapsed = self.elapsed(since: armedAt)
        machine.observe(DistanceSample(meters: distance, source: source, time: elapsed))
        updateState(at: elapsed)
    }

    /// Lost is final for a session; this starts a new one.
    func reset() {
        guard state == .lost else { return }
        machine = PTPStateMachine(config: config)
        updateState(at: .zero)
        UserDefaults.standard.removeObject(forKey: Self.armModeKey)
    }

    func restore() {
        // Read first: arm() runs updateState, which clears the stored value.
        let latched = UserDefaults.standard.string(forKey: Self.latchedKey)
        if latched == "lost" {
            machine.restoreLatched(.lost)
            updateState(at: .zero)
            return
        }
        switch UserDefaults.standard.string(forKey: Self.armModeKey) {
        case "normal": arm(.normal)
        case "event": arm(.event)
        default: break
        }
        guard latched == "alarm" else { return }
        // Without a stored arm mode nothing was armed, and an Alarm with no session could never be dismissed.
        guard armedAt != nil else {
            UserDefaults.standard.removeObject(forKey: Self.latchedKey)
            return
        }
        machine.restoreLatched(.alarm)
        updateState(at: .zero)
    }

    private func keepAliveEnded(wasRunning: Bool) {
        guard armedAt != nil else { return }
        if wasRunning {
            keepAlive.startRuntime()
        } else {
            WKInterfaceDevice.current().play(.failure)
            AccessibilityNotification.Announcement("PTP is not protected. Open the app.").post()
        }
    }

    /// Time since arming. A long gap since the last call means the app was suspended.
    private func elapsed(since armedAt: ContinuousClock.Instant) -> Duration {
        let elapsed = clock.now - armedAt
        if elapsed - lastActive > config.suspensionGap {
            machine.resumeAfterSuspension(at: elapsed)
        }
        lastActive = elapsed
        return elapsed
    }

    private func handle(_ action: OwnerAction) {
        guard let armedAt else { return }
        let elapsed = self.elapsed(since: armedAt)
        machine.handle(action, at: elapsed)
        updateState(at: elapsed)
        guard state == .disarmed || state == .lost else { return }
        tickTask?.cancel()
        tickTask = nil
        keepAlive.stop()
        UserDefaults.standard.removeObject(forKey: Self.armModeKey)
        self.armedAt = nil
        armMode = nil
        distanceMeters = nil
    }

    private func updateState(at elapsed: Duration) {
        if let deadline = machine.alarmDeadline {
            let remaining = max(.zero, deadline - elapsed).components
            secondsToAlarm = Int(remaining.seconds) + (remaining.attoseconds > 0 ? 1 : 0)
        } else {
            secondsToAlarm = nil
        }

        guard state != machine.state else { return }
        state = machine.state
        let latched = state == .alarm ? "alarm" : state == .lost ? "lost" : nil
        if let latched {
            UserDefaults.standard.set(latched, forKey: Self.latchedKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.latchedKey)
        }
        if state != .alarm {
            alarmTask?.cancel()
            alarmTask = nil
        }
        switch state {
        case .warning:
            WKInterfaceDevice.current().play(.directionUp)
            AccessibilityNotification.Announcement("Warning").post()
        case .alarm:
            AccessibilityNotification.Announcement("Alarm").post()
            alarmTask = Task { [interval = config.alarmRepeatInterval] in
                while !Task.isCancelled {
                    WKInterfaceDevice.current().play(.notification)
                    try? await Task.sleep(for: interval)
                }
            }
        default:
            break
        }
    }
}
