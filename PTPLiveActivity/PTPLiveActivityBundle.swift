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
                Text("PTP").font(.headline)
                Text(context.state.state)
                distanceLabel(context.state.distanceMeters)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .foregroundStyle(.white)
            .activityBackgroundTint(.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    distanceLabel(context.state.distanceMeters)
                }
            } compactLeading: {
                glyph
            } compactTrailing: {
                distanceLabel(context.state.distanceMeters)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } minimal: {
                glyph
            }
        }
    }

    private var glyph: some View {
        Image(systemName: "applewatch").accessibilityLabel("PTP")
    }

    private func distanceLabel(_ distance: Float?) -> some View {
        Text(distance.map { String(format: "%.1f m", $0) } ?? "—")
            .monospacedDigit()
    }
}
