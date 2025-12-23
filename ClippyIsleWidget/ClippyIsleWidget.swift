import WidgetKit
import SwiftUI

struct ClippyIsleWidget: Widget {
    let kind: String = "ClippyIsleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ClippyIsleWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("CC Isle")
        .description("Quick access to CC Isle with audio playback.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled() // Ensure content fills the widget
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
        VStack(spacing: 6) {
            // Header: CC Isle + Item Count
            HStack {
                Text("CC Isle")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text("\(entry.audioFileCount)Item")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Buttons
            VStack(spacing: 6) {
                // Click & CC me button - opens main app
                Link(destination: URL(string: "ccisle://open")!) {
                    Text("Click & CC me")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(themeColor.opacity(0.2))
                        .foregroundColor(themeColor)
                        .cornerRadius(8)
                }
                
                // Listen button - plays audio
                Link(destination: URL(string: "ccisle://playaudio")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Listen")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(themeColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding(12)
    }
}

// MARK: - Widget Preview
#Preview(as: .systemSmall) {
    ClippyIsleWidget()
} timeline: {
    SimpleEntry(date: .now, itemCount: 25, audioFileCount: 10, themeColorName: "green")
}
