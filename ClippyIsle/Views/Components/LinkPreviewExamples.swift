//
//  LinkPreviewExamples.swift
//  ClippyIsle
//
//  Example usage and test cases for LinkPresentation integration
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Example URLs for Testing

struct LinkPreviewExamples {
    /// Sample URLs for testing the link preview feature
    static let sampleURLs = [
        "https://www.apple.com",
        "https://github.com",
        "https://www.nytimes.com",
        "https://www.bbc.com/news",
        "https://www.wikipedia.org",
        "https://developer.apple.com/swift/",
        "https://www.youtube.com",
        "https://stackoverflow.com"
    ]
    
    /// Create sample ClipboardItems with URLs for testing
    static func createSampleURLItems() -> [ClipboardItem] {
        sampleURLs.map { urlString in
            ClipboardItem(
                content: urlString,
                type: UTType.url.identifier,
                timestamp: Date(),
                isPinned: false,
                displayName: nil,
                isTrashed: false,
                tags: nil
            )
        }
    }
}

// MARK: - Test View for Preview

/// A test view to demonstrate the link preview functionality
struct LinkPreviewTestView: View {
    @State private var showPreview = false
    @State private var selectedURL: URL?
    
    let testURLs = LinkPreviewExamples.sampleURLs
    
    var body: some View {
        NavigationView {
            List {
                Section("Test URLs") {
                    ForEach(testURLs, id: \.self) { urlString in
                        Button(action: {
                            if let url = URL(string: urlString) {
                                selectedURL = url
                                showPreview = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "link")
                                    .foregroundColor(.blue)
                                Text(urlString)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                
                Section("Instructions") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How to Test:")
                            .font(.headline)
                        
                        Text("1. Tap any URL above to see the link preview")
                        Text("2. In the main app, long press any URL item to trigger preview")
                        Text("3. Check loading state, error handling, and content display")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Link Preview Test")
            .sheet(isPresented: $showPreview) {
                if let url = selectedURL {
                    LinkPreviewCard(url: url)
                }
            }
        }
    }
}

// MARK: - Preview Provider

#Preview("Link Preview Test") {
    LinkPreviewTestView()
}

#Preview("Single Link Preview") {
    if let url = URL(string: "https://www.apple.com") {
        LinkPreviewCard(url: url)
    }
}
