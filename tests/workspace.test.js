const assert = require("node:assert/strict")
const Workspace = require("../Workspace.js")

assert.deepEqual(Workspace.workspaceIds([], 5, 10), [1, 2, 3, 4, 5])
assert.deepEqual(
  Workspace.workspaceIds([{ id: 8 }, { id: 2 }, { id: -99 }, { id: 12 }], 5, 10),
  [1, 2, 3, 4, 5, 8]
)

const client = {
  address: "0xabc123",
  title: "Notes — project",
  lastIpcObject: { class: "org.gnome.TextEditor", initialClass: "fallback" }
}

assert.equal(Workspace.clientClass(client), "org.gnome.TextEditor")
assert.equal(Workspace.clientTitle(client), "Notes — project")
assert.equal(Workspace.clientInitial(client), "O")
assert.equal(
  Workspace.focusCommand(client),
  'dispatch hl.dsp.focus({ window = "address:0xabc123" })'
)
assert.equal(
  Workspace.moveCommand(client, 4),
  'dispatch hl.dsp.window.move({ workspace = "4", follow = false, window = "address:0xabc123" })'
)
assert.equal(Workspace.focusCommand({ address: "$(bad)" }), "")
assert.equal(Workspace.moveCommand({ address: "0xabc" }, 0), "")

console.log("workspace: ok")
