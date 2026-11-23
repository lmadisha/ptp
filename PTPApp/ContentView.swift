import PTPCore
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("PTP").font(.largeTitle).bold()
            Text("Phone Theft Prevention — setup build · core \(PTPCore.version)")
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
