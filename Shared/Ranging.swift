import Foundation
import NearbyInteraction
import Observation

@MainActor
@Observable
final class Ranging: NSObject, NISessionDelegate {
    private(set) var distanceMeters: Float?
    private(set) var state = "Waiting to range…"
    var onChange: (@MainActor (String, Float?) -> Void)?
    var onSample: (@MainActor (Float?) -> Void)?

    private weak var exchange: TokenExchange?
    private var session: NISession?
    private var configuration: NINearbyPeerConfiguration?
    private var isSuspended = false

    func start(exchange: TokenExchange) {
        guard session == nil else { return }
        guard NISession.deviceCapabilities.supportsPreciseDistanceMeasurement else {
            setReading(state: "Nearby Interaction not available on this device", distance: nil)
            return
        }

        self.exchange = exchange
        exchange.onPeerToken = { [weak self] token in
            guard let self else { return }
            configuration = NINearbyPeerConfiguration(peerToken: token)
            runConfiguration()
        }
        startSession(exchange: exchange)
    }

    private func startSession(exchange: TokenExchange) {
        let session = NISession()
        session.delegate = self
        self.session = session
        guard let token = session.discoveryToken else {
            setReading(state: "Discovery token unavailable", distance: nil)
            return
        }
        exchange.publish(token)
        runConfiguration()
    }

    private func runConfiguration() {
        guard !isSuspended, let configuration else { return }
        session?.run(configuration)
    }

    private func setReading(state: String, distance: Float?) {
        onSample?(distance)
        guard state != self.state || distance != distanceMeters else { return }
        self.state = state
        distanceMeters = distance
        onChange?(state, distance)
    }

    nonisolated func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        let id = ObjectIdentifier(session)
        let distance = nearbyObjects.first?.distance
        Task { @MainActor in
            guard self.session.map(ObjectIdentifier.init) == id else { return }
            setReading(state: "Ranging", distance: distance)
        }
    }

    nonisolated func session(
        _ session: NISession, didRemove nearbyObjects: [NINearbyObject],
        reason: NINearbyObject.RemovalReason
    ) {
        let id = ObjectIdentifier(session)
        Task { @MainActor in
            guard self.session.map(ObjectIdentifier.init) == id else { return }
            switch reason {
            case .timeout:
                setReading(state: "Peer out of range", distance: nil)
                runConfiguration()
            case .peerEnded:
                setReading(state: "Peer ended session", distance: nil)
            @unknown default:
                setReading(state: "Peer removed", distance: nil)
            }
        }
    }

    nonisolated func sessionWasSuspended(_ session: NISession) {
        let id = ObjectIdentifier(session)
        Task { @MainActor in
            guard self.session.map(ObjectIdentifier.init) == id else { return }
            isSuspended = true
            setReading(state: "Suspended", distance: nil)
        }
    }

    nonisolated func sessionSuspensionEnded(_ session: NISession) {
        let id = ObjectIdentifier(session)
        Task { @MainActor in
            guard self.session.map(ObjectIdentifier.init) == id else { return }
            isSuspended = false
            runConfiguration()
        }
    }

    nonisolated func session(_ session: NISession, didInvalidateWith error: any Error) {
        let id = ObjectIdentifier(session)
        let code = (error as? NIError)?.code
        Task { @MainActor in
            guard self.session.map(ObjectIdentifier.init) == id else { return }
            self.session = nil
            isSuspended = false
            switch code {
            case .userDidNotAllow:
                setReading(state: "Nearby Interaction not allowed. Turn it on in Settings.", distance: nil)
            case .unsupportedPlatform:
                setReading(state: "Nearby Interaction not available on this device", distance: nil)
            case .invalidConfiguration:
                // The peer token was rejected: drop it and wait for a fresh one instead of rerunning it.
                configuration = nil
                setReading(state: "Waiting for a new peer token", distance: nil)
                if let exchange { startSession(exchange: exchange) }
            default:
                setReading(state: "Session ended", distance: nil)
                if let exchange { startSession(exchange: exchange) }
            }
        }
    }
}
