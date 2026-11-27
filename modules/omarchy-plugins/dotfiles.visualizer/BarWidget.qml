import QtQuick
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

// Audio visualizer: 8 bars moving with the music, from cava (cava.conf next
// to this file). cava runs only while a player is playing, so it costs
// nothing the rest of the time; the widget hides then. Click: play/pause.
BarWidget {
  id: root
  moduleName: "dotfiles.visualizer"

  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var player: {
    for (var i = 0; i < players.length; i++) if (players[i] && players[i].isPlaying) return players[i]
    return null
  }
  readonly property bool playing: player !== null
  readonly property int barCount: 8
  property var levels: [0, 0, 0, 0, 0, 0, 0, 0]

  readonly property real barWidth: Style.spaceReal(3)
  readonly property real barGap: Style.spaceReal(2)
  readonly property real maxHeight: Math.round(barSize * 0.5)

  visible: playing
  implicitWidth: visible ? barCount * barWidth + (barCount - 1) * barGap + Style.spaceReal(14) : 0
  implicitHeight: barSize

  // Stays a bit after a pause so a quick pause doesn't restart cava
  Timer {
    id: linger
    interval: 3000
  }
  onPlayingChanged: if (!playing) linger.restart()

  Process {
    id: cava
    running: root.playing || linger.running
    command: ["cava", "-p", String(Qt.resolvedUrl("cava.conf")).replace(/^file:\/\//, "")]
    stdout: SplitParser {
      onRead: function(line) {
        var parts = line.split(";")
        var next = []
        for (var i = 0; i < root.barCount; i++) {
          var v = parseInt(parts[i], 10)
          next.push(isFinite(v) ? Math.max(0, Math.min(7, v)) : 0)
        }
        root.levels = next
      }
    }
    onRunningChanged: if (!running) root.levels = [0, 0, 0, 0, 0, 0, 0, 0]
  }

  Row {
    anchors.centerIn: parent
    spacing: root.barGap

    Repeater {
      model: root.barCount

      Rectangle {
        required property int index
        anchors.verticalCenter: parent.verticalCenter
        width: root.barWidth
        height: Math.max(root.barWidth, root.maxHeight * (root.levels[index] + 1) / 8)
        radius: width / 2
        color: root.bar ? root.bar.barForeground : Commons.Color.foreground
        Behavior on height { NumberAnimation { duration: Style.duration(60); easing.type: Easing.OutCubic } }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying()
  }
}
