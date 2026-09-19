import QtQuick
import qs.Commons

Canvas {
  id: root

  property var samples: []
  property color lineColor: Color.foreground
  property color fillColor: Util.alpha(lineColor, 0.12)
  property real maximum: 100

  onSamplesChanged: requestPaint()
  onLineColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.clearRect(0, 0, root.width, root.height)
    var values = Array.isArray(root.samples) ? root.samples : []
    if (values.length < 2 || root.width <= 0 || root.height <= 0) return

    var step = root.width / Math.max(1, values.length - 1)
    ctx.beginPath()
    ctx.moveTo(0, root.height)
    for (var i = 0; i < values.length; i++) {
      var y = root.height - Math.max(0, Math.min(1, values[i] / root.maximum)) * root.height
      ctx.lineTo(i * step, y)
    }
    ctx.lineTo(root.width, root.height)
    ctx.closePath()
    ctx.fillStyle = root.fillColor
    ctx.fill()

    ctx.beginPath()
    for (var j = 0; j < values.length; j++) {
      var lineY = root.height - Math.max(0, Math.min(1, values[j] / root.maximum)) * root.height
      if (j === 0) ctx.moveTo(0, lineY)
      else ctx.lineTo(j * step, lineY)
    }
    ctx.strokeStyle = root.lineColor
    ctx.lineWidth = Math.max(1, Screen.devicePixelRatio)
    ctx.stroke()
  }
}
