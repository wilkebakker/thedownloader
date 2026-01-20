# Sparkle Auto-Update Setup

## Overview
THE DOWNLOADER uses Sparkle for automatic updates. Updates are checked from:
`https://tools4creatives.com/updates/thedownloader/appcast.xml`

## Setup Steps

### 1. Generate Signing Keys
Run this command from your Xcode DerivedData Sparkle folder:
```bash
# Find the generate_keys tool
find ~/Library/Developer/Xcode/DerivedData -name "generate_keys" -type f 2>/dev/null | head -1

# Run it (replace path with actual path found above)
/path/to/generate_keys
```

This creates keys in `~/Library/Application Support/Sparkle/`

### 2. Add Public Key to Info.plist
Copy the public key and add it to `TheDownloader/Info.plist`:
```xml
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY_HERE</string>
```

### 3. Sign Your Release
When creating a release:
```bash
# Find the sign_update tool
find ~/Library/Developer/Xcode/DerivedData -name "sign_update" -type f 2>/dev/null | head -1

# Sign your .zip file
/path/to/sign_update TheDownloader-1.0.zip
```

This outputs a signature like: `sparkle:edSignature="..."`

### 4. Update appcast.xml
For each release, add an `<item>` with:
- Version number
- Download URL (GitHub Releases)
- EdDSA signature
- File size (in bytes)
- Release notes

### 5. Host appcast.xml
Upload `appcast.xml` to:
`https://tools4creatives.com/updates/thedownloader/appcast.xml`

## Release Workflow

1. Build Release in Xcode (Product > Archive)
2. Export as .zip
3. Sign the .zip with `sign_update`
4. Upload .zip to GitHub Releases
5. Update appcast.xml with new version info
6. Upload appcast.xml to your server

## Testing
Set a lower version in Info.plist, build, then check for updates to test.
