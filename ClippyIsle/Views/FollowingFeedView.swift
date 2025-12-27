//
//  FollowingFeedView.swift
//  ClippyIsle
//
//  Following Feed View - displays posts from followed creators.
//

import SwiftUI
import SafariServices
import LinkPresentation

// MARK: - Following Feed View
/// Displays the feed of posts from creators the user follows
struct FollowingFeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @StateObject private var safetyService = SafetyService.shared
    @State private var selectedURL: URL?
    @State private var showSafari = false
    @State private var showSaveToast = false
    @State private var saveToastMessage = ""
    @State private var showBlockToast = false
    @State private var blockToastMessage = ""
    @State private var showReportToast = false
    
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
            
            // Block Toast
            if showBlockToast {
                VStack {
                    Spacer()
                    Text(blockToastMessage)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.red.opacity(0.9))
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 100)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showBlockToast)
            }
            
            // Report Toast
            if showReportToast {
                VStack {
                    Spacer()
                    Text("Report submitted / 檢舉已提交 ✓")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.9))
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 100)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showReportToast)
            }
        }
        .task {
            await viewModel.fetchFollowingFeed()
            await safetyService.loadBlockedUsers()
        }
        .sheet(isPresented: $showSafari) {
            if let url = selectedURL {
                SafariView(url: url)
            }
        }
    }
    
    // MARK: - Filtered Posts (excluding blocked users and hidden posts)
    private var filteredPosts: [FeedPost] {
        viewModel.feedPosts.filter { 
            !safetyService.isUserBlocked(userId: $0.creatorUid) && !$0.isHidden
        }
    }
    
    // MARK: - Feed List
    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredPosts) { post in
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
                        },
                        onUserBlocked: { uid, name in
                            showBlockToastMessage(userName: name)
                        },
                        onPostReported: {
                            showReportToastMessage()
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
        saveToastMessage = isSaved ? "Saved to My Isle 🔖" : "Removed from My Isle"
        showSaveToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSaveToast = false
        }
    }
    
    // MARK: - Show Block Toast
    private func showBlockToastMessage(userName: String) {
        blockToastMessage = "Blocked \(userName). Content hidden. / 已封鎖 \(userName)。內容已隱藏。"
        showBlockToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showBlockToast = false
        }
    }
    
    // MARK: - Show Report Toast
    private func showReportToastMessage() {
        showReportToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showReportToast = false
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
    /// Auto-load link preview client-side when no pre-saved image exists (default: false for My Isle, true for Discovery)
    var autoLoadPreview: Bool = false
    /// Callback when save button is tapped (shows toast)
    var onSaveToggle: ((Bool) -> Void)? = nil
    /// Callback when user is blocked
    var onUserBlocked: ((String, String) -> Void)? = nil
    /// Callback when post is reported
    var onPostReported: (() -> Void)? = nil
    /// Callback when post is deleted by admin
    var onPostDeleted: (() -> Void)? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var engagementService = EngagementService.shared
    @StateObject private var safetyService = SafetyService.shared
    
    // Animation states
    @State private var isLikeAnimating = false
    @State private var isSaveAnimating = false
    
    // Report/Block states
    @State private var showReportSheet = false
    @State private var showBlockConfirmation = false
    @State private var showAdminDeleteConfirmation = false
    @State private var selectedReportReason: Report.ReportReason?
    
    // Client-side preview loading states (for autoLoadPreview mode)
    @State private var isLoadingClientPreview = false
    @State private var clientFetchedMetadata: EnhancedLinkMetadata?
    @State private var clientPreviewError = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Creator Avatar + Name + Time (tappable for profile) + Follow Button + More Menu
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
                
                // More menu (Report/Block)
                moreMenu
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
        // CASE A: Web Portal Post - has pre-saved link_image from Firestore
        // Show rich preview immediately without user interaction
        if let linkImage = post.linkImage, !linkImage.isEmpty {
            return AnyView(richLinkPreviewCard(imageUrlString: linkImage))
        } 
        // CASE B: Client-fetched metadata available (from auto-load)
        else if let metadata = clientFetchedMetadata, metadata.lpMetadata.imageProvider != nil {
            return AnyView(clientFetchedPreviewCard(metadata: metadata))
        }
        // CASE C: Auto-load mode - fetch client-side preview automatically
        else if autoLoadPreview {
            return AnyView(autoLoadingPreviewCard)
        }
        // CASE D: No pre-saved image and no auto-load - show fallback generic card
        else {
            return AnyView(fallbackLinkCard)
        }
    }
    
    // Auto-loading preview card (triggers client-side fetch)
    private var autoLoadingPreviewCard: some View {
        Group {
            if isLoadingClientPreview {
                // Loading state
                Button(action: onTap) {
                    HStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading preview...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6).opacity(colorScheme == .dark ? 1.0 : 0.5))
                    )
                }
                .buttonStyle(.plain)
            } else if clientPreviewError {
                // Error state - show fallback
                fallbackLinkCard
            } else {
                // Trigger loading on appear
                fallbackLinkCard
                    .onAppear {
                        loadClientPreview()
                    }
            }
        }
    }
    
    // Load client-side preview
    private func loadClientPreview() {
        guard !isLoadingClientPreview, clientFetchedMetadata == nil, !clientPreviewError else { return }
        guard let url = URL(string: post.contentUrl) else {
            clientPreviewError = true
            return
        }
        
        isLoadingClientPreview = true
        
        Task {
            // Check cache first
            if let cached = LinkMetadataManager.shared.getCachedEnhancedMetadata(for: url) {
                await MainActor.run {
                    clientFetchedMetadata = cached
                    isLoadingClientPreview = false
                }
                return
            }
            
            // Fetch metadata
            if let metadata = await LinkMetadataManager.shared.fetchEnhancedMetadata(for: url) {
                await MainActor.run {
                    clientFetchedMetadata = metadata
                    isLoadingClientPreview = false
                }
            } else {
                await MainActor.run {
                    clientPreviewError = true
                    isLoadingClientPreview = false
                }
            }
        }
    }
    
    // Client-fetched preview card (from auto-load)
    private func clientFetchedPreviewCard(metadata: EnhancedLinkMetadata) -> some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Image (if available)
                if let imageProvider = metadata.lpMetadata.imageProvider {
                    ClientPreviewImageView(imageProvider: imageProvider)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(metadata.lpMetadata.title ?? post.linkTitle ?? post.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    // Description
                    if let description = metadata.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Domain
                    Text(post.linkDomain ?? formattedUrl)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6).opacity(colorScheme == .dark ? 1.0 : 0.5))
            )
        }
        .buttonStyle(.plain)
    }
    
    // Rich link preview card with image (for Web Portal posts with link_image)
    private func richLinkPreviewCard(imageUrlString: String) -> some View {
        // Parse URL, handling potential encoding issues
        let parsedImageUrl: URL? = {
            if let url = URL(string: imageUrlString) { return url }
            if let encoded = imageUrlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: encoded) { return url }
            return nil
        }()
        
        return Button(action: onTap) {
            if let imageUrl = parsedImageUrl {
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
                        Text(post.linkTitle ?? post.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
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
                // URL parsing failed, show fallback
                fallbackLinkCard
            }
        }
        .buttonStyle(.plain)
    }
    
    // Fallback generic link card (no image available)
    private var fallbackLinkCard: some View {
        Button(action: onTap) {
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
    
    // MARK: - More Menu (Report/Block/Admin Delete)
    private var moreMenu: some View {
        Menu {
            // Report Post
            Button(role: .none) {
                showReportSheet = true
            } label: {
                Label("Report Post / 檢舉貼文", systemImage: "exclamationmark.triangle")
            }
            
            // Block User (destructive)
            if !post.creatorUid.isEmpty {
                Button(role: .destructive) {
                    showBlockConfirmation = true
                } label: {
                    Label("Block User / 封鎖用戶", systemImage: "nosign")
                }
            }
            
            // Admin Delete (only visible to admins)
            if safetyService.isCurrentUserAdmin() {
                Divider()
                
                Button(role: .destructive) {
                    showAdminDeleteConfirmation = true
                } label: {
                    Label("Delete Post (Admin)", systemImage: "trash.fill")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .sheet(isPresented: $showReportSheet) {
            ReportPostSheet(
                postId: post.id,
                onReport: { reason in
                    submitReport(reason: reason)
                }
            )
        }
        .alert("Block User / 封鎖用戶", isPresented: $showBlockConfirmation) {
            Button("Cancel / 取消", role: .cancel) {}
            Button("Block / 封鎖", role: .destructive) {
                blockUser()
            }
        } message: {
            Text("Block \(post.creatorName)? You won't see their posts anymore.\n\n封鎖 \(post.creatorName)？你將不再看到他們的貼文。")
        }
        .alert("Delete Post (Admin)", isPresented: $showAdminDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                adminDeletePost()
            }
        } message: {
            Text("Permanently delete this post? This action cannot be undone.\n\n永久刪除此貼文？此操作無法撤銷。")
        }
    }
    
    // MARK: - Submit Report
    private func submitReport(reason: Report.ReportReason) {
        Task {
            do {
                try await safetyService.reportPost(postId: post.id, reason: reason)
                
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Notify parent
                onPostReported?()
            } catch {
                print("❌ Report failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Block User
    private func blockUser() {
        Task {
            do {
                try await safetyService.blockUser(targetUid: post.creatorUid, displayName: post.creatorName)
                
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Notify parent
                onUserBlocked?(post.creatorUid, post.creatorName)
            } catch {
                print("❌ Block failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Admin Delete Post
    private func adminDeletePost() {
        Task {
            do {
                try await safetyService.adminDeletePost(postId: post.id)
                
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Notify parent
                onPostDeleted?()
            } catch {
                print("❌ Admin delete failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Client Preview Image View (for auto-loaded link previews)
/// Helper view to display images from NSItemProvider
struct ClientPreviewImageView: View {
    let imageProvider: NSItemProvider
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
        }
        .frame(width: 80, height: 80)
        .background(Color.gray.opacity(0.1))
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        imageProvider.loadObject(ofClass: UIImage.self) { (object, error) in
            DispatchQueue.main.async {
                if let image = object as? UIImage {
                    self.image = image
                }
                self.isLoading = false
            }
        }
    }
}

// MARK: - Report Post Sheet
/// Sheet for selecting a report reason
struct ReportPostSheet: View {
    let postId: String
    let onReport: (Report.ReportReason) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: Report.ReportReason?
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(Report.ReportReason.allCases, id: \.self) { reason in
                        Button {
                            selectedReason = reason
                        } label: {
                            HStack {
                                Text(reason.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedReason == reason {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Why are you reporting this post?\n為什麼要檢舉這則貼文？")
                }
            }
            .navigationTitle("Report / 檢舉")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel / 取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit / 提交") {
                        if let reason = selectedReason {
                            onReport(reason)
                            dismiss()
                        }
                    }
                    .disabled(selectedReason == nil)
                }
            }
        }
        .presentationDetents([.medium])
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
