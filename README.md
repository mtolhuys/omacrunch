# Omacrunch

Omacrunch turns the Omarchy shell into a complete CrunchBang++-inspired
desktop. It is not a launcher skin: it changes the persistent desktop
experience while keeping Omarchy's native Hyprland and Quickshell stack.

Version `0.4.5` provides:

- a flat, translucent, 30-pixel topbar on every monitor;
- a Tint2-style workspace/taskbar hybrid with five persistent workspaces;
- application icons inside their owning workspace, including focused and
  urgent states, direct activation and middle-click close;
- wheel navigation over the workspace strip;
- pinned system-tray icons and Omarchy's complete native network, audio,
  battery/power-profile and calendar panels;
- a clickable tray disclosure: left-click collapses or expands the icon
  cluster, while right-click opens native tray management;
- a compact `HH:mm` clock and an always-readable battery percentage;
- live CPU, memory, load, network and uptime telemetry over the wallpaper;
- compact history graphs, host information, clock, date and shortcut hints;
- one telemetry surface per monitor;
- wallpaper-aware foreground selection based on the pixels beneath the monitor;
- spatially adaptive widget surfaces that keep one clean ink tone per module
  and add only the local contrast floor required by the wallpaper;
- a sharp, monochrome root menu on right-click;
- theme-derived bar colours plus wallpaper-derived monitor contrast;
- no background daemon, network access, state files or privileged commands.

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
- `T`, `F`, `W`, `A`, `S`, `K`, `P`: direct root-menu accelerators.
- Escape or `Q`: close the root menu.

Existing Omarchy/Hyprland shortcuts remain available and are shown directly
on the desktop.
