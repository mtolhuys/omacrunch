import QtQuick

// Omacrunch is intentionally barless. Selecting this bar plugin replaces the
// stock Omarchy bar with a host-compatible object that creates no surfaces.
Item {
  id: root

  required property string omarchyPath
  required property var barWidgetRegistry
  required property var barConfig
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
