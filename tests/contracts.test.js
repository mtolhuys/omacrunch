const fs = require("node:fs")
const path = require("node:path")
const assert = require("node:assert/strict")

const bar = fs.readFileSync(path.join(__dirname, "..", "Bar.qml"), "utf8")
const menu = fs.readFileSync(path.join(__dirname, "..", "Menu.qml"), "utf8")
const makefile = fs.readFileSync(path.join(__dirname, "..", "Makefile"), "utf8")
const service = fs.readFileSync(path.join(__dirname, "..", "Service.qml"), "utf8")
const injected = ["omarchyPath", "barWidgetRegistry", "barConfig"]

for (const property of injected) {
  assert.doesNotMatch(
    bar,
    new RegExp(`required\\s+property\\s+[^\\n]+\\s+${property}\\b`),
    `${property} is injected after Loader construction and cannot be required`
  )
}

assert.match(bar, /function\s+debugBarGeometry\s*\(\)\s*\{\s*return\s+\[\]\s*\}/)
assert.match(menu, /WlrKeyboardFocus\.OnDemand/)
assert.match(menu, /Qt\.ControlModifier\s*\|\s*Qt\.AltModifier\s*\|\s*Qt\.MetaModifier/)
assert.match(makefile, /omarchy-shell shell hide "\$\(PLUGIN_ID\)"/)
assert.match(makefile, /menu lifecycle: open -> closed/)
assert.match(makefile, /omarchy-shell omacrunch toneState/)
assert.match(service, /wallpaperAnalyzed:\s*root\.wallpaperAnalyzed/)
assert.match(service, /function\s+toneState\s*\(\):\s*string/)
assert.match(service, /onAnalyzedChanged:\s*root\.wallpaperAnalyzed\s*=\s*analyzed/)
assert.match(service, /sourcePath:\s*root\.currentBackground/)
assert.match(service, /revision:\s*root\.wallpaperRevision/)
assert.match(service, /function\s+toneDebug\s*\(\):\s*string/)
assert.match(makefile, /omarchy-shell omacrunch toneDebug/)
assert.match(makefile, /wallpaper lifecycle: initial -> refreshed/)
assert.match(service, /function\s+refreshTone\s*\(\):\s*string/)

console.log("contracts: ok")
