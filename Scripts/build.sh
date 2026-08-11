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

RESOURCE_BUNDLE="$BIN_PATH/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
else
    echo "Warning: resource bundle not found at $RESOURCE_BUNDLE (Secrets.plist won't load)" >&2
fi

# SwiftPM has no "Embed Frameworks" build phase, so Sparkle.framework has to be copied in
# by hand and the executable given an rpath pointing at it, or dyld can't find it at
# launch. Both must happen before codesigning: install_name_tool invalidates signatures.
SPARKLE_FRAMEWORK="$BIN_PATH/Sparkle.framework"
if [ -d "$SPARKLE_FRAMEWORK" ]; then
    mkdir -p "$APP_BUNDLE/Contents/Frameworks"
    ditto "$SPARKLE_FRAMEWORK" "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
else
    echo "Error: Sparkle.framework not found at $SPARKLE_FRAMEWORK; the app links it and will not launch" >&2
    exit 1
fi

echo "Codesigning (ad hoc)..."
# Sign inside-out: nested code first, container last. --deep is deliberately not used to
# sign. It re-signs nested code with this command's --identifier, which would stamp
# com.notifygcalmenu.menu over Sparkle's own org.sparkle-project.* identifiers — and
# Sparkle looks its installer XPC service up by identifier, so updates would download and
# then fail to install. (--deep remains correct for *verifying*, below.)
SPARKLE_BUNDLED="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
codesign --force -s - "$SPARKLE_BUNDLED/Versions/B/XPCServices/Downloader.xpc"
codesign --force -s - "$SPARKLE_BUNDLED/Versions/B/XPCServices/Installer.xpc"
codesign --force -s - "$SPARKLE_BUNDLED/Versions/B/Updater.app"
codesign --force -s - "$SPARKLE_BUNDLED/Versions/B/Autoupdate"
codesign --force -s - "$SPARKLE_BUNDLED"
codesign --force --identifier "$BUNDLE_ID" -s - "$APP_BUNDLE"
codesign --verify --strict --deep "$APP_BUNDLE"

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
