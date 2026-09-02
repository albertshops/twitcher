# Twitcher

Twitcher is a native macOS menu-bar program switcher. Press `Option+Delete` to list programs with open windows, select one, and type a letter to assign it. Programs with multiple windows also show window rows that can have their own letters. Press a program shortcut repeatedly to cycle through its unassigned windows, or press a window shortcut to focus that window directly.

## Build

```sh
chmod +x scripts/package-app.sh
scripts/package-app.sh
open dist/Twitcher.app
```

Run the dependency-free core checks with `swift run TwitcherCoreChecks`.

On first launch, grant Twitcher access in **System Settings → Privacy & Security → Accessibility**. If the permission prompt does not appear automatically, use **Open Accessibility Settings…** from the menu-bar icon. Relaunch Twitcher after enabling access.

Program assignments are restored using the program's bundle identifier. Window assignments use the document URL when the program exposes one, falling back to the window title; Twitcher beeps if the saved window is closed or cannot be matched uniquely.
