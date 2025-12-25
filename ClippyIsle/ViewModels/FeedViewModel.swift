//
//  FeedViewModel.swift
//  ClippyIsle
//
//  ViewModel for the Following Feed - fetches posts from followed creators.
//

import Foundation
import FirebaseFirestore
import Combine

// MARK: - Feed Post Model (Extended for UI)
/// Represents a creator post with additional UI-related data
struct FeedPost: Identifiable {
    var id: String
    var creatorUid: String
    var creatorName: String
    var creatorAvatarUrl: String?
    var title: String
    var contentUrl: String
    var curatorNote: String?
    var createdAt: Date
    // Link preview fields
    var linkTitle: String?
    var linkImage: String?
    var linkDescription: String?
    var linkDomain: String?
    
    init(from creatorPost: CreatorPost, creatorName: String = "Unknown Creator", creatorAvatarUrl: String? = nil) {
        self.id = creatorPost.id
        self.creatorUid = creatorPost.creator_uid
        self.creatorName = creatorName
        self.creatorAvatarUrl = creatorAvatarUrl
        self.title = creatorPost.title
        self.contentUrl = creatorPost.content_url
        self.curatorNote = creatorPost.curator_note
        self.createdAt = creatorPost.created_at
        self.linkTitle = creatorPost.link_title
        self.linkImage = creatorPost.link_image
        self.linkDescription = creatorPost.link_description
        self.linkDomain = creatorPost.link_domain
    }
}

// MARK: - Feed ViewModel
/// ViewModel for fetching and managing the Following Feed
@MainActor
class FeedViewModel: ObservableObject {
    private let db = Firestore.firestore()
    private let creatorPostsCollection = "creator_posts"
    private let followersCollection = "followers"
    private let usersCollection = "users"
    
    @Published var feedPosts: [FeedPost] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var isEmpty: Bool = false
    
    // Cache for creator profiles
    private var creatorProfileCache: [String: (name: String, avatarUrl: String?)] = [:]
    
    // MARK: - Fetch Following Feed
    /// Fetches posts from creators that the current user follows
    func fetchFollowingFeed() async {
        guard let currentUid = AuthenticationManager.shared.currentUID else {
            error = "Please sign in to see your feed"
            isEmpty = true
            return
        }
        
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            // Step A: Get the list of creator UIDs the user follows
            let followedCreatorUids = await getFollowedCreatorUids(currentUid: currentUid)
            
            guard !followedCreatorUids.isEmpty else {
                await MainActor.run {
                    feedPosts = []
                    isEmpty = true
                    isLoading = false
                }
                return
            }
            
            // Step B: Query creator_posts where creator_uid is in the list
            // Firestore 'in' query is limited to 30 items
            let posts = await fetchPostsFromCreators(creatorUids: followedCreatorUids)
            
            // Step C: Enrich posts with creator profile data
            let enrichedPosts = await enrichPostsWithCreatorInfo(posts: posts)
            
            // Sort by date (newest first)
            let sortedPosts = enrichedPosts.sorted { $0.createdAt > $1.createdAt }
            
            await MainActor.run {
                feedPosts = sortedPosts
                isEmpty = sortedPosts.isEmpty
                isLoading = false
            }
            
            print("✅ Fetched \(sortedPosts.count) posts from \(followedCreatorUids.count) followed creators")
            
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
            print("❌ Fetch following feed failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Get Followed Creator UIDs
    /// Queries the followers collection to get UIDs of creators the user follows
    private func getFollowedCreatorUids(currentUid: String) async -> [String] {
        do {
            let snapshot = try await db.collection(followersCollection)
                .whereField("follower_uid", isEqualTo: currentUid)
                .getDocuments()
            
            return snapshot.documents.compactMap { doc -> String? in
                return doc.data()["creator_uid"] as? String
            }
        } catch {
            print("❌ Get followed creators failed: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Fetch Posts from Creators
    /// Fetches posts from the given creator UIDs
    /// Handles Firestore 'in' query limit of 30 items by splitting queries
    /// Uses concurrent processing for better performance with many followed creators
    private func fetchPostsFromCreators(creatorUids: [String]) async -> [CreatorPost] {
        // Split into batches of 30 (Firestore 'in' query limit)
        let batchSize = 30
        let batches = stride(from: 0, to: creatorUids.count, by: batchSize).map {
            Array(creatorUids[$0..<min($0 + batchSize, creatorUids.count)])
        }
        
        // Process batches concurrently using TaskGroup for better performance
        return await withTaskGroup(of: [CreatorPost].self) { group in
            for batch in batches {
                group.addTask {
                    await self.fetchPostsBatch(creatorUids: batch)
                }
            }
            
            var allPosts: [CreatorPost] = []
            for await posts in group {
                allPosts.append(contentsOf: posts)
            }
            return allPosts
        }
    }
    
    /// Fetches posts for a single batch of creator UIDs
    private func fetchPostsBatch(creatorUids: [String]) async -> [CreatorPost] {
        do {
            let snapshot = try await db.collection(creatorPostsCollection)
                .whereField("creator_uid", in: creatorUids)
                .order(by: "created_at", descending: true)
                .limit(to: 50) // Limit results per batch
                .getDocuments()
            
            return snapshot.documents.compactMap { doc -> CreatorPost? in
                let data = doc.data()
                guard let creatorUid = data["creator_uid"] as? String,
                      let title = data["title"] as? String,
                      let contentUrl = data["content_url"] as? String,
                      let timestamp = data["created_at"] as? Timestamp else {
                    return nil
                }
                
                return CreatorPost(
                    id: doc.documentID,
                    creator_uid: creatorUid,
                    title: title,
                    content_url: contentUrl,
                    curator_note: data["curator_note"] as? String,
                    created_at: timestamp.dateValue(),
                    link_title: data["link_title"] as? String,
                    link_image: data["link_image"] as? String,
                    link_description: data["link_description"] as? String,
                    link_domain: data["link_domain"] as? String
                )
            }
        } catch {
            print("❌ Fetch posts batch failed: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Enrich Posts with Creator Info
    /// Fetches creator profile data and enriches posts
    private func enrichPostsWithCreatorInfo(posts: [CreatorPost]) async -> [FeedPost] {
        // Get unique creator UIDs
        let uniqueCreatorUids = Set(posts.map { $0.creator_uid })
        
        // Fetch profiles for creators not in cache
        for uid in uniqueCreatorUids {
            if creatorProfileCache[uid] == nil {
                let profile = await fetchCreatorProfile(uid: uid)
                creatorProfileCache[uid] = profile
            }
        }
        
        // Create FeedPosts with enriched data
        return posts.map { post -> FeedPost in
            let profile = creatorProfileCache[post.creator_uid]
            return FeedPost(
                from: post,
                creatorName: profile?.name ?? "User_\(String(post.creator_uid.suffix(4)))",
                creatorAvatarUrl: profile?.avatarUrl
            )
        }
    }
    
    // MARK: - Fetch Creator Profile
    /// Fetches a creator's profile data
    private func fetchCreatorProfile(uid: String) async -> (name: String, avatarUrl: String?) {
        do {
            let doc = try await db.collection(usersCollection).document(uid).getDocument()
            
            if let data = doc.data() {
                let name = data["nickname"] as? String ?? "User_\(String(uid.suffix(4)))"
                let avatarUrl = data["avatar_url"] as? String
                return (name, avatarUrl)
            }
        } catch {
            print("❌ Fetch creator profile failed: \(error.localizedDescription)")
        }
        
        return ("User_\(String(uid.suffix(4)))", nil)
    }
    
    // MARK: - Refresh Feed
    /// Refreshes the feed (pull-to-refresh)
    func refreshFeed() async {
        // Clear cache to get fresh data
        creatorProfileCache.removeAll()
        await fetchFollowingFeed()
    }
}
