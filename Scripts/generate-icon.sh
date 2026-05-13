#!/bin/bash
set -euo pipefail

# Generate Vigil's app icon (.icns) from either:
#   1. A provided 1024x1024 source PNG
#   2. The built-in Swift icon generator (if no source provided)
#
# Usage:
#   ./Scripts/generate-icon.sh                    # generate icon programmatically
#   ./Scripts/generate-icon.sh path/to/icon.png   # use a custom source image

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

SOURCE_PNG="${1:-}"
ICONSET_DIR="$PROJECT_DIR/.build/AppIcon.iconset"
OUTPUT_ICNS="$PROJECT_DIR/Resources/AppIcon.icns"

# ── Generate source PNG if not provided ──────────────────────────
if [ -z "$SOURCE_PNG" ]; then
    SOURCE_PNG="$PROJECT_DIR/.build/vigil-icon-1024.png"
    echo "==> Generating icon with Swift..."
    swift "$SCRIPT_DIR/generate-icon.swift" "$SOURCE_PNG"
fi

if [ ! -f "$SOURCE_PNG" ]; then
    echo "Error: Source PNG not found at $SOURCE_PNG"
    echo "Usage: $0 [path/to/icon-1024.png]"
    echo ""
    echo "The source image should be 1024x1024 pixels."
    exit 1
fi

# ── Generate all required sizes ──────────────────────────────────
echo "==> Generating icon sizes..."

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
mkdir -p "$(dirname "$OUTPUT_ICNS")"

sips -z 16 16     "$SOURCE_PNG" --out "$ICONSET_DIR/icon_16x16.png"      > /dev/null
sips -z 32 32     "$SOURCE_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png"  > /dev/null
sips -z 32 32     "$SOURCE_PNG" --out "$ICONSET_DIR/icon_32x32.png"      > /dev/null
sips -z 64 64     "$SOURCE_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png"  > /dev/null
sips -z 128 128   "$SOURCE_PNG" --out "$ICONSET_DIR/icon_128x128.png"    > /dev/null
sips -z 256 256   "$SOURCE_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
sips -z 256 256   "$SOURCE_PNG" --out "$ICONSET_DIR/icon_256x256.png"    > /dev/null
sips -z 512 512   "$SOURCE_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
sips -z 512 512   "$SOURCE_PNG" --out "$ICONSET_DIR/icon_512x512.png"    > /dev/null
sips -z 1024 1024 "$SOURCE_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null

# ── Create .icns ─────────────────────────────────────────────────
echo "==> Creating .icns..."

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"

# ── Cleanup ──────────────────────────────────────────────────────
rm -rf "$ICONSET_DIR"

echo ""
echo "Icon created at: $OUTPUT_ICNS"
echo "Size: $(ls -lh "$OUTPUT_ICNS" | awk '{print $5}')"
