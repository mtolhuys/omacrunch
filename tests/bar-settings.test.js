const assert = require("node:assert/strict")
const { configuredEntry, clockSettings } = require("../BarSettings.js")

const config = {
  layout: {
    left: [{ id: "omarchy.workspaces" }],
    center: [{ id: "third.party" }],
    right: [
      { id: "omarchy.audio" },
      { id: "omarchy.clock", format: "ddd d MMM HH:mm", formatAlt: "HH:mm:ss",
        weekStartsMonday: true }
    ]
  }
}
const before = JSON.stringify(config)

assert.equal(configuredEntry(config, "omarchy.clock"), config.layout.right[1])
assert.deepEqual(clockSettings(config), {
  id: "omarchy.clock",
  format: "ddd d MMM HH:mm",
  formatAlt: "HH:mm:ss",
  weekStartsMonday: true
})
assert.equal(JSON.stringify(config), before, "reading settings must not mutate shell config")

assert.deepEqual(clockSettings({
  layout: { center: [{ id: "omarchy.clock", format: "yyyy-MM-dd HH:mm" }] }
}), {
  id: "omarchy.clock",
  format: "yyyy-MM-dd HH:mm",
  formatAlt: "ddd d MMM yyyy"
})

for (const malformed of [null, {}, { layout: [] }, { layout: { right: "clock" } }, {
  layout: { right: [{ id: "omarchy.clock", format: "", formatAlt: 42 }] }
}]) {
  assert.deepEqual(clockSettings(malformed), {
    id: "omarchy.clock",
    format: "HH:mm",
    formatAlt: "ddd d MMM yyyy"
  })
}

console.log("bar settings: persisted clock format and fallbacks ok")
