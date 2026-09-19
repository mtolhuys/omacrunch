# Third-party shelf — 2026-09-20

Implementation and live acceptance commit: `35549db53cf2065b068a8e7ac643b50fa7be3239`.
Version: 0.6.0. Single physical monitor, eDP-1; multiple physical monitors were
not available for this run. This report is not a security approval.

## Implemented behaviour

- A 32px quiet handle in the free bar area; 110ms hover dwell, 200ms reveal,
  450ms leave grace. The handle does not move during the animation.
- Session-only pin/unpin, independently per monitor. Open popouts hold the shelf.
- Existing configured external widgets only, in left/center/right order.
  No installation, enabling, configuration migration or third-party update.
- Live widget instances survive hiding, settings updates, reordering and
  incremental registry arrivals. Concealed click targets are unregistered.
- Width-bounded plugin viewport with explicit overflow buttons; scrolling
  pauses while a popout holds its anchor.

## Automated checks

Final `make local-test`: exit 0. Included manifest validation, qmllint, existing
parser/contrast/workspace/widget tests, Python collector tests, real offscreen
desktop-widget drag tests, shelf interaction tests and live IPC assertions.

The shelf test sends actual QtTest hover/click events. It checks delayed hide,
pinning, child click delivery, open-panel hold, foreign-popout masking,
concealed-target removal, settings without recreation, incremental insertion,
reordering, overflow, scroll clamping and teardown cleanup. It also checks
legacy own-service scoping and that a modern factory refusal does not fall
back to the legacy adapter.

Tests passed against both:

- active dev shell: `/home/mtolhuijs/Projects/omarchy/core/shell`;
- installed shell: `/usr/share/omarchy/shell`.

## Live checks

- Exactly 18 live bar widgets: five native status modules and 13 external
  entries. No duplicate `(screen, id)` registrations.
- Collapsed shelf: width 32; expanded shelf: width 408; widget content: 368.
- Omaplug opened and visually inspected; shelf held open, unpinned.
- Disk Lens opened and visually inspected, with live service capacity 35%,
  `scanState: idle`, no scan or file operation requested.
- Both panels closed afterward; shelf returned to auto-hide.
- Existing tray animation, calendar routing, root-menu focus release and
  wallpaper analysis/refresh checks passed.
- Existing desktop widget layout was retained; the editor was closed before
  updating. No changes to Omarchy core or other installed plugin sources.

The first live attempt found that the dev host does not export the installed
host's `Ui.PluginBarApi`. A local structural facade now supports both, and
the active dev path is the default lint/test path. A subsequent live test
caught repeated initialization during incremental registry loading; keyed
model updates now preserve existing widgets. Animation acceptance waits for
settled geometry instead of assuming a fixed 300ms wall-clock deadline.

## Omakit outcomes and limits

Marketplace pin: `38060f89d2a10b1f9b6b5afe8e226451e8a5b3f6`.

- `inspect --full`: completed, static only. Existing computed-argv and
  collector-cap findings remain in its report. It does not follow the external
  widgets loaded through the registry; these keep their own resource behaviour.
- `verify --json`: `invoked: false`, no declared GitHub repository URL.
  This is **not** a passed official baseline.
- `submit --offline`: refused only on `submission.repository-url`; dependent
  checks are unknown, not passed. Nothing submitted or published.
- `weigh --json`, without `--yes`: `plugin-is-bar`, NOT WEIGHED. No A/B shell
  restarts or CPU/memory claim. Omakit's shipped lab suites are not an arbitrary
  plugin gesture/acceptance harness.

Read-only audit of the 13 reused configured entries against the pin:

- `validated`: hardie.omarchy-cast.
- `ahead`: workspace service users sidecar, radio-atlas, omaplug, robzolkos.github,
  news-radar, sero.local-ai, onscreen-keyboard and crmne.hyprmoncfg.
- `unlisted`: bjarneo.workspace-layout, news-readers and plugin-pulse;
  plugin-pulse additionally has the `modified` flag.
- `diverged`: disk-lens.

These are the already installed versions, not freshly marketplace-validated
versions. The audit did not update, roll back or modify any of them.

On modern capability-scoped hosts, service-less entry facades remain a real
compatibility limit. The legacy adapter only uses the older public injection
contract and only exposes each widget's own service/actions. It does not bypass
a modern host's refusal or retrieve private objects through parent traversal.
