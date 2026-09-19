var ids = ["monitor", "weather", "agents", "disk", "calendar"]

function defaults() { return { version: 1, screens: {}, weatherCity: "" } }
function clamp(value, low, high) { return Math.max(low, Math.min(high, value)) }
function normalize(raw) {
  var out = defaults()
  if (!raw || raw.version !== 1) return out
  out.weatherCity = typeof raw.weatherCity === "string" ? raw.weatherCity.trim().slice(0, 120) : ""
  Object.keys(raw.screens || {}).slice(0, 32).forEach(function(screen) {
    var items = {}
    ids.forEach(function(id) {
      var item = raw.screens[screen] && raw.screens[screen][id]
      if (!item || typeof item !== "object") return
      items[id] = { enabled: item.enabled === true }
      if (typeof item.x === "number" && isFinite(item.x) && typeof item.y === "number" && isFinite(item.y)) {
        items[id].x = clamp(item.x, 0, 1)
        items[id].y = clamp(item.y, 0, 1)
      }
    })
    Object.defineProperty(out.screens, screen, { value: items, enumerable: true, writable: true })
  })
  return out
}
function entry(layout, screen, id) {
  var items = Object.prototype.hasOwnProperty.call(layout.screens, screen) ? layout.screens[screen] : {}
  return items[id] || { enabled: id === "monitor" }
}
function change(layout, screen, id, update) {
  if (ids.indexOf(id) < 0 || !screen) return layout
  var next = normalize(layout)
  if (!Object.prototype.hasOwnProperty.call(next.screens, screen))
    Object.defineProperty(next.screens, screen, { value: {}, enumerable: true, writable: true })
  next.screens[screen][id] = Object.assign({}, entry(next, screen, id), update)
  return normalize(next)
}
function position(item, fallbackX, fallbackY, width, height, areaWidth, areaHeight) {
  var minX = 12, minY = 46
  var maxX = Math.max(minX, areaWidth - width - 12)
  var maxY = Math.max(minY, areaHeight - height - 12)
  return {
    x: clamp(item.x === undefined ? fallbackX : minX + item.x * (maxX - minX), minX, maxX),
    y: clamp(item.y === undefined ? fallbackY : minY + item.y * (maxY - minY), minY, maxY)
  }
}
function fraction(x, y, width, height, areaWidth, areaHeight) {
  return {
    x: clamp((Math.round(x / 8) * 8 - 12) / Math.max(1, areaWidth - width - 24), 0, 1),
    y: clamp((Math.round(y / 8) * 8 - 46) / Math.max(1, areaHeight - height - 58), 0, 1)
  }
}
function month(date) {
  var year = date.getFullYear(), m = date.getMonth()
  var offset = (new Date(year, m, 1, 12).getDay() + 6) % 7
  var days = new Date(year, m + 1, 0, 12).getDate()
  return Array.from({ length: 42 }, function(_, index) {
    var day = index - offset + 1
    return { day: day > 0 && day <= days ? day : 0, today: day === date.getDate() }
  })
}
if (typeof module !== "undefined") module.exports = { ids, defaults, normalize, entry, change, position, fraction, month }
