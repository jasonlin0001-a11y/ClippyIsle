# Creator Subscription System

This document describes the implementation of the Creator Subscription Backend and Push Notification system.

## Firestore Schema

### 1. `followers` Collection

Tracks follow relationships between creators and followers.

**Document ID:** `{creator_uid}_{follower_uid}` (Composite key to ensure unique relationship)

**Fields:**
| Field | Type | Description |
|-------|------|-------------|
| `creator_uid` | String | The UID of the creator being followed |
| `follower_uid` | String | The UID of the user following the creator |
| `created_at` | Timestamp | When the follow relationship was created |

**Example Document:**
```json
{
  "creator_uid": "abc123",
  "follower_uid": "xyz789",
  "created_at": "2024-01-15T10:30:00Z"
}
```

### 2. `creator_posts` Collection

Stores content posted by creators for their feed.

**Document ID:** Auto-generated UUID

**Fields:**
| Field | Type | Description |
|-------|------|-------------|
| `creator_uid` | String | The UID of the creator who posted |
| `title` | String | Title of the post/article |
| `content_url` | String | Link to the article or content |
| `curator_note` | String (Optional) | Creator's review or comment about the content |
| `created_at` | Timestamp | When the post was created |

**Example Document:**
```json
{
  "creator_uid": "abc123",
  "title": "Amazing Article About Swift",
  "content_url": "https://example.com/swift-article",
  "curator_note": "This article changed how I think about async/await!",
  "created_at": "2024-01-15T14:00:00Z"
}
```

## Swift Implementation

### CreatorSubscriptionManager

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
func createPost(title: String, contentUrl: String, curatorNote: String?) async throws
```

#### FCM Topic Naming Convention:
- Topic format: `creator_{creator_uid}`
- Example: `creator_abc123`

## Cloud Functions

Located at: `functions/index.js`

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

### `sendTestNotification` (Debug Only)

HTTP endpoint for testing notifications during development.

**Usage:**
```bash
POST /sendTestNotification
{
  "creatorUid": "abc123",
  "title": "Test Title",
  "body": "Test Body"
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
// Followers collection
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
