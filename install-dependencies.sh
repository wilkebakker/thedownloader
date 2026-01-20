#!/bin/bash
#
# THE DOWNLOADER - Dependency Installer
# Checks for and installs: Homebrew, yt-dlp, ffmpeg
#
# Usage: ./install-dependencies.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       THE DOWNLOADER - Setup Script        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to get Homebrew path (Apple Silicon or Intel)
get_brew_path() {
    if [[ -x "/opt/homebrew/bin/brew" ]]; then
        echo "/opt/homebrew/bin/brew"
    elif [[ -x "/usr/local/bin/brew" ]]; then
        echo "/usr/local/bin/brew"
    else
        echo ""
    fi
}

# Track what was installed
INSTALLED=()
ALREADY_INSTALLED=()

#
# 1. Check/Install Homebrew
#
echo -e "${YELLOW}[1/3]${NC} Checking Homebrew..."

BREW_PATH=$(get_brew_path)

if [[ -n "$BREW_PATH" ]]; then
    echo -e "  ${GREEN}✓${NC} Homebrew is installed at $BREW_PATH"
    ALREADY_INSTALLED+=("Homebrew")
else
    echo -e "  ${RED}✗${NC} Homebrew not found"
    echo ""
    read -p "Install Homebrew? (y/n) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "  ${BLUE}→${NC} Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add to path for this session
        if [[ -x "/opt/homebrew/bin/brew" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
            BREW_PATH="/opt/homebrew/bin/brew"
        elif [[ -x "/usr/local/bin/brew" ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
            BREW_PATH="/usr/local/bin/brew"
        fi

        INSTALLED+=("Homebrew")
        echo -e "  ${GREEN}✓${NC} Homebrew installed"
    else
        echo -e "  ${RED}✗${NC} Homebrew is required. Please install manually."
        exit 1
    fi
fi

# Ensure brew is in PATH for this script
if [[ -n "$BREW_PATH" ]]; then
    eval "$($BREW_PATH shellenv)"
fi

#
# 2. Check/Install yt-dlp
#
echo ""
echo -e "${YELLOW}[2/3]${NC} Checking yt-dlp..."

if command_exists yt-dlp; then
    YT_DLP_PATH=$(which yt-dlp)
    YT_DLP_VERSION=$(yt-dlp --version 2>/dev/null || echo "unknown")
    echo -e "  ${GREEN}✓${NC} yt-dlp $YT_DLP_VERSION is installed at $YT_DLP_PATH"
    ALREADY_INSTALLED+=("yt-dlp")
else
    echo -e "  ${RED}✗${NC} yt-dlp not found"
    echo -e "  ${BLUE}→${NC} Installing yt-dlp via Homebrew..."
    brew install yt-dlp
    INSTALLED+=("yt-dlp")
    echo -e "  ${GREEN}✓${NC} yt-dlp installed"
fi

#
# 3. Check/Install ffmpeg
#
echo ""
echo -e "${YELLOW}[3/3]${NC} Checking ffmpeg..."

if command_exists ffmpeg; then
    FFMPEG_PATH=$(which ffmpeg)
    FFMPEG_VERSION=$(ffmpeg -version 2>/dev/null | head -n1 | awk '{print $3}' || echo "unknown")
    echo -e "  ${GREEN}✓${NC} ffmpeg $FFMPEG_VERSION is installed at $FFMPEG_PATH"
    ALREADY_INSTALLED+=("ffmpeg")
else
    echo -e "  ${RED}✗${NC} ffmpeg not found"
    echo -e "  ${BLUE}→${NC} Installing ffmpeg via Homebrew..."
    brew install ffmpeg
    INSTALLED+=("ffmpeg")
    echo -e "  ${GREEN}✓${NC} ffmpeg installed"
fi

#
# Summary
#
echo ""
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo ""

if [[ ${#INSTALLED[@]} -gt 0 ]]; then
    echo -e "Newly installed:"
    for item in "${INSTALLED[@]}"; do
        echo -e "  ${GREEN}+${NC} $item"
    done
    echo ""
fi

if [[ ${#ALREADY_INSTALLED[@]} -gt 0 ]]; then
    echo -e "Already installed:"
    for item in "${ALREADY_INSTALLED[@]}"; do
        echo -e "  ${GREEN}✓${NC} $item"
    done
    echo ""
fi

# Show paths
echo "Tool locations:"
echo -e "  yt-dlp:  $(which yt-dlp 2>/dev/null || echo 'not found')"
echo -e "  ffmpeg:  $(which ffmpeg 2>/dev/null || echo 'not found')"
echo ""

echo -e "${GREEN}THE DOWNLOADER is ready to use!${NC}"
echo ""

#
# Optional: Update yt-dlp
#
read -p "Update yt-dlp to latest version? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}→${NC} Updating yt-dlp..."
    yt-dlp -U || brew upgrade yt-dlp 2>/dev/null || true
    echo -e "${GREEN}✓${NC} yt-dlp updated"
fi

echo ""
echo "Done!"
