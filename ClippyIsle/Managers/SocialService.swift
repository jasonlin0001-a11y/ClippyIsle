//
//  SocialService.swift
//  ClippyIsle
//
//  Service for managing user following relationships using Firestore subcollections.
//  Path: users/{currentUserId}/following/{targetUserId}
//

import Foundation
import Combine
import FirebaseFirestore

// MARK: - Following Relationship Model
/// Represents a follow relationship stored in the user's following subcollection
struct FollowingEntry: Codable, Identifiable {
    var id: String { uid }
    var uid: String
    var timestamp: Date
    var displayName: String?
    
    init(uid: String, timestamp: Date = Date(), displayName: String? = nil) {
        self.uid = uid
        self.timestamp = timestamp
        self.displayName = displayName
    }
}

// MARK: - Social Service Error
enum SocialServiceError: Error, LocalizedError {
    case noAuthenticatedUser
    case cannotFollowSelf
    case networkError(String)
    case userNotFound
    
    var errorDescription: String? {
        switch self {
        case .noAuthenticatedUser:
            return "You must be signed in to follow users"
        case .cannotFollowSelf:
            return "You cannot follow yourself"
        case .networkError(let message):
            return "Network error: \(message)"
        case .userNotFound:
            return "User not found"
        }
    }
}

// MARK: - Social Service
/// Manages user following relationships using Firestore subcollections
/// Path: users/{currentUserId}/following/{targetUserId}
@MainActor
class SocialService: ObservableObject {
    static let shared = SocialService()
    
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    private let followingSubcollection = "following"
    
    /// Set of UIDs that the current user is following (cached locally)
    @Published var followingSet: Set<String> = []
    
    /// List of following entries with metadata
    @Published var followingList: [FollowingEntry] = []
    
    /// Loading state
    @Published var isLoading: Bool = false
    
    /// Last error message
    @Published var error: String?
    
    private var followingListener: ListenerRegistration?
    
    private init() {
        // Empty init - load data lazily when needed
    }
    
    deinit {
        followingListener?.remove()
    }
    
    // MARK: - Follow User
    /// Follows a target user by adding a document to the current user's following subcollection
    /// - Parameter targetUid: The UID of the user to follow
    /// - Parameter displayName: Optional cached display name for quick listing
    func followUser(targetUid: String, displayName: String? = nil) async throws {
        guard let currentUid = AuthenticationManager.shared.currentUID else {
            throw SocialServiceError.noAuthenticatedUser
        }
        
        guard currentUid != targetUid else {
            throw SocialServiceError.cannotFollowSelf
        }
        
        isLoading = true
        error = nil
        
        do {
            // Path: users/{currentUid}/following/{targetUid}
            let followingDocRef = db.collection(usersCollection)
                .document(currentUid)
                .collection(followingSubcollection)
                .document(targetUid)
            
            let entry = FollowingEntry(uid: targetUid, displayName: displayName)
            
            let data: [String: Any] = [
                "uid": entry.uid,
                "timestamp": Timestamp(date: entry.timestamp),
                "displayName": entry.displayName ?? NSNull()
            ]
            
            try await followingDocRef.setData(data)
            print("✅ [SocialService] Followed user: \(targetUid)")
            
            // Increment followersCount on target user's document
            try await incrementFollowersCount(targetUid: targetUid)
            
            // Update local cache
            followingSet.insert(targetUid)
            if !followingList.contains(where: { $0.uid == targetUid }) {
                followingList.insert(entry, at: 0)
            }
            
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            print("❌ [SocialService] Follow user failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Unfollow User
    /// Unfollows a target user by removing the document from the following subcollection
    /// - Parameter targetUid: The UID of the user to unfollow
    func unfollowUser(targetUid: String) async throws {
        guard let currentUid = AuthenticationManager.shared.currentUID else {
            throw SocialServiceError.noAuthenticatedUser
        }
        
        isLoading = true
        error = nil
        
        do {
            // Path: users/{currentUid}/following/{targetUid}
            let followingDocRef = db.collection(usersCollection)
                .document(currentUid)
                .collection(followingSubcollection)
                .document(targetUid)
            
            try await followingDocRef.delete()
            print("✅ [SocialService] Unfollowed user: \(targetUid)")
            
            // Decrement followersCount on target user's document
            try await decrementFollowersCount(targetUid: targetUid)
            
            // Update local cache
            followingSet.remove(targetUid)
            followingList.removeAll { $0.uid == targetUid }
            
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            print("❌ [SocialService] Unfollow user failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Check If Following
    /// Checks if the current user is following a specific user
    /// Uses local cache for immediate response, with optional server verification
    /// - Parameter targetUid: The UID of the user to check
    /// - Returns: True if following, false otherwise
    func checkIfFollowing(targetUid: String) -> Bool {
        return followingSet.contains(targetUid)
    }
    
    /// Checks if following by querying Firestore directly (for accuracy)
    /// - Parameter targetUid: The UID of the user to check
    /// - Returns: True if following, false otherwise
    func checkIfFollowingAsync(targetUid: String) async -> Bool {
        guard let currentUid = AuthenticationManager.shared.currentUID else {
            return false
        }
        
        let followingDocRef = db.collection(usersCollection)
            .document(currentUid)
            .collection(followingSubcollection)
            .document(targetUid)
        
        do {
            let snapshot = try await followingDocRef.getDocument()
            let isFollowing = snapshot.exists
            
            // Update local cache
            if isFollowing {
                followingSet.insert(targetUid)
            } else {
                followingSet.remove(targetUid)
            }
            
            return isFollowing
        } catch {
            print("❌ [SocialService] Check following failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Load Following List
    /// Loads the list of users that the current user is following
    func loadFollowingList() async {
        guard let currentUid = AuthenticationManager.shared.currentUID else { return }
        
        isLoading = true
        
        do {
            let snapshot = try await db.collection(usersCollection)
                .document(currentUid)
                .collection(followingSubcollection)
                .order(by: "timestamp", descending: true)
                .getDocuments()
            
            var entries: [FollowingEntry] = []
            var uids: Set<String> = []
            
            for doc in snapshot.documents {
                let data = doc.data()
                let uid = data["uid"] as? String ?? doc.documentID
                let timestamp: Date
                if let ts = data["timestamp"] as? Timestamp {
                    timestamp = ts.dateValue()
                } else {
                    timestamp = Date()
                }
                let displayName = data["displayName"] as? String
                
                let entry = FollowingEntry(uid: uid, timestamp: timestamp, displayName: displayName)
                entries.append(entry)
                uids.insert(uid)
            }
            
            followingList = entries
            followingSet = uids
            isLoading = false
            
            print("✅ [SocialService] Loaded \(entries.count) following entries")
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            print("❌ [SocialService] Load following list failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Setup Real-time Listener
    /// Sets up a real-time listener for the following subcollection
    func setupFollowingListener() {
        guard let currentUid = AuthenticationManager.shared.currentUID else { return }
        
        // Remove existing listener
        followingListener?.remove()
        
        followingListener = db.collection(usersCollection)
            .document(currentUid)
            .collection(followingSubcollection)
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ [SocialService] Listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    var entries: [FollowingEntry] = []
                    var uids: Set<String> = []
                    
                    for doc in documents {
                        let data = doc.data()
                        let uid = data["uid"] as? String ?? doc.documentID
                        let timestamp: Date
                        if let ts = data["timestamp"] as? Timestamp {
                            timestamp = ts.dateValue()
                        } else {
                            timestamp = Date()
                        }
                        let displayName = data["displayName"] as? String
                        
                        let entry = FollowingEntry(uid: uid, timestamp: timestamp, displayName: displayName)
                        entries.append(entry)
                        uids.insert(uid)
                    }
                    
                    self.followingList = entries
                    self.followingSet = uids
                    print("📡 [SocialService] Following list updated: \(entries.count) entries")
                }
            }
    }
    
    // MARK: - Get Following Count
    /// Gets the number of users the current user is following
    /// - Returns: The count of following users
    func getFollowingCount() -> Int {
        return followingSet.count
    }
    
    // MARK: - Get Followers Count
    /// Gets the follower count for a specific user from their profile
    /// - Parameter uid: The user's UID
    /// - Returns: The follower count
    func getFollowersCount(uid: String) async -> Int {
        do {
            let snapshot = try await db.collection(usersCollection).document(uid).getDocument()
            return snapshot.data()?["followersCount"] as? Int ?? 0
        } catch {
            print("❌ [SocialService] Get followers count failed: \(error.localizedDescription)")
            return 0
        }
    }
    
    // MARK: - Private Helpers
    
    /// Increments the followersCount on the target user's document
    private func incrementFollowersCount(targetUid: String) async throws {
        let targetUserRef = db.collection(usersCollection).document(targetUid)
        try await targetUserRef.updateData([
            "followersCount": FieldValue.increment(Int64(1))
        ])
        print("📊 [SocialService] Incremented followers count for: \(targetUid)")
    }
    
    /// Decrements the followersCount on the target user's document
    private func decrementFollowersCount(targetUid: String) async throws {
        let targetUserRef = db.collection(usersCollection).document(targetUid)
        try await targetUserRef.updateData([
            "followersCount": FieldValue.increment(Int64(-1))
        ])
        print("📊 [SocialService] Decremented followers count for: \(targetUid)")
    }
    
    // MARK: - Cleanup
    /// Removes the following listener
    func removeListener() {
        followingListener?.remove()
        followingListener = nil
    }
}

// Note: FollowButton component has been moved to Views/Components/FollowButton.swift
