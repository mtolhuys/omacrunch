import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property int selectedIndex: 0

  readonly property string pluginId: manifest && manifest.id
    ? String(manifest.id) : "io.github.mtolhuys.omacrunch"
  readonly property var actions: [
    { key: "T", label: "Terminal", detail: "Start a clean shell", command: ["omarchy-launch-terminal"] },
    { key: "F", label: "Files", detail: "Browse the filesystem", command: ["omarchy-launch-nautilus"] },
    { key: "W", label: "Web", detail: "Open the default browser", command: ["omarchy-launch-browser"] },
    { key: "A", label: "Applications", detail: "Search installed applications", command: ["omarchy-menu", "toggle", "apps"] },
    { key: "K", label: "Keybindings", detail: "Show the Omarchy shortcut map", command: ["omarchy-menu-keybindings"] },
    { key: "P", label: "Power", detail: "Lock, sleep, restart or shut down", command: ["omarchy-menu", "toggle", "system"] }
  ]
  readonly property var shortcuts: [
    { keys: "SUPER + RETURN", label: "terminal" },
    { keys: "SUPER + SPACE", label: "menu" },
    { keys: "SUPER + 1…9", label: "workspace" },
    { keys: "SUPER + Q", label: "close window" }
  ]

  function open(payloadJson) {
    root.selectedIndex = 0
    root.opened = true
    Qt.callLater(function() { keySurface.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide(root.pluginId)
    else
      root.close()
  }

  function moveSelection(delta) {
    var count = root.actions.length
    root.selectedIndex = (root.selectedIndex + delta + count) % count
  }

  function activate(index) {
    var action = root.actions[index]
    if (!action || !Array.isArray(action.command) || action.command.length === 0) return
    Quickshell.execDetached(action.command)
    root.dismiss()
  }

  function activateKey(text) {
    var key = String(text || "").toUpperCase()
    for (var i = 0; i < root.actions.length; i++) {
      if (root.actions[i].key === key) {
        root.selectedIndex = i
        root.activate(i)
        return true
      }
    }
    return false
  }

  IpcHandler {
    target: "omacrunch"

    function open(): string { root.open("{}"); return "ok" }
    function close(): string { root.dismiss(); return "ok" }
    function toggle(): string {
      if (root.opened) root.dismiss()
      else root.open("{}")
      return "ok"
    }
    function state(): string { return root.opened ? "open" : "closed" }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  PanelWindow {
    id: overlay

    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omacrunch"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened
      ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim

      MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
      }
    }

    FocusScope {
      id: keySurface
      anchors.fill: parent
      focus: root.opened

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) {
          root.dismiss()
          event.accepted = true
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
          root.moveSelection(1)
          event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
          root.moveSelection(-1)
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.activate(root.selectedIndex)
          event.accepted = true
        } else if (root.activateKey(event.text)) {
          event.accepted = true
        }
      }

      BorderSurface {
        id: card

        width: Math.min(Style.space(760), overlay.width - Style.gapsOut * 2)
        height: Math.min(Style.space(610), overlay.height - Style.gapsOut * 2)
        anchors.centerIn: parent
        color: Color.menu.background
        borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(1)))
        radius: 0

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.NoButton
        }

        RowLayout {
          anchors.fill: parent
          anchors.margins: Style.space(28)
          spacing: Style.space(30)

          ColumnLayout {
            Layout.preferredWidth: Style.space(190)
            Layout.fillHeight: true
            spacing: Style.space(12)

            Text {
              text: "#!"
              color: Color.menu.text
              font.family: "monospace"
              font.pixelSize: Style.space(64)
              font.bold: true
            }

            Text {
              text: "OMACRUNCH"
              color: Color.menu.text
              font.family: "monospace"
              font.pixelSize: Style.font.title
              font.bold: true
              font.letterSpacing: 2
            }

            Text {
              Layout.fillWidth: true
              text: "minimal shell\nmaximum intent"
              color: Util.alpha(Color.menu.text, 0.62)
              font.family: "monospace"
              font.pixelSize: Style.font.body
              lineHeight: 1.35
            }

            Item { Layout.fillHeight: true }

            Text {
              text: Qt.formatDateTime(clock.date, "ddd d MMM\nHH:mm")
              color: Color.menu.text
              font.family: "monospace"
              font.pixelSize: Style.font.title
              lineHeight: 1.25
            }

            Text {
              text: "OMARCHY / HYPRLAND"
              color: Util.alpha(Color.menu.text, 0.45)
              font.family: "monospace"
              font.pixelSize: Style.font.caption
            }
          }

          Rectangle {
            Layout.preferredWidth: Math.max(1, Style.space(1))
            Layout.fillHeight: true
            color: Util.alpha(Color.menu.text, 0.28)
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Style.space(12)

            Text {
              text: "RUN"
              color: Util.alpha(Color.menu.text, 0.55)
              font.family: "monospace"
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 2
            }

            Repeater {
              model: root.actions

              delegate: Rectangle {
                required property int index
                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(48)
                color: index === root.selectedIndex
                  ? Color.menu.selectedBackground : "transparent"
                border.width: index === root.selectedIndex ? Math.max(1, Style.space(1)) : 0
                border.color: Color.menu.selectedBorder.a > 0
                  ? Color.menu.selectedBorder : Util.alpha(Color.menu.text, 0.32)
                radius: 0

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(12)
                  anchors.rightMargin: Style.space(12)
                  spacing: Style.space(14)

                  Text {
                    Layout.preferredWidth: Style.space(24)
                    text: modelData.key
                    color: index === root.selectedIndex
                      ? Color.menu.selectedText : Color.menu.text
                    font.family: "monospace"
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                      Layout.fillWidth: true
                      text: modelData.label
                      color: index === root.selectedIndex
                        ? Color.menu.selectedText : Color.menu.text
                      font.family: "monospace"
                      font.pixelSize: Style.font.body
                      font.bold: true
                    }

                    Text {
                      Layout.fillWidth: true
                      text: modelData.detail
                      color: Util.alpha(index === root.selectedIndex
                        ? Color.menu.selectedText : Color.menu.text, 0.58)
                      font.family: "monospace"
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }
                  }

                  Text {
                    text: "›"
                    color: Util.alpha(index === root.selectedIndex
                      ? Color.menu.selectedText : Color.menu.text, 0.7)
                    font.family: "monospace"
                    font.pixelSize: Style.font.title
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

            Item { Layout.fillHeight: true }

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: Math.max(1, Style.space(1))
              color: Util.alpha(Color.menu.text, 0.20)
            }

            GridLayout {
              Layout.fillWidth: true
              columns: 2
              columnSpacing: Style.space(18)
              rowSpacing: Style.space(6)

              Repeater {
                model: root.shortcuts

                delegate: RowLayout {
                  required property var modelData
                  Layout.fillWidth: true
                  spacing: Style.space(8)

                  Text {
                    text: modelData.keys
                    color: Color.menu.text
                    font.family: "monospace"
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }

                  Text {
                    Layout.fillWidth: true
                    text: modelData.label
                    color: Util.alpha(Color.menu.text, 0.48)
                    font.family: "monospace"
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }
              }
            }

            Text {
              Layout.alignment: Qt.AlignRight
              text: "↑↓ / JK  navigate    ENTER  run    ESC  close"
              color: Util.alpha(Color.menu.text, 0.42)
              font.family: "monospace"
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }
  }
}
