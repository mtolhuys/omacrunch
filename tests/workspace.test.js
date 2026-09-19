const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")
const Workspace = require("../Workspace.js")

assert.deepEqual(Workspace.workspaceIds([], 5, 10), [1, 2, 3, 4, 5])
assert.equal(Workspace.workspaceCommand(3, true), 'hl.dsp.focus({ workspace = "3" })')
assert.equal(Workspace.workspaceCommand(3, false), "workspace 3")
for (const invalid of [0, -1, 100, 1.5, NaN, Infinity, "bad", '3" })'])
  assert.equal(Workspace.workspaceCommand(invalid, true), "")

// Exercise the actual QML routing function, including the absent-workspace
// branch. This does not touch the running desktop during make check.
const bar = fs.readFileSync(path.join(__dirname, "..", "Bar.qml"), "utf8")
const focus = bar.match(/  function focusWorkspace\(id\) \{[\s\S]*?\n  \}/)[0]
const dispatched = []
let activated = 0
let present = false
const hyprland = {usingLua: true, dispatch: command => dispatched.push(command)}
const context = vm.createContext({Workspace, Hyprland: hyprland,
  workspaceById: () => present ? {activate: () => activated++} : null})
vm.runInContext(focus, context)
assert.equal(context.focusWorkspace(3), true)
assert.deepEqual(dispatched, ['hl.dsp.focus({ workspace = "3" })'])
present = true
assert.equal(context.focusWorkspace(3), true)
assert.equal(activated, 1)
assert.equal(dispatched.length, 1, "existing workspace uses its native activate method")
assert.equal(context.focusWorkspace(0), false)
assert.equal(activated, 1)
present = false
hyprland.usingLua = false
context.focusWorkspace(5)
assert.equal(dispatched[1], "workspace 5")
assert.match(bar, /onClicked:\s*root\.focusWorkspace\(workspaceCell\.modelData\)/)
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
