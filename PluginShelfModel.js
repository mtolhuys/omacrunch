// Only enabled, configured external bar widgets belong here. The public
// registry is authoritative; never scan/load another plugin from its path.
function isExternal(metadata, manifests, id) {
  if (!metadata || metadata.source !== "plugin") return false
  if (metadata.firstParty !== undefined) return metadata.firstParty === false
  // Older hosts put this classification on the injected registry manifest.
  var manifest = manifests && manifests[id]
  return !!manifest && manifest.__isFirstParty === false
}

function entries(config, widgets, selfId, manifests) {
  var result = [], seen = Object.create(null)
  var layout = config && config.layout ? config.layout : {}
  ;["left", "center", "right"].forEach(function(region) {
    var configured = Array.isArray(layout[region]) ? layout[region] : []
    configured.forEach(function(value) {
      var entry = typeof value === "string" ? { id: value } : value
      var id = entry && typeof entry.id === "string" ? entry.id : ""
      var record = widgets && widgets[id]
      var metadata = record && record.metadata
      if (!id || seen[id] || id === selfId || !record || !record.component
          || !isExternal(metadata, manifests, id)) return
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

function normalizeOrder(value) {
  var seen = Object.create(null)
  return (Array.isArray(value) ? value : []).slice(0, 512).filter(function(id) {
    if (typeof id !== "string" || !/^[a-zA-Z0-9][a-zA-Z0-9._-]{0,199}$/.test(id) || seen[id]) return false
    seen[id] = true
    return true
  })
}

function orderedEntries(values, order) {
  var ranks = normalizeOrder(order)
  // Unseen plugins append in configured order; disabled plugins keep their
  // remembered position without becoming enabled or loaded by this preference.
  return values.filter(function(entry) { return ranks.indexOf(entry.id) >= 0 })
    .sort(function(a, b) { return ranks.indexOf(a.id) - ranks.indexOf(b.id) })
    .concat(values.filter(function(entry) { return ranks.indexOf(entry.id) < 0 }))
}

function mergeOrder(saved, visible) {
  var next = normalizeOrder(visible), index = 0
  var result = normalizeOrder(saved).map(function(id) {
    return next.indexOf(id) >= 0 ? next[index++] : id
  })
  return normalizeOrder(result.concat(next.slice(index)))
}

function moveId(ids, id, beforeId) {
  var result = ids.slice()
  if (result.indexOf(id) < 0 || id === beforeId
      || (beforeId && result.indexOf(beforeId) < 0)) return result
  result.splice(result.indexOf(id), 1)
  result.splice(beforeId ? result.indexOf(beforeId) : result.length, 0, id)
  return result
}

if (typeof module !== "undefined") module.exports = {
  entries: entries, sameIds: sameIds, normalizeOrder: normalizeOrder,
  orderedEntries: orderedEntries, mergeOrder: mergeOrder, moveId: moveId
}
