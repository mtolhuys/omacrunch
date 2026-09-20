import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import qs.Commons
import "Workspace.js" as Workspace
import "PluginShelfModel.js" as ShelfModel
import "BarSettings.js" as BarSettings

// A full Tint2-style bar rather than a row of unrelated widgets. Workspaces
// own their windows, while Omarchy's mature status widgets keep providing the
// network, audio, power, calendar and tray panels behind CrunchBang chrome.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var barWidgetRegistry: null
  property var barConfig: ({})
  property var shell: null
  property var manifest: null
  property var pluginRegistry: null

  readonly property string pluginId: manifest && manifest.id
    ? String(manifest.id) : "io.github.mtolhuys.omacrunch"
  readonly property string home: Quickshell.env("HOME")
  readonly property string toggleDirectory: home + "/.local/state/omarchy/toggles"
  readonly property string barHiddenFlag: toggleDirectory + "/bar-off"
  readonly property string position: "top"
  readonly property bool vertical: false
  readonly property int barSize: 30
  readonly property int workspaceNumberWidth: Style.space(14)
  readonly property int taskSlotWidth: Style.space(18)
  readonly property int taskIconSize: Style.space(13)
  readonly property int workspaceContentPadding: Style.space(2)
  property bool barHidden: false
  property bool requestedTransparent: !!(barConfig && barConfig.transparent === true)
  readonly property real panelOpacity: requestedTransparent ? 0 : 0.92
  readonly property bool transparent: requestedTransparent
  readonly property color foreground: Color.bar.text
  readonly property color barForeground: foreground
  readonly property color background: Color.bar.background
  readonly property color urgent: Color.bar.active
  readonly property string fontFamily: "monospace"
  property bool foregroundAnimationEnabled: true
  property bool centerHoverRevealSuppressed: false
  property bool centerSectionRevealHeld: false
  property var activePopout: null
  property var clickTargets: []
  property var liveBarWindows: []
  property var liveWidgets: []
  property var trayControls: []
  property var pluginShelves: []
  property var tooltipTarget: null
  property string tooltipText: ""
  property bool tooltipShown: false

  readonly property var configuredPluginEntries: ShelfModel.entries(barConfig,
    barWidgetRegistry ? barWidgetRegistry.widgets : {}, pluginId,
    pluginRegistry ? pluginRegistry.installedPlugins : {})
  readonly property var pluginEntries: ShelfModel.orderedEntries(configuredPluginEntries, pluginOrder.order)
  readonly property alias pluginOrderStore: pluginOrder
  PluginOrderStore { id: pluginOrder }

  function savePluginOrder(ids) { return pluginOrder.save(ids) }

  readonly property var statusModules: [
    { id: "omarchy.tray", region: "right" },
    { id: "omarchy.network", region: "right" },
    { id: "omarchy.audio", region: "right" },
    { id: "omarchy.power", region: "right" },
    { id: "omarchy.clock", region: "right" }
  ]
  readonly property var layoutConfig: ({
    left: [{ id: "omacrunch.menu" }, { id: "omacrunch.workspaces" }],
    center: pluginEntries.map(function(entry) { return entry.settings }),
    right: statusModules
  })

  function pluginEntry(id) {
    return pluginEntries.find(function(entry) { return entry.id === id }) || null
  }

  function registerShelf(shelf) {
    if (pluginShelves.indexOf(shelf) < 0) pluginShelves = pluginShelves.concat([shelf])
  }

  function unregisterShelf(shelf) {
    pluginShelves = pluginShelves.filter(function(candidate) { return candidate !== shelf })
  }

  function focusedShelf() {
    var focused = focusedScreenName()
    return pluginShelves.find(function(shelf) { return shelf.screenName === focused })
      || pluginShelves[0] || null
  }

  function switchPluginPanel(id, screenName, direction) {
    var panels = pluginEntries.map(function(entry) {
      return root.liveWidgets.find(function(record) {
        return record.id === entry.id && record.screenName === screenName && record.item
          && typeof record.item.open === "function" && typeof record.item.close === "function"
      })
    }).filter(function(record) { return !!record })
    var current = panels.findIndex(function(record) { return record.id === id })
    if (current < 0 || panels.length < 2) return false
    panels[(current + (direction < 0 ? -1 : 1) + panels.length) % panels.length].item.open()
    return true
  }

  function widgetComponent(id) {
    var widgets = barWidgetRegistry && barWidgetRegistry.widgets
      ? barWidgetRegistry.widgets : ({})
    var record = widgets[String(id || "")]
    return record ? record.component : null
  }

  function trayIds() {
    var ids = []
    var values = SystemTray.items ? SystemTray.items.values : []
    for (var index = 0; index < values.length; index++) {
      var item = values[index]
      if (item && item.status !== Status.Passive && String(item.id || "") !== "")
        ids.push(String(item.id))
    }
    return ids
  }

  function widgetSettings(id) {
    if (id === "omarchy.tray") return { id: id, pinned: trayIds(), hidden: [] }
    if (id === "omarchy.power") return { id: id, showPercentage: false }
    if (id === "omarchy.clock") return BarSettings.clockSettings(barConfig)
    return { id: id }
  }

  function clockState() {
    var configured = BarSettings.clockSettings(barConfig)
    var clocks = moduleWidgets("omarchy.clock")
    var active = clocks.length && clocks[0].activeFormat !== undefined
      ? String(clocks[0].activeFormat) : ""
    return { configuredFormat: configured.format, activeFormat: active }
  }

  function configureWidget(loader, screenName) {
    var item = loader ? loader.item : null
    if (!item) return
    if ("bar" in item) item.bar = root
    if ("moduleName" in item) item.moduleName = loader.moduleId
    if ("settings" in item) {
      item.settings = Qt.binding(function() { return root.widgetSettings(loader.moduleId) })
    }
    registerWidget(loader.moduleId, loader.region, screenName, item)
  }

  function registerWidget(id, region, screenName, item) {
    if (!item) return
    var next = liveWidgets.filter(function(record) {
      return record.item && record.item !== item
        && !(record.id === String(id) && record.screenName === String(screenName))
    })
    next.push({ id: String(id), region: String(region), screenName: String(screenName), item: item })
    liveWidgets = next
  }

  function unregisterWidget(item) {
    if (!item) return
    liveWidgets = liveWidgets.filter(function(record) { return record.item !== item })
  }

  function registerTrayControl(control, screenName) {
    if (!control) return
    unregisterTrayControl(control)
    var next = trayControls.slice()
    next.push({ control: control, screenName: String(screenName || "") })
    trayControls = next
  }

  function unregisterTrayControl(control) {
    trayControls = trayControls.filter(function(record) { return record.control !== control })
  }

  function focusedTrayControl() {
    if (!trayControls.length) return null
    var focused = focusedScreenName()
    for (var index = 0; index < trayControls.length; index++)
      if (trayControls[index].screenName === focused) return trayControls[index].control
    return trayControls[0].control
  }

  function toggleTray() {
    var control = focusedTrayControl()
    if (!control) return false
    control.trayExpanded = !control.trayExpanded
    return true
  }

  function trayState() {
    var control = focusedTrayControl()
    return control && control.trayExpanded ? "expanded" : (control ? "collapsed" : "missing")
  }

  function trayVisualState() {
    var control = focusedTrayControl()
    if (!control) return JSON.stringify({ state: "missing" })
    return JSON.stringify({
      state: control.trayExpanded ? "expanded" : "collapsed",
      width: Math.round(control.width),
      targetWidth: Math.round(control.trayTargetWidth),
      arrowRotation: Math.round(control.trayArrowRotation)
    })
  }

  function registerBarWindow(window) {
    if (!window || liveBarWindows.indexOf(window) !== -1) return
    var next = liveBarWindows.slice()
    next.push(window)
    liveBarWindows = next
  }

  function unregisterBarWindow(window) {
    liveBarWindows = liveBarWindows.filter(function(candidate) { return candidate !== window })
  }

  function debugBarGeometry() {
    var geometry = []
    for (var index = 0; index < liveBarWindows.length; index++) {
      var window = liveBarWindows[index]
      if (!window) continue
      geometry.push({
        id: "omacrunch.workspace-taskbar",
        section: "full",
        screen: window.screen ? String(window.screen.name || "") : "",
        x: 0,
        y: 0,
        width: Math.round(window.width),
        height: Math.round(window.height),
        visible: window.visible === true,
        itemVisible: true,
        itemWidth: Math.round(window.width),
        itemHeight: Math.round(window.height)
      })
    }
    return geometry
  }

  function moduleWidgets(id) {
    var result = []
    for (var index = 0; index < liveWidgets.length; index++) {
      var record = liveWidgets[index]
      if (record.id === String(id || "") && record.item) result.push(record.item)
    }
    return result
  }

  function widgetMetrics() {
    return liveWidgets.map(function(record) {
      var item = record.item
      return {
        id: record.id,
        screen: record.screenName,
        visible: !!item && item.visible !== false,
        width: item ? Math.round(Number(item.width || 0)) : 0,
        implicitWidth: item ? Math.round(Number(item.implicitWidth || 0)) : 0,
        height: item ? Math.round(Number(item.height || 0)) : 0,
        implicitHeight: item ? Math.round(Number(item.implicitHeight || 0)) : 0
      }
    })
  }

  function focusedScreenName() {
    return Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name || "") : ""
  }

  function findPanelWidget(id) {
    var records = liveWidgets.filter(function(record) {
      var item = record.item
      return record.id === String(id || "") && item
        && typeof item.open === "function" && typeof item.close === "function"
        && item.opened !== undefined
    })
    if (!records.length) return null
    for (var opened = 0; opened < records.length; opened++)
      if (records[opened].item.opened === true) return records[opened].item
    var focused = focusedScreenName()
    for (var index = 0; index < records.length; index++)
      if (records[index].screenName === focused) return records[index].item
    return records[0].item
  }

  function summonBarWidget(id) {
    var item = findPanelWidget(id)
    if (!item) return false
    item.open()
    return true
  }

  function hideBarWidget(id) {
    var item = findPanelWidget(id)
    if (!item) return false
    item.close()
    return true
  }

  function isBarWidgetOpen(id) {
    var item = findPanelWidget(id)
    return !!item && item.opened === true
  }

  function panelWidgetIdAt(section, index) {
    var panels = String(section || "") === "center"
      ? pluginEntries.filter(function(entry) { return root.findPanelWidget(entry.id) !== null })
        .map(function(entry) { return entry.id })
      : (String(section || "") === "right"
        ? ["omarchy.network", "omarchy.audio", "omarchy.power", "omarchy.clock"] : [])
    var position = Math.round(Number(index)) - 1
    return position >= 0 && position < panels.length ? panels[position] : ""
  }

  function switchPanelFrom(owner, direction) {
    var ids = ["omarchy.network", "omarchy.audio", "omarchy.power", "omarchy.clock"]
    var current = -1
    for (var index = 0; index < liveWidgets.length; index++) {
      if (liveWidgets[index].item === owner) current = ids.indexOf(liveWidgets[index].id)
    }
    if (current < 0) return false
    var next = ids[(current + (direction < 0 ? -1 : 1) + ids.length) % ids.length]
    return summonBarWidget(next)
  }

  function registerClickTarget(target) {
    if (!target || clickTargets.indexOf(target) !== -1) return
    var next = clickTargets.slice()
    next.push(target)
    clickTargets = next
  }

  function unregisterClickTarget(target) {
    clickTargets = clickTargets.filter(function(candidate) { return candidate !== target })
  }

  function requestPopout(owner) {
    hideTooltip(null)
    if (activePopout && activePopout !== owner) {
      if (typeof activePopout.closeForPopoutSwitch === "function") activePopout.closeForPopoutSwitch()
      else if (typeof activePopout.close === "function") activePopout.close()
    }
    activePopout = owner
  }

  function releasePopout(owner) {
    if (activePopout === owner) activePopout = null
  }

  function targetWindow(target) {
    return target && target.QsWindow ? target.QsWindow.window : null
  }

  function targetBelongsToWindow(target, window) {
    return !!target && !!window && targetWindow(target) === window
  }

  function setCenterHoverRevealSuppressed(value) {
    centerHoverRevealSuppressed = !!value
  }

  function showTooltip(target, text) {
    tooltipTarget = target
    tooltipText = String(text || "")
    tooltipShown = false
    tooltipDelay.restart()
  }

  function hideTooltip(target) {
    if (target && tooltipTarget !== target) return
    tooltipDelay.stop()
    tooltipTarget = null
    tooltipText = ""
    tooltipShown = false
  }

  function run(command) {
    if (command) Util.execDetached(command)
  }

  function shellQuote(value) { return Util.shellQuote(String(value || "")) }

  function toggleTransparency() {
    var nextTransparent = !root.requestedTransparent
    if (root.shell && typeof root.shell.mutateShellConfig === "function") {
      root.shell.mutateShellConfig(function(config) {
        if (!Util.isPlainObject(config.bar)) config.bar = {}
        config.bar.transparent = nextTransparent
      })
    } else {
      root.requestedTransparent = nextTransparent
    }
    return nextTransparent
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var index = 0; index < values.length; index++)
      if (values[index].id === id) return values[index]
    return null
  }

  function workspaceIds() {
    return Workspace.workspaceIds(Hyprland.workspaces.values, 5, 10)
  }

  function focusWorkspace(id) {
    var command = Workspace.workspaceCommand(id, Hyprland.usingLua)
    if (!command) return false
    var workspace = workspaceById(Number(id))
    if (workspace && typeof workspace.activate === "function") workspace.activate()
    else Hyprland.dispatch(command)
    return true
  }

  function focusRelative(delta) {
    var ids = workspaceIds()
    var currentId = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : ids[0]
    var current = ids.indexOf(currentId)
    if (current < 0) current = 0
    focusWorkspace(ids[(current + delta + ids.length) % ids.length])
  }

  function focusClient(client) {
    if (client && client.wayland && typeof client.wayland.activate === "function") {
      client.wayland.activate()
      return
    }
    var command = Workspace.focusCommand(client)
    if (command) Hyprland.dispatch(command)
  }

  function closeClient(client) {
    if (client && client.wayland && typeof client.wayland.close === "function") client.wayland.close()
  }

  function clientIcon(client) {
    var appClass = Workspace.clientClass(client)
    var entry = appClass ? DesktopEntries.heuristicLookup(appClass) : null
    var icon = entry ? String(entry.icon || "") : ""
    if (icon) {
      var resolved = Quickshell.iconPath(icon, true)
      if (resolved) return resolved
    }
    var direct = appClass ? Quickshell.iconPath(appClass.toLowerCase(), true) : ""
    return direct || ""
  }

  function openRootMenu() {
    if (!shell || typeof shell.summon !== "function") return
    shell.summon(pluginId, JSON.stringify({
      x: Style.space(4),
      y: root.barSize + Style.space(4)
    }))
  }

  Timer {
    id: tooltipDelay
    interval: 600
    onTriggered: root.tooltipShown = root.tooltipTarget !== null && root.tooltipText !== ""
  }

  // Honor Omarchy's native `omarchy toggle bar` state. Keeping the surfaces
  // mapped and parking them just above the screen makes both hide and reveal
  // immediate without rebuilding every hosted plugin widget.
  Process {
    id: barHiddenProbe
    command: ["/usr/bin/test", "-e", root.barHiddenFlag]
    onRunningChanged: if (running) barHiddenDeadline.restart(); else barHiddenDeadline.stop()
    onExited: function(code) { root.barHidden = code === 0 }
  }
  Timer {
    id: barHiddenDeadline
    interval: 3000
    onTriggered: barHiddenProbe.running = false
  }
  FileView {
    path: root.toggleDirectory
    watchChanges: true
    printErrors: false
    onFileChanged: if (!barHiddenProbe.running) barHiddenProbe.running = true
  }
  Component.onCompleted: barHiddenProbe.running = true

  IpcHandler {
    target: "omacrunch-bar"

    function state(): string {
      return JSON.stringify({
        height: root.barSize,
        screens: root.liveBarWindows.length,
        workspaces: root.workspaceIds().length,
        clients: Hyprland.toplevels.values.length,
        widgets: root.liveWidgets.length,
        widgetMetrics: root.widgetMetrics(),
        hidden: root.barHidden,
        transparent: root.transparent,
        panelOpacity: root.panelOpacity,
        focusedWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
      })
    }

    function toggleTransparency(): string {
      return root.toggleTransparency() ? "transparent" : "opaque"
    }

    function toggleTray(): string {
      return root.toggleTray() ? root.trayState() : "missing"
    }

    function trayState(): string { return root.trayState() }

    function trayVisualState(): string { return root.trayVisualState() }

    function clockState(): string { return JSON.stringify(root.clockState()) }

    function focusWorkspace(id: int): string {
      return root.focusWorkspace(id) ? "requested" : "invalid"
    }

    function pluginState(): string {
      return JSON.stringify(root.pluginShelves.map(function(shelf) { return shelf.state() }))
    }

    function pinPlugins(value: bool): string {
      var shelf = root.focusedShelf()
      if (!shelf) return "missing"
      shelf.pinned = value
      return value ? "pinned" : "auto"
    }

    function arrangePlugins(value: bool): string {
      var shelf = root.focusedShelf()
      if (!shelf) return "missing"
      return shelf.setArranging(value) ? (value ? "arranging" : "normal") : "busy"
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: barWindow
      required property var modelData

      screen: modelData
      anchors { top: true; left: true; right: true }
      implicitHeight: root.barSize
      color: "transparent"
      exclusionMode: root.barHidden ? ExclusionMode.Ignore : ExclusionMode.Auto
      WlrLayershell.namespace: "omacrunch-bar"
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      property real parkedOffset: root.barHidden ? -root.barSize : 0
      margins { top: Math.round(barWindow.parkedOffset) }
      Behavior on parkedOffset {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
      }

      Component.onCompleted: root.registerBarWindow(barWindow)
      Component.onDestruction: root.unregisterBarWindow(barWindow)

      Rectangle {
        anchors.fill: parent
        color: root.background
        opacity: root.panelOpacity
        Behavior on opacity {
          NumberAnimation { duration: 220; easing.type: Easing.InOutCubic }
        }
      }

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Util.alpha(root.foreground, 0.18)
        opacity: root.transparent ? 0.45 : 1
        Behavior on opacity { NumberAnimation { duration: 220 } }
      }

      RowLayout {
        anchors.fill: parent
        spacing: 0

        Item {
          Layout.preferredWidth: Style.bar.iconSlot
          Layout.fillHeight: true

          Text {
            anchors.centerIn: parent
            text: "\ue900"
            color: root.foreground
            font.family: "omarchy"
            font.pixelSize: Style.font.body
            textFormat: Text.PlainText
          }

          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
              if (mouse.button === Qt.MiddleButton) Quickshell.execDetached(["omarchy-launch-terminal"])
              else root.openRootMenu()
            }
          }
        }

        Rectangle {
          Layout.preferredWidth: 1
          Layout.fillHeight: true
          color: Util.alpha(root.foreground, 0.14)
        }

        Item {
          id: workspaceViewport
          Layout.preferredWidth: Math.min(workspaceRow.implicitWidth, barWindow.width * 0.45)
          Layout.fillHeight: true
          clip: true

          Row {
            id: workspaceRow
            height: parent.height
            spacing: 0

            Repeater {
              model: root.workspaceIds()

              delegate: Rectangle {
                id: workspaceCell
                required property int modelData
                readonly property var workspace: root.workspaceById(modelData)
                readonly property var clients: workspace && workspace.toplevels
                  ? workspace.toplevels.values : []
                readonly property bool focused: Hyprland.focusedWorkspace
                  && Hyprland.focusedWorkspace.id === modelData
                readonly property bool urgentState: workspace ? workspace.urgent === true : false

                height: workspaceRow.height
                width: Math.max(root.barSize,
                  workspaceContent.implicitWidth + (root.workspaceContentPadding * 2))
                color: urgentState
                  ? Util.alpha(root.urgent, 0.34)
                  : (focused ? Util.alpha(root.foreground, 0.12) : "transparent")

                Row {
                  id: workspaceContent
                  z: 1
                  anchors.centerIn: parent
                  height: parent.height
                  spacing: 0

                  Text {
                    width: root.workspaceNumberWidth
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: workspaceCell.modelData === 10 ? "0" : String(workspaceCell.modelData)
                    color: root.foreground
                    opacity: workspaceCell.focused || workspaceCell.clients.length > 0 ? 1 : 0.44
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: workspaceCell.focused
                    textFormat: Text.PlainText
                  }

                  Repeater {
                    model: workspaceCell.clients

                    delegate: Item {
                      id: taskButton
                      required property var modelData
                      readonly property var client: modelData
                      readonly property string title: Workspace.clientTitle(client)
                      readonly property string iconSource: root.clientIcon(client)

                      width: root.taskSlotWidth
                      height: workspaceCell.height

                      Rectangle {
                        anchors.centerIn: parent
                        width: root.taskIconSize + Style.space(3)
                        height: width
                        radius: Style.space(2)
                        visible: taskButton.client && taskButton.client.urgent
                        color: Util.alpha(root.urgent, 0.42)
                      }

                      Text {
                        anchors.centerIn: parent
                        visible: taskIcon.source === ""
                        text: Workspace.clientInitial(taskButton.client)
                        color: root.foreground
                        opacity: taskButton.client && taskButton.client.activated ? 1 : 0.66
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        textFormat: Text.PlainText
                      }

                      Image {
                        id: taskIcon
                        anchors.centerIn: parent
                        width: root.taskIconSize
                        height: width
                        source: taskButton.iconSource
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        opacity: taskButton.client && taskButton.client.activated ? 1 : 0.72
                      }

                      Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        width: root.taskIconSize
                        height: 2
                        visible: taskButton.client && taskButton.client.activated
                        color: root.foreground
                      }

                      MouseArea {
                        anchors.fill: parent
                        z: 2
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.showTooltip(taskButton, taskButton.title)
                        onExited: root.hideTooltip(taskButton)
                        onClicked: function(mouse) {
                          if (mouse.button === Qt.MiddleButton) root.closeClient(taskButton.client)
                          else root.focusClient(taskButton.client)
                        }
                      }
                    }
                  }
                }

                Rectangle {
                  z: 1
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  height: workspaceCell.focused ? 2 : 1
                  color: workspaceCell.focused
                    ? root.foreground : Util.alpha(root.foreground, 0.08)
                }

                MouseArea {
                  anchors.fill: parent
                  z: 0
                  acceptedButtons: Qt.LeftButton
                  onClicked: root.focusWorkspace(workspaceCell.modelData)
                }
              }
            }
          }

          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: function(wheel) {
              root.focusRelative(wheel.angleDelta.y > 0 ? -1 : 1)
              wheel.accepted = true
            }
          }
        }

        PluginShelf {
          hostBar: root
          screenName: String(barWindow.screen.name || "")
          Layout.fillWidth: true
          Layout.fillHeight: true
          Component.onCompleted: root.registerShelf(this)
          Component.onDestruction: root.unregisterShelf(this)
        }

        Rectangle {
          Layout.preferredWidth: 1
          Layout.fillHeight: true
          color: Util.alpha(root.foreground, 0.14)
        }

        RowLayout {
          Layout.fillHeight: true
          spacing: 0

          Repeater {
            model: root.statusModules

            delegate: Item {
              id: statusSlot
              required property var modelData
              property string moduleId: String(modelData.id)
              property string region: String(modelData.region)
              property var registeredItem: null
              property bool trayExpanded: true
              readonly property bool isTray: moduleId === "omarchy.tray"
              readonly property real nativeWidth: statusLoader.item
                && statusLoader.item.visible !== false ? statusLoader.item.implicitWidth : 0
              readonly property real toggleWidth: Style.bar.iconSlot
              readonly property real trayTargetWidth: trayExpanded ? nativeWidth : toggleWidth
              property real animatedTrayWidth: trayTargetWidth
              readonly property real trayArrowRotation: trayArrow.rotation

              Layout.preferredWidth: isTray && nativeWidth > 0
                ? animatedTrayWidth : nativeWidth
              Layout.preferredHeight: root.barSize
              Layout.fillHeight: true
              visible: true
              clip: isTray

              Behavior on animatedTrayWidth {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
              }

              Item {
                id: statusContentClip
                x: statusSlot.isTray ? statusSlot.toggleWidth : 0
                width: Math.max(0, statusSlot.width - x)
                height: root.barSize
                clip: statusSlot.isTray
                opacity: statusSlot.isTray && !statusSlot.trayExpanded ? 0 : 1

                Behavior on opacity {
                  NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }

                Loader {
                  id: statusLoader
                  property string moduleId: statusSlot.moduleId
                  property string region: statusSlot.region

                  // Omarchy's tray reserves its first slot for its own
                  // hover-chevron. Crop exactly that slot and keep the pinned
                  // icons in their original coordinates behind our control.
                  x: statusSlot.isTray ? -statusSlot.toggleWidth : 0
                  active: root.widgetComponent(moduleId) !== null
                  sourceComponent: root.widgetComponent(moduleId)
                  width: item ? item.implicitWidth : 0
                  height: root.barSize
                  // Keep the host visible so the loaded item's own `visible`
                  // decision remains independent. Binding Loader visibility
                  // back to item.visible traps an initially hidden child.
                  visible: true

                  onItemChanged: {
                    if (statusSlot.registeredItem && statusSlot.registeredItem !== item)
                      root.unregisterWidget(statusSlot.registeredItem)
                    statusSlot.registeredItem = item
                    if (item) root.configureWidget(statusLoader, String(barWindow.screen.name || ""))
                  }
                }
              }

              Item {
                id: trayToggle
                z: 10
                visible: statusSlot.isTray && statusSlot.nativeWidth > 0
                width: statusSlot.toggleWidth
                height: root.barSize

                Rectangle {
                  anchors.fill: parent
                  color: trayMouse.containsMouse ? Util.alpha(root.foreground, 0.10) : "transparent"
                }

                Item {
                  id: trayArrow
                  anchors.centerIn: parent
                  width: Style.space(8)
                  height: Style.space(12)
                  // Expanded content occupies the left side of the status
                  // cluster, so collapse travels right; expansion travels left.
                  rotation: statusSlot.trayExpanded ? 0 : 180
                  scale: trayMouse.containsMouse ? 1.12 : 1

                  Behavior on rotation {
                    RotationAnimation {
                      duration: 200
                      direction: RotationAnimation.Shortest
                      easing.type: Easing.InOutCubic
                    }
                  }

                  Behavior on scale {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                  }

                  Canvas {
                    id: trayArrowCanvas
                    anchors.fill: parent

                    onPaint: {
                      var ctx = getContext("2d")
                      ctx.clearRect(0, 0, width, height)
                      ctx.beginPath()
                      ctx.moveTo(width * 0.25, height * 0.16)
                      ctx.lineTo(width * 0.72, height * 0.50)
                      ctx.lineTo(width * 0.25, height * 0.84)
                      ctx.strokeStyle = root.foreground
                      ctx.lineWidth = Math.max(1.4, Screen.devicePixelRatio)
                      ctx.lineCap = "round"
                      ctx.lineJoin = "round"
                      ctx.stroke()
                    }

                    Connections {
                      target: root
                      function onForegroundChanged() { trayArrowCanvas.requestPaint() }
                    }
                  }
                }

                MouseArea {
                  id: trayMouse
                  anchors.fill: parent
                  acceptedButtons: Qt.LeftButton | Qt.RightButton
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: root.showTooltip(trayToggle,
                    statusSlot.trayExpanded
                      ? "Collapse tray to the right" : "Expand tray to the left")
                  onExited: root.hideTooltip(trayToggle)
                  onClicked: function(mouse) {
                    root.hideTooltip(trayToggle)
                    if (mouse.button === Qt.RightButton && statusLoader.item
                        && "managePopupOpen" in statusLoader.item) {
                      statusLoader.item.managePopupOpen = !statusLoader.item.managePopupOpen
                    } else if (mouse.button === Qt.LeftButton) {
                      statusSlot.trayExpanded = !statusSlot.trayExpanded
                    }
                  }
                }
              }

              Component.onCompleted: {
                if (isTray) root.registerTrayControl(statusSlot, String(barWindow.screen.name || ""))
              }
              Component.onDestruction: {
                root.unregisterWidget(registeredItem)
                if (isTray) root.unregisterTrayControl(statusSlot)
              }
            }
          }
        }
      }

      // Pointer handlers observe passively, so existing workspace, tray and
      // plugin clicks keep their grabs while a double-click anywhere on the
      // bar can still toggle its background.
      TapHandler {
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.DragThreshold
        onDoubleTapped: root.toggleTransparency()
      }

      PopupWindow {
        id: tooltipWindow
        visible: root.tooltipShown && root.tooltipTarget !== null
          && root.targetBelongsToWindow(root.tooltipTarget, barWindow)
        color: "transparent"
        implicitWidth: Math.min(barWindow.width - 12, tooltipLabel.implicitWidth + 20)
        implicitHeight: tooltipLabel.implicitHeight + 14
        anchor {
          id: tooltipAnchor
          window: barWindow
          adjustment: PopupAdjustment.Slide
          edges: Edges.Top | Edges.Left
          gravity: Edges.Bottom | Edges.Right
          rect.width: 1
          rect.height: 1
          onAnchoring: {
            var target = root.tooltipTarget
            if (!root.targetBelongsToWindow(target, barWindow)) return
            var point = barWindow.contentItem.mapFromItem(target,
              target.width / 2 - tooltipWindow.width / 2, target.height + 6)
            tooltipAnchor.rect.x = Math.round(point.x)
            tooltipAnchor.rect.y = Math.round(point.y)
          }
        }
        Rectangle {
          anchors.fill: parent
          color: Color.tooltip.background
          border.color: Color.tooltip.border
          border.width: 1
          radius: 3
          Text {
            id: tooltipLabel
            anchors.centerIn: parent
            width: Math.min(implicitWidth, tooltipWindow.width - 20)
            text: root.tooltipText
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Color.tooltip.text
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
