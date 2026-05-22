#!/bin/bash
set -e

# =============================================
# wpsite installer
# Usage: curl -fsSL https://raw.githubusercontent.com/<user>/wpsite/main/install.sh | bash
#        wget -qO- https://raw.githubusercontent.com/<user>/wpsite/main/install.sh | bash
# =============================================

REPO="${REPO:-onian-org/wpsite}"
BRANCH="${BRANCH:-main}"
VERSION="${VERSION:-latest}"
INSTALL_DIR="${INSTALL_DIR:-}"

# Colors (if available)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    CYAN=''
    NC=''
fi

echo -e "${CYAN}Installing wpsite...${NC}"
echo ""

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Darwin|Linux) ;;
    *)
        echo -e "${RED}Error: Unsupported OS: $OS${NC}"
        echo "wpsite supports macOS and Linux only."
        exit 1
        ;;
esac

echo -e "  ${YELLOW}OS:${NC} $OS"
echo -e "  ${YELLOW}Arch:${NC} $ARCH"
echo ""

# Determine install directory
if [ -z "$INSTALL_DIR" ]; then
    if [ -d "$HOME/.local/bin" ] && echo "$PATH" | grep -q "$HOME/.local/bin"; then
        INSTALL_DIR="$HOME/.local/bin"
    elif [ -w "/usr/local/bin" ]; then
        INSTALL_DIR="/usr/local/bin"
    else
        INSTALL_DIR="$HOME/.local/bin"
        mkdir -p "$INSTALL_DIR"
    fi
fi

# Determine download URL
if [ "$VERSION" = "latest" ]; then
    DOWNLOAD_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/wpsite"
    CHECKSUM_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/wpsite.sha256"
else
    DOWNLOAD_URL="https://raw.githubusercontent.com/${REPO}/v${VERSION}/wpsite"
    CHECKSUM_URL="https://raw.githubusercontent.com/${REPO}/v${VERSION}/wpsite.sha256"
fi

# Download function
download() {
    if command -v curl &> /dev/null; then
        curl -fsSL "$1"
    elif command -v wget &> /dev/null; then
        wget -qO- "$1"
    else
        echo -e "${RED}Error: Neither curl nor wget found. Install one of them first.${NC}"
        exit 1
    fi
}

# Download script
echo -e "${YELLOW}Downloading wpsite...${NC}"
TMP_FILE=$(mktemp)
trap "rm -f $TMP_FILE" EXIT

if ! download "$DOWNLOAD_URL" > "$TMP_FILE" 2>/dev/null; then
    echo -e "${RED}Error: Failed to download wpsite from ${DOWNLOAD_URL}${NC}"
    exit 1
fi

if [ ! -s "$TMP_FILE" ]; then
    echo -e "${RED}Error: Downloaded file is empty${NC}"
    exit 1
fi

# Verify checksum if available
if command -v sha256sum &> /dev/null; then
    SHA_CMD="sha256sum"
elif command -v shasum &> /dev/null; then
    SHA_CMD="shasum -a 256"
else
    SHA_CMD=""
fi

if [ -n "$SHA_CMD" ]; then
    echo -e "${YELLOW}Verifying checksum...${NC}"
    EXPECTED_HASH=$(download "$CHECKSUM_URL" 2>/dev/null | awk '{print $1}' || true)
    if [ -n "$EXPECTED_HASH" ]; then
        ACTUAL_HASH=$($SHA_CMD "$TMP_FILE" | awk '{print $1}')
        if [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
            echo -e "${RED}Error: Checksum verification failed${NC}"
            echo "  Expected: $EXPECTED_HASH"
            echo "  Actual:   $ACTUAL_HASH"
            exit 1
        fi
        echo -e "  ${GREEN}✓ Checksum verified${NC}"
    else
        echo -e "  ${YELLOW}⚠ No checksum file found, skipping verification${NC}"
    fi
fi

# Make executable
chmod +x "$TMP_FILE"

# Install
INSTALL_PATH="${INSTALL_DIR}/wpsite"
if ! mv "$TMP_FILE" "$INSTALL_PATH" 2>/dev/null; then
    echo -e "${YELLOW}sudo required to install to ${INSTALL_DIR}...${NC}"
    sudo mv "$TMP_FILE" "$INSTALL_PATH"
fi

echo ""
echo -e "${GREEN}✓ wpsite installed successfully!${NC}"
echo ""
echo -e "  ${CYAN}Location:${NC} ${INSTALL_PATH}"
echo -e "  ${CYAN}Version:${NC} $($INSTALL_PATH --version 2>/dev/null || echo "unknown")"
echo ""
echo -e "  ${YELLOW}Quick start:${NC}"
echo "    wpsite infra install    # Set up Docker infrastructure"
echo "    wpsite infra start      # Start MariaDB, Traefik, phpMyAdmin"
echo "    wpsite dns setup        # Configure local DNS for .test domains"
echo "    wpsite create my-site   # Create your first WordPress site"
echo ""
echo -e "  ${YELLOW}Help:${NC}    wpsite help"