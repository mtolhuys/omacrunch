function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(maximum, value))
}

function number(value, fallback) {
  var parsed = Number(value)
  return isFinite(parsed) ? parsed : fallback
}

function parseCpu(raw, previous) {
  var first = String(raw || "").split("\n")[0].trim().split(/\s+/)
  if (first[0] !== "cpu" || first.length < 5)
    return { total: 0, idle: 0, percent: 0, ready: false }

  var total = 0
  for (var i = 1; i < first.length; i++) total += number(first[i], 0)
  var idle = number(first[4], 0) + number(first[5], 0)
  var oldTotal = previous ? number(previous.total, 0) : 0
  var oldIdle = previous ? number(previous.idle, 0) : 0
  var deltaTotal = total - oldTotal
  var deltaIdle = idle - oldIdle
  var percent = deltaTotal > 0 ? 100 * (deltaTotal - deltaIdle) / deltaTotal : 0
  return { total: total, idle: idle, percent: clamp(percent, 0, 100), ready: oldTotal > 0 }
}

function parseMemory(raw) {
  var values = {}
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(/^([A-Za-z_()]+):\s+(\d+)/)
    if (match) values[match[1]] = number(match[2], 0) * 1024
  }
  var total = values.MemTotal || 0
  var available = values.MemAvailable || values.MemFree || 0
  var used = Math.max(0, total - available)
  var swapTotal = values.SwapTotal || 0
  var swapUsed = Math.max(0, swapTotal - (values.SwapFree || 0))
  return {
    total: total,
    used: used,
    percent: total > 0 ? clamp(100 * used / total, 0, 100) : 0,
    swapTotal: swapTotal,
    swapUsed: swapUsed
  }
}

function parseLoad(raw) {
  var fields = String(raw || "").trim().split(/\s+/)
  return {
    one: number(fields[0], 0),
    five: number(fields[1], 0),
    fifteen: number(fields[2], 0)
  }
}

function parseUptime(raw) {
  var seconds = Math.max(0, Math.floor(number(String(raw || "").trim().split(/\s+/)[0], 0)))
  var days = Math.floor(seconds / 86400)
  var hours = Math.floor((seconds % 86400) / 3600)
  var minutes = Math.floor((seconds % 3600) / 60)
  return {
    seconds: seconds,
    label: (days > 0 ? days + "d " : "") + hours + "h " + minutes + "m"
  }
}

function parseNetwork(raw, previous, nowMs) {
  var received = 0
  var transmitted = 0
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(/^\s*([^:]+):\s*(.*)$/)
    if (!match || match[1].trim() === "lo") continue
    var fields = match[2].trim().split(/\s+/)
    received += number(fields[0], 0)
    transmitted += number(fields[8], 0)
  }
  var oldTime = previous ? number(previous.timeMs, 0) : 0
  var oldReceived = previous ? number(previous.received, received) : received
  var oldTransmitted = previous ? number(previous.transmitted, transmitted) : transmitted
  var elapsed = Math.max(0, nowMs - oldTime) / 1000
  var down = elapsed > 0 ? Math.max(0, received - oldReceived) / elapsed : 0
  var up = elapsed > 0 ? Math.max(0, transmitted - oldTransmitted) / elapsed : 0
  return {
    received: received,
    transmitted: transmitted,
    timeMs: nowMs,
    down: down,
    up: up,
    ready: oldTime > 0
  }
}

function pushSample(samples, value, limit) {
  var next = Array.isArray(samples) ? samples.slice() : []
  next.push(clamp(number(value, 0), 0, 100))
  while (next.length > limit) next.shift()
  return next
}

function formatBytes(bytes) {
  var value = Math.max(0, number(bytes, 0))
  if (value >= 1073741824) return (value / 1073741824).toFixed(1) + " GiB"
  if (value >= 1048576) return (value / 1048576).toFixed(1) + " MiB"
  if (value >= 1024) return (value / 1024).toFixed(1) + " KiB"
  return Math.round(value) + " B"
}

function formatRate(bytesPerSecond) {
  return formatBytes(bytesPerSecond) + "/s"
}

function cpuModel(raw) {
  var match = String(raw || "").match(/^model name\s*:\s*(.+)$/m)
  return match ? match[1].trim() : "processor"
}
