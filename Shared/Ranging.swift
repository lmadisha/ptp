import Foundation
import NearbyInteraction
import Observation

@MainActor
@Observable
final class Ranging: NSObject, NISessionDelegate {
    private(set) var distanceMeters: Float?
    private(set) var state = "Waiting to range…"

    private weak var exchange: TokenExchange?
    private var session: NISession?
    private var configuration: NINearbyPeerConfiguration?
    private var isSuspended = false

    func start(exchange: TokenExchange) {
        guard session == nil else { return }
        guard NISession.deviceCapabilities.supportsPreciseDistanceMeasurement else {
            state = "Nearby Interaction not available on this device"
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
            state = "Discovery token unavailable"
            return
        }
        exchange.publish(token)
        runConfiguration()
    }

    private func runConfiguration() {
        guard !isSuspended, let configuration else { return }
        session?.run(configuration)
    }

    nonisolated func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        let id = ObjectIdentifier(session)
        let distance = nearbyObjects.first?.distance
        Task { @MainActor in
            guard self.session.map(ObjectIdentifier.init) == id else { return }
            distanceMeters = distance
            state = "Ranging"
        }
    }

    nonisolated func session(
        _ session: NISession, didRemove nearbyObjects: [NINearbyObject],
        reason: NINearbyObject.RemovalReason
    ) {
        let id = ObjectIdentifier(session)
        Task { @MainActor in
            guard self.session.map(ObjectIdentifier.init) == id else { return }
            distanceMeters = nil
            switch reason {
            case .timeout:
                state = "Peer out of range"
                runConfiguration()
            case .peerEnded:
                state = "Peer ended session"
            @unknown default:
                state = "Peer removed"
            }
        }
    }

    nonisolated func sessionWasSuspended(_ session: NISession) {
        let id = ObjectIdentifier(session)
        Task { @MainActor in
            guard self.session.map(ObjectIdentifier.init) == id else { return }
            isSuspended = true
            distanceMeters = nil
            state = "Suspended"
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
            distanceMeters = nil
            self.session = nil
            isSuspended = false
            switch code {
            case .userDidNotAllow:
                state = "Nearby Interaction not allowed. Turn it on in Settings."
            case .unsupportedPlatform:
                state = "Nearby Interaction not available on this device"
            default:
                state = "Session ended"
                if let exchange { startSession(exchange: exchange) }
            }
        }
    }
}
