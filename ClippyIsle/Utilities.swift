import SwiftUI
import UniformTypeIdentifiers
import Combine

// MARK: - Global Helper Functions

func itemIcon(for type: String) -> String {
    if type == UTType.url.identifier { return "L" }
    else if type == UTType.png.identifier { return "P" }
    else if type == UTType.pdf.identifier { return "D" }
    else if type == UTType.rtfd.identifier { return "R" }
    else if let utType = UTType(type), utType.conforms(to: .image) { return "P" }
    else {
        if type.contains("html") { return "H" }
        return "T"
    }
}

// MARK: - Pending Share Manager
/// Manages pending shared items received from Firebase share links
/// Used to communicate between ClippyIsleApp (which handles deep links) and ContentView (which shows the import dialog)
class PendingShareManager: ObservableObject {
    static let shared = PendingShareManager()
    
    @Published var pendingItems: [ClipboardItem] = []
    @Published var showImportDialog: Bool = false
    
    private init() {}
    
    /// Sets pending items and triggers the import dialog
    func setPendingItems(_ items: [ClipboardItem]) {
        DispatchQueue.main.async {
            self.pendingItems = items
            self.showImportDialog = true
        }
    }
    
    /// Clears pending items after import or dismissal
    func clearPendingItems() {
        pendingItems = []
        showImportDialog = false
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

// MARK: - Theme-Aware Card View Modifier
/// A view modifier that applies modern iOS card styling based on color scheme
/// Dark Mode: Uses grey depth layering with optional inner glow
/// Light Mode: Pure white cards with soft drop shadows
struct ThemedCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var cornerRadius: CGFloat = 16
    var accentColor: Color? = nil
    
    func body(content: Content) -> some View {
        let shadowConfig = ThemeColors.cardShadow(for: colorScheme)
        
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(ThemeColors.cardBackground(for: colorScheme))
            )
            .overlay(
                // Inner glow for dark mode
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        ThemeColors.innerGlow(for: colorScheme, accent: accentColor ?? .blue),
                        lineWidth: colorScheme == .dark ? 1 : 0
                    )
            )
            .overlay(
                // Border for dark mode
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(ThemeColors.cardBorder(for: colorScheme), lineWidth: colorScheme == .dark ? 0.5 : 0)
            )
            .shadow(
                color: shadowConfig.color,
                radius: shadowConfig.radius,
                x: shadowConfig.x,
                y: shadowConfig.y
            )
    }
}

// MARK: - View Extension for Theme Cards
extension View {
    /// Applies modern iOS card styling that adapts to light/dark mode
    /// - Parameters:
    ///   - cornerRadius: Corner radius of the card (default: 16)
    ///   - accentColor: Optional accent color for dark mode inner glow
    func themedCard(cornerRadius: CGFloat = 16, accentColor: Color? = nil) -> some View {
        modifier(ThemedCardModifier(cornerRadius: cornerRadius, accentColor: accentColor))
    }
    
    /// Applies themed background color based on color scheme
    func themedBackground(_ colorScheme: ColorScheme) -> some View {
        self.background(ThemeColors.background(for: colorScheme))
    }
}