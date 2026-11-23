import PTPCore
import SwiftUI

struct ContentView: View {
    @State private var exchange = TokenExchange()

    var body: some View {
        VStack {
            Text("PTP").font(.largeTitle).bold()
            Text("Phone Theft Prevention — setup build · core \(PTPCore.version)")
                .font(.footnote)
                .multilineTextAlignment(.center)
            Text(exchange.linkStatus).font(.footnote)
            Text(exchange.tokenStatus).font(.footnote)
        }
        .padding()
        .task { exchange.start() }
    }
}
