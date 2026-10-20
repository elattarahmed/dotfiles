import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// RAM / CPU / temperature in one bar slot.
//
// Left click or scroll cycles the stat shown, right click opens btop. The
// tooltip always shows all three.
BarWidget {
  id: root
  moduleName: "verybad.sysstats"

  readonly property var modes: ["ram", "cpu", "temp"]
  property string mode: setting("mode", "ram")

  property real ramUsedGiB: 0
  property real ramPercent: 0
  property real cpuPercent: 0
  property real tempC: -1

  property real prevCpuTotal: 0
  property real prevCpuIdle: 0

  readonly property string ramText: "\u{f035b} " + ramUsedGiB.toFixed(1) + "G"
  readonly property string cpuText: "\u{f0ee0} " + Math.round(cpuPercent) + "%"
  readonly property string tempText: "\u{f050f} " + (tempC < 0 ? "?" : Math.round(tempC) + "°")

  readonly property string displayText: mode === "cpu" ? cpuText : (mode === "temp" ? tempText : ramText)

  function cycle(step) {
    var i = modes.indexOf(mode)
    mode = modes[(i + step + modes.length) % modes.length]
  }

  function parse(out) {
    // Line 1: MemTotal MemAvailable (KiB). Line 2: cpu total idle. Line 3: temp (milli°C).
    var lines = out.trim().split("\n")
    var mem = (lines[0] || "").split(" ")
    var total = Number(mem[0]), avail = Number(mem[1])
    if (total > 0) {
      ramUsedGiB = (total - avail) / 1048576
      ramPercent = (total - avail) / total * 100
    }

    var cpu = (lines[1] || "").split(" ")
    var cpuTotal = Number(cpu[0]), cpuIdle = Number(cpu[1])
    if (prevCpuTotal > 0 && cpuTotal > prevCpuTotal)
      cpuPercent = (1 - (cpuIdle - prevCpuIdle) / (cpuTotal - prevCpuTotal)) * 100
    prevCpuTotal = cpuTotal
    prevCpuIdle = cpuIdle

    var t = Number(lines[2])
    tempC = t > 0 ? t / 1000 : -1
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: statsProc
    command: ["sh", "-c",
      "awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{print t, a}' /proc/meminfo;" +
      "awk '/^cpu /{s=0; for(i=2;i<=NF;i++) s+=$i; print s, $5+$6; exit}' /proc/stat;" +
      "for z in /sys/class/thermal/thermal_zone*; do" +
      "  [ \"$(cat $z/type)\" = x86_pkg_temp ] && { cat $z/temp; exit; };" +
      "done;" +
      "cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -n1"]
    stdout: StdioCollector {
      onStreamFinished: root.parse(text)
    }
  }

  Timer {
    interval: Math.max(500, Number(root.setting("interval", 2000)))
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statsProc.running) statsProc.running = true
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.displayText
    horizontalMargin: 8.75
    tooltipText: "RAM " + root.ramUsedGiB.toFixed(1) + "G (" + Math.round(root.ramPercent) + "%)"
      + "\nCPU " + Math.round(root.cpuPercent) + "%"
      + "\nTemp " + (root.tempC < 0 ? "?" : Math.round(root.tempC) + "°C")

    onPressed: function(b) {
      if (b === Qt.RightButton) { if (root.bar) root.bar.run("omarchy-launch-or-focus-tui btop") }
      else root.cycle(1)
    }
    onWheelMoved: function(delta) { root.cycle(delta > 0 ? -1 : 1) }
  }
}
