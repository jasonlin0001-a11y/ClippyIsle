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
    @Environment(\.colorScheme) var colorScheme
    
    // Theme Color Support
    @AppStorage("themeColorName") private var themeColorName: String = "blue"
    @AppStorage("customColorRed") private var customColorRed: Double = 0.0
    @AppStorage("customColorGreen") private var customColorGreen: Double = 0.478
    @AppStorage("customColorBlue") private var customColorBlue: Double = 1.0
    
    var themeColor: Color {
        if themeColorName == "custom" {
            return Color(red: customColorRed, green: customColorGreen, blue: customColorBlue)
        }
        return ClippyIsleAttributes.ColorUtility.color(forName: themeColorName)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? ClippyIsleAttributes.ColorUtility.darkCard : Color(.systemBackground)
    }
    
    private var cardBorder: Color {
        colorScheme == .dark ? ClippyIsleAttributes.ColorUtility.darkBorder : Color(.separator).opacity(0.3)
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
            .background(colorScheme == .dark ? ClippyIsleAttributes.ColorUtility.darkBackground : Color(.systemGroupedBackground))
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
                .font(.system(size: 60, weight: .light))
                .foregroundColor(.secondary)
            
            Text("No Messages")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            
            Text("Shared items from links or app shares will appear here")
                .font(.system(size: 15, weight: .regular, design: .rounded))
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
                    cardBackground: cardBackground,
                    cardBorder: cardBorder,
                    onTap: {
                        selectedNotification = notification
                        showImportDialog = true
                    }
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onDelete { offsets in
                notificationManager.deleteNotifications(at: offsets)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Notification Row View
struct NotificationRowView: View {
    let notification: NotificationItem
    let themeColor: Color
    let cardBackground: Color
    let cardBorder: Color
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Unread indicator
                Circle()
                    .fill(notification.isRead ? Color.clear : themeColor)
                    .frame(width: 10, height: 10)
                
                // Icon with modern styling
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(themeColor.opacity(colorScheme == .dark ? 0.2 : 0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: notification.source == .appShare ? "square.and.arrow.up" : "link")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(themeColor)
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    // Title
                    Text("\(notification.items.count) item(s) received")
                        .font(.system(size: 15, weight: notification.isRead ? .medium : .semibold, design: .rounded))
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                    
                    // Preview of first item
                    if let firstItem = notification.items.first {
                        Text(firstItem.displayName ?? firstItem.content)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Timestamp and source
                    HStack {
                        Text(notification.source == .appShare ? "App Share" : "Link Share")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.gray.opacity(0.15))
                            )
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.7) : .secondary)
                        
                        Spacer()
                        
                        Text(notification.timestamp.timeAgoDisplay())
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(cardBackground)
                    .shadow(color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(cardBorder, lineWidth: 0.5)
            )
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
    @Environment(\.colorScheme) var colorScheme
    
    // Theme Color Support
    @AppStorage("themeColorName") private var themeColorName: String = "blue"
    @AppStorage("customColorRed") private var customColorRed: Double = 0.0
    @AppStorage("customColorGreen") private var customColorGreen: Double = 0.478
    @AppStorage("customColorBlue") private var customColorBlue: Double = 1.0
    
    var themeColor: Color {
        if themeColorName == "custom" {
            return Color(red: customColorRed, green: customColorGreen, blue: customColorBlue)
        }
        return ClippyIsleAttributes.ColorUtility.color(forName: themeColorName)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? ClippyIsleAttributes.ColorUtility.darkCard : Color(.systemBackground)
    }
    
    private var cardBorder: Color {
        colorScheme == .dark ? ClippyIsleAttributes.ColorUtility.darkBorder : Color(.separator).opacity(0.3)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header info
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(themeColor.opacity(colorScheme == .dark ? 0.2 : 0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: notification.source == .appShare ? "square.and.arrow.up" : "link")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(themeColor)
                    }
                    Text("Received \(notification.items.count) item(s)")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    Spacer()
                    Text(notification.timestamp.timeAgoDisplay())
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(colorScheme == .dark ? ClippyIsleAttributes.ColorUtility.darkCard : Color(.systemGray6))
                
                // Selection controls
                HStack {
                    Button(action: selectAll) {
                        Text("Select All")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                    .disabled(selectedItems.count == notification.items.count)
                    
                    Spacer()
                    
                    Text("\(selectedItems.count) selected")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: deselectAll) {
                        Text("Deselect All")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                    .disabled(selectedItems.isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                
                // Items list
                List {
                    ForEach(notification.items) { item in
                        Button(action: { toggleSelection(item) }) {
                            HStack(spacing: 14) {
                                // Selection indicator
                                Image(systemName: selectedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedItems.contains(item.id) ? themeColor : .secondary)
                                    .font(.system(size: 22))
                                
                                // Item icon with modern styling
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(themeColor.opacity(colorScheme == .dark ? 0.15 : 0.1))
                                        .frame(width: 36, height: 36)
                                    Text(itemIcon(for: item.type))
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(themeColor)
                                }
                                
                                // Item content
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.displayName ?? item.content)
                                        .lineLimit(2)
                                        .font(.system(size: 15, weight: .medium, design: .rounded))
                                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                                    
                                    HStack(spacing: 6) {
                                        // Show tags if any
                                        if let tags = item.tags, !tags.isEmpty {
                                            ForEach(tags.prefix(3), id: \.self) { tag in
                                                Text(tag)
                                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(
                                                        Capsule()
                                                            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.gray.opacity(0.12))
                                                    )
                                                    .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.7) : .secondary)
                                            }
                                            if tags.count > 3 {
                                                Text("+\(tags.count - 3)")
                                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        // Item type indicator
                                        Text(itemTypeLabel(for: item.type))
                                            .font(.system(size: 11, weight: .regular, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(cardBackground)
                                    .shadow(color: colorScheme == .dark ? Color.black.opacity(0.25) : Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(selectedItems.contains(item.id) ? themeColor.opacity(0.5) : cardBorder, lineWidth: selectedItems.contains(item.id) ? 1.5 : 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(colorScheme == .dark ? ClippyIsleAttributes.ColorUtility.darkBackground : Color(.systemGroupedBackground))
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
