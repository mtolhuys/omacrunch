#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
shelf_test_dir=$(mktemp -d /tmp/omacrunch-shelf-test-XXXXXX)
cp ./*.qml ./*.js "$shelf_test_dir/"
cp tests/tst_plugin_shelf.qml "$shelf_test_dir/shell.qml"
ln -s "${OMARCHY_SHELL_DIR:-/usr/share/omarchy/shell}/Commons" "$shelf_test_dir/Commons"
ln -s "${OMARCHY_SHELL_DIR:-/usr/share/omarchy/shell}/Ui" "$shelf_test_dir/Ui"
output=$(env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic \
  QT_QUICK_BACKEND=software XDG_RUNTIME_DIR="$shelf_test_dir" XDG_STATE_HOME="$shelf_test_dir/state" \
  timeout 30 quickshell -p "$shelf_test_dir" --no-color 2>&1)
if [[ "$output" != *SHELF_UI_PASS* || "$output" == *SHELF_UI_FAIL* ]] \
  || rg -q 'ReferenceError|TypeError|Binding loop|Unable to assign|Cannot assign|invalid context' <<<"$output"; then
  printf '%s\n' "$output" >&2
  exit 1
fi
printf 'plugin shelf UI: hover, pin, clicks, drag reorder, persistence, cancel, overflow, scoping, cleanup ok (%s)\n' "$shelf_test_dir"
# Existing directory at the file path must fail atomically and retain old order.
install -d -m 700 -- "$shelf_test_dir/blocked/omarchy/omacrunch/plugin-order.json"
output=$(env -u WAYLAND_DISPLAY QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic \
  QT_QUICK_BACKEND=software XDG_RUNTIME_DIR="$shelf_test_dir" \
  XDG_STATE_HOME="$shelf_test_dir/blocked" OMACRUNCH_ORDER_FAILURE=1 \
  timeout 10 quickshell -p "$shelf_test_dir" --no-color 2>&1)
if [[ "$output" != *SHELF_UI_PASS* || "$output" == *SHELF_UI_FAIL* ]] \
  || rg -q 'ReferenceError|TypeError|Binding loop|Unable to assign|Cannot assign|invalid context' <<<"$output"; then
  printf '%s\n' "$output" >&2
  exit 1
fi
printf 'plugin order: atomic-write failure rolls back and reports error\n'
