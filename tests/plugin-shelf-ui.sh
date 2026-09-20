#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
shelf_test_dir=$(mktemp -d /tmp/omacrunch-shelf-test-XXXXXX)
cp ./*.qml ./*.js ./*.py "$shelf_test_dir/"
cp -R -- omakit "$shelf_test_dir/omakit"
cp tests/tst_plugin_shelf.qml "$shelf_test_dir/shell.qml"
ln -s "${OMARCHY_SHELL_DIR:-/usr/share/omarchy/shell}/Commons" "$shelf_test_dir/Commons"
ln -s "${OMARCHY_SHELL_DIR:-/usr/share/omarchy/shell}/Ui" "$shelf_test_dir/Ui"
install -d -m 700 -- "$shelf_test_dir/state/omarchy/omacrunch"
install -m 600 -- tests/legacy-plugin-order.json "$shelf_test_dir/state/omarchy/omacrunch/plugin-order.json"
output=$(env -u WAYLAND_DISPLAY HOME="$shelf_test_dir" QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic \
  QT_QUICK_BACKEND=software XDG_RUNTIME_DIR="$shelf_test_dir" XDG_STATE_HOME="$shelf_test_dir/state" \
  timeout 30 quickshell -p "$shelf_test_dir" --no-color 2>&1)
if [[ "$output" != *SHELF_UI_PASS* || "$output" == *SHELF_UI_FAIL* ]] \
  || rg -q 'ReferenceError|TypeError|Binding loop|Unable to assign|Cannot assign|invalid context' <<<"$output"; then
  printf '%s\n' "$output" >&2
  exit 1
fi
test -f "$shelf_test_dir/state/io.github.mtolhuys.omacrunch/plugin-order.json"
test -f "$shelf_test_dir/state/omarchy/omacrunch/plugin-order.json"
test "$(stat -c %a "$shelf_test_dir/state/io.github.mtolhuys.omacrunch")" = 700
test "$(stat -c %a "$shelf_test_dir/state/io.github.mtolhuys.omacrunch/plugin-order.json")" = 600
printf 'plugin shelf UI: legacy migration, private Store, drag persistence and rollback ok (%s)\n' "$shelf_test_dir"
# Existing directory at the file path must fail atomically and retain old order.
install -d -m 700 -- "$shelf_test_dir/blocked/io.github.mtolhuys.omacrunch/plugin-order.json"
output=$(env -u WAYLAND_DISPLAY HOME="$shelf_test_dir" QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic \
  QT_QUICK_BACKEND=software XDG_RUNTIME_DIR="$shelf_test_dir" \
  XDG_STATE_HOME="$shelf_test_dir/blocked" OMACRUNCH_ORDER_FAILURE=1 \
  timeout 10 quickshell -p "$shelf_test_dir" --no-color 2>&1)
if [[ "$output" != *SHELF_UI_PASS* || "$output" == *SHELF_UI_FAIL* ]] \
  || rg -q 'ReferenceError|TypeError|Binding loop|Unable to assign|Cannot assign|invalid context' <<<"$output"; then
  printf '%s\n' "$output" >&2
  exit 1
fi
printf 'plugin order: atomic-write failure rolls back and reports error\n'
