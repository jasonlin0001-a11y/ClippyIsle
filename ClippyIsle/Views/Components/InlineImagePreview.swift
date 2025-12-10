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
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            if let imageData = imageData, let uiImage = UIImage(data: imageData) {
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
                .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Preview Provider
#Preview("Inline Image Preview") {
    InlineImagePreview(imageData: nil)
        .padding()
}
