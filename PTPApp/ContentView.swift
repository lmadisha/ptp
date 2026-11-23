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
            Text("Log: \(readingLog.rows) rows").font(.footnote)
        }
        .padding()
        .task {
            ranging.onChange = { [liveActivity] in liveActivity.update(state: $0, distance: $1) }
            ranging.onSample = { [readingLog] in readingLog.log(distance: $0, source: .uwb) }
            heartbeat.onBeat = { [readingLog] in readingLog.log(distance: nil, source: .ble) }
            exchange.publishHeartbeatID(Self.heartbeatID)
            ranging.start(exchange: exchange)
            exchange.start()
            heartbeat.start()
        }
        .onChange(of: scenePhase, initial: true) {
            guard scenePhase == .active else { return }
            liveActivity.start()
            liveActivity.update(state: ranging.state, distance: ranging.distanceMeters)
        }
    }
}
