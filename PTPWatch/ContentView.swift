import PTPCore
import SwiftUI

struct ContentView: View {
    @State private var exchange = TokenExchange()
    @State private var ranging = Ranging()
    @State private var session = WatchSession()
    @State private var heartbeat = HeartbeatReceiver()
    private let readingLog = ReadingLog.shared

    var body: some View {
        let keepAlive = session.keepAlive
        ScrollView {
            VStack {
                Text("PTP").font(.largeTitle).bold()
                switch session.state {
                case .disarmed: Text("Disarmed")
                case .armed: Text("Armed")
                case .warning: Text("Warning")
                case .alarm: Text("Alarm")
                case .lost: Text("Lost")
                }
                if session.state == .disarmed {
                    Button("Arm") { session.arm(.normal) }
                } else if session.state == .lost {
                    Button("Done") { session.reset() }
                } else {
                    Button("Disarm") { session.disarm() }
                }
                if session.state == .alarm {
                    Button("I have it") { session.iHaveIt() }
                    Button("Mark as Lost") { session.markAsLost() }
                }
                Text("Phone Theft Prevention — setup build · core \(PTPCore.version)")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                Text(exchange.linkStatus).font(.footnote)
                Text(ranging.state).font(.footnote)
                Text(ranging.distanceMeters.map { String(format: "%.1f m", $0) } ?? "—")
                Text("Heartbeat: \(heartbeat.state)").font(.footnote)
                if let lastBeat = heartbeat.lastBeat {
                    Text("Last beat: \(Text(lastBeat, style: .relative))").font(.footnote)
                }
                Text("Log: \(readingLog.rows) rows").font(.footnote)
                Button("Send logs to phone") { exchange.sendLogs() }

                Button("Keep alive: runtime") { keepAlive.startRuntime() }
                    .disabled(keepAlive.mode != .off)
                Button("Keep alive: workout") {
                    Task { await keepAlive.startWorkout() }
                }
                .disabled(keepAlive.mode != .off)
                Button("Stop") { keepAlive.stop() }
                    .disabled(keepAlive.mode == .off)

                Text(keepAlive.state).font(.footnote)
                if let startedAt = keepAlive.startedAt {
                    Text(startedAt, style: .relative).font(.footnote)
                }
            }
            .padding()
        }
        .task {
            ranging.onSample = { [readingLog, session] distance in
                session.observe(distance: distance, source: .uwb)
                readingLog.log(distance: distance, source: .uwb)
            }
            heartbeat.onBeat = { [readingLog, session] in
                session.observe(distance: nil, source: .ble)
                readingLog.log(distance: nil, source: .ble)
            }
            exchange.onHeartbeatID = { [heartbeat] in heartbeat.expect($0) }
            session.restore()
            exchange.start()
            ranging.start(exchange: exchange)
        }
    }
}
