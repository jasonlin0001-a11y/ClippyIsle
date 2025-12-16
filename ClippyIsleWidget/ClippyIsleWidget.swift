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

// MARK: - Lock Screen Widget (AccessoryRectangular)

@available(iOS 16.0, *)
struct ClippyIsleLockScreenWidget: Widget {
    let kind: String = "ClippyIsleLockScreenWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LockScreenWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("CC Isle")
        .description("Quick access to your clipboard.")
        .supportedFamilies([.accessoryRectangular])
    }
}

@available(iOS 16.0, *)
struct LockScreenWidgetEntryView: View {
    var entry: Provider.Entry
    
    private var hasContent: Bool {
        entry.latestClippedText != nil && !entry.latestClippedText!.isEmpty
    }
    
    var body: some View {
        if hasContent {
            contentStateView
        } else {
            emptyStateView
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "tray")
                    .font(.system(size: 12))
                Text("Nothing here yet...")
                    .font(.system(size: 12))
            }
            .foregroundStyle(.secondary)
            
            Link(destination: URL(string: "ccisle://")!) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Click & CC me!")
                        .font(.system(size: 12, weight: .bold))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Content State View
    private var contentStateView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 12))
                Text(entry.latestClippedText ?? "")
                    .font(.system(size: 12))
                    .lineLimit(2)
            }
            .foregroundStyle(.primary)
            
            Link(destination: URL(string: "ccisle://play")!) {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Play")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
