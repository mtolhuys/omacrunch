# Changelog

## 0.4.1 - 2026-09-20

- Remove the large adaptive backdrop that turned mixed wallpapers into a grey
  rectangle behind the monitor.
- Give text, sparklines, progress bars and dividers a wallpaper-aware local
  contrast halo, preserving legibility over light/dark split imagery without
  hiding the wallpaper.
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
