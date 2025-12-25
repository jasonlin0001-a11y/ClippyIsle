//
//  FollowingFeedView.swift
//  ClippyIsle
//
//  Following Feed View - displays posts from followed creators.
//

import SwiftUI
import SafariServices

// MARK: - Following Feed View
/// Displays the feed of posts from creators the user follows
struct FollowingFeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var selectedURL: URL?
    @State private var showSafari = false
    @State private var showSaveToast = false
    @State private var saveToastMessage = ""
    
    let themeColor: Color
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.feedPosts.isEmpty {
                loadingView
            } else if viewModel.isEmpty {
                emptyStateView
            } else if let error = viewModel.error {
                errorView(error)
            } else {
                feedList
            }
            
            // Save Toast
            if showSaveToast {
                VStack {
                    Spacer()
                    Text(saveToastMessage)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.8))
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 100)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showSaveToast)
            }
        }
        .task {
            await viewModel.fetchFollowingFeed()
        }
        .sheet(isPresented: $showSafari) {
            if let url = selectedURL {
                SafariView(url: url)
            }
        }
    }
    
    // MARK: - Feed List
    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.feedPosts) { post in
                    CreatorPostCell(
                        post: post,
                        themeColor: themeColor,
                        onTap: {
                            if let url = URL(string: post.contentUrl) {
                                selectedURL = url
                                showSafari = true
                            }
                        },
                        showFollowButton: false, // Already following these creators
                        onSaveToggle: { isSaved in
                            showSaveToastMessage(isSaved: isSaved)
                        }
                    )
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
        }
        .refreshable {
            await viewModel.refreshFeed()
        }
    }
    
    // MARK: - Show Save Toast
    private func showSaveToastMessage(isSaved: Bool) {
        saveToastMessage = isSaved ? "Saved to CC FEED 🔖" : "Removed from CC FEED"
        showSaveToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSaveToast = false
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading feed...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("尚未有訂閱")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("尚未有訂閱，去 Discovery 探索更多創作者！\n\nNo subscriptions yet. Go to Discovery to find creators!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    // MARK: - Error View
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Error loading feed")
                .font(.headline)
            
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                Task {
                    await viewModel.fetchFollowingFeed()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(themeColor)
        }
        .padding()
    }
}

// MARK: - Creator Post Cell
/// Cell design for creator posts with header, body, link preview, and author footer
struct CreatorPostCell: View {
    let post: FeedPost
    let themeColor: Color
    let onTap: () -> Void
    /// Show follow button in footer (default: true for Discovery, false for Following tab)
    var showFollowButton: Bool = true
    /// Callback when save button is tapped (shows toast)
    var onSaveToggle: ((Bool) -> Void)? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var engagementService = EngagementService.shared
    
    // Animation states
    @State private var isLikeAnimating = false
    @State private var isSaveAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Creator Avatar + Name + Time (tappable for profile) + Follow Button
            HStack(spacing: 12) {
                // Tappable Avatar + Name section (navigates to profile)
                NavigationLink(destination: CreatorProfileView(
                    targetUserId: post.creatorUid,
                    targetUserName: post.creatorName,
                    themeColor: themeColor
                )) {
                    HStack(spacing: 12) {
                        // Avatar
                        creatorAvatar
                        
                        // Name and time
                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.creatorName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text(post.createdAt.timeAgoDisplay())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain) // Removes default NavigationLink styling
                .disabled(post.creatorUid.isEmpty) // Disable if no creator UID
                
                Spacer()
                
                // Follow button in header (only if showFollowButton is true)
                // Placed outside NavigationLink so it remains independently clickable
                if showFollowButton && !post.creatorUid.isEmpty {
                    CompactFollowButton(
                        targetUid: post.creatorUid,
                        targetDisplayName: post.creatorName
                    )
                }
            }
            
            // Body: Curator Note (if available)
            if let curatorNote = post.curatorNote, !curatorNote.isEmpty {
                Text(curatorNote)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
            
            // Attachment: Rich Link Preview Card
            linkPreviewCard
            
            // Footer: Engagement Actions (Like + Save)
            engagementFooter
        }
        .padding(16)
        .background(cardBackground)
        .shadow(
            color: colorScheme == .dark ? .black.opacity(0.3) : .black.opacity(0.1),
            radius: colorScheme == .dark ? 5 : 4,
            x: 0,
            y: 2
        )
    }
    
    // MARK: - Engagement Footer
    private var engagementFooter: some View {
        HStack(spacing: 20) {
            // Like Button
            Button {
                toggleLike()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: engagementService.isPostLiked(postId: post.id) ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundColor(engagementService.isPostLiked(postId: post.id) ? .red : .secondary)
                        .scaleEffect(isLikeAnimating ? 1.3 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isLikeAnimating)
                    
                    if post.likes > 0 {
                        Text("\(post.likes)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Save to CC FEED Button (Bookmark)
            Button {
                toggleSave()
            } label: {
                Image(systemName: engagementService.isPostSaved(postId: post.id) ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 18))
                    .foregroundColor(engagementService.isPostSaved(postId: post.id) ? themeColor : .secondary)
                    .scaleEffect(isSaveAnimating ? 1.3 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isSaveAnimating)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.top, 4)
    }
    
    // MARK: - Toggle Like
    private func toggleLike() {
        // Animate
        isLikeAnimating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isLikeAnimating = false
        }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        Task {
            do {
                try await engagementService.toggleLike(postId: post.id)
            } catch {
                print("❌ Like toggle failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Toggle Save
    private func toggleSave() {
        // Animate
        isSaveAnimating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isSaveAnimating = false
        }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        let wasSaved = engagementService.isPostSaved(postId: post.id)
        
        Task {
            do {
                try await engagementService.toggleSave(post: post)
                // Notify parent about save toggle for toast
                await MainActor.run {
                    onSaveToggle?(!wasSaved)
                }
            } catch {
                print("❌ Save toggle failed: \(error.localizedDescription)")
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
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
            }
        }
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(themeColor.opacity(0.2))
            .frame(width: 44, height: 44)
            .overlay(
                Text(String(post.creatorName.prefix(1)).uppercased())
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(themeColor)
            )
    }
    
    // MARK: - Link Preview Card
    private var linkPreviewCard: some View {
        Button(action: onTap) {
            // Check if we have a rich link image
            if let linkImage = post.linkImage, !linkImage.isEmpty,
               let imageUrl = URL(string: linkImage) {
                // Rich Link Card with image
                VStack(alignment: .leading, spacing: 0) {
                    // Large image (16:9 aspect ratio)
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .aspectRatio(16/9, contentMode: .fit)
                                .overlay(
                                    ProgressView()
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 180)
                                .clipped()
                        case .failure:
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .aspectRatio(16/9, contentMode: .fit)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(.secondary)
                                )
                        @unknown default:
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .aspectRatio(16/9, contentMode: .fit)
                        }
                    }
                    
                    // Title and domain below image
                    VStack(alignment: .leading, spacing: 4) {
                        // Title (use link_title, fallback to post.title)
                        Text(post.linkTitle ?? post.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        // Domain in small gray text
                        Text(post.linkDomain ?? formattedUrl)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6).opacity(colorScheme == .dark ? 1.0 : 0.5))
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6).opacity(colorScheme == .dark ? 1.0 : 0.5))
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // Fallback: generic link card (no image available)
                HStack(spacing: 12) {
                    // Link icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeColor.opacity(0.1))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "link")
                            .font(.title2)
                            .foregroundColor(themeColor)
                    }
                    
                    // Title and URL
                    VStack(alignment: .leading, spacing: 4) {
                        Text(post.linkTitle ?? post.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Text(post.linkDomain ?? formattedUrl)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Chevron indicator
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6).opacity(colorScheme == .dark ? 1.0 : 0.5))
                )
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Card Background
    private var cardBackground: some View {
        Group {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(themeColor.opacity(0.15))
                    )
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
            }
        }
    }
    
    // MARK: - Formatted URL
    private var formattedUrl: String {
        if let url = URL(string: post.contentUrl) {
            return url.host ?? post.contentUrl
        }
        return post.contentUrl
    }
}

// MARK: - Safari View
/// UIViewControllerRepresentable for SFSafariViewController
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let safari = SFSafariViewController(url: url, configuration: config)
        return safari
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
