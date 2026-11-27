import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// A light frame around each group of widgets of the section it sits in, so
// the bar reads by role (applications · tools · music · network · system ·
// privacy). Groups end at the spacers the dotfiles put between them
// (bar-order.jq marks them "dotfilesSpacer"); a widget showing nothing (the
// visualizer while nothing plays…) takes no room in its frame, and a group
// with nothing to show has none.
// It takes no room itself: placed first in the section, it draws behind the
// widgets that follow it, from where the bar lays them out. The bar has no
// API for this; if its layout isn't found, nothing is drawn.
BarWidget {
  id: root
  moduleName: "dotfiles.bar-groups"

  implicitWidth: 0
  implicitHeight: 1

  property Item list: null
  property var frames: []
  readonly property color fg: bar ? bar.foreground : Commons.Color.foreground

  function findList() {
    for (var p = root.parent; p; p = p.parent)
      if (p.listRows !== undefined && p.flow !== undefined) return p
    return null
  }

  function recompute() {
    if (!list) list = findList()
    if (!list || list.flow !== GridLayout.LeftToRight) { frames = []; return }
    var slots = []
    for (var i = 0; i < list.children.length; i++) {
      var c = list.children[i]
      if (c && c.widgetKey !== undefined && c.visible) slots.push(c)
    }
    slots.sort(function(a, b) { return a.x - b.x })
    var groups = [], current = []
    for (var j = 0; j < slots.length; j++) {
      var s = slots[j], e = s.entry || {}
      if (s.moduleName === root.moduleName) continue
      if (e.dotfilesSpacer === true || e.id === "omarchy.spacer") {
        if (current.length) groups.push(current)
        current = []
        continue
      }
      if (s.width >= 1) current.push(s)
    }
    if (current.length) groups.push(current)
    var top = list.mapToItem(root, 0, 0).y
    frames = groups.map(function(g) {
      var first = g[0], last = g[g.length - 1]
      var a = list.mapToItem(root, first.x, 0).x
      var b = list.mapToItem(root, last.x + last.width, 0).x
      return { x: a, width: b - a, y: top, height: list.height }
    })
  }

  // Widgets grow and shrink (an IP, the visualizer appearing): follow the list
  Connections {
    target: root.list
    ignoreUnknownSignals: true
    function onImplicitWidthChanged() { refresh.restart() }
    function onWidthChanged() { refresh.restart() }
    function onHeightChanged() { refresh.restart() }
  }
  Timer { id: refresh; interval: 30; onTriggered: root.recompute() }
  // And now and then, for a change that moves nothing the list reports
  Timer { interval: 1500; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.recompute() }

  Repeater {
    model: root.frames
    Rectangle {
      required property var modelData
      readonly property real pad: Style.space(3)
      readonly property real inset: Math.max(Style.space(3), modelData.height * 0.14)
      x: modelData.x - pad
      width: modelData.width + pad * 2
      y: modelData.y + inset
      height: Math.max(0, modelData.height - inset * 2)
      radius: Math.min(height / 2, Style.cornerRadius * 2)
      color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)
      border.width: 1
      border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.16)
    }
  }
}
