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
assert.ok(mixed.haloOpacity >= 0.42, `mixed wallpaper halo was only ${mixed.haloOpacity}`)
assert.ok(mixed.haloOpacity <= 0.64, `mixed wallpaper halo was too heavy at ${mixed.haloOpacity}`)
assert.ok(mixed.spread > 0.5)
assert.ok(mixed.minimumContrast < 4.5, "mixed wallpaper should exercise the local halo path")
assert.ok(mixed.requiredExtremeOpacity > 0.15,
  "mixed wallpaper should request a real per-widget contrast floor")

const fiery = context.analyze(
  pixels([[18, 3, 12], [92, 10, 18], [240, 45, 4], [255, 205, 8]]),
  light,
  dark
)
assert.equal(fiery.useLight, true)
assert.equal(fiery.scrimOpacity, 0)
assert.ok(fiery.haloOpacity >= 0.42, `fiery wallpaper halo was only ${fiery.haloOpacity}`)
assert.ok(fiery.requiredExtremeOpacity > 0,
  "fiery wallpaper should expose the surface opacity needed for readable widgets")

const mostlyDark = context.analyze(
  pixels([[0, 0, 0], [8, 8, 8], [16, 16, 16], [30, 30, 30], [255, 255, 255]]),
  light,
  dark
)
assert.equal(mostlyDark.useLight, true, "one bright object must not flip a dark region to dark ink")

const mostlyLight = context.analyze(
  pixels([[255, 255, 255], [245, 245, 245], [230, 230, 230], [210, 210, 210], [0, 0, 0]]),
  light,
  dark
)
assert.equal(mostlyLight.useLight, false, "one dark object must not flip a light region to light ink")

console.log("contrast: ok")
