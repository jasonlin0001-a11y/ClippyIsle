import ActivityKit
import WidgetKit
import SwiftUI
import UniformTypeIdentifiers // 雖然此檔案用不到，但保持一致性

// MARK: - 共享 App Group ID
// 必須與 App Target (ContentView) 中的定義完全一致
let appGroupID = "group.com.shihchieh.clippyisle"

// MARK: - 共享的 Attributes
// 必須與 App Target (ContentView) 中的定義完全一致
struct ClippyIsleAttributes: ActivityAttributes {
    
    // 【V4 Widget 修復】 複製 ColorUtility，讓 Widget 也能使用
    struct ColorUtility {
        static func color(forName name: String) -> Color {
            switch name.lowercased() {
            case "green": return .green
            case "orange": return .orange
            case "red": return .red
            case "pink": return .pink
            case "purple": return .purple
            case "black": return .black
            case "white": return .white
            default: return .blue
            }
        }
    }
    
    // 【V4 Widget 修復】 複製 ContentState
    public struct ContentState: Codable, Hashable {
        var itemCount: Int
        var themeColorName: String
        var itemsLabel: String // 從 App 傳來的本地化 "items" 字串
    }
}

// MARK: - Widget 主體
// 【V4 錯誤修正】 移除 @main。
// 專案中應由 ClippyIsleWidgetBundle 擔任 @main。
struct ClippyIsleWidget: Widget {
    let kind: String = "ClippyIsleWidget" // Widget 的唯一 ID

    // Widget 的主體，定義 Live Activity 如何顯示
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClippyIsleAttributes.self) { context in
            
            // MARK: - 鎖定畫面 (Lock Screen) UI
            // 【V4 名稱修復】 使用新的 LockScreenView 來強制顯示 App 名稱
            LockScreenView(context: context)
                // 讓使用者點擊鎖定畫面時，能打開主 App
                .widgetURL(URL(string: "clippyisle://openApp"))

        } dynamicIsland: { context in
            
            // MARK: - 動態島 (Dynamic Island) UI
            DynamicIsland {
                
                // --- 擴展示圖 (Expanded View) ---
                
                // 【V4 名稱修復】 在 .leading 區域 (左上角) 顯示 App 名稱
                DynamicIslandExpandedRegion(.leading) {
                    Text("Clippy Isle")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                
                // 【V4 名稱修復】 在 .bottom 區域顯示精簡的項目計數
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedIslandView(context: context)
                }
                
            } compactLeading: {
                
                // --- 緊湊視圖 (左側) ---
                // 【V4 Widget 修復】 讀取 themeColor 並套用
                let themeColor = ClippyIsleAttributes.ColorUtility.color(forName: context.state.themeColorName)
                Image(systemName: "clipboard.fill")
                    .foregroundColor(themeColor)
                
            } compactTrailing: {
                
                // --- 緊湊視圖 (右側) ---
                // 【V4 Widget 修復】 讀取 themeColor 並套用
                let themeColor = ClippyIsleAttributes.ColorUtility.color(forName: context.state.themeColorName)
                
                // 【V4 名稱修復】 修正為顯示 "16 項" (以符合截圖)
                Text("\(context.state.itemCount) \(context.state.itemsLabel)")
                    .font(.caption2) // 使用小字體以符合空間
                    .foregroundColor(themeColor)
                
            } minimal: {
                
                // --- 最小視圖 (AOD) ---
                // 【V4 Widget 修復】 讀取 themeColor 並套用
                let themeColor = ClippyIsleAttributes.ColorUtility.color(forName: context.state.themeColorName)
                Image(systemName: "clipboard.fill")
                    .foregroundColor(themeColor)
            }
        }
    }
}

// MARK: - 【V4 名稱修復】 鎖定畫面的 UI
// 這個 View 會顯示 App 名稱
struct LockScreenView: View {
    let context: ActivityViewContext<ClippyIsleAttributes>

    var body: some View {
        let state = context.state
        let themeColor = ClippyIsleAttributes.ColorUtility.color(forName: state.themeColorName)
        
        HStack {
            Image(systemName: "clipboard.fill")
                .font(.body)
                .foregroundColor(themeColor)
            
            // 加上 App 名稱
            Text("Clippy Isle")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(themeColor)
            
            Spacer() // 將計數推到右邊

            // 顯示計數
            Text("\(state.itemCount) \(state.itemsLabel)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(themeColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}


// MARK: - 【V4 名稱修復】 動態島擴展 (Bottom) 的 UI
// 這個 View *不* 顯示 App 名稱，因為名稱已經在 .leading 區域了
struct ExpandedIslandView: View {
    let context: ActivityViewContext<ClippyIsleAttributes>
    
    var body: some View {
        let state = context.state
        let themeColor = ClippyIsleAttributes.ColorUtility.color(forName: state.themeColorName)
        
        // 只有圖示和計數
        HStack {
            Image(systemName: "clipboard.fill")
                .font(.body)
                .foregroundColor(themeColor)
            
            Text("\(state.itemCount) \(state.itemsLabel)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(themeColor)
        }
    }
}

// 【V4 名稱修復】 移除舊的 ClippyIsleWidgetEntryView
// (你舊的 ClippyIsleWidgetEntryView 程式碼會在這裡，
// 它現在已經被 LockScreenView 和 ExpandedIslandView 取代了)


