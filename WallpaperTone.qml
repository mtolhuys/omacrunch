import QtQuick
import Quickshell.Io
import "Contrast.js" as Contrast

// Samples the exact wallpaper crop behind the telemetry block. ImageMagick
// emits a fixed 12x18 pixel grid, keeping output bounded while preserving
// enough position data to choose tones per header/body/footer and left/right.
Item {
  id: root

  property string sourcePath
  property int revision: 0
  property real screenWidth: 1
  property real screenHeight: 1
  property rect sampleRect: Qt.rect(0, 0, 1, 1)
  property color lightCandidate: "#f2f2f2"
  property color darkCandidate: "#111111"
  property color ink: lightCandidate
  property color haloColor: "#000000"
  property real haloOpacity: 0.94
  property real scrimOpacity: 0
  property real measuredContrast: 1
  property real measuredSpread: 1
  property var zones: ({})
  property bool analyzed: false
  property int attempts: 0
  property var gridPixels: []

  width: 1
  height: 1
  visible: false

  function geometry() {
    var screen = Math.max(1, Math.round(screenWidth)) + "x"
      + Math.max(1, Math.round(screenHeight))
    var x = Math.max(0, Math.round(sampleRect.x))
    var y = Math.max(0, Math.round(sampleRect.y))
    var width = Math.max(1, Math.min(Math.round(sampleRect.width), Math.round(screenWidth) - x))
    var height = Math.max(1, Math.min(Math.round(sampleRect.height), Math.round(screenHeight) - y))
    return { screen: screen, crop: width + "x" + height + "+" + x + "+" + y }
  }

  function schedule() {
    analyzed = false
    refreshDebounce.restart()
  }

  function refresh() {
    if (!sourcePath || screenWidth <= 0 || screenHeight <= 0) return
    if (toneProcess.running) toneProcess.running = false
    attempts += 1
    gridPixels = []
    toneProcess.running = true
    processDeadline.restart()
  }

  function acceptPixelLine(line) {
    if (gridPixels.length >= 216) return
    var match = String(line || "").match(/^\s*(\d+),(\d+):.*#([0-9a-f]{6})\b/i)
    if (!match) return
    var hex = match[3]
    gridPixels.push({
      x: parseInt(match[1], 10),
      y: parseInt(match[2], 10),
      red: parseInt(hex.slice(0, 2), 16),
      green: parseInt(hex.slice(2, 4), 16),
      blue: parseInt(hex.slice(4, 6), 16)
    })
  }

  function pixelsFor(left, right, top, bottom) {
    var pixels = []
    for (var index = 0; index < gridPixels.length; index++) {
      var pixel = gridPixels[index]
      if (pixel.x < left || pixel.x >= right || pixel.y < top || pixel.y >= bottom) continue
      pixels.push(pixel.red, pixel.green, pixel.blue, 255)
    }
    return pixels
  }

  function analyzeZone(left, right, top, bottom) {
    return Contrast.analyze(pixelsFor(left, right, top, bottom), lightCandidate, darkCandidate)
  }

  function finishGrid() {
    if (!gridPixels.length) return

    var result = analyzeZone(0, 12, 0, 18)
    zones = {
      headerLeft: analyzeZone(0, 8, 0, 6),
      headerRight: analyzeZone(6, 12, 0, 6),
      bodyLeft: analyzeZone(0, 6, 5, 14),
      bodyRight: analyzeZone(6, 12, 5, 14),
      footerLeft: analyzeZone(0, 6, 13, 18),
      footerRight: analyzeZone(6, 12, 13, 18)
    }
    ink = result.useLight ? lightCandidate : darkCandidate
    haloColor = result.useLight ? "#000000" : "#ffffff"
    haloOpacity = result.haloOpacity
    scrimOpacity = result.scrimOpacity
    measuredContrast = result.minimumContrast
    measuredSpread = result.spread
    analyzed = true
  }

  onSourcePathChanged: schedule()
  onRevisionChanged: schedule()
  onScreenWidthChanged: schedule()
  onScreenHeightChanged: schedule()
  onSampleRectChanged: schedule()
  onLightCandidateChanged: schedule()
  onDarkCandidateChanged: schedule()
  Component.onCompleted: schedule()

  Timer {
    id: refreshDebounce
    interval: 100
    onTriggered: root.refresh()
  }

  Timer {
    id: processDeadline
    interval: 5000
    onTriggered: if (toneProcess.running) toneProcess.running = false
  }

  Process {
    id: toneProcess
    command: {
      var area = root.geometry()
      return [
        "/usr/bin/magick", root.sourcePath,
        "-auto-orient",
        "-resize", area.screen + "^",
        "-gravity", "center",
        "-extent", area.screen,
        "-gravity", "NorthWest",
        "-crop", area.crop,
        "+repage",
        "-resize", "12x18!",
        "-colorspace", "sRGB",
        "-depth", "8",
        "txt:-"
      ]
    }
    stdout: SplitParser {
      onRead: function(line) { root.acceptPixelLine(line) }
    }
    onExited: root.finishGrid()
    onRunningChanged: if (!running) processDeadline.stop()
  }
}
