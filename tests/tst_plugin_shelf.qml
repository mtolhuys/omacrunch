import QtQuick
import QtTest
import Quickshell

FloatingWindow {
  id: window
  visible: true
  implicitWidth: 1000
  implicitHeight: 300
  color: "#151515"
  property int creations: 0
  property var registered: []

  QtObject {
    id: mockBar
    property var pluginEntries: [
      {id: "a", pluginId: "a", settings: {id: "a", label: "one"}},
      {id: "b", pluginId: "b", settings: {id: "b", label: "two"}}
    ]
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
      implicitWidth: 72
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
  TestCase {
    id: testCase
    name: "PluginShelf"
    when: false
    function test_shelf() {
      tryCompare(window, "creations", 2)
      compare(shelf.expanded, false)
      var first = mockBar.moduleWidgets("a")[0]
      var second = mockBar.moduleWidgets("b")[0]
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
      compare(first.bar.clickTargets.length, 1)
      compare(first.bar.clickTargets[0], first)
      wait(240)
      compare(shelf.surface.width, shelf.openWidth)
      mouseMove(window.contentItem, 900, 200)
      wait(160)
      compare(shelf.expanded, true, "leave grace")
      tryCompare(shelf, "expanded", false)
      compare(mockBar.clickTargets.length, 0)
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
      mockBar.pluginEntries = [
        {id: "a", pluginId: "a", settings: {id: "a", label: "updated"}},
        {id: "b", pluginId: "b", settings: {id: "b", label: "two"}}
      ]
      tryCompare(first.settings, "label", "updated")
      compare(window.creations, 2, "settings updates must not recreate widgets")
      mockBar.pluginEntries = [mockBar.pluginEntries[0],
        {id: "c", pluginId: "c", settings: {id: "c", label: "three"}}, mockBar.pluginEntries[1]]
      tryCompare(window, "creations", 3)
      compare(mockBar.moduleWidgets("a")[0], first, "registry arrivals preserve earlier widgets")
      compare(mockBar.moduleWidgets("b")[0], second)
      mockBar.pluginEntries = [mockBar.pluginEntries[2], mockBar.pluginEntries[0], mockBar.pluginEntries[1]]
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
      mockBar.pluginEntries = []
      tryCompare(window.registered, "length", 0)
      compare(mockBar.activePopout, null, "unloading releases popout")
      compare(mockBar.clickTargets.length, 0, "unloading removes click targets")
      compare(shelf.expanded, false)
    }
  }
  Timer {
    interval: 300; running: true
    onTriggered: {
      try { testCase.test_shelf(); console.log("SHELF_UI_PASS") }
      catch (error) { console.error("SHELF_UI_FAIL", String(error)) }
      Qt.quit()
    }
  }
}
