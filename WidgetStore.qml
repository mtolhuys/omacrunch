import QtQuick
import Quickshell
import Quickshell.Io
import "WidgetLayout.js" as Layout

Item {
  id: root
  property var layout: Layout.defaults()
  property var savedLayout: Layout.defaults()
  property bool editing: false
  property bool loaded: false
  property bool directoryReady: false
  property string error: ""
  property var pendingLayout: Layout.defaults()
  signal weatherLocationSaved()
  readonly property string directory: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/omacrunch"

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
    pendingLayout = Layout.normalize(snapshot || layout)
    if (directoryReady) writePending()
    else ensureDirectory.running = true
  }
  function writePending() { stateFile.setText(JSON.stringify(pendingLayout, null, 2) + "\n") }
  FileView {
    id: stateFile
    path: root.directory + "/widgets.json"
    atomicWrites: true
    printErrors: false
    onLoaded: {
      if (root.loaded) return
      try { root.layout = Layout.normalize(JSON.parse(text())) }
      catch (e) { root.error = "Could not read widget layout; defaults loaded." }
      root.loaded = true
    }
    onLoadFailed: root.loaded = true
    onSaveFailed: root.error = "Could not save widget layout. Check directory permissions."
  }
  Process {
    id: ensureDirectory
    command: ["/usr/bin/mkdir", "-p", "--", root.directory]
    onRunningChanged: if (running) deadline.restart(); else deadline.stop()
    onExited: function(code) {
      root.directoryReady = code === 0
      if (root.directoryReady) root.writePending()
      else root.error = "Could not create widget layout directory."
    }
  }
  Timer { id: deadline; interval: 3000; onTriggered: ensureDirectory.running = false }
}
