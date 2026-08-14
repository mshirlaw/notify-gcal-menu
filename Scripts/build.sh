#!/bin/bash
# Builds the Swift package and assembles it into a launchable NotifyGCalMenu.app bundle,
# since `swift build` alone only produces a bare executable (no Info.plist, no bundle ID
# for notification/keychain permissions, no place for the bundled Secrets.plist resource).
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIGURATION="${1:-debug}"
BUNDLE_ID="com.notifygcalmenu.menu"
APP_NAME="NotifyGCalMenu"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Building ($CONFIGURATION)..."
swift build -c "$CONFIGURATION"
BIN_PATH="$(swift build -c "$CONFIGURATION" --show-bin-path)"

echo "Assembling $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp Info.plist "$APP_BUNDLE/Contents/Info.plist"
cp AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# The git tag is the version source of truth (see README, "Cutting a Release"), so the
# tracked Info.plist keeps a placeholder and the real version is stamped into the bundle's
# copy at build time — no version-bump commit needed before tagging a release. Both keys
# move together since Sparkle (once wired up) compares CFBundleVersion for update checks.
if [ -n "${MARKETING_VERSION:-}" ]; then
    echo "Stamping version $MARKETING_VERSION..."
    plutil -replace CFBundleShortVersionString -string "$MARKETING_VERSION" "$APP_BUNDLE/Contents/Info.plist"
    plutil -replace CFBundleVersion -string "$MARKETING_VERSION" "$APP_BUNDLE/Contents/Info.plist"
fi

RESOURCE_BUNDLE="$BIN_PATH/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
else
    echo "Warning: resource bundle not found at $RESOURCE_BUNDLE (Secrets.plist won't load)" >&2
fi

echo "Codesigning (ad hoc)..."
codesign --force --deep --identifier "$BUNDLE_ID" -s - "$APP_BUNDLE"

echo "Done: $APP_BUNDLE"

if [ "$CONFIGURATION" = "release" ]; then
    INSTALLED_APP="/Applications/$APP_NAME.app"
    LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

    echo "Installing to $INSTALLED_APP..."
    if pkill -f "$INSTALLED_APP/Contents/MacOS/$APP_NAME" 2>/dev/null; then
        # Wait for the old process to fully exit before relaunching under the same bundle
        # ID/path — launching too soon after can cause macOS to misdirect a leftover quit
        # Apple Event at the new process instead of the one it was meant for.
        for _ in $(seq 1 20); do
            pgrep -f "$INSTALLED_APP/Contents/MacOS/$APP_NAME" >/dev/null 2>&1 || break
            sleep 0.2
        done
    fi
    rm -rf "$INSTALLED_APP"
    cp -R "$APP_BUNDLE" "$INSTALLED_APP"
    "$LSREGISTER" -f "$INSTALLED_APP"

    echo "Launching $INSTALLED_APP..."
    open "$INSTALLED_APP"
else
    echo "Run it with: open \"$APP_BUNDLE\""
fi
