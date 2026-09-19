function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(maximum, value))
}

function channel(value) {
  var c = clamp(Number(value) || 0, 0, 1)
  return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
}

function colorLuminance(color) {
  if (typeof color === "string") {
    var match = color.match(/^#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i)
    if (match) {
      return 0.2126 * channel(parseInt(match[1], 16) / 255)
        + 0.7152 * channel(parseInt(match[2], 16) / 255)
        + 0.0722 * channel(parseInt(match[3], 16) / 255)
    }
  }
  return 0.2126 * channel(color && color.r)
    + 0.7152 * channel(color && color.g)
    + 0.0722 * channel(color && color.b)
}

function contrast(first, second) {
  var high = Math.max(first, second)
  var low = Math.min(first, second)
  return (high + 0.05) / (low + 0.05)
}

function percentile(sorted, fraction) {
  if (!sorted.length) return 0
  return sorted[Math.min(sorted.length - 1, Math.floor(fraction * (sorted.length - 1)))]
}

function analyze(pixels, lightCandidate, darkCandidate) {
  var luminances = []
  for (var i = 0; i + 3 < pixels.length; i += 4) {
    if (pixels[i + 3] < 16) continue
    luminances.push(0.2126 * channel(pixels[i] / 255)
      + 0.7152 * channel(pixels[i + 1] / 255)
      + 0.0722 * channel(pixels[i + 2] / 255))
  }
  if (!luminances.length)
    return { useLight: true, scrimOpacity: 0.18, spread: 1, minimumContrast: 1 }

  var light = colorLuminance(lightCandidate)
  var dark = colorLuminance(darkCandidate)
  var lightRatios = []
  var darkRatios = []
  luminances.sort(function(left, right) { return left - right })
  for (var j = 0; j < luminances.length; j++) {
    lightRatios.push(contrast(light, luminances[j]))
    darkRatios.push(contrast(dark, luminances[j]))
  }
  lightRatios.sort(function(left, right) { return left - right })
  darkRatios.sort(function(left, right) { return left - right })

  var lightFloor = percentile(lightRatios, 0.10)
  var darkFloor = percentile(darkRatios, 0.10)
  var useLight = lightFloor >= darkFloor
  var minimumContrast = useLight ? lightFloor : darkFloor
  var spread = percentile(luminances, 0.90) - percentile(luminances, 0.10)
  var contrastDebt = clamp((4.5 - minimumContrast) / 4.5, 0, 1)
  var mixedBackground = clamp((spread - 0.18) / 0.55, 0, 1)
  var scrimOpacity = clamp(contrastDebt * 0.42 + mixedBackground * 0.30, 0, 0.52)

  return {
    useLight: useLight,
    scrimOpacity: scrimOpacity,
    spread: spread,
    minimumContrast: minimumContrast
  }
}
