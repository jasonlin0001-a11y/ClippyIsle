//
//  UserRowView.swift
//  ClippyIsle
//
//  A reusable SwiftUI component for displaying a user row in a list.
//  Shows avatar, name, and follow button with navigation to profile.
//

import SwiftUI

// MARK: - User Row View
/// A reusable row component for displaying a user in a list.
/// Includes avatar, name, and follow button with navigation to profile.
struct UserRowView: View {
    let userId: String
    let displayName: String
    let avatarUrl: String?
    let themeColor: Color
    
    /// Set to false when showing current user's own profile
    var showFollowButton: Bool = true
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(userId: String, displayName: String, avatarUrl: String? = nil, themeColor: Color = .blue, showFollowButton: Bool = true) {
        self.userId = userId
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.themeColor = themeColor
        self.showFollowButton = showFollowButton
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Navigation area (Avatar + Name)
            NavigationLink(destination: CreatorProfileView(
                targetUserId: userId,
                targetUserName: displayName,
                themeColor: themeColor
            )) {
                HStack(spacing: 12) {
                    // Avatar
                    userAvatar
                    
                    // Display Name
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text("@\(userId.prefix(8))...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Follow Button (independent from navigation)
            if showFollowButton {
                CompactFollowButton(targetUid: userId, targetDisplayName: displayName)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(colorScheme == .dark ? Color(.systemGray6) : Color.white)
    }
    
    // MARK: - User Avatar
    private var userAvatar: some View {
        Group {
            if let avatarUrlString = avatarUrl,
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
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                avatarPlaceholder
            }
        }
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(themeColor.opacity(0.2))
            .frame(width: 40, height: 40)
            .overlay(
                Text(String(displayName.prefix(1)).uppercased())
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(themeColor)
            )
    }
}

// MARK: - Preview
#if DEBUG
struct UserRowView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            VStack(spacing: 0) {
                UserRowView(
                    userId: "user_123",
                    displayName: "John Doe",
                    avatarUrl: nil,
                    themeColor: .blue
                )
                
                Divider()
                
                UserRowView(
                    userId: "creator_456",
                    displayName: "Creative Creator",
                    avatarUrl: "https://picsum.photos/100",
                    themeColor: .purple
                )
                
                Divider()
                
                UserRowView(
                    userId: "current_user",
                    displayName: "Current User",
                    avatarUrl: nil,
                    themeColor: .green,
                    showFollowButton: false
                )
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}
#endif
