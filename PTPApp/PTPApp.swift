import SwiftUI

@main
struct PTPApp: App {
    @State private var visitLearner = VisitLearner()

    var body: some Scene {
        WindowGroup { ContentView(visitLearner: visitLearner) }
    }
}
