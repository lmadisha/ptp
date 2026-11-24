import Accessibility
import Foundation
import Observation
import PTPCore
import WatchKit

@MainActor
@Observable
final class WatchSession {
    private static let armModeKey = "armMode"

    private let config = DetectionConfig.standard
    private var machine = PTPStateMachine(config: .standard)
    private let clock = ContinuousClock()
    private var armedAt: ContinuousClock.Instant?
    private var tickTask: Task<Void, Never>?
    private var alarmTask: Task<Void, Never>?

    private(set) var state: PTPState = .disarmed
    private(set) var distanceMeters: Float?
    private(set) var armMode: ArmMode?
    private(set) var secondsToAlarm: Int?
    var threshold: Float {
        armMode == .event ? config.eventAlertDistance : config.alertDistance
    }
    let keepAlive = KeepAlive()

    func arm(_ mode: ArmMode) {
        guard state == .disarmed else { return }
        armedAt = clock.now
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
                let elapsed = clock.now - armedAt
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
        let elapsed = clock.now - armedAt
        machine.observe(DistanceSample(meters: distance, source: source, time: elapsed))
        updateState(at: elapsed)
    }

    /// Lost is final for a session; this starts a new one.
    func reset() {
        guard state == .lost else { return }
        machine = PTPStateMachine(config: config)
        updateState(at: .zero)
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
        let elapsed = clock.now - armedAt
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
