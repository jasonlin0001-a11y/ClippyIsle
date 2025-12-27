# Universal Links Configuration

This document describes the configuration for Universal Links with the custom domain `ccisle.app`.

## Firebase Hosting Configuration

The `firebase.json` file configures Firebase Hosting to:
- Serve the `public` folder
- Rewrite `/u/*`, `/s/*`, and `/article/*` paths to `index.html` for SPA behavior
- Serve the Apple App Site Association file with the correct `Content-Type: application/json` header

## Apple App Site Association (AASA)

The AASA file is located at `public/.well-known/apple-app-site-association` and configures Universal Links for the iOS app.

### Current Configuration

The AASA file is configured with:
- **Team ID**: `J894ABBU74`
- **Bundle ID**: `J894ABBU74.ClippyIsle`
- **App ID**: `J894ABBU74.J894ABBU74.ClippyIsle`

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "J894ABBU74.J894ABBU74.ClippyIsle",
        "paths": ["/u/*", "/s/*", "/article/*"]
      }
    ]
  }
}
```

## iOS Project Configuration

To enable Universal Links in your iOS app:

1. **Open your project in Xcode**

2. **Add the Associated Domains capability:**
   - Select your project in the Project Navigator
   - Select your app target
   - Go to the "Signing & Capabilities" tab
   - Click the "+ Capability" button
   - Search for and add "Associated Domains"

3. **Add the domain:**
   - In the Associated Domains section, click the "+" button
   - Add: `applinks:ccisle.app`

4. **Verify the configuration:**
   - Ensure your Apple Developer account has the Associated Domains capability enabled
   - Make sure your provisioning profile is updated to include this capability

## Testing Universal Links

After deployment:

1. Deploy the Firebase Hosting configuration: `firebase deploy --only hosting`
2. Verify the AASA file is accessible at: `https://ccisle.app/.well-known/apple-app-site-association`
3. Install the app on a device (not simulator)
4. Test links like:
   - `https://ccisle.app/u/example`
   - `https://ccisle.app/s/example`
   - `https://ccisle.app/article/example`
