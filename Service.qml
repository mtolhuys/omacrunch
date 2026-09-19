import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "Metrics.js" as Metrics

Item {
  id: root

  property var shell: null
  property var manifest: null
  readonly property string pluginId: manifest && manifest.id
    ? String(manifest.id) : "io.github.mtolhuys.omacrunch"

  property var cpuSnapshot: ({ total: 0, idle: 0 })
  property real cpuPercent: 0
  property var memory: ({ total: 0, used: 0, percent: 0, swapTotal: 0, swapUsed: 0 })
  property var load: ({ one: 0, five: 0, fifteen: 0 })
  property string uptime: "0h 0m"
  property var networkSnapshot: ({ received: 0, transmitted: 0, timeMs: 0 })
  property real networkDown: 0
  property real networkUp: 0
  property string hostname: "omarchy"
  property string kernel: ""
  property string processor: "processor"
  property var cpuHistory: []
  property var memoryHistory: []
  property var networkHistory: []

  readonly property color ink: Color.foreground
  readonly property color quietInk: Util.alpha(ink, 0.60)
  readonly property color faintInk: Util.alpha(ink, 0.26)
  readonly property color outlineInk: Util.alpha(Color.background, 0.86)

  function refresh() {
    cpuFile.reload()
    memoryFile.reload()
    loadFile.reload()
    uptimeFile.reload()
    networkFile.reload()
  }

  function openMenu(x, y) {
    if (!root.shell || typeof root.shell.summon !== "function") return
    root.shell.summon(root.pluginId, JSON.stringify({ x: x, y: y }))
  }

  FileView {
    id: cpuFile
    path: "/proc/stat"
    printErrors: false
    onLoaded: {
      var next = Metrics.parseCpu(text(), root.cpuSnapshot)
      root.cpuSnapshot = next
      if (next.ready) {
        root.cpuPercent = next.percent
        root.cpuHistory = Metrics.pushSample(root.cpuHistory, next.percent, 48)
      }
    }
  }

  FileView {
    id: memoryFile
    path: "/proc/meminfo"
    printErrors: false
    onLoaded: {
      root.memory = Metrics.parseMemory(text())
      root.memoryHistory = Metrics.pushSample(root.memoryHistory, root.memory.percent, 48)
    }
  }

  FileView {
    id: loadFile
    path: "/proc/loadavg"
    printErrors: false
    onLoaded: root.load = Metrics.parseLoad(text())
  }

  FileView {
    id: uptimeFile
    path: "/proc/uptime"
    printErrors: false
    onLoaded: root.uptime = Metrics.parseUptime(text()).label
  }

  FileView {
    id: networkFile
    path: "/proc/net/dev"
    printErrors: false
    onLoaded: {
      var next = Metrics.parseNetwork(text(), root.networkSnapshot, Date.now())
      root.networkSnapshot = next
      if (next.ready) {
        root.networkDown = next.down
        root.networkUp = next.up
        var activity = Math.min(100, Math.log(1 + next.down + next.up) / Math.log(1024 * 1024 * 50) * 100)
        root.networkHistory = Metrics.pushSample(root.networkHistory, activity, 48)
      }
    }
  }

  FileView {
    path: "/proc/sys/kernel/hostname"
    printErrors: false
    onLoaded: root.hostname = String(text() || "omarchy").trim()
  }

  FileView {
    path: "/proc/sys/kernel/osrelease"
    printErrors: false
    onLoaded: root.kernel = String(text() || "").trim()
  }

  FileView {
    path: "/proc/cpuinfo"
    printErrors: false
    onLoaded: root.processor = Metrics.cpuModel(text())
  }

  Timer {
    interval: 2000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  IpcHandler {
    target: "omacrunch"

    function ping(): string { return "ok" }

    function state(): string {
      return JSON.stringify({
        version: manifest && manifest.version ? String(manifest.version) : "0.2.0",
        screens: Quickshell.screens.length,
        cpuPercent: Math.round(root.cpuPercent),
        memoryPercent: Math.round(root.memory.percent),
        hostname: root.hostname
      })
    }

    function menu(): string {
      root.openMenu(Style.space(42), Style.space(42))
      return "ok"
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: desktop
      required property var modelData

      screen: modelData
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      WlrLayershell.namespace: "omacrunch-desktop"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: function(mouse) {
          root.openMenu(mouse.x, mouse.y)
          mouse.accepted = true
        }
      }

      ColumnLayout {
        width: Math.min(Style.space(360), desktop.width * 0.34)
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Style.space(42)
        anchors.rightMargin: Style.space(46)
        spacing: Style.space(12)

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          Ink {
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.pixelSize: Style.space(48)
            font.bold: true
          }

          Ink {
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy").toUpperCase()
            color: root.quietInk
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1.5
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Math.max(1, Style.space(1))
          color: root.faintInk
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.space(3)

          Ink { text: root.hostname.toUpperCase(); font.bold: true; font.pixelSize: Style.font.title }
          Ink { text: "OMARCHY  /  HYPRLAND  /  " + root.kernel; color: root.quietInk; font.pixelSize: Style.font.caption }
          Ink { text: root.processor; color: root.quietInk; font.pixelSize: Style.font.caption; elide: Text.ElideRight; Layout.fillWidth: true }
        }

        Metric {
          label: "CPU"
          value: root.cpuPercent.toFixed(0) + "%"
          fraction: root.cpuPercent / 100
          samples: root.cpuHistory
        }

        Metric {
          label: "MEM"
          value: Metrics.formatBytes(root.memory.used) + " / " + Metrics.formatBytes(root.memory.total)
          fraction: root.memory.percent / 100
          samples: root.memoryHistory
        }

        Metric {
          label: "LOAD"
          value: root.load.one.toFixed(2) + "  " + root.load.five.toFixed(2) + "  " + root.load.fifteen.toFixed(2)
          fraction: Math.min(1, root.load.one / 8)
          samples: []
        }

        Metric {
          label: "NET"
          value: "↓ " + Metrics.formatRate(root.networkDown) + "   ↑ " + Metrics.formatRate(root.networkUp)
          fraction: 0
          samples: root.networkHistory
        }

        RowLayout {
          Layout.fillWidth: true
          Ink { text: "UPTIME"; color: root.quietInk; font.pixelSize: Style.font.caption; font.bold: true }
          Item { Layout.fillWidth: true }
          Ink { text: root.uptime; font.pixelSize: Style.font.body }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Math.max(1, Style.space(1))
          Layout.topMargin: Style.space(4)
          color: root.faintInk
        }

        GridLayout {
          Layout.fillWidth: true
          columns: 2
          columnSpacing: Style.space(18)
          rowSpacing: Style.space(4)

          Hint { keys: "SUPER + RETURN"; action: "terminal" }
          Hint { keys: "SUPER + SPACE"; action: "menu" }
          Hint { keys: "SUPER + 1…9"; action: "workspace" }
          Hint { keys: "SUPER + Q"; action: "close" }
          Hint { keys: "RIGHT CLICK"; action: "omacrunch" }
          Hint { keys: "SUPER + K"; action: "all keys" }
        }
      }
    }
  }

  component Ink: Text {
    color: root.ink
    font.family: "monospace"
    font.pixelSize: Style.font.body
    textFormat: Text.PlainText
    style: Text.Outline
    styleColor: root.outlineInk
  }

  component Hint: RowLayout {
    required property string keys
    required property string action
    Layout.fillWidth: true
    spacing: Style.space(7)

    Ink { text: keys; color: root.ink; font.pixelSize: Style.font.caption; font.bold: true }
    Ink { Layout.fillWidth: true; text: action; color: root.quietInk; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
  }

  component Metric: ColumnLayout {
    id: metricRoot
    required property string label
    required property string value
    required property real fraction
    required property var samples
    Layout.fillWidth: true
    spacing: Style.space(3)

    RowLayout {
      Layout.fillWidth: true
      Ink { text: label; color: root.quietInk; font.pixelSize: Style.font.caption; font.bold: true }
      Item { Layout.fillWidth: true }
      Ink { text: value; font.pixelSize: Style.font.body }
    }

    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(22)

      Sparkline {
        anchors.fill: parent
        samples: metricRoot.samples
        lineColor: root.ink
      }

      Rectangle {
        visible: metricRoot.samples.length < 2
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * Math.max(0, Math.min(1, metricRoot.fraction))
        height: Math.max(1, Style.space(2))
        color: root.ink
      }

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(1, Style.space(1))
        color: root.faintInk
      }
    }
  }
}
