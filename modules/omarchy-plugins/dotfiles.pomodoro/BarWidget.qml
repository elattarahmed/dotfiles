import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Pomodoro timer in the bar.
//   click        start a work session / pause / resume
//   right click  stop
//   scroll       change the work length while stopped (5 to 90 min)
// A work session ends with a notification and starts the break on its own
// (a long one every 4th); the break ends with a notification and the timer
// stops, waiting for a click to start the next session.
BarWidget {
  id: root
  moduleName: "dotfiles.pomodoro"

  property int workMinutes: Number(setting("work", 25))
  readonly property int shortBreak: Number(setting("shortBreak", 5))
  readonly property int longBreak: Number(setting("longBreak", 15))
  readonly property int longEvery: Number(setting("longEvery", 4))

  property string phase: "idle"   // idle | work | break
  property bool paused: false
  property real endsAt: 0         // ms since epoch
  property int secondsLeft: 0           // seconds left, also while paused
  property int done: 0            // work sessions completed

  function fmt(s) {
    var m = Math.floor(s / 60), r = s % 60
    return m + ":" + (r < 10 ? "0" : "") + r
  }

  function notify(title, body) {
    Quickshell.execDetached(["notify-send", "-a", "Pomodoro", "-i", "alarm-symbolic", title, body])
  }

  function start(kind, minutes) {
    phase = kind
    paused = false
    secondsLeft = minutes * 60
    endsAt = Date.now() + secondsLeft * 1000
  }

  function stop() {
    phase = "idle"
    paused = false
    secondsLeft = 0
  }

  function primary() {
    if (phase === "idle") start("work", workMinutes)
    else if (paused) { paused = false; endsAt = Date.now() + secondsLeft * 1000 }
    else { paused = true }
  }

  function tick() {
    if (phase === "idle" || paused) return
    secondsLeft = Math.max(0, Math.round((endsAt - Date.now()) / 1000))
    if (secondsLeft > 0) return
    if (phase === "work") {
      done += 1
      var isLong = done % longEvery === 0
      notify("Pause !", isLong ? "Longue pause de " + longBreak + " min, tu l'as méritée." : "Pause de " + shortBreak + " min.")
      start("break", isLong ? longBreak : shortBreak)
    } else {
      notify("Au travail", "Fin de la pause : clique sur le minuteur pour lancer la prochaine session.")
      stop()
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Timer {
    interval: 1000
    repeat: true
    running: root.phase !== "idle" && !root.paused
    onTriggered: root.tick()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.phase === "idle" ? "\u{f051b}"
        : (root.phase === "work" ? "\u{f051f} " : "\u{f0176} ") + root.fmt(root.secondsLeft)
    dimmed: root.paused
    horizontalMargin: 8.5
    tooltipText: root.phase === "idle"
      ? "Pomodoro · " + root.workMinutes + " min\nclic : démarrer · molette : durée"
      : (root.phase === "work" ? "Travail" : "Pause") + (root.paused ? " (en pause)" : "")
        + " · " + root.done + " session" + (root.done > 1 ? "s" : "") + " terminée" + (root.done > 1 ? "s" : "")
        + "\nclic : " + (root.paused ? "reprendre" : "pause") + " · clic droit : arrêter"

    onPressed: function(b) {
      if (b === Qt.RightButton) root.stop()
      else root.primary()
    }
    onWheelMoved: function(delta) {
      if (root.phase !== "idle") return
      root.workMinutes = Math.max(5, Math.min(90, root.workMinutes + (delta > 0 ? 5 : -5)))
    }
  }
}
