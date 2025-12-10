import WidgetKit
import SwiftUI

struct ClippyIsleWidget: Widget {
    let kind: String = "ClippyIsleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ClippyIsleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("CC Isle")
        .description("View your clipboard item count.")
        .supportedFamilies([.systemSmall])
    }
}

struct ClippyIsleWidgetEntryView : View {
    var entry: Provider.Entry
    
    private var themeColor: Color {
        if entry.themeColorName == "custom" {
            // Try to read custom color from App Group UserDefaults
            if let defaults = UserDefaults(suiteName: widgetAppGroupID) {
                let r = defaults.double(forKey: "customColorRed")
                let g = defaults.double(forKey: "customColorGreen")
                let b = defaults.double(forKey: "customColorBlue")
                
                // If all zeros, fall back to default color (more likely unset than intentional black)
                // Note: This means pure black (0,0,0) cannot be set as a custom color
                if r == 0 && g == 0 && b == 0 {
                    return ClippyIsleAttributes.ColorUtility.color(forName: entry.themeColorName)
                }
                
                return Color(red: r, green: g, blue: b)
            }
        }
        return ClippyIsleAttributes.ColorUtility.color(forName: entry.themeColorName)
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "c.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(themeColor)
            Text("\(entry.itemCount) items")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
