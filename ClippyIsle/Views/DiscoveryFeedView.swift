//
//  DiscoveryFeedView.swift
//  ClippyIsle
//
//  Discovery Feed View - displays all creator posts from Firestore.
//

import SwiftUI
import SafariServices

// MARK: - Identifiable URL Wrapper
/// Wrapper to make URL identifiable for sheet presentation
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Discovery Feed View
/// Displays all creator posts from the creator_posts collection
struct DiscoveryFeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @StateObject private var safetyService = SafetyService.shared
    @State private var selectedURL: IdentifiableURL?
    @State private var showSaveToast = false
    @State private var saveToastMessage = ""
    @State private var showBlockToast = false
    @State private var blockToastMessage = ""
    @State private var showReportToast = false
    
    let themeColor: Color
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            if viewModel.isDiscoveryLoading && viewModel.discoveryPosts.isEmpty {
                loadingView
            } else if viewModel.isDiscoveryEmpty && filteredPosts.isEmpty {
                emptyStateView
            } else if let error = viewModel.discoveryError {
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
        .onAppear {
            // Setup real-time listener when view appears
            viewModel.setupDiscoveryListener()
            // Load blocked users for filtering
            Task {
                await safetyService.loadBlockedUsers()
            }
        }
        .onDisappear {
            // Remove listener when view disappears
            viewModel.removeDiscoveryListener()
        }
        .sheet(item: $selectedURL) { identifiableURL in
            SafariView(url: identifiableURL.url)
        }
    }
    
    // MARK: - Filtered Posts (excluding blocked users and hidden posts)
    private var filteredPosts: [FeedPost] {
        viewModel.discoveryPosts.filter { 
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
                                selectedURL = IdentifiableURL(url: url)
                            }
                        },
                        autoLoadPreview: true, // Auto-load link previews in Discovery feed
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
            await viewModel.fetchDiscoveryFeed()
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
            Text("Loading posts...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "newspaper")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No posts yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Be the first to share something!\nTap the + button to create a post.")
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
            
            Text("Error loading posts")
                .font(.headline)
            
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                viewModel.setupDiscoveryListener()
            }
            .buttonStyle(.borderedProminent)
            .tint(themeColor)
        }
        .padding()
    }
}
