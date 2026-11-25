import SwiftUI

@main
struct PTPApp: App {
    @State private var visitLearner: VisitLearner
    @State private var placeWatcher: PlaceWatcher

    init() {
        let learner = VisitLearner()
        let watcher = PlaceWatcher()
        // Wired here, not in a view: a background relaunch for a visit may never build the view.
        learner.isInChosenPlace = watcher.contains(latitude:longitude:)
        _visitLearner = State(initialValue: learner)
        _placeWatcher = State(initialValue: watcher)
    }

    var body: some Scene {
        WindowGroup { ContentView(visitLearner: visitLearner, placeWatcher: placeWatcher) }
    }
}
