function parseDetails(raw) {
  var result = {}
  String(raw || "").split("\n").forEach(function(line) {
    var parts = line.split("\t")
    if (parts.length >= 2) result[parts[0]] = parts.slice(1).join("\t").trim()
  })
  return result
}

function parseNetworks(raw) {
  return String(raw || "").split("\n").filter(function(line) {
    return line.trim() !== ""
  }).map(function(line) {
    var parts = []
    var current = ""
    var escaped = false
    for (var i = 0; i < line.length; i++) {
      var character = line[i]
      if (escaped) {
        current += character
        escaped = false
      } else if (character === "\\") {
        escaped = true
      } else if (character === ":") {
        parts.push(current)
        current = ""
      } else {
        current += character
      }
    }
    parts.push(current)
    return {
      active: parts[0] === "yes" || parts[0] === "*",
      ssid: parts.slice(1, -2).join(":") || "Hidden network",
      signal: parseInt(parts[parts.length - 2], 10) || 0,
      security: parts[parts.length - 1] || ""
    }
  }).filter(function(network) { return network.ssid !== "Hidden network" })
}

function parseKnown(raw) {
  return String(raw || "").split("\n").map(function(value) {
    return value.trim()
  }).filter(function(value) { return value !== "" })
}

function wifiIcon(signal) {
  if (signal >= 80) return "󰤨"
  if (signal >= 60) return "󰤥"
  if (signal >= 40) return "󰤢"
  if (signal >= 20) return "󰤟"
  return "󰤯"
}

function formatBytes(value) {
  var number = Number(value) || 0
  if (number < 1024) return Math.round(number) + " B"
  if (number < 1048576) return (number / 1024).toFixed(1) + " KB"
  if (number < 1073741824) return (number / 1048576).toFixed(1) + " MB"
  return (number / 1073741824).toFixed(2) + " GB"
}

function rate(previousBytes, currentBytes, previousTime, currentTime) {
  var elapsed = (Number(currentTime) - Number(previousTime)) / 1000
  if (!isFinite(elapsed) || elapsed <= 0) return 0
  return Math.max(0, (Number(currentBytes) - Number(previousBytes)) / elapsed)
}

function escapeWifi(value) {
  return String(value || "").replace(/([\\;,":])/g, "\\$1")
}

function wifiQr(ssid, password, security) {
  var type = security && security !== "--" && security !== "NONE" ? "WPA" : "nopass"
  return "WIFI:T:" + type + ";S:" + escapeWifi(ssid) + ";P:" + escapeWifi(password) + ";;"
}

if (typeof module !== "undefined") {
  module.exports = {
    parseDetails: parseDetails,
    parseNetworks: parseNetworks,
    parseKnown: parseKnown,
    wifiIcon: wifiIcon,
    formatBytes: formatBytes,
    rate: rate,
    wifiQr: wifiQr
  }
}
