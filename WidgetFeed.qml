import QtQuick
import Quickshell.Io

Item {
  id: root
  required property string kind
  property bool active: false
  property string city: ""
  property int interval: 60000
  property var report: ({})
  property string error: ""
  property string buffer: ""
  readonly property bool busy: collector.running
  function refresh() {
    if (!active || collector.running) return
    buffer = ""
    error = ""
    collector.running = true
  }
  onActiveChanged: {
    if (active) refresh()
    else collector.running = false
  }
  onCityChanged: {
    report = ({})
    collector.running = false
    Qt.callLater(refresh)
  }
  Component.onCompleted: if (active) refresh()
  Timer { interval: root.interval; running: root.active; repeat: true; onTriggered: root.refresh() }
  Timer {
    id: deadline
    interval: 18000
    onTriggered: { root.error = "Request timed out; will retry."; collector.running = false }
  }
  Process {
    id: collector
    command: ["/usr/bin/python3", String(Qt.resolvedUrl("widget-data.py")).replace(/^file:\/\//, ""), root.kind, root.city]
    onRunningChanged: if (running) deadline.restart(); else deadline.stop()
    stdout: SplitParser {
      onRead: function(line) { if (root.buffer.length + line.length < 65536) root.buffer += line }
    }
    onExited: function(code) {
      if (!root.active) return
      if (code !== 0) { root.error = "Collector unavailable; will retry."; return }
      try {
        var next = JSON.parse(root.buffer)
        if (next.error) root.error = String(next.error)
        else { root.report = next; root.error = "" }
      } catch (e) { root.error = "Invalid response; will retry." }
    }
  }
}
