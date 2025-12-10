//
//  InlineImagePreview.swift
//  ClippyIsle
//
//  Inline compact preview for image items
//

import SwiftUI
import UniformTypeIdentifiers

/// A compact inline view that displays image preview between list items
struct InlineImagePreview: View {
    let imageData: Data?
    let filename: String?
    let loadFileData: ((String) -> Data?)?
    
    @State private var loadedImageData: Data?
    @State private var isLoading: Bool = false
    
    init(imageData: Data?, filename: String? = nil, loadFileData: ((String) -> Data?)? = nil) {
        self.imageData = imageData
        self.filename = filename
        self.loadFileData = loadFileData
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading image...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(12)
            } else if let data = loadedImageData ?? imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(12)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("Image preview unavailable")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .task {
            if imageData == nil, let filename = filename, let loadFileData = loadFileData {
                isLoading = true
                loadedImageData = await Task.detached(priority: .userInitiated) {
                    loadFileData(filename)
                }.value
                isLoading = false
            }
        }
    }
}

// MARK: - Preview Provider
#Preview("Inline Image Preview") {
    InlineImagePreview(imageData: nil)
        .padding()
}
