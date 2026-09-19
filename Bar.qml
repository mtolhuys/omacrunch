import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import qs.Commons
import "Workspace.js" as Workspace

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
  readonly property string position: "top"
  readonly property bool vertical: false
  readonly property int barSize: 30
  property real panelOpacity: 0.92
  readonly property bool transparent: panelOpacity < 1
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
  property var tooltipTarget: null
  property string tooltipText: ""
  property bool tooltipShown: false

  readonly property var statusModules: [
    { id: "omarchy.tray", region: "right" },
    { id: "omarchy.network", region: "right" },
    { id: "omarchy.audio", region: "right" },
    { id: "omarchy.power", region: "right" },
    { id: "omarchy.clock", region: "right" }
  ]
  readonly property var layoutConfig: ({
    left: [{ id: "omacrunch.menu" }, { id: "omacrunch.workspaces" }],
    center: [],
    right: statusModules
  })

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
    if (id === "omarchy.power") return { id: id, showPercentage: true }
    if (id === "omarchy.clock") return { id: id, format: "HH:mm", formatAlt: "ddd d MMM yyyy" }
    return { id: id }
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
    unregisterWidget(item)
    var next = liveWidgets.slice()
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
    if (String(section || "") !== "right") return ""
    var panels = ["omarchy.network", "omarchy.audio", "omarchy.power", "omarchy.clock"]
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
    tooltipShown = tooltipText !== ""
  }

  function hideTooltip(target) {
    if (target && tooltipTarget !== target) return
    tooltipTarget = null
    tooltipText = ""
    tooltipShown = false
  }

  function run(command) {
    if (command) Util.execDetached(command)
  }

  function shellQuote(value) { return Util.shellQuote(String(value || "")) }

  function toggleTransparency() {
    panelOpacity = panelOpacity < 1 ? 1 : 0.92
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
    var workspace = workspaceById(id)
    if (workspace && typeof workspace.activate === "function") workspace.activate()
    else Hyprland.dispatch("dispatch hl.dsp.focus({ workspace = \"" + Number(id) + "\" })")
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
        focusedWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
      })
    }

    function toggleTray(): string {
      return root.toggleTray() ? root.trayState() : "missing"
    }

    function trayState(): string { return root.trayState() }
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
      exclusionMode: ExclusionMode.Auto
      WlrLayershell.namespace: "omacrunch-bar"
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      Component.onCompleted: root.registerBarWindow(barWindow)
      Component.onDestruction: root.unregisterBarWindow(barWindow)

      Rectangle {
        anchors.fill: parent
        color: Util.alpha(root.background, root.panelOpacity)
      }

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Util.alpha(root.foreground, 0.18)
      }

      RowLayout {
        anchors.fill: parent
        spacing: 0

        Item {
          Layout.preferredWidth: root.barSize + Style.space(4)
          Layout.fillHeight: true

          Text {
            anchors.centerIn: parent
            text: "#!"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
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
          Layout.fillWidth: true
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
                width: Math.max(root.barSize, workspaceContent.implicitWidth + Style.space(8))
                color: urgentState
                  ? Util.alpha(root.urgent, 0.34)
                  : (focused ? Util.alpha(root.foreground, 0.12) : "transparent")

                Row {
                  id: workspaceContent
                  z: 1
                  anchors.centerIn: parent
                  height: parent.height
                  spacing: Style.space(2)

                  Text {
                    width: Style.space(16)
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

                      width: Style.space(22)
                      height: workspaceCell.height

                      Rectangle {
                        anchors.fill: parent
                        anchors.margins: Style.space(2)
                        radius: 1
                        color: taskButton.client && taskButton.client.urgent
                          ? Util.alpha(root.urgent, 0.48)
                          : (taskButton.client && taskButton.client.activated
                            ? Util.alpha(root.foreground, 0.16) : "transparent")
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
                        width: Style.space(14)
                        height: width
                        source: taskButton.iconSource
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        opacity: taskButton.client && taskButton.client.activated ? 1 : 0.72
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

              Layout.preferredWidth: isTray && nativeWidth > 0
                ? (trayExpanded ? nativeWidth : toggleWidth) : nativeWidth
              Layout.preferredHeight: root.barSize
              Layout.fillHeight: true
              visible: true
              clip: isTray

              Loader {
                id: statusLoader
                property string moduleId: statusSlot.moduleId
                property string region: statusSlot.region

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

                Text {
                  anchors.centerIn: parent
                  text: statusSlot.trayExpanded ? "\uf053" : "\uf054"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  textFormat: Text.PlainText
                }

                MouseArea {
                  id: trayMouse
                  anchors.fill: parent
                  acceptedButtons: Qt.LeftButton | Qt.RightButton
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: root.showTooltip(trayToggle,
                    statusSlot.trayExpanded ? "Collapse tray" : "Expand tray")
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
    }
  }
}
