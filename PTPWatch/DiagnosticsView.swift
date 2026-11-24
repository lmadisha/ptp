import PTPCore
import SwiftUI

struct DiagnosticsView: View {
    let exchange: TokenExchange
    let ranging: Ranging
    let heartbeat: HeartbeatReceiver
    let readingLog: ReadingLog
    let keepAlive: KeepAlive

    var body: some View {
        ScrollView {
            VStack {
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
        .navigationTitle("Diagnostics")
    }
}
