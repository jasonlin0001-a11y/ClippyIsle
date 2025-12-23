//
//  LinkPreviewCard.swift
//  ClippyIsle
//
//  SwiftUI view for displaying URL metadata in a card format
//  Enhanced with waterfall description extraction
//

import SwiftUI
import LinkPresentation

/// A card view that displays link metadata with async loading and error handling
struct LinkPreviewCard: View {
    let url: URL
    @StateObject private var metadataManager = LinkMetadataManager()
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                if metadataManager.isLoading {
                    loadingView
                } else if let error = metadataManager.error {
                    errorView(error: error)
                } else if let enhanced = metadataManager.enhancedMetadata {
                    contentView(enhanced: enhanced)
                }
            }
            .navigationTitle("Link Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            metadataManager.fetchEnhancedMetadata(for: url)
        }
        .onDisappear {
            metadataManager.cancel()
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading preview...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    private func errorView(error: Error) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Failed to Load Preview")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                metadataManager.fetchEnhancedMetadata(for: url)
            }) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Content View (Enhanced)
    private func contentView(enhanced: EnhancedLinkMetadata) -> some View {
        let metadata = enhanced.lpMetadata
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Card
                VStack(alignment: .leading, spacing: 12) {
                    // Image
                    if let imageProvider = metadata.imageProvider {
                        LinkImageView(imageProvider: imageProvider)
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(12)
                    }
                    
                    // Title
                    if let title = metadata.title {
                        Text(title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .lineLimit(3)
                    }
                    
                    // Description (from waterfall extraction)
                    if let description = enhanced.description {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(5)
                    }
                    
                    // URL as subtitle
                    if let url = metadata.url {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(url.absoluteString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                )
                .padding(.horizontal)
                
                Spacer()
            }
        }
    }
}

/// Helper view to load and display NSItemProvider images
struct LinkImageView: View {
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
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        imageProvider.loadObject(ofClass: UIImage.self) { (object, error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("⚠️ Failed to load link preview image: \(error.localizedDescription)")
                } else if let image = object as? UIImage {
                    self.image = image
                }
                self.isLoading = false
            }
        }
    }
}

// MARK: - Preview Provider
#Preview("Link Preview with Apple URL") {
    LinkPreviewCard(url: URL(string: "https://www.apple.com") ?? URL(string: "https://example.com")!)
}
