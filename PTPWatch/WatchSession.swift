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
    private static let eventEndKey = "eventEndsAt"

    private let config = DetectionConfig.standard
    private var machine = PTPStateMachine(config: .standard)
    private let clock = ContinuousClock()
    private var armedAt: ContinuousClock.Instant?
    private var tickTask: Task<Void, Never>?
    private var alarmTask: Task<Void, Never>?
    private var lastActive: Duration = .zero

    private(set) var state: PTPState = .disarmed
    /// Called on every state change, also in the background where SwiftUI may not update.
    var onStateChange: ((PTPState) -> Void)?
    private(set) var distanceMeters: Float?
    /// The heartbeat's signal strength in dBm, shown when there is no distance.
    private(set) var rssi: Int?
    private(set) var armMode: ArmMode?
    private var restored = false
    /// When the running event ends. Wall-clock time, so it survives a restart of the app.
    private(set) var eventEndsAt: Date?
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

    /// Arms in Event mode until `duration` from now. Only the lengths the watch itself offers are accepted,
    /// so a request from the phone can't ask for anything else.
    func armEvent(for duration: Duration) {
        guard state == .disarmed, config.eventDurations.contains(duration) else { return }
        let end = Date.now.addingTimeInterval(TimeInterval(duration.components.seconds))
        UserDefaults.standard.set(end.timeIntervalSince1970, forKey: Self.eventEndKey)
        eventEndsAt = end
        arm(.event)
    }

    func arm(_ mode: ArmMode) {
        guard state == .disarmed else { return }
        armedAt = clock.now
        lastActive = .zero
        machine.handle(.arm(mode), at: .zero)
        armMode = mode
        updateState(at: .zero)
        UserDefaults.standard.set(mode.rawValue, forKey: Self.armModeKey)
        // Extended runtime is provisional until Gate 0 picks the keep-alive mode (ADR-0004).
        keepAlive.startRuntime()

        tickTask = Task { [weak self, interval = config.tickInterval] in
            #if DEBUG
            // Simulator evidence only, because Nearby Interaction cannot run there.
            // Launch argument only (`-demoDistance 9`), so a stored value can't mask signal loss later.
            let arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
            let demoDistance = (arguments["demoDistance"] as? String).flatMap(Float.init)
            // Pass the magnitude (`-demoRSSI 90` is -90 dBm): a value starting with "-" reads as the next argument.
            let demoRSSI = (arguments["demoRSSI"] as? String).flatMap(Int.init).map { -abs($0) }
            #endif
            // The link-loss watchdog runs on the watch without reading from the phone.
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled, let self, let armedAt else { return }
                #if DEBUG
                if let demoDistance {
                    observe(distance: demoDistance, source: .uwb)
                } else if let demoRSSI {
                    observe(distance: nil, source: .ble, rssi: demoRSSI)
                }
                #endif
                let elapsed = self.elapsed(since: armedAt)
                machine.tick(at: elapsed)
                updateState(at: elapsed)
                if eventShouldEnd(at: .now) {
                    disarm()
                    // Protection ending is worth a tap: the owner may not be looking.
                    WKInterfaceDevice.current().play(.stop)
                    AccessibilityNotification.Announcement("Event ended. PTP is disarmed.").post()
                    return
                }
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

    func observe(distance: Float?, source: ReadingSource, rssi: Int? = nil) {
        guard let armedAt else { return }
        if source == .uwb { distanceMeters = distance } else { self.rssi = rssi }
        // Ranging also reports "no reading" (peer out of range, suspended). That is not a signal.
        guard source == .ble || distance != nil else { return }
        let elapsed = self.elapsed(since: armedAt)
        machine.observe(DistanceSample(meters: distance, source: source, time: elapsed, rssi: rssi))
        updateState(at: elapsed)
    }

    /// Lost is final for a session; this starts a new one.
    func reset() {
        guard state == .lost else { return }
        machine = PTPStateMachine(config: config)
        updateState(at: .zero)
        UserDefaults.standard.removeObject(forKey: Self.armModeKey)
    }

    /// Runs once per launch: the view and a notification action (`NewAreaPrompt`) both call it, in either order.
    func restore() {
        guard !restored else { return }
        restored = true
        // Read first: arm() runs updateState, which clears the stored value.
        let latched = UserDefaults.standard.string(forKey: Self.latchedKey)
        if latched == "lost" {
            machine.restoreLatched(.lost)
            updateState(at: .zero)
            return
        }
        if let mode = UserDefaults.standard.string(forKey: Self.armModeKey).flatMap(ArmMode.init(rawValue:)) {
            // Zero means no event: `double(forKey:)` also reads the value from a launch argument.
            let end = UserDefaults.standard.double(forKey: Self.eventEndKey)
            eventEndsAt = end > 0 ? Date(timeIntervalSince1970: end) : nil
            // An event that ran out long ago while the app was closed is over, unless an Alarm is still waiting
            // for the owner. One that ran out just now is armed again, so the link is checked before it ends.
            if let eventEndsAt, Date.now.timeIntervalSince(eventEndsAt) > eventEndGrace, latched != "alarm" {
                endSession()
            } else {
                arm(mode)
            }
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
        endSession()
    }

    private var eventEndGrace: TimeInterval {
        TimeInterval(config.eventEndGrace.components.seconds)
    }

    /// Soon after the end, the watch first confirms the phone is still there (ADR-0007 decision 9).
    /// Long after, it disarms from Armed without asking.
    private func eventShouldEnd(at now: Date) -> Bool {
        guard let eventEndsAt, eventEndsAt <= now else { return false }
        return now.timeIntervalSince(eventEndsAt) > eventEndGrace ? state.allowsAutoDisarm : machine.canEndEvent
    }

    private func endSession() {
        tickTask?.cancel()
        tickTask = nil
        keepAlive.stop()
        UserDefaults.standard.removeObject(forKey: Self.armModeKey)
        UserDefaults.standard.removeObject(forKey: Self.eventEndKey)
        armedAt = nil
        armMode = nil
        eventEndsAt = nil
        distanceMeters = nil
        rssi = nil
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
        onStateChange?(state)
        if state == .alarm || state == .lost {
            UserDefaults.standard.set(state.rawValue, forKey: Self.latchedKey)
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
