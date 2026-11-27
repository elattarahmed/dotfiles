import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Privacy indicator, like macOS: an orange dot while an app records the
// microphone, a green one while an app uses the camera; nothing otherwise.
// The tooltip names the apps. App names come from PipeWire and /proc:
// shown as plain text, cut short.
BarWidget {
  id: root
  moduleName: "dotfiles.privacy"

  property var micApps: []
  property var camApps: []
  readonly property bool micOn: micApps.length > 0
  readonly property bool camOn: camApps.length > 0

  readonly property color micColor: "#ff9f0a"
  readonly property color camColor: "#30d158"

  function names(list) {
    return list.slice(0, 6).map(function(n) { return String(n).replace(/[\u0000-\u001f]/g, " ").slice(0, 40) }).join(", ")
  }

  function parse(out) {
    try {
      var d = JSON.parse(out.trim().split("\n").pop() || "{}")
      micApps = Array.isArray(d.mic) ? d.mic : []
      camApps = Array.isArray(d.cam) ? d.cam : []
    } catch (e) {
      micApps = []
      camApps = []
    }
  }

  visible: micOn || camOn
  implicitWidth: visible ? row.implicitWidth : 0
  implicitHeight: row.implicitHeight

  Process {
    id: scan
    command: [String(Qt.resolvedUrl("privacy-scan")).replace(/^file:\/\//, "")]
    stdout: StdioCollector {
      onStreamFinished: root.parse(text)
    }
  }

  Timer {
    interval: Math.max(1000, Number(root.setting("interval", 2000)))
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!scan.running) scan.running = true
  }

  Row {
    id: row
    anchors.verticalCenter: parent.verticalCenter

    WidgetButton {
      visible: root.camOn
      bar: root.bar
      text: "\u{f0567}"
      foreground: root.camColor
      useActiveColor: false
      horizontalMargin: 5
      tooltipText: "Caméra utilisée par : " + root.names(root.camApps)
    }

    WidgetButton {
      visible: root.micOn
      bar: root.bar
      text: "\u{f036c}"
      foreground: root.micColor
      useActiveColor: false
      horizontalMargin: 5
      tooltipText: "Micro utilisé par : " + root.names(root.micApps)
    }
  }
}
