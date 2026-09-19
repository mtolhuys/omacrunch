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
  property bool arranging: false
  property string dragId: ""
  property string dropBeforeId: ""
  property real dragX: 0
  property real dragOffset: 0
  property real markerX: 0
  property bool validDrop: false
  property string lastGesture: "idle"
  readonly property bool expanded: entryIds.length > 0 && (pinned || peek || panelHeld || arranging)
  readonly property bool orderReady: hostBar.pluginOrderStore.loaded && !hostBar.pluginOrderStore.saving
  readonly property bool overflow: widgetsRow.width > Math.max(0, openWidth - handleWidth - 8) + 1
  readonly property real handleWidth: 32
  readonly property real openWidth: Math.min(Math.max(0, width - 12), handleWidth + widgetsRow.width + 8)
  readonly property alias handle: handleButton
  readonly property alias surface: capsule
  readonly property alias scrollPosition: viewport.contentX
  readonly property alias contentWidth: widgetsRow.width
  property real animatedWidth: expanded ? openWidth : Math.min(handleWidth, width)
  signal diagnosticsChanged()
  onWidthChanged: cancelDrag()

  function syncEntries() {
    var ids = hostBar.pluginEntries.map(function(entry) { return entry.id })
    if (ShelfModel.sameIds(ids, entryIds)) return
    cancelDrag() // A rescan, disable or another monitor's reorder invalidates a drag.
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
    if (ids.length < 2) arranging = false
  }

  function setArranging(value) {
    if (value && (!orderReady || entryIds.length < 2 || panelHeld || hostBar.activePopout)) return false
    cancelDrag()
    arranging = value
    hostBar.hideTooltip(null)
    if (!value && !hover.hovered) closeDelay.restart()
    return true
  }

  function hostAt(point) {
    for (var index = 0; index < hosts.count; index++) {
      var item = hosts.itemAt(index)
      if (item && item.width > 0 && point >= item.x && point < item.x + item.width) return item
    }
    return null
  }

  function startDrag(point) {
    lastGesture = "press:" + Math.round(point)
    if (!arranging || !orderReady || panelHeld) { lastGesture += ":blocked"; return }
    var item = hostAt(point + viewport.contentX)
    if (!item) { lastGesture += ":no-item"; return }
    dragId = item.entryId
    dragOffset = point + viewport.contentX - item.x
    updateDrag(point, height / 2)
    hostBar.hideTooltip(null)
  }

  function updateDrag(point, y) {
    if (!dragId) return
    dragX = point + viewport.contentX - dragOffset
    validDrop = point >= 0 && point <= viewport.width && y >= 0 && y <= height
    dropBeforeId = ""
    markerX = widgetsRow.width
    for (var index = 0; index < hosts.count; index++) {
      var item = hosts.itemAt(index)
      if (item && item.entryId !== dragId && item.width > 0
          && point + viewport.contentX < item.x + item.width / 2) {
        dropBeforeId = item.entryId
        markerX = item.x
        break
      }
    }
  }

  function cancelDrag() { dragId = ""; validDrop = false }

  function finishDrag(moved) {
    var next = ShelfModel.moveId(entryIds, dragId, dropBeforeId)
    var save = moved && validDrop && !ShelfModel.sameIds(next, entryIds)
    lastGesture = "release:" + dragId + ":moved=" + moved + ":valid=" + validDrop + ":save=" + save
    cancelDrag()
    if (save) hostBar.savePluginOrder(next)
  }

  function syncPanels() {
    var held = false
    for (var index = 0; index < hosts.count; index++) {
      var item = hosts.itemAt(index)
      if (item && item.panelHeld) held = true
    }
    panelHeld = held
    if (held && arranging) setArranging(false)
    if (held) closeDelay.stop()
    else if (!hover.hovered) closeDelay.restart()
  }

  function scrollBy(amount) {
    viewport.contentX = Math.max(0, Math.min(widgetsRow.width - viewport.width,
      viewport.contentX + amount))
  }

  function state() {
    var inputPoint = arrangeMouse.mapToItem(shelf, 0, 0)
    return { screen: screenName, ids: entryIds, expanded: expanded, pinned: pinned,
      gesture: lastGesture, input: {x: shelf.x + inputPoint.x, y: inputPoint.y,
        width: arrangeMouse.width, height: arrangeMouse.height,
        enabled: arrangeMouse.enabled, visible: arrangeMouse.visible, pressed: arrangeMouse.pressed},
      arranging: arranging, dragging: dragId, orderReady: orderReady,
      orderError: hostBar.pluginOrderStore.error,
      held: panelHeld, overflow: overflow, width: Math.round(capsule.width),
      contentWidth: Math.round(widgetsRow.width), scroll: Math.round(viewport.contentX),
      x: Math.round(shelf.x + capsule.x),
      right: Math.round(shelf.x + capsule.x + capsule.width),
      anchorRight: Math.round(shelf.x + shelf.width),
      handleX: Math.round(shelf.x + capsule.x + handleButton.x + handleWidth / 2) }
  }

  Connections {
    target: shelf.hostBar
    function onPluginEntriesChanged() { shelf.syncEntries() }
    function onActivePopoutChanged() {
      if (shelf.hostBar.activePopout && shelf.arranging) shelf.setArranging(false)
    }
  }
  Component.onCompleted: syncEntries()
  ListModel { id: entriesModel }
  Behavior on animatedWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

  Timer { id: openDelay; interval: 110; onTriggered: shelf.peek = true }
  Timer {
    id: closeDelay
    interval: 450
    onTriggered: if (!hover.hovered && !shelf.panelHeld && !shelf.arranging) shelf.peek = false
  }

  Item {
    id: capsule
    // Dock to the status section. The rightmost handle stays still while the
    // plugin strip reveals toward the left, leaving the middle of the bar calm.
    x: shelf.width - width
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
      x: Math.max(0, capsule.width - width)
      width: shelf.handleWidth
      height: parent.height
      property bool tooltipHovered: handleMouse.containsMouse
      Row {
        visible: !shelf.arranging && !shelf.hostBar.pluginOrderStore.error
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
      Text {
        anchors.centerIn: parent
        visible: shelf.arranging || !!shelf.hostBar.pluginOrderStore.error
        text: shelf.hostBar.pluginOrderStore.error ? "!" : "✓"
        textFormat: Text.PlainText
        color: shelf.hostBar.pluginOrderStore.error ? shelf.hostBar.urgent : shelf.hostBar.foreground
        font.pixelSize: 16
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
          shelf.hostBar.hideTooltip(handleButton)
          if (shelf.arranging) shelf.setArranging(false)
          else if (mouse.button === Qt.RightButton) {
            if (!shelf.setArranging(true)) shelf.hostBar.showTooltip(handleButton,
              "Close plugin panels before arranging · at least two plugins required")
          } else shelf.pinned = !shelf.pinned
        }
        onEntered: shelf.hostBar.showTooltip(handleButton,
          shelf.hostBar.pluginOrderStore.error || (shelf.arranging
            ? "Drag plugins to reorder · release to save · click ✓ when done"
            : "Plugins · " + shelf.entryIds.length
              + (shelf.pinned ? " · click to unpin" : " · click to pin") + " · right-click to arrange"))
        onExited: shelf.hostBar.hideTooltip(handleButton)
      }
    }

    Item {
      id: contents
      width: Math.max(0, capsule.width - shelf.handleWidth)
      height: parent.height
      // Keep each icon's final coordinates even while clipped out. A panel
      // opened via IPC/shortcut must not acquire a moving animation anchor.
      readonly property real stripWidth: Math.max(0, shelf.openWidth - shelf.handleWidth)
      readonly property real stripX: width - stripWidth
      clip: true
      enabled: shelf.expanded
      opacity: shelf.expanded ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 140 } }

      Flickable {
        id: viewport
        x: contents.stripX + (shelf.overflow ? 20 : 4)
        width: Math.max(0, contents.stripWidth - (shelf.overflow ? 40 : 8))
        height: parent.height
        contentWidth: widgetsRow.width
        contentHeight: height
        clip: true
        interactive: false // never steal a plugin's click, drag or wheel gesture
        onWidthChanged: { shelf.cancelDrag(); shelf.scrollBy(0) }
        Row {
          id: widgetsRow
          height: parent.height
          spacing: 0
          move: Transition { NumberAnimation { properties: "x"; duration: 160; easing.type: Easing.OutCubic } }
          Repeater {
            id: hosts
            model: entriesModel
            delegate: PluginWidgetHost {
              id: pluginHost
              required property string entryId
              hostBar: shelf.hostBar
              moduleId: entryId
              screenName: shelf.screenName
              revealHeld: shelf.expanded
              interactionBlocked: shelf.arranging
              z: shelf.dragId === entryId ? 2 : 0
              transform: Translate { x: shelf.dragId === pluginHost.entryId ? shelf.dragX - pluginHost.x : 0 }
              width: implicitWidth
              height: widgetsRow.height
              onPanelHeldChanged: shelf.syncPanels()
              Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                visible: shelf.arranging
                color: "transparent"
                border.width: 1
                border.color: shelf.hostBar.foreground
                opacity: shelf.dragId === pluginHost.entryId ? 0.85 : 0.2
              }
            }
            onItemRemoved: Qt.callLater(shelf.syncPanels)
          }
        }
        Rectangle {
          x: Math.max(0, Math.min(viewport.width - 2, shelf.markerX - viewport.contentX - 1))
          y: 2; width: 2; height: parent.height - 4
          color: shelf.hostBar.foreground
          visible: shelf.dragId !== "" && shelf.validDrop
          z: 5
          parent: viewport
        }
        MouseArea {
          id: arrangeMouse
          parent: viewport
          width: viewport.width; height: viewport.height
          z: 10
          enabled: shelf.arranging
          hoverEnabled: true
          preventStealing: true
          cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
          property real pressX: 0
          property bool moved: false
          onPressed: function(mouse) { pressX = mouse.x; moved = false; shelf.startDrag(mouse.x) }
          onPositionChanged: function(mouse) {
            if (!pressed) return
            if (Math.abs(mouse.x - pressX) >= 6) moved = true
            shelf.updateDrag(mouse.x, mouse.y)
          }
          onReleased: function(mouse) {
            shelf.updateDrag(mouse.x, mouse.y)
            shelf.finishDrag(moved)
          }
          onCanceled: shelf.cancelDrag()
          onWheel: function(wheel) {
            if (shelf.dragId) return
            shelf.scrollBy(wheel.angleDelta.y > 0 ? -60 : 60)
            wheel.accepted = true
          }
        }
        // Only runs at an overflow edge during an explicit drag; idle cost is zero.
        Timer {
          interval: 40; repeat: true
          running: !!shelf.dragId && shelf.validDrop && shelf.overflow
            && (arrangeMouse.mouseX < 18 || arrangeMouse.mouseX > viewport.width - 18)
          onTriggered: {
            shelf.scrollBy(arrangeMouse.mouseX < 18 ? -8 : 8)
            shelf.updateDrag(arrangeMouse.mouseX, arrangeMouse.mouseY)
          }
        }
      }

      Repeater {
        model: [-1, 1]
        delegate: Item {
          required property int modelData
          width: 20; height: contents.height
          x: contents.stripX + (modelData < 0 ? 0 : contents.stripWidth - width)
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
