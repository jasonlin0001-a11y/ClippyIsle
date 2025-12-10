//
//  CompactItemPreview.swift
//  ClippyIsle
//
//  Lightweight compact preview for clipboard items
//

import SwiftUI
import UniformTypeIdentifiers

/// A very lightweight inline preview that shows a small indicator for each item type
/// No async operations or network calls to ensure smooth scrolling performance
struct CompactItemPreview: View {
    let item: ClipboardItem
    let clipboardManager: ClipboardManager
    
    // Constants
    private static let textPreviewMaxLength = 50
    
    var body: some View {
        Group {
            if item.type == UTType.url.identifier {
                urlPreview
            } else if item.type == UTType.png.identifier || item.type == UTType.jpeg.identifier {
                imagePreview
            } else if item.type == UTType.plainText.identifier || item.type == UTType.text.identifier {
                textPreview
            }
        }
    }
    
    // URL preview: Just show the URL domain/path without fetching metadata
    private var urlPreview: some View {
        HStack(spacing: 8) {
            Image(systemName: "link.circle.fill")
                .foregroundColor(.blue)
                .font(.caption)
            
            if let url = URL(string: item.content) {
                VStack(alignment: .leading, spacing: 2) {
                    if let host = url.host {
                        Text(host)
                            .font(.caption2)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    Text(url.absoluteString)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    // Image preview: Show thumbnail only if data is already loaded
    private var imagePreview: some View {
        HStack(spacing: 8) {
            // Only show image if fileData is already available (no async loading)
            if let data = item.fileData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "photo.circle.fill")
                    .foregroundColor(.purple)
                    .font(.title2)
                    .frame(width: 60, height: 60)
            }
            
            Text("Image")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.purple.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    // Text preview: Show first N characters
    private var textPreview: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text")
                .foregroundColor(.green)
                .font(.caption)
            
            Text(item.content.prefix(Self.textPreviewMaxLength))
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            if item.content.count > Self.textPreviewMaxLength {
                Text("...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}
