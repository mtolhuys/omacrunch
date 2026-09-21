import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "MenuActions.js" as MenuActions
import "omakit" as Omakit

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var service: null
  property string page: "root"
  readonly property var store: service ? service.widgetStore : null
  property bool opened: false
  property bool focusPrimed: false
  property int selectedIndex: 0
  property real requestedX: Style.space(42)
  property real requestedY: Style.space(42)
  property string shortcutState: "checking"
  property string shortcutMessage: ""
  property string shortcutAction: "status-code"
  readonly property string pluginId: manifest && manifest.id
    ? String(manifest.id) : "io.github.mtolhuys.omacrunch"
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  readonly property string shortcutHelper: decodeURIComponent(
    String(Qt.resolvedUrl("shortcut.py")).replace(/^file:\/\//, ""))
  readonly property bool shortcutBusy: shortcutRun.running
  readonly property var rootEntries: MenuActions.rootEntries(root.shortcutState, root.shortcutBusy)
  readonly property int widgetsIndex: rootEntries.findIndex(function(entry) { return entry.action === "widgets" })
  readonly property var entries: page === "widgets" ? widgetEntries : rootEntries
  readonly property string screenName: targetScreen ? String(targetScreen.name) : ""
  readonly property var widgetEntries: [
    { key: "M", label: "System Monitor", widget: "monitor" },
    { key: "W", label: "Weather", widget: "weather" },
    { key: "A", label: "Agent Usage", widget: "agents" },
    { key: "D", label: "Disk Usage", widget: "disk" },
    { key: "C", label: "Calendar", widget: "calendar" },
    { key: "E", label: "Edit layout", action: "edit" },
    { key: "L", label: "Weather location", action: "location" },
    { key: "B", label: "Back", action: "back" }
  ]

  function focusedScreen() {
    var name = Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name || "") : ""
    for (var i = 0; i < Quickshell.screens.length; i++)
      if (String(Quickshell.screens[i].name || "") === name) return Quickshell.screens[i]
    return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
  }

  property var targetScreen: focusedScreen()

  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") } catch (e) {}
    root.targetScreen = root.focusedScreen()
    root.page = payload.page === "widgets" ? "widgets" : "root"
    root.requestedX = Number(payload.x) || Style.space(42)
    root.requestedY = Number(payload.y) || Style.space(42)
    root.selectedIndex = 0
    locationBox.visible = false
    root.focusPrimed = false
    root.opened = true
    root.refreshShortcut()
    focusPrimeTimer.restart()
    Qt.callLater(function() { keySurface.forceActiveFocus() })
  }

  function close() {
    focusPrimeTimer.stop()
    root.focusPrimed = false
    root.opened = false
  }

  function state() { return root.opened ? "open" : "closed" }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
    else root.close()
  }

  function move(delta) {
    root.selectedIndex = (root.selectedIndex + delta + root.entries.length) % root.entries.length
  }

  function runShortcut(action) {
    if (shortcutRun.running) return false
    root.shortcutAction = action
    shortcutRun.command = ["/usr/bin/python3", "-I", "-S", "-B", root.shortcutHelper, action]
    shortcutRun.start()
    return true
  }

  function refreshShortcut(clearMessage) {
    if (clearMessage !== false) root.shortcutMessage = ""
    root.shortcutState = "checking"
    root.runShortcut("status-code")
  }

  function finishShortcut(result) {
    var code = result.state === "ok" ? 0 : (result.state === "exit" ? result.exitCode : -1)
    if (result.state === "timeout") {
      root.shortcutState = "unavailable"
      root.shortcutMessage = "Shortcut inspection timed out."
      return
    }
    if (root.shortcutAction === "status-code") {
      if (code === 0) root.shortcutState = "free"
      else if (code === 10) root.shortcutState = "owned"
      else if (code === 11) {
        root.shortcutState = "personal-conflict"
        root.shortcutMessage = "Super+Alt+C is already in use."
      } else if (code === 12) {
        root.shortcutState = "ambiguous"
        root.shortcutMessage = "The Omacrunch shortcut block needs manual attention."
      } else {
        root.shortcutState = "unavailable"
        root.shortcutMessage = "Could not inspect Super+Alt+C."
      }
      return
    }
    if (code === 0) root.shortcutMessage = root.shortcutAction === "install-quiet"
      ? "Super+Alt+C installed." : "Super+Alt+C removed."
    else root.shortcutMessage = "Shortcut change was refused; no personal binding was replaced."
    Qt.callLater(function() { root.refreshShortcut(false) })
  }

  function manageShortcut() {
    if (root.shortcutState === "free") root.runShortcut("install-quiet")
    else if (root.shortcutState === "owned") root.runShortcut("remove-quiet")
    else if (root.shortcutState !== "checking") root.refreshShortcut()
  }

  function activate(index) {
    var entry = entries[index]
    if (!entry) return
    if (entry.enabled === false) {
      if (!root.shortcutMessage) root.shortcutMessage = "Super+Alt+C is unavailable."
      return
    }
    if (entry.action === "widgets") { page = "widgets"; selectedIndex = 0; return }
    if (page === "widgets") {
      if (!store) return
      if (entry.widget) { store.toggle(screenName, entry.widget); return }
      if (entry.action === "back") { page = "root"; selectedIndex = widgetsIndex; return }
      if (entry.action === "location") { locationInput.text = store.layout.weatherCity; locationBox.visible = true; locationInput.forceActiveFocus(); return }
      if (entry.action === "edit") { root.dismiss(); store.begin(); return }
      return
    }
    if (entry.action === "shortcut") { root.manageShortcut(); return }
    var command = MenuActions.commandFor(entry)
    if (!command.length) return
    root.dismiss()
    command[0] = root.omarchyPath + "/bin/" + command[0]
    menuActionRun.command = command
    menuActionRun.start()
  }

  function activateKey(text) {
    var key = String(text || "").toUpperCase()
    for (var i = 0; i < root.entries.length; i++) {
      if (root.entries[i].key === key) {
        root.selectedIndex = i
        root.activate(i)
        return true
      }
    }
    return false
  }

  Timer {
    id: focusPrimeTimer
    interval: 75
    repeat: false
    onTriggered: if (root.opened) root.focusPrimed = true
  }

  function sessionEnvironment(includeOmarchyPath) {
    var result = {}
    ;["WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE", "DBUS_SESSION_BUS_ADDRESS", "DISPLAY",
      "XDG_CONFIG_HOME", "XDG_STATE_HOME"].forEach(function(name) {
      var value = Quickshell.env(name)
      if (value) result[name] = value
    })
    if (includeOmarchyPath) result.PATH = root.omarchyPath + "/bin:/usr/bin"
    return result
  }

  Omakit.Run {
    id: shortcutRun
    environment: root.sessionEnvironment(false)
    deadlineMs: 12000
    maxBytes: 65536
    keepBytes: 65536
    maxLines: 1024
    onFinished: function(result) { root.finishShortcut(result) }
  }

  Omakit.Run {
    id: menuActionRun
    environment: root.sessionEnvironment(true)
    deadlineMs: 30000
    maxBytes: 65536
    keepBytes: 4096
    maxLines: 1024
    onFinished: function(result) {
      if (result.state === "ok") return
      root.open("{}")
      root.shortcutMessage = "Menu action failed (" + result.state + ")."
    }
  }

  PanelWindow {
    id: overlay
    screen: root.targetScreen
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omacrunch-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened
      ? (root.focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
      : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    onVisibleChanged: if (visible) focusPrimeTimer.restart()

    MouseArea {
      anchors.fill: parent
      enabled: root.opened
      acceptedButtons: Qt.AllButtons
      onClicked: root.dismiss()
    }

    FocusScope {
      id: keySurface
      anchors.fill: parent
      focus: root.opened

      Keys.onPressed: function(event) {
        var commandModifiers = event.modifiers
          & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)
        if (commandModifiers) {
          event.accepted = false
        } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
          if (root.page === "widgets") { root.page = "root"; root.selectedIndex = root.widgetsIndex }
          else root.dismiss()
          event.accepted = true
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
          root.move(1); event.accepted = true
        } else if (event.key === Qt.Key_Up) {
          root.move(-1); event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.activate(root.selectedIndex); event.accepted = true
        } else if (root.activateKey(event.text)) {
          event.accepted = true
        }
      }

      BorderSurface {
        id: menuCard
        width: Style.space(292)
        height: menuColumn.implicitHeight + Style.space(24)
        x: Math.max(Style.gapsOut, Math.min(root.requestedX, overlay.width - width - Style.gapsOut))
        y: Math.max(Style.gapsOut, Math.min(root.requestedY, overlay.height - height - Style.gapsOut))
        color: Color.menu.background
        borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(1)))
        radius: 0

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        }

        Column {
          id: menuColumn
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(12)
          spacing: Style.space(2)

          RowLayout {
            width: parent.width
            height: Style.space(40)
            spacing: Style.space(10)

            Text {
              Layout.leftMargin: Style.space(9)
              Layout.preferredWidth: Style.space(20)
              horizontalAlignment: Text.AlignHCenter
              text: "\ue900"
              textFormat: Text.PlainText
              color: Color.menu.text
              font.family: "omarchy"
              font.pixelSize: Style.font.title
              Accessible.name: "Omarchy"
            }
            Text {
              Layout.fillWidth: true
              text: "Crunch #!"
              textFormat: Text.PlainText
              color: Color.menu.text
              font.family: "monospace"
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }
            Text {
              visible: root.page === "widgets"
              text: "WIDGETS"
              textFormat: Text.PlainText
              color: Util.alpha(Color.menu.text, 0.45)
              font.family: "monospace"
              font.pixelSize: Style.font.caption
            }
          }

          Rectangle { width: parent.width; height: Math.max(1, Style.space(1)); color: Util.alpha(Color.menu.text, 0.22) }

          Repeater {
            model: root.entries

            delegate: Rectangle {
              required property int index
              required property var modelData
              width: menuColumn.width
              height: Style.space(38)
              color: index === root.selectedIndex ? Color.menu.selectedBackground : "transparent"
              radius: 0

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(9)
                anchors.rightMargin: Style.space(9)
                spacing: Style.space(10)

                Text {
                  Layout.preferredWidth: Style.space(20)
                  text: modelData.key
                  color: index === root.selectedIndex ? Color.menu.selectedText : Util.alpha(Color.menu.text, 0.55)
                  font.family: "monospace"
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
                Text {
                  Layout.fillWidth: true
                  text: modelData.label
                  color: modelData.enabled === false
                    ? Util.alpha(Color.menu.text, 0.42)
                    : (index === root.selectedIndex ? Color.menu.selectedText : Color.menu.text)
                  font.family: "monospace"
                  font.pixelSize: Style.font.body
                }
                Text {
                  visible: root.page === "widgets" || !!modelData.route
                    || modelData.action === "widgets" || !!modelData.hint
                  text: modelData.hint ? modelData.hint
                    : (modelData.widget && root.store
                      ? (root.store.enabled(root.screenName, modelData.widget) ? "●" : "○")
                      : "›")
                  color: Util.alpha(index === root.selectedIndex ? Color.menu.selectedText : Color.menu.text, 0.65)
                  font.family: "monospace"
                  font.pixelSize: modelData.hint ? Style.font.caption : Style.font.body
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selectedIndex = index
                onClicked: root.activate(index)
              }
            }
          }
          Column {
            id: locationBox
            visible: false
            width: parent.width
            spacing: Style.space(8)
            Text { width: parent.width; text: "City (blank follows Omarchy) · Enter to save"; wrapMode: Text.WordWrap; color: Color.menu.text; font.pixelSize: Style.font.caption }
            Rectangle {
              width: parent.width; height: Style.space(36)
              color: Color.menu.selectedBackground
              TextInput {
                id: locationInput
                anchors.fill: parent; anchors.margins: Style.space(8)
                color: Color.menu.text; font.family: "monospace"; font.pixelSize: Style.font.body
                maximumLength: 120; clip: true; selectByMouse: true
                onAccepted: { if (root.store && root.store.setCity(text)) { locationBox.visible = false; keySurface.forceActiveFocus() } }
                Keys.onEscapePressed: { locationBox.visible = false; keySurface.forceActiveFocus() }
              }
            }
          }
          Text {
            visible: root.page === "root" && root.shortcutMessage !== ""
            width: parent.width
            text: root.shortcutMessage
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: Util.alpha(Color.menu.text, 0.62)
            font.family: "monospace"
            font.pixelSize: Style.font.caption
          }
          Text {
            visible: root.page === "widgets"
            width: parent.width
            text: root.store && root.store.error ? root.store.error : "Layout for " + root.screenName + " · ● visible / ○ hidden"
            textFormat: Text.PlainText; wrapMode: Text.WordWrap
            color: Color.menu.text; font.family: "monospace"; font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
