# Admin System - Firestore Setup

This document explains how to set up the Admin system using Firestore.

## Database Schema

### Admin Collection
The admin status is verified by checking if a document exists in the `admins` collection.

```
admins/
  └── {user_uid}/
        ├── name: "Admin Name" (string)
        ├── role: "super_admin" (string)
        └── createdAt: timestamp
```

### How to Add an Admin

1. Go to Firebase Console → Firestore Database
2. Create a new collection called `admins` (if it doesn't exist)
3. Add a new document with the user's UID as the Document ID
4. Add fields:
   - `name`: String (admin's display name)
   - `role`: String (e.g., "super_admin", "moderator")
   - `createdAt`: Timestamp

Example document:
```json
{
  "name": "Jason",
  "role": "super_admin",
  "createdAt": "December 27, 2024 at 9:00:00 AM UTC+8"
}
```

## Firestore Security Rules

Update your Firestore Security Rules to use the admin collection for authorization.

### Helper Function
```javascript
// Check if user is an admin
function isAdmin() {
  return exists(/databases/$(database)/documents/admins/$(request.auth.uid));
}
```

### Rules for Posts Collection
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function: Check if current user is admin
    function isAdmin() {
      return exists(/databases/$(database)/documents/admins/$(request.auth.uid));
    }
    
    // Helper function: Check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Admin collection - read-only (only Firebase Console can write)
    match /admins/{uid} {
      allow read: if isAuthenticated();
      allow write: if false; // Only editable via Firebase Console
    }
    
    // Creator posts - anyone can read, curators can create, owner/admin can delete
    match /creator_posts/{postId} {
      allow read: if true;
      allow create: if isAuthenticated();
      allow update: if isAuthenticated() && 
                      (request.auth.uid == resource.data.creatorId || isAdmin());
      allow delete: if isAuthenticated() && 
                      (request.auth.uid == resource.data.creatorId || isAdmin());
    }
    
    // Reports collection - users can create, admins can read/update
    match /reports/{reportId} {
      allow create: if isAuthenticated();
      allow read, update: if isAdmin();
      allow delete: if false;
    }
    
    // Flagged for review - admins only
    match /flagged_for_review/{postId} {
      allow read, write: if isAdmin();
    }
    
    // User profiles
    match /users/{userId} {
      allow read: if true;
      allow write: if isAuthenticated() && request.auth.uid == userId;
      
      // User subcollections
      match /{subcollection}/{docId} {
        allow read, write: if isAuthenticated() && request.auth.uid == userId;
      }
    }
  }
}
```

## How Admin Check Works in the App

1. **On User Login**: The app calls `SafetyService.shared.checkAdminStatus()` which:
   - Queries `admins/{currentUserUID}` in Firestore
   - If document exists → `isAdmin = true`
   - If document doesn't exist → `isAdmin = false`

2. **On Sign Out**: The `SafetyService.shared.resetAdminStatus()` is called to clear the admin flag.

3. **UI Access Control**: The `isCurrentUserAdmin()` function returns the cached `isAdmin` value for:
   - Showing "Delete Post (Admin)" button in context menus
   - Any other admin-only features

## Security Notes

- ❌ **Never** hardcode admin UIDs in the app source code
- ✅ **Always** verify admin status from Firestore
- ✅ **Always** enforce permissions in Firestore Security Rules (client-side checks can be bypassed)
- ✅ The `admins` collection should only be writable via Firebase Console (not from the app)
