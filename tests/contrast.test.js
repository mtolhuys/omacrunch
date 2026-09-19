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
assert.ok(mixed.scrimOpacity >= 0.25, `mixed wallpaper scrim was only ${mixed.scrimOpacity}`)
assert.ok(mixed.spread > 0.5)

console.log("contrast: ok")
