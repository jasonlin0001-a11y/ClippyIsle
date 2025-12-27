# Creator Subscription System

This document describes the implementation of the Creator Subscription Backend and Push Notification system.

## Firestore Schema

### 1. User Following (Subcollection Approach)

For scalable following relationships, we use a subcollection-based approach.

**Path:** `users/{currentUserId}/following/{targetUserId}`

**Fields:**
| Field | Type | Description |
|-------|------|-------------|
| `uid` | String | The UID of the user being followed |
| `timestamp` | Timestamp | When the follow relationship was created |
| `displayName` | String (Optional) | Cached display name for quick listing |

**Example Document:**
```json
// Path: users/myUser123/following/creator456
{
  "uid": "creator456",
  "timestamp": "2024-01-15T10:30:00Z",
  "displayName": "Cool Creator"
}
```

### 2. User Profile (with follow counts)

**Path:** `users/{uid}`

**Additional Fields:**
| Field | Type | Description |
|-------|------|-------------|
| `followersCount` | Int | Number of followers |
| `followingCount` | Int | Number of users being followed |

### 3. `followers` Collection (Legacy - for FCM Topics)

Tracks follow relationships for FCM topic-based push notifications.

**Document ID:** `{creator_uid}_{follower_uid}` (Composite key to ensure unique relationship)

**Fields:**
| Field | Type | Description |
|-------|------|-------------|
| `creator_uid` | String | The UID of the creator being followed |
| `follower_uid` | String | The UID of the user following the creator |
| `created_at` | Timestamp | When the follow relationship was created |

### 4. `creator_posts` Collection

Stores content posted by creators for their feed.

**Document ID:** Auto-generated UUID

**Fields:**
| Field | Type | Description |
|-------|------|-------------|
| `creator_uid` | String | The UID of the creator who posted |
| `title` | String | Title of the post/article |
| `content_url` | String | Link to the article or content |
| `curator_note` | String (Optional) | Creator's review or comment about the content |
| `link_title` | String (Optional) | OG title from link preview |
| `link_image` | String (Optional) | OG image URL from link preview |
| `link_description` | String (Optional) | OG description from link preview |
| `link_domain` | String (Optional) | Domain name (e.g., "youtube.com") |
| `created_at` | Timestamp | When the post was created |

**Example Document:**
```json
{
  "creator_uid": "abc123",
  "title": "Amazing Article About Swift",
  "content_url": "https://example.com/swift-article",
  "curator_note": "This article changed how I think about async/await!",
  "link_title": "Swift Async/Await Guide",
  "link_image": "https://example.com/image.jpg",
  "link_domain": "example.com",
  "created_at": "2024-01-15T14:00:00Z"
}
```

## Swift Implementation

### SocialService (New - Subcollection Approach)

Located at: `ClippyIsle/Managers/SocialService.swift`

#### Key Functions:

```swift
// Follow a user - adds to subcollection and increments followersCount
func followUser(targetUid: String, displayName: String?) async throws

// Unfollow a user - removes from subcollection and decrements followersCount
func unfollowUser(targetUid: String) async throws

// Check if following (local cache)
func checkIfFollowing(targetUid: String) -> Bool

// Check if following (server verification)
func checkIfFollowingAsync(targetUid: String) async -> Bool

// Load all following entries for current user
func loadFollowingList() async

// Setup real-time listener for following subcollection
func setupFollowingListener()

// Get following count
func getFollowingCount() -> Int

// Get followers count for a user
func getFollowersCount(uid: String) async -> Int
```

#### Usage Example:

```swift
// In a SwiftUI View
struct CreatorProfileView: View {
    let creatorUid: String
    let creatorName: String
    
    var body: some View {
        VStack {
            // Creator info...
            
            // Follow/Unfollow button
            FollowButton(targetUid: creatorUid, targetDisplayName: creatorName)
        }
        .onAppear {
            // Setup listener when view appears
            SocialService.shared.setupFollowingListener()
        }
    }
}
```

### CreatorSubscriptionManager (Legacy - for FCM)

Located at: `ClippyIsle/Managers/CreatorSubscriptionManager.swift`

#### Key Functions:

```swift
// Follow a creator - writes to Firestore and subscribes to FCM topic
func followUser(targetUid: String) async throws

// Unfollow a creator - deletes from Firestore and unsubscribes from FCM topic
func unfollowUser(targetUid: String) async throws

// Check if following a creator
func isFollowing(targetUid: String) async -> Bool

// Load all followed creators for current user
func loadFollowedCreators() async

// Get follower count for a creator
func getFollowerCount(creatorUid: String) async -> Int

// Create a new post (triggers push notification via Cloud Function)
func createPost(title: String, contentUrl: String, curatorNote: String?, linkTitle: String?, linkImage: String?, linkDescription: String?, linkDomain: String?) async throws
```

#### FCM Topic Naming Convention:
- Topic format: `creator_{creator_uid}`
- Example: `creator_abc123`

## Cloud Functions

Located at: `functions/index.js`

### `fetchLinkPreview`

**Type:** HTTPS Callable Function

**Input:** `{ url: string }`

**Logic:**
1. Validates URL and user authentication
2. Fetches HTML using axios with browser User-Agent
3. Parses Open Graph tags using cheerio
4. Falls back to twitter:* and meta description tags

**Output:**
```javascript
{
  success: true,
  data: {
    title: "Page Title",
    image: "https://example.com/og-image.jpg",
    description: "Page description",
    url: "https://example.com"
  }
}
```

### `onCreatorPostCreated`

**Trigger:** Firestore `onCreate` for `creator_posts/{postId}`

**Logic:**
1. When a new post is added, extracts `creator_uid` and `title`
2. Fetches creator's profile to get their display name
3. Sends FCM message to topic `creator_{creator_uid}`

**Notification Payload:**
```javascript
{
  notification: {
    title: "New update from [Creator Name]",
    body: "[Post Title] - [Curator Note]"
  },
  data: {
    type: "creator_post",
    post_id: postId,
    creator_uid: creatorUid,
    url: contentUrl  // For Deep Linking
  }
}
```

## Deployment

### Deploy Cloud Functions:
```bash
cd functions
npm install
firebase deploy --only functions
```

### Firestore Security Rules

Add to your Firestore rules:

```javascript
// Users collection and following subcollection
match /users/{userId} {
  // Users can read any profile
  allow read: if true;
  // Users can only update their own profile
  allow update: if request.auth != null && request.auth.uid == userId;
  // Users can create their own profile
  allow create: if request.auth != null && request.auth.uid == userId;
  
  // Following subcollection
  match /following/{targetId} {
    // Anyone can read following relationships
    allow read: if true;
    // Users can only manage their own following list
    allow create, delete: if request.auth != null && request.auth.uid == userId;
    // No updates allowed
    allow update: if false;
  }
}

// Legacy followers collection (for FCM)
match /followers/{docId} {
  // Anyone can read follower relationships
  allow read: if true;
  // Users can only create/delete their own follow relationships
  allow create, delete: if request.auth != null 
    && request.resource.data.follower_uid == request.auth.uid;
  // No updates allowed
  allow update: if false;
}

// Creator posts collection
match /creator_posts/{postId} {
  // Anyone can read posts
  allow read: if true;
  // Only the creator can create posts for themselves
  allow create: if request.auth != null 
    && request.resource.data.creator_uid == request.auth.uid;
  // Creators can update/delete their own posts
  allow update, delete: if request.auth != null 
    && resource.data.creator_uid == request.auth.uid;
}
```

## iOS App Configuration Reminder

To receive push notifications, ensure your iOS app has:

1. **Push Notification Capability** enabled in Xcode
2. **Firebase Messaging SDK** integrated
3. **APNs Authentication Key** uploaded to Firebase Console
4. Proper handling of FCM tokens in `AuthenticationManager.updateFCMToken()`
