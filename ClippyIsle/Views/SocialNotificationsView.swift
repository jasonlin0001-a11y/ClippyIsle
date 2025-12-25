//
//  SocialNotificationsView.swift
//  ClippyIsle
//
//  View for displaying social notifications (new followers, etc.)
//

import SwiftUI

// MARK: - Social Notifications View
/// Displays the list of social notifications
struct SocialNotificationsView: View {
    @StateObject private var notificationService = SocialNotificationService.shared
    @State private var showClearAllConfirmation = false
    @Environment(\.dismiss) var dismiss
    
    // Theme Color Support
    @AppStorage("themeColorName") private var themeColorName: String = "green"
    @AppStorage("customColorRed") private var customColorRed: Double = 0.0
    @AppStorage("customColorGreen") private var customColorGreen: Double = 0.478
    @AppStorage("customColorBlue") private var customColorBlue: Double = 1.0
    
    var themeColor: Color {
        if themeColorName == "custom" {
            return Color(red: customColorRed, green: customColorGreen, blue: customColorBlue)
        }
        return ClippyIsleAttributes.ColorUtility.color(forName: themeColorName)
    }
    
    var body: some View {
        NavigationView {
            Group {
                if notificationService.notifications.isEmpty {
                    emptyStateView
                } else {
                    notificationsList
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !notificationService.notifications.isEmpty {
                        Button("Mark All Read") {
                            Task {
                                try? await notificationService.markAllAsRead()
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                notificationService.listenToNotifications()
            }
        }
        .tint(themeColor)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Notifications")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("尚未有通知")
                .font(.body)
                .foregroundColor(.secondary)
            
            Text("When someone follows you, you'll see it here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    private var notificationsList: some View {
        List {
            ForEach(notificationService.notifications) { notification in
                SocialNotificationRow(
                    notification: notification,
                    themeColor: themeColor,
                    onTap: {
                        // Mark as read when tapped
                        Task {
                            try? await notificationService.markAsRead(notificationId: notification.id)
                        }
                    }
                )
            }
            .onDelete { offsets in
                Task {
                    for offset in offsets {
                        let notification = notificationService.notifications[offset]
                        try? await notificationService.deleteNotification(notificationId: notification.id)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Social Notification Row
/// A single notification row with navigation to creator profile
struct SocialNotificationRow: View {
    let notification: SocialNotification
    let themeColor: Color
    let onTap: () -> Void
    
    var body: some View {
        NavigationLink(destination: CreatorProfileView(
            targetUid: notification.fromUserId,
            targetDisplayName: notification.fromUserName
        )) {
            HStack(spacing: 12) {
                // Unread indicator
                Circle()
                    .fill(notification.isRead ? Color.clear : themeColor)
                    .frame(width: 10, height: 10)
                
                // Avatar
                avatarView
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Main text
                    HStack(spacing: 4) {
                        Text(notification.fromUserName)
                            .font(.body)
                            .fontWeight(notification.isRead ? .regular : .semibold)
                            .foregroundColor(.primary)
                        
                        Text(notification.type.localizedDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Chinese text for new follower
                    if notification.type == .newFollower {
                        Text("開始追蹤你")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Timestamp
                    Text(notification.timestamp.timeAgoDisplay())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Notification type icon
                Image(systemName: notification.type.iconName)
                    .foregroundColor(themeColor)
                    .font(.title3)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded {
            onTap()
        })
    }
    
    @ViewBuilder
    private var avatarView: some View {
        if let avatarUrl = notification.fromUserAvatarUrl,
           let url = URL(string: avatarUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure(_), .empty:
                    avatarPlaceholder
                @unknown default:
                    avatarPlaceholder
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
        } else {
            avatarPlaceholder
        }
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(themeColor.opacity(0.2))
            .frame(width: 44, height: 44)
            .overlay(
                Text(String(notification.fromUserName.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundColor(themeColor)
            )
    }
}

// MARK: - Preview
#Preview {
    SocialNotificationsView()
}
