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

function requiredBlackScrim(text, background, target) {
  var maximumBackground = (text + 0.05) / target - 0.05
  if (background <= maximumBackground || background <= 0) return 0
  return 1 - maximumBackground / background
}

function requiredWhiteScrim(text, background, target) {
  var minimumBackground = target * (text + 0.05) - 0.05
  if (background >= minimumBackground || background >= 1) return 0
  return (minimumBackground - background) / (1 - background)
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
    return { useLight: true, scrimOpacity: 0, haloOpacity: 0.94, spread: 1, minimumContrast: 1 }

  var light = colorLuminance(lightCandidate)
  var dark = colorLuminance(darkCandidate)
  luminances.sort(function(left, right) { return left - right })
  var low = percentile(luminances, 0.05)
  var median = percentile(luminances, 0.50)
  var high = percentile(luminances, 0.95)
  var spread = high - low
  var target = 4.5
  var lightOpacity = requiredBlackScrim(light, high, target)
  var darkOpacity = requiredWhiteScrim(dark, low, target)

  // Pick the ink for the representative local tone. The opposite-colour halo
  // handles the minority extreme; letting one bright object dictate the ink
  // for a mostly dark region is exactly what made mixed wallpapers look hollow.
  var useLight = contrast(light, median) >= contrast(dark, median)
  var ratios = []
  var textLuminance = useLight ? light : dark
  for (var j = 0; j < luminances.length; j++) {
    ratios.push(contrast(textLuminance, luminances[j]))
  }
  ratios.sort(function(left, right) { return left - right })
  var minimumContrast = percentile(ratios, 0.05)
  var haloOpacity = minimumContrast < 4.5 || spread > 0.18
    ? clamp(0.42 + spread * 0.18, 0.42, 0.64)
    : 0.24

  return {
    useLight: useLight,
    scrimOpacity: 0,
    haloOpacity: haloOpacity,
    spread: spread,
    minimumContrast: minimumContrast,
    medianLuminance: median,
    requiredExtremeOpacity: useLight ? lightOpacity : darkOpacity
  }
}
