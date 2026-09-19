import QtQuick
import Quickshell

// Omacrunch is intentionally barless. Selecting this bar plugin replaces the
// stock Omarchy bar with a host-compatible object that creates no surfaces.
Item {
  id: root

  // Replacement bars are instantiated before the host injects these values.
  // Defaults are therefore mandatory; `required` makes the Loader reject the
  // component before configureBar() gets a chance to assign them.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var barWidgetRegistry: null
  property var barConfig: ({})
  property var shell: null
  property var manifest: null
  property var pluginRegistry: null

  function debugBarGeometry() { return [] }
  function summonBarWidget(pluginId) { return false }
  function hideBarWidget(pluginId) { return false }
  function isBarWidgetOpen(pluginId) { return false }
  function panelWidgetIdAt(section, index) { return "" }
  function toggleTransparency() {}
}
