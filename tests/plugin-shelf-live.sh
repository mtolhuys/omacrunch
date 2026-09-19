#!/usr/bin/env bash
set -euo pipefail
# Registry loading is asynchronous. Wait for each currently configured shelf
# widget to have exactly one live instance with nonzero height on its screen.
shelf_ready=0
for attempt in $(seq 1 60); do
  shelves=$(omarchy-shell omacrunch-bar pluginState)
  bar_state=$(omarchy-shell omacrunch-bar state)
  if jq -en --argjson shelves "$shelves" --argjson bar "$bar_state" '
    ($shelves | length) > 0 and
    all($shelves[]; .right == .anchorRight and (. as $shelf |
      all(.ids[]; . as $id |
        [$bar.widgetMetrics[] | select(.id == $id and .screen == $shelf.screen and .height > 0)] | length == 1)))
    and ([$bar.widgetMetrics[] | [.screen,.id]] | length == (unique | length))
  ' >/dev/null; then shelf_ready=1; break; fi
  sleep 0.1
done
if [[ "$shelf_ready" != 1 ]]; then
  printf 'Plugin shelf registry did not settle: %s\n' "$bar_state" >&2
  exit 1
fi
printf 'Omacrunch plugin shelf: %s\n' "$shelves"
