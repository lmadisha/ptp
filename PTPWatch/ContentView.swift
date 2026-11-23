import PTPCore
import SwiftUI

struct ContentView: View {
    @State private var exchange = TokenExchange()
    @State private var ranging = Ranging()
    @State private var keepAlive = KeepAlive()
    @State private var heartbeat = HeartbeatReceiver()
    private let readingLog = ReadingLog.shared

    var body: some View {
        ScrollView {
            VStack {
                Text("PTP").font(.largeTitle).bold()
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
                Button("Send log to phone") {
                    if let file = readingLog.fileURL { exchange.send(file: file) }
                }
                .disabled(readingLog.fileURL == nil)

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
            ranging.onSample = { [readingLog] in readingLog.log(distance: $0, source: .uwb) }
            heartbeat.onBeat = { [readingLog] in readingLog.log(distance: nil, source: .ble) }
            exchange.onHeartbeatID = { [heartbeat] in heartbeat.expect($0) }
            exchange.start()
            ranging.start(exchange: exchange)
        }
    }
}
