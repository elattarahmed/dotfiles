import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// Omarchy bar widget for whichport.
//
// Shows the port when one server is listening and the count when there are
// more. The tooltip lists them all. Left click opens whichport in a floating
// terminal, right click opens the first server in the browser.
BarWidget {
  id: root
  moduleName: "elattarahmed.whichport"

  property var servers: []

  readonly property string binary: String(setting("command", "whichport"))
  readonly property bool hideWhenEmpty: setting("hideWhenEmpty", true) === true

  readonly property string displayText: servers.length === 0
    ? "\u{f048d}"
    : "\u{f048d} " + (servers.length === 1 ? ":" + servers[0].port : servers.length)

  function describe(server) {
    var line = ":" + server.port + "  " + (server.name || "")
    if (server.branch) line += " (" + server.branch + ")"
    if (server.memoryBytes) line += " · " + Math.round(server.memoryBytes / 1048576) + " MB"
    return line
  }

  function parse(out) {
    try {
      var list = JSON.parse(out)
      servers = Array.isArray(list) ? list : []
    } catch (e) {
      servers = []
    }
  }

  visible: servers.length > 0 || !hideWhenEmpty
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: listProc
    // ~/.local/bin is where `make install PREFIX=~/.local` puts the binary, and it isn't
    // always on the shell's PATH.
    command: ["sh", "-c", 'PATH="$HOME/.local/bin:$PATH" exec "$0" list --json', root.binary]
    stdout: StdioCollector {
      onStreamFinished: root.parse(text)
    }
  }

  Timer {
    interval: Math.max(1000, Number(root.setting("interval", 3000)))
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!listProc.running) listProc.running = true
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.displayText
    horizontalMargin: 8.75
    tooltipText: root.servers.length === 0
      ? "No dev servers listening"
      : root.servers.map(root.describe).join("\n")

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) {
        if (root.servers.length > 0)
          root.bar.run("xdg-open http://localhost:" + Number(root.servers[0].port))
      } else {
        root.bar.run('PATH="$HOME/.local/bin:$PATH" omarchy-launch-or-focus-tui --app-id=org.omarchy.whichport ' + root.binary)
      }
    }
  }
}
