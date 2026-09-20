import QtQuick
import Quickshell.Io

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
  property string buffer: ""
  property int revision: 0
  property int runningRevision: 0
  property string runningCity: ""
  property bool inFlight: false
  property bool pendingRefresh: false
  property bool timedOut: false
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
    buffer = ""
    error = ""
    timedOut = false
    inFlight = true
    deadline.restart()
    collector.running = true
  }
  function invalidate() {
    revision++
    pendingRefresh = active
    if (inFlight) collector.running = false
    else Qt.callLater(startPending)
  }
  function acceptResponse(code) {
    if (timedOut) { error = "Request timed out; will retry."; return }
    if (code !== 0) { error = "Data request failed; will retry."; return }
    try {
      var next = JSON.parse(buffer)
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
  Timer {
    id: deadline
    objectName: "request-deadline"
    interval: 18000
    onTriggered: {
      root.timedOut = true
      root.error = "Request timed out; will retry."
      if (collector.running) collector.running = false
      else root.inFlight = false
    }
  }
  Process {
    id: collector
    command: ["/usr/bin/timeout", "18", "/usr/bin/python3", root.collectorPath, root.kind, root.runningCity]
    stdout: SplitParser {
      onRead: function(line) { if (root.buffer.length + line.length < 65536) root.buffer += line }
    }
    onExited: function(code) {
      deadline.stop()
      root.inFlight = false
      if (!root.active) return
      if (root.runningRevision === root.revision) root.acceptResponse(code)
      if (root.pendingRefresh) Qt.callLater(root.startPending)
    }
  }
}
