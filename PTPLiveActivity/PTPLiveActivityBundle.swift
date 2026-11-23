import SwiftUI
import WidgetKit

struct PlaceholderEntry: TimelineEntry { let date: Date }

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry { PlaceholderEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping @Sendable (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [PlaceholderEntry(date: .now)], policy: .never))
    }
}

struct PlaceholderWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PTPPlaceholder", provider: PlaceholderProvider()) { _ in
            Text("PTP").containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("PTP")
        .description("Placeholder.")
    }
}

@main
struct PTPLiveActivityBundle: WidgetBundle {
    var body: some Widget { PlaceholderWidget() }
}
