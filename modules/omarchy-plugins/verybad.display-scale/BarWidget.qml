import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Screen scale in one bar slot.
//
// Scroll up or left click: everything bigger. Scroll down or right click:
// everything smaller. Goes through Omarchy's own command, which steps through
// clean scales (1, 1.25, 1.6, 2…) and saves the value in monitors.lua, so it
// survives a reboot.
BarWidget {
  id: root
  moduleName: "verybad.display-scale"

  property real scale: 0

  function change(direction) {
    if (changeProc.running) return
    changeProc.command = ["omarchy-hyprland-monitor-scaling", direction]
    changeProc.running = true
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: readProc
    command: ["sh", "-c", "hyprctl monitors -j | jq -r '.[] | select(.focused) | .scale'"]
    stdout: StdioCollector {
      onStreamFinished: {
        var value = Number(text.trim())
        if (value > 0) root.scale = value
      }
    }
  }

  Process {
    id: changeProc
    onExited: if (!readProc.running) readProc.running = true
  }

  // The scale can also change from Omarchy's menu or a shortcut
  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!readProc.running) readProc.running = true
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\u{f0379} " + (root.scale > 0 ? Math.round(root.scale * 100) + "%" : "…")
    horizontalMargin: 8.75
    tooltipText: "Display scale " + (root.scale > 0 ? root.scale.toFixed(2) : "?")
      + "\nScroll up / left click: bigger"
      + "\nScroll down / right click: smaller"

    onPressed: function(b) { root.change(b === Qt.RightButton ? "down" : "up") }
    onWheelMoved: function(delta) { root.change(delta > 0 ? "up" : "down") }
  }
}
