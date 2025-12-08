import WidgetKit
import SwiftUI
import UniformTypeIdentifiers

struct Provider: TimelineProvider {
    // 修正：明確指定 Entry 的類型
    typealias Entry = SimpleEntry

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), itemCount: 0, themeColorName: "blue")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), itemCount: 10, themeColorName: "blue")
        completion(entry)
    }

    // 修正：使用具體的 SimpleEntry 類型，而不是泛型的 Entry
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: appGroupID)
        let itemCount = userDefaults?.data(forKey: "clippedItems").flatMap {
            try? JSONDecoder().decode([ClipboardItem].self, from: $0).count
        } ?? 0
        let themeColorName = userDefaults?.string(forKey: "themeColorName") ?? "blue"

        let entry = SimpleEntry(date: Date(), itemCount: itemCount, themeColorName: themeColorName)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let itemCount: Int
    let themeColorName: String
}
