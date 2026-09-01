# Twitcher

Twitcher is a native macOS menu-bar window switcher. Press `Option+Delete` to list open windows, select one, and type a letter to assign it. Press `Option+letter` from anywhere to focus that window.

## Build

```sh
chmod +x scripts/package-app.sh
scripts/package-app.sh
open dist/Twitcher.app
```

Run the dependency-free core checks with `swift run TwitcherCoreChecks`.

On first launch, grant Twitcher access in **System Settings → Privacy & Security → Accessibility**. If the permission prompt does not appear automatically, use **Open Accessibility Settings…** from the menu-bar icon. Relaunch Twitcher after enabling access.

Assignments are restored using a window's application and document URL when available, or its exact title otherwise. A shortcut does nothing if the saved identity matches multiple current windows.
