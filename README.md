# Omacrunch

Omacrunch turns the Omarchy shell into a barless, CrunchBang-inspired desktop.
It is not a launcher skin: it changes the persistent desktop experience while
keeping Omarchy's native Hyprland and Quickshell stack intact.

Version `0.2.0` provides:

- a truly barless shell through an intentionally empty Omarchy bar provider;
- live CPU, memory, load, network and uptime telemetry over the wallpaper;
- compact history graphs, host information, clock, date and shortcut hints;
- one telemetry surface per monitor;
- a sharp, monochrome root menu on right-click;
- theme-derived colours, so the desktop remains coherent with the active
  Omarchy theme;
- no background daemon, network access, state files or privileged commands.

The root menu is deliberately secondary. The always-visible wallpaper
telemetry, absence of a bar and direct desktop interaction are the product.

## Architecture

The manifest exposes three cooperating Quattro plugin kinds:

- `bar` — replaces the stock bar without creating a panel surface;
- `service` — reads Linux `/proc` data every two seconds and renders the
  desktop overlay below application windows;
- `menu` — supplies the right-click root menu and delegates to the standard
  Omarchy application, style, keybinding and power menus.

No Openbox, tint2 or Conky process is introduced. Omacrunch recreates their
role inside the existing Omarchy shell instead of running a second desktop
stack beside it.

## Requirements

- Omarchy 4.0.3 or newer with the Quattro shell plugin contract.
- The standard Omarchy launcher commands on `PATH`.

## Install from this local checkout

```bash
omarchy plugin add "$HOME/Projects/plugins/omacrunch" --enable --yes
```

The plugin is cloned into Omarchy's user plugin directory and selected as the
active bar. The stock bar disappears, wallpaper telemetry starts immediately,
and right-clicking an empty part of the desktop opens the root menu.

## Update a local test installation

Local installation clones committed Git state. Commit the version you want to
test, then remove and add it again:

```bash
omarchy plugin remove io.github.mtolhuys.omacrunch --yes
omarchy plugin add "$HOME/Projects/plugins/omacrunch" --enable --yes
```

## Remove

```bash
omarchy plugin remove io.github.mtolhuys.omacrunch --yes
```

Removing an enabled installation unloads its service and lets Omarchy restore
the bar it replaced.

## Quality checks

Omakit is the quality gate for this repository. The regular check also runs
Omarchy manifest validation, QML static analysis and deterministic unit tests
for the `/proc` parsers:

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

`make local-test` refuses a dirty worktree. This guarantees that Omarchy clones
and runs the same commit that passed the checks.

## Interaction

- Right-click empty desktop: Omacrunch root menu.
- Arrow keys or `J`, then Enter: navigate and activate.
- `T`, `F`, `W`, `A`, `S`, `K`, `P`: direct root-menu accelerators.
- Escape or `Q`: close the root menu.

Existing Omarchy/Hyprland shortcuts remain available and are shown directly
on the desktop.
