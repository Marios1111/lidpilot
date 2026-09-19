# LidPilot design comparison

Open `index.html` directly in a browser. It also works through any local static server. All assets are local; there are no dependencies, trackers, external fonts, or network requests.

The four directions use the same simulated mode/session state so their hierarchy can be compared. Change a mode or duration in any preview to update all four. Use the toolbar to inspect Off, Active, Starting, Paused, Unverified, Recovery required, or closed-lid examples. Start briefly shows Starting; Turn Off cancels the pending simulated activation.

**Explore** opens a larger popover and matching settings window. The settings button in each popover opens that direction's settings directly. General, Sessions, Protection, and Updates controls are interactive local examples. The favourite button marks a choice only in this page; tell Codex the number/name to confirm the direction.

This is a visual decision artifact, not the native application. No helper is installed, no hardware is sampled, no real update check runs, and no power or system preference changes. “Confirmed” and “Available” are sample UI states. The clock is a static preview, not a real session countdown. Internal-panel shutdown and native inactivity dimming remain hardware validation gates.

Settings layouts deliberately share native macOS conventions; the four main alternatives concern the everyday popover. Final app/menu-bar icon artwork remains provisional.

Browser verification on 19 September 2026: inspected the rendered light/dark popovers and settings in the Codex browser, including 935px and 390px viewports with no horizontal overflow. Exercised mode synchronization, preset/custom/until/indefinite controls, invalid duration blocking, Start→Off cancellation, paused/recovery details, settings navigation and toggles, and Escape dismissal with focus restoration. Custom duration entry updates the visible clock without replacing the active input. Browser console contained no errors or warnings; `node --check design/preview.js` passed. These are prototype checks, not native-app or hardware validation.
