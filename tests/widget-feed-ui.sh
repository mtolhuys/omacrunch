#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
feed_test_dir=$(mktemp -d /tmp/omacrunch-feed-test-XXXXXX)
cp ./*.qml ./*.js "$feed_test_dir/"
cp ./legacy-state.py "$feed_test_dir/"
cp -R -- omakit "$feed_test_dir/omakit"
cp tests/tst_widget_feed.qml "$feed_test_dir/shell.qml"
cp tests/widget-feed-fixture.py "$feed_test_dir/widget-data.py"
ln -s "${OMARCHY_SHELL_DIR:-/usr/share/omarchy/shell}/Commons" "$feed_test_dir/Commons"
ln -s "${OMARCHY_SHELL_DIR:-/usr/share/omarchy/shell}/Ui" "$feed_test_dir/Ui"
if ! output=$(env -u WAYLAND_DISPLAY HOME="$feed_test_dir" QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=generic \
  QT_QUICK_BACKEND=software XDG_RUNTIME_DIR="$feed_test_dir" \
  XDG_STATE_HOME="$feed_test_dir/state" timeout 25 quickshell -p "$feed_test_dir" --no-color 2>&1); then
  printf '%s\n' "$output" >&2
  exit 1
fi
if [[ "$output" != *WIDGET_FEED_PASS* || "$output" == *WIDGET_FEED_FAIL* ]] \
  || rg -q 'ReferenceError|TypeError|Binding loop|Unable to assign|Cannot assign|invalid context' <<<"$output"; then
  printf '%s\n' "$output" >&2
  exit 1
fi
printf 'widget feed lifecycle: ok (%s)\n' "$feed_test_dir"
