import SwiftUI
import UniformTypeIdentifiers

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

// MARK: - Export Helpers

struct ExportHelper {
    // Delay before showing share sheet after alert (in seconds)
    private static let shareSheetDelay: TimeInterval = 0.5
    
    static func handleExportResult(_ result: ClipboardManager.ExportResult, 
                                   showAlert: @escaping (String) -> Void,
                                   setExportURL: @escaping (URL) -> Void) {
        switch result.format {
        case .urlScheme(let urlString):
            // Short content - share ccisle:// URL
            let sizeInKB = Double(result.estimatedSize) / 1024.0
            let message = String(format: "Short content detected (%.1f KB)\n\nExporting as ccisle:// URL link.\nThis can be easily shared through messaging apps.", sizeInKB)
            showAlert(message)
            
            // After showing alert, share the URL
            DispatchQueue.main.asyncAfter(deadline: .now() + shareSheetDelay) {
                shareURLScheme(urlString, onError: { errorMessage in
                    showAlert("Failed to share: \(errorMessage)")
                })
            }
            
        case .json(let url):
            // Long content - share JSON file
            let sizeInKB = Double(result.estimatedSize) / 1024.0
            let message = String(format: "Large content detected (%.1f KB)\n\nExporting as standard .json backup file.\nThis format works well with all apps including LINE.", sizeInKB)
            showAlert(message)
            setExportURL(url)
        }
    }
    
    static func shareURLScheme(_ urlString: String, onError: @escaping (String) -> Void) {
        // Use modern approach for iOS 15+
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            onError("Unable to find window scene")
            return
        }
        
        guard let rootViewController = windowScene.windows.first?.rootViewController else {
            onError("Unable to find root view controller")
            return
        }
        
        let activityVC = UIActivityViewController(activityItems: [urlString], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootViewController.view
            popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, 
                                       y: rootViewController.view.bounds.midY, 
                                       width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        rootViewController.present(activityVC, animated: true)
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