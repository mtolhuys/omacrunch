import QtQuick
import Quickshell
import "PluginShelfModel.js" as Model
import "omakit" as Omakit

// One shared preference for all monitors. Never rewrites shell.json or any
// third-party plugin's settings. Writes only after an explicit user drop.
Item {
  id: store
  property var order: []
  property var confirmedOrder: []
  property bool loaded: false
  property bool saving: false
  property bool migrating: false
  property string error: ""
  readonly property string migrationHelper: decodeURIComponent(
    String(Qt.resolvedUrl("legacy-state.py")).replace(/^file:\/\//, ""))

  function save(ids) {
    if (!loaded || saving) return false
    var next = Model.mergeOrder(order, ids)
    if (Model.sameIds(next, order)) return true
    error = ""
    order = next
    saving = true
    orderStore.write({ version: 1, order: order })
    return true
  }

  function fail(message) {
    error = message
    order = confirmedOrder.slice()
    saving = false
  }

  function applyOrder(value) {
    if (!value || value.version !== 1 || !Array.isArray(value.order)) return false
    order = Model.normalizeOrder(value.order)
    confirmedOrder = order.slice()
    return true
  }

  Omakit.Store {
    id: orderStore
    pluginId: "io.github.mtolhuys.omacrunch"
    name: "plugin-order.json"
    maxBytes: 65536
    schema: ({
      type: "object",
      required: ["version", "order"],
      properties: {
        version: { type: "integer", enum: [1] },
        order: {
          type: "array", maxItems: 512,
          items: { type: "string", maxLength: 200, pattern: "^[a-zA-Z0-9][a-zA-Z0-9._-]{0,199}$" }
        }
      },
      additionalProperties: false
    })
    onFinished: function(result) {
      if (result.op === "read") {
        if (result.state === "ok" && store.applyOrder(result.value)) store.loaded = true
        else if (result.state === "missing") legacyReader.start()
        else {
          store.error = "Could not read plugin order (" + result.state + "); using configured order."
          store.loaded = true
        }
      } else if (result.op === "write" && store.migrating) {
        store.migrating = false
        if (result.state !== "ok") store.error = "Could not migrate plugin order (" + result.state + ")."
        store.loaded = true
      } else if (result.op === "write" && result.state === "ok") {
        store.confirmedOrder = store.order.slice()
        store.saving = false
      } else if (result.op === "write") {
        store.fail("Could not save plugin order (" + result.state + "). Previous order restored.")
      }
    }
  }

  Omakit.Run {
    id: legacyReader
    command: ["/usr/bin/python3", "-I", "-S", "-B", store.migrationHelper, "plugin-order.json"]
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
          if (!store.applyOrder(JSON.parse(result.stdout))) throw new Error("Invalid order")
          store.migrating = true
          orderStore.write({ version: 1, order: store.order })
          return
        } catch (error) {
          store.error = "Could not migrate the old plugin order; using configured order."
        }
      } else if (!(result.state === "exit" && result.exitCode === 3)) {
        store.error = "Could not inspect the old plugin order; using configured order."
      }
      store.loaded = true
    }
  }

  Component.onCompleted: orderStore.read()
}
