#!/bin/zsh
# MisiQC Pro — Release builder
# ---------------------------------------------------------------------------
# Builds, signs, notarizes and zips the app — ready to upload to Payhip.
#
# Usage:
#   ./scripts/release.sh 1.0.0
#
# Prerequisites (one-time setup):
#   1. Apple Developer ID Application certificate installed in Keychain
#   2. App-specific password stored as a Keychain profile:
#        xcrun notarytool store-credentials AC_NOTARY \
#            --apple-id "contact@misiraca.com" \
#            --team-id "XXXXXXXXXX" \
#            --password "abcd-efgh-ijkl-mnop"
#   3. (Optional) Sparkle's sign_update tool available — installed by the
#      Sparkle SPM package.
#
# Outputs (in build/release/):
#   MisiQC-Pro-<version>.zip          — notarized + stapled + zipped
#   MisiQC-Pro-<version>.sparkle.txt  — Sparkle signature & length (if Sparkle present)

set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 1.0.0"
  exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

PROJECT="MisiQC.xcodeproj"
SCHEME="MisiQC"
# Xcode product name is "MisiQC" — we rename the bundle to "MisiQC Pro" for
# end-user distribution so it shows up nicely in Applications and the Dock.
XCODE_APP_NAME="MisiQC"
DIST_APP_NAME="MisiQC Pro"
NOTARY_PROFILE="AC_NOTARY"

ARCHIVE_DIR="build/MisiQC.xcarchive"
EXPORT_DIR="build/export"
RELEASE_DIR="build/release"
APP_PATH="$EXPORT_DIR/$XCODE_APP_NAME.app"
DIST_APP_PATH="$EXPORT_DIR/$DIST_APP_NAME.app"
ZIP_PATH="$RELEASE_DIR/MisiQC-Pro-$VERSION.zip"
DMG_PATH="$RELEASE_DIR/MisiQC-Pro-$VERSION.dmg"
DMG_STAGING="build/dmg-staging"
DMG_VOLUME="MisiQC Pro $VERSION"
SIG_PATH="$RELEASE_DIR/MisiQC-Pro-$VERSION.sparkle.txt"

mkdir -p "$RELEASE_DIR" "build"
rm -rf "$ARCHIVE_DIR" "$EXPORT_DIR"

# 1. Bump CFBundleShortVersionString in build settings
echo "→ Setting MARKETING_VERSION=$VERSION"
xcrun agvtool new-marketing-version "$VERSION" >/dev/null
xcrun agvtool next-version -all >/dev/null

# 2. Archive (Release config, Developer ID signed)
echo "→ Archiving (xcodebuild archive)…"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_DIR" \
  -destination 'generic/platform=macOS' \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \

if [[ ! -d "$ARCHIVE_DIR" ]]; then
  echo "✗ Archive failed — check Xcode signing settings."
  exit 1
fi

# 3. Export .app
echo "→ Exporting .app"
cat > "$EXPORT_DIR.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>manual</string>
</dict>
</plist>
EOF
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_DIR" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_DIR.plist" \

if [[ ! -d "$APP_PATH" ]]; then
  echo "✗ Export failed — no $APP_PATH"
  exit 1
fi

# 4. Rename for end-user distribution (folder rename does not invalidate
#    the codesign signature — only modifying contents would).
echo "→ Renaming bundle to '$DIST_APP_NAME.app' for distribution"
rm -rf "$DIST_APP_PATH"
mv "$APP_PATH" "$DIST_APP_PATH"

# 4b. Re-sign ffmpeg + ffprobe with hardened runtime — the upstream
#     evermeet.cx binaries ship without the runtime flag which causes
#     Apple notarization to reject the bundle. Re-signing the inner CLIs
#     invalidates the outer signature, so we re-sign the whole .app after.
echo "→ Hardening ffmpeg + ffprobe + re-signing app bundle"
CERT="Developer ID Application: matthieu misiraca (SM6L2XLUBA)"
ENTITLEMENTS="MisiQC/MisiQC.entitlements"
codesign --force --options runtime --timestamp \
    --sign "$CERT" "$DIST_APP_PATH/Contents/Resources/ffmpeg"
codesign --force --options runtime --timestamp \
    --sign "$CERT" "$DIST_APP_PATH/Contents/Resources/ffprobe"
codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" --sign "$CERT" "$DIST_APP_PATH"
codesign --verify --deep --strict "$DIST_APP_PATH"

# 5. Notarize
echo "→ Submitting to Apple notarization (may take a few minutes)…"
ditto -c -k --keepParent "$DIST_APP_PATH" "/tmp/MisiQC-Pro-notarize.zip"
xcrun notarytool submit "/tmp/MisiQC-Pro-notarize.zip" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait
rm -f "/tmp/MisiQC-Pro-notarize.zip"

# 6. Staple the ticket
echo "→ Stapling notarization ticket"
xcrun stapler staple "$DIST_APP_PATH"
xcrun stapler validate "$DIST_APP_PATH"

# 7. Zip the final bundle (for Sparkle updates — Sparkle prefers .zip)
echo "→ Creating distribution zip"
ditto -c -k --keepParent "$DIST_APP_PATH" "$ZIP_PATH"

# 7b. DMG with Applications shortcut (for Payhip customer download)
echo "→ Creating DMG with Applications shortcut"
rm -rf "$DMG_STAGING" "$DMG_PATH"
mkdir -p "$DMG_STAGING"
cp -R "$DIST_APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create \
  -volname "$DMG_VOLUME" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"
rm -rf "$DMG_STAGING"
codesign --force --sign "$CERT" --timestamp "$DMG_PATH"
echo "→ Submitting DMG for notarization (5-10 min)…"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

# 8. Sparkle signature — use our own script so we don't depend on Sparkle
#    being installed. The private key lives in scripts/output/.
if [[ -f "scripts/output/sparkle_private_key.dat" ]]; then
  echo "→ Sparkle signature (for appcast.xml)"
  SPARKLE_LINE=$(swift scripts/sign_update.swift "$ZIP_PATH")
  echo "$SPARKLE_LINE" > "$SIG_PATH"
  echo "  ✓ $SPARKLE_LINE"
  echo "  ✓ Saved at $SIG_PATH"
else
  echo "  (No Sparkle key found — run scripts/generate_sparkle_keys.swift first)"
fi

# 9. Summary
ZIP_SIZE=$(stat -f%z "$ZIP_PATH")
ZIP_SHA=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
DMG_SIZE=$(stat -f%z "$DMG_PATH")
DMG_SHA=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')

echo ""
echo "============================================================"
echo "✅ Release $VERSION ready."
echo ""
echo "  DMG (for Payhip customer download):"
echo "    File:    $DMG_PATH"
echo "    Size:    $DMG_SIZE bytes"
echo "    SHA-256: $DMG_SHA"
echo ""
echo "  ZIP (for Sparkle auto-update):"
echo "    File:    $ZIP_PATH"
echo "    Size:    $ZIP_SIZE bytes"
echo "    SHA-256: $ZIP_SHA"
echo ""
echo "Next steps:"
echo "  • Upload $DMG_PATH to Payhip → Product → Files"
echo "  • Upload scripts/output/keys.csv to Payhip → Product → License Keys (one-time)"
echo "  • Upload scripts/output/MisiQC-Pro-Guide-Installation.pdf alongside the DMG"
echo "  • (Sparkle) Add a new <item> to appcast.xml pointing at the ZIP with $ZIP_SHA"
echo "============================================================"
