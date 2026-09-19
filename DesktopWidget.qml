import QtQuick
import qs.Commons
import "WidgetLayout.js" as Layout

Item {
  id: root
  required property var store
  required property string screenName
  required property string widgetId
  required property string title
  property real defaultX: 20
  property real defaultY: 54
  property bool adaptiveSurface: true
  property string wallpaper: ""
  property int wallpaperRevision: 0
  property bool dragging: false
  property real dragX: 0
  property real dragY: 0
  default property alias content: contentItem.data
  readonly property var placement: Layout.position(store.item(screenName, widgetId), defaultX, defaultY,
    width, height, parent ? parent.width : 1, parent ? parent.height : 1)
  readonly property var tone: sampler.zones.whole || { useLight: true, minimumContrast: 1, requiredExtremeOpacity: 0.8 }
  readonly property color ink: tone.useLight ? "#f2f2f2" : "#111111"
  readonly property real surfaceOpacity: Number(tone.minimumContrast) >= 4.5 ? 0
    : Math.min(0.94, Math.max(0.22, Number(tone.requiredExtremeOpacity || 0.8) + 0.08))
  readonly property real contentHeight: contentItem.childrenRect.height

  width: Math.min(Style.space(310), parent ? parent.width - 24 : 310)
  height: contentHeight + (adaptiveSurface ? Style.space(28) : 0) + (store.editing ? Style.space(28) : 0)
  x: dragging ? dragX : placement.x
  y: dragging ? dragY : placement.y
  visible: store.enabled(screenName, widgetId)
  z: dragging ? 20 : 4

  WallpaperTone {
    id: sampler
    sourcePath: root.visible && root.adaptiveSurface && !root.dragging ? root.wallpaper : ""
    revision: root.wallpaperRevision
    screenWidth: root.parent ? root.parent.width : 1
    screenHeight: root.parent ? root.parent.height : 1
    sampleRect: Qt.rect(root.x, root.y, root.width, root.height)
  }
  Rectangle {
    anchors.fill: parent
    color: root.store.editing ? Color.menu.background
      : (root.adaptiveSurface ? Util.alpha(root.tone.useLight ? "#000000" : "#ffffff", root.surfaceOpacity) : "transparent")
    border.width: root.store.editing || (root.adaptiveSurface && root.surfaceOpacity > 0) ? 1 : 0
    border.color: root.store.editing ? Color.menu.border : Util.alpha(root.ink, 0.35)
    radius: Style.space(2)
  }
  Item {
    id: contentItem
    x: root.adaptiveSurface ? Style.space(14) : 0
    y: (root.store.editing ? Style.space(28) : 0) + (root.adaptiveSurface ? Style.space(14) : 0)
    width: root.width - (root.adaptiveSurface ? Style.space(28) : 0)
    height: childrenRect.height
  }
  Rectangle {
    visible: root.store.editing
    width: parent.width
    height: Style.space(28)
    color: Util.alpha(Color.menu.text, 0.1)
    Text {
      anchors.centerIn: parent
      text: "⠿  " + root.title + "  ·  drag to move"
      textFormat: Text.PlainText
      color: Color.menu.text
      font.family: "monospace"
      font.pixelSize: Style.font.caption
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
      property point pressPoint
      property point startPoint
      onPressed: function(mouse) {
        pressPoint = mapToItem(root.parent, mouse.x, mouse.y)
        startPoint = Qt.point(root.x, root.y)
        root.dragX = root.x; root.dragY = root.y; root.dragging = true
      }
      onPositionChanged: function(mouse) {
        if (!pressed) return
        var point = mapToItem(root.parent, mouse.x, mouse.y)
        root.dragX = Layout.clamp(startPoint.x + point.x - pressPoint.x, 12, Math.max(12, root.parent.width - root.width - 12))
        root.dragY = Layout.clamp(startPoint.y + point.y - pressPoint.y, 46, Math.max(46, root.parent.height - root.height - 12))
      }
      onReleased: {
        root.store.place(root.screenName, root.widgetId,
          Layout.fraction(root.x, root.y, root.width, root.height, root.parent.width, root.parent.height))
        root.dragging = false
      }
      onCanceled: root.dragging = false
    }
  }
}
