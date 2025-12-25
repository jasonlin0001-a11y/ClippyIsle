//
//  SearchResultsView.swift
//  ClippyIsle
//
//  View for displaying global search results (Users and Posts).
//

import SwiftUI

// MARK: - Search Results View
/// Displays search results for users (People) and posts
struct SearchResultsView: View {
    @ObservedObject var viewModel: SearchResultsViewModel
    let themeColor: Color
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            // Background matching app theme
            if colorScheme == .dark {
                Color.black.ignoresSafeArea()
            } else {
                Color(UIColor.systemBackground).ignoresSafeArea()
            }
            
            if viewModel.isSearching {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Searching...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if viewModel.hasSearched && viewModel.matchedUsers.isEmpty && viewModel.matchedPosts.isEmpty {
                // Empty state
                emptyStateView
            } else if viewModel.hasSearched {
                // Results
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Section: People (Users/Creators)
                        if !viewModel.matchedUsers.isEmpty {
                            peopleSection
                        }
                        
                        // Section: Posts
                        if !viewModel.matchedPosts.isEmpty {
                            postsSection
                        }
                    }
                    .padding(.bottom, 100) // Space for search bar
                }
            }
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No results found")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("找不到結果")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Try searching for a different name or topic")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - People Section
    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(themeColor)
                Text("People")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("(\(viewModel.matchedUsers.count))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
            
            // User Rows (limit to 5 initially)
            ForEach(Array(viewModel.matchedUsers.prefix(5).enumerated()), id: \.element.id) { index, user in
                VStack(spacing: 0) {
                    UserRowView(
                        userId: user.uid,
                        displayName: user.displayName,
                        avatarUrl: user.avatarUrl,
                        themeColor: themeColor,
                        showFollowButton: true
                    )
                    
                    if index < min(viewModel.matchedUsers.count, 5) - 1 {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }
            }
            
            // "See All" button if more than 5 users
            if viewModel.matchedUsers.count > 5 {
                NavigationLink {
                    // Full list of users
                    FullUserSearchResultsView(
                        users: viewModel.matchedUsers,
                        themeColor: themeColor
                    )
                } label: {
                    HStack {
                        Text("See all \(viewModel.matchedUsers.count) people")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(themeColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }
    
    // MARK: - Posts Section
    private var postsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(themeColor)
                Text("Posts")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("(\(viewModel.matchedPosts.count))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
            
            // Post Cards
            ForEach(viewModel.matchedPosts) { post in
                SearchPostCard(post: post, themeColor: themeColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                
                if post.id != viewModel.matchedPosts.last?.id {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }
}

// MARK: - Search Post Card
/// Simplified post card for search results
struct SearchPostCard: View {
    let post: FeedPost
    let themeColor: Color
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var showSafariSheet = false
    
    var body: some View {
        Button {
            if let url = URL(string: post.contentUrl), !post.contentUrl.isEmpty {
                showSafariSheet = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Creator info row
                HStack(spacing: 8) {
                    // Avatar
                    creatorAvatar
                    
                    // Name and timestamp
                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.creatorName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(post.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Post title
                Text(post.linkTitle ?? post.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                // Curator note (if present)
                if let note = post.curatorNote, !note.isEmpty {
                    Text(note)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Link preview image (if available)
                if let imageUrl = post.linkImage, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)
                                .clipped()
                                .cornerRadius(8)
                        case .failure:
                            EmptyView()
                        case .empty:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(height: 120)
                                .overlay(
                                    ProgressView()
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                
                // Domain badge
                if let domain = post.linkDomain, !domain.isEmpty {
                    HStack {
                        Image(systemName: "link")
                            .font(.caption2)
                        Text(domain)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSafariSheet) {
            if let url = URL(string: post.contentUrl) {
                SafariView(url: url)
            }
        }
    }
    
    // MARK: - Creator Avatar
    private var creatorAvatar: some View {
        Group {
            if let avatarUrlString = post.creatorAvatarUrl,
               let avatarUrl = URL(string: avatarUrlString) {
                AsyncImage(url: avatarUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        avatarPlaceholder
                    @unknown default:
                        avatarPlaceholder
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
            }
        }
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(themeColor.opacity(0.2))
            .frame(width: 32, height: 32)
            .overlay(
                Text(String(post.creatorName.prefix(1)).uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(themeColor)
            )
    }
}

// MARK: - Full User Search Results View
/// Displays the full list of user search results
struct FullUserSearchResultsView: View {
    let users: [SearchResultUser]
    let themeColor: Color
    
    var body: some View {
        List {
            ForEach(users) { user in
                UserRowView(
                    userId: user.uid,
                    displayName: user.displayName,
                    avatarUrl: user.avatarUrl,
                    themeColor: themeColor,
                    showFollowButton: true
                )
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.visible)
            }
        }
        .listStyle(.plain)
        .navigationTitle("People")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview
// Note: SafariView is declared in FollowingFeedView.swift and reused here
#if DEBUG
struct SearchResultsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SearchResultsView(
                viewModel: SearchResultsViewModel(),
                themeColor: .blue
            )
        }
    }
}
#endif
