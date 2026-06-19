#!/bin/bash
set -euo pipefail

# Build and package Vigil as a signed, notarized DMG for distribution,
# with Sparkle auto-update support.
#
# Vigil is an SPM-only project (no .xcodeproj), so we build with
# swift build and manually assemble the .app bundle, including
# embedding Sparkle.framework from the SPM binary artifact.
#
# Prerequisites:
#   brew install create-dmg gh
#   gh auth login
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
mkdir -p "$APP_BUNDLE/Contents/Frameworks"

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

# ── Embed Sparkle.framework ─────────────────────────────────────
SPARKLE_XCFW="$PROJECT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework"
SPARKLE_SOURCE="$SPARKLE_XCFW/macos-arm64_x86_64/Sparkle.framework"
if [ -d "$SPARKLE_SOURCE" ]; then
    echo "==> Embedding Sparkle.framework..."
    cp -R "$SPARKLE_SOURCE" "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
else
    echo "WARNING: Sparkle.framework not found at $SPARKLE_SOURCE"
    echo "  Run 'swift package resolve' first."
fi

# Verify the binary exists in the app bundle
if [ ! -f "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ]; then
    echo "Error: App bundle created but the binary is missing!"
    exit 1
fi

# ── Code signing ──────────────────────────────────────────────────
APP_PATH="$APP_BUNDLE"
if [ -n "$IDENTITY" ]; then
    echo "==> Signing embedded frameworks and helpers..."
    SPARKLE_FW="$APP_PATH/Contents/Frameworks/Sparkle.framework"
    if [ -d "$SPARKLE_FW" ]; then
        # Sign XPC services (innermost first)
        for xpc in "$SPARKLE_FW"/Versions/B/XPCServices/*.xpc; do
            [ -d "$xpc" ] && codesign --force --options runtime --sign "$IDENTITY" --timestamp "$xpc"
        done
        # Sign helper apps
        for app in "$SPARKLE_FW"/Versions/B/*.app; do
            [ -d "$app" ] && codesign --force --options runtime --sign "$IDENTITY" --timestamp "$app"
        done
        # Sign standalone executables
        for bin in "$SPARKLE_FW"/Versions/B/Autoupdate; do
            [ -f "$bin" ] && codesign --force --options runtime --sign "$IDENTITY" --timestamp "$bin"
        done
        # Sign the framework itself
        codesign --force --options runtime --sign "$IDENTITY" --timestamp "$SPARKLE_FW"
    fi

    echo "==> Signing app with: $IDENTITY"
    codesign --force --options runtime \
        --sign "$IDENTITY" \
        --timestamp \
        --entitlements "$PROJECT_DIR/Vigil.entitlements" \
        "$APP_PATH"
    echo "==> Verifying signature..."
    codesign --verify --verbose=2 --deep "$APP_PATH"
    echo "    Signature OK"
else
    echo "==> Ad-hoc signing..."
    codesign --force --deep --sign - "$APP_PATH"
fi

# ── Verify universal binary ──────────────────────────────────────
echo "==> Verifying universal binary..."
ARCHS=$(lipo -archs "$APP_PATH/Contents/MacOS/$APP_NAME" 2>/dev/null || echo "unknown")
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
    ICON_PATH="$APP_PATH/Contents/Resources/AppIcon.icns"
    VOL_ICON_FLAG=""
    if [ -f "$ICON_PATH" ]; then
        VOL_ICON_FLAG="--volicon $ICON_PATH"
    fi

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

# ── Sparkle update archive + appcast ────────────────────────────
echo "==> Creating Sparkle update archive..."
SPARKLE_BUILD_DIR="$PROJECT_DIR/build/sparkle"
rm -rf "$SPARKLE_BUILD_DIR"
mkdir -p "$SPARKLE_BUILD_DIR"

ZIP_NAME="Vigil-${VERSION}-b${NEW_BUILD}.zip"
ZIP_PATH="$SPARKLE_BUILD_DIR/$ZIP_NAME"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
echo "  Archive: $ZIP_PATH"

GENERATE_APPCAST="$PROJECT_DIR/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"
if [ -x "$GENERATE_APPCAST" ]; then
    echo "==> Generating appcast..."
    "$GENERATE_APPCAST" "$SPARKLE_BUILD_DIR"
    echo "  Appcast: $SPARKLE_BUILD_DIR/appcast.xml"
else
    echo "WARNING: generate_appcast not found at $GENERATE_APPCAST"
    echo "  Run 'swift package resolve' first, then re-run this script."
fi

# ── Stage appcast to website ─────────────────────────────────────
WWW_UPDATES="$PROJECT_DIR/../www/static/updates/vigil"
if [ -d "$PROJECT_DIR/../www" ]; then
    mkdir -p "$WWW_UPDATES"
    [ -f "$SPARKLE_BUILD_DIR/appcast.xml" ] && cp -f "$SPARKLE_BUILD_DIR/appcast.xml" "$WWW_UPDATES/"
    echo "  Appcast staged to: $WWW_UPDATES/appcast.xml"
fi

# ── Cleanup ──────────────────────────────────────────────────────
rm -rf "$STAGING_DIR"

echo ""
echo "Done!"
echo "  DMG:      $DMG_PATH ($(ls -lh "$DMG_PATH" | awk '{print $5}'))"
echo "  ZIP:      $ZIP_PATH (for Sparkle auto-update)"
echo "  Version:  $VERSION (build $NEW_BUILD)"
echo "  Arch:     $ARCHS"
if [ -n "$IDENTITY" ]; then
    echo "  Signed:   $IDENTITY"
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

# ── Git tag + push ───────────────────────────────────────────────
TAG="v${VERSION}-b${NEW_BUILD}"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git add "$PLIST"
    git commit -m "Build $NEW_BUILD for v$VERSION distribution" 2>/dev/null || true
    git tag -a "$TAG" -m "$APP_NAME $VERSION build $NEW_BUILD"
    echo "  Tagged: $TAG"
    echo "==> Pushing to remote..."
    git push && git push --tags
fi

# ── GitHub Release ───────────────────────────────────────────────
if command -v gh >/dev/null 2>&1; then
    echo "==> Creating GitHub release..."
    PREV_TAG=$(git tag --sort=-v:refname | grep -v "^$TAG$" | head -1)
    RELEASE_NOTES=""
    if [ -n "$PREV_TAG" ]; then
        RELEASE_NOTES=$(git log --pretty=format:"- %s" "$PREV_TAG".."$TAG" -- . ':!Info.plist' ':!Resources/Info.plist' | grep -v "^- Build [0-9]")
    fi
    if [ -z "$RELEASE_NOTES" ]; then
        RELEASE_NOTES="Vigil $VERSION build $NEW_BUILD"
    fi

    NOTES_BODY="## What's New

$RELEASE_NOTES

## Install

Download **$DMG_NAME**, open it, and drag Vigil to your Applications folder.

Existing users with auto-update enabled will receive this update automatically via Sparkle."

    REPO_SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner)

    gh release create "$TAG" "$DMG_PATH" "$ZIP_PATH" \
        --title "Vigil $VERSION (build $NEW_BUILD)" \
        --notes "$NOTES_BODY" \
        && echo "  Release: https://github.com/$REPO_SLUG/releases/tag/$TAG" \
        || echo "  WARNING: GitHub release creation failed."

    # Rewrite appcast enclosure URL to point at GitHub Releases
    GITHUB_ZIP_URL="https://github.com/$REPO_SLUG/releases/download/$TAG/$ZIP_NAME"
    if [ -f "$WWW_UPDATES/appcast.xml" ]; then
        sed -i '' "s|url=\"[^\"]*$ZIP_NAME\"|url=\"$GITHUB_ZIP_URL\"|" "$WWW_UPDATES/appcast.xml"
        echo "  Appcast URL rewritten to: $GITHUB_ZIP_URL"
    fi
else
    echo "  gh CLI not found — skipping GitHub release. Install with: brew install gh"
fi

# ── Website deploy reminder ──────────────────────────────────────
echo ""
if [ -d "$WWW_UPDATES" ]; then
    echo "Next: cd ../www && git add -A && git commit -m \"Vigil $VERSION build $NEW_BUILD\" && git push"
fi
