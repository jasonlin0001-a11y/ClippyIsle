//
//  CreatorProfileViewModel.swift
//  ClippyIsle
//
//  ViewModel for the Creator Profile page - fetches user details and posts.
//

import Foundation
import FirebaseFirestore
import Combine

// MARK: - Creator Profile Model
/// Represents a creator's profile with their details
struct CreatorProfile {
    var uid: String
    var displayName: String
    var bio: String?
    var avatarUrl: String?
    var followersCount: Int
    var followingCount: Int
    var isCurator: Bool
    
    init(uid: String, displayName: String = "Unknown", bio: String? = nil, avatarUrl: String? = nil, followersCount: Int = 0, followingCount: Int = 0, isCurator: Bool = false) {
        self.uid = uid
        self.displayName = displayName
        self.bio = bio
        self.avatarUrl = avatarUrl
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.isCurator = isCurator
    }
}

// MARK: - Creator Profile ViewModel
/// ViewModel for fetching and managing Creator Profile data
@MainActor
class CreatorProfileViewModel: ObservableObject {
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    private let postsCollection = "creator_posts"
    
    @Published var profile: CreatorProfile?
    @Published var posts: [FeedPost] = []
    @Published var isLoadingProfile: Bool = false
    @Published var isLoadingPosts: Bool = false
    @Published var error: String?
    
    private let targetUid: String
    
    init(targetUid: String) {
        self.targetUid = targetUid
    }
    
    // MARK: - Fetch All Data
    /// Fetches both profile and posts
    func fetchAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchProfile() }
            group.addTask { await self.fetchPosts() }
        }
    }
    
    // MARK: - Fetch Profile
    /// Fetches the creator's profile from Firestore
    func fetchProfile() async {
        await MainActor.run {
            isLoadingProfile = true
            error = nil
        }
        
        do {
            let doc = try await db.collection(usersCollection).document(targetUid).getDocument()
            
            if let data = doc.data() {
                let profile = CreatorProfile(
                    uid: targetUid,
                    displayName: data["nickname"] as? String ?? data["displayName"] as? String ?? "User_\(String(targetUid.suffix(4)))",
                    bio: data["bio"] as? String,
                    avatarUrl: data["avatar_url"] as? String ?? data["profileImageUrl"] as? String,
                    followersCount: data["followersCount"] as? Int ?? 0,
                    followingCount: data["followingCount"] as? Int ?? 0,
                    isCurator: data["isCurator"] as? Bool ?? false
                )
                
                await MainActor.run {
                    self.profile = profile
                    self.isLoadingProfile = false
                }
                
                print("✅ [CreatorProfile] Loaded profile for: \(profile.displayName)")
            } else {
                // User document doesn't exist, use placeholder
                await MainActor.run {
                    self.profile = CreatorProfile(uid: targetUid, displayName: "User_\(String(targetUid.suffix(4)))")
                    self.isLoadingProfile = false
                }
                print("⚠️ [CreatorProfile] No user document found for UID: \(targetUid)")
            }
            
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoadingProfile = false
            }
            print("❌ [CreatorProfile] Fetch profile error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Fetch Posts
    /// Fetches all posts by this creator
    func fetchPosts() async {
        await MainActor.run {
            isLoadingPosts = true
        }
        
        do {
            let snapshot = try await db.collection(postsCollection)
                .whereField("creator_uid", isEqualTo: targetUid)
                .order(by: "created_at", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            var fetchedPosts: [FeedPost] = []
            
            for doc in snapshot.documents {
                let data = doc.data()
                let post = FeedPost(
                    id: doc.documentID,
                    data: data,
                    creatorName: profile?.displayName ?? "Creator",
                    creatorAvatarUrl: profile?.avatarUrl
                )
                
                if !post.contentUrl.isEmpty || !post.title.isEmpty {
                    fetchedPosts.append(post)
                }
            }
            
            await MainActor.run {
                self.posts = fetchedPosts
                self.isLoadingPosts = false
            }
            
            print("✅ [CreatorProfile] Loaded \(fetchedPosts.count) posts for creator")
            
        } catch {
            await MainActor.run {
                self.isLoadingPosts = false
            }
            print("❌ [CreatorProfile] Fetch posts error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Refresh
    /// Refreshes all data
    func refresh() async {
        await fetchAll()
    }
}
