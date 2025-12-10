//
//  InlineTextPreview.swift
//  ClippyIsle
//
//  Inline compact preview for text items
//

import SwiftUI

/// A compact inline view that displays text preview between list items
struct InlineTextPreview: View {
    let text: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
#Preview("Inline Text Preview") {
    InlineTextPreview(text: "This is a sample text preview that shows how the text content will be displayed in a compact inline format.")
        .padding()
}
