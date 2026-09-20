// Omarchy persists per-widget bar settings inside shell.json. Omacrunch owns
// the visual layout, but native widgets must keep using those saved settings.
function configuredEntry(barConfig, id) {
  var layout = barConfig && typeof barConfig === "object" ? barConfig.layout : null
  if (!layout || typeof layout !== "object") return null

  var regions = ["left", "center", "right"]
  for (var regionIndex = 0; regionIndex < regions.length; regionIndex++) {
    var values = layout[regions[regionIndex]]
    if (!Array.isArray(values)) continue
    for (var valueIndex = 0; valueIndex < values.length; valueIndex++) {
      var value = values[valueIndex]
      if (value && typeof value === "object" && String(value.id || "") === id)
        return value
    }
  }
  return null
}

function nonEmptyString(value, fallback) {
  return typeof value === "string" && value.trim() !== "" ? value : fallback
}

function clockSettings(barConfig) {
  var stored = configuredEntry(barConfig, "omarchy.clock") || {}
  return Object.assign({}, stored, {
    id: "omarchy.clock",
    format: nonEmptyString(stored.format, "HH:mm"),
    formatAlt: nonEmptyString(stored.formatAlt, "ddd d MMM yyyy")
  })
}

if (typeof module !== "undefined") module.exports = {
  configuredEntry: configuredEntry,
  clockSettings: clockSettings
}
