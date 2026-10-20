import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Clipboard history in one bar slot.
//
// Left click opens the picker (same as Alt+Shift+V). The tooltip shows how
// many entries there are and the pinned ones with their Alt+letter shortcut.
BarWidget {
  id: root
  moduleName: "verybad.clipboard-button"

  property int entryCount: 0
  property var pinned: []

  function parse(raw) {
    var list = []
    try { list = JSON.parse(String(raw || "[]")) } catch (e) { list = [] }
    if (!Array.isArray(list)) list = []

    var pins = []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i]
      if (!entry || !entry.pinned) continue
      var label = entry.type === "image" ? "Image" : String(entry.text || "").replace(/\s+/g, " ").trim()
      if (label.length > 40) label = label.slice(0, 40) + "…"
      pins.push({ key: String(entry.pinKey || ""), label: label })
    }
    pins.sort(function(a, b) { return a.key < b.key ? -1 : a.key > b.key ? 1 : 0 })

    entryCount = list.length
    pinned = pins
  }

  readonly property string tooltip: {
    var lines = ["Clipboard: " + entryCount + " items"]
    if (pinned.length > 0) {
      lines.push("")
      for (var i = 0; i < pinned.length; i++)
        lines.push("󰐃 " + (pinned[i].key ? "Alt+" + pinned[i].key.toUpperCase() + "  " : "") + pinned[i].label)
    }
    lines.push("")
    lines.push("Click or Alt+Shift+V to open")
    return lines.join("\n")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/clipboard-history.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.parse(text())
    onLoadFailed: root.parse("[]")
    onFileChanged: reload()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\u{f014c}"
    horizontalMargin: 8.75
    tooltipText: root.tooltip

    onPressed: function(b) {
      if (root.bar) root.bar.run("omarchy-shell shell toggle verybad.clipboard")
    }
  }
}
