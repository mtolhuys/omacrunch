# Plugin shelf drag order — 0.7.0

The QtTest fixture dispatches real mouse events to PluginShelf and mock
third-party widgets in an isolated offscreen shell/state directory. It is not
a claim that every installed third-party plugin has been gesture-tested.

Verified with the active development shell's public components and the
packaged `/usr/share/omarchy/shell` components:

- Right-click enters arrange mode; normal click behavior returns on exit.
- Left/right moves with mixed widget widths; insertion feedback and animation.
- No accidental panel activation or forwarded clicks while arranging.
- Existing widget instances survive moves; a second shelf follows the order.
- Release outside the strip and registry changes cancel a pending move.
- Overflow-edge autoscroll, panel-anchor hold, pin state preserved.
- Atomic order save and fresh-store readback; failed writes roll back and
  report an error instead of claiming persistence.
- Pure model tests cover malformed/duplicate IDs, disabled and new plugins,
  settings identity and invalid moves.

Commands: `node tests/plugin-shelf.test.js`, `bash tests/plugin-shelf-ui.sh`,
`OMARCHY_SHELL_DIR="$OMARCHY_PATH/shell" bash tests/plugin-shelf-ui.sh`.
The full suite and installed-shell smoke tests are wired into `make local-test`.

Omakit audit: local installation is **unlisted**, with no modified/disabled
or upstream-moved flags. Official baseline is **not run** without a declared
GitHub repository URL; submit refuses `submission.repository-url`.
`omakit weigh` reports **NOT WEIGHED**: this is a whole replacement bar
(`plugin-is-bar`). No shell restarts were performed for weighing.
