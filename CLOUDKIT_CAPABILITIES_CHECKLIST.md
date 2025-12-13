# CloudKit Sharing - Capabilities Checklist

This checklist outlines exactly which capabilities need to be enabled in Xcode's "Signing & Capabilities" tab to support CloudKit Sharing in CC ISLE.

## ✅ Required Capabilities

### 1. iCloud
**Status:** Already Configured ✓

**Configuration Steps:**
1. In Xcode, select your project
2. Select the "ClippyIsle" target
3. Go to "Signing & Capabilities" tab
4. Click "+ Capability" if not present, then add "iCloud"

**Required Settings:**
- ☑️ **CloudKit** - Enable CloudKit services
- ☑️ **Containers** - Select or create: `iCloud.J894ABBU74.ClippyIsle`

**Verification in Entitlements:**
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

---

### 2. App Groups
**Status:** Already Configured ✓

**Configuration Steps:**
1. In Xcode, select your project
2. Select the "ClippyIsle" target
3. Go to "Signing & Capabilities" tab
4. Click "+ Capability" if not present, then add "App Groups"

**Required Settings:**
- ☑️ **App Groups** - `group.com.shihchieh.clippyisle`

**Purpose:** 
- Required for sharing data between main app and extensions
- Used for file storage that needs to be synced

**Verification in Entitlements:**
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.shihchieh.clippyisle</string>
</array>
```

---

### 3. Background Modes (Optional but Recommended)
**Status:** May need configuration

**Configuration Steps:**
1. In Xcode, select your project
2. Select the "ClippyIsle" target
3. Go to "Signing & Capabilities" tab
4. Click "+ Capability" if not present, then add "Background Modes"

**Required Settings:**
- ☑️ **Remote notifications** - Receive CloudKit change notifications

**Purpose:**
- Allows the app to receive CloudKit sync notifications in the background
- Enables faster sync when shared items are modified
- Not strictly required but improves user experience

**Verification in Entitlements:**
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

---

## 📱 Additional Configuration

### CloudKit Dashboard Setup

1. **Access Dashboard:**
   - Go to [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
   - Sign in with your Apple Developer account
   - Select "iCloud.J894ABBU74.ClippyIsle" container

2. **Schema Configuration:**
   - The schema is automatically created by Core Data
   - Record Types: `CD_ClipboardItemEntity`, `CKShare`
   - Indexes: Created automatically for query optimization

3. **Security Roles (Optional):**
   - Default roles are sufficient for basic sharing
   - Custom roles can be created for advanced scenarios

---

## 🎯 Target-Specific Configuration

### Main App Target (ClippyIsle)
All capabilities should be enabled as described above.

### Widget Extension Target (ClippyIsleWidget)
- ✅ App Groups - Same group identifier
- ✅ iCloud (Optional) - If widget needs to access CloudKit data

### Share Extension Target (ClippyIsleShare)
- ✅ App Groups - Same group identifier
- ✅ iCloud (Optional) - If share extension needs to access CloudKit data

---

## 🔐 Provisioning Profile Requirements

### Development
- App ID must have iCloud capability enabled
- Development provisioning profile must include iCloud
- App Groups must be configured in App ID

### Distribution (App Store)
- Production provisioning profile must include iCloud
- App Store Connect must have iCloud configured
- CloudKit container must be in production environment

---

## ✔️ Verification Steps

### 1. Build-Time Verification
```bash
# Check entitlements are correctly set
xcodebuild -showBuildSettings -project ClippyIsle.xcodeproj -target ClippyIsle | grep ENTITLEMENTS
```

### 2. Runtime Verification
```swift
// In your app code, verify CloudKit availability
CKContainer.default().accountStatus { (accountStatus, error) in
    switch accountStatus {
    case .available:
        print("✅ iCloud is available")
    case .noAccount:
        print("❌ No iCloud account")
    case .restricted:
        print("❌ iCloud is restricted")
    case .couldNotDetermine:
        print("❌ Could not determine iCloud status")
    case .temporarilyUnavailable:
        print("⚠️ iCloud temporarily unavailable")
    @unknown default:
        print("❌ Unknown iCloud status")
    }
}
```

### 3. Device Verification
- **Settings → [Your Name] → iCloud** - User must be signed in
- **Settings → [Your Name] → iCloud → iCloud Drive** - Must be ON
- **Settings → ClippyIsle** - iCloud permission granted

---

## 🚨 Common Issues & Solutions

### Issue 1: "CloudKit container not found"
**Solution:**
- Verify container identifier matches exactly: `iCloud.J894ABBU74.ClippyIsle`
- Check that container exists in CloudKit Dashboard
- Regenerate provisioning profile with iCloud enabled

### Issue 2: "App Groups not accessible"
**Solution:**
- Verify app group identifier: `group.com.shihchieh.clippyisle`
- Ensure all targets use the same group identifier
- Clean build folder and rebuild

### Issue 3: "Sharing not available"
**Solution:**
- Confirm user is signed in to iCloud on device
- Check that iCloud Drive is enabled
- Verify network connectivity
- Ensure development/production environment is correct

### Issue 4: "Provisioning profile doesn't support iCloud"
**Solution:**
- Go to Apple Developer Portal
- Regenerate provisioning profile with iCloud capability
- Download and install new profile
- Restart Xcode

---

## 📋 Pre-Release Checklist

Before releasing with CloudKit Sharing:

- [ ] All required capabilities enabled
- [ ] Entitlements file is correct
- [ ] CloudKit Dashboard schema is finalized
- [ ] Tested with multiple iCloud accounts
- [ ] Tested share link on different devices
- [ ] Verified sharing permissions work correctly
- [ ] Tested offline/online scenarios
- [ ] Error handling for no iCloud account
- [ ] User-facing documentation updated
- [ ] TestFlight testing completed
- [ ] Privacy policy updated (if needed)

---

## 📚 Additional Resources

- [Apple Developer: Configuring CloudKit](https://developer.apple.com/documentation/cloudkit/configuring_cloudkit)
- [Apple Developer: App Groups](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_application-groups)
- [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
- [Technical Q&A: CloudKit Setup](https://developer.apple.com/library/archive/qa/qa1838/_index.html)

---

## 💡 Tips

1. **Always test on physical devices** - Simulator has limitations with CloudKit
2. **Use development environment first** - Easier to test and debug
3. **Monitor CloudKit Dashboard** - Check for sync issues and errors
4. **Enable CloudKit logging** - Add launch argument: `-com.apple.CoreData.CloudKitDebug 1`
5. **Test with multiple accounts** - Verify sharing works between different users
6. **Check quota limits** - CloudKit has storage and request limits

---

**Last Updated:** December 2025
**App Version:** CC ISLE
**CloudKit Container:** iCloud.J894ABBU74.ClippyIsle
