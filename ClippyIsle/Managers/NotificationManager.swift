import SwiftUI
import UserNotifications

// MARK: - Notification Manager
/// Manages shared notifications received from app shares and deep links
/// Stores notifications persistently and tracks unread count for badge display
@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var notifications: [NotificationItem] = []
    @Published var unreadCount: Int = 0
    
    private let userDefaults: UserDefaults
    private let notificationsKey = "messageCenter_notifications"
    private let pendingNotificationsKey = "pendingNotifications"
    
    private init() {
        if let defaults = UserDefaults(suiteName: appGroupID) {
            self.userDefaults = defaults
        } else {
            self.userDefaults = UserDefaults.standard
        }
        loadNotifications()
        updateUnreadCount()
    }
    
    // MARK: - Persistence
    
    private func loadNotifications() {
        guard let data = userDefaults.data(forKey: notificationsKey) else {
            notifications = []
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode([NotificationItem].self, from: data)
            notifications = decoded.sorted { $0.timestamp > $1.timestamp }
        } catch {
            print("❌ Failed to load notifications: \(error.localizedDescription)")
            notifications = []
        }
    }
    
    private func saveNotifications() {
        do {
            let data = try JSONEncoder().encode(notifications)
            userDefaults.set(data, forKey: notificationsKey)
            updateUnreadCount()
            updateAppBadge()
        } catch {
            print("❌ Failed to save notifications: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Badge Management
    
    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }
    
    private func updateAppBadge() {
        UNUserNotificationCenter.current().requestAuthorization(options: .badge) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UNUserNotificationCenter.current().setBadgeCount(self.unreadCount)
                }
            }
        }
    }
    
    // MARK: - Pending Notifications (from Share Extension)
    
    /// Structure to match what the Share Extension creates
    private struct PendingNotification: Codable {
        var id: UUID
        var items: [ClipboardItem]
        var timestamp: Date
        var source: String
    }
    
    /// Checks for and migrates any pending notifications from the Share Extension
    /// Call this when the app becomes active
    func checkForPendingNotifications() {
        guard let data = userDefaults.data(forKey: pendingNotificationsKey),
              let pendingNotifications = try? JSONDecoder().decode([PendingNotification].self, from: data),
              !pendingNotifications.isEmpty else {
            return
        }
        
        print("📬 Found \(pendingNotifications.count) pending notification(s) from Share Extension")
        
        // Convert pending notifications to NotificationItems
        for pending in pendingNotifications {
            let source: NotificationItem.NotificationSource = pending.source == "appShare" ? .appShare : .deepLink
            let notification = NotificationItem(
                id: pending.id,
                items: pending.items,
                timestamp: pending.timestamp,
                isRead: false,
                source: source
            )
            
            // Avoid duplicates
            if !notifications.contains(where: { $0.id == notification.id }) {
                notifications.insert(notification, at: 0)
            }
        }
        
        // Sort and save
        notifications.sort { $0.timestamp > $1.timestamp }
        saveNotifications()
        
        // Clear pending notifications
        userDefaults.removeObject(forKey: pendingNotificationsKey)
        print("✅ Migrated \(pendingNotifications.count) notification(s) to Message Center")
    }
    
    // MARK: - Notification Operations
    
    /// Adds a new notification with the given shared items
    func addNotification(items: [ClipboardItem], source: NotificationItem.NotificationSource) {
        let notification = NotificationItem(items: items, source: source)
        notifications.insert(notification, at: 0)
        saveNotifications()
        print("📬 Added notification with \(items.count) item(s) from \(source.rawValue)")
    }
    
    /// Marks a notification as read
    func markAsRead(_ notification: NotificationItem) {
        guard let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        notifications[index].isRead = true
        saveNotifications()
    }
    
    /// Marks all notifications as read
    func markAllAsRead() {
        for index in notifications.indices {
            notifications[index].isRead = true
        }
        saveNotifications()
    }
    
    /// Deletes a notification
    func deleteNotification(_ notification: NotificationItem) {
        notifications.removeAll { $0.id == notification.id }
        saveNotifications()
    }
    
    /// Deletes multiple notifications
    func deleteNotifications(at offsets: IndexSet) {
        notifications.remove(atOffsets: offsets)
        saveNotifications()
    }
    
    /// Clears all notifications
    func clearAll() {
        notifications.removeAll()
        saveNotifications()
    }
    
    /// Gets items from a notification and marks it as read
    func getItemsAndMarkRead(_ notification: NotificationItem) -> [ClipboardItem] {
        markAsRead(notification)
        return notification.items
    }
}
