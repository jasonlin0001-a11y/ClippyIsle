# Quick Start: Adding CloudKit Sharing to CC ISLE

This guide provides step-by-step instructions for integrating the CloudKit Sharing implementation into your app.

## Step 1: Add Files to Xcode Project

1. Open `ClippyIsle.xcodeproj` in Xcode
2. Create a new group called "Persistence" under the ClippyIsle folder
3. Add these files to the Persistence group:
   - `ClippyIsle/Persistence/PersistenceController.swift`
   - `ClippyIsle/Persistence/CoreDataModel.swift`
   - `ClippyIsle/Persistence/ClipboardItemEntity.swift`

4. Add this file to the Views group:
   - `ClippyIsle/Views/CloudSharingView.swift`

5. Reference file (optional):
   - `ClippyIsle/Views/CloudSharingIntegrationExample.swift`

## Step 2: Verify Capabilities (Already Configured ✓)

Your app already has the required capabilities configured:
- ✅ iCloud with CloudKit
- ✅ Container: `iCloud.J894ABBU74.ClippyIsle`
- ✅ App Groups: `group.com.shihchieh.clippyisle`

No additional capability configuration needed!

## Step 3: Add to ContentView

### 3.1: Add State Variables

Add these to your `ContentView`:

```swift
@State private var itemToShare: ClipboardItemEntity? = nil
@State private var isShowingShareSheet = false
```

### 3.2: Add Share Helper Methods

```swift
extension ContentView {
    /// Convert ClipboardItem to ClipboardItemEntity for sharing
    func getOrCreateEntity(for item: ClipboardItem) -> ClipboardItemEntity? {
        let context = PersistenceController.shared.container.viewContext
        
        // Check if entity already exists
        if let existing = try? ClipboardItemEntity.fetch(id: item.id, in: context) {
            return existing
        }
        
        // Create new entity
        let entity = ClipboardItemEntity.create(from: item, in: context)
        do {
            try context.save()
            return entity
        } catch {
            print("Error saving entity: \(error)")
            return nil
        }
    }
    
    /// Share an item via iCloud
    func shareItem(_ item: ClipboardItem) {
        guard let entity = getOrCreateEntity(for: item) else {
            print("Failed to create entity for sharing")
            return
        }
        
        itemToShare = entity
        isShowingShareSheet = true
    }
    
    /// Check if item is shared
    func isShared(_ item: ClipboardItem) -> Bool {
        guard let entity = try? ClipboardItemEntity.fetch(
            id: item.id,
            in: PersistenceController.shared.container.viewContext
        ) else {
            return false
        }
        return PersistenceController.shared.isShared(object: entity)
    }
}
```

### 3.3: Add Share Button to Context Menu

Find your item's context menu (usually in the List item's `.contextMenu { }` block) and add:

```swift
.contextMenu {
    // ... existing menu items ...
    
    Divider()
    
    // Add share option
    if isShared(item) {
        Button {
            shareItem(item) // Manage existing share
        } label: {
            Label("Manage Share", systemImage: "person.2.fill")
        }
    } else {
        Button {
            shareItem(item)
        } label: {
            Label("Share via iCloud", systemImage: "square.and.arrow.up.on.square")
        }
    }
}
```

### 3.4: Add CloudSharing Modifier

Add this modifier to your main view (after `.navigationTitle` or similar):

**Note:** Only present the sheet when itemToShare is valid. The sheet should not appear if itemToShare is nil.

```swift
// Option 1: Use if-let binding (recommended)
if let itemToShare = itemToShare {
    EmptyView()
        .cloudSharing(
            isPresented: $isShowingShareSheet,
            item: itemToShare,
            container: CKContainer(identifier: "iCloud.J894ABBU74.ClippyIsle")
        )
}

// Option 2: Guard against nil in shareItem method
// Ensure shareItem() only sets isShowingShareSheet = true when entity is valid
```

## Step 4: Build and Test

### 4.1: Build the Project
1. Clean Build Folder (Cmd+Shift+K)
2. Build (Cmd+B)
3. Resolve any compilation errors

### 4.2: Test on Physical Device
**Important:** CloudKit Sharing only works on physical devices, not in Simulator!

#### Test Scenario 1: Create Share
1. Run app on Device A (signed in to iCloud Account A)
2. Long-press a clipboard item
3. Tap "Share via iCloud"
4. Configure share settings
5. Copy the share link

#### Test Scenario 2: Accept Share
1. Send share link to Device B (signed in to iCloud Account B)
2. Open link on Device B
3. Verify item appears in the app (if installed) or web view
4. Check that changes sync between devices

#### Test Scenario 3: Manage Share
1. Long-press the shared item
2. Tap "Manage Share"
3. Modify permissions or stop sharing
4. Verify changes on Device B

## Step 5: Optional - Add Share Indicator

To show which items are shared, add a visual indicator in your item row:

```swift
HStack {
    // ... existing item content ...
    
    Spacer()
    
    // Share indicator
    if isShared(item) {
        Image(systemName: "person.2.fill")
            .foregroundColor(.blue)
            .font(.caption)
    }
}
```

## Troubleshooting

### Build Errors

**Error: "Cannot find 'PersistenceController' in scope"**
- Ensure all Persistence files are added to the Xcode project
- Check that files are in the correct target membership

**Error: "Use of unresolved identifier 'ClipboardItemEntity'"**
- Make sure ClipboardItemEntity.swift is in the project
- Check target membership includes the main app

**Error: "Cannot find 'CKContainer' in scope"**
- Add `import CloudKit` at the top of the file

### Runtime Errors

**Error: "Core Data failed to load"**
- Check that the CloudKit container identifier is correct
- Verify iCloud capability is enabled

**Error: "Cannot create share"**
- Ensure user is signed in to iCloud (Settings > [Name] > iCloud)
- Check network connectivity
- Verify the item is saved to Core Data

**Share sheet doesn't appear**
- Check that itemToShare is not nil
- Verify isShowingShareSheet is set to true
- Ensure the entity exists in Core Data

## Testing Checklist

Before releasing:

- [ ] App builds successfully
- [ ] Share button appears in context menu
- [ ] Tapping share button shows UICloudSharingController
- [ ] Share link is generated successfully
- [ ] Share link works on second device
- [ ] Shared items sync between devices
- [ ] Can stop sharing successfully
- [ ] Share indicator shows for shared items
- [ ] Thumbnails generate correctly
- [ ] Share title displays correctly
- [ ] Error handling works (offline, no iCloud account)

## Next Steps

1. **Test thoroughly** on multiple devices
2. **Gather feedback** from beta testers
3. **Monitor CloudKit Dashboard** for errors
4. **Update user documentation**
5. **Consider phased rollout** to manage server load

## Getting Help

- Review: `CLOUDKIT_SHARING_GUIDE.md` - Comprehensive implementation guide
- Review: `CLOUDKIT_CAPABILITIES_CHECKLIST.md` - Detailed capability setup
- Review: `CloudSharingIntegrationExample.swift` - More code examples
- Check: CloudKit Dashboard for server-side issues

## Advanced Features (Future Enhancements)

Once basic sharing works, consider adding:

- [ ] Share multiple items at once
- [ ] Custom share permissions per user
- [ ] Share notifications when items are modified
- [ ] Collaborative editing indicators
- [ ] Share history and analytics
- [ ] Batch operations on shared items

---

**Ready to implement!** Start with Step 1 and work through each step carefully.

For questions or issues, refer to the detailed documentation files included with this implementation.
