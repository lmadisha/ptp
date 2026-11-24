import Foundation
import NearbyInteraction
import Observation
import PTPCore
import WatchConnectivity

@MainActor
@Observable
final class TokenExchange: NSObject {
    private nonisolated static let tokenKey = "niDiscoveryToken"
    private nonisolated static let heartbeatIDKey = "heartbeatID"
    private nonisolated static let watchStateKey = "watchState"
    private nonisolated static let armEventKey = "armEventSeconds"

    private(set) var linkStatus = "Connecting to companion device…"
    private(set) var tokenStatus = "Waiting to exchange tokens…"
    /// True while the other device's app can receive a message right now.
    private(set) var isReachable = false
    /// Phone only: the last event request could not be delivered.
    private(set) var eventRequestFailed = false
    /// Watch only: the phone asks for an event of this length. The watch decides (ADR-0008).
    var onArmEventRequest: (@MainActor (Duration) -> Void)?
    var onPeerToken: (@MainActor (NIDiscoveryToken) -> Void)?
    var onHeartbeatID: (@MainActor (UUID) -> Void)?
    /// The watch owns the session (ADR-0008). This is the last state it reported, which may be stale.
    private(set) var watchState: PTPState? {
        didSet { if watchState != oldValue { onWatchState?(watchState) } }
    }
    /// A callback, not SwiftUI observation, so it also runs while the phone is locked.
    var onWatchState: (@MainActor (PTPState?) -> Void)?

    private var pendingToken: Data?
    private var pendingHeartbeatID: Data?
    private var pendingState: String?
    private var lastPeerToken: Data?
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

    #if os(watchOS)
    /// Fire-and-forget: nothing on the watch waits for the phone to hear this.
    func publishState(_ state: PTPState) {
        guard pendingState != state.rawValue else { return }
        pendingState = state.rawValue
        contextPublished = false
        sendContext()
    }
    #endif

    #if os(iOS)
    /// Asks the watch to start an event. Sent only while the watch app is reachable and never queued:
    /// a request delivered hours later would arm the watch when nobody expects it.
    /// The phone has no message that disarms.
    func requestEvent(for duration: Duration) {
        let session = WCSession.default
        eventRequestFailed = false
        guard session.activationState == .activated, session.isReachable else {
            eventRequestFailed = true
            return
        }
        session.sendMessage([Self.armEventKey: Int(duration.components.seconds)], replyHandler: nil) { _ in
            Task { @MainActor [weak self] in self?.eventRequestFailed = true }
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
        isReachable = reachable
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

        var context: [String: Any] = [:]
        context[Self.tokenKey] = pendingToken
        context[Self.heartbeatIDKey] = pendingHeartbeatID
        context[Self.watchStateKey] = pendingState
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

    private func receiveContext(token: Data?, heartbeatID: Data?, state: String?) {
        if let state = state.flatMap(PTPState.init(rawValue:)) { watchState = state }
        guard token != nil || heartbeatID != nil else { return }
        sendContext()  // the peer exists now, so retry an unpublished context first
        if let heartbeatID, let id = Heartbeat.decodeID(heartbeatID) {
            onHeartbeatID?(id)
        }
        // The context is resent whole on every state change; only a new token restarts ranging.
        if let token, token != lastPeerToken {
            lastPeerToken = token
            receiveToken(token)
        }
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
        let state = context[Self.watchStateKey] as? String
        Task { @MainActor in
            updateLinkStatus(reachable: reachable)
            guard activated else {
                linkStatus += " · activation failed"
                return
            }
            sendContext()
            receiveContext(token: token, heartbeatID: heartbeatID, state: state)
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
        let state = applicationContext[Self.watchStateKey] as? String
        Task { @MainActor in receiveContext(token: token, heartbeatID: heartbeatID, state: state) }
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
            watchState = nil  // a different watch may be paired next
            isReachable = false
            lastPeerToken = nil
            WCSession.default.activate()
        }
    }
    #endif

    #if os(watchOS)
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let seconds = message[Self.armEventKey] as? Int else { return }
        Task { @MainActor in onArmEventRequest?(.seconds(seconds)) }
    }

    nonisolated func sessionCompanionAppInstalledDidChange(_ session: WCSession) {
        Task { @MainActor in sendContext() }
    }
    #endif
}
