# Built-in User Guide Implementation Summary

## Overview
This implementation adds a built-in user guide item to the ClippyIsle app that is always displayed at the top of the clipboard items list. The guide provides comprehensive information about app features and highlights the differences between free and paid versions.

## Requirements Fulfilled

✅ **Built-in item with highest priority**: The user guide always appears at the top, even above other pinned items
✅ **Title**: "CC Isle 使用說明" (CC Isle User Guide)
✅ **Comprehensive content**: Includes detailed feature descriptions and free vs paid comparison
✅ **Delete protection for free users**: Only paid version users can delete the guide
✅ **Edit instructions provided**: Clear documentation on how to modify the guide content

## Key Features

### 1. Always on Top
The user guide uses a special sorting mechanism that places it above all other items, including regular pinned items. This is implemented in the `sortAndSave()` function.

### 2. Comprehensive Content
The guide includes:
- Introduction to ClippyIsle
- Main feature categories:
  - Clipboard Management (📋)
  - Item Management (📌)
  - Tag System (🏷️)
  - Voice Features (🔊)
  - Web Preview (🌐)
  - Personalization (🎨)
  - Data Sync (☁️)
  - Audio File Management (🎵)
- Free vs Paid version comparison
- Quick operation tips for main screen and toolbar

### 3. Free vs Paid Differences Highlighted

**Free Version:**
- Basic clipboard management
- Pin functionality
- Up to 10 tags
- Voice reading
- Web preview
- Basic theme colors
- iCloud sync
- Data import/export

**Paid Version Exclusive:**
- Unlimited tags
- Custom tag colors
- Ability to delete this user guide
- Future advanced features

### 4. Delete Protection
- Free version users see an upgrade prompt when trying to delete the guide
- Paid version users can delete the guide like any other item
- The guide is protected from automatic cleanup operations

## Implementation Details

### Files Modified

1. **SharedModels/SharedModels.swift**
   - Added `userGuideItemID` constant with fixed UUID: `00000000-0000-0000-0000-000000000001`

2. **ClippyIsle/Managers/ClipboardManager.swift**
   - Added `ensureUserGuideExists()` function to create/update the guide
   - Modified `sortAndSave()` to always place guide at the top
   - Modified `moveItemToTrash()` to prevent deletion in free version
   - Modified `permanentlyDeleteItem()` to prevent permanent deletion in free version
   - Modified `cleanupItems()` to protect guide from automatic cleanup

3. **ClippyIsle/ContentView.swift**
   - Added `isShowingGuideDeleteAlert` state variable
   - Modified delete action to check for guide item and show upgrade alert for free users
   - Added alert view for upgrade prompt

4. **USER_GUIDE_EDIT_INSTRUCTIONS.md** (NEW)
   - Complete documentation on how to edit the guide content
   - Bilingual (Chinese and English)
   - Technical details about the implementation

## How to Edit the User Guide

### Title
Edit the `displayName` parameter in the `ensureUserGuideExists()` function:
```swift
displayName: "CC Isle 使用說明",  // Change this
```

### Content
Edit the `guideContent` variable in the `ensureUserGuideExists()` function:
```swift
let guideContent = """
# CC Isle 使用說明
... (your content here)
"""
```

**Location**: `ClippyIsle/Managers/ClipboardManager.swift`, approximately lines 79-174

For detailed instructions, see `USER_GUIDE_EDIT_INSTRUCTIONS.md`

## Technical Considerations

### UUID Strategy
The guide uses a fixed UUID (`00000000-0000-0000-0000-000000000001`) to ensure:
- Consistent identification across devices
- No duplicates when syncing via iCloud
- Easy identification in code

### Automatic Updates
The `ensureUserGuideExists()` function runs on every app launch and:
- Creates the guide if it doesn't exist
- Updates the content if it has changed (useful for app updates)
- Preserves the guide's pinned status

### Pro Status Check
Uses `SubscriptionManager.shared.isPro` consistently throughout the codebase for checking subscription status.

### Sorting Priority
Sort order in `sortAndSave()`:
1. User guide (by ID check)
2. Regular pinned items (by isPinned = true)
3. Non-pinned items (by timestamp, newest first)

## Testing Checklist

- [ ] App launches without errors
- [ ] User guide appears at the top of the list
- [ ] User guide stays at the top even when other items are pinned
- [ ] Free users see upgrade alert when trying to delete the guide
- [ ] Paid users can delete the guide successfully
- [ ] Guide survives automatic cleanup operations
- [ ] Guide content displays correctly in preview
- [ ] Guide syncs properly via iCloud
- [ ] Guide persists across app restarts

## Upgrade Path for Users

When a free user tries to delete the guide:
1. Alert appears with title "升級至付費版" (Upgrade to Paid Version)
2. Message explains that only paid users can delete the guide
3. Two options:
   - "升級" (Upgrade) - Opens the paywall
   - "取消" (Cancel) - Dismisses the alert

This creates a natural upgrade prompt that adds value while encouraging conversion to paid version.

## Maintenance Notes

- The guide content should be updated with each major feature release
- Consider translating the guide for international versions
- Monitor user feedback about the guide's helpfulness
- Consider making the guide content downloadable/updatable without app updates in future versions

## Summary

This implementation successfully adds a permanent, top-priority user guide to ClippyIsle that:
- Educates users about all app features
- Clearly differentiates free and paid versions
- Provides an upgrade incentive
- Can be easily updated by developers
- Respects paid users by allowing them to remove it

The implementation follows the existing code patterns and integrates seamlessly with the app's architecture.
