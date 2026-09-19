const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")
const assert = require("node:assert/strict")
const actions = vm.createContext({})
vm.runInContext(fs.readFileSync(path.join(__dirname, "..", "MenuActions.js"), "utf8"), actions)
const plain = value => JSON.parse(JSON.stringify(value))

const expected = {
  T: ["omarchy-launch-terminal"],
  F: ["omarchy-launch-nautilus"],
  W: ["omarchy-launch-browser"],
  A: ["omarchy-menu", "toggle", "apps"],
  B: ["omarchy-menu", "toggle", "background"],
  H: ["omarchy-menu", "toggle", "theme"],
  S: ["omarchy-menu", "toggle", "style"],
  I: [],
  K: ["omarchy-menu-keybindings"],
  P: ["omarchy-menu", "toggle", "system"]
}
const entries = actions.rootEntries()
assert.equal(entries.length, 10)
assert.equal(new Set(entries.map(entry => entry.key)).size, entries.length)
for (const entry of entries) assert.deepEqual(plain(actions.commandFor(entry)), expected[entry.key])
// Commands must follow entries, not their old indices, even when reordered.
for (const entry of entries.slice().reverse()) assert.deepEqual(plain(actions.commandFor(entry)), expected[entry.key])
assert.deepEqual(plain(actions.commandFor(undefined)), [])
assert.deepEqual(plain(actions.commandFor({})), [])
assert.equal(entries.find(entry => entry.key === "B").label, "Wallpaper")
assert.equal(entries.find(entry => entry.key === "H").label, "Theme")
assert.equal(entries.find(entry => entry.action === "widgets").key, "I")
console.log("menu actions: native wallpaper/theme routes, existing commands and unique accelerators ok")
