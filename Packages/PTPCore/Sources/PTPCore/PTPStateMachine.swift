/// The raw values are stored on the watch and sent to the phone. Don't rename them.
public enum PTPState: String, Sendable, Equatable {
    case disarmed, armed, warning, alarm, lost
}

extension PTPState {
    /// An event that has run out disarms the watch only from Armed. A Warning or an Alarm is the owner's to end
    /// (ADR-0007 decision 4), so the end of the event waits for it.
    public var allowsAutoDisarm: Bool { self == .armed }

    /// The word to log when the state changes from `previous`: entering Alarm, or how an Alarm ended. Nil otherwise.
    public func alarmLogEntry(after previous: PTPState?) -> String? {
        self != previous && (self == .alarm || previous == .alarm) ? rawValue : nil
    }
}

public enum ArmMode: String, Sendable, Equatable {
    case normal, event
}

public enum OwnerAction: Sendable, Equatable {
    case arm(ArmMode), disarm, iHaveIt, markAsLost
}

/// Times are a `Duration` on one clock that never restarts while the machine is
/// armed. The caller stamps every sample on its own clock when it arrives,
/// never with the sending device's time: a future-dated sample reads as silence.
/// Arming starts a new time base, so the clock may restart between sessions.
public struct PTPStateMachine: Sendable {
    public private(set) var state: PTPState = .disarmed

    /// The over-threshold deadline shown as the Warning countdown. Signal loss can still raise the Alarm sooner.
    public var alarmDeadline: Duration? {
        guard state == .warning, let overSince else { return nil }
        return overSince + config.warningDelay + config.alarmDelay
    }

    /// True when the watch is Armed, has heard from the phone since arming, restarting or waking, and has no
    /// out-of-range verdict pending. Only then may the end of an event disarm it (ADR-0007 decision 9).
    public var canEndEvent: Bool {
        state == .armed && !awaitingFirstSignal && overSince == nil
    }

    private let config: DetectionConfig
    private var smoother: MedianSmoother
    // Signal strength of the heartbeat, used only while there is no fresh UWB distance (ADR-0009).
    private var signalSmoother: MedianSmoother
    private var lastDistance: Duration?
    // True when the current out-of-range verdict came from signal strength. Only then may a strong signal clear it.
    private var overFromSignal = false
    // After "I have it", a weak signal can't raise a new verdict until the signal has been strong once
    // or a distance arrives: a phone in a pocket would otherwise alarm again every few seconds.
    private var signalMuted = false
    private var threshold: Float
    private var latestTime: Duration = .zero
    private var lastSignal: Duration = .zero
    // A nil verdict from the smoother leaves this start time intact.
    private var overSince: Duration?
    // True from arming until the first sample: the link may still be starting up.
    private var awaitingFirstSignal = false
    // True from a suspension until the next sample: one allowance per silence.
    private var resumedSinceSignal = false

    public init(config: DetectionConfig) {
        self.config = config
        threshold = config.alertDistance
        smoother = MedianSmoother(window: config.smoothingWindow)
        signalSmoother = MedianSmoother(window: config.rssiWindow)
    }

    @discardableResult
    public mutating func handle(_ action: OwnerAction, at time: Duration) -> PTPState {
        // Arming starts a new time base; a session clock may restart from zero.
        latestTime = state == .disarmed ? time : max(latestTime, time)
        // A deadline that fell due before the tap is applied first, so the tap acts on the true state.
        advanceTimers(includingEndpoint: true)
        switch (state, action) {
        case (.disarmed, .arm(let mode)):
            threshold = mode == .event ? config.eventAlertDistance : config.alertDistance
            restartArmed()
            awaitingFirstSignal = true
        case (.warning, .iHaveIt), (.alarm, .iHaveIt):
            // No sample yet since arming, a restart or a suspension: the link may still be starting up.
            let linkStarting = awaitingFirstSignal
            restartArmed()
            awaitingFirstSignal = linkStarting
            signalMuted = true
        case (.alarm, .markAsLost):
            state = .lost
        case (_, .disarm) where state != .lost:
            state = .disarmed
        default:
            break
        }
        return state
    }

    private mutating func restartArmed() {
        smoother = MedianSmoother(window: config.smoothingWindow)
        signalSmoother = MedianSmoother(window: config.rssiWindow)
        lastDistance = nil
        overFromSignal = false
        signalMuted = false
        overSince = nil
        lastSignal = latestTime
        awaitingFirstSignal = false
        resumedSinceSignal = false
        state = .armed
    }

    @discardableResult
    public mutating func observe(_ sample: DistanceSample) -> PTPState {
        latestTime = max(latestTime, sample.time)
        guard state == .armed || state == .warning else { return state }

        // An arriving sample can satisfy a deadline exactly, but cannot undo
        // an alarm that fell due strictly before it arrived.
        advanceTimers(includingEndpoint: false)
        guard state != .alarm else { return state }
        lastSignal = latestTime
        awaitingFirstSignal = false
        resumedSinceSignal = false
        var reading = sample
        reading.time = latestTime
        let median = smoother.add(reading)
        // A heartbeat ages the window. Expiring an old reading alone must
        // not reverse the last range verdict while UWB is unavailable.
        if reading.meters?.isFinite == true, let distance = median {
            lastDistance = latestTime
            signalMuted = false
            if distance > threshold {
                overSince = overSince ?? latestTime
                overFromSignal = false
            } else {
                clearVerdict()
            }
        } else if let rssi = reading.rssi {
            // The smoother works on any number; here it holds dBm.
            let signal = signalSmoother.add(DistanceSample(meters: Float(rssi), source: .ble, time: latestTime))
            let distanceIsStale = lastDistance.map { latestTime - $0 > config.uwbFreshness } ?? true
            if distanceIsStale, let signal, signalSmoother.count >= config.rssiMinSamples {
                if signal > Float(config.nearRSSI) {
                    signalMuted = false
                    // A strong signal never clears a verdict that a distance raised:
                    // Bluetooth can stay strong well past the alert distance.
                    if overFromSignal { clearVerdict() }
                } else if signal < Float(config.farRSSI), !signalMuted, overSince == nil {
                    overSince = latestTime
                    overFromSignal = true
                }
                // Between the two levels the last verdict stands.
            }
        }
        advanceTimers(includingEndpoint: true)
        return state
    }

    private mutating func clearVerdict() {
        overSince = nil
        overFromSignal = false
        state = .armed
    }

    @discardableResult
    public mutating func tick(at time: Duration) -> PTPState {
        latestTime = max(latestTime, time)
        advanceTimers(includingEndpoint: true)
        return state
    }

    /// The app was not running for a while, so the silence proves nothing (ADR-0007 decision 7).
    /// The no-signal timer restarts with the link start-up allowance. The range verdict and its countdown stand.
    @discardableResult
    public mutating func resumeAfterSuspension(at time: Duration) -> PTPState {
        latestTime = max(latestTime, time)
        guard state == .armed || state == .warning else { return state }
        // One allowance per silence: gaps with no sample in between can't postpone the Alarm again.
        if !resumedSinceSignal {
            resumedSinceSignal = true
            lastSignal = latestTime
            awaitingFirstSignal = true
        }
        // Signal readings from before the gap must not decide anything now.
        signalSmoother = MedianSmoother(window: config.rssiWindow)
        advanceTimers(includingEndpoint: true)
        return state
    }

    /// Puts a new machine back in a latched state after the app restarts (ADR-0007 decision 8).
    /// An Alarm is restored only on an armed machine, so "I have it" returns to the right threshold.
    public mutating func restoreLatched(_ latched: PTPState) {
        guard latched == .lost || (latched == .alarm && state == .armed) else { return }
        state = latched
    }

    private mutating func advanceTimers(includingEndpoint: Bool) {
        guard state == .armed || state == .warning else { return }
        let now = latestTime
        func reached(_ deadline: Duration) -> Bool {
            includingEndpoint ? now >= deadline : now > deadline
        }

        let allowedSilence = awaitingFirstSignal ? config.linkStartupDelay : config.signalLossDelay
        if reached(lastSignal + allowedSilence) {
            state = .alarm
            // The allowance is spent: "I have it" after this gets the usual delay.
            awaitingFirstSignal = false
        } else if let overSince {
            // Use the logical Warning entry time even when ticks arrive late.
            let warningAt = overSince + config.warningDelay
            if reached(warningAt) {
                state = reached(warningAt + config.alarmDelay) ? .alarm : .warning
            }
        }
    }
}
