import QtQuick
import QtTest
import Quickshell

FloatingWindow {
  visible: true
  implicitWidth: 600
  implicitHeight: 400

  WidgetFeed { id: feed; kind: "weather"; interval: 900000 }
  Component {
    id: sessionComponent
    Item {
      property alias store: sessionStore
      property alias weather: sessionFeed
      WidgetStore { id: sessionStore }
      WidgetFeed {
        id: sessionFeed
        kind: "weather"
        active: sessionStore.loaded && sessionStore.enabled("test-screen", "weather")
        city: sessionStore.layout.weatherCity
        interval: 900000
      }
      Connections {
        target: sessionStore
        function onWeatherLocationSaved() { sessionFeed.refresh() }
      }
    }
  }
  TestCase {
    id: testCase
    name: "WidgetFeed"
    when: false
    function test_location_during_request() {
      feed.city = "Previous city"
      feed.active = true
      tryCompare(feed, "busy", true)
      wait(20)
      feed.city = "Den Helder"
      tryVerify(function() { return feed.report.city === "Den Helder" }, 4000)
      compare(feed.error, "")
      feed.active = false
    }
    function test_quick_changes_and_reenable() {
      feed.city = "Old"
      feed.active = true
      tryCompare(feed, "inFlight", true)
      feed.city = "Intermediate"
      feed.city = "Latest"
      feed.active = false
      feed.active = true
      tryVerify(function() { return feed.report.city === "Latest" }, 4000)
      compare(feed.error, "")
      feed.active = false
      tryCompare(feed, "busy", false)
    }
    function test_failures_and_retry() {
      feed.city = "process-failure"
      feed.active = true
      tryVerify(function() { return feed.error !== "" }, 4000)
      compare(feed.pollInterval, 60000)
      compare(feed.needsLocation, false)
      feed.city = "network-failure"
      feed.report = {city: "network-failure", current: {temperature_2m: 16}}
      tryCompare(feed, "error", "Network unavailable; will retry.")
      compare(feed.report.current.temperature_2m, 16, "retain last known conditions on failure")
      feed.city = ""
      tryCompare(feed, "needsLocation", true)
      feed.retryInterval = 80
      feed.city = "recover-on-retry"
      tryVerify(function() { return feed.report.city === "recover-on-retry" }, 4000)
      compare(feed.error, "")
      compare(feed.needsLocation, false)
      compare(feed.pollInterval, 900000)
      feed.active = false
    }
    function test_timeout_and_recovery() {
      var deadline = findChild(feed, "request-deadline")
      verify(!!deadline)
      deadline.interval = 50
      feed.city = "slow-response"
      feed.active = true
      tryCompare(feed, "error", "Request timed out; will retry.")
      tryCompare(feed, "busy", false)
      compare(feed.report.city, undefined)
      deadline.interval = 18000
      feed.city = "Den Helder"
      tryVerify(function() { return feed.report.city === "Den Helder" }, 4000)
      compare(feed.error, "")
      feed.active = false
    }
    function test_saved_location_on_fresh_session() {
      var session = sessionComponent.createObject(testCase)
      tryCompare(session.store, "loaded", true)
      session.store.toggle("test-screen", "weather")
      verify(session.store.setCity("  Den Helder  "))
      tryVerify(function() { return session.weather.report.city === "Den Helder" }, 4000)
      // Re-entering the same city also refreshes: no backspace workaround.
      session.weather.report = ({})
      verify(session.store.setCity("Den Helder"))
      tryVerify(function() { return session.weather.report.city === "Den Helder" }, 4000)
      session.destroy()
      wait(150)
      session = sessionComponent.createObject(testCase)
      tryCompare(session.store, "loaded", true)
      compare(session.store.layout.weatherCity, "Den Helder")
      tryVerify(function() { return session.weather.report.city === "Den Helder" }, 4000)
      compare(session.weather.error, "")
      session.destroy()
    }
  }
  Timer {
    interval: 300; running: true
    onTriggered: {
      try {
        testCase.test_location_during_request()
        testCase.test_quick_changes_and_reenable()
        testCase.test_failures_and_retry()
        testCase.test_timeout_and_recovery()
        testCase.test_saved_location_on_fresh_session()
        console.log("WIDGET_FEED_PASS")
      }
      catch (error) { console.error("WIDGET_FEED_FAIL", String(error)) }
      Qt.quit()
    }
  }
}
