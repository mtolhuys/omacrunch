// Only enabled, configured external bar widgets belong here. The public
// registry is authoritative; never scan/load another plugin from its path.
function entries(config, widgets, selfId) {
  var result = [], seen = Object.create(null)
  var layout = config && config.layout ? config.layout : {}
  ;["left", "center", "right"].forEach(function(region) {
    var configured = Array.isArray(layout[region]) ? layout[region] : []
    configured.forEach(function(value) {
      var entry = typeof value === "string" ? { id: value } : value
      var id = entry && typeof entry.id === "string" ? entry.id : ""
      var record = widgets && widgets[id]
      var metadata = record && record.metadata
      if (!id || seen[id] || id === selfId || !record || !record.component || !metadata
          || metadata.firstParty !== false || metadata.source !== "plugin") return
      seen[id] = true
      var settings = Object.assign({}, metadata.defaults || {}, entry, { id: id })
      result.push({ id: id, pluginId: String(metadata.pluginId || id), settings: settings,
        name: String(metadata.displayName || id), originalRegion: region })
    })
  })
  return result
}

function sameIds(first, second) {
  return first.length === second.length && first.every(function(id, index) {
    return id === second[index]
  })
}

if (typeof module !== "undefined") module.exports = { entries: entries, sameIds: sameIds }
