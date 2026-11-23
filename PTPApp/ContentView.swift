import PTPCore
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var exchange = TokenExchange()
    @State private var ranging = Ranging()
    @State private var liveActivity = LiveActivityController()

    var body: some View {
        VStack {
            Text("PTP").font(.largeTitle).bold()
            Text("Phone Theft Prevention — setup build · core \(PTPCore.version)")
                .font(.footnote)
                .multilineTextAlignment(.center)
            Text(exchange.linkStatus).font(.footnote)
            Text(ranging.state).font(.footnote)
            Text(ranging.distanceMeters.map { String(format: "%.1f m", $0) } ?? "—")
        }
        .padding()
        .task {
            ranging.onChange = { [liveActivity] in liveActivity.update(state: $0, distance: $1) }
            exchange.start()
            ranging.start(exchange: exchange)
        }
        .onChange(of: scenePhase, initial: true) {
            guard scenePhase == .active else { return }
            liveActivity.start()
            liveActivity.update(state: ranging.state, distance: ranging.distanceMeters)
        }
    }
}
