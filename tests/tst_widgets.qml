import QtQuick
import QtTest
import Quickshell
// The headless runner copies this entry point beside the plugin components.

FloatingWindow {
  visible: true
  implicitWidth: 1000
  implicitHeight: 720
  WidgetStore { id: store }
  DesktopWidget {
    id: card
    store: store
    screenName: "test-screen"
    widgetId: "disk"
    title: "Disk"
    defaultX: 100; defaultY: 100
    Rectangle { width: parent.width; height: 140; color: "transparent" }
  }
  TestCase {
    id: testCase
    name: "DesktopWidgets"
    when: false
    function test_drag_cancel_save() {
      tryCompare(store, "loaded", true)
      store.begin()
      store.toggle("test-screen", "disk")
      tryCompare(card, "visible", true)
      var oldX = card.x, oldY = card.y
      mouseDrag(card, 70, 12, 120, 90, Qt.LeftButton)
      tryVerify(function() { return card.x > oldX + 80 && card.y > oldY + 50 })
      verify(store.item("test-screen", "disk").x > 0)
      store.finish(false)
      compare(card.visible, false)
      compare(store.item("test-screen", "disk").x, undefined)
      store.begin()
      store.toggle("test-screen", "disk")
      mouseDrag(card, 70, 12, 120, 90, Qt.LeftButton)
      store.finish(true)
      tryCompare(store, "directoryReady", true)
      compare(store.error, "")
      var expected = store.item("test-screen", "disk").x
      wait(200)
      var fresh = Qt.createQmlObject('import "."; WidgetStore {}', card.parent)
      tryCompare(fresh, "loaded", true)
      compare(fresh.item("test-screen", "disk").enabled, true)
      compare(fresh.item("test-screen", "disk").x, expected)
      fresh.destroy()
      store.begin()
      store.place("test-screen", "disk", {x: 0.9, y: 0.9})
      verify(store.setCity("  Den Helder  "))
      wait(200)
      fresh = Qt.createQmlObject('import "."; WidgetStore {}', card.parent)
      tryCompare(fresh, "loaded", true)
      compare(fresh.layout.weatherCity, "Den Helder", "location saves during layout editing")
      compare(fresh.item("test-screen", "disk").x, expected, "location save does not save draft positions")
      fresh.destroy()
      store.finish(false)
      compare(store.layout.weatherCity, "Den Helder", "layout Cancel does not revert location")
      compare(store.item("test-screen", "disk").x, expected)
    }
  }
  Timer {
    interval: 300; running: true
    onTriggered: {
      try { testCase.test_drag_cancel_save(); console.log("WIDGET_UI_PASS") }
      catch (error) { console.error("WIDGET_UI_FAIL", String(error)) }
      Qt.quit()
    }
  }
}
