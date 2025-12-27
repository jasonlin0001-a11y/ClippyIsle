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
    // Additional optional fields with defaults
    var likes: Int
    var views: Int
    var tags: [String]
    var feedType: String
    // Moderation fields
    var isHidden: Bool
    var reportCount: Int
    
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
        self.likes = 0
        self.views = 0
        self.tags = []
        self.feedType = "text"
        self.isHidden = false
        self.reportCount = 0
    }
    
    /// Initialize directly from Firestore document data with robust decoding
    init(id: String, data: [String: Any], creatorName: String = "Unknown Creator", creatorAvatarUrl: String? = nil) {
        self.id = id
        self.creatorUid = data["creator_uid"] as? String ?? ""
        self.creatorName = creatorName
        self.creatorAvatarUrl = creatorAvatarUrl
        self.title = data["title"] as? String ?? data["link_title"] as? String ?? "Untitled"
        self.contentUrl = data["content_url"] as? String ?? ""
        self.curatorNote = data["curator_note"] as? String
        
        // Handle created_at carefully - it might be a Timestamp object or missing
        if let timestamp = data["created_at"] as? Timestamp {
            self.createdAt = timestamp.dateValue()
        } else if let dateValue = data["created_at"] as? Date {
            self.createdAt = dateValue
        } else {
            self.createdAt = Date() // Default to now if missing
        }
        
        // Link preview fields
        self.linkTitle = data["link_title"] as? String
        self.linkImage = data["link_image"] as? String
        self.linkDescription = data["link_description"] as? String
        self.linkDomain = data["link_domain"] as? String
        
        // Optional fields with defaults
        self.likes = data["likes"] as? Int ?? 0
        self.views = data["views"] as? Int ?? 0
        self.tags = data["tags"] as? [String] ?? []
        self.feedType = data["feed_type"] as? String ?? "text"
        
        // Moderation fields
        self.isHidden = data["isHidden"] as? Bool ?? false
        self.reportCount = data["reportCount"] as? Int ?? 0
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
    }
    
    // MARK: - Get Followed Creator UIDs
    /// Queries the users/{currentUid}/following subcollection to get UIDs of creators the user follows
    private func getFollowedCreatorUids(currentUid: String) async -> [String] {
        do {
            // Use subcollection path: users/{currentUid}/following/{targetUserId}
            let snapshot = try await db.collection(usersCollection)
                .document(currentUid)
                .collection("following")
                .getDocuments()
            
            // Document IDs are the target user IDs, or use "uid" field
            return snapshot.documents.compactMap { doc -> String? in
                // Prefer document ID as it's the target user ID
                let docId = doc.documentID
                // Fallback to "uid" field if available
                let uidField = doc.data()["uid"] as? String
                return uidField ?? docId
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
    
    // MARK: - Discovery Feed with Real-time Listener
    
    /// Snapshot listener registration
    private var discoveryListener: ListenerRegistration?
    
    /// Discovery feed posts (all creator_posts)
    @Published var discoveryPosts: [FeedPost] = []
    @Published var isDiscoveryLoading: Bool = false
    @Published var discoveryError: String?
    @Published var isDiscoveryEmpty: Bool = false
    
    /// Sets up a real-time listener for Discovery feed (all creator_posts)
    /// - Returns: ListenerRegistration that can be used to remove the listener
    func setupDiscoveryListener() {
        print("🔄 Setting up Discovery feed listener...")
        
        isDiscoveryLoading = true
        discoveryError = nil
        
        // Remove existing listener if any
        discoveryListener?.remove()
        
        // Setup snapshot listener on creator_posts collection, ordered by created_at descending
        discoveryListener = db.collection(creatorPostsCollection)
            .order(by: "created_at", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    self.isDiscoveryLoading = false
                    
                    if let error = error {
                        print("❌ Discovery listener error: \(error.localizedDescription)")
                        self.discoveryError = error.localizedDescription
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("⚠️ Discovery: No documents in snapshot")
                        self.discoveryPosts = []
                        self.isDiscoveryEmpty = true
                        return
                    }
                    
                    print("📦 Discovery: Fetched \(documents.count) documents from Firestore")
                    
                    // Decode documents with robust error handling
                    var posts: [FeedPost] = []
                    var decodingErrors: [String] = []
                    
                    for doc in documents {
                        let data = doc.data()
                        
                        // Debug: Print raw document data for first document
                        if posts.isEmpty {
                            print("📄 Sample document ID: \(doc.documentID)")
                            print("📄 Sample document fields: \(data.keys.joined(separator: ", "))")
                            // Debug: Print link preview field values
                            print("📄 link_image: \(data["link_image"] ?? "nil")")
                            print("📄 link_title: \(data["link_title"] ?? "nil")")
                            print("📄 link_domain: \(data["link_domain"] ?? "nil")")
                            print("📄 link_description: \(data["link_description"] ?? "nil")")
                        }
                        
                        // Create FeedPost with robust decoding
                        let post = FeedPost(
                            id: doc.documentID,
                            data: data,
                            creatorName: "Creator", // Will be enriched later
                            creatorAvatarUrl: nil
                        )
                        
                        // Debug: Print decoded post link preview fields
                        if posts.isEmpty {
                            print("📄 Decoded post.linkImage: \(post.linkImage ?? "nil")")
                            print("📄 Decoded post.linkTitle: \(post.linkTitle ?? "nil")")
                        }
                        
                        // Validate we have at least a content_url or title
                        if !post.contentUrl.isEmpty || !post.title.isEmpty {
                            posts.append(post)
                        } else {
                            decodingErrors.append("Document \(doc.documentID) missing required fields")
                        }
                    }
                    
                    if !decodingErrors.isEmpty {
                        print("⚠️ Discovery: \(decodingErrors.count) decoding errors:")
                        for error in decodingErrors.prefix(5) {
                            print("   - \(error)")
                        }
                    }
                    
                    // Enrich posts with creator info
                    await self.enrichDiscoveryPosts(posts: posts)
                }
            }
    }
    
    /// Enriches discovery posts with creator profile data
    private func enrichDiscoveryPosts(posts: [FeedPost]) async {
        // Get unique creator UIDs
        let uniqueCreatorUids = Set(posts.map { $0.creatorUid }).filter { !$0.isEmpty }
        
        // Fetch profiles for creators not in cache
        for uid in uniqueCreatorUids {
            if creatorProfileCache[uid] == nil {
                let profile = await fetchCreatorProfile(uid: uid)
                creatorProfileCache[uid] = profile
            }
        }
        
        // Enrich posts with creator data
        let enrichedPosts = posts.map { post -> FeedPost in
            var enrichedPost = post
            if let profile = creatorProfileCache[post.creatorUid] {
                enrichedPost.creatorName = profile.name
                enrichedPost.creatorAvatarUrl = profile.avatarUrl
            }
            return enrichedPost
        }
        
        await MainActor.run {
            self.discoveryPosts = enrichedPosts
            self.isDiscoveryEmpty = enrichedPosts.isEmpty
            print("✅ Discovery: Loaded \(enrichedPosts.count) posts")
        }
    }
    
    /// Removes the Discovery listener
    func removeDiscoveryListener() {
        discoveryListener?.remove()
        discoveryListener = nil
        print("🔴 Discovery listener removed")
    }
    
    /// Fetches Discovery feed once (without listener)
    func fetchDiscoveryFeed() async {
        print("🔄 Fetching Discovery feed...")
        
        await MainActor.run {
            isDiscoveryLoading = true
            discoveryError = nil
        }
        
        do {
            let snapshot = try await db.collection(creatorPostsCollection)
                .order(by: "created_at", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            print("📦 Discovery: Fetched \(snapshot.documents.count) documents")
            
            var posts: [FeedPost] = []
            
            for doc in snapshot.documents {
                let data = doc.data()
                
                // Debug: Print first document details
                if posts.isEmpty {
                    print("📄 First doc ID: \(doc.documentID)")
                    print("📄 First doc keys: \(data.keys.sorted().joined(separator: ", "))")
                    for (key, value) in data {
                        print("   \(key): \(type(of: value)) = \(value)")
                    }
                }
                
                let post = FeedPost(
                    id: doc.documentID,
                    data: data,
                    creatorName: "Creator",
                    creatorAvatarUrl: nil
                )
                
                if !post.contentUrl.isEmpty || !post.title.isEmpty {
                    posts.append(post)
                }
            }
            
            // Enrich with creator info
            await enrichDiscoveryPosts(posts: posts)
            
            await MainActor.run {
                isDiscoveryLoading = false
            }
            
        } catch {
            print("❌ Fetch Discovery feed failed: \(error.localizedDescription)")
            await MainActor.run {
                discoveryError = error.localizedDescription
                isDiscoveryLoading = false
            }
        }
    }
}
