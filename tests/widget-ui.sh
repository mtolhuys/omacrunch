#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
widget_test_dir=$(mktemp -d /tmp/omacrunch-widget-test-XXXXXX)
cp ./*.qml ./*.js ./*.py "$widget_test_dir/"
cp -R -- omakit "$widget_test_dir/omakit"
cp tests/tst_widgets.qml "$widget_test_dir/shell.qml"
ln -s "${OMARCHY_SHELL_DIR:-/usr/share/omarchy/shell}/Commons" "$widget_test_dir/Commons"
ln -s "${OMARCHY_SHELL_DIR:-/usr/share/omarchy/shell}/Ui" "$widget_test_dir/Ui"
install -d -m 700 -- "$widget_test_dir/state/omarchy/omacrunch"
install -m 600 -- tests/legacy-widgets.json "$widget_test_dir/state/omarchy/omacrunch/widgets.json"
output=$(env -u WAYLAND_DISPLAY HOME="$widget_test_dir" QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic \
  QT_QUICK_BACKEND=software XDG_STATE_HOME="$widget_test_dir/state" \
  XDG_RUNTIME_DIR="$widget_test_dir" timeout 25 quickshell -p "$widget_test_dir" --no-color 2>&1)
if [[ "$output" != *WIDGET_UI_PASS* || "$output" == *WIDGET_UI_FAIL* ]]; then
  printf '%s\n' "$output" >&2
  exit 1
fi
test -f "$widget_test_dir/state/io.github.mtolhuys.omacrunch/widgets.json"
test -f "$widget_test_dir/state/omarchy/omacrunch/widgets.json"
test "$(stat -c %a "$widget_test_dir/state/io.github.mtolhuys.omacrunch")" = 700
test "$(stat -c %a "$widget_test_dir/state/io.github.mtolhuys.omacrunch/widgets.json")" = 600
printf 'widget UI: legacy migration, private Store, real drag, Cancel, atomic Save, fresh reload ok (%s)\n' "$widget_test_dir"
