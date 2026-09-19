# Changelog

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
