import SwiftUI

struct ContentView: View {
    @State private var exchange = TokenExchange()
    @State private var ranging = Ranging()
    @State private var session = WatchSession()
    @State private var heartbeat = HeartbeatReceiver()
    @Environment(\.scenePhase) private var scenePhase
    private let readingLog = ReadingLog.shared

    var body: some View {
        NavigationStack {
            switch session.state {
            case .disarmed:
                DisarmedView(
                    session: session,
                    diagnostics: DiagnosticsView(
                        exchange: exchange,
                        ranging: ranging,
                        heartbeat: heartbeat,
                        readingLog: readingLog,
                        keepAlive: session.keepAlive
                    )
                )
            case .armed:
                ArmedView(session: session)
            case .warning:
                WarningView(session: session)
            case .alarm:
                AlarmView(session: session)
            case .lost:
                LostView(session: session)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { session.appBecameActive() }
        }
        .task {
            ranging.onSample = { [readingLog, session] distance in
                session.observe(distance: distance, source: .uwb)
                readingLog.log(distance: distance, source: .uwb)
            }
            heartbeat.onBeat = { [readingLog, session] rssi in
                session.observe(distance: nil, source: .ble, rssi: rssi)
                readingLog.log(distance: nil, source: .ble, rssi: rssi)
            }
            exchange.onHeartbeatID = { [heartbeat] in heartbeat.expect($0) }
            session.onStateChange = { [exchange] in exchange.publishState($0) }
            exchange.publishState(session.state)
            session.restore()
            exchange.start()
            ranging.start(exchange: exchange)
        }
    }
}
