//
//  CreatorSubscriptionManager.swift
//  ClippyIsle
//
//  Manages creator follow/unfollow relationships and FCM topic subscriptions.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseMessaging

// MARK: - Creator Post Model
/// Represents a post created by a creator
struct CreatorPost: Codable, Identifiable {
    var id: String
    var creator_uid: String
    var title: String
    var content_url: String
    var curator_note: String?
    var created_at: Date
    
    init(id: String = UUID().uuidString, creator_uid: String, title: String, content_url: String, curator_note: String? = nil, created_at: Date = Date()) {
        self.id = id
        self.creator_uid = creator_uid
        self.title = title
        self.content_url = content_url
        self.curator_note = curator_note
        self.created_at = created_at
    }
}

// MARK: - Follower Relationship Model
/// Represents a follow relationship between a creator and follower
struct FollowerRelationship: Codable {
    var creator_uid: String
    var follower_uid: String
    var created_at: Date
    
    /// Composite document ID for unique relationship
    var documentID: String {
        return "\(creator_uid)_\(follower_uid)"
    }
    
    init(creator_uid: String, follower_uid: String, created_at: Date = Date()) {
        self.creator_uid = creator_uid
        self.follower_uid = follower_uid
        self.created_at = created_at
    }
}

// MARK: - Error Types
/// Errors that can occur during creator subscription operations
enum CreatorSubscriptionError: Int, Error, LocalizedError {
    case noAuthenticatedUser = 1
    case cannotFollowSelf = 2
    case networkError = 3
    
    var errorDescription: String? {
        switch self {
        case .noAuthenticatedUser:
            return "No authenticated user"
        case .cannotFollowSelf:
            return "Cannot follow yourself"
        case .networkError:
            return "Network error occurred"
        }
    }
}

// MARK: - Creator Subscription Manager
/// Manages creator follow/unfollow relationships and FCM topic subscriptions
@MainActor
class CreatorSubscriptionManager: ObservableObject {
    static let shared = CreatorSubscriptionManager()
    
    private let db = Firestore.firestore()
    private let followersCollection = "followers"
    private let creatorPostsCollection = "creator_posts"
    
    @Published var followedCreators: [String] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    private init() {
        // Empty init for performance - load data lazily
    }
    
    // MARK: - Follow User
    /// Follows a creator and subscribes to their FCM topic for notifications
    /// - Parameter targetUid: The UID of the creator to follow
    func followUser(targetUid: String) async throws {
        guard let currentUid = AuthenticationManager.shared.currentUID else {
            throw CreatorSubscriptionError.noAuthenticatedUser
        }
        
        // Don't allow self-follow
        guard currentUid != targetUid else {
            throw CreatorSubscriptionError.cannotFollowSelf
        }
        
        await MainActor.run { isLoading = true; error = nil }
        
        do {
            // Create follower relationship
            let relationship = FollowerRelationship(creator_uid: targetUid, follower_uid: currentUid)
            
            let docRef = db.collection(followersCollection).document(relationship.documentID)
            
            let relationshipData: [String: Any] = [
                "creator_uid": relationship.creator_uid,
                "follower_uid": relationship.follower_uid,
                "created_at": Timestamp(date: relationship.created_at)
            ]
            
            try await docRef.setData(relationshipData)
            print("✅ Created follow relationship: \(relationship.documentID)")
            
            // Subscribe to FCM topic for this creator
            let topic = "creator_\(targetUid)"
            try await subscribeToTopic(topic)
            print("✅ Subscribed to FCM topic: \(topic)")
            
            // Update local state
            await MainActor.run {
                if !followedCreators.contains(targetUid) {
                    followedCreators.append(targetUid)
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
            print("❌ Follow user failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Unfollow User
    /// Unfollows a creator and unsubscribes from their FCM topic
    /// - Parameter targetUid: The UID of the creator to unfollow
    func unfollowUser(targetUid: String) async throws {
        guard let currentUid = AuthenticationManager.shared.currentUID else {
            throw CreatorSubscriptionError.noAuthenticatedUser
        }
        
        await MainActor.run { isLoading = true; error = nil }
        
        do {
            // Delete follower relationship document
            let documentID = "\(targetUid)_\(currentUid)"
            let docRef = db.collection(followersCollection).document(documentID)
            
            try await docRef.delete()
            print("✅ Deleted follow relationship: \(documentID)")
            
            // Unsubscribe from FCM topic
            let topic = "creator_\(targetUid)"
            try await unsubscribeFromTopic(topic)
            print("✅ Unsubscribed from FCM topic: \(topic)")
            
            // Update local state
            await MainActor.run {
                followedCreators.removeAll { $0 == targetUid }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
            print("❌ Unfollow user failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Check if Following
    /// Checks if the current user is following a specific creator
    /// - Parameter targetUid: The UID of the creator to check
    /// - Returns: True if following, false otherwise
    func isFollowing(targetUid: String) async -> Bool {
        guard let currentUid = AuthenticationManager.shared.currentUID else {
            return false
        }
        
        let documentID = "\(targetUid)_\(currentUid)"
        let docRef = db.collection(followersCollection).document(documentID)
        
        do {
            let snapshot = try await docRef.getDocument()
            return snapshot.exists
        } catch {
            print("❌ Check following failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Load Followed Creators
    /// Loads the list of creators that the current user follows
    func loadFollowedCreators() async {
        guard let currentUid = AuthenticationManager.shared.currentUID else { return }
        
        await MainActor.run { isLoading = true }
        
        do {
            let snapshot = try await db.collection(followersCollection)
                .whereField("follower_uid", isEqualTo: currentUid)
                .getDocuments()
            
            let creatorUids = snapshot.documents.compactMap { doc -> String? in
                return doc.data()["creator_uid"] as? String
            }
            
            await MainActor.run {
                followedCreators = creatorUids
                isLoading = false
            }
            print("✅ Loaded \(creatorUids.count) followed creators")
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
            print("❌ Load followed creators failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Get Follower Count
    /// Gets the number of followers for a specific creator
    /// - Parameter creatorUid: The UID of the creator
    /// - Returns: The number of followers
    func getFollowerCount(creatorUid: String) async -> Int {
        do {
            let snapshot = try await db.collection(followersCollection)
                .whereField("creator_uid", isEqualTo: creatorUid)
                .getDocuments()
            
            return snapshot.documents.count
        } catch {
            print("❌ Get follower count failed: \(error.localizedDescription)")
            return 0
        }
    }
    
    // MARK: - Create Creator Post
    /// Creates a new post for the creator (triggers push notification via Cloud Function)
    /// - Parameters:
    ///   - title: The title of the post
    ///   - contentUrl: URL to the content/article
    ///   - curatorNote: Optional note/review from the curator
    func createPost(title: String, contentUrl: String, curatorNote: String? = nil) async throws {
        guard let currentUid = AuthenticationManager.shared.currentUID else {
            throw CreatorSubscriptionError.noAuthenticatedUser
        }
        
        let post = CreatorPost(
            creator_uid: currentUid,
            title: title,
            content_url: contentUrl,
            curator_note: curatorNote
        )
        
        let docRef = db.collection(creatorPostsCollection).document(post.id)
        
        var postData: [String: Any] = [
            "creator_uid": post.creator_uid,
            "title": post.title,
            "content_url": post.content_url,
            "created_at": Timestamp(date: post.created_at)
        ]
        
        // Only add curator_note if it has a value
        if let note = post.curator_note {
            postData["curator_note"] = note
        }
        
        try await docRef.setData(postData)
        print("✅ Created creator post: \(post.id)")
    }
    
    // MARK: - FCM Topic Management
    
    /// Subscribes to an FCM topic
    private func subscribeToTopic(_ topic: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Messaging.messaging().subscribe(toTopic: topic) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    /// Unsubscribes from an FCM topic
    private func unsubscribeFromTopic(_ topic: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Messaging.messaging().unsubscribe(fromTopic: topic) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
