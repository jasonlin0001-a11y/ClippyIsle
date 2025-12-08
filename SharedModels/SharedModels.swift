import Foundation
import SwiftUI
import ActivityKit
import UniformTypeIdentifiers

// MARK: - Global Constants & Functions
public let appGroupID = "group.com.shihchieh.clippyisle"

public func saveFileDataToAppGroup(data: Data, type: String) -> String? {
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
        print("❌ 儲存檔案失敗：無法取得共享容器 URL。")
        return nil
    }

    let id = UUID().uuidString
    let utType = UTType(type)
    let fileExtension = utType?.preferredFilenameExtension ?? "data"
    let filename = "\(id).\(fileExtension)"
    let fileURL = containerURL.appendingPathComponent(filename)

    do {
        try data.write(to: fileURL)
        print("✅ 成功將檔案寫入: \(filename)")
        return filename
    } catch {
        print("❌ 寫入檔案 \(filename) 失敗: \(error.localizedDescription)")
        return nil
    }
}

// MARK: - Clipboard Item Data Model
public struct ClipboardItem: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var content: String
    public var type: String
    public var filename: String?
    public var timestamp: Date
    public var isPinned: Bool
    public var displayName: String?
    public var isTrashed: Bool
    
    // 【新增】標籤屬性
    public var tags: [String]?
    
    public var fileData: Data?

    // 【修改】初始化方法加入 tags
    public init(id: UUID = UUID(), content: String, type: String, filename: String? = nil, timestamp: Date = Date(), isPinned: Bool = false, displayName: String? = nil, isTrashed: Bool = false, tags: [String]? = nil, fileData: Data? = nil) {
        self.id = id
        self.content = content
        self.type = type
        self.filename = filename
        self.timestamp = timestamp
        self.isPinned = isPinned
        self.displayName = displayName
        self.isTrashed = isTrashed
        self.tags = tags // 設定 tags
        self.fileData = fileData
    }

    // 【修改】CodingKeys 加入 tags
    enum CodingKeys: String, CodingKey {
        case id, content, type, filename, timestamp, isPinned, displayName, isTrashed, tags
    }

    public static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Live Activity Attributes
public struct ClippyIsleAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var itemCount: Int
        public var themeColorName: String
        public var itemsLabel: String
    }
}

// MARK: - Color Utility
public extension ClippyIsleAttributes {
    struct ColorUtility {
        public static func color(forName name: String) -> Color {
            switch name {
            case "green": return .green
            case "orange": return .orange
            case "red": return .red
            case "pink": return .pink
            case "purple": return .purple
            case "black": return .black
            case "white": return .white
            case "retro": return Color(red: 214/255, green: 196/255, blue: 169/255) // 復古牛皮紙色
            default: return .blue
            }
        }
    }
}
