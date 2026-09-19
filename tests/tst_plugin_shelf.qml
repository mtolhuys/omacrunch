import QtQuick
import QtTest
import Quickshell
import "PluginShelfModel.js" as ShelfModel

FloatingWindow {
  id: window
  visible: true
  implicitWidth: 1000
  implicitHeight: 300
  color: "#151515"
  property int creations: 0
  property var registered: []
  PluginOrderStore { id: orderStore }

  QtObject {
    id: mockBar
    property var configuredEntries: [
      {id: "a", pluginId: "a", settings: {id: "a", label: "one"}},
      {id: "b", pluginId: "b", settings: {id: "b", label: "two"}}
    ]
    readonly property var pluginEntries: ShelfModel.orderedEntries(configuredEntries, orderStore.order)
    readonly property alias pluginOrderStore: orderStore
    function savePluginOrder(ids) { return orderStore.save(ids) }
    property var activePopout: null
    property var clickTargets: []
    property var layoutConfig: ({center: pluginEntries})
    property var shell: QtObject {
      property bool refuse: false
      function pluginShellForBarEntry(owner, moduleName) { return refuse ? null : {pluginId: moduleName} }
    }
    property color foreground: "white"
    property color barForeground: "white"
    property color background: "black"
    property color urgent: "red"
    property string fontFamily: "monospace"
    property string position: "top"
    property bool vertical: false
    property bool transparent: false
    property bool foregroundAnimationEnabled: true
    property int barSize: 30
    function pluginEntry(id) { return pluginEntries.find(function(entry) { return entry.id === id }) }
    function widgetComponent(id) { return mockWidget }
    function registerWidget(id, region, screenName, widget) {
      unregisterWidget(widget)
      window.registered = window.registered.concat([{id: id, item: widget}])
    }
    function unregisterWidget(widget) {
      window.registered = window.registered.filter(function(record) { return record.item !== widget })
    }
    function moduleWidgets(id) {
      return window.registered.filter(function(record) { return record.id === id })
        .map(function(record) { return record.item })
    }
    function registerClickTarget(target) { clickTargets = clickTargets.concat([target]) }
    function unregisterClickTarget(target) { clickTargets = clickTargets.filter(function(t) { return t !== target }) }
    function requestPopout(owner) {
      if (activePopout && activePopout !== owner) activePopout.close()
      activePopout = owner
    }
    function releasePopout(owner) { if (activePopout === owner) activePopout = null }
    function showTooltip(target, text) {}
    function hideTooltip(target) {}
    function targetBelongsToWindow(target, window) { return true }
    function switchPluginPanel(id, screen, direction) { return false }
    function run(command) {}
  }
  LegacyPluginShell {
    id: legacyTest
    pluginId: "self"
    moduleName: "self-entry"
    legacyShell: QtObject {
      property var barConfig: ({})
      function serviceFor(id) { return id }
      function updateEntryInline(id, settings) { return id }
    }
  }
  Component {
    id: mockWidget
    Rectangle {
      id: button
      property var bar: null
      property string moduleName: ""
      property var settings: ({})
      property bool opened: false
      color: opened ? "#555555" : "#222222"
      implicitWidth: settings.width || 72
      implicitHeight: 30
      function open() { opened = true; bar.requestPopout(button) }
      function close() { opened = false; bar.releasePopout(button) }
      onBarChanged: if (bar) bar.registerClickTarget(button)
      Component.onCompleted: window.creations++
      Text { anchors.centerIn: parent; text: button.settings.label || "?"; color: "white" }
      MouseArea { anchors.fill: parent; onClicked: button.open() }
    }
  }
  PluginShelf { id: shelf; hostBar: mockBar; screenName: "test"; width: 800; height: 30 }
  Component {
    id: mirrorComponent
    PluginShelf { hostBar: mockBar; screenName: "second-screen"; width: 800; height: 30; y: 100 }
  }
  TestCase {
    id: testCase
    name: "PluginShelf"
    when: false
    function dragWidget(item, x, dx, dy) {
      // Use stable window coordinates: the widget itself follows the pointer.
      var point = item.mapToItem(window.contentItem, x, 15)
      mouseDrag(window.contentItem, point.x, point.y, dx, dy, Qt.LeftButton)
    }
    function test_shelf() {
      tryCompare(window, "creations", 2)
      compare(shelf.expanded, false)
      var first = mockBar.moduleWidgets("a")[0]
      var second = mockBar.moduleWidgets("b")[0]
      var restingHandleX = shelf.handle.mapToItem(window.contentItem, 16, 15).x
      var restingIconX = first.mapToItem(window.contentItem, 0, 0).x
      compare(shelf.surface.x + shelf.surface.width, shelf.width, "collapsed right edge is docked")
      verify(first.bar !== mockBar, "never inject host bar")
      compare(first.bar.pluginId, "a")
      compare(first.bar.shell.pluginId, "a")
      mockBar.shell.refuse = true
      compare(first.bar.shell, null, "scoped refusal must not fall back to legacy")
      mockBar.shell.refuse = false
      compare(legacyTest.serviceFor("self"), "self")
      compare(legacyTest.serviceFor("foreign"), null)
      compare(legacyTest.updateEntryInline("self-entry", {}), "self-entry")
      compare(legacyTest.updateEntryInline("foreign", {}), false)
      compare(first.bar.moduleWidgets("b").length, 0, "no foreign widget access")
      compare(first.bar.clickTargets.length, 0, "concealed targets cannot receive forwarded clicks")
      compare(mockBar.clickTargets.length, 0)
      mouseMove(shelf.handle, 16, 15)
      tryCompare(shelf, "expanded", true)
      wait(60)
      compare(shelf.handle.mapToItem(window.contentItem, 16, 15).x, restingHandleX,
        "handle stays fixed during reveal")
      compare(first.mapToItem(window.contentItem, 0, 0).x, restingIconX,
        "panel anchor stays fixed during reveal")
      compare(first.bar.clickTargets.length, 1)
      compare(first.bar.clickTargets[0], first)
      wait(240)
      compare(shelf.surface.width, shelf.openWidth)
      compare(shelf.surface.x + shelf.surface.width, shelf.width, "expanded right edge is docked")
      mouseMove(window.contentItem, 900, 200)
      wait(160)
      compare(shelf.expanded, true, "leave grace")
      tryCompare(shelf, "expanded", false)
      compare(mockBar.clickTargets.length, 0)
      wait(220)
      compare(shelf.handle.mapToItem(window.contentItem, 16, 15).x, restingHandleX,
        "handle stays fixed after collapse")
      compare(window.creations, 2, "hide must not unload")
      mouseClick(shelf.handle, 16, 15, Qt.LeftButton)
      tryCompare(shelf, "pinned", true)
      mouseMove(window.contentItem, 900, 200)
      wait(520)
      compare(shelf.expanded, true)
      shelf.pinned = false
      tryCompare(shelf, "expanded", false)
      // A real click on a child, not just an IPC toggle, must reach the widget.
      mouseMove(shelf.handle, 16, 15)
      tryCompare(shelf, "expanded", true)
      wait(240)
      mouseClick(first, 30, 15, Qt.LeftButton)
      tryCompare(first, "opened", true)
      mouseMove(window.contentItem, 900, 200)
      wait(650)
      compare(shelf.expanded, true, "popout holds anchor")
      compare(shelf.panelHeld, true)
      compare(second.bar.activePopout.foreign, true, "foreign popout is a marker, not object")
      first.close()
      tryCompare(shelf, "expanded", false)
      mockBar.configuredEntries = [
        {id: "a", pluginId: "a", settings: {id: "a", label: "updated"}},
        {id: "b", pluginId: "b", settings: {id: "b", label: "two"}}
      ]
      tryCompare(first.settings, "label", "updated")
      compare(window.creations, 2, "settings updates must not recreate widgets")
      mockBar.configuredEntries = [mockBar.pluginEntries[0],
        {id: "c", pluginId: "c", settings: {id: "c", label: "three"}}, mockBar.pluginEntries[1]]
      tryCompare(window, "creations", 3)
      compare(mockBar.moduleWidgets("a")[0], first, "registry arrivals preserve earlier widgets")
      compare(mockBar.moduleWidgets("b")[0], second)
      mockBar.configuredEntries = [mockBar.pluginEntries[2], mockBar.pluginEntries[0], mockBar.pluginEntries[1]]
      wait(50)
      compare(window.creations, 3, "reorder preserves instances")
      shelf.width = 120
      shelf.pinned = true
      wait(260)
      compare(shelf.overflow, true)
      shelf.scrollBy(100)
      verify(shelf.scrollPosition > 0)
      shelf.width = 800
      tryCompare(shelf, "overflow", false)
      tryCompare(shelf, "scrollPosition", 0)
      first.open()
      mockBar.configuredEntries = []
      tryCompare(window.registered, "length", 0)
      compare(mockBar.activePopout, null, "unloading releases popout")
      compare(mockBar.clickTargets.length, 0, "unloading removes click targets")
      compare(shelf.expanded, false)
    }

    function test_reorder() {
      tryCompare(orderStore, "loaded", true)
      mockBar.configuredEntries = [
        {id: "a", pluginId: "a", settings: {id: "a", label: "one"}},
        {id: "b", pluginId: "b", settings: {id: "b", label: "wide", width: 110}},
        {id: "c", pluginId: "c", settings: {id: "c", label: "three"}}
      ]
      shelf.pinned = false
      wait(260)
      mouseClick(shelf.handle, 16, 15, Qt.RightButton)
      tryCompare(shelf, "arranging", true)
      wait(260)
      var first = mockBar.moduleWidgets("a")[0]
      var second = mockBar.moduleWidgets("b")[0]
      var third = mockBar.moduleWidgets("c")[0]
      var count = window.creations
      compare(mockBar.clickTargets.length, 0, "arrangement disables forwarded clicks")
      mouseClick(first, 20, 15, Qt.LeftButton)
      compare(first.opened, false, "arrangement cannot launch plugins")
      compare(orderStore.order.length, 0, "click is not a drag")
      dragWidget(first, 20, 220, 0)
      tryVerify(function() { return shelf.entryIds.join() === "b,c,a" })
      tryCompare(orderStore, "saving", false)
      compare(orderStore.error, "")
      compare(window.creations, count, "drag preserves mounted widgets")
      var mirror = mirrorComponent.createObject(window.contentItem)
      tryVerify(function() { return mirror.entryIds.join() === "b,c,a" })
      wait(180)
      dragWidget(first, 20, -195, 0)
      tryVerify(function() { return shelf.entryIds.join() === "a,b,c" })
      compare(mirror.entryIds.join(), "a,b,c", "all monitors share the saved order")
      mirror.destroy()
      tryCompare(orderStore, "saving", false)
      wait(180)
      dragWidget(first, 20, 180, 70)
      compare(shelf.entryIds.join(), "a,b,c", "release outside bar cancels")
      mousePress(first, 20, 15, Qt.LeftButton)
      mockBar.configuredEntries = mockBar.configuredEntries.slice(0, 2)
      tryCompare(shelf, "dragId", "")
      mouseRelease(window.contentItem, 900, 200, Qt.LeftButton)
      compare(shelf.entryIds.join(), "a,b", "rescan cancels drag")
      wait(260)
      dragWidget(first, 20, 140, 0)
      tryVerify(function() { return shelf.entryIds.join() === "b,a" })
      tryCompare(orderStore, "saving", false)
      var fresh = Qt.createQmlObject('import "."; PluginOrderStore {}', window.contentItem)
      tryCompare(fresh, "loaded", true)
      compare(fresh.order.join(), orderStore.order.join(), "fresh instance restores persisted order")
      fresh.destroy()
      mouseClick(shelf.handle, 16, 15, Qt.LeftButton)
      compare(shelf.arranging, false)
      compare(shelf.pinned, false, "arranging preserves pin preference")
      mouseMove(shelf.handle, 16, 15)
      wait(260)
      mouseClick(second, 20, 15, Qt.LeftButton)
      tryCompare(second, "opened", true, 1000)
      compare(shelf.setArranging(true), false, "cannot move open popout anchor")
      second.close()
      // Remember hidden plugins and append newly configured ones without rewriting settings.
      mockBar.configuredEntries = mockBar.configuredEntries.concat([
        {id: "c", pluginId: "c", settings: {id: "c", label: "three"}},
        {id: "d", pluginId: "d", settings: {id: "d", label: "four"}}
      ])
      tryVerify(function() { return shelf.entryIds.join() === "b,a,c,d" })
      shelf.width = 180
      shelf.setArranging(true)
      wait(260)
      var source = mockBar.moduleWidgets("b")[0]
      mousePress(source, 8, 15, Qt.LeftButton)
      var edge = shelf.handle.mapToItem(window.contentItem, -27, 15)
      mouseMove(window.contentItem, edge.x, edge.y)
      wait(700)
      verify(shelf.scrollPosition > 0, "drag autoscrolls overflow edge")
      mouseRelease(window.contentItem, edge.x, edge.y)
      tryCompare(orderStore, "saving", false)
      shelf.setArranging(false)
      shelf.width = 800
    }
    function test_write_failure() {
      tryCompare(orderStore, "loaded", true)
      compare(orderStore.save(["b", "a"]), true)
      tryCompare(orderStore, "saving", false)
      verify(orderStore.error.indexOf("Previous order restored") >= 0)
      compare(orderStore.order.length, 0, "failed write rolls back optimistic order")
    }
  }
  Timer {
    interval: 300; running: true
    onTriggered: {
      try {
        if (Quickshell.env("OMACRUNCH_ORDER_FAILURE")) testCase.test_write_failure()
        else { testCase.test_shelf(); testCase.test_reorder() }
        console.log("SHELF_UI_PASS")
      }
      catch (error) { console.error("SHELF_UI_FAIL", String(error), error.stack) }
      Qt.quit()
    }
  }
}
