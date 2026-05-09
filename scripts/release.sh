#!/usr/bin/env bash
# Usage: ./scripts/release.sh <version>
# Example: ./scripts/release.sh 1.0.1
#
# Requires:
#   - Apple Developer Program membership with a Developer ID Application cert in Keychain
#   - `xcrun notarytool store-credentials <profile>` run once (default profile name: cursa-notary)
#   - `gh` CLI installed and authenticated (brew install gh && gh auth login)
#   - Sparkle SPM dependency resolved (run `xcodebuild -resolvePackageDependencies` once)
#
# Env vars:
#   NOTARY_PROFILE  Override the notarytool keychain profile name (default: cursa-notary)
#
# What it does:
#   1. Bumps MARKETING_VERSION + CURRENT_PROJECT_VERSION
#   2. Archives, exports with Developer ID, notarizes, staples
#   3. Zips the .app for distribution
#   4. Signs the zip with Sparkle's sign_update
#   5. Creates a GitHub Release with the zip as an asset
#   6. Appends an <item> entry to docs/appcast.xml
#   7. Commits the version bump + appcast and pushes

set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 <version>" >&2
    echo "Example: $0 1.0.1" >&2
    exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Version must be semver (e.g. 1.0.1), got: $VERSION" >&2
    exit 1
fi

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

SCHEME="cursa"
APP_NAME="Cursa"
GH_REPO="TWilson023/cursa"
NOTARY_PROFILE="${NOTARY_PROFILE:-cursa-notary}"
BUILD_DIR="$PROJECT_ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/cursa.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
ZIP_PATH="$BUILD_DIR/$APP_NAME-$VERSION.zip"

# Locate Sparkle's sign_update tool inside the Xcode SPM artifacts cache.
SIGN_UPDATE=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name sign_update -type f 2>/dev/null | head -1)
if [[ -z "$SIGN_UPDATE" ]]; then
    echo "sign_update not found in DerivedData. Run:" >&2
    echo "  xcodebuild -project cursa.xcodeproj -resolvePackageDependencies" >&2
    exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI not found. Install with: brew install gh && gh auth login" >&2
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Working tree is dirty. Commit or stash changes before releasing." >&2
    exit 1
fi

echo "==> Cleaning build directory"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Bumping version to $VERSION"
# Replace MARKETING_VERSION and CURRENT_PROJECT_VERSION in the pbxproj.
# Keeping them in sync for v1; split later if you want a separate build number.
sed -i '' \
    -e "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $VERSION;/g" \
    -e "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = $VERSION;/g" \
    cursa.xcodeproj/project.pbxproj

echo "==> Archiving"
xcodebuild -project cursa.xcodeproj \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    archive

echo "==> Exporting with Developer ID"
cat > "$BUILD_DIR/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist"

APP_PATH="$EXPORT_DIR/cursa.app"
if [[ ! -d "$APP_PATH" ]]; then
    echo "Exported app not found at $APP_PATH" >&2
    exit 1
fi

echo "==> Zipping for notarization"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "==> Submitting to notary (this may take a few minutes)"
xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "$APP_PATH"

echo "==> Re-zipping stapled app"
rm "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "==> Signing zip with Sparkle"
SPARKLE_OUTPUT=$("$SIGN_UPDATE" "$ZIP_PATH")
echo "    $SPARKLE_OUTPUT"

ED_SIG=$(echo "$SPARKLE_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')
LENGTH=$(echo "$SPARKLE_OUTPUT" | sed -n 's/.*length="\([^"]*\)".*/\1/p')

if [[ -z "$ED_SIG" || -z "$LENGTH" ]]; then
    echo "Could not parse sign_update output: $SPARKLE_OUTPUT" >&2
    exit 1
fi

DOWNLOAD_URL="https://github.com/$GH_REPO/releases/download/v$VERSION/$APP_NAME-$VERSION.zip"
PUB_DATE=$(LC_TIME=en_US.UTF-8 date "+%a, %d %b %Y %H:%M:%S %z")
MIN_SYS=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$APP_PATH/Contents/Info.plist")

echo "==> Appending entry to docs/appcast.xml"
python3 - <<PY
import pathlib, html
item = '''        <item>
            <title>Version $VERSION</title>
            <pubDate>$PUB_DATE</pubDate>
            <sparkle:version>$VERSION</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>$MIN_SYS</sparkle:minimumSystemVersion>
            <enclosure url="$DOWNLOAD_URL" sparkle:edSignature="$ED_SIG" length="$LENGTH" type="application/octet-stream"/>
        </item>
'''
p = pathlib.Path("docs/appcast.xml")
text = p.read_text()
text = text.replace("    </channel>", item + "    </channel>")
p.write_text(text)
PY

echo "==> Creating GitHub release"
LATEST_ZIP="$BUILD_DIR/Cursa.zip"
cp "$ZIP_PATH" "$LATEST_ZIP"
gh release create "v$VERSION" "$ZIP_PATH" "$LATEST_ZIP" \
    --repo "$GH_REPO" \
    --title "Cursa $VERSION" \
    --notes "Release $VERSION"

echo "==> Committing version bump + appcast"
git add docs/appcast.xml cursa.xcodeproj/project.pbxproj
git commit -m "Release v$VERSION"
git push

echo ""
echo "Done. Release v$VERSION published:"
echo "  $DOWNLOAD_URL"
echo ""
echo "GitHub Pages will serve the new appcast within ~1 minute:"
echo "  https://twilson023.github.io/cursa/appcast.xml"
