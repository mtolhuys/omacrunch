SHELL := /bin/bash

PLUGIN_ID := io.github.mtolhuys.omacrunch
OMARCHY_SHELL_DIR ?= /usr/share/omarchy/shell

.PHONY: check marketplace-check install-local open local-test remove-local

check:
	@test -z "$$(git status --porcelain)" || { echo "Refusing to test a dirty worktree; commit the version you want Omarchy to clone." >&2; exit 1; }
	omarchy plugin validate .
	qmllint -I "$(OMARCHY_SHELL_DIR)" Bar.qml Service.qml Menu.qml Sparkline.qml
	node tests/metrics.test.js
	node tests/contracts.test.js
	omakit inspect . --full
	omakit verify .

marketplace-check:
	omakit submit . --category Desktop --tags bar,hyprland,launcher --offline

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
	@bar_geometry="$$(omarchy-shell shell debugBarGeometry)"; \
	if [ "$$bar_geometry" != "[]" ]; then \
		echo "Omacrunch service loaded, but the stock bar is still active: $$bar_geometry" >&2; \
		exit 1; \
	fi
	@echo "Omacrunch service state:"
	omarchy-shell omacrunch state
	omarchy-shell omacrunch menu

local-test: check install-local open
