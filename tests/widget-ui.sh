#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
widget_test_dir=$(mktemp -d /tmp/omacrunch-widget-test-XXXXXX)
cp ./*.qml ./*.js ./*.py "$widget_test_dir/"
cp tests/tst_widgets.qml "$widget_test_dir/shell.qml"
ln -s "${OMARCHY_SHELL_DIR:-/usr/share/omarchy/shell}/Commons" "$widget_test_dir/Commons"
ln -s "${OMARCHY_SHELL_DIR:-/usr/share/omarchy/shell}/Ui" "$widget_test_dir/Ui"
output=$(env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic \
  QT_QUICK_BACKEND=software XDG_STATE_HOME="$widget_test_dir/state" \
  XDG_RUNTIME_DIR="$widget_test_dir" timeout 25 quickshell -p "$widget_test_dir" --no-color 2>&1)
if [[ "$output" != *WIDGET_UI_PASS* || "$output" == *WIDGET_UI_FAIL* ]]; then
  printf '%s\n' "$output" >&2
  exit 1
fi
printf 'widget UI: real mouse drag, Cancel, atomic Save, fresh-store reload ok (%s)\n' "$widget_test_dir"
