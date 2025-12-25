//
//  SocialNotification.swift
//  ClippyIsle
//
//  Model for social notifications (new followers, etc.)
//

import Foundation
import FirebaseFirestore

// MARK: - Notification Type
/// Types of social notifications
enum SocialNotificationType: String, Codable {
    case newFollower = "newFollower"
    case systemMessage = "systemMessage"
    
    var localizedDescription: String {
        switch self {
        case .newFollower:
            return "started following you"
        case .systemMessage:
            return "System message"
        }
    }
    
    var iconName: String {
        switch self {
        case .newFollower:
            return "person.badge.plus.fill"
        case .systemMessage:
            return "bell.fill"
        }
    }
}

// MARK: - Social Notification Model
/// Represents a social notification (e.g., new follower)
struct SocialNotification: Identifiable, Codable {
    var id: String
    var type: SocialNotificationType
    var fromUserId: String
    var fromUserName: String
    var fromUserAvatarUrl: String?
    var timestamp: Date
    var isRead: Bool
    
    init(
        id: String = UUID().uuidString,
        type: SocialNotificationType,
        fromUserId: String,
        fromUserName: String,
        fromUserAvatarUrl: String? = nil,
        timestamp: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.type = type
        self.fromUserId = fromUserId
        self.fromUserName = fromUserName
        self.fromUserAvatarUrl = fromUserAvatarUrl
        self.timestamp = timestamp
        self.isRead = isRead
    }
    
    /// Creates a notification from Firestore document data
    init?(id: String, data: [String: Any]) {
        guard let typeRaw = data["type"] as? String,
              let type = SocialNotificationType(rawValue: typeRaw),
              let fromUserId = data["fromUserId"] as? String,
              let fromUserName = data["fromUserName"] as? String else {
            return nil
        }
        
        self.id = id
        self.type = type
        self.fromUserId = fromUserId
        self.fromUserName = fromUserName
        self.fromUserAvatarUrl = data["fromUserAvatarUrl"] as? String
        self.isRead = data["isRead"] as? Bool ?? false
        
        // Handle timestamp - check for Firestore Timestamp first
        if let firestoreTimestamp = data["timestamp"] as? Timestamp {
            self.timestamp = firestoreTimestamp.dateValue()
        } else if let timestamp = data["timestamp"] as? Double {
            self.timestamp = Date(timeIntervalSince1970: timestamp)
        } else {
            self.timestamp = Date()
        }
    }
    
    /// Converts to Firestore document data
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "type": type.rawValue,
            "fromUserId": fromUserId,
            "fromUserName": fromUserName,
            "timestamp": Timestamp(date: timestamp),
            "isRead": isRead
        ]
        
        if let avatarUrl = fromUserAvatarUrl {
            data["fromUserAvatarUrl"] = avatarUrl
        }
        
        return data
    }
}
