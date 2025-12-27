//
//  SearchResultsViewModel.swift
//  ClippyIsle
//
//  ViewModel for global search - searches both Users (Creators) and Posts.
//

import Foundation
import FirebaseFirestore
import Combine

// MARK: - Search Result User
/// Represents a user result from search
struct SearchResultUser: Identifiable {
    var id: String { uid }
    let uid: String
    let displayName: String
    let avatarUrl: String?
    let bio: String?
    let followersCount: Int
}

// MARK: - Search Results ViewModel
/// ViewModel for managing global search across users and posts
@MainActor
class SearchResultsViewModel: ObservableObject {
    private let db = Firestore.firestore()
    private let usersCollection = "users"
    private let creatorPostsCollection = "creator_posts"
    
    @Published var searchText: String = ""
    @Published var matchedUsers: [SearchResultUser] = []
    @Published var matchedPosts: [FeedPost] = []
    @Published var isSearching: Bool = false
    @Published var hasSearched: Bool = false
    
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // Cache for creator profiles (for post enrichment)
    private var creatorProfileCache: [String: (name: String, avatarUrl: String?)] = [:]
    
    init() {
        // Setup debounced search on searchText changes
        $searchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }
                Task {
                    await self.performSearch(query: query)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Perform Search
    /// Performs search on both users and posts
    func performSearch(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedQuery.isEmpty else {
            await MainActor.run {
                matchedUsers = []
                matchedPosts = []
                hasSearched = false
                isSearching = false
            }
            return
        }
        
        // Cancel previous search task
        searchTask?.cancel()
        
        searchTask = Task {
            await MainActor.run {
                isSearching = true
            }
            
            // Run both searches concurrently
            async let usersResult = searchUsers(query: trimmedQuery)
            async let postsResult = searchPosts(query: trimmedQuery)
            
            let (users, posts) = await (usersResult, postsResult)
            
            // Check if task was cancelled
            if Task.isCancelled { return }
            
            await MainActor.run {
                matchedUsers = users
                matchedPosts = posts
                hasSearched = true
                isSearching = false
            }
            
            print("🔍 Search '\(trimmedQuery)': Found \(users.count) users, \(posts.count) posts")
        }
    }
    
    // MARK: - Search Users
    /// Searches users by display name using Firestore text search pattern
    /// Uses >= and < pattern for prefix matching
    private func searchUsers(query: String) async -> [SearchResultUser] {
        let lowercaseQuery = query.lowercased()
        let endString = lowercaseQuery + "\u{f8ff}"
        
        do {
            // Search by nickname (display name) - using prefix match pattern
            let snapshot = try await db.collection(usersCollection)
                .whereField("nickname_lowercase", isGreaterThanOrEqualTo: lowercaseQuery)
                .whereField("nickname_lowercase", isLessThan: endString)
                .limit(to: 10)
                .getDocuments()
            
            var users: [SearchResultUser] = []
            
            for doc in snapshot.documents {
                let data = doc.data()
                
                let user = SearchResultUser(
                    uid: doc.documentID,
                    displayName: data["nickname"] as? String ?? "User_\(String(doc.documentID.suffix(4)))",
                    avatarUrl: data["avatar_url"] as? String,
                    bio: data["bio"] as? String,
                    followersCount: data["followersCount"] as? Int ?? 0
                )
                
                users.append(user)
            }
            
            // If no results with lowercase field, try original nickname field
            if users.isEmpty {
                let fallbackSnapshot = try await db.collection(usersCollection)
                    .whereField("nickname", isGreaterThanOrEqualTo: query)
                    .whereField("nickname", isLessThan: query + "\u{f8ff}")
                    .limit(to: 10)
                    .getDocuments()
                
                for doc in fallbackSnapshot.documents {
                    let data = doc.data()
                    
                    let user = SearchResultUser(
                        uid: doc.documentID,
                        displayName: data["nickname"] as? String ?? "User_\(String(doc.documentID.suffix(4)))",
                        avatarUrl: data["avatar_url"] as? String,
                        bio: data["bio"] as? String,
                        followersCount: data["followersCount"] as? Int ?? 0
                    )
                    
                    users.append(user)
                }
            }
            
            return users
            
        } catch {
            print("❌ Search users failed: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Search Posts
    /// Searches posts by title using text search pattern
    private func searchPosts(query: String) async -> [FeedPost] {
        let lowercaseQuery = query.lowercased()
        
        do {
            // First try to search by link_title (if posts have it)
            var snapshot = try await db.collection(creatorPostsCollection)
                .whereField("link_title_lowercase", isGreaterThanOrEqualTo: lowercaseQuery)
                .whereField("link_title_lowercase", isLessThan: lowercaseQuery + "\u{f8ff}")
                .limit(to: 20)
                .getDocuments()
            
            // If no results, try by title field
            if snapshot.documents.isEmpty {
                snapshot = try await db.collection(creatorPostsCollection)
                    .whereField("title", isGreaterThanOrEqualTo: query)
                    .whereField("title", isLessThan: query + "\u{f8ff}")
                    .limit(to: 20)
                    .getDocuments()
            }
            
            // If still no results, fall back to fetching recent posts and filter client-side
            var posts: [FeedPost] = []
            
            if snapshot.documents.isEmpty {
                // Fallback: Get recent posts and filter
                let fallbackSnapshot = try await db.collection(creatorPostsCollection)
                    .order(by: "created_at", descending: true)
                    .limit(to: 100)
                    .getDocuments()
                
                for doc in fallbackSnapshot.documents {
                    let data = doc.data()
                    let post = FeedPost(
                        id: doc.documentID,
                        data: data,
                        creatorName: "Creator",
                        creatorAvatarUrl: nil
                    )
                    
                    // Client-side filter by title, link_title, or curator_note
                    let title = post.title.lowercased()
                    let linkTitle = post.linkTitle?.lowercased() ?? ""
                    let note = post.curatorNote?.lowercased() ?? ""
                    
                    if title.contains(lowercaseQuery) ||
                       linkTitle.contains(lowercaseQuery) ||
                       note.contains(lowercaseQuery) {
                        posts.append(post)
                    }
                    
                    // Limit results
                    if posts.count >= 20 { break }
                }
            } else {
                // Direct search results
                for doc in snapshot.documents {
                    let data = doc.data()
                    let post = FeedPost(
                        id: doc.documentID,
                        data: data,
                        creatorName: "Creator",
                        creatorAvatarUrl: nil
                    )
                    posts.append(post)
                }
            }
            
            // Enrich posts with creator info
            let enrichedPosts = await enrichPostsWithCreatorInfo(posts: posts)
            
            return enrichedPosts
            
        } catch {
            print("❌ Search posts failed: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Enrich Posts with Creator Info
    /// Fetches creator profile data and enriches posts
    private func enrichPostsWithCreatorInfo(posts: [FeedPost]) async -> [FeedPost] {
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
        return posts.map { post -> FeedPost in
            var enrichedPost = post
            if let profile = creatorProfileCache[post.creatorUid] {
                enrichedPost.creatorName = profile.name
                enrichedPost.creatorAvatarUrl = profile.avatarUrl
            }
            return enrichedPost
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
    
    // MARK: - Clear Search
    /// Clears search text and results
    func clearSearch() {
        searchTask?.cancel()
        searchText = ""
        matchedUsers = []
        matchedPosts = []
        hasSearched = false
        isSearching = false
    }
}
