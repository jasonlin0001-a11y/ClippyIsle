# CloudKit Sharing Implementation Guide

This document provides a comprehensive guide to implementing CloudKit Sharing (CKShare) in the CC ISLE app.

## Overview

CloudKit Sharing allows users to share clipboard items via iCloud links. Recipients can view and interact with shared items without needing to install the app (web-based sharing) or can use the app to get full functionality.

## Implementation Components

### 1. Data Model Analysis

**Current State:**
- The app currently uses `ClipboardItem` struct with Codable/JSON serialization
- Data is stored in UserDefaults with App Group sharing
- Basic CloudKit sync exists using CKRecord directly

**Refactoring to Core Data:**
To support CloudKit Sharing, we need to use Core Data with `NSPersistentCloudKitContainer`. The following components have been created:

#### Files Created:
- `Persistence/PersistenceController.swift` - Core Data stack with CloudKit sharing support
- `Persistence/ClipboardItemEntity.swift` - NSManagedObject subclass for clipboard items
- `Persistence/CoreDataModel.swift` - Programmatic Core Data model creation
- `Views/CloudSharingView.swift` - UICloudSharingController wrapper for SwiftUI

### 2. CloudKit Stack Configuration

The `PersistenceController` class configures the Core Data stack for CloudKit sharing:

```swift
// Key configuration in PersistenceController.init()
let cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
    containerIdentifier: "iCloud.J894ABBU74.ClippyIsle"
)
cloudKitContainerOptions.databaseScope = .private
description.cloudKitContainerOptions = cloudKitContainerOptions

// Enable persistent history tracking
description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
```

**Database Scopes:**
- **Private Database**: User's personal data (default)
- **Shared Database**: Items shared by or with the user
- **Public Database**: Not used in this implementation

### 3. UIViewControllerRepresentable Implementation

The `CloudSharingView` struct wraps `UICloudSharingController` for use in SwiftUI:

**Key Features:**
- Presents the native iOS sharing interface
- Handles share creation and management
- Provides delegate callbacks for share lifecycle events
- Generates thumbnail images based on content type

**Usage Example:**
```swift
.cloudSharing(
    isPresented: $isShowingShareSheet,
    item: clipboardItemEntity,
    container: PersistenceController.shared.container.persistentStoreCoordinator.container
)
```

### 4. Delegate Handling

The `Coordinator` class implements `UICloudSharingControllerDelegate`:

**Implemented Methods:**
- `itemTitle(for:)` - Returns the share title (item's display name or "Clipboard Item")
- `itemThumbnailData(for:)` - Generates a thumbnail based on content type
  - Photo icon for images
  - Link icon for URLs
  - Document icon for text/other content
- `cloudSharingControllerDidSaveShare(_:)` - Called when share is saved
- `cloudSharingControllerDidStopSharing(_:)` - Called when sharing is stopped
- `cloudSharingController(_:failedToSaveShareWithError:)` - Error handling

### 5. Capability Requirements

To enable CloudKit Sharing, configure the following in Xcode:

#### Signing & Capabilities Tab:

1. **iCloud** (Already configured, update if needed)
   - ✅ CloudKit
   - ✅ Container: `iCloud.J894ABBU74.ClippyIsle`
   - Services: CloudKit

2. **App Groups** (Already configured)
   - ✅ `group.com.shihchieh.clippyisle`

3. **Background Modes** (If not already enabled)
   - ✅ Remote notifications
   - Purpose: Receive CloudKit change notifications

#### Entitlements File Updates:

The `ClippyIsle.entitlements` file already contains the necessary entries:
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

### 6. Integration Steps

To integrate CloudKit Sharing into the existing app:

#### Step 1: Update ClipboardManager
The ClipboardManager should be updated to work with Core Data instead of JSON:
- Keep the existing JSON-based implementation as a migration path
- Add methods to sync between ClipboardItem (Codable) and ClipboardItemEntity (Core Data)
- Gradually migrate data from UserDefaults to Core Data

#### Step 2: Add Share Button to UI
Add a share button to the item context menu in ContentView:

```swift
Button(action: {
    // Convert ClipboardItem to ClipboardItemEntity
    // Present CloudSharingView
}) {
    Label("Share via iCloud", systemImage: "square.and.arrow.up")
}
```

#### Step 3: Handle Share Links
Implement scene delegate methods to handle incoming share URLs:
```swift
.onOpenURL { url in
    // Handle cloudkit share URL
}
```

## Migration Strategy

Since the app currently uses JSON/UserDefaults, we recommend a phased migration:

### Phase 1: Dual Storage (Recommended)
- Keep existing JSON storage for backward compatibility
- Add Core Data storage for items that support sharing
- Sync between both systems
- Mark items as "shareable" once migrated to Core Data

### Phase 2: Gradual Migration
- Automatically migrate items to Core Data on app updates
- Maintain JSON as backup during transition period
- Provide manual export/import for safety

### Phase 3: Complete Migration (Future)
- Once stable, deprecate JSON storage
- Use Core Data as primary storage
- Remove migration code

## Testing Checklist

- [ ] Create a clipboard item
- [ ] Share the item using the share button
- [ ] Verify share link is generated
- [ ] Open share link on another device (logged in with different iCloud account)
- [ ] Verify shared item appears correctly
- [ ] Modify shared item and verify sync
- [ ] Stop sharing and verify access is revoked
- [ ] Test with different content types (text, URL, image)
- [ ] Verify thumbnail generation for each type
- [ ] Test offline behavior
- [ ] Test conflict resolution

## Known Limitations

1. **No Web Preview**: CloudKit sharing works best within the app ecosystem
2. **iCloud Account Required**: Both sharer and recipient need iCloud accounts
3. **Network Dependency**: Sharing requires active internet connection
4. **Permission Model**: Limited to read-only and read-write permissions

## Troubleshooting

### Share Not Appearing
- Verify iCloud is enabled in device settings
- Check that the item exists in Core Data
- Ensure CloudKit container is properly configured

### Share Link Not Working
- Verify recipient is signed in to iCloud
- Check that sharing permissions are correctly set
- Ensure both devices have network connectivity

### Sync Issues
- Enable persistent history tracking
- Check CloudKit dashboard for errors
- Verify container identifiers match across targets

## Additional Resources

- [Apple Documentation: NSPersistentCloudKitContainer](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer)
- [Apple Documentation: CKShare](https://developer.apple.com/documentation/cloudkit/ckshare)
- [Apple Documentation: UICloudSharingController](https://developer.apple.com/documentation/uikit/uicloudsharingcontroller)
- [WWDC Session: Building Apps with CloudKit](https://developer.apple.com/videos/)

## Security Considerations

1. **Data Privacy**: Only share items explicitly selected by the user
2. **Permission Checks**: Always verify share permissions before allowing access
3. **Content Validation**: Validate shared content before displaying
4. **User Consent**: Clearly communicate what is being shared
5. **Revocation**: Provide easy way to stop sharing and revoke access

## Performance Notes

- Share creation is asynchronous and may take a few seconds
- Thumbnail generation should be lightweight (200x200px recommended)
- Batch share operations to avoid rate limiting
- Use background contexts for heavy operations

## Next Steps

1. Review the implementation files
2. Test the sharing flow in a development environment
3. Add UI elements to expose sharing functionality
4. Implement migration from JSON to Core Data
5. Test with multiple users and devices
6. Submit for TestFlight testing before production release
