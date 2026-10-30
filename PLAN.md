# Visor implementation plan

- [x] Swift Package project builds and launches
- [x] Run as a regular macOS app with Dock, Force Quit, and Command-Q support
- [x] Top-pinned full-width panel below the menu bar
- [x] Customizable global show/hide shortcut (Option–Space by default)
- [x] Focus terminal when summoned
- [x] Live PTY-backed login shell
- [x] Persistent in-memory shell tabs
- [x] Add and close tabs
- [x] Green-on-black theme
- [x] Saved opacity, font size, and panel height
- [x] Bottom-edge panel resize handle
- [x] Replace the native ANSI subset with xterm.js VT emulation
- [x] Preserve per-tab scrollback when switching tabs
- [ ] Add tab reordering (deferred; fixed tabs are more reliable)
- [x] Add saved SSH connection bookmarks
- [x] Add shortcut rebinding
- [x] Lock the panel to a selected display and recover when that display disconnects
- [x] Allow automatic hiding to be disabled in Settings
- [x] Refresh SSH-derived tab names when a remote session ends
- [ ] Add accessibility labels and keyboard-only tab management
- [x] Package a locally signed `.app`
- [ ] Sign the release with Developer ID and notarize it
- [ ] Complete version 1.0 release QA

The original product plan is preserved conceptually, but this checklist reflects what the repository actually implements.
