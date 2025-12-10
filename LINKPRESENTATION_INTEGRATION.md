# LinkPresentation Integration

This document describes the LinkPresentation feature integration that enables rich link preview functionality in ClippyIsle.

## Overview

The app now uses Apple's native LinkPresentation framework to fetch and display metadata for URL items stored in the clipboard history. **The preview expands inline between list items**, creating a card-like separation effect.

## Features

### 1. LinkMetadataManager
**Location:** `ClippyIsle/Managers/LinkMetadataManager.swift`

A manager class that handles asynchronous fetching of URL metadata using `LPMetadataProvider`.

**Key Features:**
- Fetches metadata (title, image, summary) for any URL
- Manages loading states
- Handles errors gracefully
- Supports cancellation of ongoing requests

**Usage:**
```swift
let manager = LinkMetadataManager()
manager.fetchMetadata(for: url)
```

### 2. InlineLinkPreview
**Location:** `ClippyIsle/Views/Components/InlineLinkPreview.swift`

A compact SwiftUI view that displays URL metadata inline between list items.

**Key Features:**
- Displays URL metadata in a compact format (80x80 image)
- Shows title (2 lines max), image, and domain
- Includes loading indicator during fetch
- Error view with error message
- Compact card design that fits between list items

**States:**
- **Loading:** Shows a compact progress indicator with "Loading preview..." message
- **Success:** Displays the metadata in a compact card layout
- **Error:** Shows error message inline

### 3. Long Press Gesture with Inline Expansion
**Location:** Modified in `ClippyIsle/Views/Subviews.swift` and `ClippyIsle/ContentView.swift`

The `ClipboardItemRow` has been enhanced with a long-press gesture handler that triggers inline preview expansion.

**Behavior:**
- When user long-presses on a URL item (0.3 second duration for better sensitivity)
- The app automatically detects if the item is a URL
- **The preview expands inline between the pressed item and the item below it**
- Creates a visual card separation effect
- Long-press the same item again to collapse the preview
- Regular tap still works as before (opens full-screen preview)

## User Experience

1. **Add a URL** to clipboard (e.g., https://www.apple.com)
2. The URL appears in the ClippyIsle main list
3. **Long press** on the URL item (0.3 second hold)
4. The list items separate and an inline preview card appears showing:
   - Loading indicator (while fetching)
   - Rich preview card with:
     - Website image/icon (80x80)
     - Page title (up to 2 lines)
     - Domain/URL
5. **Long press again** to collapse the preview
6. Tap normally to open full-screen preview (existing behavior)

## Technical Details

### Framework Used
- **LinkPresentation** (iOS native framework)
  - `LPMetadataProvider` for fetching metadata
  - `LPLinkMetadata` for metadata storage
  - `NSItemProvider` for image loading

### Async/Await
The implementation uses modern Swift concurrency:
- `async/await` for metadata fetching
- `@MainActor` for UI updates
- Proper error handling with try/catch

### Error Handling
- Network errors
- Invalid URLs
- Timeout errors
- Parse errors
All are caught and displayed with user-friendly messages

## Implementation Details

### Files Created
1. `ClippyIsle/Managers/LinkMetadataManager.swift` - Metadata fetching logic
2. `ClippyIsle/Views/Components/LinkPreviewCard.swift` - Preview card UI

### Files Modified
1. `ClippyIsle/Views/Subviews.swift` - Added long-press gesture to ClipboardItemRow

### Dependencies
- No external dependencies required
- Uses native iOS LinkPresentation framework (iOS 13+)

## Future Enhancements

Potential improvements:
1. Cache fetched metadata to avoid repeated network calls
2. Add animation when opening the preview
3. Support for custom URL schemes
4. Share button in the preview card
5. Copy individual metadata fields (title, description)
6. Open URL in Safari button

## Testing

Since the iOS simulator and physical device are not available in this environment, manual testing should include:

1. **Valid URLs:**
   - Test with various websites (news, blogs, social media)
   - Verify image loading
   - Check title and description display

2. **Invalid URLs:**
   - Test error handling
   - Verify retry button works

3. **Edge Cases:**
   - Very long URLs
   - URLs without images
   - URLs with special characters
   - Slow network conditions

4. **User Interaction:**
   - Long press gesture responsiveness
   - Sheet presentation/dismissal
   - Tap vs long press distinction
