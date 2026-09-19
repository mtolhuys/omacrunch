# Omacrunch

Omacrunch is a keyboard-first, CrunchBang-inspired command deck for Omarchy.
It keeps Omarchy's native Hyprland and Quickshell stack while borrowing the
quiet typography, sharp edges and direct interaction that made CrunchBang
memorable.

Version `0.1.0` is deliberately small:

- a `#!` bar widget;
- a keyboard-navigable command deck;
- launchers for Terminal, Files, Web, Apps, Keybindings and Power;
- no daemon, network access, polling, state files or privileged commands.

## Requirements

- Omarchy 4.0.3 or newer with the Quattro shell plugin contract.
- The standard Omarchy launcher commands on `PATH`.

## Install from this local checkout

```bash
omarchy plugin add "$HOME/Projects/plugins/omacrunch" --enable --yes
```

The plugin is cloned into Omarchy's user plugin directory. Left-click `#!` to
open the command deck. Middle-click opens the Omarchy keybinding guide and
right-click opens the applications menu.

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

## Quality checks

Omakit is the quality gate for this repository:

```bash
omakit inspect . --full --json
omakit verify . --json
omakit submit . --category Desktop --tags bar,hyprland,launcher --json --offline
```

`submit --offline` performs the local marketplace checks without posting
anything. A public GitHub origin is intentionally not required for local use;
the submission preflight will report that missing publication metadata until
one is configured.

## Current scope

This first release is the shell interaction layer. A companion Omarchy theme
and a complete replacement bar are natural later stages, but are intentionally
not hidden inside the initial plugin.
