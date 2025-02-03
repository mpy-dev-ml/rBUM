#!/bin/bash

# Script to install and code sign the ResticService XPC service

set -e

# Configuration
APP_NAME="rBUM"
XPC_SERVICE_NAME="ResticService"
TEAM_ID="YOUR_TEAM_ID" # Replace with your Apple Developer Team ID
APP_BUNDLE_ID="dev.mpy.rBUM"
XPC_BUNDLE_ID="dev.mpy.rBUM.ResticService"

# Paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Helper functions
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check requirements
if ! command -v codesign &> /dev/null; then
    error "codesign command not found"
fi

# Find the app bundle
find_app_bundle() {
    local search_dir="$1"
    find "$search_dir" -name "*.app" -type d | grep -i "$APP_NAME" || true
}

# Find XPC service bundle
find_xpc_bundle() {
    local search_dir="$1"
    find "$search_dir" -name "*.xpc" -type d | grep -i "$XPC_SERVICE_NAME" || true
}

# Main installation process
main() {
    info "Starting installation of $XPC_SERVICE_NAME XPC service..."

    # Find the app bundle
    APP_BUNDLE=$(find_app_bundle "$BUILD_DIR")
    if [ -z "$APP_BUNDLE" ]; then
        APP_BUNDLE=$(find_app_bundle "$DERIVED_DATA")
    fi
    
    if [ -z "$APP_BUNDLE" ]; then
        error "Could not find $APP_NAME.app bundle"
    fi
    info "Found app bundle at: $APP_BUNDLE"

    # Find the XPC service bundle
    XPC_BUNDLE=$(find_xpc_bundle "$BUILD_DIR")
    if [ -z "$XPC_BUNDLE" ]; then
        XPC_BUNDLE=$(find_xpc_bundle "$DERIVED_DATA")
    fi
    
    if [ -z "$XPC_BUNDLE" ]; then
        error "Could not find $XPC_SERVICE_NAME.xpc bundle"
    fi
    info "Found XPC service bundle at: $XPC_BUNDLE"

    # Create XPCServices directory if it doesn't exist
    XPC_SERVICES_DIR="$APP_BUNDLE/Contents/XPCServices"
    mkdir -p "$XPC_SERVICES_DIR"

    # Copy XPC service to app bundle
    XPC_DEST="$XPC_SERVICES_DIR/$(basename "$XPC_BUNDLE")"
    info "Copying XPC service to: $XPC_DEST"
    rm -rf "$XPC_DEST"
    cp -R "$XPC_BUNDLE" "$XPC_DEST"

    # Code sign XPC service
    info "Code signing XPC service..."
    codesign --force --sign "Developer ID Application: $TEAM_ID" \
             --entitlements "$PROJECT_ROOT/$XPC_SERVICE_NAME/$XPC_SERVICE_NAME.entitlements" \
             "$XPC_DEST"

    # Verify code signing
    info "Verifying code signing..."
    codesign --verify --verbose "$XPC_DEST"

    # Code sign app bundle
    info "Code signing app bundle..."
    codesign --force --sign "Developer ID Application: $TEAM_ID" \
             --entitlements "$PROJECT_ROOT/$APP_NAME/$APP_NAME.entitlements" \
             "$APP_BUNDLE"

    # Verify app bundle
    info "Verifying app bundle..."
    codesign --verify --verbose "$APP_BUNDLE"

    info "Installation complete!"
    info "XPC service installed at: $XPC_DEST"
}

# Run the installation
main
