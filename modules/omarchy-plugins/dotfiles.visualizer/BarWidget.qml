import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Music in the bar: 8 bars moving with what plays (cava, cava.conf next to
// this file), and a card with the usual controls.
//   hover        the card opens (and stays while the mouse is on it)
//   click        the card stays open until a click elsewhere
//   scroll       previous / next track
// cava runs only while a player is playing, so it costs nothing otherwise;
// without cava installed a note shows instead of bars that would never move.
// Player text (titles, artists) is untrusted: PlainText everywhere.
BarWidget {
  id: root
  moduleName: "dotfiles.visualizer"

  readonly property var players: Mpris.players ? Mpris.players.values : []
  // The player shown: the one picked in the card, else the one playing,
  // else the first with a track
  property var picked: null
  readonly property var player: {
    if (picked && players.indexOf(picked) >= 0) return picked
    var withTrack = null
    for (var i = 0; i < players.length; i++) {
      var p = players[i]
      if (!p) continue
      if (p.isPlaying) return p
      if (!withTrack && (p.trackTitle || p.trackArtist)) withTrack = p
    }
    return withTrack
  }
  readonly property var sources: players.filter(function(p) { return p && (p.trackTitle || p.trackArtist || p.identity) })
  readonly property bool playing: !!player && player.isPlaying
  readonly property string title: player ? String(player.trackTitle || "") : ""
  readonly property string artist: player ? String(player.trackArtist || "") : ""
  readonly property string album: player ? String(player.trackAlbum || "") : ""

  readonly property int barCount: 8
  property var levels: [0, 0, 0, 0, 0, 0, 0, 0]
  property bool cavaAvailable: true

  readonly property real barWidth: Style.spaceReal(3)
  readonly property real barGap: Style.spaceReal(2)
  readonly property real maxHeight: Math.round(barSize * 0.5)

  // Card state: opened by hover, or pinned by a click
  property bool hoverOpen: false
  property bool pinned: false
  function close() { pinned = false; hoverOpen = false }

  visible: player !== null
  implicitWidth: visible ? barCount * barWidth + (barCount - 1) * barGap + Style.spaceReal(14) : 0
  implicitHeight: barSize

  function clean(s, max) { s = String(s || ""); return s.length > max ? s.slice(0, max) : s }

  Process {
    running: true
    command: ["sh", "-c", "command -v cava"]
    onExited: function(code) { root.cavaAvailable = code === 0 }
  }

  // Stays a bit after a pause so a quick pause doesn't restart cava
  Timer { id: linger; interval: 3000 }
  onPlayingChanged: if (!playing) linger.restart()

  Process {
    id: cava
    running: root.cavaAvailable && (root.playing || linger.running)
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

  // Bars, or a note without cava
  Row {
    anchors.centerIn: parent
    spacing: root.barGap
    visible: root.cavaAvailable

    Repeater {
      model: root.barCount

      Rectangle {
        required property int index
        anchors.verticalCenter: parent.verticalCenter
        width: root.barWidth
        height: Math.max(root.barWidth, root.maxHeight * (root.levels[index] + 1) / 8)
        radius: width / 2
        color: root.bar ? root.bar.barForeground : Commons.Color.foreground
        opacity: root.playing ? 1 : 0.5
        Behavior on height { NumberAnimation { duration: Style.duration(60); easing.type: Easing.OutCubic } }
      }
    }
  }

  Text {
    anchors.centerIn: parent
    visible: !root.cavaAvailable
    textFormat: Text.PlainText
    text: root.playing ? "\u{f075a}" : "\u{f03e4}"
    color: root.bar ? root.bar.barForeground : Commons.Color.foreground
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.body
  }

  Timer {
    id: openDelay
    interval: 300
    onTriggered: if (hover.containsMouse) root.hoverOpen = true
  }
  Timer {
    id: closeDelay
    interval: 450
    onTriggered: if (!hover.containsMouse && !popup.containsMouse && !root.pinned) root.hoverOpen = false
  }

  MouseArea {
    id: hover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: { closeDelay.stop(); openDelay.restart() }
    onExited: { openDelay.stop(); closeDelay.restart() }
    onClicked: { root.pinned = !root.pinned; root.hoverOpen = root.pinned }
    onWheel: function(wheel) {
      if (!root.player) return
      if (wheel.angleDelta.y > 0 && root.player.canGoPrevious) root.player.previous()
      else if (wheel.angleDelta.y < 0 && root.player.canGoNext) root.player.next()
    }
  }

  Connections {
    target: popup
    function onContainsMouseChanged() { if (!popup.containsMouse) closeDelay.restart(); else closeDelay.stop() }
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.pinned || root.hoverOpen
    triggerMode: root.pinned ? "click" : "hover"
    contentWidth: popup.fittedContentWidth(Style.space(320))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(10)

      Row {
        spacing: Style.space(10)
        width: parent.width

        BorderSurface {
          width: Style.space(64)
          height: Style.space(64)
          radius: Style.spacing.labelGap
          color: Style.normalFillFor(root.bar.foreground, Commons.Color.accent)
          borderSpec: Border.controlSpec("normal", root.bar.foreground, Commons.Color.accent)

          // Cover art only from a local file: the card never reaches the network
          SizedImage {
            anchors.fill: parent
            anchors.margins: Style.space(2)
            crop: true
            url: root.player && /^file:\/\//.test(String(root.player.trackArtUrl || "")) ? String(root.player.trackArtUrl) : ""
            visible: url != ""
          }

          Text {
            anchors.centerIn: parent
            visible: !root.player || !/^file:\/\//.test(String(root.player.trackArtUrl || ""))
            textFormat: Text.PlainText
            text: "\u{f075a}"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
          }
        }

        Column {
          spacing: Style.space(4)
          width: parent.width - Style.space(74)

          Text {
            textFormat: Text.PlainText
            text: root.clean(root.title, 200) || "Rien en lecture"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
          }

          Text {
            textFormat: Text.PlainText
            text: root.clean(root.artist, 200)
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }

          Text {
            textFormat: Text.PlainText
            text: root.clean(root.album, 200)
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
            visible: text !== ""
          }
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)
        LayoutMirroring.enabled: false
        LayoutMirroring.childrenInherit: true

        Button {
          iconText: "\u{f04ae}"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: !!root.player && root.player.canGoPrevious
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.player.previous()
        }

        Button {
          iconText: root.playing ? "\u{f03e4}" : "\u{f040a}"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.panelGap
          verticalPadding: Style.spacing.controlPaddingY
          iconSize: Style.font.iconLarge
          enabled: !!root.player && root.player.canTogglePlaying
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.player.togglePlaying()
        }

        Button {
          iconText: "\u{f04ad}"
          foreground: root.bar.foreground
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          enabled: !!root.player && root.player.canGoNext
          opacity: enabled ? 1.0 : 0.4
          onClicked: root.player.next()
        }
      }

      // Several players open: pick the one the card controls
      PanelSeparator {
        visible: root.sources.length > 1
        foreground: root.bar.foreground
      }

      Column {
        id: sourceList
        visible: root.sources.length > 1
        width: parent.width
        spacing: Style.space(4)

        Repeater {
          model: root.sources

          BorderSurface {
            id: sourceRow
            required property var modelData
            readonly property bool selected: modelData === root.player

            width: sourceList.width
            height: Style.space(32)
            radius: Style.spacing.labelGap
            color: selected ? Style.selectedFillFor(root.bar.foreground, Commons.Color.accent) : "transparent"
            borderSpec: selected ? Border.controlSpec("normal", root.bar.foreground, Commons.Color.accent) : Border.none()

            Text {
              anchors.fill: parent
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              verticalAlignment: Text.AlignVCenter
              textFormat: Text.PlainText
              text: (sourceRow.modelData.isPlaying ? "\u{f040a}  " : "\u{f03e4}  ")
                + root.clean(sourceRow.modelData.trackTitle || sourceRow.modelData.identity || "Lecteur", 120)
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: sourceRow.selected
              elide: Text.ElideRight
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.picked = sourceRow.modelData
            }
          }
        }
      }
    }
  }
}
