# Omacrunch

![Omacrunch — Omarchy in Crunch mode](assets/omacrunch.gif)

**Omarchy, in Crunch mode.**

Omacrunch turns Omarchy into a clean, CrunchBang-inspired desktop experience.
It is more than a theme: the bar, desktop, widgets and right-click menu work
together as one calm interface, while Omarchy stays Omarchy underneath.

## What you get

- A slim topbar with persistent workspaces, application icons and native
  network, audio, battery and calendar controls.
- A clock and live system monitor on the wallpaper, readable across light and
  dark backgrounds.
- Optional weather, disk, agent-usage and calendar widgets.
- Widgets you can drag, snap and save independently on each monitor.
- A fast right-click menu for apps, wallpapers, themes, keybindings and power.
- A quiet, hover-reveal shelf for third-party Omarchy bar plugins.

No Openbox, Tint2 or Conky processes are added. Omacrunch recreates that
focused desktop feeling inside Omarchy's existing Hyprland and Quickshell stack.

The shelf hosts configured third-party bar widgets through Omarchy's public bar
API. Most compact widgets work unchanged; a widget that relies on private stock
bar internals may not. Omacrunch never loads an unconfigured plugin or reaches
into another plugin's files.

## Install

```bash
omarchy plugin add https://github.com/mtolhuys/omacrunch --enable --yes
```

The bar and desktop widget appear immediately. Right-click an empty part of the
desktop to open the menu.

To update to the latest published version:

```bash
omarchy plugin update io.github.mtolhuys.omacrunch --yes
```

## Everyday use

| Do this | What happens |
|---|---|
| Right-click the desktop | Open the Crunch menu |
| Click the Omarchy logo | Open the same menu |
| Press `Super+Alt+C` | Open the Crunch menu after one-time setup |
| Press `Super+Shift+Space` | Hide or reveal the topbar |
| Double-click the topbar | Fade its background between solid and transparent |
| Press `I` in the menu | Open Widgets |
| Choose **Edit layout** | Drag widgets by their handle |
| Press Enter / Escape | Save / cancel the layout |
| Click a workspace number | Switch there, even when it is empty |
| Hover the three-dot shelf | Reveal third-party bar plugins |
| Right-click that shelf | Arrange plugins by dragging |

Wallpaper and theme actions use Omarchy's native pickers. Existing Hyprland
shortcuts continue to work.

Choose **Install menu shortcut** once in the Crunch menu to claim
`Super+Alt+C`. Omacrunch only installs it when the chord is free, creates a
private backup and rolls back if Hyprland cannot reload it. The same menu row
removes the exact Omacrunch-owned binding again.

## Widgets

Only **System Monitor** is enabled by default. Extra widgets are opt-in:

- **Weather** uses Open-Meteo and only makes requests after you enable it and
  choose a city. Your location is saved locally.
- **Agent Usage** reads Omarchy's existing local usage summaries; it does not
  read credentials or transcripts.
- **Disk Usage** shows free space for `/` and your home filesystem.
- **Calendar** is a local month view without accounts or appointments.

Widget positions are stored in
`~/.local/state/omarchy/omacrunch/widgets.json`. Plugin-shelf order is stored
beside it in `plugin-order.json`. Removing the plugin leaves both files intact.

## Requirements

- Omarchy 4.0.3 or newer with Quattro plugin support.
- ImageMagick for wallpaper-aware contrast.
- Python 3's standard library for the optional data widgets.

## Develop and test

From the root of a checkout:

```bash
make check
make marketplace-check
```

To install and exercise the exact clean Git commit locally:

```bash
make local-test
```

`make local-test` refuses a dirty worktree. It validates the manifest and QML,
runs the unit and offscreen UI tests, applies the Omakit checks, updates the
local installation and probes the live bar, menu and wallpaper lifecycle.

Omakit's shipped VM suites do not currently cover arbitrary plugin pointer
gestures, so drag behaviour also has focused component and live-shell tests.

## Remove

If you installed `Super+Alt+C`, choose **Remove menu shortcut** first or run:

```bash
python3 "$HOME/.config/omarchy/plugins/io.github.mtolhuys.omacrunch/shortcut.py" remove
```

```bash
omarchy plugin remove io.github.mtolhuys.omacrunch --yes
```

Omacrunch is inspired by [CrunchBang++](https://www.crunchbangplusplus.org/)
and released under the [MIT License](LICENSE). See the
[changelog](CHANGELOG.md) for version history.
