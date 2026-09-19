import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root

  moduleName: "io.github.mtolhuys.omacrunch"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "#!"
    fontFamily: "monospace"
    fontSize: Style.font.title
    horizontalMargin: 9
    tooltipText: "Omacrunch · left: command deck · middle: keybindings · right: apps"

    onPressed: function(button) {
      if (!root.bar) return
      if (button === Qt.MiddleButton)
        root.bar.run("omarchy-menu-keybindings")
      else if (button === Qt.RightButton)
        root.bar.run("omarchy-menu toggle apps")
      else
        root.bar.run("omarchy-shell shell toggle io.github.mtolhuys.omacrunch '{}'")
    }
  }
}
