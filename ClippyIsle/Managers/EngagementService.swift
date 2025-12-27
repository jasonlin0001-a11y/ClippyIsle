//
//  EngagementService.swift
//  ClippyIsle
//
//  Service for managing post engagement: Likes and Saves (to My Isle).
//

import Foundation
import Combine
import FirebaseFirestore

// MARK: - Saved Post Model
/// Represents a saved post in the user's My Isle
struct SavedPost: Codable, Identifiable {
    var id: String
    var type: SavedItemType
    var originalPostId: String
    var originalCreatorUid: String
    var originalCreatorName: String
    var timestamp: Date
    // Cached content for offline viewing
    var cachedTitle: String
    var cachedContentUrl: String
    var cachedCuratorNote: String?
    var cachedLinkImage: String?
    var cachedLinkTitle: String?
    var cachedLinkDomain: String?
    
    enum SavedItemType: String, Codable {
        case savedPost = "saved_post"
        case textNote = "text_note"
    }
}

// MARK: - Engagement Service
/// Manages post likes and saves to My Isle
@MainActor
class EngagementService: ObservableObject {
    static let shared = EngagementService()
    
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    private let creatorPostsCollection = "creator_posts"
    private let myIsleSubcollection = "cc_feed_items"  // Keep collection name for backward compatibility
    private let likesSubcollection = "likes"
    
    /// Set of post IDs that the current user has liked
    @Published var likedPostIds: Set<String> = []
    
    /// Set of post IDs that the current user has saved
    @Published var savedPostIds: Set<String> = []
    
    /// Saved posts for My Isle display
    @Published var savedPosts: [SavedPost] = []
    
    /// Loading state
    @Published var isLoading: Bool = false
    
    private var likesListener: ListenerRegistration?
    private var savesListener: ListenerRegistration?
    
    private init() {}
    
    deinit {
        likesListener?.remove()
        savesListener?.remove()
    }
    
    // MARK: - Like Post
    /// Likes a post by adding to posts/{postId}/likes/{userId} and incrementing likeCount
    func likePost(postId: String) async throws {
        guard let currentUid = AuthenticationManager.shared.currentUID else {
            throw EngagementError.noAuthenticatedUser
        }
        
        // Optimistic update
        likedPostIds.insert(postId)
        
        do {
            // Add to likes subcollection
            let likeDocRef = db.collection(creatorPostsCollection)
                .document(postId)
                .collection(likesSubcollection)
                .document(currentUid)
            
            try await likeDocRef.setData([
                "userId": currentUid,
                "timestamp": Timestamp(date: Date())
            ])
            
            // Increment likeCount on post document
            let postRef = db.collection(creatorPostsCollection).document(postId)
            try await postRef.updateData([
                "likeCount": FieldValue.increment(Int64(1))
            ])
            
            print("❤️ [EngagementService] Liked post: \(postId)")
        } catch {
            // Revert optimistic update on failure
            likedPostIds.remove(postId)
            print("❌ [EngagementService] Like failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Unlike Post
    /// Unlikes a post by removing from likes subcollection and decrementing likeCount
    func unlikePost(postId: String) async throws {
        guard let currentUid = AuthenticationManager.shared.currentUID else {
            throw EngagementError.noAuthenticatedUser
        }
        
        // Optimistic update
        likedPostIds.remove(postId)
        
        do {
            // Remove from likes subcollection
            let likeDocRef = db.collection(creatorPostsCollection)
                .document(postId)
                .collection(likesSubcollection)
                .document(currentUid)
            
            try await likeDocRef.delete()
            
            // Decrement likeCount on post document
            let postRef = db.collection(creatorPostsCollection).document(postId)
            try await postRef.updateData([
                "likeCount": FieldValue.increment(Int64(-1))
            ])
            
            print("💔 [EngagementService] Unliked post: \(postId)")
        } catch {
            // Revert optimistic update on failure
            likedPostIds.insert(postId)
            print("❌ [EngagementService] Unlike failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Toggle Like
    /// Toggles like status for a post
    func toggleLike(postId: String) async throws {
        if likedPostIds.contains(postId) {
            try await unlikePost(postId: postId)
        } else {
            try await likePost(postId: postId)
        }
    }
    
    // MARK: - Check If Liked
    /// Returns true if the current user has liked the post
    func isPostLiked(postId: String) -> Bool {
        return likedPostIds.contains(postId)
    }
    
    // MARK: - Save Post to CC FEED
    /// Saves a post to the user's CC FEED
    func savePost(post: FeedPost) async throws {
        guard let currentUid = AuthenticationManager.shared.currentUID else {
            throw EngagementError.noAuthenticatedUser
        }
        
        // Optimistic update
        savedPostIds.insert(post.id)
        
        do {
            let savedPost = SavedPost(
                id: UUID().uuidString,
                type: .savedPost,
                originalPostId: post.id,
                originalCreatorUid: post.creatorUid,
                originalCreatorName: post.creatorName,
                timestamp: Date(),
                cachedTitle: post.title,
                cachedContentUrl: post.contentUrl,
                cachedCuratorNote: post.curatorNote,
                cachedLinkImage: post.linkImage,
                cachedLinkTitle: post.linkTitle,
                cachedLinkDomain: post.linkDomain
            )
            
            // Path: users/{currentUid}/cc_feed_items/{savedPostId}
            let ccFeedDocRef = db.collection(usersCollection)
                .document(currentUid)
                .collection(myIsleSubcollection)
                .document(savedPost.id)
            
            let data: [String: Any] = [
                "id": savedPost.id,
                "type": savedPost.type.rawValue,
                "originalPostId": savedPost.originalPostId,
                "originalCreatorUid": savedPost.originalCreatorUid,
                "originalCreatorName": savedPost.originalCreatorName,
                "timestamp": Timestamp(date: savedPost.timestamp),
                "cachedTitle": savedPost.cachedTitle,
                "cachedContentUrl": savedPost.cachedContentUrl,
                "cachedCuratorNote": savedPost.cachedCuratorNote ?? NSNull(),
                "cachedLinkImage": savedPost.cachedLinkImage ?? NSNull(),
                "cachedLinkTitle": savedPost.cachedLinkTitle ?? NSNull(),
                "cachedLinkDomain": savedPost.cachedLinkDomain ?? NSNull()
            ]
            
            try await ccFeedDocRef.setData(data)
            
            // Add to local list
            savedPosts.insert(savedPost, at: 0)
            
            print("🔖 [EngagementService] Saved post to CC FEED: \(post.id)")
        } catch {
            // Revert optimistic update on failure
            savedPostIds.remove(post.id)
            print("❌ [EngagementService] Save failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Unsave Post from CC FEED
    /// Removes a saved post from the user's CC FEED
    func unsavePost(postId: String) async throws {
        guard let currentUid = AuthenticationManager.shared.currentUID else {
            throw EngagementError.noAuthenticatedUser
        }
        
        // Find the saved post document ID
        guard let savedPost = savedPosts.first(where: { $0.originalPostId == postId }) else {
            // Not found in local cache, try to find in Firestore
            savedPostIds.remove(postId)
            return
        }
        
        // Optimistic update
        savedPostIds.remove(postId)
        savedPosts.removeAll { $0.originalPostId == postId }
        
        do {
            // Path: users/{currentUid}/cc_feed_items/{savedPostId}
            let ccFeedDocRef = db.collection(usersCollection)
                .document(currentUid)
                .collection(myIsleSubcollection)
                .document(savedPost.id)
            
            try await ccFeedDocRef.delete()
            
            print("📌 [EngagementService] Unsaved post from CC FEED: \(postId)")
        } catch {
            // Revert optimistic update on failure
            savedPostIds.insert(postId)
            savedPosts.insert(savedPost, at: 0)
            print("❌ [EngagementService] Unsave failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Toggle Save
    /// Toggles save status for a post
    func toggleSave(post: FeedPost) async throws {
        if savedPostIds.contains(post.id) {
            try await unsavePost(postId: post.id)
        } else {
            try await savePost(post: post)
        }
    }
    
    // MARK: - Check If Saved
    /// Returns true if the post is saved to CC FEED
    func isPostSaved(postId: String) -> Bool {
        return savedPostIds.contains(postId)
    }
    
    // MARK: - Load Saved Posts
    /// Loads all saved posts from CC FEED
    func loadSavedPosts() async {
        guard let currentUid = AuthenticationManager.shared.currentUID else { return }
        
        isLoading = true
        
        do {
            let snapshot = try await db.collection(usersCollection)
                .document(currentUid)
                .collection(myIsleSubcollection)
                .whereField("type", isEqualTo: SavedPost.SavedItemType.savedPost.rawValue)
                .order(by: "timestamp", descending: true)
                .getDocuments()
            
            var posts: [SavedPost] = []
            var ids: Set<String> = []
            
            for doc in snapshot.documents {
                let data = doc.data()
                guard let id = data["id"] as? String,
                      let typeRaw = data["type"] as? String,
                      let type = SavedPost.SavedItemType(rawValue: typeRaw),
                      let originalPostId = data["originalPostId"] as? String,
                      let originalCreatorUid = data["originalCreatorUid"] as? String,
                      let originalCreatorName = data["originalCreatorName"] as? String,
                      let timestamp = data["timestamp"] as? Timestamp,
                      let cachedTitle = data["cachedTitle"] as? String,
                      let cachedContentUrl = data["cachedContentUrl"] as? String else {
                    continue
                }
                
                let savedPost = SavedPost(
                    id: id,
                    type: type,
                    originalPostId: originalPostId,
                    originalCreatorUid: originalCreatorUid,
                    originalCreatorName: originalCreatorName,
                    timestamp: timestamp.dateValue(),
                    cachedTitle: cachedTitle,
                    cachedContentUrl: cachedContentUrl,
                    cachedCuratorNote: data["cachedCuratorNote"] as? String,
                    cachedLinkImage: data["cachedLinkImage"] as? String,
                    cachedLinkTitle: data["cachedLinkTitle"] as? String,
                    cachedLinkDomain: data["cachedLinkDomain"] as? String
                )
                
                posts.append(savedPost)
                ids.insert(originalPostId)
            }
            
            savedPosts = posts
            savedPostIds = ids
            isLoading = false
            
            print("✅ [EngagementService] Loaded \(posts.count) saved posts")
        } catch {
            isLoading = false
            print("❌ [EngagementService] Load saved posts failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Load Liked Posts
    /// Loads the IDs of posts the current user has liked
    func loadLikedPosts() async {
        guard AuthenticationManager.shared.currentUID != nil else { return }
        
        // For performance, we query the user's liked posts from a dedicated collection
        // or check individual posts they've interacted with
        // For MVP, we'll check against posts in Discovery/Following feeds
        
        // This would be more efficient with a users/{uid}/liked_posts subcollection
        // For now, we'll rely on real-time checking when viewing posts
        print("📊 [EngagementService] Liked posts tracking initialized")
    }
    
    // MARK: - Check Like Status for Multiple Posts
    /// Checks like status for multiple posts (batch check)
    func checkLikeStatus(postIds: [String]) async {
        guard let currentUid = AuthenticationManager.shared.currentUID else { return }
        
        for postId in postIds {
            let likeDocRef = db.collection(creatorPostsCollection)
                .document(postId)
                .collection(likesSubcollection)
                .document(currentUid)
            
            do {
                let doc = try await likeDocRef.getDocument()
                if doc.exists {
                    likedPostIds.insert(postId)
                }
            } catch {
                // Silently fail for individual checks
            }
        }
    }
    
    // MARK: - Cleanup
    func removeListeners() {
        likesListener?.remove()
        likesListener = nil
        savesListener?.remove()
        savesListener = nil
    }
}

// MARK: - Engagement Error
enum EngagementError: Error, LocalizedError {
    case noAuthenticatedUser
    case networkError(String)
    case postNotFound
    
    var errorDescription: String? {
        switch self {
        case .noAuthenticatedUser:
            return "You must be signed in to like or save posts"
        case .networkError(let message):
            return "Network error: \(message)"
        case .postNotFound:
            return "Post not found"
        }
    }
}
