import PTPCore
import SwiftUI

struct ContentView: View {
    private static let heartbeatID = UUID()

    @Environment(\.scenePhase) private var scenePhase
    @State private var exchange = TokenExchange()
    @State private var ranging = Ranging()
    @State private var liveActivity = LiveActivityController()
    @State private var heartbeat = HeartbeatSender(sessionID: ContentView.heartbeatID)
    private let readingLog = ReadingLog.shared

    private func updateLiveActivity() {
        liveActivity.update(
            state: ranging.state, distance: ranging.distanceMeters, watchState: Self.watchState(exchange))
    }

    private static func watchState(_ exchange: TokenExchange) -> String? {
        #if DEBUG
        // Simulator evidence only: the Simulators are not paired, so no watch state arrives there.
        let arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        if let demo = (arguments["demoWatchState"] as? String).flatMap(PTPState.init(rawValue:)) {
            return demo.rawValue
        }
        #endif
        return exchange.watchState?.rawValue
    }

    var body: some View {
        VStack {
            Text("PTP").font(.largeTitle).bold()
            Text("Phone Theft Prevention — setup build · core \(PTPCore.version)")
                .font(.footnote)
                .multilineTextAlignment(.center)
            Text(exchange.linkStatus).font(.footnote)
            Text(ranging.state).font(.footnote)
            Text(ranging.distanceMeters.map { String(format: "%.1f m", $0) } ?? "—")
            Text(heartbeat.state).font(.footnote)
            Text("Watch: \(Self.watchState(exchange)?.capitalized ?? "no state received")").font(.footnote)
            Text("Log: \(readingLog.rows) rows").font(.footnote)
        }
        .padding()
        .task {
            ranging.onChange = { [liveActivity, exchange] in
                liveActivity.update(state: $0, distance: $1, watchState: Self.watchState(exchange))
            }
            ranging.onSample = { [readingLog] in readingLog.log(distance: $0, source: .uwb) }
            heartbeat.onBeat = { [readingLog] in readingLog.log(distance: nil, source: .ble) }
            exchange.onWatchState = { _ in updateLiveActivity() }
            exchange.publishHeartbeatID(Self.heartbeatID)
            ranging.start(exchange: exchange)
            exchange.start()
            heartbeat.start()
        }
        .onChange(of: scenePhase, initial: true) {
            guard scenePhase == .active else { return }
            liveActivity.start()
            updateLiveActivity()
        }
    }
}
