import SwiftUI

struct DisarmedView: View {
    let session: WatchSession
    let diagnostics: DiagnosticsView

    var body: some View {
        ScrollView {
            VStack {
                Text("Disarmed").font(.headline).accessibilityAddTraits(.isHeader)
                Button("Arm") { session.arm(.normal) }
                NavigationLink("Diagnostics") { diagnostics }
            }
        }
    }
}

struct ArmedView: View {
    let session: WatchSession

    var body: some View {
        let distance = session.distanceMeters
        let distanceText = distance.map { String(format: "%.1f m", $0) }
        let progress = min((distance ?? 0) / session.threshold, 1)

        ScrollView {
            VStack {
                Text("Armed").font(.headline).accessibilityAddTraits(.isHeader)
                Text(distanceText ?? "—")
                    .accessibilityLabel("Distance")
                    .accessibilityValue(Text(distanceText ?? "Unavailable"))
                if distance == nil {
                    // Without a distance the watch judges by the heartbeat's signal strength (ADR-0009).
                    Text(session.rssi.map { "No distance. Signal \($0) dBm" } ?? "No distance reading").font(.footnote)
                }
                ProgressView(value: progress)
                    .accessibilityLabel("Distance relative to alert threshold")
                    .accessibilityValue(Text(progress.formatted(.percent.precision(.fractionLength(0)))))
                if session.isUnprotected {
                    Text("Not protected. Keep PTP open.").font(.footnote).foregroundStyle(.orange)
                }
                Button("Disarm") { session.disarm() }
            }
        }
    }
}

struct WarningView: View {
    let session: WatchSession

    var body: some View {
        let distanceText = session.distanceMeters.map { String(format: "%.1f m", $0) }

        ScrollView {
            VStack {
                Text("Warning").font(.headline).accessibilityAddTraits(.isHeader)
                Text(distanceText ?? "—")
                    .accessibilityLabel("Distance")
                    .accessibilityValue(Text(distanceText ?? "Unavailable"))
                if let seconds = session.secondsToAlarm {
                    Text("Alarm in \(seconds) s")
                        .accessibilityLabel("Time until alarm")
                        .accessibilityValue(Text(Duration.seconds(seconds).formatted(.units(allowed: [.seconds]))))
                }
                Button("I have it") { session.iHaveIt() }
            }
        }
        .containerBackground(Color.orange.gradient, for: .navigation)
    }
}

struct AlarmView: View {
    let session: WatchSession

    var body: some View {
        ScrollView {
            VStack {
                Text("Alarm").font(.headline).accessibilityAddTraits(.isHeader)
                // First, where Warning has it: a tap that lands as the screen changes must not mark the phone lost.
                Button("I have it") { session.iHaveIt() }
                Button("Mark as Lost") { session.markAsLost() }
                Button("Disarm") { session.disarm() }
            }
        }
        .containerBackground(Color.red.gradient, for: .navigation)
    }
}

struct LostView: View {
    let session: WatchSession

    var body: some View {
        ScrollView {
            VStack {
                Text("Mark your iPhone as lost").font(.headline).accessibilityAddTraits(.isHeader)
                Text("Open Find Devices on this watch, or icloud.com/find on another device.")
                Button("Done") { session.reset() }
            }
        }
    }
}
