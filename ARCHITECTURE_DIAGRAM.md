# CloudKit Sharing Architecture

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CC ISLE App Architecture                     │
│                      with CloudKit Sharing Support                   │
└─────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────┐
│                              UI Layer (SwiftUI)                            │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌─────────────┐         ┌─────────────────┐      ┌──────────────────┐  │
│  │ ContentView │◄────────┤ CloudSharingView│◄─────┤Share Button/Menu │  │
│  │             │         │ (Wrapper)        │      │                  │  │
│  │ - Items     │         │                  │      │ - Context Menu   │  │
│  │ - Search    │         └─────────────────┘      │ - Share Icon     │  │
│  │ - Filters   │                  │                └──────────────────┘  │
│  └─────────────┘                  │                                       │
│        │                           ▼                                       │
│        │          ┌────────────────────────────────┐                      │
│        │          │ UICloudSharingController       │                      │
│        │          │ (Native iOS Sharing UI)        │                      │
│        │          │                                 │                      │
│        │          │ - Share Link Generation        │                      │
│        │          │ - Permission Management        │                      │
│        │          │ - Participant List              │                      │
│        │          └────────────────────────────────┘                      │
│        │                                                                   │
└────────┼───────────────────────────────────────────────────────────────────┘
         │
         ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                           Data Management Layer                            │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌─────────────────┐              ┌──────────────────────┐               │
│  │ ClipboardManager│◄────────────►│ PersistenceController│               │
│  │                 │              │                       │               │
│  │ - Current impl. │              │ - Core Data Stack    │               │
│  │ - JSON/Codable  │              │ - CloudKit Container │               │
│  │ - UserDefaults  │              │ - Share Management   │               │
│  └─────────────────┘              └──────────────────────┘               │
│         │                                    │                             │
│         │                                    │                             │
│         ▼                                    ▼                             │
│  ┌─────────────────┐              ┌──────────────────────┐               │
│  │ ClipboardItem   │◄────────────►│ ClipboardItemEntity  │               │
│  │ (Struct)        │  Conversion  │ (NSManagedObject)    │               │
│  │                 │              │                       │               │
│  │ - id: UUID      │              │ - id: UUID           │               │
│  │ - content       │              │ - content            │               │
│  │ - type          │              │ - type               │               │
│  │ - timestamp     │              │ - timestamp          │               │
│  │ - tags          │              │ - tags               │               │
│  │ - isPinned      │              │ - isPinned           │               │
│  └─────────────────┘              └──────────────────────┘               │
│                                              │                             │
└──────────────────────────────────────────────┼─────────────────────────────┘
                                               │
                                               ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                         Persistence Layer (Core Data)                      │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────┐    │
│  │          NSPersistentCloudKitContainer                            │    │
│  │                                                                    │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌──────────────────────┐     │    │
│  │  │   Managed   │  │   Managed   │  │  Persistent History   │     │    │
│  │  │   Object    │  │   Object    │  │      Tracking         │     │    │
│  │  │   Context   │  │   Model     │  │                       │     │    │
│  │  └─────────────┘  └─────────────┘  └──────────────────────┘     │    │
│  │                                                                    │    │
│  │  Options:                                                         │    │
│  │  - Container ID: iCloud.J894ABBU74.ClippyIsle                    │    │
│  │  - Database Scope: Private                                        │    │
│  │  - History Tracking: Enabled                                      │    │
│  │  - Remote Changes: Enabled                                        │    │
│  └──────────────────────────────────────────────────────────────────┘    │
│                                  │                                         │
└──────────────────────────────────┼─────────────────────────────────────────┘
                                   │
                                   ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                         CloudKit Service Layer                             │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────┐      │
│  │                  CKContainer (iCloud.J894ABBU74.ClippyIsle)     │      │
│  │                                                                  │      │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐    │      │
│  │  │   Private   │  │   Shared    │  │      Public         │    │      │
│  │  │  Database   │  │  Database   │  │     Database        │    │      │
│  │  │             │  │             │  │                     │    │      │
│  │  │ - User data │  │ - Shared    │  │ - Not used         │    │      │
│  │  │ - Synced    │  │   items     │  │                     │    │      │
│  │  │   across    │  │ - CKShare   │  │                     │    │      │
│  │  │   devices   │  │   records   │  │                     │    │      │
│  │  └─────────────┘  └─────────────┘  └─────────────────────┘    │      │
│  │                                                                  │      │
│  │  Record Types:                                                  │      │
│  │  - CD_ClipboardItemEntity (Auto-generated)                     │      │
│  │  - CKShare (System type)                                        │      │
│  │                                                                  │      │
│  └────────────────────────────────────────────────────────────────┘      │
│                                                                            │
└───────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                            iCloud Infrastructure                           │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  - Sync across user's devices                                             │
│  - Share with other iCloud users                                          │
│  - Web-based sharing (cloudkit.com)                                       │
│  - Conflict resolution                                                     │
│  - Change notifications                                                    │
│                                                                            │
└───────────────────────────────────────────────────────────────────────────┘
```

## Data Flow: Creating a Share

```
1. User Action
   └─> User taps "Share via iCloud" in context menu

2. ContentView.shareItem()
   └─> Converts ClipboardItem to ClipboardItemEntity
       └─> Creates entity if doesn't exist
       └─> Saves to Core Data

3. Present CloudSharingView
   └─> Sets itemToShare and isShowingShareSheet = true
       └─> CloudSharingView initializes

4. CloudSharingView.prepareShare()
   └─> Checks if already shared
       ├─> Yes: Use existing CKShare
       └─> No: Create new CKShare via PersistenceController

5. PersistenceController.createShare()
   └─> Calls container.share([object], to: nil)
       └─> CloudKit creates CKShare record
       └─> Configures share properties (title, permissions)

6. Present UICloudSharingController
   └─> Native iOS sharing interface
       └─> User configures share settings
       └─> Share link generated
       └─> User copies/sends link

7. Share Saved
   └─> Delegate callback: cloudSharingControllerDidSaveShare
       └─> Share synced to iCloud
       └─> Available to recipients
```

## Data Flow: Accepting a Share

```
1. Recipient Opens Share Link
   └─> URL scheme: cloudkit://...

2. iOS Handles URL
   └─> Prompts to accept share
       └─> User accepts

3. CKShare Added to Recipient's Shared Database
   └─> ClipboardItemEntity synced to recipient's device
       └─> Available in Core Data

4. App Displays Shared Item
   └─> Recipient sees item in their list
       └─> Can view/interact based on permissions
       └─> Changes sync back to owner
```

## Component Relationships

```
┌─────────────────────────┐
│   ClipboardItem         │  Existing implementation
│   (Codable/JSON)        │  - Stored in UserDefaults
└──────────┬──────────────┘  - Used throughout app
           │
           │ Conversion
           │ (when sharing)
           ▼
┌─────────────────────────┐
│ ClipboardItemEntity     │  New implementation
│ (NSManagedObject)       │  - Stored in Core Data
└──────────┬──────────────┘  - Used for sharing only
           │
           │ Manages
           ▼
┌─────────────────────────┐
│      CKShare            │  CloudKit system record
│  (CloudKit Record)      │  - Contains sharing metadata
└──────────┬──────────────┘  - Participants, permissions
           │
           │ Synced via
           ▼
┌─────────────────────────┐
│   iCloud Servers        │  Apple infrastructure
│   (CloudKit Service)    │  - Handles sync, sharing
└─────────────────────────┘  - Conflict resolution
```

## Migration Strategy

```
Phase 1: Dual Storage
┌──────────────────┐          ┌──────────────────┐
│  ClipboardItem   │          │ClipboardItemEntity│
│  (UserDefaults)  │◄────────►│  (Core Data)     │
└──────────────────┘  Sync    └──────────────────┘
        │                              │
        │ Used for                     │ Used for
        │ all operations               │ sharing only
        ▼                              ▼
   All Features              Sharing Features
   (existing)                    (new)


Phase 2: Gradual Migration
┌──────────────────┐          ┌──────────────────┐
│  ClipboardItem   │  Migrate │ClipboardItemEntity│
│  (UserDefaults)  │─────────►│  (Core Data)     │
└──────────────────┘  items   └──────────────────┘
        │                              │
        │ Deprecated                   │ Primary
        │ (backup only)                │ storage
        ▼                              ▼
   Legacy Support           All Features
   (compatibility)          (new + old)


Phase 3: Complete Migration (Future)
                            ┌──────────────────┐
                            │ClipboardItemEntity│
                            │  (Core Data)     │
                            └──────────────────┘
                                     │
                                     │ Only
                                     │ storage
                                     ▼
                               All Features
                            (unified approach)
```

## Key Design Decisions

### 1. Why Core Data?
- **Required for Sharing**: UICloudSharingController requires NSManagedObject
- **CloudKit Integration**: NSPersistentCloudKitContainer handles sync automatically
- **Conflict Resolution**: Built-in merge policies
- **History Tracking**: Required for multi-device sync

### 2. Why Keep ClipboardItem?
- **Backward Compatibility**: Existing code continues to work
- **Migration Safety**: No breaking changes
- **Flexibility**: Easy rollback if needed
- **Performance**: Lighter weight for non-shared items

### 3. Why Separate Files?
- **Modularity**: Each component has clear responsibility
- **Testability**: Easier to test individual pieces
- **Maintainability**: Changes isolated to specific files
- **Reusability**: Components can be used independently

## Performance Characteristics

### Share Creation
- **Time**: 1-3 seconds (network dependent)
- **Process**: Asynchronous (non-blocking UI)
- **Impact**: Minimal - only when user initiates

### Sync
- **Frequency**: Automatic (push notifications)
- **Latency**: 1-10 seconds typically
- **Bandwidth**: Minimal (delta sync)
- **Battery**: Low impact (efficient protocol)

### Storage
- **Core Data**: ~1KB per item (metadata only)
- **File Assets**: Stored in app group container
- **CloudKit**: Shared quota with iCloud account
- **Local Cache**: Minimal overhead

## Security Model

```
┌────────────────────────────────────────────────┐
│              Share Permissions                  │
├────────────────────────────────────────────────┤
│                                                 │
│  Owner (Sharer)                                │
│  - Full control                                 │
│  - Can modify item                              │
│  - Can stop sharing                             │
│  - Can manage participants                      │
│                                                 │
│  Participant (Recipient)                        │
│  - Read-only or Read-write (configurable)      │
│  - Can view item                                │
│  - Can modify (if permitted)                    │
│  - Cannot delete owner's copy                   │
│  - Cannot share with others (default)           │
│                                                 │
└────────────────────────────────────────────────┘
```

## Error Handling

```
Share Creation
├─> No iCloud Account → Show alert to sign in
├─> No Network → Queue for later / Show error
├─> Already Shared → Show manage share UI
└─> CloudKit Error → Log and show user-friendly message

Share Acceptance
├─> Invalid Link → Show error message
├─> Expired Share → Notify recipient
├─> No Permission → Request access from owner
└─> Network Error → Retry with exponential backoff

Sync Issues
├─> Conflict → Use merge policy (timestamp-based)
├─> Lost Connection → Queue changes, sync when online
├─> Quota Exceeded → Notify user, suggest cleanup
└─> Authentication → Prompt to re-sign in
```

---

This architecture provides a robust, scalable foundation for CloudKit Sharing while maintaining backward compatibility with the existing implementation.
