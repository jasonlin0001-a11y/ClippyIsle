//
//  InlineLinkPreview.swift
//  ClippyIsle
//
//  Inline compact preview for URL metadata
//

import SwiftUI
import LinkPresentation

/// A compact inline view that displays link metadata between list items
struct InlineLinkPreview: View {
    let url: URL
    @State private var metadata: LPLinkMetadata?
    @State private var isLoading = true
    @State private var hasError = false
    @Environment(\.colorScheme) var colorScheme
    
    // Constants for timeout handling
    private static let fetchTimeoutSeconds: TimeInterval = 10.0
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingView
            } else if hasError {
                errorView
            } else if let metadata = metadata {
                contentView(metadata: metadata)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .task {
            // Check cache first (synchronous, outside async to avoid Task overhead)
            if let cached = LinkMetadataManager.shared.getCachedMetadata(for: url) {
                metadata = cached
                isLoading = false
                LaunchLogger.log("InlineLinkPreview.task - Using cached metadata for \(url)")
            } else {
                // Fetch metadata if not cached
                await fetchMetadata()
            }
        }
    }
    
    @MainActor
    private func fetchMetadata() async {
        LaunchLogger.log("InlineLinkPreview.task - START fetching metadata for \(url)")
        
        do {
            // Use async/await pattern with timeout
            let result = try await withTimeout(seconds: Self.fetchTimeoutSeconds) {
                await LinkMetadataManager.shared.fetchMetadata(for: url)
            }
            
            if let fetchedMetadata = result {
                metadata = fetchedMetadata
                isLoading = false
                LaunchLogger.log("InlineLinkPreview.task - SUCCESS fetching metadata for \(url)")
            } else {
                hasError = true
                isLoading = false
                LaunchLogger.log("InlineLinkPreview.task - FAILED fetching metadata for \(url)")
            }
        } catch {
            hasError = true
            isLoading = false
            LaunchLogger.log("InlineLinkPreview.task - TIMEOUT fetching metadata for \(url)")
        }
    }
    
    /// Helper to add timeout to async operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the actual operation
            group.addTask {
                await operation()
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw TimeoutError()
            }
            
            // Return first result (either success or timeout)
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            
            // Cancel remaining tasks
            group.cancelAll()
            
            return result
        }
    }
    
    private struct TimeoutError: Error {}
    
    
    // MARK: - Loading View
    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading preview...")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(12)
    }
    
    // MARK: - Error View
    private var errorView: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
                .font(.caption)
            Text("Failed to load preview")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(12)
    }
    
    // MARK: - Content View
    private func contentView(metadata: LPLinkMetadata) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Image (if available)
            if let imageProvider = metadata.imageProvider {
                CompactLinkImageView(imageProvider: imageProvider)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 6) {
                // Title
                if let title = metadata.title {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                }
                
                // URL
                if let url = metadata.url {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(url.host ?? url.absoluteString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
    }
}

/// Helper view to load and display images in compact format
struct CompactLinkImageView: View {
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
                if let error = error {
                    print("⚠️ Failed to load compact link preview image: \(error.localizedDescription)")
                } else if let image = object as? UIImage {
                    self.image = image
                }
                self.isLoading = false
            }
        }
    }
}

// MARK: - Preview Provider
#Preview("Inline Link Preview") {
    InlineLinkPreview(url: URL(string: "https://www.apple.com") ?? URL(string: "https://example.com")!)
        .padding()
}
