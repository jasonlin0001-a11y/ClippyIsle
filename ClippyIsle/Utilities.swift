import SwiftUI
import UniformTypeIdentifiers

// MARK: - Global Helper Functions

func itemIcon(for type: String) -> String {
    if type == UTType.url.identifier { return "link" }
    else if type == UTType.png.identifier { return "photo" }
    else if type == UTType.pdf.identifier { return "doc.text.fill" }
    else if type == UTType.rtfd.identifier { return "doc.richtext" }
    else if let utType = UTType(type), utType.conforms(to: .image) { return "photo" }
    else {
        if type.contains("html") { return "safari" }
        return "doc.text"
    }
}

// MARK: - Enums

enum AppearanceMode: Int, CaseIterable, Identifiable {
    case system = 0
    case light = 1
    case dark = 2

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .system: return String(localized: "System")
        case .light: return String(localized: "Light")
        case .dark: return String(localized: "Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Date Extensions

extension Date {
    func timeAgoDisplay() -> String {
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate the difference in components
        let components = calendar.dateComponents([.minute, .hour, .day], from: self, to: now)
        
        // Check if it's within the last 24 hours (less than 1 day difference)
        if let day = components.day, day < 1 {
            if let hour = components.hour, hour > 0 {
                return "\(hour) " + String(localized: "hr ago")
            } else if let minute = components.minute, minute > 0 {
                return "\(minute) " + String(localized: "min ago")
            } else {
                return String(localized: "Just now")
            }
        } else {
            // Older than 24 hours: Use YYYY/MM/DD format
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd"
            return formatter.string(from: self)
        }
    }
}

// MARK: - App Version Utility

struct AppVersion {
    static var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}