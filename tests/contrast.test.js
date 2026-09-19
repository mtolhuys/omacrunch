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
assert.equal(mixed.scrimOpacity, 0)
assert.ok(mixed.haloOpacity >= 0.90, `mixed wallpaper halo was only ${mixed.haloOpacity}`)
assert.ok(mixed.spread > 0.5)
assert.ok(mixed.minimumContrast < 4.5, "mixed wallpaper should exercise the local halo path")

const fiery = context.analyze(
  pixels([[18, 3, 12], [92, 10, 18], [240, 45, 4], [255, 205, 8]]),
  light,
  dark
)
assert.equal(fiery.useLight, false)
assert.equal(fiery.scrimOpacity, 0)
assert.ok(fiery.haloOpacity >= 0.80, `fiery wallpaper halo was only ${fiery.haloOpacity}`)

console.log("contrast: ok")
