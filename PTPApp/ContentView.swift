import PTPCore
import SwiftUI

struct ContentView: View {
    private static let heartbeatID = UUID()

    @Environment(\.scenePhase) private var scenePhase
    @State private var exchange = TokenExchange()
    @State private var ranging = Ranging()
    @State private var liveActivity = LiveActivityController()
    @State private var alarmHistory = AlarmHistory()
    @State private var heartbeat = HeartbeatSender(sessionID: ContentView.heartbeatID)
    let visitLearner: VisitLearner
    let placeWatcher: PlaceWatcher
    private let readingLog = ReadingLog.shared

    private func updateLiveActivity() {
        liveActivity.update(
            state: ranging.state, distance: ranging.distanceMeters, watchState: Self.watchState(exchange))
    }

    private static func watchState(_ exchange: TokenExchange) -> String? {
        #if DEBUG
        // Simulator evidence only: the Simulators are not paired, so no watch state arrives there.
        let arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        if let demo = (arguments["demoWatchState"] as? String).flatMap(PTPState.init(rawValue:)) {
            return demo.rawValue
        }
        #endif
        return exchange.watchState?.rawValue
    }

    var body: some View {
        VStack {
            Text("PTP").font(.largeTitle).bold()
            Text("Phone Theft Prevention — setup build · core \(PTPCore.version)")
                .font(.footnote)
                .multilineTextAlignment(.center)
            Text(exchange.linkStatus).font(.footnote)
            Text(ranging.state).font(.footnote)
            Text(ranging.distanceMeters.map { String(format: "%.1f m", $0) } ?? "—")
            Text(heartbeat.state).font(.footnote)
            Text("Watch: \(Self.watchState(exchange)?.capitalized ?? "no state received")").font(.footnote)
            Text("Log: \(readingLog.rows) rows").font(.footnote)
            Text("Alarm log: \(alarmHistory.count) events").font(.footnote)
            Text("Places learned: \(visitLearner.areas) areas").font(.footnote)
            if !visitLearner.isLearning {
                Button(
                    visitLearner.needsSettings ? "Allow location “Always” in Settings" : "Learn places",
                    action: visitLearner.start
                ).font(.footnote)
            }
            Button("Delete learned places", action: visitLearner.deleteAll).font(.footnote)
            Text("Risky places: \(placeWatcher.riskyCount) · Safe places: \(placeWatcher.safeCount)").font(.footnote)
            Group {
                Button("Mark here as risky") { placeWatcher.mark(.risky) }
                Button("Mark here as safe") { placeWatcher.mark(.safe) }
            }
            .font(.footnote)
            .disabled(placeWatcher.isLocating || !visitLearner.isLearning)
            if placeWatcher.markFailed {
                Text("Couldn't get a precise location. Try again outdoors.").font(.footnote)
            }
            Button("Remove chosen places", action: placeWatcher.deleteAll)
                .font(.footnote)
                .disabled(placeWatcher.isLocating)

            // The phone can ask the watch to arm, never to disarm (ADR-0008).
            let watchState = Self.watchState(exchange).flatMap(PTPState.init(rawValue:))
            let canAsk = exchange.isReachable && watchState == .disarmed
            let reason =
                exchange.eventRequestFailed
                ? "The watch didn't get the request. Open PTP on your watch and try again."
                : watchState == .disarmed || watchState == nil
                    ? "Open PTP on your watch to start an event from here."
                    : "An event can be started when the watch is disarmed."
            ForEach(DetectionConfig.standard.eventDurations, id: \.self) { duration in
                Button("Event \(duration.formatted(.units(allowed: [.hours], width: .wide)))") {
                    exchange.requestEvent(for: duration)
                }
                .buttonStyle(.bordered)
                .disabled(!canAsk)
                .accessibilityHint(canAsk ? "Asks your watch to arm for this long" : reason)
            }
            if !canAsk || exchange.eventRequestFailed {
                Text(reason).font(.footnote).multilineTextAlignment(.center)
            }
        }
        .padding()
        .task {
            ranging.onChange = { [liveActivity, exchange] in
                liveActivity.update(state: $0, distance: $1, watchState: Self.watchState(exchange))
            }
            ranging.onSample = { [readingLog] in readingLog.log(distance: $0, source: .uwb) }
            heartbeat.onBeat = { [readingLog] in readingLog.log(distance: nil, source: .ble) }
            exchange.onWatchState = { [alarmHistory] in
                alarmHistory.watchStateChanged(to: $0)
                updateLiveActivity()
            }
            #if DEBUG
            // Simulator evidence only: feeds the debug argument's state into the log.
            alarmHistory.watchStateChanged(to: Self.watchState(exchange).flatMap(PTPState.init(rawValue:)))
            #endif
            exchange.publishHeartbeatID(Self.heartbeatID)
            ranging.start(exchange: exchange)
            exchange.start()
            heartbeat.start()
        }
        .onChange(of: scenePhase, initial: true) {
            guard scenePhase == .active else { return }
            liveActivity.start()
            updateLiveActivity()
        }
    }
}
