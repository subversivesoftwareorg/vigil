#!/bin/bash
set -euo pipefail

# Build and package Vigil as a signed, notarized DMG for distribution.
#
# Vigil is an SPM-only project (no .xcodeproj), so we build with
# swift build and manually assemble the .app bundle.
#
# Prerequisites (optional):
#   brew install create-dmg    (for styled DMG with drag-to-install layout)
#
# Environment variables (optional — prompted if missing):
#   APPLE_ID        — your Apple ID email for notarization
#   TEAM_ID         — your Apple Developer team ID (default: 84CC987JU3)
#   APP_PASSWORD    — app-specific password for notarytool
#
# Usage:
#   ./Scripts/create-dmg.sh                   # full build + sign + notarize
#   ./Scripts/create-dmg.sh --skip-notarize   # build + sign only

APP_NAME="Vigil"
BINARY_NAME="Vigil"
BUNDLE_ID="com.subversivesoftware.vigil"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/apple/Products/Release"
STAGING_DIR="$PROJECT_DIR/.build/dmg-staging"
NOTARIZE_TIMEOUT="15m"

# ── Auto-increment build number ──────────────────────────────────
# Read current build number from Info.plist and increment it.
# This ensures every DMG has a unique version so builds are never
# confused with each other and notarized DMGs can't be overwritten.
PLIST="$PROJECT_DIR/Resources/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")
NEW_BUILD=$((CURRENT_BUILD + 1))
echo "==> Incrementing build number: $CURRENT_BUILD → $NEW_BUILD"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$PLIST"

DMG_NAME="Vigil-${VERSION}-b${NEW_BUILD}.dmg"
DMG_PATH="$PROJECT_DIR/build/$DMG_NAME"

SKIP_NOTARIZE=false
if [ "${1:-}" = "--skip-notarize" ]; then
    SKIP_NOTARIZE=true
fi

# ── Find Developer ID certificate ────────────────────────────────
IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')
if [ -z "$IDENTITY" ]; then
    echo "Error: No 'Developer ID Application' certificate found in keychain."
    if [ "$SKIP_NOTARIZE" = true ]; then
        echo "Continuing with ad-hoc signing..."
        IDENTITY=""
    else
        exit 1
    fi
fi

# ── Notarization credentials ─────────────────────────────────────
if [ "$SKIP_NOTARIZE" = false ] && [ -n "$IDENTITY" ]; then
    TEAM_ID="${TEAM_ID:-84CC987JU3}"

    if [ -z "${APPLE_ID:-}" ]; then
        printf "Apple ID (email) for notarization: "
        read -r APPLE_ID
    fi
    if [ -z "${APP_PASSWORD:-}" ]; then
        printf "App-specific password: "
        stty -echo
        read -r APP_PASSWORD
        stty echo
        echo ""
    fi
fi

# ── Build (Universal) ────────────────────────────────────────────
echo "==> Building $APP_NAME v$VERSION build $NEW_BUILD (Release, Universal: arm64 + x86_64)..."
cd "$PROJECT_DIR"
swift build -c release --arch arm64 --arch x86_64

# Verify the binary actually exists (catches silent build failures)
if [ ! -f "$BUILD_DIR/$BINARY_NAME" ]; then
    echo "Error: Build failed — $BINARY_NAME not found at $BUILD_DIR"
    exit 1
fi

# ── Create app bundle ────────────────────────────────────────────
echo "==> Creating app bundle..."
APP_BUNDLE="$STAGING_DIR/$APP_NAME.app"
rm -rf "$STAGING_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/$BINARY_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy app icon
if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

# Copy resource bundles (SPM puts .bundle dirs in the build output)
for bundle in "$BUILD_DIR"/*.bundle; do
    [ -e "$bundle" ] && cp -R "$bundle" "$APP_BUNDLE/Contents/Resources/"
done

# Copy Info.plist (single source of truth with updated build number)
cp "$PLIST" "$APP_BUNDLE/Contents/Info.plist"

# Verify the binary exists in the app bundle
if [ ! -f "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ]; then
    echo "Error: App bundle created but the binary is missing!"
    exit 1
fi

# ── Code signing ──────────────────────────────────────────────────
if [ -n "$IDENTITY" ]; then
    echo "==> Signing with: $IDENTITY"
    codesign --force --options runtime \
        --sign "$IDENTITY" \
        --timestamp \
        "$APP_BUNDLE"
    echo "==> Verifying signature..."
    codesign --verify --verbose=2 "$APP_BUNDLE"
    echo "    Signature OK"
else
    echo "==> Ad-hoc signing..."
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

# ── Verify universal binary ──────────────────────────────────────
echo "==> Verifying universal binary..."
ARCHS=$(lipo -archs "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null || echo "unknown")
echo "    Architectures: $ARCHS"
if echo "$ARCHS" | grep -q "arm64" && echo "$ARCHS" | grep -q "x86_64"; then
    echo "    Universal binary OK"
else
    echo "    Warning: Expected universal binary (arm64 x86_64), got: $ARCHS"
fi

# ── Create DMG ───────────────────────────────────────────────────
echo "==> Creating DMG..."
mkdir -p "$(dirname "$DMG_PATH")"
rm -f "$DMG_PATH"

if command -v create-dmg >/dev/null 2>&1; then
    ICON_PATH="$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    VOL_ICON_FLAG=""
    if [ -f "$ICON_PATH" ]; then
        VOL_ICON_FLAG="--volicon $ICON_PATH"
    fi

    # create-dmg often exits non-zero even on success (e.g., exit 2
    # when background image positioning fails). Tolerate that as long
    # as the DMG file is actually produced.
    create-dmg \
        --volname "$APP_NAME" \
        $VOL_ICON_FLAG \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 175 190 \
        --app-drop-link 425 190 \
        --hide-extension "$APP_NAME.app" \
        "$DMG_PATH" \
        "$STAGING_DIR" \
        || true
    if [ ! -f "$DMG_PATH" ]; then
        echo "Error: create-dmg failed to produce $DMG_NAME"
        exit 1
    fi
else
    ln -sf /Applications "$STAGING_DIR/Applications"
    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$STAGING_DIR" \
        -ov \
        -format UDZO \
        "$DMG_PATH"
fi

# Sign the DMG
if [ -n "$IDENTITY" ]; then
    codesign --force --sign "$IDENTITY" --timestamp "$DMG_PATH"
fi

# ── Notarize ─────────────────────────────────────────────────────
if [ "$SKIP_NOTARIZE" = false ] && [ -n "$IDENTITY" ]; then
    echo "==> Submitting for notarization (timeout: ${NOTARIZE_TIMEOUT})..."
    if xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "$APP_PASSWORD" \
        --wait \
        --timeout "$NOTARIZE_TIMEOUT"; then

        echo "==> Stapling..."
        xcrun stapler staple "$DMG_PATH"

        echo "==> Verifying notarization..."
        spctl --assess --type open --context context:primary-signature "$DMG_PATH" && echo "    Notarization OK" || echo "    Warning: spctl check failed (may need to retry)"
    else
        echo ""
        echo "WARNING: Notarization did not complete within ${NOTARIZE_TIMEOUT}."
        echo "Check status: xcrun notarytool history --apple-id $APPLE_ID --team-id $TEAM_ID --password YOUR_PASSWORD"
        echo "Then staple:  xcrun stapler staple $DMG_PATH"
    fi
fi

# ── Cleanup ──────────────────────────────────────────────────────
rm -rf "$STAGING_DIR"

echo ""
echo "Done! DMG created at:"
echo "  $DMG_PATH"
echo "  Version: $VERSION (build $NEW_BUILD)"
echo "  Size: $(ls -lh "$DMG_PATH" | awk '{print $5}')"
echo "  Architectures: $ARCHS"
if [ -n "$IDENTITY" ]; then
    echo "  Signed with: $IDENTITY"
    if [ "$SKIP_NOTARIZE" = false ]; then
        echo "  Notarized and stapled"
    else
        echo "  NOT notarized (--skip-notarize)"
    fi
else
    echo "  WARNING: Unsigned — users will see Gatekeeper warnings"
fi

echo ""
echo "Build number $NEW_BUILD has been written to Resources/Info.plist."
echo "Remember to commit this change if you want to keep it."
