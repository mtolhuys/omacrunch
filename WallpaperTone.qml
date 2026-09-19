import QtQuick
import "Contrast.js" as Contrast

// Samples the exact wallpaper crop behind the telemetry block. The canvas is
// intentionally tiny: it captures luminance distribution, not visual detail.
Item {
  id: root

  property url source
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

  width: 40
  height: 64
  opacity: 0.001

  function requestAnalysis() {
    if (wallpaper.status === Image.Ready) sampler.requestPaint()
  }

  onScreenWidthChanged: requestAnalysis()
  onScreenHeightChanged: requestAnalysis()
  onSampleRectChanged: requestAnalysis()
  onLightCandidateChanged: requestAnalysis()
  onDarkCandidateChanged: requestAnalysis()

  Image {
    id: wallpaper
    source: root.source
    sourceSize.width: 640
    asynchronous: true
    cache: false
    visible: false
    onStatusChanged: if (status === Image.Ready) Qt.callLater(root.requestAnalysis)
  }

  Canvas {
    id: sampler
    anchors.fill: parent
    renderTarget: Canvas.Image
    antialiasing: false

    onPaint: {
      if (wallpaper.status !== Image.Ready) return
      var imageWidth = wallpaper.sourceSize.width
      var imageHeight = wallpaper.sourceSize.height
      if (imageWidth <= 0 || imageHeight <= 0 || root.screenWidth <= 0 || root.screenHeight <= 0) return

      var scale = Math.max(root.screenWidth / imageWidth, root.screenHeight / imageHeight)
      var fittedWidth = imageWidth * scale
      var fittedHeight = imageHeight * scale
      var fittedX = (root.screenWidth - fittedWidth) / 2
      var fittedY = (root.screenHeight - fittedHeight) / 2
      var sourceX = Math.max(0, (root.sampleRect.x - fittedX) / scale)
      var sourceY = Math.max(0, (root.sampleRect.y - fittedY) / scale)
      var sourceWidth = Math.min(imageWidth - sourceX, root.sampleRect.width / scale)
      var sourceHeight = Math.min(imageHeight - sourceY, root.sampleRect.height / scale)
      if (sourceWidth <= 0 || sourceHeight <= 0) return

      var context = getContext("2d")
      context.clearRect(0, 0, width, height)
      context.drawImage(wallpaper, sourceX, sourceY, sourceWidth, sourceHeight, 0, 0, width, height)
      var result = Contrast.analyze(
        context.getImageData(0, 0, width, height).data,
        root.lightCandidate,
        root.darkCandidate
      )
      root.ink = result.useLight ? root.lightCandidate : root.darkCandidate
      root.scrimColor = result.useLight ? "#000000" : "#ffffff"
      root.scrimOpacity = result.scrimOpacity
      root.measuredContrast = result.minimumContrast
      root.measuredSpread = result.spread
    }
  }
}
