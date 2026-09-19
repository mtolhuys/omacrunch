import QtQuick
import "PluginShelfModel.js" as ShelfModel

Item {
  id: shelf
  required property var hostBar
  required property string screenName
  property var entryIds: []
  property bool pinned: false
  property bool peek: false
  property bool panelHeld: false
  readonly property bool expanded: entryIds.length > 0 && (pinned || peek || panelHeld)
  readonly property bool overflow: widgetsRow.width > Math.max(0, openWidth - handleWidth) + 1
  readonly property real handleWidth: 32
  readonly property real openWidth: Math.min(Math.max(0, width - 12), handleWidth + widgetsRow.width + 8)
  readonly property alias handle: handleButton
  readonly property alias surface: capsule
  readonly property alias scrollPosition: viewport.contentX
  readonly property alias contentWidth: widgetsRow.width
  property real animatedWidth: expanded ? openWidth : Math.min(handleWidth, width)
  signal diagnosticsChanged()

  function syncEntries() {
    var ids = hostBar.pluginEntries.map(function(entry) { return entry.id })
    if (ShelfModel.sameIds(ids, entryIds)) return
    // Registry components arrive incrementally during a shell rescan. A JS
    // array Repeater would rebuild every preceding plugin on each arrival.
    for (var removed = entriesModel.count - 1; removed >= 0; removed--)
      if (ids.indexOf(entriesModel.get(removed).entryId) < 0) entriesModel.remove(removed)
    for (var index = 0; index < ids.length; index++) {
      var existing = index
      while (existing < entriesModel.count && entriesModel.get(existing).entryId !== ids[index]) existing++
      if (existing === entriesModel.count) entriesModel.insert(index, {entryId: ids[index]})
      else if (existing !== index) entriesModel.move(existing, index, 1)
    }
    entryIds = ids
  }

  function syncPanels() {
    var held = false
    for (var index = 0; index < hosts.count; index++) {
      var item = hosts.itemAt(index)
      if (item && item.panelHeld) held = true
    }
    panelHeld = held
    if (held) closeDelay.stop()
    else if (!hover.hovered) closeDelay.restart()
  }

  function scrollBy(amount) {
    viewport.contentX = Math.max(0, Math.min(widgetsRow.width - viewport.width,
      viewport.contentX + amount))
  }

  function state() {
    return { screen: screenName, ids: entryIds, expanded: expanded, pinned: pinned,
      held: panelHeld, overflow: overflow, width: Math.round(capsule.width),
      contentWidth: Math.round(widgetsRow.width), scroll: Math.round(viewport.contentX),
      x: Math.round(shelf.x + capsule.x), handleX: Math.round(shelf.x + capsule.x + handleWidth / 2) }
  }

  Connections {
    target: shelf.hostBar
    function onPluginEntriesChanged() { shelf.syncEntries() }
  }
  Component.onCompleted: syncEntries()
  ListModel { id: entriesModel }
  Behavior on animatedWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

  Timer { id: openDelay; interval: 110; onTriggered: shelf.peek = true }
  Timer {
    id: closeDelay
    interval: 450
    onTriggered: if (!hover.hovered && !shelf.panelHeld) shelf.peek = false
  }

  Item {
    id: capsule
    // The handle stays still during reveal, so hover never moves a target
    // out from under the pointer. The expanded shelf is centered in free space.
    x: Math.max(0, (shelf.width - shelf.openWidth) / 2)
    width: shelf.animatedWidth
    height: shelf.height
    visible: shelf.entryIds.length > 0

    Rectangle {
      anchors.fill: parent
      color: shelf.hostBar.foreground
      opacity: shelf.expanded ? 0.06 : (hover.hovered ? 0.035 : 0)
      Behavior on opacity { NumberAnimation { duration: 180 } }
    }
    HoverHandler {
      id: hover
      onHoveredChanged: {
        if (hovered) { closeDelay.stop(); openDelay.restart() }
        else { openDelay.stop(); if (!shelf.panelHeld) closeDelay.restart() }
      }
    }

    Item {
      id: handleButton
      width: shelf.handleWidth
      height: parent.height
      property bool tooltipHovered: handleMouse.containsMouse
      Row {
        anchors.centerIn: parent
        spacing: 3
        Repeater {
          model: 3
          Rectangle {
            width: 3; height: shelf.pinned ? 8 : 3
            radius: 1
            color: shelf.hostBar.foreground
            opacity: shelf.expanded || handleMouse.containsMouse ? 0.9 : 0.38
            Behavior on height { NumberAnimation { duration: 140 } }
          }
        }
      }
      Rectangle {
        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
        width: 14; height: 2
        color: shelf.hostBar.foreground
        opacity: shelf.pinned ? 0.7 : 0
      }
      MouseArea {
        id: handleMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
          shelf.pinned = mouse.button === Qt.RightButton ? false : !shelf.pinned
          shelf.hostBar.hideTooltip(handleButton)
        }
        onEntered: shelf.hostBar.showTooltip(handleButton,
          "Plugins · " + shelf.entryIds.length + (shelf.pinned ? " · click to unpin" : " · click to pin"))
        onExited: shelf.hostBar.hideTooltip(handleButton)
      }
    }

    Item {
      id: contents
      x: shelf.handleWidth
      width: Math.max(0, capsule.width - x)
      height: parent.height
      clip: true
      enabled: shelf.expanded
      opacity: shelf.expanded ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 140 } }

      Flickable {
        id: viewport
        x: shelf.overflow ? 20 : 0
        width: Math.max(0, contents.width - (shelf.overflow ? 40 : 0))
        height: parent.height
        contentWidth: widgetsRow.width
        contentHeight: height
        clip: true
        interactive: false // never steal a plugin's click, drag or wheel gesture
        onWidthChanged: shelf.scrollBy(0)
        Row {
          id: widgetsRow
          height: parent.height
          spacing: 0
          Repeater {
            id: hosts
            model: entriesModel
            delegate: PluginWidgetHost {
              required property string entryId
              hostBar: shelf.hostBar
              moduleId: entryId
              screenName: shelf.screenName
              revealHeld: shelf.expanded
              width: implicitWidth
              height: widgetsRow.height
              onPanelHeldChanged: shelf.syncPanels()
            }
            onItemRemoved: Qt.callLater(shelf.syncPanels)
          }
        }
      }

      Repeater {
        model: [-1, 1]
        delegate: Item {
          required property int modelData
          width: 20; height: contents.height
          x: modelData < 0 ? 0 : contents.width - width
          visible: shelf.overflow
          Text {
            anchors.centerIn: parent
            text: parent.modelData < 0 ? "‹" : "›"
            textFormat: Text.PlainText
            color: shelf.hostBar.foreground
            font.pixelSize: 18
            opacity: mouse.containsMouse ? 1 : 0.55
          }
          MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: !shelf.panelHeld // preserve a popout's anchor while open
            onClicked: shelf.scrollBy(parent.modelData * Math.max(40, viewport.width * 0.6))
          }
        }
      }
    }
  }
}
