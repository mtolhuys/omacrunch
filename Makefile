SHELL := /bin/bash

PLUGIN_ID := io.github.mtolhuys.omacrunch
OMARCHY_SHELL_DIR ?= /usr/share/omarchy/shell

.PHONY: check marketplace-check install-local open local-test remove-local

check:
	@test -z "$$(git status --porcelain)" || { echo "Refusing to test a dirty worktree; commit the version you want Omarchy to clone." >&2; exit 1; }
	omarchy plugin validate .
	qmllint -I "$(OMARCHY_SHELL_DIR)" Bar.qml Service.qml Menu.qml Sparkline.qml WallpaperTone.qml
	node tests/metrics.test.js
	node tests/contrast.test.js
	node tests/tone-sample.test.js
	node tests/workspace.test.js
	node tests/contracts.test.js
	omakit inspect . --full
	omakit verify .

marketplace-check:
	omakit submit . --category Desktop --tags Bar,Hyprland,Workspaces --json --offline

remove-local:
	@if omarchy plugin list --json | jq -e 'any(.[]; .id == "$(PLUGIN_ID)")' >/dev/null; then \
		omarchy plugin remove "$(PLUGIN_ID)" --yes; \
	fi

install-local: remove-local
	omarchy plugin add "$(CURDIR)" --enable --yes

open:
	@ready=0; \
	for attempt in $$(seq 1 100); do \
		if omarchy-shell omacrunch ping >/dev/null 2>&1; then ready=1; break; fi; \
		sleep 0.1; \
	done; \
	if [ "$$ready" -ne 1 ]; then \
		echo "Omacrunch service did not register within 10 seconds." >&2; \
		echo "Inspect the current Quickshell log for 'service plugin load failed'." >&2; \
		exit 1; \
	fi
	@bar_ready=0; \
	for attempt in $$(seq 1 100); do \
		bar_geometry="$$(omarchy-shell shell debugBarGeometry 2>/dev/null)"; \
		if jq -e 'length >= 1 and all(.[]; .id == "omacrunch.workspace-taskbar" and .visible == true and .height == 30 and .width > 0)' <<<"$$bar_geometry" >/dev/null 2>&1; then bar_ready=1; break; fi; \
		sleep 0.1; \
	done; \
	if [ "$$bar_ready" -ne 1 ]; then \
		echo "Omacrunch workspace taskbar did not expose valid per-screen geometry: $$bar_geometry" >&2; \
		exit 1; \
	fi
	@bar_state="$$(omarchy-shell omacrunch-bar state)"; \
	if ! jq -e '.height == 30 and .screens >= 1 and .workspaces >= 5 and .widgets >= 4 and ([.widgetMetrics[] | select(.visible == true and .implicitWidth > 0 and .implicitHeight > 0)] | length) >= 4' <<<"$$bar_state" >/dev/null; then \
		echo "Omacrunch workspace/status bar was incomplete: $$bar_state" >&2; \
		exit 1; \
	fi; \
	echo "Omacrunch bar state: $$bar_state"
	@if [ "$$(omarchy-shell omacrunch-bar trayState)" != "expanded" ]; then \
		echo "Omacrunch tray did not start expanded." >&2; exit 1; \
	fi
	@if [ "$$(omarchy-shell omacrunch-bar toggleTray)" != "collapsed" ]; then \
		echo "Omacrunch tray disclosure did not collapse." >&2; exit 1; \
	fi
	@if [ "$$(omarchy-shell omacrunch-bar toggleTray)" != "expanded" ]; then \
		echo "Omacrunch tray disclosure did not expand." >&2; exit 1; \
	fi
	@echo "Omacrunch tray lifecycle: expanded -> collapsed -> expanded"
	@echo "Omacrunch service state:"
	@tone_ready=0; \
	for attempt in $$(seq 1 100); do \
		if [ "$$(omarchy-shell omacrunch toneState 2>/dev/null)" = "ready" ]; then tone_ready=1; break; fi; \
		sleep 0.1; \
	done; \
	if [ "$$tone_ready" -ne 1 ]; then \
		echo "Omacrunch did not analyze the active wallpaper within 10 seconds." >&2; \
		omarchy-shell omacrunch toneDebug >&2 || true; \
		exit 1; \
	fi
	omarchy-shell omacrunch state
	@omarchy-shell omacrunch refreshTone >/dev/null
	@tone_refreshed=0; \
	for attempt in $$(seq 1 100); do \
		if [ "$$(omarchy-shell omacrunch toneState 2>/dev/null)" = "ready" ]; then tone_refreshed=1; break; fi; \
		sleep 0.1; \
	done; \
	if [ "$$tone_refreshed" -ne 1 ]; then \
		echo "Omacrunch did not re-analyze the wallpaper after a refresh signal." >&2; \
		omarchy-shell omacrunch toneDebug >&2 || true; \
		exit 1; \
	fi
	@echo "Omacrunch wallpaper lifecycle: initial -> refreshed"
	@if [ "$$(omarchy-shell shell summon omarchy.clock '{}')" != "ok" ]; then \
		echo "Omacrunch did not route the native calendar through its status cluster." >&2; exit 1; \
	fi
	@omarchy-shell shell hide omarchy.clock
	@echo "Omacrunch status panel lifecycle: clock open -> closed"
	@omarchy-shell shell summon "$(PLUGIN_ID)" '{}'
	@menu_ready=0; \
	for attempt in $$(seq 1 30); do \
		if [ "$$(omarchy-shell omacrunch menuState 2>/dev/null)" = "open" ]; then menu_ready=1; break; fi; \
		sleep 0.05; \
	done; \
	if [ "$$menu_ready" -ne 1 ]; then echo "Omacrunch menu did not open." >&2; exit 1; fi
	@omarchy-shell shell hide "$(PLUGIN_ID)"
	@menu_closed=0; \
	for attempt in $$(seq 1 30); do \
		if [ "$$(omarchy-shell omacrunch menuState 2>/dev/null)" = "closed" ]; then menu_closed=1; break; fi; \
		sleep 0.05; \
	done; \
	if [ "$$menu_closed" -ne 1 ]; then echo "Omacrunch menu retained input focus after hide." >&2; exit 1; fi
	@echo "Omacrunch menu lifecycle: open -> closed"

local-test: check install-local open
