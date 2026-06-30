# THE DOWNLOADER

A free macOS menu-bar app for downloading video and audio from YouTube, TikTok and
Instagram, plus a built-in media converter. Built with SwiftUI. Bundles `yt-dlp` and
`ffmpeg` so there's nothing to install — just run the app.

## Features

### Download
- **Platforms:** YouTube (incl. Shorts), TikTok, Instagram (Reels, Posts, Stories)
- **Video:** MP4 (H.264), MP4 (H.265), MOV — video and audio are always merged into a
  single file
- **Audio:** WAV (24-bit / 48 kHz), MP3 (320 kbps)
- Paste multiple links at once; optional full-playlist download
- Auto-paste from clipboard, live progress, cancel

### Convert (drag & drop)
- **Audio:** WAV 24-bit, MP3
- **Video:** H.264, H.265, WebM, ProRes — optional rescale (720p/1080p/4K/50%/25%)
- **Image:** WebP, PNG, JPG
- **Webify** one-click: web-optimised WebM / WebP / MP3
- Drop files on the menu-bar icon or the Convert tab
- Incompatible format/input combinations are skipped automatically and reported
  honestly ("3 done · 1 failed · 2 skipped") instead of failing silently
- Never overwrites a source file (adds a `_converted` suffix on a name clash)

### Projects & Quick Actions
- Set a project folder; drop files to convert and/or copy into it
- Optional Finder Quick Actions ("Webify", "Convert to WAV")

## Instagram login

Instagram requires a logged-in session. In the **Setup** tab pick which browser to pull
cookies from (Safari / Chrome / Firefox / Brave / Edge). TikTok and YouTube need no login.

Safari stores its cookies in a protected folder, so the app needs **Full Disk Access**.
The app adds itself to the Full Disk Access list automatically — open
System Settings → Privacy & Security → Full Disk Access and toggle **TheDownloader** on
(the Setup tab has a button that opens this directly).

## Requirements

- macOS 13 or later
- Apple Silicon or Intel — the app and its bundled `yt-dlp` / `ffmpeg` are universal
  (arm64 + x86_64), so it runs natively on Apple Silicon

## Building

Bundled binaries (`yt-dlp`, `ffmpeg`, `ffprobe`) are downloaded and code-signed by the
build script, which also packages a signed, notarised installer:

```bash
./build-installer.sh
```

The script downloads universal `ffmpeg`/`ffprobe` (arm64 + x86_64 via `lipo`) so the app
stays Apple-Silicon-native. The bundled CLI tools are signed with
`installer/bundled-bin.entitlements` (`com.apple.security.cs.disable-library-validation`)
so `yt-dlp`'s embedded Python loads under the Hardened Runtime.

Updates are delivered via Sparkle.

## License

See `installer/LICENSE.txt`. Only download content you have the rights to use.
