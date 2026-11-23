import PTPCore
import SwiftUI

struct ContentView: View {
    @State private var exchange = TokenExchange()
    @State private var ranging = Ranging()

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
            exchange.start()
            ranging.start(exchange: exchange)
        }
    }
}
