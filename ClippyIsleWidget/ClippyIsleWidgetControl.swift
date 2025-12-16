import WidgetKit
import SwiftUI
import UniformTypeIdentifiers

struct Provider: TimelineProvider {
    // 修正：明確指定 Entry 的類型
    typealias Entry = SimpleEntry

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), itemCount: 0, themeColorName: "blue", latestClippedText: nil, latestItemID: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), itemCount: 10, themeColorName: "blue", latestClippedText: "Sample clipped text preview", latestItemID: nil)
        completion(entry)
    }

    // 修正：使用具體的 SimpleEntry 類型，而不是泛型的 Entry
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: appGroupID)
        let items = userDefaults?.data(forKey: "clippedItems").flatMap {
            try? JSONDecoder().decode([ClipboardItem].self, from: $0)
        }
        let itemCount = items?.count ?? 0
        let themeColorName = userDefaults?.string(forKey: "themeColorName") ?? "blue"
        
        // Get the latest text item for lock screen widget, sorted by timestamp (most recent first)
        let latestTextItem = items?
            .filter { $0.type == UTType.text.identifier || $0.type == UTType.url.identifier }
            .sorted { $0.timestamp > $1.timestamp }
            .first
        let latestClippedText = latestTextItem?.displayName ?? latestTextItem?.content
        let latestItemID = latestTextItem?.id

        let entry = SimpleEntry(date: Date(), itemCount: itemCount, themeColorName: themeColorName, latestClippedText: latestClippedText, latestItemID: latestItemID)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let itemCount: Int
    let themeColorName: String
    let latestClippedText: String?
    let latestItemID: UUID?
}
