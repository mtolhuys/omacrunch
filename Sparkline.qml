import QtQuick
import qs.Commons

Canvas {
  id: root

  property var samples: []
  property color lineColor: Color.foreground
  property color lineColorRight: lineColor
  property color outlineColor: "transparent"
  property color outlineColorRight: outlineColor
  property color fillColor: Util.alpha(lineColor, 0.12)
  property real maximum: 100

  onSamplesChanged: requestPaint()
  onLineColorChanged: requestPaint()
  onLineColorRightChanged: requestPaint()
  onOutlineColorChanged: requestPaint()
  onOutlineColorRightChanged: requestPaint()
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
    var outlineGradient = ctx.createLinearGradient(0, 0, root.width, 0)
    outlineGradient.addColorStop(0, root.outlineColor)
    outlineGradient.addColorStop(1, root.outlineColorRight)
    ctx.strokeStyle = outlineGradient
    ctx.lineWidth = Math.max(2, Screen.devicePixelRatio * 2)
    ctx.stroke()
    var lineGradient = ctx.createLinearGradient(0, 0, root.width, 0)
    lineGradient.addColorStop(0, root.lineColor)
    lineGradient.addColorStop(1, root.lineColorRight)
    ctx.strokeStyle = lineGradient
    ctx.lineWidth = Math.max(1, Screen.devicePixelRatio)
    ctx.stroke()
  }
}
