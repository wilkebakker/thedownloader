#!/bin/bash
#
# THE DOWNLOADER - Build Professional Installer
# Creates a signed & notarized PKG installer with license agreement and DMG
#
# Usage: ./build-installer.sh
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="/tmp/TheDownloader-build"
INSTALLER_DIR="$SCRIPT_DIR/installer"
PKG_ROOT="$BUILD_DIR/pkg_root"
OUTPUT_DIR="$SCRIPT_DIR/build"

# Signing identities
APP_SIGN_IDENTITY="Developer ID Application: Wilke Neels Bakker (X762P3DH33)"
PKG_SIGN_IDENTITY="Developer ID Installer: Wilke Neels Bakker (X762P3DH33)"
TEAM_ID="X762P3DH33"

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    THE DOWNLOADER - Build Installer        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$PKG_ROOT/Applications"

#
# 1. Build the app
#
echo -e "${YELLOW}[1/7]${NC} Building TheDownloader.app..."

cd "$SCRIPT_DIR"
xcodebuild -project TheDownloader.xcodeproj \
    -scheme TheDownloader \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -archivePath "$BUILD_DIR/TheDownloader.xcarchive" \
    archive \
    CODE_SIGN_IDENTITY="$APP_SIGN_IDENTITY" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE="Manual" \
    2>&1 | grep -E "(error:|warning:|ARCHIVE)" || true

# Find the built app (check multiple locations)
if [[ -d "$BUILD_DIR/TheDownloader.app" ]]; then
    APP_PATH="$BUILD_DIR/TheDownloader.app"
elif [[ -d "$BUILD_DIR/DerivedData/Build/Products/Release/TheDownloader.app" ]]; then
    APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/TheDownloader.app"
    cp -R "$APP_PATH" "$BUILD_DIR/"
    APP_PATH="$BUILD_DIR/TheDownloader.app"
elif [[ -d "$BUILD_DIR/DerivedData/Build/Intermediates.noindex/ArchiveIntermediates/TheDownloader/InstallationBuildProductsLocation/Applications/TheDownloader.app" ]]; then
    APP_PATH="$BUILD_DIR/DerivedData/Build/Intermediates.noindex/ArchiveIntermediates/TheDownloader/InstallationBuildProductsLocation/Applications/TheDownloader.app"
    cp -R "$APP_PATH" "$BUILD_DIR/"
    APP_PATH="$BUILD_DIR/TheDownloader.app"
elif [[ -d "$BUILD_DIR/TheDownloader.xcarchive/Products/Applications/TheDownloader.app" ]]; then
    APP_PATH="$BUILD_DIR/TheDownloader.xcarchive/Products/Applications/TheDownloader.app"
    cp -R "$APP_PATH" "$BUILD_DIR/"
    APP_PATH="$BUILD_DIR/TheDownloader.app"
else
    echo -e "${RED}Build failed. Please build manually in Xcode first.${NC}"
    exit 1
fi

echo -e "  ${GREEN}✓${NC} App built"

#
# 2. Create bin directory and download dependencies
#
echo -e "${YELLOW}[2/7]${NC} Bundling dependencies..."
BUNDLE_DIR="$APP_PATH/Contents/Resources/bin"
mkdir -p "$BUNDLE_DIR"

# Detect architecture
ARCH=$(uname -m)

# Download yt-dlp
echo -e "  ${BLUE}→${NC} Downloading yt-dlp..."
if [[ "$ARCH" == "arm64" ]]; then
    YT_DLP_URL="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos"
else
    YT_DLP_URL="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos_legacy"
fi
curl -L -o "$BUNDLE_DIR/yt-dlp" "$YT_DLP_URL" 2>/dev/null
chmod +x "$BUNDLE_DIR/yt-dlp"
echo -e "  ${GREEN}✓${NC} yt-dlp downloaded"

# Download ffmpeg + ffprobe as UNIVERSAL2 (arm64 + x86_64).
# evermeet.cx ships x86_64-only, which triggers macOS's "Intel-based app,
# support ending" warning and breaks once Rosetta is gone. martin-riedl.de
# publishes static builds for BOTH arches at the same version; we lipo them
# into one universal binary so the app runs natively on Apple Silicon and
# still works on Intel. yt-dlp_macos (above) is already universal2.
cd "$BUILD_DIR"
FFMPEG_BASE="https://ffmpeg.martin-riedl.de/redirect/latest/macos"
for tool in ffmpeg ffprobe; do
    echo -e "  ${BLUE}→${NC} Downloading $tool (arm64 + x86_64)..."
    for slice_arch in arm64 amd64; do
        curl -fsSL -o "$tool-$slice_arch.zip" "$FFMPEG_BASE/$slice_arch/release/$tool.zip"
        unzip -o -q "$tool-$slice_arch.zip" -d "$tool-$slice_arch"
    done
    arm_bin=$(find "$tool-arm64" -name "$tool" -type f | head -1)
    x86_bin=$(find "$tool-amd64" -name "$tool" -type f | head -1)
    lipo -create "$arm_bin" "$x86_bin" -output "$BUNDLE_DIR/$tool"
    chmod +x "$BUNDLE_DIR/$tool"
    # Fail loudly if the result isn't actually universal — a silently x86_64-only
    # binary would reintroduce the Intel warning.
    if ! lipo -archs "$BUNDLE_DIR/$tool" | grep -q "arm64"; then
        echo -e "  ${RED}✗ $tool is not universal (missing arm64) — aborting${NC}"; exit 1
    fi
    echo -e "  ${GREEN}✓${NC} $tool universal: $(lipo -archs "$BUNDLE_DIR/$tool")"
done

# Strip extended attributes from all binaries
xattr -cr "$BUNDLE_DIR"

#
# 3. Sign bundled binaries and app
#
echo -e "${YELLOW}[3/7]${NC} Signing binaries and app..."

# Remove ALL extended attributes recursively from app bundle
find "$APP_PATH" -exec xattr -c {} \; 2>/dev/null || true

# Entitlements files
APP_ENTITLEMENTS="$SCRIPT_DIR/TheDownloader/TheDownloader.entitlements"
BIN_ENTITLEMENTS="$INSTALLER_DIR/bundled-bin.entitlements"

# Sign the app itself FIRST (--deep covers Sparkle.framework + nested code).
# Pass --entitlements so the app keeps its file-access entitlements; without it
# a --force re-sign strips everything Xcode applied during archive.
codesign --force --deep --options runtime --timestamp \
    --entitlements "$APP_ENTITLEMENTS" \
    --sign "$APP_SIGN_IDENTITY" \
    "$APP_PATH"

# Re-sign each bundled binary AFTER the deep sign (the --deep pass above clobbers
# them with the app's entitlements). yt-dlp/ffmpeg/ffprobe need
# disable-library-validation so yt-dlp can load its extracted Python.framework.
for binary in "$BUNDLE_DIR"/*; do
    if [[ -f "$binary" && -x "$binary" ]]; then
        echo -e "  ${BLUE}→${NC} Signing $(basename "$binary")..."
        codesign --force --options runtime --timestamp \
            --entitlements "$BIN_ENTITLEMENTS" \
            --sign "$APP_SIGN_IDENTITY" \
            "$binary"
    fi
done

# Re-seal the app container (NO --deep) so its CodeResources reflect the
# re-signed binaries above; without this the app seal is obsolete and
# notarization/Gatekeeper rejects it. --deep is omitted on purpose so the
# already-valid nested signatures (Sparkle, bins) are preserved, not overwritten.
codesign --force --options runtime --timestamp \
    --entitlements "$APP_ENTITLEMENTS" \
    --sign "$APP_SIGN_IDENTITY" \
    "$APP_PATH"
echo -e "  ${GREEN}✓${NC} All binaries and app signed"

#
# 4. Copy app to pkg root
#
echo -e "${YELLOW}[4/7]${NC} Preparing package contents..."
cp -R "$APP_PATH" "$PKG_ROOT/Applications/"
echo -e "  ${GREEN}✓${NC} App staged for packaging"

#
# 5. Build component package
#
echo -e "${YELLOW}[5/7]${NC} Building component package..."

# Make scripts executable
chmod +x "$INSTALLER_DIR/scripts/postinstall"

pkgbuild --root "$PKG_ROOT" \
    --identifier "com.wilkebakker.thedownloader" \
    --version "1.0" \
    --scripts "$INSTALLER_DIR/scripts" \
    --install-location "/" \
    --sign "$PKG_SIGN_IDENTITY" \
    "$BUILD_DIR/TheDownloader.pkg"

echo -e "  ${GREEN}✓${NC} Component package created and signed"

#
# 6. Build product archive (with license and welcome)
#
echo -e "${YELLOW}[6/7]${NC} Building installer package..."

# Create resources directory
mkdir -p "$BUILD_DIR/resources"
cp "$INSTALLER_DIR/welcome.html" "$BUILD_DIR/resources/"
cp "$INSTALLER_DIR/LICENSE.txt" "$BUILD_DIR/resources/"
cp "$INSTALLER_DIR/conclusion.html" "$BUILD_DIR/resources/"

productbuild --distribution "$INSTALLER_DIR/distribution.xml" \
    --resources "$BUILD_DIR/resources" \
    --package-path "$BUILD_DIR" \
    --sign "$PKG_SIGN_IDENTITY" \
    "$BUILD_DIR/TheDownloader-Installer.pkg"

echo -e "  ${GREEN}✓${NC} Installer package created and signed"

#
# 7. Create DMG with installer
#
echo -e "${YELLOW}[7/7]${NC} Creating DMG..."

mkdir -p "$BUILD_DIR/dmg_contents"
cp "$BUILD_DIR/TheDownloader-Installer.pkg" "$BUILD_DIR/dmg_contents/"
cp "$INSTALLER_DIR/LICENSE.txt" "$BUILD_DIR/dmg_contents/License.txt"

# Create README
cat > "$BUILD_DIR/dmg_contents/README.txt" << 'EOF'
THE DOWNLOADER - Installation Instructions
==========================================

1. Double-click "TheDownloader-Installer.pkg" to start the installer
2. Follow the on-screen instructions
3. Accept the license agreement
4. The app will be installed to /Applications and added to Login Items

After installation, look for the download icon in your menu bar!

For support or feedback, visit: https://github.com/wilkebakker/thedownloader
EOF

hdiutil create -volname "THE DOWNLOADER" \
    -srcfolder "$BUILD_DIR/dmg_contents" \
    -ov -format UDZO \
    "$BUILD_DIR/TheDownloader.dmg" 2>/dev/null

echo -e "  ${GREEN}✓${NC} DMG created"

# Copy final outputs to project directory
mkdir -p "$OUTPUT_DIR"
cp "$BUILD_DIR/TheDownloader-Installer.pkg" "$OUTPUT_DIR/"
cp "$BUILD_DIR/TheDownloader.dmg" "$OUTPUT_DIR/"

#
# Summary
#
echo ""
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo ""
echo "Output files:"
echo -e "  ${GREEN}PKG Installer:${NC} $OUTPUT_DIR/TheDownloader-Installer.pkg"
echo -e "  ${GREEN}DMG:${NC}           $OUTPUT_DIR/TheDownloader.dmg"
echo ""
echo "Bundled dependencies:"
ls -lh "$BUNDLE_DIR/" 2>/dev/null | grep -v "^total" | awk '{print "  " $9 " (" $5 ")"}'
echo ""
echo -e "${BLUE}Distribution:${NC}"
echo "  Share TheDownloader.dmg - users double-click the PKG inside"
echo ""
echo -e "${BLUE}What users get:${NC}"
echo "  • Welcome screen with feature overview"
echo "  • License agreement (must accept to continue)"
echo "  • Auto-install to /Applications"
echo "  • Auto-add to Login Items (opens at startup)"
echo "  • App launches after installation"
echo ""
