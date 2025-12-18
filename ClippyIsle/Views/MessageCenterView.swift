import SwiftUI
import UniformTypeIdentifiers

// MARK: - Message Center View
/// Displays all pending notifications from app shares and deep links
/// Users can view, import items, or delete notifications
struct MessageCenterView: View {
    @ObservedObject var notificationManager: NotificationManager
    @ObservedObject var clipboardManager: ClipboardManager
    @State private var selectedNotification: NotificationItem?
    @State private var showImportDialog = false
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
                if notificationManager.notifications.isEmpty {
                    emptyStateView
                } else {
                    notificationsList
                }
            }
            .navigationTitle("Message Center")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !notificationManager.notifications.isEmpty {
                        Button("Clear All") {
                            notificationManager.clearAll()
                        }
                        .foregroundColor(.red)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .tint(themeColor)
        .sheet(isPresented: $showImportDialog) {
            if let notification = selectedNotification {
                MessageCenterImportView(
                    clipboardManager: clipboardManager,
                    notification: notification,
                    notificationManager: notificationManager,
                    isPresented: $showImportDialog
                )
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Messages")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Shared items from links or app shares will appear here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    private var notificationsList: some View {
        List {
            ForEach(notificationManager.notifications) { notification in
                NotificationRowView(
                    notification: notification,
                    themeColor: themeColor,
                    onTap: {
                        selectedNotification = notification
                        showImportDialog = true
                    }
                )
            }
            .onDelete { offsets in
                notificationManager.deleteNotifications(at: offsets)
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Notification Row View
struct NotificationRowView: View {
    let notification: NotificationItem
    let themeColor: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Unread indicator
                Circle()
                    .fill(notification.isRead ? Color.clear : themeColor)
                    .frame(width: 10, height: 10)
                
                // Icon based on source
                Image(systemName: notification.source == .appShare ? "square.and.arrow.up" : "link")
                    .font(.title3)
                    .foregroundColor(themeColor)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text("\(notification.items.count) item(s) received")
                        .font(.body)
                        .fontWeight(notification.isRead ? .regular : .semibold)
                        .foregroundColor(.primary)
                    
                    // Preview of first item
                    if let firstItem = notification.items.first {
                        Text(firstItem.displayName ?? firstItem.content)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Timestamp and source
                    HStack {
                        Text(notification.source == .appShare ? "App Share" : "Link Share")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        Text(notification.timestamp.timeAgoDisplay())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Message Center Import View
/// View for importing items from a notification in the message center
struct MessageCenterImportView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    let notification: NotificationItem
    @ObservedObject var notificationManager: NotificationManager
    @Binding var isPresented: Bool
    @State private var selectedItems: Set<UUID> = []
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
            VStack(spacing: 0) {
                // Header info
                HStack {
                    Image(systemName: notification.source == .appShare ? "square.and.arrow.up" : "link")
                        .font(.title2)
                        .foregroundColor(themeColor)
                    Text("Received \(notification.items.count) item(s)")
                        .font(.headline)
                    Spacer()
                    Text(notification.timestamp.timeAgoDisplay())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Selection controls
                HStack {
                    Button(action: selectAll) {
                        Text("Select All")
                            .font(.subheadline)
                    }
                    .disabled(selectedItems.count == notification.items.count)
                    
                    Spacer()
                    
                    Text("\(selectedItems.count) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: deselectAll) {
                        Text("Deselect All")
                            .font(.subheadline)
                    }
                    .disabled(selectedItems.isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Items list
                List {
                    ForEach(notification.items) { item in
                        Button(action: { toggleSelection(item) }) {
                            HStack(spacing: 12) {
                                // Selection indicator
                                Image(systemName: selectedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedItems.contains(item.id) ? themeColor : .secondary)
                                    .font(.title3)
                                
                                // Item icon
                                Text(itemIcon(for: item.type))
                                    .font(.system(size: 20))
                                
                                // Item content
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.displayName ?? item.content)
                                        .lineLimit(2)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    HStack(spacing: 8) {
                                        // Show tags if any
                                        if let tags = item.tags, !tags.isEmpty {
                                            ForEach(tags.prefix(3), id: \.self) { tag in
                                                Text(tag)
                                                    .font(.caption2)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 2)
                                                    .background(Color.gray.opacity(0.2))
                                                    .cornerRadius(4)
                                            }
                                            if tags.count > 3 {
                                                Text("+\(tags.count - 3)")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        // Item type indicator
                                        Text(itemTypeLabel(for: item.type))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Import Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        // Mark as read when viewing
                        notificationManager.markAsRead(notification)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") {
                        importSelectedItems()
                    }
                    .disabled(selectedItems.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .tint(themeColor)
        .onAppear {
            // Pre-select all items by default
            selectedItems = Set(notification.items.map { $0.id })
            // Mark as read when opening
            notificationManager.markAsRead(notification)
        }
    }
    
    private func toggleSelection(_ item: ClipboardItem) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }
    
    private func selectAll() {
        selectedItems = Set(notification.items.map { $0.id })
    }
    
    private func deselectAll() {
        selectedItems.removeAll()
    }
    
    private func importSelectedItems() {
        let itemsToImport = notification.items.filter { selectedItems.contains($0.id) }
        
        for item in itemsToImport {
            // Create new item with fresh timestamp for import
            let importedItem = ClipboardItem(
                content: item.content,
                type: item.type,
                filename: item.filename,
                timestamp: Date(),
                isPinned: false,
                displayName: item.displayName,
                isTrashed: false,
                tags: item.tags,
                fileData: item.fileData
            )
            
            // Insert at beginning
            clipboardManager.items.insert(importedItem, at: 0)
        }
        
        // Save all changes at once
        clipboardManager.sortAndSave()
        
        // Delete the notification after successful import
        notificationManager.deleteNotification(notification)
        
        print("✅ Successfully imported \(itemsToImport.count) item(s) from message center")
        
        dismiss()
    }
    
    private func itemTypeLabel(for type: String) -> String {
        switch type {
        case UTType.url.identifier:
            return "URL"
        case UTType.png.identifier, UTType.jpeg.identifier:
            return "Image"
        case UTType.pdf.identifier:
            return "PDF"
        case UTType.rtf.identifier:
            return "RTF"
        default:
            return "Text"
        }
    }
}
