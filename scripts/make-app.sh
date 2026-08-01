#!/bin/sh
set -eu

APP_NAME="Pinned"
EXECUTABLE_NAME="PinnedItems"
APP_DIR=".build/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

mkdir -p ".build/module-cache" ".build/swiftpm-cache"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_HOME="$PWD/.build/swiftpm-cache"
swift build --disable-sandbox -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp ".build/release/${EXECUTABLE_NAME}" "${MACOS_DIR}/${EXECUTABLE_NAME}"
cp "Info.plist" "${CONTENTS_DIR}/Info.plist"
printf "APPL????" > "${CONTENTS_DIR}/PkgInfo"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_DIR"
fi

echo "Created ${APP_DIR}"
