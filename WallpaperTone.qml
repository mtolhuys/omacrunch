import QtQuick
import Quickshell.Io
import "Contrast.js" as Contrast

// Samples the exact wallpaper crop behind the telemetry block. ImageMagick
// emits a quantized histogram with at most 16 lines, so analysis is bounded
// and independent of whether the compositor schedules a hidden Canvas frame.
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
  property color scrimColor: "#000000"
  property real scrimOpacity: 0.18
  property real measuredContrast: 1
  property real measuredSpread: 1
  property bool analyzed: false
  property int attempts: 0
  property var histogramPixels: []

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
    histogramPixels = []
    toneProcess.running = true
    processDeadline.restart()
  }

  function acceptHistogramLine(line) {
    // The sampled image is exactly 40x64 pixels. Keep the collector bounded
    // even if ImageMagick (or a future replacement) emits malformed counts.
    if (histogramPixels.length >= 10240) return
    var match = String(line || "").match(/^\s*(\d+):.*#([0-9a-f]{6})\b/i)
    if (!match) return
    var remaining = Math.floor((10240 - histogramPixels.length) / 4)
    var count = Math.min(remaining, 2560, parseInt(match[1], 10) || 0)
    var red = parseInt(match[2].slice(0, 2), 16)
    var green = parseInt(match[2].slice(2, 4), 16)
    var blue = parseInt(match[2].slice(4, 6), 16)
    for (var index = 0; index < count; index++) histogramPixels.push(red, green, blue, 255)
  }

  function finishHistogram() {
    if (!histogramPixels.length) return

    var result = Contrast.analyze(histogramPixels, lightCandidate, darkCandidate)
    ink = result.useLight ? lightCandidate : darkCandidate
    scrimColor = result.useLight ? "#000000" : "#ffffff"
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
        "-resize", "40x64!",
        "-colorspace", "sRGB",
        "-colors", "16",
        "-format", "%c",
        "histogram:info:-"
      ]
    }
    stdout: SplitParser {
      onRead: function(line) { root.acceptHistogramLine(line) }
    }
    onExited: root.finishHistogram()
    onRunningChanged: if (!running) processDeadline.stop()
  }
}
