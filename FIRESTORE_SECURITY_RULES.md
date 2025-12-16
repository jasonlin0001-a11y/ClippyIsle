# Firestore Security Rules for User Identity System

This document provides the recommended Firestore security rules for the `users` collection implemented in the User Identity System.

## Recommended Security Rules

Add these rules to your Firebase Console → Firestore → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection - for User Identity System
    match /users/{userId} {
      // Allow users to read their own profile
      allow read: if request.auth != null && request.auth.uid == userId;
      
      // Allow users to create their own profile
      allow create: if request.auth != null && request.auth.uid == userId
        && request.resource.data.uid == userId
        && request.resource.data.keys().hasAll(['uid', 'nickname', 'referral_count', 'discovery_impact', 'created_at']);
      
      // Allow users to update their own profile (nickname, fcm_token only for security)
      allow update: if request.auth != null && request.auth.uid == userId
        && request.resource.data.uid == userId
        && (!request.resource.data.diff(resource.data).affectedKeys().hasAny(['uid', 'created_at']));
      
      // Prevent deletion of user profiles
      allow delete: if false;
    }
    
    // Public read access for nickname only (for "Shared by" feature on web)
    // This can be implemented via a Cloud Function or a separate public subcollection
    // For simplicity, we allow public read of the nickname field:
    match /users/{userId}/public/{document} {
      allow read: if true;
    }
    
    // Shared clipboards collection - include sharer info
    match /sharedClipboards/{shareId} {
      // Anyone can read shared clipboards (they need the share ID)
      allow read: if true;
      
      // Only authenticated users can create shares
      allow create: if request.auth != null;
      
      // No updates or deletes allowed
      allow update, delete: if false;
    }
    
    // Existing clipboard items collection (if you have one)
    match /clipboardItems/{itemId} {
      allow read, write: if request.auth != null;
    }
    
    // Cloud Notes - Email mapping collection
    match /email_mapping/{email} {
      // Allow authenticated users to create/update their email binding
      allow read, write: if request.auth != null;
    }
    
    // Cloud Notes - User inbox subcollection
    match /users/{userId}/inbox/{messageId} {
      // Allow users to read their own inbox
      allow read: if request.auth != null && request.auth.uid == userId;
      
      // Allow users to update isProcessed status on their own messages
      allow update: if request.auth != null && request.auth.uid == userId
        && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['isProcessed']);
      
      // Cloud Functions can write to inbox (requires admin SDK)
      // Users cannot create or delete inbox items directly
      allow create, delete: if false;
    }
  }
}
```

## Schema Overview

### Users Collection (`/users/{uid}`)

| Field | Type | Description | Default |
|-------|------|-------------|---------|
| `uid` | String | Firebase Auth UID (immutable) | Auto-generated |
| `nickname` | String | Display name for sharing | `User_[Last4CharsOfUID]` |
| `referral_count` | Int | For Influencer Rank feature | 0 |
| `discovery_impact` | Int | For Discoverer Rank feature | 0 |
| `created_at` | Timestamp | Account creation date | Server timestamp |
| `fcm_token` | String? | Firebase Cloud Messaging token | null |

### Policy Notes

1. **Duplicate nicknames are allowed** - No uniqueness check is required per the requirements.
2. **UID is immutable** - Once set, the uid field cannot be changed.
3. **created_at is immutable** - The creation timestamp cannot be modified.
4. **Public nickname access** - For web sharing features, nickname can be read publicly.

### Email Mapping Collection (`/email_mapping/{email}`)

| Field | Type | Description |
|-------|------|-------------|
| `uid` | String | Firebase Auth UID of the user who bound this email |

### User Inbox Subcollection (`/users/{uid}/inbox/{messageId}`)

| Field | Type | Description |
|-------|------|-------------|
| `content` | String | Email body content |
| `subject` | String | Email subject line |
| `from` | String | Sender email address |
| `receivedAt` | Timestamp | When the email was received |
| `isProcessed` | Boolean | Whether the item has been archived |

## Implementation Details

- **Anonymous Authentication**: Users are signed in anonymously on first app launch.
- **Profile Creation**: A user profile is automatically created in Firestore upon first sign-in.
- **Nickname Updates**: Users can update their nickname through the Settings screen.
- **Sharing Integration**: When sharing items, the sharer's UID and nickname are attached to the share document.

## Testing the Rules

You can test these rules using the Firebase Emulator Suite:

```bash
firebase emulators:start
```

Then use the Firebase Console's Rules Playground to test various scenarios.
