//
//  DiscoveryFeedView.swift
//  ClippyIsle
//
//  Discovery Feed View - displays all creator posts from Firestore.
//

import SwiftUI
import SafariServices

// MARK: - Discovery Feed View
/// Displays all creator posts from the creator_posts collection
struct DiscoveryFeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var selectedURL: URL?
    @State private var showSafari = false
    
    let themeColor: Color
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            if viewModel.isDiscoveryLoading && viewModel.discoveryPosts.isEmpty {
                loadingView
            } else if viewModel.isDiscoveryEmpty && viewModel.discoveryPosts.isEmpty {
                emptyStateView
            } else if let error = viewModel.discoveryError {
                errorView(error)
            } else {
                feedList
            }
        }
        .onAppear {
            // Setup real-time listener when view appears
            viewModel.setupDiscoveryListener()
        }
        .onDisappear {
            // Remove listener when view disappears
            viewModel.removeDiscoveryListener()
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
                ForEach(viewModel.discoveryPosts) { post in
                    CreatorPostCell(
                        post: post,
                        themeColor: themeColor,
                        onTap: {
                            if let url = URL(string: post.contentUrl) {
                                selectedURL = url
                                showSafari = true
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
            .padding(.top, 60) // Account for floating header
        }
        .refreshable {
            await viewModel.fetchDiscoveryFeed()
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
