# Omacrunch

Omacrunch turns the Omarchy shell into a complete CrunchBang++-inspired
desktop. It is not a launcher skin: it changes the persistent desktop
experience while keeping Omarchy's native Hyprland and Quickshell stack.

Version `0.6.0` provides:

- a flat, translucent, 30-pixel topbar on every monitor;
- a Tint2-style workspace/taskbar hybrid with five persistent workspaces;
- application icons inside their owning workspace, including focused and
  urgent states, direct activation and middle-click close;
- wheel navigation over the workspace strip;
- pinned system-tray icons and Omarchy's complete native network, audio,
  battery/power-profile and calendar panels;
- a smooth, direction-aware tray disclosure: left-click animates the icon
  cluster and rotates toward its next destination, while right-click opens
  native tray management;
- a compact `HH:mm` clock and a calm icon-only battery indicator by default;
- a separate hover-reveal shelf for configured third-party bar widgets;
- live CPU, memory, load, network and uptime telemetry over the wallpaper;
- compact history graphs, host information, clock, date and shortcut hints;
- one telemetry surface per monitor;
- wallpaper-aware foreground selection based on the pixels beneath the monitor;
- spatially adaptive widget surfaces that keep one clean ink tone per module
  and add only the local contrast floor required by the wallpaper;
- a sharp, monochrome root menu on right-click;
- theme-derived bar colours plus wallpaper-derived monitor contrast;
- optional Weather, Agent Usage, Disk Usage and Calendar desktop widgets;
- per-monitor widget layouts with drag handles, snapping, Save and Cancel;
- no extra background daemon or privileged commands.

The topbar, wallpaper telemetry and root menu form one desktop experience.
There is no second panel daemon and no Openbox compatibility layer.

## Architecture

The manifest exposes three cooperating Quattro plugin kinds:

- `bar` — replaces the stock bar with a CrunchBang++ workspace taskbar and
  hosts Omarchy's existing status-panel components;
- `service` — reads Linux `/proc` data every two seconds and renders the
  desktop overlay below application windows;
- `menu` — supplies the right-click root menu and delegates to the standard
  Omarchy application, style, keybinding and power menus.

No Openbox, Tint2 or Conky process is introduced. Omacrunch recreates their
roles inside the existing Omarchy shell instead of running a second desktop
stack beside it. Network selection, the audio mixer, power profiles, the
calendar and tray menus remain the native Omarchy implementations.

## Requirements

- Omarchy 4.0.3 or newer with the Quattro shell plugin contract.
- The standard Omarchy launcher commands on `PATH`.
- Python 3 (standard library only) for the optional data widgets.
- ImageMagick for wallpaper contrast sampling.

## Third-party plugin shelf

The quiet three-dot handle between workspaces and status indicators is the
plugin shelf. Hover for 110 ms to reveal it; moving away gives you 450 ms of
grace before it fades closed. Left-click the handle to pin/unpin it for this
session; right-click returns to auto-hide. A pinned handle becomes three small
bars with an underline. Each monitor has its own reveal/pin state.

An open widget panel keeps the shelf and its anchor in place until it closes.
Widgets stay mounted while concealed, so hover does not reset their state or
restart their collectors. The shelf does not intercept their clicks or wheel
gestures. When space is tight, the two edge buttons scroll the plugin strip;
scrolling is held while a plugin panel is open. Workspace/status space is kept
separate, and an empty shelf has no handle.

Only **enabled external bar widgets already in Omarchy's bar layout** appear.
Their existing settings and left → center → right order are preserved, with
duplicate IDs shown once. Built-in widgets, Omacrunch itself, disabled plugins
and unconfigured entries are excluded. Configure them in Omarchy's existing
bar/plugin settings; Omacrunch does not enable, install or update those plugins.
Settings-only changes do not recreate their widgets. Disabling/removing a
widget releases its click targets and open popout.

Compatibility is bounded by Omarchy's public replacement-bar API:

- Widgets receive the official `Ui.PluginBarApi`, including scoped shell
  actions, settings updates, tooltips and popout coordination.
- Replacement bars currently receive **service-less** shell entry facades.
  Widgets requiring `bar.shell.serviceFor(theirId)` (for example Disk Lens
  and News Readers) may render, but their service-backed features are not
  available through this API. This is not full compatibility with every plugin.
- Omacrunch does not bypass this boundary, read another plugin's private
  objects, instantiate a duplicate service or modify Omarchy core.
- Hosted third-party code retains its own network/process/resource behaviour;
  hiding it is visual, not suspension or a security sandbox.

Diagnostics: `omarchy-shell omacrunch-bar pluginState` reports entries,
per-monitor reveal/pin/held state and overflow. `pinPlugins true` / `false`
on the same IPC target controls the focused monitor for testing.

## Desktop widgets

Open the root menu → **Widgets** (`I`). Toggle widgets for the current monitor.
Only the existing System Monitor is enabled initially. Choose **Edit layout**,
drag a widget by its labelled handle, then **Save** (Enter) or **Cancel** (Escape).
**Reset positions** restores the current screen's starting arrangement while
preserving which widgets are enabled. Application windows stay underneath the
editor; leaving it restores the desktop layer and releases keyboard focus.

Positions snap to an 8-pixel grid and are saved as fractions of each monitor's
available area. A resolution change clamps widgets back on-screen, while
disconnected monitors retain their settings for when they return. Move a widget
on each screen independently; dragging across monitor edges is not supported.
State is written atomically to
`$XDG_STATE_HOME/omarchy/omacrunch/widgets.json` (default:
`~/.local/state/omarchy/omacrunch/widgets.json`). Uninstalling preserves this layout.

Each new widget samples the wallpaper under its own position, including after
a drag or wallpaper change. Loading and error states use a readable fallback.

- **Weather** shows Celsius, conditions, wind and three forecast days. It uses
  the configured Omarchy weather location or a city set in **Weather location**.
  With no location it asks for one; it does not infer your location from your IP.
  When enabled, it contacts `geocoding-api.open-meteo.com` (city lookup) and
  `api.open-meteo.com` every 15 minutes. [Open-Meteo](https://open-meteo.com/)
  supplies the data. Requests have timeouts and response limits; errors preserve
  the last successful result with its age shown.
- **Agent Usage** reads Omarchy's existing `agents/usage/*.json` records once a
  minute. It displays provider limits, token counts, auth/status errors and
  update age. It does not read credentials or transcripts or refresh providers
  itself. Missing limits are not presented as zero usage.
- **Disk Usage** samples `/` and the home filesystem once a minute, showing
  available space and capacity. Both rows can represent the same filesystem.
- **Calendar** is a local month view with Monday first and today highlighted;
  it does not connect to online calendars or display appointments.

Collectors run only while their widget is enabled on at least one monitor;
multiple monitors share each feed. Widgets are read-only outside edit mode.
The automated offscreen Quickshell test sends mouse-drag events to the actual
widget component and checks Cancel, atomic Save and a fresh store reload.
It uses an isolated temporary state directory, not the user's saved layout.

## Install from this local checkout

```bash
omarchy plugin add "$HOME/Projects/plugins/omacrunch" --enable --yes
```

The plugin is cloned into Omarchy's user plugin directory and selected as the
active bar. Its workspace taskbar and wallpaper telemetry start immediately;
right-clicking an empty part of the desktop opens the root menu.

## Update a local test installation

Local installation clones committed Git state. Commit the version you want to
test, then fast-forward the installed clone without unloading the active bar:

```bash
omarchy plugin update io.github.mtolhuys.omacrunch --yes
```

This preserves a stable layer-shell exclusive zone while applications are
running. Removing and immediately re-adding an active replacement bar can
otherwise make some Wayland clients briefly retain a stale buffer after the
two opposing screen resizes.

## Remove

```bash
omarchy plugin remove io.github.mtolhuys.omacrunch --yes
```

Removing an enabled installation unloads its service and lets Omarchy restore
the bar it replaced.

## Quality checks

Omakit is the quality gate for this repository. The regular check also runs
Omarchy manifest validation, QML static analysis, deterministic unit tests for
the `/proc` parsers and wallpaper contrast algorithm, plus regression tests for
the replacement-bar and menu-focus contracts:

```bash
make check
make marketplace-check
```

`submit --offline` performs the local marketplace checks without posting
anything. A public GitHub origin is intentionally not required for local use;
the submission preflight will report that missing publication metadata until
one is configured.
The official security baseline is **not run** without that origin; a successful
`verify` command with `invoked: false` is not a passed baseline.
`omakit weigh` refuses full replacement bars (`plugin-is-bar`), so this project
does not claim an Omakit CPU/memory measurement. The shipped Omakit lab suites
exercise Omakit's Run/Store/weigh blocks, not arbitrary desktop widget gestures.

To validate the clean Git `HEAD`, replace any earlier local installation,
verify that its service is alive and open its root menu in one pass:

```bash
make local-test
```

`make local-test` refuses a dirty worktree. This guarantees that Omarchy runs
the same commit that passed the checks. An existing local clone is fast-forwarded
and rescanned in place so the active bar is never deliberately unloaded; a
first run still installs and enables it. It then waits up to ten seconds for
the shell's asynchronous plugin reload before probing the service. It proves
one visible 30-pixel Omacrunch bar exists per screen, at
least five workspaces are exposed, the native status widgets loaded and the
calendar routes through the replacement bar. Finally it exercises the adaptive
wallpaper lifecycle and opens and closes the root menu, leaving no fullscreen
surface or keyboard grab behind.

## Interaction

- Click a workspace number: switch to it.
- Scroll over the workspace strip: previous or next workspace.
- Click an application icon: focus its window and workspace.
- Middle-click an application icon: close the window.
- Click network, audio, battery or time: open the corresponding native panel.
- Right-click the battery: toggle its percentage display.
- Middle-click the Omarchy logo: open a terminal.
- Click or right-click the Omarchy logo: open the Omacrunch root menu.
- Right-click empty desktop: Omacrunch root menu.
- Arrow keys or `J`, then Enter: navigate and activate.
- `T`, `F`, `W`, `A`, `S`, `I`, `K`, `P`: direct root-menu accelerators.
- Escape or `Q`: close the root menu.

Existing Omarchy/Hyprland shortcuts remain available and are shown directly
on the desktop.
