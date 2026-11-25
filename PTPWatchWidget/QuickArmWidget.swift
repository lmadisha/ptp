import SwiftUI
import WidgetKit

@main
struct PTPWatchWidgetBundle: WidgetBundle {
    var body: some Widget { QuickArmWidget() }
}

/// A watch-face complication that opens PTP and arms it. It shows a fixed icon, not the live state:
/// that would need an App Group shared with the watch app.
private struct QuickArmWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickArm", provider: QuickArmProvider()) { _ in
            QuickArmView()
                .widgetURL(URL(string: "ptp://arm"))
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Arm PTP")
        .description("Opens PTP and arms it.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline])
    }
}

private struct QuickArmProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry { SimpleEntry() }
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) { completion(SimpleEntry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        completion(Timeline(entries: [SimpleEntry()], policy: .never))
    }
}

private struct SimpleEntry: TimelineEntry {
    let date = Date.now
}

private struct QuickArmView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("Arm PTP", systemImage: "lock.shield")
        case .accessoryCorner:
            Image(systemName: "lock.shield")
                .font(.title2)
                .widgetLabel("Arm PTP")
        default:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "lock.shield").font(.title2)
            }
            .accessibilityLabel("Arm PTP")
        }
    }
}
