const fs = require("node:fs")
const vm = require("node:vm")
const assert = require("node:assert/strict")
const path = require("node:path")

const source = fs.readFileSync(path.join(__dirname, "..", "Contrast.js"), "utf8")
const context = {}
vm.createContext(context)
vm.runInContext(source, context)

function pixels(colors, repeats = 32) {
  const output = []
  for (let i = 0; i < repeats; i++) {
    for (const color of colors) output.push(color[0], color[1], color[2], 255)
  }
  return output
}

const light = "#f2f2f2"
const dark = "#111111"

const onBlack = context.analyze(pixels([[0, 0, 0]]), light, dark)
assert.equal(onBlack.useLight, true)
assert.equal(onBlack.scrimOpacity, 0)

const onWhite = context.analyze(pixels([[255, 255, 255]]), light, dark)
assert.equal(onWhite.useLight, false)
assert.equal(onWhite.scrimOpacity, 0)

const mixed = context.analyze(pixels([[0, 0, 0], [150, 235, 210], [255, 255, 255]]), light, dark)
assert.equal(mixed.useLight, false)
assert.ok(mixed.scrimOpacity >= 0.20, `mixed wallpaper scrim was only ${mixed.scrimOpacity}`)
assert.ok(mixed.scrimOpacity <= 0.40, `mixed wallpaper scrim was too heavy at ${mixed.scrimOpacity}`)
assert.ok(mixed.spread > 0.5)
assert.ok(mixed.minimumContrast >= 4.5, `mixed wallpaper contrast was only ${mixed.minimumContrast}`)

const fiery = context.analyze(
  pixels([[18, 3, 12], [92, 10, 18], [240, 45, 4], [255, 205, 8]]),
  light,
  dark
)
assert.equal(fiery.useLight, false)
assert.ok(fiery.scrimOpacity >= 0.20, `fiery wallpaper scrim was only ${fiery.scrimOpacity}`)
assert.ok(fiery.scrimOpacity <= 0.40, `fiery wallpaper scrim was too heavy at ${fiery.scrimOpacity}`)
assert.ok(fiery.minimumContrast >= 4.5, `fiery wallpaper contrast was only ${fiery.minimumContrast}`)

console.log("contrast: ok")
