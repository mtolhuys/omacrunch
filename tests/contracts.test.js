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

assert.match(bar, /WlrLayershell\.namespace:\s*"omacrunch-bar"/)
assert.match(bar, /readonly\s+property\s+int\s+barSize:\s*30/)
assert.match(bar, /readonly\s+property\s+int\s+taskSlotWidth:\s*Style\.space\(18\)/)
assert.match(bar, /readonly\s+property\s+int\s+taskIconSize:\s*Style\.space\(13\)/)
assert.ok(bar.includes('text: "\\ue900"'), "bar menu uses the Omarchy logo glyph")
assert.match(bar, /font\.family:\s*"omarchy"/)
assert.match(bar, /workspaceContent\.implicitWidth\s*\+\s*\(root\.workspaceContentPadding\s*\*\s*2\)/)
assert.match(bar, /visible:\s*taskButton\.client\s*&&\s*taskButton\.client\.activated/)
assert.match(bar, /function\s+debugBarGeometry\s*\(\)/)
assert.match(bar, /"omacrunch\.workspace-taskbar"/)
assert.match(bar, /workspace\.toplevels\.values/)
assert.match(bar, /function\s+summonBarWidget\s*\(id\)/)
assert.match(bar, /showPercentage:\s*true/)
assert.match(bar, /format:\s*"HH:mm"/)
assert.match(bar, /target:\s*"omacrunch-bar"/)
assert.match(bar, /statusSlot\.trayExpanded\s*=\s*!statusSlot\.trayExpanded/)
assert.match(bar, /managePopupOpen\s*=\s*!statusLoader\.item\.managePopupOpen/)
assert.match(menu, /WlrKeyboardFocus\.OnDemand/)
assert.match(menu, /Qt\.ControlModifier\s*\|\s*Qt\.AltModifier\s*\|\s*Qt\.MetaModifier/)
assert.match(makefile, /omarchy-shell shell hide "\$\(PLUGIN_ID\)"/)
assert.match(makefile, /menu lifecycle: open -> closed/)
assert.match(makefile, /omarchy-shell omacrunch toneState/)
assert.match(makefile, /omarchy-shell omacrunch-bar state/)
assert.match(makefile, /tray lifecycle: expanded -> collapsed -> expanded/)
assert.match(makefile, /widgetMetrics\[\]/)
assert.match(makefile, /omacrunch\.workspace-taskbar/)
assert.match(makefile, /shell summon omarchy\.clock/)
assert.match(service, /wallpaperAnalyzed:\s*root\.wallpaperAnalyzed/)
assert.match(service, /function\s+toneState\s*\(\):\s*string/)
assert.match(service, /onAnalyzedChanged:\s*root\.wallpaperAnalyzed\s*=\s*analyzed/)
assert.match(service, /sourcePath:\s*root\.currentBackground/)
assert.match(service, /revision:\s*root\.wallpaperRevision/)
assert.match(service, /function\s+toneDebug\s*\(\):\s*string/)
assert.match(makefile, /omarchy-shell omacrunch toneDebug/)
assert.match(makefile, /wallpaper lifecycle: initial -> refreshed/)
assert.match(service, /function\s+refreshTone\s*\(\):\s*string/)
assert.match(service, /component\s+WidgetSurface:\s*Rectangle/)
assert.match(service, /surfaceOpacity:\s*root\.zoneSurfaceOpacity\(toneZone\)/)
assert.match(service, /color:\s*root\.zoneSurfaceColor\(toneZone\)/)
assert.match(service, /style:\s*Text\.Normal/)
assert.match(service, /outlineColorRight:\s*outlineColor/)
assert.doesNotMatch(service, /style:\s*Text\.Outline/)
assert.match(service, /component\s+ContrastRule:/)
assert.doesNotMatch(service, /color:\s*Util\.alpha\(root\.scrimColor/)
assert.match(service, /WidgetSurface\s*\{\s*toneZone:\s*"body"/)
assert.match(service, /onZonesChanged:\s*root\.wallpaperZones\s*=\s*zones/)
assert.match(service, /requiredExtremeOpacity/)
assert.match(
  fs.readFileSync(path.join(__dirname, "..", "WallpaperTone.qml"), "utf8"),
  /gridPixels\.length\s*>=\s*216/
)

console.log("contracts: ok")
