import QtQuick
import Quickshell
import "WidgetLayout.js" as Layout
import "omakit" as Omakit

Item {
  id: root
  property var layout: Layout.defaults()
  property var savedLayout: Layout.defaults()
  property bool editing: false
  property bool loaded: false
  property string error: ""
  property bool migrating: false
  signal weatherLocationSaved()
  readonly property bool directoryReady: loaded && !stateStore.busy
  readonly property string migrationHelper: decodeURIComponent(
    String(Qt.resolvedUrl("legacy-state.py")).replace(/^file:\/\//, ""))

  function item(screen, id) { return Layout.entry(layout, screen, id) }
  function enabled(screen, id) { return item(screen, id).enabled }
  function anyEnabled(id) {
    return Quickshell.screens.some(function(screen) { return root.enabled(screen.name, id) })
  }
  function toggle(screen, id) {
    layout = Layout.change(layout, screen, id, { enabled: !enabled(screen, id) })
    if (!editing) persist()
  }
  function place(screen, id, point) { layout = Layout.change(layout, screen, id, point) }
  function begin() {
    if (editing) return
    savedLayout = Layout.normalize(layout)
    editing = true
  }
  function finish(save) {
    if (!editing) return
    if (save) persist()
    else layout = Layout.normalize(savedLayout)
    editing = false
  }
  function reset(screen) {
    var next = Layout.normalize(layout)
    Object.keys(next.screens[screen] || {}).forEach(function(id) {
      delete next.screens[screen][id].x
      delete next.screens[screen][id].y
    })
    layout = next
    if (!editing) persist()
  }
  function setCity(city) {
    if (!loaded) { error = "Settings are still loading; try again."; return false }
    var next = Layout.normalize(layout)
    next.weatherCity = String(city || "").trim().slice(0, 120)
    layout = next
    // Location is a preference, not a draft widget position. Saving it must
    // survive cancelling layout edits without committing those draft positions.
    if (editing) {
      var saved = Layout.normalize(savedLayout)
      saved.weatherCity = next.weatherCity
      savedLayout = saved
    }
    persist(editing ? savedLayout : layout)
    weatherLocationSaved()
    return true
  }
  function persist(snapshot) {
    if (!loaded) return
    error = ""
    stateStore.write(Layout.normalize(snapshot || layout))
  }

  function finishLoad(value) {
    layout = Layout.normalize(value)
    savedLayout = Layout.normalize(layout)
    loaded = true
  }

  Omakit.Store {
    id: stateStore
    pluginId: "io.github.mtolhuys.omacrunch"
    name: "widgets.json"
    maxBytes: 65536
    schema: ({
      type: "object",
      required: ["version", "screens", "weatherCity"],
      properties: {
        version: { type: "integer", enum: [1] },
        screens: { type: "object", maxProperties: 32 },
        weatherCity: { type: "string", maxLength: 120 }
      },
      additionalProperties: false
    })
    onFinished: function(result) {
      if (result.op === "read") {
        if (result.state === "ok") root.finishLoad(result.value)
        else if (result.state === "missing") legacyReader.start()
        else {
          root.error = "Could not read widget layout (" + result.state + "); defaults loaded."
          root.finishLoad(Layout.defaults())
        }
      } else if (result.op === "write" && root.migrating) {
        root.migrating = false
        if (result.state !== "ok") root.error = "Could not migrate widget layout (" + result.state + ")."
        root.loaded = true
      } else if (result.op === "write" && result.state !== "ok") {
        root.error = "Could not save widget layout (" + result.state + ")."
      }
    }
  }

  Omakit.Run {
    id: legacyReader
    command: ["/usr/bin/python3", "-I", "-S", "-B", root.migrationHelper, "widgets.json"]
    environment: {
      var result = {}
      var stateHome = Quickshell.env("XDG_STATE_HOME")
      if (stateHome) result.XDG_STATE_HOME = stateHome
      return result
    }
    deadlineMs: 3000
    maxBytes: 65536
    keepBytes: 65536
    maxLines: 2
    onFinished: function(result) {
      if (result.state === "ok") {
        try {
          root.layout = Layout.normalize(JSON.parse(result.stdout))
          root.savedLayout = Layout.normalize(root.layout)
          root.migrating = true
          stateStore.write(root.layout)
          return
        } catch (error) {
          root.error = "Could not migrate the old widget layout; defaults loaded."
        }
      } else if (!(result.state === "exit" && result.exitCode === 3)) {
        root.error = "Could not inspect the old widget layout; defaults loaded."
      }
      root.finishLoad(Layout.defaults())
    }
  }

  Component.onCompleted: stateStore.read()
}
