import Foundation
import NearbyInteraction
import Observation
import WatchConnectivity

@MainActor
@Observable
final class TokenExchange: NSObject {
    private nonisolated static let tokenKey = "niDiscoveryToken"

    private(set) var linkStatus = "Connecting to companion device…"
    private(set) var tokenStatus = "Waiting to exchange tokens…"
    private(set) var peerToken: NIDiscoveryToken?

    private var nearbySession: NISession?
    private var tokenPublished = false

    func start() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        } else {
            linkStatus = "WatchConnectivity not available on this device"
        }

        guard NISession.deviceCapabilities.supportsPreciseDistanceMeasurement else {
            tokenStatus = "Nearby Interaction not available on this device"
            return
        }
        if nearbySession == nil {
            nearbySession = NISession()
            tokenPublished = false
        }
    }

    private func updateLinkStatus(reachable: Bool) {
        let reachability = reachable ? "reachable" : "not reachable"
        #if os(iOS)
        let session = WCSession.default
        let pairing = session.isPaired ? "paired" : "not paired"
        let installation = session.isWatchAppInstalled ? "app installed" : "app not installed"
        linkStatus = "Watch link: \(pairing) · \(installation) · \(reachability)"
        #else
        linkStatus = "iPhone link: \(reachability)"
        #endif
    }

    private func sendToken() {
        guard !tokenPublished else { return }
        let session = WCSession.default
        guard session.activationState == .activated, let nearbySession else { return }
        guard let token = nearbySession.discoveryToken else {
            tokenStatus = "Discovery token unavailable"
            return
        }

        do {
            let data = try NSKeyedArchiver.archivedData(
                withRootObject: token, requiringSecureCoding: true)
            try session.updateApplicationContext([Self.tokenKey: data])
            tokenPublished = true
            tokenStatus = "Token sent"
        } catch {
            switch (error as? WCError)?.code {
            case .watchAppNotInstalled:
                tokenStatus = "Token not sent yet: watch app not installed"
            case .companionAppNotInstalled:
                tokenStatus = "Token not sent yet: companion app not installed"
            default:
                tokenStatus = "Token not sent yet"
            }
        }
    }

    private func receiveToken(_ data: Data) {
        guard nearbySession != nil else { return }
        guard let token = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: NIDiscoveryToken.self, from: data)
        else {
            tokenStatus = "Could not read peer discovery token"
            return
        }
        peerToken = token
        sendToken()  // the peer exists now, so retry an unpublished token first
        tokenStatus = "Peer token received"
    }
}

extension TokenExchange: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        let reachable = session.isReachable
        let activated = activationState == .activated && error == nil
        let data = session.receivedApplicationContext[Self.tokenKey] as? Data
        Task { @MainActor in
            updateLinkStatus(reachable: reachable)
            guard activated else {
                linkStatus += " · activation failed"
                return
            }
            sendToken()
            if let data { receiveToken(data) }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            updateLinkStatus(reachable: reachable)
            sendToken()
        }
    }

    nonisolated func session(
        _ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let data = applicationContext[Self.tokenKey] as? Data else { return }
        Task { @MainActor in receiveToken(data) }
    }

    #if os(iOS)
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        let installed = session.isWatchAppInstalled
        Task { @MainActor in
            updateLinkStatus(reachable: reachable)
            if installed { sendToken() }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            tokenPublished = false
            WCSession.default.activate()
        }
    }
    #endif

    #if os(watchOS)
    nonisolated func sessionCompanionAppInstalledDidChange(_ session: WCSession) {
        Task { @MainActor in sendToken() }
    }
    #endif
}
