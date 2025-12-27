//
//  UserListViewModel.swift
//  ClippyIsle
//
//  ViewModel for fetching and managing lists of followers/following users.
//

import Foundation
import FirebaseFirestore
import Combine

// MARK: - User List Type
/// Enum to specify whether to load followers or following list
enum UserListType {
    case followers
    case following
    
    var title: String {
        switch self {
        case .followers: return "Followers"
        case .following: return "Following"
        }
    }
    
    var emptyMessage: String {
        switch self {
        case .followers: return "No followers yet"
        case .following: return "Not following anyone yet"
        }
    }
    
    var emptySubtitle: String {
        switch self {
        case .followers: return "Share your content to attract followers!"
        case .following: return "Go to Discovery to find creators to follow!"
        }
    }
}

// MARK: - User List Item
/// A simple model for displaying users in a list
struct UserListItem: Identifiable {
    var id: String { uid }
    var uid: String
    var displayName: String
    var avatarUrl: String?
    var timestamp: Date?
    
    init(uid: String, displayName: String = "Unknown", avatarUrl: String? = nil, timestamp: Date? = nil) {
        self.uid = uid
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.timestamp = timestamp
    }
}

// MARK: - User List ViewModel
/// ViewModel for fetching and managing user lists (followers/following)
@MainActor
class UserListViewModel: ObservableObject {
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    private let followingSubcollection = "following"
    private let followersSubcollection = "followers"
    
    @Published var users: [UserListItem] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    private let targetUserId: String
    private let listType: UserListType
    
    init(userId: String, listType: UserListType) {
        self.targetUserId = userId
        self.listType = listType
    }
    
    // MARK: - Fetch Users
    /// Fetches the list of users based on the list type
    func fetchUsers() async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            var userIds: [(String, Date?, String?)] = [] // (uid, timestamp, cachedName)
            
            switch listType {
            case .following:
                // Query: users/{targetUserId}/following
                let snapshot = try await db.collection(usersCollection)
                    .document(targetUserId)
                    .collection(followingSubcollection)
                    .order(by: "timestamp", descending: true)
                    .getDocuments()
                
                for doc in snapshot.documents {
                    let data = doc.data()
                    let uid = data["uid"] as? String ?? doc.documentID
                    let timestamp: Date?
                    if let ts = data["timestamp"] as? Timestamp {
                        timestamp = ts.dateValue()
                    } else {
                        timestamp = nil
                    }
                    let displayName = data["displayName"] as? String
                    userIds.append((uid, timestamp, displayName))
                }
                
            case .followers:
                // Query: users/{targetUserId}/followers
                let snapshot = try await db.collection(usersCollection)
                    .document(targetUserId)
                    .collection(followersSubcollection)
                    .order(by: "timestamp", descending: true)
                    .getDocuments()
                
                for doc in snapshot.documents {
                    let data = doc.data()
                    let uid = data["uid"] as? String ?? doc.documentID
                    let timestamp: Date?
                    if let ts = data["timestamp"] as? Timestamp {
                        timestamp = ts.dateValue()
                    } else {
                        timestamp = nil
                    }
                    let displayName = data["displayName"] as? String
                    userIds.append((uid, timestamp, displayName))
                }
            }
            
            print("📦 [UserListViewModel] Found \(userIds.count) \(listType.title.lowercased())")
            
            // Fetch full user profiles for users without cached names
            var fetchedUsers: [UserListItem] = []
            
            for (uid, timestamp, cachedName) in userIds {
                if let name = cachedName, !name.isEmpty {
                    // Use cached name
                    fetchedUsers.append(UserListItem(
                        uid: uid,
                        displayName: name,
                        avatarUrl: nil, // Will be loaded from user doc if needed
                        timestamp: timestamp
                    ))
                } else {
                    // Fetch full profile
                    if let profile = await fetchUserProfile(uid: uid) {
                        fetchedUsers.append(UserListItem(
                            uid: uid,
                            displayName: profile.displayName,
                            avatarUrl: profile.avatarUrl,
                            timestamp: timestamp
                        ))
                    } else {
                        // Fallback with placeholder name
                        fetchedUsers.append(UserListItem(
                            uid: uid,
                            displayName: "User_\(uid.suffix(4))",
                            avatarUrl: nil,
                            timestamp: timestamp
                        ))
                    }
                }
            }
            
            await MainActor.run {
                self.users = fetchedUsers
                self.isLoading = false
            }
            
            print("✅ [UserListViewModel] Loaded \(fetchedUsers.count) users")
            
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
            print("❌ [UserListViewModel] Fetch error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Fetch Single User Profile
    /// Fetches a single user's profile
    private func fetchUserProfile(uid: String) async -> (displayName: String, avatarUrl: String?)? {
        do {
            let doc = try await db.collection(usersCollection).document(uid).getDocument()
            
            if let data = doc.data() {
                let displayName = data["nickname"] as? String ?? data["displayName"] as? String ?? "User_\(uid.suffix(4))"
                let avatarUrl = data["avatar_url"] as? String ?? data["profileImageUrl"] as? String
                return (displayName, avatarUrl)
            }
        } catch {
            print("⚠️ [UserListViewModel] Failed to fetch profile for \(uid): \(error.localizedDescription)")
        }
        return nil
    }
    
    // MARK: - Refresh
    /// Refreshes the user list
    func refresh() async {
        await fetchUsers()
    }
}
