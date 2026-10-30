# Visor for macOS

Visor is a lightweight drop-down terminal for macOS with its own Dock and Finder icon. Press **Option–Space** to smoothly show or hide a full-width terminal panel below the menu bar. Clicking outside Visor hides it automatically. Shell processes remain alive while the panel is hidden.

Visor is currently a prerelease app. Version 1.0 release preparation, signing, and notarization are in progress.

## Run it

Requirements: macOS 14 or later and Xcode 16 or later.

```sh
swift run Visor
```

On first launch, the panel opens automatically. Visor appears in the Dock and macOS Force Quit window; use Command-Q or the Visor application menu to quit. Use the plus button in the top bar for a new shell. Each tab keeps its own complete terminal state, including alternate-screen programs such as Vim, `less`, and remote SSH tools. When you run `ssh` in a shell tab, the tab adopts the destination device name and returns to its previous name when the SSH session ends. Add saved SSH connections from the slim SSH bookmark bar, then click a bookmark to connect. Right-click a bookmark to edit or delete it. Visor stores host, user, port, and identity-file path; passwords and key passphrases stay with SSH. Open Settings to record a different global show/hide shortcut, disable automatic hiding, or lock Visor to a specific connected display. Drag the thin handle at the bottom to resize the panel.

Visor supports normal macOS Command-C, Command-V, Command-A, and Command-K shortcuts. Paste uses terminal bracketed-paste mode when the active shell or remote program requests it. Keyboard modes, modified keys, mouse reporting, binary terminal input, Unicode input, true color, resizing, and terminal bells are handled by the bundled xterm-compatible terminal engine.

## Build and test

Build a release executable:

```sh
swift build -c release
```

The binary is written to `.build/release/Visor`.

Run the test suite:

```sh
swift test
```

To make a locally signed app you can open from Finder:

```sh
./scripts/build-app.sh
open outputs/Visor.app
```

## Project status

The app includes a customizable global shortcut, persistent shell and SSH sessions, saved SSH bookmarks, independent terminal state per tab, multi-display placement, configurable auto-hide, panel sizing, translucency, and a green-on-black terminal. Terminal input and VT rendering use a locally bundled xterm.js runtime.

The remaining version 1.0 work is tracked in [PLAN.md](PLAN.md). Distribution signing and notarization require an Apple Developer Program signing identity and are intentionally separate from local development builds.

## Third-party software

The bundled terminal renderer is based on xterm.js. Its license and the fit add-on license are included with the vendored resources in `Sources/Visor/Resources/vendor/`.
