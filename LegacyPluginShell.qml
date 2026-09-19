import QtQuick

// Only for shells whose public bar contract directly injects ShellRoot.
// Never use as fallback when a modern scoped factory exists but refuses.
QtObject {
  id: bridge
  required property var legacyShell
  required property string pluginId
  required property string moduleName
  readonly property var barConfig: legacyShell ? legacyShell.barConfig : ({})
  function owns(id) { return id === pluginId || id === moduleName }
  function serviceFor(id) {
    return owns(id) && legacyShell && typeof legacyShell.serviceFor === "function"
      ? legacyShell.serviceFor(pluginId) : null
  }
  function summon(id, payload) { return owns(id) && legacyShell ? legacyShell.summon(pluginId, payload || "") : false }
  function hide(id) { return owns(id) && legacyShell ? legacyShell.hide(pluginId) : false }
  function toggle(id, payload) { return owns(id) && legacyShell ? legacyShell.toggle(pluginId, payload || "") : false }
  function isPluginOpen(id) { return owns(id) && legacyShell ? legacyShell.isPluginOpen(pluginId) : false }
  function updateEntryInline(id, settings) {
    return id === moduleName && legacyShell ? legacyShell.updateEntryInline(moduleName, settings) : false
  }
}
