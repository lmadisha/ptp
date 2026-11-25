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
        WindowGroup {
            ContentView(session: session)
                .onOpenURL { url in
                    // The quick-arm complication. Restore first, so a cold launch can't arm over a saved state.
                    guard url.scheme == "ptp", url.host == "arm" else { return }
                    session.restore()
                    session.arm(.normal)
                }
        }
    }
}
