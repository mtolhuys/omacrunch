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
  property alias widgetStore: widgets

  WidgetStore { id: widgets }
  WidgetFeed { id: weatherFeed; kind: "weather"; active: widgets.anyEnabled("weather"); city: widgets.layout.weatherCity; interval: 900000 }
  WidgetFeed { id: diskFeed; kind: "disk"; active: widgets.anyEnabled("disk"); interval: 60000 }
  WidgetFeed { id: agentFeed; kind: "agents"; active: widgets.anyEnabled("agents"); interval: 60000 }

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
  property var wallpaperZones: ({})
  property bool wallpaperAnalyzed: false
  property int wallpaperAnalysisAttempts: 0
  readonly property color outlineInk: Util.alpha(haloColor, haloOpacity)

  function tone(name) {
    var candidate = wallpaperZones ? wallpaperZones[name] : null
    return candidate && candidate.useLight !== undefined
      ? candidate : {
        useLight: true,
        haloOpacity: 0.48,
        minimumContrast: 1,
        requiredExtremeOpacity: 0.72
      }
  }

  function zoneInk(name) {
    return tone(name).useLight ? "#f2f2f2" : "#111111"
  }

  function zoneQuietInk(name) {
    return Util.alpha(zoneInk(name), 0.82)
  }

  function zoneFaintInk(name) {
    return Util.alpha(zoneInk(name), 0.46)
  }

  function zoneOutline(name) {
    return Util.alpha(tone(name).useLight ? "#000000" : "#ffffff", tone(name).haloOpacity)
  }

  function zoneSurfaceOpacity(name) {
    var local = tone(name)
    if (Number(local.minimumContrast || 0) >= 4.5) return 0
    return Math.min(0.88, Math.max(0.18, Number(local.requiredExtremeOpacity || 0) + 0.04))
  }

  function zoneSurfaceColor(name) {
    var local = tone(name)
    return Util.alpha(local.useLight ? "#000000" : "#ffffff", zoneSurfaceOpacity(name))
  }

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
    precision: SystemClock.Minutes
  }

  IpcHandler {
    target: "omacrunch"

    function ping(): string { return "ok" }

    function state(): string {
      return JSON.stringify({
        version: manifest && manifest.version ? String(manifest.version) : "0.5.0",
        screens: Quickshell.screens.length,
        cpuPercent: Math.round(root.cpuPercent),
        memoryPercent: Math.round(root.memory.percent),
        hostname: root.hostname,
        wallpaperAnalyzed: root.wallpaperAnalyzed,
        wallpaperInk: String(root.ink),
        wallpaperContrast: Number(root.wallpaperContrast.toFixed(2)),
        wallpaperSpread: Number(root.wallpaperSpread.toFixed(2)),
        scrimOpacity: Number(root.scrimOpacity.toFixed(2)),
        haloOpacity: Number(root.haloOpacity.toFixed(2)),
        wallpaperZones: root.wallpaperZones
      })
    }

    function menu(): string {
      root.openMenu(Style.space(42), Style.space(42))
      return "ok"
    }

    function widgetsMenu(): string {
      if (root.shell) root.shell.summon(root.pluginId, '{"page":"widgets"}')
      return "ok"
    }
    function widgetState(): string {
      return JSON.stringify({ editing: widgets.editing, loaded: widgets.loaded, layout: widgets.layout,
        error: widgets.error, disk: diskFeed.report, agents: agentFeed.report,
        weather: weatherFeed.report, weatherError: weatherFeed.error })
    }
    function editWidgets(): string { widgets.begin(); return "editing" }
    function finishWidgets(save: bool): string { widgets.finish(save); return "done" }
    function toggleWidget(screen: string, id: string): string { widgets.toggle(screen, id); return "ok" }
    function moveWidget(screen: string, id: string, x: real, y: real): string {
      if (!widgets.editing) return "edit mode required"
      widgets.place(screen, id, { x: x, y: y }); return "ok"
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
      WlrLayershell.layer: widgets.editing ? WlrLayer.Overlay : WlrLayer.Bottom
      WlrLayershell.keyboardFocus: widgets.editing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      Connections {
        target: widgets
        function onEditingChanged() {
          if (widgets.editing) Qt.callLater(function() { editorKeys.forceActiveFocus() })
        }
      }

      FocusScope {
        id: editorKeys
        anchors.fill: parent
        focus: widgets.editing
        Keys.onEscapePressed: widgets.finish(false)
        Keys.onReturnPressed: widgets.finish(true)
      }

      WallpaperTone {
        id: wallpaperTone
        x: monitorFrame.x
        y: monitorFrame.y
        z: 0
        sourcePath: monitorFrame.dragging ? "" : root.currentBackground
        revision: root.wallpaperRevision
        screenWidth: desktop.width
        screenHeight: desktop.height
        sampleRect: Qt.rect(
          monitorFrame.x - Style.space(22),
          monitorFrame.y - Style.space(18),
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
        onZonesChanged: root.wallpaperZones = zones
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
          if (widgets.editing) return
          root.openMenu(mouse.x, mouse.y)
          mouse.accepted = true
        }
      }

      DesktopWidget {
        id: monitorFrame
        store: widgets
        screenName: String(desktop.screen.name)
        widgetId: "monitor"
        title: "System Monitor"
        adaptiveSurface: false
        width: Math.min(Style.space(360), desktop.width * 0.34)
        defaultX: desktop.width - width - Style.space(46)
        defaultY: Style.space(42)

      ColumnLayout {
        id: monitorColumn
        z: 2
        width: parent.width
        spacing: Style.space(12)

        WidgetSurface {
          toneZone: "header"

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Ink {
              text: Qt.formatDateTime(clock.date, "HH:mm")
              toneZone: "header"
              font.pixelSize: Style.space(48)
              font.bold: true
            }

            Ink {
              text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy").toUpperCase()
              toneZone: "header"
              quiet: true
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1.5
            }
          }

          ContrastRule { Layout.fillWidth: true; toneZone: "header" }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(3)

            Ink { text: root.hostname.toUpperCase(); toneZone: "header"; font.bold: true; font.pixelSize: Style.font.title }
            Ink { text: "OMARCHY  /  HYPRLAND  /  " + root.kernel; toneZone: "header"; quiet: true; font.pixelSize: Style.font.caption }
            Ink { text: root.processor; toneZone: "header"; quiet: true; font.pixelSize: Style.font.caption; elide: Text.ElideRight; Layout.fillWidth: true }
          }
        }

        WidgetSurface {
          toneZone: "body"

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
            Ink { text: "UPTIME"; toneZone: "body"; quiet: true; font.pixelSize: Style.font.caption; font.bold: true }
            Item { Layout.fillWidth: true }
            Ink { text: root.uptime; toneZone: "body"; font.pixelSize: Style.font.body }
          }
        }

        WidgetSurface {
          toneZone: "footer"

          GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Style.space(18)
            rowSpacing: Style.space(4)

            Hint { keys: "SUPER + RETURN"; action: "terminal"; toneZone: "footer" }
            Hint { keys: "SUPER + SPACE"; action: "menu"; toneZone: "footer" }
            Hint { keys: "SUPER + 1…9"; action: "workspace"; toneZone: "footer" }
            Hint { keys: "SUPER + Q"; action: "close"; toneZone: "footer" }
            Hint { keys: "RIGHT CLICK"; action: "omacrunch"; toneZone: "footer" }
            Hint { keys: "SUPER + K"; action: "all keys"; toneZone: "footer" }
          }
        }
      }
      }

      Repeater {
        model: ["weather", "agents", "disk", "calendar"]
        delegate: DesktopWidget {
          id: extraWidget
          required property string modelData
          required property int index
          store: widgets
          screenName: String(desktop.screen.name)
          widgetId: modelData
          title: ({ weather: "Weather", agents: "Agent Usage", disk: "Disk Usage", calendar: "Calendar" })[modelData]
          defaultX: Style.space(24) + (index % 2) * (width + Style.space(18))
          defaultY: Style.space(62) + Math.floor(index / 2) * Style.space(390)
          wallpaper: root.currentBackground
          wallpaperRevision: root.wallpaperRevision
          WidgetContent {
            width: parent.width
            kind: extraWidget.modelData
            ink: widgets.editing ? Color.menu.text : extraWidget.ink
            today: clock.date
            feed: kind === "weather" ? weatherFeed : kind === "agents" ? agentFeed : kind === "disk" ? diskFeed : null
          }
        }
      }

      Rectangle {
        visible: widgets.editing
        anchors.horizontalCenter: parent.horizontalCenter
        y: Style.space(40)
        width: editorRow.implicitWidth + Style.space(24)
        height: Style.space(38)
        z: 100
        color: Color.menu.background
        border.color: Color.menu.border
        Row {
          id: editorRow
          anchors.centerIn: parent
          spacing: Style.space(18)
          Text { text: "WIDGET LAYOUT"; color: Color.menu.text; font.family: "monospace"; font.pixelSize: Style.font.body; anchors.verticalCenter: parent.verticalCenter }
          Repeater {
            model: ["Save", "Cancel", "Reset positions"]
            delegate: Rectangle {
              required property int index
              required property string modelData
              width: actionLabel.implicitWidth + Style.space(16); height: Style.space(28)
              color: actionMouse.containsMouse ? Color.menu.selectedBackground : "transparent"
              Text { id: actionLabel; anchors.centerIn: parent; text: modelData; color: Color.menu.text; font.family: "monospace"; font.pixelSize: Style.font.body }
              MouseArea {
                id: actionMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (index === 2) widgets.reset(String(desktop.screen.name))
                  else widgets.finish(index === 0)
                }
              }
            }
          }
        }
      }
    }
  }

  component WidgetSurface: Rectangle {
    id: surfaceRoot
    required property string toneZone
    default property alias widgetData: surfaceContent.data
    readonly property real surfaceOpacity: root.zoneSurfaceOpacity(toneZone)
    readonly property real inset: Style.space(8)

    Layout.fillWidth: true
    implicitHeight: surfaceContent.implicitHeight + (inset * 2)
    color: root.zoneSurfaceColor(toneZone)
    radius: Style.space(2)
    border.width: surfaceOpacity > 0 ? 1 : 0
    border.color: root.zoneFaintInk(toneZone)

    ColumnLayout {
      id: surfaceContent
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: surfaceRoot.inset
      spacing: Style.space(10)
    }
  }

  component Ink: Text {
    property string toneZone: "body"
    property bool quiet: false
    color: quiet ? root.zoneQuietInk(toneZone) : root.zoneInk(toneZone)
    font.family: "monospace"
    font.pixelSize: Style.font.body
    textFormat: Text.PlainText
    style: Text.Normal
  }

  component ContrastRule: Item {
    id: ruleRoot
    property string toneZone: "body"
    implicitHeight: Math.max(1, Style.space(1))

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      height: Math.max(1, Style.space(1))
      color: root.zoneFaintInk(ruleRoot.toneZone)
    }
  }

  component Hint: RowLayout {
    id: hintRoot
    required property string keys
    required property string action
    required property string toneZone
    Layout.fillWidth: true
    spacing: Style.space(7)

    Ink { text: keys; toneZone: hintRoot.toneZone; font.pixelSize: Style.font.caption; font.bold: true }
    Ink { Layout.fillWidth: true; text: action; toneZone: hintRoot.toneZone; quiet: true; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
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
      Ink { text: label; toneZone: "body"; quiet: true; font.pixelSize: Style.font.caption; font.bold: true }
      Item { Layout.fillWidth: true }
      Ink { text: value; toneZone: "body"; font.pixelSize: Style.font.body }
    }

    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(22)

      Sparkline {
        anchors.fill: parent
        samples: metricRoot.samples
        lineColor: root.zoneInk("body")
        lineColorRight: lineColor
        outlineColor: "transparent"
        outlineColorRight: outlineColor
        fillColor: Util.alpha(root.zoneInk("body"), 0.08)
      }

      Rectangle {
        visible: metricRoot.samples.length < 2
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * Math.max(0, Math.min(1, metricRoot.fraction))
        height: Math.max(1, Style.space(2))
        color: root.zoneInk("body")
      }

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(1, Style.space(1))
        color: root.zoneFaintInk("body")
      }
    }
  }
}
