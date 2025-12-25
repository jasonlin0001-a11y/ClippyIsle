//
//  CreatorProfileView.swift
//  ClippyIsle
//
//  A detailed profile view for creators showing their bio and past posts.
//

import SwiftUI
import SafariServices

// MARK: - Creator Profile View
/// Displays a creator's profile with their avatar, bio, stats, and posts
struct CreatorProfileView: View {
    let targetUserId: String
    let targetUserName: String
    let themeColor: Color
    
    @StateObject private var viewModel: CreatorProfileViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedURL: URL?
    @State private var showSafari = false
    
    init(targetUserId: String, targetUserName: String, themeColor: Color = .blue) {
        self.targetUserId = targetUserId
        self.targetUserName = targetUserName
        self.themeColor = themeColor
        self._viewModel = StateObject(wrappedValue: CreatorProfileViewModel(targetUid: targetUserId))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Profile Header
                profileHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                
                // Divider
                Divider()
                    .padding(.horizontal, 16)
                
                // Posts Section
                postsSection
                    .padding(.top, 16)
            }
        }
        .background(colorScheme == .dark ? Color.black : Color(.systemGroupedBackground))
        .navigationTitle(viewModel.profile?.displayName ?? targetUserName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchAll()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .sheet(isPresented: $showSafari) {
            if let url = selectedURL {
                SafariView(url: url)
            }
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar and Stats Row
            HStack(spacing: 20) {
                // Large Avatar
                largeAvatar
                
                Spacer()
                
                // Stats
                HStack(spacing: 24) {
                    statItem(
                        count: viewModel.posts.count,
                        label: "Posts"
                    )
                    
                    NavigationLink(destination: UserListView(
                        userId: targetUserId,
                        listType: .followers,
                        themeColor: themeColor
                    )) {
                        statItem(
                            count: viewModel.profile?.followersCount ?? 0,
                            label: "Followers"
                        )
                    }
                    .buttonStyle(.plain)
                    
                    NavigationLink(destination: UserListView(
                        userId: targetUserId,
                        listType: .following,
                        themeColor: themeColor
                    )) {
                        statItem(
                            count: viewModel.profile?.followingCount ?? 0,
                            label: "Following"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Name and Bio
            VStack(alignment: .leading, spacing: 8) {
                // Display Name
                Text(viewModel.profile?.displayName ?? targetUserName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // Bio
                if let bio = viewModel.profile?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                } else {
                    Text("No bio available")
                        .font(.body)
                        .foregroundColor(.secondary.opacity(0.6))
                        .italic()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Follow Button
            FollowButton(targetUid: targetUserId, targetDisplayName: viewModel.profile?.displayName ?? targetUserName)
                .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Large Avatar
    private var largeAvatar: some View {
        Group {
            if let avatarUrlString = viewModel.profile?.avatarUrl,
               let avatarUrl = URL(string: avatarUrlString) {
                AsyncImage(url: avatarUrl) { phase in
                    switch phase {
                    case .empty:
                        avatarPlaceholder
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        avatarPlaceholder
                    @unknown default:
                        avatarPlaceholder
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
            }
        }
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(themeColor.opacity(0.2))
            .frame(width: 80, height: 80)
            .overlay(
                Text(String((viewModel.profile?.displayName ?? targetUserName).prefix(1)).uppercased())
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(themeColor)
            )
    }
    
    // MARK: - Stat Item
    private func statItem(count: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Posts Section
    private var postsSection: some View {
        Group {
            if viewModel.isLoadingPosts && viewModel.posts.isEmpty {
                loadingPostsView
            } else if viewModel.posts.isEmpty {
                emptyPostsView
            } else {
                postsListView
            }
        }
    }
    
    private var loadingPostsView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading posts...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }
    
    private var emptyPostsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No posts yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("This creator hasn't shared any posts yet.")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 32)
    }
    
    private var postsListView: some View {
        LazyVStack(spacing: 16) {
            // Section Header
            HStack {
                Text("Posts")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(viewModel.posts.count) posts")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            
            // Posts
            ForEach(viewModel.posts) { post in
                CreatorPostCell(
                    post: post,
                    themeColor: themeColor,
                    onTap: {
                        if let url = URL(string: post.contentUrl) {
                            selectedURL = url
                            showSafari = true
                        }
                    },
                    showFollowButton: false // Already on profile, no need for follow button on each post
                )
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 32)
    }
}

// MARK: - Preview
#if DEBUG
struct CreatorProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            CreatorProfileView(
                targetUserId: "sample_user_123",
                targetUserName: "Sample Creator",
                themeColor: .blue
            )
        }
    }
}
#endif
