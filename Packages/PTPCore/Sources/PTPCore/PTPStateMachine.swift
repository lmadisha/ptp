public enum PTPState: Sendable, Equatable {
    case disarmed, armed, warning, alarm, lost
}

public enum ArmMode: Sendable, Equatable {
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

    private let config: DetectionConfig
    private var smoother: MedianSmoother
    private var threshold: Float
    private var latestTime: Duration = .zero
    private var lastSignal: Duration = .zero
    // A nil verdict from the smoother leaves this start time intact.
    private var overSince: Duration?
    // True from arming until the first sample: the link may still be starting up.
    private var awaitingFirstSignal = false

    public init(config: DetectionConfig) {
        self.config = config
        threshold = config.alertDistance
        smoother = MedianSmoother(window: config.smoothingWindow)
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
        case (.alarm, .iHaveIt):
            restartArmed()
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
        overSince = nil
        lastSignal = latestTime
        awaitingFirstSignal = false
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
        var reading = sample
        reading.time = latestTime
        let median = smoother.add(reading)
        // A heartbeat ages the window. Expiring an old reading alone must
        // not reverse the last range verdict while UWB is unavailable.
        if reading.meters?.isFinite == true, let distance = median {
            if distance > threshold {
                overSince = overSince ?? latestTime
            } else {
                overSince = nil
                state = .armed
            }
        }
        advanceTimers(includingEndpoint: true)
        return state
    }

    @discardableResult
    public mutating func tick(at time: Duration) -> PTPState {
        latestTime = max(latestTime, time)
        advanceTimers(includingEndpoint: true)
        return state
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
        } else if let overSince {
            // Use the logical Warning entry time even when ticks arrive late.
            let warningAt = overSince + config.warningDelay
            if reached(warningAt) {
                state = reached(warningAt + config.alarmDelay) ? .alarm : .warning
            }
        }
    }
}
