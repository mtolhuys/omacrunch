function parsePixelLine(line) {
  var match = String(line || "").match(
    /^\s*(\d+),(\d+):.*#([0-9a-f]{6})(?:[0-9a-f]{2})?(?:\s|$)/i
  )
  if (!match) return null

  var hex = match[3]
  return {
    x: parseInt(match[1], 10),
    y: parseInt(match[2], 10),
    red: parseInt(hex.slice(0, 2), 16),
    green: parseInt(hex.slice(2, 4), 16),
    blue: parseInt(hex.slice(4, 6), 16)
  }
}
