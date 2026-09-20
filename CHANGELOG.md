# Changelog

## 0.8.1 - 2026-09-20

- Make the live tray lifecycle test preserve the user's original collapsed or
  expanded state, including restoration after a failed assertion.
- Guarantee that shortcut backups are written completely before a personal
  Hyprland binding is changed; cover a large backup and exact backup contents.
- Document the public-API boundary for third-party bar-widget compatibility.
- Put producer-side deadlines on both output collectors and create the
  simulated blocked state with an explicit private directory mode.

## 0.8.0 - 2026-09-20

- Add an explicit, reversible `Super+Alt+C` Crunch-menu shortcut with conflict
  detection, private backup, atomic writes, Hyprland validation and rollback.
- Add shortcut installation/removal and native topbar visibility to the Crunch
  menu; keep Omarchy's existing `Super+Shift+Space` binding authoritative.
- Mirror Omarchy's `bar-off` state with a smooth parked-surface transition, so
  hiding the replacement bar removes its exclusion zone without rebuilding it.
- Double-click anywhere on the topbar to persistently fade its background
  between solid and transparent without stealing normal widget clicks.

## 0.7.4 - 2026-09-20

- Fix a collector lifecycle race: queue a replacement request until the
  cancelled process has exited and discard its stale result/error.
- Wait for stored widget settings on startup; keep the configured weather city
  visible during loading/errors and retry failures after a minute, not fifteen.
- Reconfirming the same location refreshes immediately. Saving a location
  during layout editing persists it independently of draft widget positions.
- Add subprocess lifecycle, cancellation, retry, timeout, same-city refresh and
  fresh-session location persistence regressions.

## 0.7.3 - 2026-09-20

- Add direct Wallpaper and Theme root-menu entries using the native Omarchy
  `background` and `theme` routes, matching Super+Ctrl+Space and
  Super+Shift+Ctrl+Space. Menu accelerators are B and H respectively.
- Resolve menu actions and submenu arrows by entry identity instead of row
  number; keep Widgets return selection correct when entries are inserted.
- Close the root menu before launching a native picker to hand over focus.

## 0.7.2 - 2026-09-20

- Accept drops slightly outside the thin plugin strip while it owns the pointer
  grab. Previously a small vertical deviation silently rejected the entire move.
- Add diagonal/overshoot regressions alongside far-away cancellation tests and
  live pointer diagnostics to distinguish input, cancellation and persistence.

## 0.7.1 - 2026-09-20

- Add a compact `Crunch #!` heading beside the native Omarchy logo, aligned
  with the menu labels. Keep the Widgets page label and existing menu behavior.

## 0.7.0 - 2026-09-20

- Right-click the plugin shelf handle to arrange third-party widgets by drag
  and drop; click the checkmark to finish without changing the pin preference.
- Show an insertion marker and animate the move, with edge autoscroll on
  narrow bars. Dropping outside cancels; normal plugin gestures stay intact.
- Persist a shared order atomically in plugin-owned state, preserve disabled
  entries, append new plugins, and roll back with visible feedback on failure.
- Preserve mounted widget instances and align panel navigation with the new
  order. Test mouse gestures, cancellation, multiple monitors, fresh-store
  reload, registry changes, overflow and failed writes.

## 0.6.3 - 2026-09-20

- Replace the desktop menu's `#! OMACRUNCH` heading with the native Omarchy
  logo, aligned with the menu shortcut column, and remove the `ROOT` label.
- Keep the Widgets page label for navigation and call the wallpaper's
  right-click action simply `menu`. Plugin identity and saved state stay intact.

## 0.6.2 - 2026-09-20

- Dock the plugin shelf directly against the right-hand status section.
- Reveal widgets leftward from a stationary rightmost handle; keep both
  handle and popout-anchor coordinates stable during the animation.
- Assert right alignment and stable reveal/collapse geometry in UI/live tests.

## 0.6.1 - 2026-09-20

- Fix clicking empty/uncreated workspaces: pass the dispatcher expression
  without a duplicate `dispatch` prefix and respect Hyprland's Lua mode.
- Preserve native activation for existing workspaces. Cover absent/existing
  workspace routing, legacy mode and invalid IDs with regression tests.

## 0.6.0 - 2026-09-20

- Host configured external bar widgets in a separate, centered plugin shelf.
- Add a stationary subtle hover handle, animated reveal, delayed hide and
  per-monitor session pinning. Open panels hold their anchor in place.
- Preserve registry components, scoped APIs, existing order/settings and live
  widget instances across hide/reveal and settings-only changes.
- Add overflow navigation, popout/target cleanup and native-style tooltips.
- Test real hover/click gestures, pinning, panel hold, API scoping, settings
  updates, overflow and removal in an isolated offscreen Quickshell instance.
- Document Omarchy's service-less replacement-bar facade limitation instead
  of bypassing it or claiming universal third-party compatibility.
- Support older/dev host contracts with a local bar facade and own-plugin-only
  service adapter; validate both the active dev shell and installed shell.

## 0.5.0 - 2026-09-20

- Add a Widgets submenu with per-monitor visibility for System Monitor,
  Weather, Agent Usage, Disk Usage and Calendar.
- Add an explicit layout editor with drag handles, 8px snapping, bounded
  normalized positions, Save, Cancel and Reset positions.
- Persist layouts atomically outside the installed plugin so updates retain them.
- Analyze wallpaper contrast independently for each additional widget.
- Share bounded, deadline-limited collectors across monitors, only when enabled.
- Show actual local agent records, filesystem capacity, current-month dates,
  and opt-in Open-Meteo conditions/forecast with explicit location and stale states.

## 0.4.7 - 2026-09-20

- Clip Omarchy's native hover-chevron slot out of the composed tray before
  drawing Omacrunch's animated disclosure control.
- Preserve the native icon coordinates and translucent bar background while
  guaranteeing that only one direction indicator can be visible.
- Keep the battery indicator icon-only by default, matching the equally compact
  network and volume indicators; its native right-click percentage toggle
  remains available when an explicit readout is useful.

## 0.4.6 - 2026-09-20

- Replace the swapping tray characters with one vector chevron that rotates
  smoothly toward the direction of the next action.
- Animate tray width and icon opacity with coordinated easing, plus a subtle
  hover response on the disclosure control.
- Extend the live tray lifecycle proof to verify the settled width and arrow
  rotation after both collapse and expansion.

## 0.4.5 - 2026-09-20

- Update an existing local test installation in place instead of removing and
  re-adding the active replacement bar.
- Keep the layer-shell exclusive zone stable during `make local-test`, avoiding
  transient double-resizes that can leave Chromium/Electron Wayland clients
  with an unpainted strip until their next workspace redraw.
- Refuse to overwrite an installation whose Git origin is not this checkout.

## 0.4.4 - 2026-09-20

- Accept both ImageMagick `#RRGGBB` and `#RRGGBBAA` pixel output so wallpapers
  with an alpha channel complete spatial contrast analysis.
- Clear the previous wallpaper's tone map as soon as a new analysis starts;
  pending or failed analysis now falls back to guaranteed light-on-dark widget
  surfaces instead of retaining potentially invisible ink.
- Require the complete bounded 12-by-18 sample before publishing new tones.

## 0.4.3 - 2026-09-20

- Replace the historical `#!` menu mark with Omarchy's own logo glyph, keeping
  the host desktop visibly credited while the surrounding experience remains
  CrunchBang++ inspired.
- Turn workspace applications into a compact icon strip without nested card
  padding, and mark the active application with a restrained two-pixel rule.
- Replace per-label light/dark switching and noisy text outlines with reusable
  header, metrics and shortcut surfaces. Each future desktop widget now picks
  one consistent ink tone and adds only the local contrast floor its wallpaper
  region needs.

## 0.4.2 - 2026-09-20

- Turn the tray chevron into a real disclosure control instead of leaving the
  upstream hover-only button visible beside an already pinned tray.
- Left-click now collapses or expands the complete tray icon cluster, with a
  directional `‹`/`›` state; right-click still opens native tray management.
- Add a live tray lifecycle proof to `make local-test`.

## 0.4.1 - 2026-09-20

- Remove the large adaptive backdrop that turned mixed wallpapers into a grey
  rectangle behind the monitor.
- Give text, sparklines, progress bars and dividers a wallpaper-aware local
  contrast halo, preserving legibility over light/dark split imagery without
  hiding the wallpaper.
- Analyze a bounded spatial grid and choose tones independently for the left
  and right sides of the header, metrics and shortcut block; graphs blend
  between both local tones instead of drawing a harsh global outline.
- Strengthen secondary labels now that their contrast no longer depends on a
  shared translucent surface.

## 0.4.0 - 2026-09-20

- Replace the deliberately empty bar provider with a 30-pixel CrunchBang++
  top panel on every monitor.
- Add a Tint2-style workspace/taskbar hybrid: five persistent desktops,
  per-workspace application icons, focused and urgent states, direct window
  activation, middle-click close and wheel workspace navigation.
- Reuse Omarchy's native tray, network, audio, power and clock components so
  their complete panels remain available behind the minimal topbar.
- Pin active tray icons, show battery percentage, use a compact `HH:mm` clock
  and preserve native calendar, mixer, network and power-profile interactions.
- Add deterministic workspace-model tests and runtime proofs for bar geometry,
  native status-widget loading and panel routing.

## 0.3.2 - 2026-09-19

- Use neutral light and dark telemetry ink instead of potentially clashing
  theme accent colours.
- Calculate scrim opacity from the contrast target after compositing, using
  the 5th and 95th percentile wallpaper luminance.
- Choose the ink-and-veil pairing that meets the contrast target with the
  least wallpaper coverage, with a regression palette for fiery backgrounds.

## 0.3.1 - 2026-09-19

- Replace the compositor-dependent Canvas sampler with a bounded 16-colour
  histogram of the exact wallpaper region behind the monitor.
- Expose the sampler's readiness over IPC and make the local runtime test fail
  unless real wallpaper pixels were analyzed.
- Give wallpaper analysis a five-second process deadline and rerun it whenever
  Omarchy changes the active background.

## 0.3.0 - 2026-09-19

- Sample the actual wallpaper pixels beneath the system monitor and choose the
  higher-contrast light or dark theme colour.
- Add a restrained adaptive scrim for wallpapers whose local tones are too
  mixed for one text colour to remain legible.
- Refresh contrast analysis automatically after theme or wallpaper changes.
- Release exclusive keyboard focus after a short map-time prime.
- Ignore menu accelerators when Control, Alt or Meta is held.
- Make the local runtime test prove an open-to-closed menu lifecycle so it
  cannot leave an invisible input-capturing surface behind.

## 0.2.2 - 2026-09-19

- Fix replacement-bar construction by providing defaults for properties that
  Omarchy injects only after the QML Loader has created the component.
- Make `local-test` detect a silent fallback to the stock Omarchy bar.
- Add a regression test for the replacement-bar loader contract.

## 0.2.1 - 2026-09-19

- Wait for the asynchronous Omarchy plugin reload before probing the service
  during `make local-test`.
- Report a bounded, actionable readiness timeout instead of a transient
  `Target not found` failure.

## 0.2.0 - 2026-09-19

- Replace the launcher-centric prototype with a persistent desktop experience.
- Replace the stock bar with a deliberately barless provider.
- Add live wallpaper telemetry for CPU, memory, load, network and uptime.
- Add per-monitor system identity, clock, date, shortcut hints and graphs.
- Add a compact right-click root menu integrated with native Omarchy menus.
- Add deterministic parser tests and a runtime IPC health check.

## 0.1.0 - 2026-09-19

- Retracted: this version was a launcher prototype and did not represent the
  intended CrunchBang desktop experience.
- Add the `#!` Omarchy bar widget.
- Add a keyboard-first CrunchBang-inspired command deck.
- Add fixed-argument launch actions for standard Omarchy tools.
- Add local installation, update, removal and Omakit QA documentation.
