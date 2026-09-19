import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property int selectedIndex: 0
  property real requestedX: Style.space(42)
  property real requestedY: Style.space(42)
  readonly property string pluginId: manifest && manifest.id
    ? String(manifest.id) : "io.github.mtolhuys.omacrunch"
  readonly property var entries: [
    { key: "T", label: "Terminal" },
    { key: "F", label: "Files" },
    { key: "W", label: "Web browser" },
    { key: "A", label: "Applications" },
    { key: "S", label: "Style" },
    { key: "K", label: "Keybindings" },
    { key: "P", label: "Power" }
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
    root.requestedX = Number(payload.x) || Style.space(42)
    root.requestedY = Number(payload.y) || Style.space(42)
    root.selectedIndex = 0
    root.opened = true
    Qt.callLater(function() { keySurface.forceActiveFocus() })
  }

  function close() { root.opened = false }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
    else root.close()
  }

  function move(delta) {
    root.selectedIndex = (root.selectedIndex + delta + root.entries.length) % root.entries.length
  }

  function activate(index) {
    if (index === 0) Quickshell.execDetached(["omarchy-launch-terminal"])
    else if (index === 1) Quickshell.execDetached(["omarchy-launch-nautilus"])
    else if (index === 2) Quickshell.execDetached(["omarchy-launch-browser"])
    else if (index === 3) Quickshell.execDetached(["omarchy-menu", "toggle", "apps"])
    else if (index === 4) Quickshell.execDetached(["omarchy-menu", "toggle", "style"])
    else if (index === 5) Quickshell.execDetached(["omarchy-menu-keybindings"])
    else if (index === 6) Quickshell.execDetached(["omarchy-menu", "toggle", "system"])
    else return
    root.dismiss()
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

  PanelWindow {
    id: overlay
    screen: root.targetScreen
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omacrunch-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      onClicked: root.dismiss()
    }

    FocusScope {
      id: keySurface
      anchors.fill: parent
      focus: root.opened

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
          root.dismiss(); event.accepted = true
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

            Text {
              text: "#!  OMACRUNCH"
              color: Color.menu.text
              font.family: "monospace"
              font.pixelSize: Style.font.title
              font.bold: true
              font.letterSpacing: 1
            }
            Item { Layout.fillWidth: true }
            Text {
              text: "ROOT"
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
                  color: index === root.selectedIndex ? Color.menu.selectedText : Color.menu.text
                  font.family: "monospace"
                  font.pixelSize: Style.font.body
                }
                Text {
                  visible: index >= 3 && index !== 5
                  text: "›"
                  color: Util.alpha(index === root.selectedIndex ? Color.menu.selectedText : Color.menu.text, 0.65)
                  font.family: "monospace"
                  font.pixelSize: Style.font.body
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
        }
      }
    }
  }
}
