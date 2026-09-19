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
  readonly property string home: Quickshell.env("HOME")
  readonly property string currentStateDir: home + "/.local/state/omarchy/current"
  readonly property string currentBackground: currentStateDir + "/background"
  property int wallpaperRevision: 0

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

  property color ink: Color.foreground
  property color haloColor: Color.background
  property real haloOpacity: 0.94
  property real scrimOpacity: 0
  property real wallpaperContrast: 1
  property real wallpaperSpread: 1
  property bool wallpaperAnalyzed: false
  property int wallpaperAnalysisAttempts: 0
  readonly property color quietInk: Util.alpha(ink, 0.78)
  readonly property color faintInk: Util.alpha(ink, 0.42)
  readonly property color outlineInk: Util.alpha(haloColor, haloOpacity)

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

  FileView {
    path: root.currentStateDir
    watchChanges: true
    printErrors: false
    onFileChanged: root.wallpaperRevision += 1
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
        version: manifest && manifest.version ? String(manifest.version) : "0.4.1",
        screens: Quickshell.screens.length,
        cpuPercent: Math.round(root.cpuPercent),
        memoryPercent: Math.round(root.memory.percent),
        hostname: root.hostname,
        wallpaperAnalyzed: root.wallpaperAnalyzed,
        wallpaperInk: String(root.ink),
        wallpaperContrast: Number(root.wallpaperContrast.toFixed(2)),
        wallpaperSpread: Number(root.wallpaperSpread.toFixed(2)),
        scrimOpacity: Number(root.scrimOpacity.toFixed(2)),
        haloOpacity: Number(root.haloOpacity.toFixed(2))
      })
    }

    function menu(): string {
      root.openMenu(Style.space(42), Style.space(42))
      return "ok"
    }

    function menuState(): string {
      return root.shell && typeof root.shell.isPluginOpen === "function"
        && root.shell.isPluginOpen(root.pluginId) ? "open" : "closed"
    }

    function toneState(): string {
      return root.wallpaperAnalyzed ? "ready" : "pending"
    }

    function toneDebug(): string {
      return JSON.stringify({
        sourceConfigured: root.currentBackground.length > 0,
        attempts: root.wallpaperAnalysisAttempts,
        analyzed: root.wallpaperAnalyzed
      })
    }

    function refreshTone(): string {
      root.wallpaperAnalyzed = false
      root.wallpaperRevision += 1
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

      WallpaperTone {
        id: wallpaperTone
        x: monitorColumn.x
        y: monitorColumn.y
        z: 0
        sourcePath: root.currentBackground
        revision: root.wallpaperRevision
        screenWidth: desktop.width
        screenHeight: desktop.height
        sampleRect: Qt.rect(
          monitorColumn.x - Style.space(22),
          monitorColumn.y - Style.space(18),
          monitorColumn.width + Style.space(44),
          monitorColumn.implicitHeight + Style.space(36)
        )
        // Wallpaper legibility must not depend on a theme accent that can
        // clash with the image (cyan over orange is a common failure mode).
        lightCandidate: "#f2f2f2"
        darkCandidate: "#111111"
        onInkChanged: root.ink = ink
        onHaloColorChanged: root.haloColor = haloColor
        onHaloOpacityChanged: root.haloOpacity = haloOpacity
        onScrimOpacityChanged: root.scrimOpacity = scrimOpacity
        onMeasuredContrastChanged: root.wallpaperContrast = measuredContrast
        onMeasuredSpreadChanged: root.wallpaperSpread = measuredSpread
        onAnalyzedChanged: root.wallpaperAnalyzed = analyzed
        onAttemptsChanged: root.wallpaperAnalysisAttempts = attempts
      }

      MouseArea {
        anchors.fill: parent
        z: 3
        acceptedButtons: Qt.RightButton
        onClicked: function(mouse) {
          root.openMenu(mouse.x, mouse.y)
          mouse.accepted = true
        }
      }

      ColumnLayout {
        id: monitorColumn
        z: 2
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

        ContrastRule {
          Layout.fillWidth: true
          lineColor: root.faintInk
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

        ContrastRule {
          Layout.fillWidth: true
          Layout.topMargin: Style.space(4)
          lineColor: root.faintInk
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

  component ContrastRule: Item {
    required property color lineColor
    implicitHeight: Math.max(3, Style.space(3))

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      height: Math.max(3, Style.space(3))
      color: root.outlineInk
    }

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      height: Math.max(1, Style.space(1))
      color: parent.lineColor
    }
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
        outlineColor: root.outlineInk
        fillColor: Util.alpha(root.ink, 0.06)
      }

      Rectangle {
        visible: metricRoot.samples.length < 2
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * Math.max(0, Math.min(1, metricRoot.fraction))
        height: Math.max(3, Style.space(4))
        color: root.outlineInk
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
        height: Math.max(3, Style.space(3))
        color: root.outlineInk
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
