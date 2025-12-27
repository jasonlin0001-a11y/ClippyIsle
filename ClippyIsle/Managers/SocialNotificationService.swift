//
//  SocialNotificationService.swift
//  ClippyIsle
//
//  Service for managing social notifications (new followers, etc.)
//  Stores notifications in Firestore: users/{uid}/notifications/{notificationId}
//

import Foundation
import Combine
import FirebaseFirestore

// MARK: - Social Notification Service
/// Manages social notifications using Firestore
@MainActor
class SocialNotificationService: ObservableObject {
    static let shared = SocialNotificationService()
    
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    private let notificationsSubcollection = "notifications"
    
    /// List of notifications for the current user
    @Published var notifications: [SocialNotification] = []
    
    /// Count of unread notifications
    @Published var unreadCount: Int = 0
    
    /// Loading state
    @Published var isLoading: Bool = false
    
    /// Error message
    @Published var error: String?
    
    private var notificationsListener: ListenerRegistration?
    
    private init() {
        // Empty init - load data lazily when needed
    }
    
    deinit {
        notificationsListener?.remove()
    }
    
    // MARK: - Listen to Notifications
    /// Sets up a real-time listener for notifications
    func listenToNotifications() {
        guard let currentUid = AuthenticationManager.shared.currentUID else {
            print("❌ [SocialNotificationService] No authenticated user")
            return
        }
        
        // Remove existing listener
        notificationsListener?.remove()
        
        print("🔔 [SocialNotificationService] Setting up notifications listener for user: \(currentUid)")
        
        notificationsListener = db.collection(usersCollection)
            .document(currentUid)
            .collection(notificationsSubcollection)
            .order(by: "timestamp", descending: true)
            .limit(to: 50) // Limit to recent 50 notifications
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ [SocialNotificationService] Listener error: \(error.localizedDescription)")
                    Task { @MainActor in
                        self.error = error.localizedDescription
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("📭 [SocialNotificationService] No notifications found")
                    return
                }
                
                Task { @MainActor in
                    var notificationsList: [SocialNotification] = []
                    
                    for doc in documents {
                        let data = doc.data()
                        if let notification = SocialNotification(id: doc.documentID, data: data) {
                            notificationsList.append(notification)
                        }
                    }
                    
                    self.notifications = notificationsList
                    self.unreadCount = notificationsList.filter { !$0.isRead }.count
                    print("🔔 [SocialNotificationService] Loaded \(notificationsList.count) notifications, \(self.unreadCount) unread")
                }
            }
    }
    
    // MARK: - Mark as Read
    /// Marks a notification as read
    func markAsRead(notificationId: String) async throws {
        guard let currentUid = AuthenticationManager.shared.currentUID else {
            throw SocialServiceError.noAuthenticatedUser
        }
        
        let notificationRef = db.collection(usersCollection)
            .document(currentUid)
            .collection(notificationsSubcollection)
            .document(notificationId)
        
        try await notificationRef.updateData(["isRead": true])
        
        // Update local state
        if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
            notifications[index].isRead = true
            unreadCount = notifications.filter { !$0.isRead }.count
        }
        
        print("✅ [SocialNotificationService] Marked notification as read: \(notificationId)")
    }
    
    // MARK: - Mark All as Read
    /// Marks all notifications as read
    func markAllAsRead() async throws {
        guard let currentUid = AuthenticationManager.shared.currentUID else {
            throw SocialServiceError.noAuthenticatedUser
        }
        
        let batch = db.batch()
        
        for notification in notifications where !notification.isRead {
            let notificationRef = db.collection(usersCollection)
                .document(currentUid)
                .collection(notificationsSubcollection)
                .document(notification.id)
            batch.updateData(["isRead": true], forDocument: notificationRef)
        }
        
        try await batch.commit()
        
        // Update local state
        for index in notifications.indices {
            notifications[index].isRead = true
        }
        unreadCount = 0
        
        print("✅ [SocialNotificationService] Marked all notifications as read")
    }
    
    // MARK: - Delete Notification
    /// Deletes a notification
    func deleteNotification(notificationId: String) async throws {
        guard let currentUid = AuthenticationManager.shared.currentUID else {
            throw SocialServiceError.noAuthenticatedUser
        }
        
        let notificationRef = db.collection(usersCollection)
            .document(currentUid)
            .collection(notificationsSubcollection)
            .document(notificationId)
        
        try await notificationRef.delete()
        
        // Update local state
        notifications.removeAll { $0.id == notificationId }
        unreadCount = notifications.filter { !$0.isRead }.count
        
        print("✅ [SocialNotificationService] Deleted notification: \(notificationId)")
    }
    
    // MARK: - Create Notification
    /// Creates a notification for a target user (called when following someone)
    /// - Parameters:
    ///   - targetUid: The user who will receive the notification
    ///   - type: The type of notification
    ///   - fromUserId: The user who triggered the notification
    ///   - fromUserName: Display name of the triggering user
    ///   - fromUserAvatarUrl: Avatar URL of the triggering user (optional)
    func createNotification(
        targetUid: String,
        type: SocialNotificationType,
        fromUserId: String,
        fromUserName: String,
        fromUserAvatarUrl: String? = nil
    ) async throws {
        let notification = SocialNotification(
            type: type,
            fromUserId: fromUserId,
            fromUserName: fromUserName,
            fromUserAvatarUrl: fromUserAvatarUrl
        )
        
        let notificationRef = db.collection(usersCollection)
            .document(targetUid)
            .collection(notificationsSubcollection)
            .document(notification.id)
        
        try await notificationRef.setData(notification.toFirestoreData())
        
        print("🔔 [SocialNotificationService] Created \(type.rawValue) notification for user: \(targetUid)")
    }
    
    // MARK: - Cleanup
    /// Removes the notifications listener
    func removeListener() {
        notificationsListener?.remove()
        notificationsListener = nil
    }
}
