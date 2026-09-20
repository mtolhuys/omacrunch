import QtQuick
import Quickshell
import "omakit" as Omakit

Item {
  id: root
  required property string kind
  property bool active: false
  property string city: ""
  property int interval: 60000
  property int retryInterval: 60000
  property var report: ({})
  property string error: ""
  property bool needsLocation: false
  property int revision: 0
  property int runningRevision: 0
  property string runningCity: ""
  property bool inFlight: false
  property bool pendingRefresh: false
  readonly property string collectorPath: decodeURIComponent(String(Qt.resolvedUrl("widget-data.py")).replace(/^file:\/\//, ""))
  readonly property bool busy: inFlight || pendingRefresh
  readonly property int pollInterval: error ? Math.min(interval, retryInterval) : interval

  function refresh() {
    if (!active) return
    pendingRefresh = true
    Qt.callLater(startPending)
  }
  function startPending() {
    // A stopped Process is not finished until exited arrives. Starting sooner
    // lets the cancelled request overwrite the new city's result/error.
    if (!active || !pendingRefresh || inFlight || collector.running) return
    pendingRefresh = false
    runningRevision = revision
    runningCity = city
    error = ""
    inFlight = true
    collector.command = ["/usr/bin/python3", "-I", "-S", "-B",
      root.collectorPath, root.kind, root.runningCity]
    collector.start()
  }
  function invalidate() {
    revision++
    pendingRefresh = active
    if (inFlight) collector.cancel()
    else Qt.callLater(startPending)
  }
  function acceptResponse(result) {
    if (result.state === "timeout") { error = "Request timed out; will retry."; return }
    if (result.state !== "ok") { error = "Data request failed (" + result.state + "); will retry."; return }
    try {
      var next = JSON.parse(result.stdout)
      if (!next || typeof next !== "object" || Array.isArray(next)) throw new Error("Invalid response")
      needsLocation = next.needsLocation === true
      if (next.error) error = String(next.error)
      else { report = next; error = "" }
    } catch (e) { error = "Invalid response; will retry." }
  }
  onActiveChanged: {
    if (active) refresh()
    else invalidate()
  }
  onCityChanged: {
    report = ({})
    needsLocation = false
    error = ""
    invalidate()
  }
  Component.onCompleted: if (active) refresh()
  Timer { interval: root.pollInterval; running: root.active; repeat: true; onTriggered: root.refresh() }

  Omakit.Run {
    id: collector
    objectName: "request-run"
    deadlineMs: 18000
    maxBytes: 65536
    keepBytes: 65536
    maxLines: 2048
    environment: {
      var result = {}
      var stateHome = Quickshell.env("XDG_STATE_HOME")
      if (stateHome) result.XDG_STATE_HOME = stateHome
      return result
    }
    onFinished: function(result) {
      root.inFlight = false
      if (!root.active) return
      if (root.runningRevision === root.revision) root.acceptResponse(result)
      if (root.pendingRefresh) Qt.callLater(root.startPending)
    }
  }
}
