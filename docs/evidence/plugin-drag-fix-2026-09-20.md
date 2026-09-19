# Plugin drag drop tolerance — 0.7.2

## Reproduction on the installed bar

On the diagnostic 0.7.1 build (`fee73ec`), a native Wayland pointer drag
of `bjarneo.workspace-layout` from the first position toward the last was
rejected when released at y=45 on a 30-logical-pixel bar. The pointer was
grabbed and the item moved, but the release reported:

`release:bjarneo.workspace-layout:moved=true:valid=false:save=false`

The order did not change. A horizontal drag inside the bar succeeded. This
isolated a strict drop-boundary problem, not a failure to write the order.

## Fix and live result

Build `63922b45b7a7b8783cd215ee3e836e10989e46f1` accepts a 24-logical-pixel
margin around the strip during an already-grabbed drag. It creates no new
input surface over ordinary windows. Far-away releases still cancel.

Using a temporary `zwlr_virtual_pointer_v1` diagnostic client, the same
gesture was repeated against the installed bar on eDP-1 (2560x1600, scale
1.6), with 13 real third-party widgets loaded:

- Native right-click on the shelf handle opened arrange mode.
- Left drag from local (1047,15) to (1393,45) moved the first plugin last.
- Release reported `moved=true:valid=true:save=true`; gesture serial increased.
- `plugin-order.json` matched the new live order.
- A reverse native drag restored the exact original order, including its
  persisted representation. Arrange mode was closed and the cursor restored.

This tests a real installed plugin through the compositor, not every plugin
or every possible gesture. The temporary helper is not shipped or needed by
the plugin. No third-party plugin code or settings were edited.

## Automated regression coverage

`make local-test` passed on this commit, including QML lint, model/unit tests,
widget UI tests, shelf UI tests with both development and packaged shell
components, and installed-shell lifecycle/registry smoke tests.

The shelf QtTest now covers a release 15px below the bar and a slight
horizontal overshoot, alongside reverse moves, far-away cancellation,
atomic persistence/readback and write-error rollback. The diagonal case
failed before the tolerance fix and passed afterward.

Omakit inspect, verify and offline submit were run. Official baseline:
**not run**, because no GitHub repository URL is declared. Offline submission
is refused on `submission.repository-url`. These results are not marketplace
approval or a security audit.
