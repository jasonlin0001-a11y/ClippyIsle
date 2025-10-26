import WidgetKit
import SwiftUI
import ActivityKit
import UniformTypeIdentifiers

// MARK: - 顏色管理 (必須與主 App 一致)
struct ColorUtility {
    static func color(forName name: String) -> Color {
        switch name.lowercased() {
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "pink": return .pink
        case "purple": return .purple
        default: return .blue
        }
    }
}

// MARK: - 動態島屬性 (Attributes)
// !!! 這必須與主 App 中的定義完全一致 !!!
struct ClippyIsleAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var itemCount: Int
        var themeColorName: String // 【修復】 確保與 ContentView 一致
    }
    // 【本地化】 appName 已移除，改為在 Widget 內部讀取本地化字串
}

// MARK: - 動態島 Widget 主體
struct ClippyIsleWidget: Widget {
    var body: some WidgetConfiguration {
        // 設定 Live Activity
        ActivityConfiguration(for: ClippyIsleAttributes.self) { context in
            // MARK: 鎖定畫面的外觀
            let themeColor = ColorUtility.color(forName: context.state.themeColorName)
            
            // 【UI 優化】
            HStack {
                Image(systemName: "clipboard.fill")
                    .foregroundColor(themeColor)
                Text("APP_NAME") // 【本地化】
                    .font(.headline)
                    .foregroundColor(themeColor)
                
                Spacer()
                
                Text("\(context.state.itemCount) \(String(localized: "ITEMS_LABEL"))") // 【本地化】
                    .font(.subheadline)
                    .foregroundColor(themeColor)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.8)) // 【UI 優化】
            .activitySystemActionForegroundColor(Color.white)
            
        } dynamicIsland: { context in
            // 動態島的外觀
            let themeColor = ColorUtility.color(forName: context.state.themeColorName)
            
            return DynamicIsland {
                // MARK: 展開時 (Long press on island)
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "clipboard.fill")
                        .font(.title2)
                        .foregroundColor(themeColor)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.itemCount)")
                        .font(.title2)
                        .foregroundColor(themeColor)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // 【本地化】
                    Text("\(String(localized: "APP_NAME")): \(context.state.itemCount) \(String(localized: "ITEMS_LABEL"))")
                        .font(.footnote)
                        .foregroundColor(themeColor)
                }
            } compactLeading: {
                // MARK: 緊湊時 (左側)
                Image(systemName: "clipboard.fill")
                    .foregroundColor(themeColor)
            } compactTrailing: {
                // MARK: 緊湊時 (右側)
                Text("\(context.state.itemCount)")
                    .foregroundColor(themeColor)
            } minimal: {
                // MARK: 最小化時
                Image(systemName: "clipboard.fill")
                    .foregroundColor(themeColor)
            }
            // 點擊動態島的行為
            // 點擊會自動開啟主 App。
        }
    }
}


