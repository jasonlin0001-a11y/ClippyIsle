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

// MARK: - Tag Color
public struct TagColor: Codable, Equatable {
    public var tag: String
    public var red: Double
    public var green: Double
    public var blue: Double
    
    public init(tag: String, red: Double, green: Double, blue: Double) {
        self.tag = tag
        self.red = red
        self.green = green
        self.blue = blue
    }
}

// MARK: - Exportable Data (for import/export)
public struct ExportableData: Codable {
    public var items: [ExportableClipboardItem]
    public var tagColors: [TagColor]?
    
    public init(items: [ExportableClipboardItem], tagColors: [TagColor]? = nil) {
        self.items = items
        self.tagColors = tagColors
    }
}

// MARK: - Exportable Clipboard Item (for import/export)
public struct ExportableClipboardItem: Codable {
    public var id: UUID
    public var content: String
    public var type: String
    public var filename: String?
    public var timestamp: Date
    public var isPinned: Bool
    public var displayName: String?
    public var isTrashed: Bool
    public var tags: [String]?
    public var fileData: Data?
    
    public init(id: UUID, content: String, type: String, filename: String?, timestamp: Date, isPinned: Bool, displayName: String?, isTrashed: Bool, tags: [String]?, fileData: Data?) {
        self.id = id
        self.content = content
        self.type = type
        self.filename = filename
        self.timestamp = timestamp
        self.isPinned = isPinned
        self.displayName = displayName
        self.isTrashed = isTrashed
        self.tags = tags
        self.fileData = fileData
    }
}


// MARK: - Notification Item (for Message Center)
public struct NotificationItem: Identifiable, Codable, Equatable {
    public var id: UUID
    public var items: [ClipboardItem]  // The shared clipboard items
    public var timestamp: Date         // When the notification was received
    public var isRead: Bool            // Whether the user has viewed this notification
    public var source: NotificationSource  // Where the notification came from
    
    public enum NotificationSource: String, Codable {
        case appShare      // From app share extension
        case deepLink      // From URL deep link
    }
    
    public init(id: UUID = UUID(), items: [ClipboardItem], timestamp: Date = Date(), isRead: Bool = false, source: NotificationSource) {
        self.id = id
        self.items = items
        self.timestamp = timestamp
        self.isRead = isRead
        self.source = source
    }
    
    public static func == (lhs: NotificationItem, rhs: NotificationItem) -> Bool {
        lhs.id == rhs.id
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
        // Cement gray color matching the app logo (used in widgets)
        public static let cementGray = Color(red: 0.74, green: 0.74, blue: 0.74)
        
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
            // New accent colors for dark mode (neon/glowing)
            case "electricBlue": return ThemeColors.electricBlue
            case "neonGreen": return ThemeColors.neonGreen
            case "vibrantOrange": return ThemeColors.vibrantOrange
            // New accent colors for light mode (deeper for contrast)
            case "deepPurple": return ThemeColors.deepPurple
            case "royalBlue": return ThemeColors.royalBlue
            case "coralRed": return ThemeColors.coralRed
            default: return .blue
            }
        }
    }
}

// MARK: - Theme Colors
/// Adaptive colors for modern iOS design following Apple's HIG
/// Dark Mode: Uses different grey depths for layering, neon accent colors
/// Light Mode: Off-white background (#F2F2F7), pure white cards with soft shadows
public struct ThemeColors {
    
    // MARK: - Background Colors
    
    /// Main background color
    /// Light: Soft off-white (#F2F2F7 - Apple's systemGray6)
    /// Dark: Neutral black
    public static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.0, green: 0.0, blue: 0.0) // Neutral black
            : Color(red: 242/255, green: 242/255, blue: 247/255) // #F2F2F7 off-white
    }
    
    /// Secondary background for grouped content
    /// Light: System background
    /// Dark: Deep grey for layering
    public static func secondaryBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 28/255, green: 28/255, blue: 30/255) // Deep grey
            : Color(red: 242/255, green: 242/255, blue: 247/255) // #F2F2F7
    }
    
    // MARK: - Card/Surface Colors
    
    /// Floating card background
    /// Light: Pure white with soft shadows
    /// Dark: Sleek dark grey panel
    public static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 44/255, green: 44/255, blue: 46/255) // Sleek dark grey
            : Color.white // Pure white
    }
    
    /// Elevated surface (for modals, sheets)
    /// Light: White
    /// Dark: Lighter grey for elevation
    public static func elevatedSurface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 58/255, green: 58/255, blue: 60/255) // Lighter grey
            : Color.white
    }
    
    // MARK: - Text Colors
    
    /// Primary text color
    /// Light: Dark grey for clean typography
    /// Dark: High contrast white
    public static func primaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white
            : Color(red: 0.1, green: 0.1, blue: 0.1) // Dark grey
    }
    
    /// Secondary text color
    public static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.6, green: 0.6, blue: 0.6)
            : Color(red: 0.4, green: 0.4, blue: 0.4)
    }
    
    // MARK: - Accent Colors for Dark Mode (Neon/Glowing)
    
    /// Electric Blue - neon accent for dark mode
    public static let electricBlue = Color(red: 0/255, green: 199/255, blue: 255/255)
    
    /// Neon Green - glowing accent for dark mode
    public static let neonGreen = Color(red: 57/255, green: 255/255, blue: 20/255)
    
    /// Vibrant Orange - warm neon accent for dark mode
    public static let vibrantOrange = Color(red: 255/255, green: 149/255, blue: 0/255)
    
    // MARK: - Accent Colors for Light Mode (Deeper for contrast)
    
    /// Deep Purple - strong contrast for light mode
    public static let deepPurple = Color(red: 88/255, green: 86/255, blue: 214/255)
    
    /// Royal Blue - classic accent for light mode
    public static let royalBlue = Color(red: 0/255, green: 122/255, blue: 255/255)
    
    /// Coral Red - warm accent for light mode
    public static let coralRed = Color(red: 255/255, green: 69/255, blue: 58/255)
    
    // MARK: - Shadow Configuration
    
    /// Card shadow for light mode (soft drop shadow)
    public static func cardShadow(for colorScheme: ColorScheme) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        colorScheme == .dark
            ? (Color.clear, 0, 0, 0) // No shadow in dark mode - use grey depth instead
            : (Color.black.opacity(0.08), 8, 0, 4) // Soft drop shadow for light mode
    }
    
    // MARK: - Inner Glow for Dark Mode
    
    /// Soft inner glow color for dark mode cards
    public static func innerGlow(for colorScheme: ColorScheme, accent: Color) -> Color {
        colorScheme == .dark
            ? accent.opacity(0.15)
            : Color.clear
    }
    
    // MARK: - Border Colors
    
    /// Subtle border for cards
    public static func cardBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 58/255, green: 58/255, blue: 60/255) // Subtle grey border
            : Color.clear // No border in light mode, shadows provide depth
    }
}
