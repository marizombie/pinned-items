#!/usr/bin/env bash
# Rebuilds Pinned and restarts it, so a code change is in the menu bar in one
# command. Adapted from ../must-rest/scripts/run-app.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_NAME="Pinned"
EXECUTABLE_NAME="PinnedItems"
APP_DIR="$ROOT_DIR/.build/${APP_NAME}.app"

if pkill -x "$EXECUTABLE_NAME" >/dev/null 2>&1; then
    echo "Stopping the running ${APP_NAME}..."
    for _ in $(seq 1 50); do
        pgrep -x "$EXECUTABLE_NAME" >/dev/null 2>&1 || break
        sleep 0.1
    done
    if pgrep -x "$EXECUTABLE_NAME" >/dev/null 2>&1; then
        echo "${APP_NAME} did not quit. Quit it and rerun." >&2
        exit 1
    fi
fi

(cd "$ROOT_DIR" && "$SCRIPT_DIR/make-app.sh")

open -n "$APP_DIR"
echo "Opened $APP_DIR"
