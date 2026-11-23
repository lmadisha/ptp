import Foundation
import NearbyInteraction
import Observation
import WatchConnectivity

@MainActor
@Observable
final class TokenExchange: NSObject {
    private nonisolated static let tokenKey = "niDiscoveryToken"
    private nonisolated static let heartbeatIDKey = "heartbeatID"

    private(set) var linkStatus = "Connecting to companion device…"
    private(set) var tokenStatus = "Waiting to exchange tokens…"
    var onPeerToken: (@MainActor (NIDiscoveryToken) -> Void)?
    var onHeartbeatID: (@MainActor (UUID) -> Void)?

    private var pendingToken: Data?
    private var pendingHeartbeatID: Data?
    private var contextPublished = false

    func start() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        } else {
            linkStatus = "WatchConnectivity not available on this device"
        }
    }

    #if os(watchOS)
    /// Sends every reading log, including those from launches that were killed mid-session.
    func sendLogs() {
        let session = WCSession.default
        guard session.activationState == .activated, session.isCompanionAppInstalled else { return }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: .documentsDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasSuffix(".diagnostics.csv") {
            // Send a snapshot, because the current log is still being appended to.
            let copy = URL.temporaryDirectory.appending(path: file.lastPathComponent)
            try? FileManager.default.removeItem(at: copy)
            guard (try? FileManager.default.copyItem(at: file, to: copy)) != nil else { continue }
            session.transferFile(copy, metadata: nil)
        }
    }
    #endif

    func publish(_ token: NIDiscoveryToken) {
        contextPublished = false
        pendingToken = try? NSKeyedArchiver.archivedData(
            withRootObject: token, requiringSecureCoding: true)
        guard pendingToken != nil else {
            tokenStatus = "Token not sent yet"
            return
        }
        sendContext()
    }

    func publishHeartbeatID(_ id: UUID) {
        let data = Heartbeat.encodeID(id)
        if pendingHeartbeatID != data {
            pendingHeartbeatID = data
            contextPublished = false
        }
        sendContext()
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

    private func sendContext() {
        guard !contextPublished else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        var context: [String: Data] = [:]
        context[Self.tokenKey] = pendingToken
        context[Self.heartbeatIDKey] = pendingHeartbeatID
        guard !context.isEmpty else { return }

        do {
            try session.updateApplicationContext(context)
            contextPublished = true
            if pendingToken != nil { tokenStatus = "Token sent" }
        } catch {
            guard pendingToken != nil else { return }
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

    private func receiveContext(token: Data?, heartbeatID: Data?) {
        guard token != nil || heartbeatID != nil else { return }
        sendContext()  // the peer exists now, so retry an unpublished context first
        if let heartbeatID, let id = Heartbeat.decodeID(heartbeatID) {
            onHeartbeatID?(id)
        }
        if let token { receiveToken(token) }
    }

    private func receiveToken(_ data: Data) {
        guard let token = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: NIDiscoveryToken.self, from: data)
        else {
            tokenStatus = "Could not read peer discovery token"
            return
        }
        tokenStatus = "Peer token received"
        onPeerToken?(token)
    }
}

extension TokenExchange: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        let reachable = session.isReachable
        let activated = activationState == .activated && error == nil
        // The system keeps the last context even after the other app is removed.
        #if os(iOS)
        let counterpartInstalled = session.isWatchAppInstalled
        #else
        let counterpartInstalled = session.isCompanionAppInstalled
        #endif
        let context = counterpartInstalled ? session.receivedApplicationContext : [:]
        let token = context[Self.tokenKey] as? Data
        let heartbeatID = context[Self.heartbeatIDKey] as? Data
        Task { @MainActor in
            updateLinkStatus(reachable: reachable)
            guard activated else {
                linkStatus += " · activation failed"
                return
            }
            sendContext()
            receiveContext(token: token, heartbeatID: heartbeatID)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in
            updateLinkStatus(reachable: reachable)
            sendContext()
        }
    }

    nonisolated func session(
        _ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        let token = applicationContext[Self.tokenKey] as? Data
        let heartbeatID = applicationContext[Self.heartbeatIDKey] as? Data
        Task { @MainActor in receiveContext(token: token, heartbeatID: heartbeatID) }
    }

    #if os(iOS)
    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // WatchConnectivity removes the Inbox file when this callback returns.
        let name = file.fileURL.lastPathComponent
        guard name.hasPrefix("ptp-watch-"), name.hasSuffix(".diagnostics.csv") else { return }
        var destination = URL.documentsDirectory.appending(path: name)
        try? FileManager.default.removeItem(at: destination)  // a newer snapshot of the same log
        guard (try? FileManager.default.moveItem(at: file.fileURL, to: destination)) != nil else { return }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? destination.setResourceValues(values)
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        let installed = session.isWatchAppInstalled
        Task { @MainActor in
            updateLinkStatus(reachable: reachable)
            if installed { sendContext() }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            contextPublished = false
            WCSession.default.activate()
        }
    }
    #endif

    #if os(watchOS)
    nonisolated func sessionCompanionAppInstalledDidChange(_ session: WCSession) {
        Task { @MainActor in sendContext() }
    }
    #endif
}
