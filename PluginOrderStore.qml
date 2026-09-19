import QtQuick
import Quickshell
import Quickshell.Io
import "PluginShelfModel.js" as Model

// One shared preference for all monitors. Never rewrites shell.json or any
// third-party plugin's settings. Writes only after an explicit user drop.
Item {
  id: store
  property var order: []
  property var confirmedOrder: []
  property bool loaded: false
  property bool saving: false
  property string error: ""
  readonly property string directory: (Quickshell.env("XDG_STATE_HOME")
    || Quickshell.env("HOME") + "/.local/state") + "/omarchy/omacrunch"

  function save(ids) {
    if (!loaded || saving) return false
    var next = Model.mergeOrder(order, ids)
    if (Model.sameIds(next, order)) return true
    error = ""
    order = next
    saving = true
    ensureDirectory.running = true
    return true
  }

  function fail(message) {
    error = message
    order = confirmedOrder.slice()
    saving = false
  }

  FileView {
    id: file
    path: store.directory + "/plugin-order.json"
    atomicWrites: true
    printErrors: false
    onLoaded: {
      if (store.loaded) return
      try {
        var data = JSON.parse(text())
        if (data.version !== 1 || !Array.isArray(data.order)) throw new Error("Invalid order")
        store.order = Model.normalizeOrder(data.order)
        store.confirmedOrder = store.order.slice()
      } catch (e) { store.error = "Could not read plugin order; using configured order." }
      store.loaded = true
    }
    onLoadFailed: store.loaded = true
    onSaved: {
      store.confirmedOrder = store.order.slice()
      store.saving = false
    }
    onSaveFailed: store.fail("Could not save plugin order. Previous order restored.")
  }
  Process {
    id: ensureDirectory
    command: ["/usr/bin/mkdir", "-p", "--", store.directory]
    onRunningChanged: if (running) deadline.restart(); else deadline.stop()
    onExited: function(code) {
      if (code === 0) file.setText(JSON.stringify({version: 1, order: store.order}, null, 2) + "\n")
      else store.fail("Could not create plugin order directory. Previous order restored.")
    }
  }
  Timer { id: deadline; interval: 3000; onTriggered: ensureDirectory.running = false }
}
