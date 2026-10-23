function normalizeEntry(value) {
  if (typeof value === "string")
    return value.trim().length > 0 ? { type: "text", text: value } : null

  if (!value || typeof value !== "object") return null

  var type = String(value.type || value.kind || "")
  if (type === "text") {
    var text = String(value.text || "")
    if (text.trim().length === 0) return null
    var textEntry = { type: "text", text: text }
    copyPin(value, textEntry)
    return textEntry
  }

  if (type === "image") {
    var path = String(value.path || "")
    if (!path) return null
    var entry = {
      type: "image",
      path: path,
      mime: String(value.mime || "image/png")
    }
    if (value.capturedAt !== undefined && value.capturedAt !== null)
      entry.capturedAt = String(value.capturedAt)
    copyPin(value, entry)
    return entry
  }

  return null
}

// Letters a pinned entry can be bound to (Alt+letter in the picker). P pins,
// U clears the search, so they are skipped.
var pinKeys = "abcdefghijklmnoqrstvwxyz"

function copyPin(from, to) {
  if (!from || !from.pinned) return
  to.pinned = true
  var key = String(from.pinKey || "").toLowerCase()
  if (key.length === 1 && pinKeys.indexOf(key) >= 0) to.pinKey = key
}

function entryKey(entry) {
  if (!entry) return ""
  if (entry.type === "image") return "image:" + String(entry.path || "")
  return "text:" + String(entry.text || "")
}

function parseHistory(raw) {
  try {
    var parsed = JSON.parse(String(raw || "[]"))
    var next = []
    if (!Array.isArray(parsed)) return next

    for (var i = 0; i < parsed.length; i++) {
      var entry = normalizeEntry(parsed[i])
      if (entry) next.push(entry)
    }
    return next
  } catch (e) {
    return []
  }
}

function addEntry(history, entry, limit) {
  var normalized = normalizeEntry(entry)
  var max = limit === undefined || limit === null ? 100 : Number(limit)
  if (isNaN(max)) max = 100
  max = Math.max(0, max)
  if (!normalized) return Array.isArray(history) ? history.slice(0, max) : []
  if (max === 0) return []

  var key = entryKey(normalized)
  var values = Array.isArray(history) ? history : []

  // Copying a pinned entry again keeps it pinned
  for (var j = 0; j < values.length; j++) {
    var same = normalizeEntry(values[j])
    if (same && same.pinned && entryKey(same) === key) copyPin(same, normalized)
  }

  // Pinned entries never count against the limit and are never evicted
  var next = [normalized]
  var unpinned = normalized.pinned ? 0 : 1
  for (var i = 0; i < values.length; i++) {
    var existing = normalizeEntry(values[i])
    if (!existing || entryKey(existing) === key) continue
    if (!existing.pinned) {
      if (unpinned >= max) continue
      unpinned++
    }
    next.push(existing)
  }

  return next
}

function togglePinAt(history, index) {
  var values = Array.isArray(history) ? history : []
  var target = Number(index)
  if (isNaN(target) || target < 0 || target >= values.length) return values.slice()

  var next = values.slice()
  var entry = normalizeEntry(next[target])
  if (!entry) return next

  if (entry.pinned) {
    delete entry.pinned
    delete entry.pinKey
  } else {
    // First letter not already bound to another pinned entry
    var used = {}
    for (var i = 0; i < next.length; i++) {
      var other = normalizeEntry(next[i])
      if (other && other.pinKey) used[other.pinKey] = true
    }
    entry.pinned = true
    for (var k = 0; k < pinKeys.length; k++) {
      if (!used[pinKeys[k]]) { entry.pinKey = pinKeys[k]; break }
    }
  }
  next[target] = entry
  return next
}

function removeEntryAt(history, index) {
  var values = Array.isArray(history) ? history : []
  var target = Number(index)
  if (isNaN(target) || target < 0 || target >= values.length) return values.slice()

  var next = values.slice()
  next.splice(target, 1)
  return next
}

// Clearing keeps pinned entries, like Maccy
function clearHistory(history) {
  var values = Array.isArray(history) ? history : []
  var next = []
  for (var i = 0; i < values.length; i++) {
    var entry = normalizeEntry(values[i])
    if (entry && entry.pinned) next.push(entry)
  }
  return next
}

function parseEntryJson(line) {
  var raw = String(line || "").trim()
  if (!raw) return null
  try { return normalizeEntry(JSON.parse(raw)) } catch (e) { return null }
}

function searchableText(entry) {
  if (!entry) return ""
  if (entry.type === "image") return "image screenshot " + String(entry.mime || "") + " " + String(entry.capturedAt || "")
  return String(entry.text || "") + " " + fileEntryText(entry)
}

function decodeFileUri(uri) {
  var value = String(uri || "").trim()
  if (value.indexOf("file://") !== 0) return ""

  var path = value.substring(7)
  if (path.indexOf("localhost/") === 0) path = path.substring(9)
  if (path.charAt(0) !== "/") return ""

  try { return decodeURIComponent(path) } catch (e) { return path }
}

function filePaths(entry) {
  if (!entry || entry.type !== "text") return []

  var lines = String(entry.text || "").split(/\r?\n/)
  var paths = []
  for (var i = 0; i < lines.length; i++) {
    var path = decodeFileUri(lines[i])
    if (path) paths.push(path)
  }
  return paths
}

function fileName(path) {
  var parts = String(path || "").split("/")
  return parts.length > 0 ? parts[parts.length - 1] : String(path || "")
}

function isImagePath(path) {
  return /\.(png|jpe?g|webp|gif|bmp|tiff?)$/i.test(String(path || ""))
}

function fileEntryText(entry) {
  var paths = filePaths(entry)
  if (paths.length === 0) return ""
  if (paths.length === 1) return fileName(paths[0])
  return paths.length + " files"
}

function imagePreviewText(entry) {
  var timestamp = String(entry && entry.capturedAt || "")
  if (!timestamp) return "Image"

  var label = String(entry && entry.mime || "") === "image/png" ? "Screenshot" : "Image"
  return label + " from " + timestamp
}

function previewText(entry) {
  if (!entry) return ""
  if (entry.type === "image") return imagePreviewText(entry)
  var fileText = fileEntryText(entry)
  if (fileText) return fileText
  return String(entry.text || "").replace(/\s+/g, " ")
}

function fullText(entry) {
  if (!entry) return ""
  var paths = filePaths(entry)
  if (paths.length > 0) return paths.join("\n")
  return String(entry.text || "")
}

// The picker only ever searches and renders a prefix of an entry, so scan and
// render just that much. A single huge paste otherwise costs hundreds of
// megabytes of string work on every keystroke and stalls the whole shell.
// Pasting reads the full entry back from history by index, so nothing is lost.
var displayTextLimit = 8192

function cappedEntry(entry) {
  if (!entry || entry.type !== "text" || entry.text.length <= displayTextLimit) return entry

  // Cut on a line break so a file:// URI never truncates into a bogus path.
  var cut = entry.text.lastIndexOf("\n", displayTextLimit)
  var capped = { type: "text", text: entry.text.slice(0, cut > 0 ? cut : displayTextLimit) }
  copyPin(entry, capped)
  return capped
}

function displayRows(history, query, limit) {
  var values = Array.isArray(history) ? history : []
  var needle = String(query || "").trim().toLowerCase()
  var max = limit === undefined || limit === null ? 50 : Number(limit)
  if (isNaN(max)) max = 50
  max = Math.max(0, max)
  if (max === 0) return []

  var rows = []

  // Pinned entries first (by their letter), then the rest in history order.
  // Rows keep their real history index, which the paste scripts read back
  // from disk.
  var pinned = []
  var order = []
  for (var p = 0; p < values.length; p++) if (values[p] && values[p].pinned) pinned.push(p)
  pinned.sort(function(a, b) {
    var ka = String(values[a].pinKey || "~"), kb = String(values[b].pinKey || "~")
    return ka < kb ? -1 : ka > kb ? 1 : a - b
  })
  for (var u = 0; u < values.length; u++) if (!(values[u] && values[u].pinned)) order.push(u)
  order = pinned.concat(order)
  var number = 0

  for (var o = 0; o < order.length; o++) {
    var i = order[o]
    var entry = cappedEntry(normalizeEntry(values[i]))
    if (!entry) continue
    if (needle && searchableText(entry).toLowerCase().indexOf(needle) < 0) continue

    var paths = filePaths(entry)
    var isFile = paths.length > 0
    var isImage = entry.type === "image"
    var previewPath = isImage ? String(entry.path || "") : (isFile && paths.length === 1 && isImagePath(paths[0]) ? paths[0] : "")
    rows.push({
      entryType: isFile ? "file" : entry.type,
      fullText: isImage ? "" : fullText(entry),
      previewText: previewText(entry),
      previewImage: previewPath,
      path: isImage ? String(entry.path || "") : (isFile && paths.length === 1 ? paths[0] : ""),
      mime: isImage ? String(entry.mime || "image/png") : "text/plain",
      pinned: !!entry.pinned,
      pinKey: entry.pinned ? String(entry.pinKey || "") : "",
      number: entry.pinned || number >= 9 ? 0 : ++number,
      index: i
    })
    if (rows.length >= max) break
  }

  return rows
}

if (typeof module !== "undefined") {
  module.exports = {
    normalizeEntry: normalizeEntry,
    entryKey: entryKey,
    parseHistory: parseHistory,
    addEntry: addEntry,
    removeEntryAt: removeEntryAt,
    togglePinAt: togglePinAt,
    clearHistory: clearHistory,
    parseEntryJson: parseEntryJson,
    searchableText: searchableText,
    previewText: previewText,
    imagePreviewText: imagePreviewText,
    filePaths: filePaths,
    fileEntryText: fileEntryText,
    fullText: fullText,
    displayRows: displayRows
  }
}
