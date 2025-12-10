# LinkPresentation Integration

This document describes the preview functionality in ClippyIsle.

## Overview

The app displays lightweight compact previews for all clipboard items to help users identify content at a glance. **Previews are always visible** and optimized for smooth scrolling performance.

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

**Note:** Currently used only in full-screen preview mode to avoid performance issues.

### 2. Preview Components

#### CompactItemPreview
**Location:** `ClippyIsle/Views/Components/CompactItemPreview.swift`

A lightweight inline preview component that displays content indicators for all item types.

**Key Features:**
- **No network calls** - URLs show domain/path only (no metadata fetching)
- **No async operations** - Images shown only if data already loaded
- **Minimal UI** - Simple colored badges with icons
- **Fast rendering** - Optimized for smooth scrolling

**Preview Types:**
- **URL items:** Blue badge with link icon + domain and URL path
- **Image items:** Purple badge with photo icon (shows thumbnail if data loaded)
- **Text items:** Green badge with text icon + first 50 characters

#### InlineLinkPreview
**Location:** `ClippyIsle/Views/Components/InlineLinkPreview.swift`

A rich preview component for URL metadata (used in full-screen mode only).

**Key Features:**
- Displays URL metadata in a compact format (80x80 image)
- Shows title (2 lines max), image, and domain
- Includes loading indicator during fetch
- Error view with error message

**States:**
- **Loading:** Shows a compact progress indicator with "Loading preview..." message
- **Success:** Displays the metadata in a compact card layout
- **Error:** Shows error message inline

### 3. Always-On Lightweight Previews
**Location:** Modified in `ClippyIsle/Views/Subviews.swift` and `ClippyIsle/ContentView.swift`

All clipboard items now automatically display lightweight inline previews.

**Behavior:**
- **URL items:** Show blue badge with domain/path (no network call)
- **Image items (PNG/JPEG):** Show purple badge with thumbnail (if data loaded)
- **Text items:** Show green badge with first 50 chars
- **No user interaction required** - previews are always visible
- **No long-press gesture** - removed to simplify UX
- Regular tap still works as before (opens full-screen preview)

## User Experience

1. **Add content** to clipboard (URL, image, or text)
2. The item appears in the ClippyIsle main list
3. **Lightweight preview is automatically displayed** below the item:
   - **URLs:** Blue badge showing domain and URL path (no network call)
   - **Images:** Purple badge with thumbnail (if data loaded) or photo icon
   - **Text:** Green badge showing first 50 characters
4. **Tap the item** to open full-screen preview with rich content

## Technical Details

### Framework Used
- **LinkPresentation** (iOS native framework)
  - `LPMetadataProvider` for fetching metadata (full-screen mode only)
  - `LPLinkMetadata` for metadata storage
  - `NSItemProvider` for image loading

### Performance Optimization
- **No network calls in list view** - Prevents simultaneous requests causing crashes
- **No async operations** - Ensures smooth scrolling
- **Minimal UI rendering** - Simple badge-style previews
- **Conditional image display** - Shows thumbnail only if data already loaded

### Error Handling
- Network errors (full-screen mode only)
- Invalid URLs
- Timeout errors
- Parse errors
All are caught and displayed with user-friendly messages

## Implementation Details

### Files Created
1. `ClippyIsle/Managers/LinkMetadataManager.swift` - Metadata fetching logic for URLs
2. `ClippyIsle/Views/Components/InlineLinkPreview.swift` - Rich preview for full-screen mode
3. `ClippyIsle/Views/Components/CompactItemPreview.swift` - Lightweight preview for list view
4. `ClippyIsle/Views/Components/LinkPreviewCard.swift` - Full-screen preview card UI (legacy)

### Files Modified
1. `ClippyIsle/Views/Subviews.swift` - Removed long-press gesture from ClipboardItemRow
2. `ClippyIsle/ContentView.swift` - Added always-on lightweight previews for all item types

### Dependencies
- No external dependencies required
- Uses native iOS LinkPresentation framework (iOS 13+) for URL metadata (full-screen mode only)

## Known Issues & Fixes

### v1 - Performance Issues (Fixed)
**Problem:** Initial implementation caused crashes due to:
- Creating inline previews for ALL items simultaneously
- Multiple network requests for URL metadata
- Heavy async image loading for all images
- Excessive UI rendering

**Solution:** Replaced with lightweight `CompactItemPreview`:
- No network calls in list view
- No async operations during scrolling
- Minimal UI with simple badges
- Rich previews only shown in full-screen mode

## Future Enhancements

Potential improvements:
1. Cache fetched metadata to avoid repeated network calls in full-screen mode
2. Add smooth animations when displaying previews
3. Support for custom URL schemes
4. Share button in the preview card
5. Copy individual metadata fields (title, description)
6. Open URL in Safari button
7. Support for more file types (PDFs, videos, etc.)
8. Optional rich previews in list view (with performance optimizations)

## Testing

Manual testing should include:

1. **URL Items:**
   - Test with various websites (news, blogs, social media)
   - Verify domain/path display in list view
   - Verify rich preview in full-screen mode
   - Test error handling for invalid URLs

2. **Image Items:**
   - Test with PNG images
   - Test with JPEG images
   - Verify thumbnail display in compact preview
   - Check behavior when image data not loaded

3. **Text Items:**
   - Test with short text (< 50 chars)
   - Test with long text (> 50 chars to verify truncation)
   - Verify text readability in compact preview

4. **Performance:**
   - Test with many items (50+) in the list
   - Verify smooth scrolling
   - Verify no crashes or freezing
   - Check memory usage

5. **Edge Cases:**
   - Very long URLs
   - URLs with special characters
   - Slow network conditions
   - Missing image data
   - Very long text content

5. **User Interaction:**
   - Verify previews display automatically
   - Test tap to open full-screen preview
   - Verify scrolling performance with multiple previews
   - Test on both iPhone and iPad
   - Test in light and dark mode
