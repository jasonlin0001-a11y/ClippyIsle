import WidgetKit
import SwiftUI

struct ClippyIsleWidget: Widget {
    let kind: String = "ClippyIsleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ClippyIsleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Clippy Isle")
        .description("View your clipboard item count.")
        .supportedFamilies([.systemSmall])
    }
}

struct ClippyIsleWidgetEntryView : View {
    var entry: Provider.Entry
    var themeColor: Color { ClippyIsleAttributes.ColorUtility.color(forName: entry.themeColorName) }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "c.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(Color(red: 0.74, green: 0.74, blue: 0.74))
            Text("\(entry.itemCount) items")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
