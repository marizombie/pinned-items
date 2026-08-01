#!/bin/sh
set -eu

APP_NAME="Pinned"
DMG_NAME="Pinned.dmg"
STAGING_DIR=".build/dmg"
DMG_PATH=".build/${DMG_NAME}"

./scripts/make-app.sh

rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R ".build/${APP_NAME}.app" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "Created ${DMG_PATH}"
