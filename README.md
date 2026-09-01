# Twitcher

Twitcher is a native macOS menu-bar program switcher. Press `Option+Delete` to list programs with open windows, select one, and type a letter to assign it. Press `Option+letter` from anywhere to focus that program. Press the same shortcut repeatedly to cycle through all of its windows.

## Build

```sh
chmod +x scripts/package-app.sh
scripts/package-app.sh
open dist/Twitcher.app
```

Run the dependency-free core checks with `swift run TwitcherCoreChecks`.

On first launch, grant Twitcher access in **System Settings → Privacy & Security → Accessibility**. If the permission prompt does not appear automatically, use **Open Accessibility Settings…** from the menu-bar icon. Relaunch Twitcher after enabling access.

Assignments are restored using the program's bundle identifier and continue to work when its windows or titles change.
