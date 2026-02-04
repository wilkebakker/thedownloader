# THE DOWNLOADER - Claude Instructions

## Project Overview
macOS menu bar app for downloading videos (YouTube, TikTok, Instagram) and converting media files. Built with SwiftUI.

## Key Files
- `TheDownloader/TheDownloaderApp.swift` - Main app, AppDelegate, popover setup
- `TheDownloader/DownloaderView.swift` - Download tab UI + yt-dlp integration
- `TheDownloader/ConverterView.swift` - Convert tab UI + ffmpeg integration
- `TheDownloader/SetupView.swift` - Setup tab, Sparkle updates, Quick Actions
- `TheDownloader/Utilities.swift` - Helper functions (which, runProcess)
- `TheDownloader/Info.plist` - App config + Sparkle settings

## Dependencies
- yt-dlp (brew install yt-dlp)
- ffmpeg (brew install ffmpeg)
- Sparkle framework (Swift Package)

## Sparkle Auto-Update System

### Feed URL
```
https://tools4creatives.com/updates/thedownloader/appcast.xml
```

### Public Key (in Info.plist)
```
0CTbhbvjwE0o3pYEOGFPehi3zP77fLOAyF6kEaAc0po=
```

### Private Key
Stored in macOS Keychain (generated via Sparkle's generate_keys tool)

### Sign Update Tool Location
```
/Users/wilkebakker/Library/Developer/Xcode/DerivedData/TheDownloader-eysocukhbosxzdageskvsyrkfmjs/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update
```

Note: Path may change if DerivedData is cleaned. Find it with:
```bash
find ~/Library/Developer/Xcode/DerivedData -name "sign_update" -type f 2>/dev/null | head -1
```

## Release Process

### 1. Update Version
Edit `TheDownloader/Info.plist`:
- `CFBundleShortVersionString` (e.g., "1.1")
- `CFBundleVersion` (build number, e.g., "2")

### 2. Build Release
```bash
xcodebuild -scheme TheDownloader -configuration Release archive -archivePath ./build/TheDownloader.xcarchive
```

Or use Xcode: Product > Archive

### 3. Export App
Export from Organizer or:
```bash
xcodebuild -exportArchive -archivePath ./build/TheDownloader.xcarchive -exportPath ./build -exportOptionsPlist ExportOptions.plist
```

### 4. Create ZIP
```bash
cd ./build
ditto -c -k --keepParent TheDownloader.app TheDownloader-VERSION.zip
```

### 5. Sign the ZIP
```bash
# Find sign_update tool
SIGN_TOOL=$(find ~/Library/Developer/Xcode/DerivedData -name "sign_update" -type f 2>/dev/null | head -1)

# Sign the zip
$SIGN_TOOL TheDownloader-VERSION.zip
```

This outputs something like:
```
sparkle:edSignature="ABC123..." length="12345678"
```

### 6. Upload to GitHub
Create a new release on GitHub with the .zip attached.

### 7. Update appcast.xml
Edit `sparkle/appcast.xml` - add new `<item>`:
```xml
<item>
    <title>Version X.X</title>
    <pubDate>DATE_HERE</pubDate>
    <sparkle:version>BUILD_NUMBER</sparkle:version>
    <sparkle:shortVersionString>X.X</sparkle:shortVersionString>
    <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
    <description><![CDATA[
        <h2>What's New</h2>
        <ul>
            <li>Change 1</li>
            <li>Change 2</li>
        </ul>
    ]]></description>
    <enclosure
        url="https://github.com/USERNAME/TheDownloader/releases/download/vX.X/TheDownloader-X.X.zip"
        sparkle:edSignature="SIGNATURE_FROM_STEP_5"
        length="FILE_SIZE_IN_BYTES"
        type="application/octet-stream"/>
</item>
```

### 8. Upload appcast.xml
Upload to: `https://tools4creatives.com/updates/thedownloader/appcast.xml`

## Build Commands

### Debug Build
```bash
xcodebuild -scheme TheDownloader -configuration Debug build
```

### Release Build
```bash
xcodebuild -scheme TheDownloader -configuration Release build
```

## Window Size
Popover: 380x480 (set in TheDownloaderApp.swift)

## Backup Location
Original backup at: `~/Desktop/TheDownloader_backup_20260120_121707`
