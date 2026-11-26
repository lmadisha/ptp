import PTPCore
import SwiftUI
import UserNotifications

/// First-launch setup (ADR-0017). Each permission is asked only when the owner taps on its page, with the reason
/// shown first. Only the "finished" flag is stored.
struct OnboardingView: View {
    static let finishedKey = "onboardingFinished"
    private static let riskyPlacesToAsk = 3

    private enum Step: Int, CaseIterable {
        case welcome, watch, bluetooth, nearby, notifications, location, risky, test
    }

    let exchange: TokenExchange
    let visitLearner: VisitLearner
    let placeWatcher: PlaceWatcher
    let startBluetooth: () -> Void
    let startRanging: () -> Void
    @AppStorage(finishedKey) private var finished = false
    @State private var step = Step.welcome
    @State private var sawAlarm = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            page
            Spacer()
        }
        .padding()
        .animation(.default, value: step)
        .onChange(of: exchange.watchState) { _, state in
            if step == .test, state == .alarm { sawAlarm = true }
        }
    }

    @ViewBuilder private var page: some View {
        switch step {
        case .welcome:
            card(
                "shield.lefthalf.filled", "PTP",
                "Your watch warns you, then alarms, when your iPhone is left behind or taken. From the alarm, one tap gets you to Mark as Lost. PTP doesn't lock your iPhone, and nothing leaves your devices.")
            primary("Get started") { next() }
        case .watch:
            let ready = exchange.isPaired && exchange.isWatchAppInstalled
            card(
                "applewatch", "Your Apple Watch",
                ready
                    ? "Your watch is paired and PTP is installed on it."
                    : !exchange.isPaired
                        ? "Pair an Apple Watch in the Watch app. PTP needs it to measure the distance."
                        : "Install PTP on your watch from the Watch app, under Available Apps.")
            primary(ready ? "Continue" : "Continue anyway") { next() }
        case .bluetooth:
            card(
                "dot.radiowaves.left.and.right", "Bluetooth",
                "Your iPhone sends a signal to your watch every second. If it stops, the watch alarms, even when the distance can't be measured.")
            primary("Allow Bluetooth") {
                startBluetooth()
                next()
            }
        case .nearby:
            card(
                "ruler", "Nearby Interaction",
                "Measures how far your iPhone is from your watch, so the watch can warn you when they're too far apart. iOS asks once your watch app is open.")
            primary("Allow distance") {
                startRanging()
                next()
            }
        case .notifications:
            card(
                "bell.badge", "Notifications",
                "When you arrive somewhere new or at a place you marked as risky, your watch asks whether to arm.")
            primary("Allow notifications") {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
                next()
            }
            secondary("Not now") { next() }
        case .location:
            card(
                "location", "Location",
                "PTP learns the areas you visit often, so it can ask to arm somewhere new, and watches the risky places you mark. Areas are rounded and stay on your iPhone. Choose “Always” when iOS asks.")
            primary(visitLearner.isLearning ? "Continue" : "Allow location") {
                if !visitLearner.isLearning, !visitLearner.needsSettings { visitLearner.start() }
                next()
            }
            if !visitLearner.isLearning { secondary("Not now") { next() } }
        case .risky:
            card(
                "exclamationmark.triangle", "Risky places",
                visitLearner.isLearning
                    ? "Where would you want PTP armed every time, like a station or a market? Mark up to \(Self.riskyPlacesToAsk) now while you're there, or later from the main screen."
                    : "Marking a risky place needs location “Always”. You can mark places later from the main screen.")
            if visitLearner.isLearning {
                Text("Risky places: \(placeWatcher.riskyCount)").font(.footnote)
                Button("Mark here as risky") { placeWatcher.mark(.risky) }
                    .buttonStyle(.bordered)
                    .disabled(placeWatcher.isLocating || placeWatcher.riskyCount >= Self.riskyPlacesToAsk)
                if let problem = placeWatcher.markProblem {
                    Text(problem).font(.footnote).multilineTextAlignment(.center)
                }
            }
            primary("Continue") { next() }
        case .test:
            card(
                "bell.and.waves.left.and.right", "Try an alarm",
                "Open PTP on your watch and tap Arm. Put your iPhone down and walk away. The watch warns, then alarms. Walk back and tap “I have it”, then Disarm.")
            Text(
                sawAlarm
                    ? "Alarm received. PTP works."
                    : "Watch: \(exchange.watchState?.rawValue.capitalized ?? "no state received")"
            )
            .font(.footnote)
            primary("Done") { finished = true }
            if !sawAlarm { secondary("Skip the test") { finished = true } }
        }
    }

    private func next() {
        step = Step(rawValue: step.rawValue + 1) ?? .test
    }

    private func card(_ symbol: String, _ title: String, _ text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 48)).foregroundStyle(.tint).accessibilityHidden(true)
            Text(title).font(.title).bold().accessibilityAddTraits(.isHeader)
            Text(text).multilineTextAlignment(.center)
        }
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action).buttonStyle(.borderedProminent).controlSize(.large)
    }

    private func secondary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
    }
}
