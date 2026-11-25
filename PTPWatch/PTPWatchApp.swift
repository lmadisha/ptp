import SwiftUI

@main
struct PTPWatchApp: App {
    @State private var session: WatchSession
    private let newAreaPrompt: NewAreaPrompt

    init() {
        let initialSession = WatchSession()
        session = initialSession
        newAreaPrompt = NewAreaPrompt(session: initialSession)
    }

    var body: some Scene {
        WindowGroup { ContentView(session: session) }
    }
}
