// Lock screen extras from the dotfiles (lockscreen-info): the time and date
// above the password field, the battery, and the music playing. Display only:
// it handles no input, so it can't get in the way of unlocking, and Omarchy's
// lock service (PAM, fingerprint) is left exactly as shipped.
//
// Player text (titles, artists) is untrusted: every Text is PlainText. Cover
// art is shown only from a local file, so the locked screen never reaches
// the network.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import qs.Commons
import qs.Commons as Commons

Item {
  id: root

  // Room the password field takes in the middle (LockView's 67 px field)
  property int fieldHalfHeight: 34
  readonly property color textColor: Commons.Color.lock.text
  readonly property color softColor: Commons.Color.lock.placeholder

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  // ---- Time and date, above the password field -------------------------
  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.verticalCenter
    anchors.bottomMargin: root.fieldHalfHeight + 48
    spacing: 4

    Text {
      textFormat: Text.PlainText
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatTime(clock.date, "HH:mm")
      color: root.textColor
      font.family: Style.font.family
      font.pixelSize: 120
      font.weight: Font.Light
    }

    Text {
      textFormat: Text.PlainText
      anchors.horizontalCenter: parent.horizontalCenter
      text: {
        var s = clock.date.toLocaleDateString(Qt.locale(Commons.I18n.formatLocale), "dddd d MMMM")
        return s.charAt(0).toUpperCase() + s.slice(1)
      }
      color: root.softColor
      font.family: Style.font.family
      font.pixelSize: 26
    }
  }

  // ---- Battery, top right ----------------------------------------------
  Row {
    readonly property var device: UPower.displayDevice
    readonly property int level: device && device.isPresent ? Math.round(Number(device.percentage || 0) * 100) : -1
    readonly property bool charging: !!device && (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.FullyCharged || !UPower.onBattery)
    readonly property bool low: level >= 0 && level <= 15 && !charging

    visible: level >= 0
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.margins: 36
    spacing: 10

    Text {
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      text: {
        if (parent.charging) return "󰂄"
        var icons = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
        return icons[Math.max(0, Math.min(9, Math.floor((parent.level - 1) / 10)))]
      }
      color: parent.low ? Commons.Color.lock.textError : root.textColor
      font.family: Style.font.family
      font.pixelSize: 26
    }

    Text {
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      text: Commons.I18n.formatNumber(parent.level, 0) + " %"
      color: parent.low ? Commons.Color.lock.textError : root.textColor
      font.family: Style.font.family
      font.pixelSize: 22
    }
  }

  // ---- Music playing, at the bottom ------------------------------------
  Item {
    id: media

    readonly property var players: Mpris.players ? Mpris.players.values : []
    // The player that is playing, otherwise the first one with a track
    readonly property var player: {
      var withTrack = null
      for (var i = 0; i < players.length; i++) {
        var p = players[i]
        if (!p || !(p.trackTitle || p.trackArtist)) continue
        if (p.isPlaying) return p
        if (!withTrack) withTrack = p
      }
      return withTrack
    }
    readonly property string title: player ? String(player.trackTitle || "") : ""
    readonly property string artist: player ? String(player.trackArtist || "") : ""
    readonly property string art: player && /^file:\/\//.test(String(player.trackArtUrl || "")) ? String(player.trackArtUrl) : ""

    visible: player !== null
    width: Math.min(parent.width - 72, 520)
    height: 88
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 56

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: Commons.Color.lock.background
    }

    Row {
      anchors.fill: parent
      anchors.margins: 12
      spacing: 14

      Rectangle {
        width: 64
        height: 64
        anchors.verticalCenter: parent.verticalCenter
        radius: Math.max(4, Style.cornerRadius - 4)
        color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.08)
        clip: true

        Image {
          anchors.fill: parent
          source: media.art
          visible: status === Image.Ready
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          sourceSize: Qt.size(128, 128)
        }

        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          visible: media.art === ""
          text: "󰎆"
          color: root.softColor
          font.family: Style.font.family
          font.pixelSize: 30
        }
      }

      Column {
        width: parent.width - 64 - 40 - parent.spacing * 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: media.title.length > 200 ? media.title.slice(0, 200) : media.title
          color: root.textColor
          font.family: Style.font.family
          font.pixelSize: 19
          font.weight: Font.DemiBold
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          visible: text.length > 0
          text: media.artist.length > 200 ? media.artist.slice(0, 200) : media.artist
          color: root.softColor
          font.family: Style.font.family
          font.pixelSize: 16
          elide: Text.ElideRight
        }
      }

      Text {
        textFormat: Text.PlainText
        width: 40
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignHCenter
        text: media.player && media.player.isPlaying ? "󰏤" : "󰐊"
        color: root.softColor
        font.family: Style.font.family
        font.pixelSize: 26
      }
    }
  }
}
