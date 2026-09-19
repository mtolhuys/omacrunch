function workspaceIds(workspaces, minimumCount, maximumId) {
  var minimum = Math.max(1, Number(minimumCount) || 5)
  var maximum = Math.max(minimum, Number(maximumId) || 10)
  var ids = []

  for (var base = 1; base <= minimum; base++) ids.push(base)
  var values = workspaces || []
  for (var index = 0; index < values.length; index++) {
    var id = Number(values[index] && values[index].id)
    if (id > 0 && id <= maximum && ids.indexOf(id) === -1) ids.push(id)
  }

  ids.sort(function(left, right) { return left - right })
  return ids
}

function workspaceCommand(workspaceId, usingLua) {
  var id = Number(workspaceId)
  if (!Number.isInteger(id) || id < 1 || id > 99) return ""
  // Quickshell adds the IPC dispatch wrapper itself. A non-existent workspace
  // must be dispatched by number; there is no workspace object to activate yet.
  return usingLua ? 'hl.dsp.focus({ workspace = "' + id + '" })' : "workspace " + id
}

function clientClass(client) {
  var ipc = client && client.lastIpcObject ? client.lastIpcObject : ({})
  return String(ipc.class || ipc.initialClass || ipc.appId
    || (client && client.wayland && client.wayland.appId) || "").trim()
}

function clientTitle(client) {
  var ipc = client && client.lastIpcObject ? client.lastIpcObject : ({})
  return String((client && client.title) || ipc.title || ipc.initialTitle
    || clientClass(client) || "Application").trim()
}

function clientInitial(client) {
  var name = clientClass(client) || clientTitle(client)
  var match = name.match(/[A-Za-z0-9]/)
  return match ? match[0].toUpperCase() : "·"
}

function focusCommand(client) {
  var address = String(client && client.address || "")
  if (!/^0x[0-9a-f]+$/i.test(address)) return ""
  return "dispatch hl.dsp.focus({ window = \"address:" + address + "\" })"
}

function moveCommand(client, workspaceId) {
  var address = String(client && client.address || "")
  var id = Math.round(Number(workspaceId))
  if (!/^0x[0-9a-f]+$/i.test(address) || id < 1 || id > 99) return ""
  return "dispatch hl.dsp.window.move({ workspace = \"" + id
    + "\", follow = false, window = \"address:" + address + "\" })"
}

if (typeof module !== "undefined") {
  module.exports = {
    workspaceIds,
    workspaceCommand,
    clientClass,
    clientTitle,
    clientInitial,
    focusCommand,
    moveCommand
  }
}
