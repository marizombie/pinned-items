# Pinned

A small macOS menu bar app for keeping important files and folders one click away.

macOS does not provide a public API for third-party apps to rewrite another app's Dock menu. Pinned gives you the practical version of that workflow: a native status bar menu that shows pins for the currently active app, plus global pins that are always visible.

## Features

- Pin files or folders to the currently active app.
- Pin files or folders globally.
- Open pinned files and folders from the menu bar.
- Remove pins from the menu.
- Stores pins locally at `~/Library/Application Support/PinnedItems/pins.json`.

## Safety

- No network access is used.
- No Accessibility, Automation, screen recording, or admin permission is requested.
- The app does not inject into other apps or modify their menus.
- Pins are local file URLs selected by you through the standard macOS file picker.
- Missing pinned items show an alert instead of trying to open a stale path silently.

When running, the app appears as a pin icon in the macOS menu bar.

## Build

```sh
swift build -c release
./scripts/make-app.sh
```

The app bundle will be created at:

```text
.build/Pinned.app
```

Open it with:

```sh
open ".build/Pinned.app"
```

## DMG

```sh
./scripts/make-dmg.sh
open ".build/Pinned.dmg"
```

Drag `Pinned.app` to `Applications`, then launch it from there.

## Notes

Pins scoped to an app appear when that app is frontmost. For example, pins created while VS Code is active appear in the `Pinned for Visual Studio Code` section when VS Code is the active app.
