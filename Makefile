SHELL := /bin/bash

PLUGIN_ID := io.github.mtolhuys.omacrunch
OMARCHY_SHELL_DIR ?= /usr/share/omarchy/shell

.PHONY: check marketplace-check install-local open local-test remove-local

check:
	@test -z "$$(git status --porcelain)" || { echo "Refusing to test a dirty worktree; commit the version you want Omarchy to clone." >&2; exit 1; }
	omarchy plugin validate .
	qmllint -I "$(OMARCHY_SHELL_DIR)" Bar.qml Service.qml Menu.qml Sparkline.qml
	node tests/metrics.test.js
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
	@echo "Omacrunch service state:"
	omarchy-shell omacrunch state
	omarchy-shell omacrunch menu

local-test: check install-local open
