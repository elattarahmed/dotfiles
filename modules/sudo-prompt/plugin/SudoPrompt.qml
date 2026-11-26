// A small window, styled like Omarchy's polkit dialog, while sudo waits in a
// terminal: the fingerprint first, then the password. It never takes the
// keyboard or the mouse (clicks go through it): the password is typed in the
// terminal, where sudo reads it.
//
// sudo can't take the password while it waits for the fingerprint (PAM runs
// one module at a time, see pam_fprintd(8) LIMITATIONS), so the window counts
// down the fingerprint's timeout: when it runs out, sudo asks for the password.
//
// Driven by /usr/local/lib/dotfiles/sudo-prompt (pam_exec lines in
// /etc/pam.d/sudo) through `omarchy-shell sudo-prompt <function> ...`.
// The command shown comes from sudo's arguments: PlainText, cut to length.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  property string requestId: ""
  property string phase: ""       // fingerprint | password | ok | fail
  property string command: ""
  property int remaining: 0       // seconds before sudo asks for the password
  property bool shown: false
  property real shakeOffset: 0

  readonly property color accent: Commons.Color.polkit.accent
  readonly property color background: Commons.Color.polkit.background
  readonly property color foreground: Commons.Color.polkit.text
  readonly property color errorColor: Commons.Color.polkit.textError
  readonly property color okColor: Commons.Color.green !== undefined ? Commons.Color.green : "#6fd49b"
  readonly property string fontFamily: Style.font.menuFamily
  readonly property int glyphSize: Math.max(Style.space(42), Style.spacing.controlHeight)

  function clean(text, max) {
    var s = String(text || "").replace(/[\u0000-\u001f\u007f]/g, " ").trim()
    return s.length > max ? s.slice(0, max - 1) + "…" : s
  }

  function finish(result) {
    phase = result === "ok" ? "ok" : "fail"
    if (phase === "fail") shake.restart()
    closeTimer.interval = phase === "ok" ? 650 : 900
    closeTimer.restart()
  }


  Timer {
    id: countdown
    interval: 1000
    repeat: true
    running: root.shown && root.phase === "fingerprint" && root.remaining > 0
    onTriggered: root.remaining = Math.max(0, root.remaining - 1)
  }

  Timer {
    id: closeTimer
    onTriggered: { root.shown = false; root.requestId = "" }
  }

  // Never left on screen: sudo gives up on a fingerprint or password long
  // before this
  Timer {
    id: staleTimer
    interval: 5 * 60 * 1000
    onTriggered: { root.shown = false; root.requestId = "" }
  }

  SequentialAnimation {
    id: shake
    NumberAnimation { target: root; property: "shakeOffset"; to: -8; duration: Style.duration(35); easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "shakeOffset"; to: 8; duration: Style.duration(50); easing.type: Easing.InOutQuad }
    NumberAnimation { target: root; property: "shakeOffset"; to: 0; duration: Style.duration(55); easing.type: Easing.OutQuad }
  }

  ShellIpc {
    target: "sudo-prompt"

    // begin(id, phase, command, timeout): a sudo started asking, or moved on
    // from the fingerprint to the password. timeout: seconds pam_fprintd
    // waits for a finger (0: no countdown). A newer sudo takes the window.
    function begin(id: string, phase: string, command: string, timeout: string): string {
      if (phase !== "fingerprint" && phase !== "password") return "bad-phase"
      closeTimer.stop()
      root.requestId = root.clean(id, 32)
      root.phase = phase
      root.command = root.clean(command, 120)
      var t = parseInt(timeout, 10)
      root.remaining = phase === "fingerprint" && t > 0 && t < 600 ? t : 0
      root.shown = true
      staleTimer.restart()
      return "ok"
    }

    // end(id, result): sudo authenticated ("ok") or gave up ("fail")
    function end(id: string, result: string): string {
      if (!root.shown || root.clean(id, 32) !== root.requestId) return "ignored"
      // A quick command (sudo true) ends right after "ok": keep the success
      if (root.phase === "ok" || root.phase === "fail") return "ignored"
      root.finish(result)
      return "ok"
    }
  }

  PanelWindow {
    id: panel
    visible: root.shown
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "dotfiles-sudo-prompt"
    WlrLayershell.layer: WlrLayer.Overlay
    // The terminal keeps the keyboard: the password is typed there
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    // Takes no clicks at all: everything under it stays usable
    mask: Region {}

    Item {
      id: cardArea
      width: card.width
      height: label.height + Style.space(10) + card.height
      anchors.centerIn: parent
      anchors.horizontalCenterOffset: root.shakeOffset

      opacity: root.shown ? 1 : 0
      scale: root.shown ? 1 : 0.97
      Behavior on opacity { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: Style.duration(180); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut } }

      // What sudo will run, above the card like polkit's justification line
      Rectangle {
        id: label
        width: Math.min(labelText.implicitWidth + Style.space(24), panel.width - Style.gapsOut * 2)
        height: Style.space(28)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        radius: Style.cornerRadius
        color: root.background
        visible: root.command.length > 0

        Text {
          id: labelText
          textFormat: Text.PlainText
          anchors.fill: parent
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(12)
          text: root.command
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideMiddle
        }
      }

      BorderSurface {
        id: card
        width: Math.min(Style.space(400), panel.width - Style.gapsOut * 2)
        height: root.glyphSize + Style.space(64)
        anchors.top: label.bottom
        anchors.topMargin: Style.space(10)
        radius: Style.cornerRadius
        color: root.background
        borderSpec: Border.surfaceSpec("polkit", root.phase === "fail" ? "border-error" : "border",
                                       root.phase === "fail" ? Commons.Color.polkit.borderError : Commons.Color.polkit.border,
                                       Math.max(1, Style.space(2)), "border-alpha")

        Column {
          anchors.centerIn: parent
          width: parent.width - Style.space(32)
          spacing: Style.space(10)

          OpticalGlyph {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(root.glyphSize * 0.8)
            height: width
            fontFamily: root.fontFamily
            fontSize: Math.round(root.glyphSize * 0.8)
            text: root.phase === "ok" ? "󰄬" : (root.phase === "password" ? "" : (root.phase === "fail" ? "󰅖" : "󰈷"))
            color: root.phase === "ok" ? root.okColor : (root.phase === "fail" ? root.errorColor : root.accent)
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.phase === "ok" ? "Autorisé"
                : root.phase === "fail" ? "Refusé"
                : root.phase === "password" ? "Tape ton mot de passe dans le terminal"
                : "Touche le capteur d'empreinte"
            color: root.phase === "fail" ? root.errorColor : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            visible: root.phase === "fingerprint" || root.phase === "password"
            text: root.phase === "fingerprint"
              ? (root.remaining > 0 ? "sinon, mot de passe dans le terminal dans " + root.remaining + " s"
                                    : "le mot de passe va être demandé dans le terminal")
              : "sudo le lit dans le terminal"
            color: root.foreground
            opacity: 0.5
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

      }
    }
  }
}
