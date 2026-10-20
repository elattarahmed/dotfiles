import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

// The SUPER + R resize mode (a Hyprland submap) in one bar slot.
//
// Off: a dim icon. On: highlighted "RESIZE". Click toggles the mode; scrolling
// over the widget makes the active window wider or narrower.
BarWidget {
  id: root
  moduleName: "verybad.resize-mode"

  readonly property string submapName: "resize"
  property bool resizing: false

  function dispatch(lua) {
    Quickshell.execDetached(["hyprctl", "dispatch", lua])
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Hyprland announces every submap change; an empty name means back to normal
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event && String(event.name) === "submap")
        root.resizing = String(event.data || "") === root.submapName
    }
  }

  // State at startup (the shell may start or reload while the mode is on)
  Process {
    running: true
    command: ["hyprctl", "submap"]
    stdout: StdioCollector {
      onStreamFinished: root.resizing = text.trim() === root.submapName
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.resizing ? "\u{f0a68} RESIZE" : "\u{f0a68}"
    active: root.resizing
    dimmed: !root.resizing
    horizontalMargin: 8.75
    tooltipText: root.resizing
      ? "Resize mode on: arrows resize (Shift = faster)\nEsc, Enter, Super+R or click to leave"
      : "Resize the active window: click or Super+R\nScroll here to make it wider / narrower"

    onPressed: function(b) {
      root.dispatch('hl.dsp.submap("' + (root.resizing ? "reset" : root.submapName) + '")')
    }
    onWheelMoved: function(delta) {
      root.dispatch("hl.dsp.window.resize({ x = " + (delta > 0 ? 40 : -40) + ", y = 0, relative = true })")
    }
  }
}
