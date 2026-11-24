import ActivityKit
import SwiftUI
import WidgetKit

@main
struct PTPLiveActivityBundle: WidgetBundle {
    var body: some Widget { PTPLiveActivity() }
}

private struct PTPLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PTPActivityAttributes.self) { context in
            VStack(alignment: .leading) {
                Text(title(context.state)).font(.headline)
                Text(context.state.state)
                distanceLabel(context.state.distanceMeters)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .foregroundStyle(.white)
            // Darker than system red, so white body text keeps its contrast.
            .activityBackgroundTint(context.state.isAlarm ? Color(red: 0.7, green: 0, blue: 0) : .black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(title(context.state)).foregroundStyle(context.state.isAlarm ? .red : .primary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    distanceLabel(context.state.distanceMeters)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.state)
                }
            } compactLeading: {
                glyph(context.state)
            } compactTrailing: {
                distanceLabel(context.state.distanceMeters)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } minimal: {
                glyph(context.state)
            }
        }
    }

    /// The watch's state when the phone has one, so the Alarm reads as a word and not only as a colour.
    private func title(_ state: PTPActivityAttributes.ContentState) -> String {
        state.watchState.map { "PTP · \($0.capitalized)" } ?? "PTP"
    }

    private func glyph(_ state: PTPActivityAttributes.ContentState) -> some View {
        Image(systemName: state.isAlarm ? "exclamationmark.triangle.fill" : "applewatch")
            .foregroundStyle(state.isAlarm ? .red : .primary)
            .accessibilityLabel(title(state))
    }

    private func distanceLabel(_ distance: Float?) -> some View {
        Text(distance.map { String(format: "%.1f m", $0) } ?? "—")
            .monospacedDigit()
    }
}
