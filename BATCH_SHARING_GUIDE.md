# Batch Sharing & Import Feature - Implementation Guide

## Overview

This document describes the implementation of the Batch Sharing & Import feature using CloudKit Sharing for the CC ISLE iOS app. This feature allows users to:

1. Select multiple clipboard items
2. Bundle them into a ShareGroup
3. Share the group via CloudKit
4. Allow receivers to import items into their local database

## Architecture

### Core Data Model

The implementation uses Core Data with `NSPersistentCloudKitContainer` for CloudKit integration.

#### Entities

**ShareGroup**
- `title` (String): Name of the share group
- `createdAt` (Date): Creation timestamp
- `items` (Relationship): One-to-Many relationship to ClipboardItemEntity
- Delete Rule: `Nullify` (safe - items won't be deleted when group is deleted)

**ClipboardItemEntity**
- `id` (UUID): Unique identifier
- `content` (String): Text content of the item
- `type` (String): UTType identifier
- `createdAt` (Date): Creation timestamp
- `displayName` (String?, Optional): Custom display name
- `filename` (String?, Optional): Associated file name
- `isPinned` (Bool): Pin status
- `isTrashed` (Bool): Trash status
- `tags` ([String]?, Optional): Array of tag strings
- `shareGroup` (Relationship): Many-to-One relationship to ShareGroup

### Core Components

#### 1. PersistenceController.swift

Manages the Core Data stack with CloudKit integration.

```swift
let persistenceController = PersistenceController.shared
let context = persistenceController.container.viewContext
```

**Key Features:**
- Configures `NSPersistentCloudKitContainer` with CloudKit container ID
- Enables persistent history tracking
- Sets up automatic change merging
- Provides preview instance for SwiftUI previews

**CloudKit Configuration:**
- Container ID: `iCloud.J894ABBU74.ClippyIsle`
- Persistent history tracking enabled
- Remote change notifications enabled

#### 2. ShareGroupManager.swift

Manages all share group operations including creation, sharing, import, and cleanup.

**Key Methods:**

##### Sender Side (Export)

**`createShareGroup(with items: [ClipboardItem], title: String) -> ShareGroup`**
- Creates a new ShareGroup entity
- Creates deep copies of selected ClipboardItems as ClipboardItemEntity objects
- Each copied item gets a new UUID to avoid conflicts
- File data is NOT copied to reduce transfer size (only text content)
- Returns the created ShareGroup

**`shareGroup(_ shareGroup: ShareGroup, from viewController: UIViewController) async throws`**
- Checks if the ShareGroup is already shared
- Creates a new CKShare if needed
- Presents UICloudSharingController for sharing
- User can then share via Messages, Mail, AirDrop, etc.

##### Receiver Side (Import)

**`importSharedItems(from group: ShareGroup) async -> Int`**
- Extracts all ClipboardItemEntity objects from the ShareGroup
- Creates new ClipboardItem structs (with new UUIDs)
- Adds them to ClipboardManager
- Saves to local UserDefaults storage
- Returns the count of imported items

**`leaveShare(_ shareGroup: ShareGroup) async throws`**
- Fetches the CKShare associated with the ShareGroup
- Purges the shared data from the device
- User keeps their imported local copies
- Recommended to call after successful import

##### Management

**`fetchShareGroups() -> [ShareGroup]`**
- Fetches all ShareGroups (both owned and shared)

**`fetchIncomingSharedGroups() -> [ShareGroup]`**
- Filters for only shared groups (not owned by current user)

**`deleteShareGroup(_ shareGroup: ShareGroup) throws`**
- Deletes a ShareGroup from Core Data

#### 3. SwiftUI Views

##### CreateShareGroupView.swift

UI for creating a new share group.

**Features:**
- Text field for group name
- Preview of selected items (shows first 5, then "... and X more")
- "Share" button that creates the group and presents sharing UI
- Integrates with UICloudSharingController

**Usage:**
```swift
.sheet(isPresented: $showCreateShareGroup) {
    let itemsToShare = clipboardManager.items.filter { selectedItems.contains($0.id) }
    CreateShareGroupView(selectedItems: itemsToShare)
}
```

##### IncomingShareView.swift

UI for viewing and importing received share groups.

**Features:**
- Lists all incoming shared groups
- Shows group title, item count, and "shared X ago" timestamp
- "Import to Library" button for each group
- Success alert after import
- Automatically leaves share after import

**Usage:**
```swift
.sheet(isPresented: $showIncomingShares) {
    IncomingShareView()
}
```

##### ShareGroupListView.swift

Comprehensive view for managing all share groups.

**Features:**
- Segmented control: "Received" vs "Created" tabs
- Received tab: Shows incoming shares with import buttons
- Created tab: Shows owned shares with delete option
- Empty states for each tab
- Pull to refresh

**Usage:**
```swift
.sheet(isPresented: $showShareGroupList) {
    ShareGroupListView()
}
```

## User Flow

### Sharing Flow (Sender)

1. User enters selection mode by tapping "Select Items to Share" in the + menu
2. User taps checkboxes to select items (or tap "Select All")
3. User taps the share button (up arrow) in bottom toolbar
4. CreateShareGroupView appears
5. User enters a group name (optional, defaults to "Shared Items")
6. User taps "Share" button
7. UICloudSharingController appears with sharing options
8. User shares via Messages, Mail, AirDrop, etc.
9. Selection mode exits automatically

### Importing Flow (Receiver)

1. User receives CloudKit share link via Messages/Mail/etc.
2. User taps link, which opens the app
3. ShareGroup appears in their Core Data store
4. User taps the share groups button (square with up arrow) in top toolbar
5. ShareGroupListView appears, showing the "Received" tab
6. User sees the shared group with item count
7. User taps "Import to Library"
8. Items are deep copied into ClipboardManager with new UUIDs
9. Success alert shows count of imported items
10. Share is automatically left, cleaning up shared data
11. User now has local copies in their library

## Integration with ContentView

### Selection Mode

**New State Variables:**
```swift
@State private var isInSelectionMode = false
@State private var selectedItems: Set<UUID> = []
@State private var showCreateShareGroup = false
@State private var showShareGroupList = false
```

**UI Changes:**
- Checkboxes appear on the left of each item in selection mode
- Toolbar shows "Cancel" button instead of normal buttons
- Bottom toolbar transforms to show selection count and actions
- "Select All" and "Share" (up arrow) buttons appear

**Entry Points:**
- + menu > "Select Items to Share"
- Top toolbar > Share groups icon (view existing groups)

## Data Safety

### Why Deep Copies?

The implementation creates deep copies of items when:

1. **Creating a ShareGroup**: Original ClipboardItems remain untouched
2. **Importing**: New local items with new UUIDs are created

This approach ensures:
- Original user data is never modified
- No conflicts between shared and local items
- Users can delete shared groups without affecting their library
- Imported items are truly independent copies

### Delete Rules

**ShareGroup -> items**: `Nullify`
- When a ShareGroup is deleted, ClipboardItemEntity objects are NOT deleted
- They remain in Core Data as orphaned entities
- This is safe because they're only used for sharing
- Alternatively, could use `Cascade` to clean up, but `Nullify` is safer

## CloudKit Configuration Requirements

### Entitlements

Ensure your `ClippyIsle.entitlements` includes:

```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.J894ABBU74.ClippyIsle</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
```

### CloudKit Dashboard

1. Schema must include:
   - `ShareGroup` record type
   - `ClipboardItemEntity` record type
   - Proper relationships defined

2. Permissions:
   - Private database accessible by current user
   - Shared database accessible by shared users

## API Reference

### ShareGroupManager

```swift
// Create a share group
let shareGroup = try shareGroupManager.createShareGroup(
    with: selectedItems, 
    title: "My Share Group"
)

// Share the group
try await shareGroupManager.shareGroup(shareGroup, from: viewController)

// Import items from a shared group
let count = try await shareGroupManager.importSharedItems(from: sharedGroup)

// Leave a share
try await shareGroupManager.leaveShare(sharedGroup)

// Fetch all groups
let allGroups = shareGroupManager.fetchShareGroups()

// Fetch only incoming groups
let incomingGroups = shareGroupManager.fetchIncomingSharedGroups()

// Delete a group
try shareGroupManager.deleteShareGroup(group)
```

### PersistenceController

```swift
// Access shared instance
let controller = PersistenceController.shared

// Get view context
let context = controller.container.viewContext

// Save context
controller.saveContext()

// For previews
let previewController = PersistenceController.preview
```

## Testing Checklist

- [ ] Create a share group with multiple items
- [ ] Share via Messages to another device
- [ ] Receive share on second device
- [ ] Import items on second device
- [ ] Verify new UUIDs are generated
- [ ] Verify original items unchanged on sender device
- [ ] Delete a share group on sender device
- [ ] Leave a share on receiver device
- [ ] Test with pinned items
- [ ] Test with tagged items
- [ ] Test with items containing special characters
- [ ] Test selection mode UI
- [ ] Test "Select All" functionality
- [ ] Test empty states

## Troubleshooting

### Share not appearing on receiver device

- Check CloudKit Dashboard for errors
- Ensure both devices logged into same iCloud account (for testing)
- Check CloudKit container identifier matches
- Verify network connectivity

### Import fails

- Check console for error messages
- Verify ShareGroup has items
- Ensure ClipboardManager is initialized
- Check UserDefaults access

### Core Data errors

- Check that ShareGroupModel is added to target
- Verify entity names match class names
- Ensure PersistenceController is initialized in App
- Check CloudKit permissions

## Future Enhancements

1. **File Support**: Currently only text content is shared. Could add file data support for images and other media.

2. **Batch Import Options**: Allow users to selectively import items instead of all-or-nothing.

3. **Share Permissions**: Customize read-only vs read-write permissions.

4. **Share Expiration**: Set expiration dates for shares.

5. **Activity Feed**: Show history of shared and imported groups.

6. **Share Analytics**: Track which items are shared most often.

7. **Collaborative Editing**: Allow multiple users to add items to a shared group.

## Conclusion

This implementation provides a robust, safe, and user-friendly batch sharing feature that leverages CloudKit's built-in sharing capabilities. The deep copy approach ensures data integrity, while the SwiftUI interface provides a familiar iOS experience.
