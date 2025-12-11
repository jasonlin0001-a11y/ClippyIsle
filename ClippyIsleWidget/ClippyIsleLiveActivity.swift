import SwiftUI
import WidgetKit

// 【⚠️ 重要修正 ⚠️】
// 已根據您的截圖修正為全小寫，必須完全一致才能讀取資料
let widgetAppGroupID = "group.com.shihchieh.clippyisle"

#if os(iOS)
import ActivityKit 

// 【新增】一個可重用的、支持高亮和滾動的文字視圖
struct ScrollingHighlightTextView: View {
    let text: String
    let highlightRange: NSRange?
    let font: Font
    let highlightColor: Color
    let defaultColor: Color

    @State private var offset: CGFloat = 0

    var body: some View {
        let (pre, highlighted, post) = parts(from: text, range: highlightRange)

        HStack(spacing: 0) {
            Text(pre).font(font)
            Text(pre).font(font).hidden().background(
                GeometryReader { geo in
                    Color.clear.onAppear { calculateOffset(width: geo.size.width) }
                    .onChange(of: geo.size.width) { _, newWidth in calculateOffset(width: newWidth) }
                }
            )
            Text(highlighted).font(font).foregroundColor(highlightColor)
            Text(post).font(font)
        }
        .foregroundColor(defaultColor)
        .offset(x: offset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func parts(from text: String, range: NSRange?) -> (String, String, String) {
        guard let range, let stringRange = Range(range, in: text) else { return (text, "", "") }
        let pre = String(text[..<stringRange.lowerBound])
        let highlighted = String(text[stringRange])
        let post = String(text[stringRange.upperBound...])
        return (pre, highlighted, post)
    }
    
    private func calculateOffset(width: CGFloat) {
        let newOffset = -width
        withAnimation(.easeInOut(duration: 0.25)) { offset = newOffset }
    }
}

// **新增**: 用於解析主題顏色的輔助擴充
extension Color {
    static func resolveThemeColor(name: String) -> Color {
        if name == "custom" {
            // 嘗試從 App Group UserDefaults 讀取自訂顏色
            // 這裡會使用上方定義的 widgetAppGroupID
            if let defaults = UserDefaults(suiteName: widgetAppGroupID) {
                let r = defaults.double(forKey: "customColorRed")
                let g = defaults.double(forKey: "customColorGreen")
                let b = defaults.double(forKey: "customColorBlue")
                
                // 除錯用：如果讀到的都是 0，代表尚未設定過或讀取失敗
                // 這裡為了避免真正設定為黑色的使用者受影響，我們只在確認讀取失敗(defaults為nil)時才報錯
                // 但因為 double(forKey:) 預設回傳 0，所以這裡做個簡單的防呆：
                // 如果全是 0，雖然有可能是黑色，但也極有可能是讀取失敗。
                // 為了安全起見，如果全 0 則回退到藍色。
                if r == 0 && g == 0 && b == 0 {
                     return ClippyIsleAttributes.ColorUtility.color(forName: name)
                }
                
                return Color(red: r, green: g, blue: b)
            } else {
                print("❌ Live Activity: 無法存取 App Group: \(widgetAppGroupID)")
            }
        }
        return ClippyIsleAttributes.ColorUtility.color(forName: name)
    }
}

@available(iOS 16.1, *)
struct ClippyIsleLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClippyIsleAttributes.self) { context in
            // Lock screen UI
            LiveActivityView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.3))

        } dynamicIsland: { context in
            // Dynamic Island UI
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "c.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.resolveThemeColor(name: context.state.themeColorName))
                        Text("CC Isle")
                            .font(.headline)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                     Text("\(context.state.itemCount) \(context.state.itemsLabel)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // Removed subtitle area
                }
            } compactLeading: {
                Image(systemName: "c.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color.resolveThemeColor(name: context.state.themeColorName))
            } compactTrailing: {
                Text("\(context.state.itemCount)")
                    .foregroundColor(.secondary)
            } minimal: {
                Image(systemName: "c.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color.resolveThemeColor(name: context.state.themeColorName))
            }
        }
    }
}

// 鎖定畫面 Live Activity 的主要視圖
struct LiveActivityView: View {
    let context: ActivityViewContext<ClippyIsleAttributes>
    
    private var themeColor: Color { 
        Color.resolveThemeColor(name: context.state.themeColorName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 左側：App 名稱
                Label {
                    Text("CC Isle")
                } icon: {
                    Image(systemName: "c.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(themeColor)
                }
                
                Spacer()
                
                // 右側：項目數量
                Text("\(context.state.itemCount) \(context.state.itemsLabel)")
                    .font(.body.weight(.medium))
            }
        }
        .padding()
        .foregroundColor(.white)
    }
}
#endif