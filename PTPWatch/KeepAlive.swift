import Foundation
import HealthKit
import Observation
import WatchKit

@MainActor
@Observable
final class KeepAlive: NSObject {
    enum Mode { case off, extendedRuntime, workout }

    private(set) var mode: Mode = .off
    private(set) var state = "Keep alive off"
    private(set) var startedAt: Date?

    private let healthStore = HKHealthStore()
    private var runtimeSession: WKExtendedRuntimeSession?
    private var workoutSession: HKWorkoutSession?
    private var authorizationRequest: UUID?
    private var isStoppingWorkout = false

    func startRuntime() {
        guard mode == .off else { return }

        let session = WKExtendedRuntimeSession()
        session.delegate = self
        runtimeSession = session
        mode = .extendedRuntime
        state = "Starting runtime…"
        session.start()
    }

    func startWorkout() async {
        guard mode == .off else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            state = "HealthKit unavailable"
            return
        }

        let request = UUID()
        authorizationRequest = request
        mode = .workout
        state = "Requesting workout authorization…"

        do {
            let workoutType = HKObjectType.workoutType()
            try await healthStore.requestAuthorization(toShare: [workoutType], read: [])
            guard authorizationRequest == request else { return }
            guard healthStore.authorizationStatus(for: workoutType) == .sharingAuthorized else {
                finish("Workout authorization denied")
                return
            }

            let configuration = HKWorkoutConfiguration()
            configuration.activityType = .other
            configuration.locationType = .unknown
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            session.delegate = self
            authorizationRequest = nil
            workoutSession = session
            state = "Starting workout…"
            session.startActivity(with: .now)
        } catch {
            guard authorizationRequest == request else { return }
            finish("Workout could not start: \(error.localizedDescription)")
        }
    }

    func stop() {
        switch mode {
        case .off:
            break
        case .extendedRuntime:
            runtimeSession?.invalidate()
            finish("Runtime stopped")
        case .workout:
            guard let workoutSession else {
                finish("Workout start cancelled")
                return
            }
            guard !isStoppingWorkout else { return }
            isStoppingWorkout = true
            state = "Stopping workout…"
            startedAt = nil
            // HealthKit can end the session once startup has reached an active state.
            if workoutSession.state != .notStarted && workoutSession.state != .prepared {
                workoutSession.end()
            }
        }
    }

    private func finish(_ message: String) {
        runtimeSession = nil
        workoutSession = nil
        authorizationRequest = nil
        isStoppingWorkout = false
        startedAt = nil
        mode = .off
        state = message
    }
}

extension KeepAlive: WKExtendedRuntimeSessionDelegate {
    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        let id = ObjectIdentifier(extendedRuntimeSession)
        let date = Date.now
        Task { @MainActor in
            guard runtimeSession.map(ObjectIdentifier.init) == id else { return }
            state = "Runtime running"
            startedAt = date
        }
    }

    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        let id = ObjectIdentifier(extendedRuntimeSession)
        Task { @MainActor in
            guard runtimeSession.map(ObjectIdentifier.init) == id else { return }
            state = "Runtime will expire"
        }
    }

    nonisolated func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: (any Error)?
    ) {
        let id = ObjectIdentifier(extendedRuntimeSession)
        let detail = error?.localizedDescription
        Task { @MainActor in
            guard runtimeSession.map(ObjectIdentifier.init) == id else { return }
            switch reason {
            case .none:
                finish("Runtime ended")
            case .expired:
                finish("Runtime expired")
            case .sessionInProgress:
                finish("Runtime ended: another session is in progress")
            case .resignedFrontmost:
                finish("Runtime ended: app lost frontmost status")
            case .suppressedBySystem:
                finish("Runtime ended: suppressed by the system")
            case .error:
                finish("Runtime ended: \(detail ?? "unknown error")")
            @unknown default:
                finish("Runtime ended: reason \(reason.rawValue)")
            }
        }
    }
}

extension KeepAlive: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from _: HKWorkoutSessionState,
        date: Date
    ) {
        let id = ObjectIdentifier(workoutSession)
        Task { @MainActor in
            guard let session = self.workoutSession, ObjectIdentifier(session) == id else { return }
            switch toState {
            case .running, .paused:
                if isStoppingWorkout {
                    session.end()
                } else if toState == .running {
                    state = "Workout running"
                    startedAt = session.startDate ?? date
                } else {
                    state = "Workout paused"
                    startedAt = nil
                }
            case .stopped:
                session.end()
                state = "Stopping workout…"
                startedAt = nil
            case .ended:
                finish(isStoppingWorkout ? "Workout ended: stopped" : "Workout ended")
            case .notStarted, .prepared:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        let id = ObjectIdentifier(workoutSession)
        let detail = error.localizedDescription
        Task { @MainActor in
            guard self.workoutSession.map(ObjectIdentifier.init) == id else { return }
            finish("Workout ended: \(detail)")
        }
    }
}
