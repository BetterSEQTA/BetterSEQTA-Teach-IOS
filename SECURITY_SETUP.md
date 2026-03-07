# Cloudflare API Key Security Setup

This document explains how to securely manage your Cloudflare API credentials in the TechQTA iOS app.

## Overview

The app uses a secure configuration system that keeps API keys out of source code by:
1. Using `.xcconfig` files for local development (excluded from Git)
2. Injecting secrets into `Info.plist` at build time via Xcode Cloud environment variables
3. Loading credentials dynamically from the app bundle

## File Structure

```
TechQTA/Config/
├── Secrets.xcconfig          # Local secrets file (.gitignored)
└── CloudflareSecrets.example.plist  # Template for actual plist

ci_scripts/
└── ci_pre_xcodebuild.sh      # Xcode Cloud build script

.gitignore                     # Excludes Secrets.xcconfig
```

## Local Development Setup

### Step 1: Configure Your Secrets File

1. Open `TechQTA/Config/Secrets.xcconfig` (if it doesn't exist, copy from the example)
2. Fill in your credentials:
   ```
   CLOUDFLARE_ACCOUNT_ID = your-cloudflare-account-id
   CLOUDFLARE_API_KEY = your-api-key
   ```

### Step 2: Link to Xcode Project

1. In Xcode, select your project (not the target) from the Project Navigator
2. Go to the **Info** tab
3. Under **Configurations**, set both Debug and Release to use `TechQTA/Config/Secrets.xcconfig`

### Step 3: Test Locally

1. Build and run the app on a device or simulator
2. Check that Cloudflare API calls work correctly
3. Verify credentials are loaded via `AppConfiguration.isAvailable`

## Xcode Cloud Setup

### Step 1: Configure Environment Variables

1. Go to App Store Connect → Your Apps → TechQTA → Xcode Cloud
2. Edit the workflow and go to the **Environment** tab
3. Add two environment variables:
   - `CLOUDFLARE_ACCOUNT_ID` (mark as Secret)
   - `CLOUDFLARE_API_KEY` (mark as Secret)

### Step 2: Verify Build Script

The script at `ci_scripts/ci_pre_xcodebuild.sh` will:
- Read the environment variables from Xcode Cloud
- Generate `TechQTA/Config/Secrets.xcconfig` with your credentials
- Inject these into the app bundle during build

## Using the Configuration in Code

```swift
import Foundation

// Check if configuration is available
if AppConfiguration.isAvailable {
    // Make API calls using the loaded credentials
} else {
    print("Cloudflare credentials not configured")
}

// Get account ID
let accountId = AppConfiguration.cloudflareAccountID

// Get auth token
let authToken = AppConfiguration.cloudflareAuthToken

// Construct base URL
if let baseURL = AppConfiguration.baseURL() {
    // Use this URL for API requests
}
```

## Security Considerations

### What's Protected?
- ✅ Credentials are never in Swift source code
- ✅ `.xcconfig` files are gitignored
- ✅ Xcode Cloud secrets are encrypted at rest
- ✅ Secrets only exist in compiled binary

### What's Not Perfectly Secure?
⚠️ **Important:** Anyone who can extract the app binary (via decompilation) could potentially access credentials. This is a fundamental limitation of client-side apps.

For maximum security, consider:
- Building your own backend proxy to hold secrets server-side
- Using Cloudflare's WARP or other edge computing services
- Implementing key obfuscation for additional protection

## Troubleshooting

### "Cloudflare credentials not configured" Error

1. **Local Development:**
   - Verify `Secrets.xcconfig` is linked in Xcode Info tab
   - Check that `.xcconfig` file contains valid credentials
   - Clean build folder: `Product > Clean Build Folder`

2. **Xcode Cloud:**
   - Verify environment variables are set in App Store Connect
   - Ensure script runs before build (check workflow settings)
   - Check Xcode Cloud logs for script execution errors

### Credentials Not Loading

1. Verify key names match between `.xcconfig` and `CloudflareSecrets.plist`
2. Check that plist file is included in the target's Bundle Resources
3. Ensure no placeholder values remain (e.g., "YOUR_ACCOUNT_ID")

## Updating Credentials

### Local Development
Simply edit `TechQTA/Config/Secrets.xcconfig` and rebuild.

### Xcode Cloud
1. Update environment variables in App Store Connect
2. Trigger a new build to regenerate the `.xcconfig` file
3. New builds will use updated credentials

## Best Practices

- ✅ Never commit `.xcconfig` files with real secrets
- ✅ Use descriptive key names for better maintainability
- ✅ Rotate API keys regularly
- ✅ Monitor API usage and set rate limits
- ✅ Test in staging environment before production deployment
