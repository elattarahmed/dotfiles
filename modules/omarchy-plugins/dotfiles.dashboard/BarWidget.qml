import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The middle of the bar: the clock (and the pomodoro countdown while it
// runs), and a dashboard that drops from it.
//   hover   the dashboard opens (stays while the mouse is on it)
//   click   it stays open until a click elsewhere
// Two tabs: Aperçu (clock, calendar, weather, world clocks, pomodoro) and
// Performances (CPU, memory, temperature, battery, disk, network, each with
// its history). Weather and performance data are fetched only while the
// dashboard is open (weather also at most every 20 min), so it costs nothing
// the rest of the time. Weather text comes from wttr.in: PlainText, cut.
BarWidget {
  id: root
  moduleName: "dotfiles.dashboard"

  readonly property color fg: bar ? bar.foreground : Commons.Color.foreground
  readonly property color accent: Commons.Color.accent
  readonly property color soft: Qt.rgba(fg.r, fg.g, fg.b, 0.6)
  readonly property color tile: Qt.rgba(fg.r, fg.g, fg.b, 0.06)
  readonly property string font: bar ? bar.fontFamily : Style.font.family
  readonly property var loc: Qt.locale(Commons.I18n.formatLocale)

  // ---- Clock ------------------------------------------------------------
  SystemClock { id: clock; precision: SystemClock.Seconds }
  readonly property string barFormat: String(setting("format", "ddd d MMM  HH:mm"))
  readonly property var cities: {
    var c = setting("cities", null)
    return Array.isArray(c) ? c : [
      { name: "Paris", zone: "Europe/Paris" }, { name: "Dubai", zone: "Asia/Dubai" },
      { name: "Tokyo", zone: "Asia/Tokyo" }, { name: "Los Angeles", zone: "America/Los_Angeles" },
      { name: "New York", zone: "America/New_York" }]
  }
  property var cityTimes: ({})

  // ---- Pomodoro -----------------------------------------------------------
  property int workMinutes: Number(setting("work", 25))
  readonly property int shortBreak: Number(setting("shortBreak", 5))
  readonly property int longBreak: Number(setting("longBreak", 15))
  readonly property int longEvery: Number(setting("longEvery", 4))
  property string phase: "idle"   // idle | work | break
  property bool paused: false
  property real endsAt: 0
  property int secondsLeft: 0
  property int totalSeconds: 1
  property int sessions: 0

  function fmt(s) { var m = Math.floor(s / 60), r = s % 60; return m + ":" + (r < 10 ? "0" : "") + r }
  function notify(title, body) {
    Quickshell.execDetached(["notify-send", "-a", "Pomodoro", "-i", "alarm-symbolic", title, body])
  }
  function startPhase(kind, minutes) {
    phase = kind; paused = false
    totalSeconds = minutes * 60; secondsLeft = totalSeconds
    endsAt = Date.now() + secondsLeft * 1000
  }
  function stopPomodoro() { phase = "idle"; paused = false; secondsLeft = 0 }
  function togglePomodoro() {
    if (phase === "idle") startPhase("work", workMinutes)
    else if (paused) { paused = false; endsAt = Date.now() + secondsLeft * 1000 }
    else paused = true
  }
  function skipPhase() {
    if (phase === "work") { secondsLeft = 0; endsAt = Date.now(); tick() }
    else if (phase === "break") { stopPomodoro() }
  }
  function tick() {
    if (phase === "idle" || paused) return
    secondsLeft = Math.max(0, Math.round((endsAt - Date.now()) / 1000))
    if (secondsLeft > 0) return
    if (phase === "work") {
      sessions += 1
      var isLong = sessions % longEvery === 0
      notify("Pause !", isLong ? "Longue pause de " + longBreak + " min, tu l'as méritée." : "Pause de " + shortBreak + " min.")
      startPhase("break", isLong ? longBreak : shortBreak)
    } else {
      notify("Au travail", "Fin de la pause : lance la prochaine session depuis le tableau de bord.")
      stopPomodoro()
    }
  }
  Timer { interval: 1000; repeat: true; running: root.phase !== "idle" && !root.paused; onTriggered: root.tick() }

  // ---- Dashboard open state ------------------------------------------------
  property bool hoverOpen: false
  property bool pinned: false
  property string tab: "overview"
  readonly property bool dashOpen: pinned || hoverOpen
  function close() { pinned = false; hoverOpen = false }

  // ---- Weather --------------------------------------------------------------
  property var weather: null
  property real weatherAt: 0
  function weatherIcon(code) {
    code = Number(code)
    if (code === 113) return "\u{f0599}"
    if (code === 116) return "\u{f0595}"
    if (code === 119 || code === 122) return "\u{f0590}"
    if ([143, 248, 260].indexOf(code) >= 0) return "\u{f0591}"
    if ([200, 386, 389, 392, 395].indexOf(code) >= 0) return "\u{f0593}"
    if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371].indexOf(code) >= 0) return "\u{f0598}"
    if ([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].indexOf(code) >= 0) return "\u{f067f}"
    if ([302, 305, 308, 356, 359].indexOf(code) >= 0) return "\u{f0596}"
    return "\u{f0597}"
  }
  function plain(s, n) { s = String(s === undefined || s === null ? "" : s); return s.length > n ? s.slice(0, n) : s }
  Process {
    id: weatherProc
    command: [String(Qt.resolvedUrl("weather-fetch")).replace(/^file:\/\//, "")]
    stdout: StdioCollector {
      onStreamFinished: {
        try { var w = JSON.parse(text.trim()); if (w && w.days) { root.weather = w; root.weatherAt = Date.now() } } catch (e) {}
      }
    }
  }
  function refreshWeather() {
    if (!weatherProc.running && Date.now() - weatherAt > 20 * 60 * 1000) weatherProc.running = true
  }
  onDashOpenChanged: if (dashOpen) { refreshWeather(); updateCities(); perfProc.running = true }

  // Qt's JavaScript ignores toLocaleTimeString's timeZone, so date(1) gives
  // each city's time. Zone names are checked before they reach the shell.
  readonly property var zones: cities.map(function(c) { return String(c.zone || "") }).filter(function(z) { return /^[A-Za-z_]+(\/[A-Za-z0-9_+-]+)*$/.test(z) })
  function updateCities() { if (!citiesProc.running && zones.length) citiesProc.running = true }
  Process {
    id: citiesProc
    command: ["sh", "-c", 'for z in "$@"; do printf "%s %s\\n" "$z" "$(TZ="$z" date +%H:%M)"; done', "sh"].concat(root.zones)
    stdout: StdioCollector {
      onStreamFinished: {
        var out = {}
        text.trim().split("\n").forEach(function(line) {
          var parts = line.split(" ")
          if (parts.length === 2 && /^\d\d:\d\d$/.test(parts[1])) out[parts[0]] = parts[1]
        })
        root.cityTimes = out
      }
    }
  }

  // ---- Performances ---------------------------------------------------------
  readonly property int historySize: 60
  property var hist: ({ cpu: [], mem: [], temp: [], watts: [], down: [], up: [] })
  property var perf: ({ cpu: 0, memUsed: 0, memTotal: 0, temp: -1, battery: -1, batteryStatus: "", watts: -1, disk: 0, iface: "", down: 0, up: 0 })
  property var prevSample: null
  function push(list, v) { var l = list.slice(); l.push(v); while (l.length > historySize) l.shift(); return l }
  function rate(bytes) {
    if (bytes < 1024) return Math.round(bytes) + " o/s"
    if (bytes < 1048576) return (bytes / 1024).toFixed(0) + " Ko/s"
    return (bytes / 1048576).toFixed(1) + " Mo/s"
  }
  function takeSample(s) {
    var p = prevSample
    var cpu = p && s.cpuTotal > p.cpuTotal ? (1 - (s.cpuIdle - p.cpuIdle) / (s.cpuTotal - p.cpuTotal)) * 100 : perf.cpu
    var dt = p ? Math.max(0.5, s.t - p.t) : 1
    var down = p && s.rx >= p.rx ? (s.rx - p.rx) / dt : 0
    var up = p && s.tx >= p.tx ? (s.tx - p.tx) / dt : 0
    prevSample = s
    perf = { cpu: cpu, memUsed: (s.memTotal - s.memAvail) / 1048576, memTotal: s.memTotal / 1048576,
             temp: s.temp, battery: s.battery, batteryStatus: String(s.batteryStatus || ""), watts: s.watts,
             disk: s.disk, iface: plain(s.iface, 20), down: down, up: up }
    hist = { cpu: push(hist.cpu, cpu), mem: push(hist.mem, s.memTotal > 0 ? (s.memTotal - s.memAvail) / s.memTotal * 100 : 0),
             temp: push(hist.temp, s.temp), watts: push(hist.watts, s.watts), down: push(hist.down, down), up: push(hist.up, up) }
  }
  Process {
    id: perfProc
    command: [String(Qt.resolvedUrl("perf-sample")).replace(/^file:\/\//, "")]
    stdout: StdioCollector {
      onStreamFinished: { try { root.takeSample(JSON.parse(text.trim())) } catch (e) {} }
    }
  }
  Timer {
    interval: 2000; repeat: true; running: root.dashOpen
    onTriggered: { if (!perfProc.running) perfProc.running = true; root.updateCities() }
  }

  // ---- Quick toggles (Omarchy's bar indicators, through the same services and
  // commands they use) -------------------------------------------------------
  readonly property var notifService: bar?.shell?.firstPartyServiceFor("omarchy.notifications")
  readonly property var nightService: bar?.shell?.firstPartyServiceFor("omarchy.nightlight")
  readonly property var idleService: bar?.shell?.firstPartyServiceFor("omarchy.idle")
  readonly property var remoteService: bar?.shell?.firstPartyServiceFor("omarchy.remote-session")
  readonly property bool dnd: notifService ? notifService.doNotDisturb === true : false
  readonly property bool nightlight: nightService ? nightService.enabled === true : false
  readonly property bool stayAwake: idleService ? idleService.stayAwake === true : false
  readonly property bool remote: remoteService ? remoteService.active === true : false
  property bool sudoOpen: false
  property bool recording: false
  property int reminders: 0

  function run(cmd) { if (bar) bar.run(cmd) }
  Process { id: sudoProc; command: ["omarchy-sudo-passwordless", "--active"]; onExited: function(code, status) { root.sudoOpen = code === 0 && status === 0 } }
  Process { id: sudoOff; command: ["omarchy-sudo-passwordless", "--disable"]; onExited: sudoProc.running = true }
  Process { id: recProc; command: ["omarchy-capture-screenrecording", "--status"]; onExited: function(code) { root.recording = code === 0 } }
  Process {
    id: remindProc
    command: ["omarchy-reminder", "show", "--json"]
    stdout: StdioCollector { onStreamFinished: { try { root.reminders = Number(JSON.parse(text).count || 0) } catch (e) { root.reminders = 0 } } }
  }
  function refreshToggles() {
    if (!sudoProc.running) sudoProc.running = true
    if (!recProc.running) recProc.running = true
    if (!remindProc.running) remindProc.running = true
  }
  // Light polling so the bar shows a recording or open sudo even when closed
  Timer { interval: root.dashOpen ? 2000 : 10000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refreshToggles() }
  readonly property string activeMarks:
      (recording ? " \u{f0ec2}" : "") + (sudoOpen ? " \u{f07f5}" : "") + (stayAwake ? " \u{f0176}" : "")
    + (dnd ? " \u{f009b}" : "") + (nightlight ? " \u{f050e}" : "") + (remote ? " \u{f08b9}" : "")

  // ---- Bar label ------------------------------------------------------------
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  // The bar's open-panel mark spans the whole label instead of 55 % of it
  readonly property real openPanelIndicatorWidth: button.labelWidth

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: clock.date.toLocaleString(root.loc, root.barFormat) + root.activeMarks
      + (root.phase === "idle" ? "" : (root.phase === "work" ? "   \u{f051f} " : "   \u{f0176} ") + root.fmt(root.secondsLeft) + (root.paused ? " \u{f03e4}" : ""))
    onPressed: function(b) {
      if (b === Qt.RightButton) { root.togglePomodoro(); return }
      root.pinned = !root.pinned
      root.hoverOpen = root.pinned
    }
  }

  Timer { id: openDelay; interval: 350; onTriggered: if (button.tooltipHovered) root.hoverOpen = true }
  Timer { id: closeDelay; interval: 450; onTriggered: if (!button.tooltipHovered && !popup.containsMouse && !root.pinned) root.hoverOpen = false }
  Connections {
    target: button
    function onTooltipHoveredChanged() { if (button.tooltipHovered) { closeDelay.stop(); openDelay.restart() } else { openDelay.stop(); closeDelay.restart() } }
  }
  Connections {
    target: popup
    function onContainsMouseChanged() { if (popup.containsMouse) closeDelay.stop(); else closeDelay.restart() }
  }

  // ---- Reusable pieces ----------------------------------------------------------
  // (Inline components don't see `root`: they use Omarchy's tokens directly)
  component Label: Text {
    textFormat: Text.PlainText
    color: Commons.Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    elide: Text.ElideRight
  }

  component Tile: Rectangle {
    radius: Style.cornerRadius
    color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.06)
  }

  component Spark: Canvas {
    id: spark
    property var values: []
    property real maxValue: 0     // 0: scale to the largest value
    property int capacity: 60
    property color lineColor: Commons.Color.accent
    height: Style.space(34)
    onValuesChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var v = values.filter(function(x) { return x >= 0 })
      if (values.length < 2) return
      var top = maxValue > 0 ? maxValue : Math.max.apply(null, v.concat([1]))
      var step = width / (capacity - 1)
      var x0 = width - (values.length - 1) * step
      ctx.beginPath()
      for (var i = 0; i < values.length; i++) {
        var y = height - 2 - Math.max(0, values[i]) / top * (height - 4)
        if (i === 0) ctx.moveTo(x0, y); else ctx.lineTo(x0 + i * step, y)
      }
      ctx.lineWidth = 1.5
      ctx.strokeStyle = lineColor
      ctx.stroke()
      ctx.lineTo(x0 + (values.length - 1) * step, height)
      ctx.lineTo(x0, height)
      ctx.closePath()
      ctx.fillStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.15)
      ctx.fill()
    }
  }

  component Metric: Tile {
    id: metric
    property string icon: ""
    property string name: ""
    property string value: ""
    property string detail: ""
    property var values: []
    property real maxValue: 0
    height: Style.space(96)
    Column {
      anchors.fill: parent
      anchors.margins: Style.space(10)
      spacing: Style.space(4)
      Row {
        width: parent.width
        spacing: Style.space(6)
        Label { text: metric.icon; color: Commons.Color.accent }
        Label { text: metric.name; opacity: 0.6; font.pixelSize: Style.font.bodySmall; width: parent.width * 0.45 }
        Label { text: metric.value; font.bold: true; horizontalAlignment: Text.AlignRight; width: parent.width * 0.4 }
      }
      Spark { width: parent.width; values: metric.values; maxValue: metric.maxValue }
      Label { text: metric.detail; opacity: 0.6; font.pixelSize: Style.font.caption; width: parent.width; visible: text !== "" }
    }
  }

  // ---- The dashboard ---------------------------------------------------------------
  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    centerOnBar: true
    open: root.dashOpen
    triggerMode: root.pinned ? "click" : "hover"
    contentWidth: popup.fittedContentWidth(Style.space(720))
    contentHeight: popup.fittedContentHeight(content.implicitHeight)

    Column {
      id: content
      width: parent.width
      spacing: Style.space(12)

      // Title (its name, to talk about it) and tabs
      Item {
        width: parent.width
        height: tabs.implicitHeight
        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: "Tableau de bord"
          color: root.soft
          font.family: root.font
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }
      Row {
        id: tabs
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)
        Button {
          text: "\u{f0570}  Aperçu"; foreground: root.fg; selected: root.tab === "overview"
          onClicked: root.tab = "overview"
        }
        Button {
          text: "\u{f04c5}  Performances"; foreground: root.fg; selected: root.tab === "perf"
          onClicked: { root.tab = "perf"; if (!perfProc.running) perfProc.running = true }
        }
      }
      }

      // Quick toggles, on both tabs
      Flow {
        width: parent.width
        spacing: Style.space(6)
        Button {
          iconText: "\u{f009b}"; text: "Ne pas déranger"; foreground: root.fg; selected: root.dnd
          onClicked: if (root.notifService) root.notifService.setDoNotDisturb(!root.dnd)
        }
        Button {
          iconText: "\u{f050e}"; text: "Veilleuse"; foreground: root.fg; selected: root.nightlight
          onClicked: if (root.nightService) root.nightService.setNightlight(!root.nightlight)
        }
        Button {
          iconText: "\u{f0176}"; text: "Rester éveillé"; foreground: root.fg; selected: root.stayAwake
          onClicked: if (root.idleService) root.idleService.setIdleEnabled(root.stayAwake)
        }
        Button {
          iconText: "\u{f07f5}"; text: "Sudo sans mot de passe"; foreground: root.sudoOpen ? Commons.Color.urgent : root.fg; selected: root.sudoOpen
          tooltipText: root.sudoOpen ? "Actif : clic pour le couper" : "Ouvre un terminal pour l'activer"
          onClicked: { if (root.sudoOpen) { if (!sudoOff.running) sudoOff.running = true } else root.run("omarchy-launch-floating-terminal-with-presentation omarchy-sudo-passwordless") }
        }
        Button {
          iconText: "\u{f0ec2}"; text: root.recording ? "Arrêter l'enregistrement" : "Enregistrer l'écran"; foreground: root.recording ? Commons.Color.urgent : root.fg; selected: root.recording
          onClicked: { root.run(root.recording ? "omarchy-capture-screenrecording --stop-recording" : "omarchy-menu toggle trigger.capture.screenrecord"); root.close() }
        }
        Button {
          iconText: "\u{f088c}"; text: root.reminders > 0 ? "Rappels (" + root.reminders + ")" : "Rappel"; foreground: root.fg; selected: root.reminders > 0
          onClicked: { Quickshell.execDetached(root.reminders > 0 ? ["omarchy-reminder", "show"] : ["omarchy-reminder", "-i"]); root.close() }
        }
        Button {
          visible: root.remote
          iconText: "\u{f08b9}"; text: "Session à distance"; foreground: Commons.Color.urgent; selected: true
        }
      }

      // ===== Aperçu =====
      Row {
        visible: root.tab === "overview"
        width: parent.width
        spacing: Style.space(12)
        readonly property real col: (width - spacing * 2) / 3

        // --- Clock and calendar
        Tile {
          width: parent.col
          height: overviewHeight.height
          Column {
            id: clockCol
            anchors.fill: parent
            anchors.margins: Style.space(12)
            spacing: Style.space(4)
            Label {
              text: clock.date.toLocaleString(root.loc, "HH:mm")
              font.pixelSize: Style.font.displayLarge * 1.6
              font.weight: Font.Light
            }
            Label {
              width: parent.width
              text: { var s = clock.date.toLocaleString(root.loc, "dddd d MMMM yyyy"); return s.charAt(0).toUpperCase() + s.slice(1) }
              color: root.soft
            }
            Item { width: 1; height: Style.space(6) }
            // Month grid, Monday first, with the previous / next month
            Column {
              id: cal
              width: parent.width
              property int offset: 0
              readonly property var month: { var d = new Date(clock.date.getFullYear(), clock.date.getMonth() + offset, 1); return d }
              spacing: Style.space(4)
              Row {
                width: cal.width
                Button { iconText: "\u{f0141}"; foreground: root.fg; onClicked: cal.offset -= 1 }
                Label {
                  width: cal.width - Style.space(64)
                  horizontalAlignment: Text.AlignHCenter
                  anchors.verticalCenter: parent.verticalCenter
                  text: { var s = cal.month.toLocaleDateString(root.loc, "MMMM yyyy"); return s.charAt(0).toUpperCase() + s.slice(1) }
                  font.bold: true
                  MouseArea { anchors.fill: parent; onClicked: cal.offset = 0 }
                }
                Button { iconText: "\u{f0142}"; foreground: root.fg; onClicked: cal.offset += 1 }
              }
              Grid {
                columns: 7
                width: cal.width
                readonly property real cell: cal.width / 7
                Repeater {
                  model: ["L", "M", "M", "J", "V", "S", "D"]
                  Label { required property string modelData; width: parent.cell; text: modelData; horizontalAlignment: Text.AlignHCenter; color: root.soft; font.pixelSize: Style.font.caption }
                }
                Repeater {
                  model: 42
                  Item {
                    required property int index
                    readonly property int lead: (cal.month.getDay() + 6) % 7
                    readonly property var day: new Date(cal.month.getFullYear(), cal.month.getMonth(), index - lead + 1)
                    readonly property bool inMonth: day.getMonth() === cal.month.getMonth()
                    readonly property bool today: day.toDateString() === clock.date.toDateString()
                    width: parent.cell
                    height: Style.space(22)
                    Rectangle {
                      anchors.centerIn: parent
                      width: Math.min(parent.width, parent.height); height: width; radius: width / 2
                      color: today ? root.accent : "transparent"
                    }
                    Label {
                      anchors.centerIn: parent
                      text: day.getDate()
                      font.pixelSize: Style.font.caption
                      color: today ? Commons.Color.background : root.fg
                      opacity: inMonth ? 1 : 0.3
                    }
                  }
                }
              }
            }
          }
        }

        // --- Weather and world clocks
        Tile {
          width: parent.col
          height: overviewHeight.height
          Column {
            anchors.fill: parent
            anchors.margins: Style.space(12)
            spacing: Style.space(6)
            Row {
              spacing: Style.space(10)
              Label {
                text: root.weather ? root.weatherIcon(root.weather.code) : "\u{f0590}"
                font.pixelSize: Style.font.displayLarge * 1.4
                color: root.accent
              }
              Column {
                anchors.verticalCenter: parent.verticalCenter
                Label {
                  text: root.weather && root.weather.temp !== null ? root.weather.temp + "°" : "--°"
                  font.pixelSize: Style.font.displayLarge
                }
                Label {
                  text: root.weather ? root.plain(root.weather.desc, 40) : "Météo…"
                  color: root.soft
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }
            Label {
              width: parent.width
              visible: !!root.weather
              text: root.weather ? root.plain(root.weather.place, 40) + " · ressenti " + root.weather.feels + "° · " + root.weather.humidity + " % · " + root.weather.wind + " km/h" : ""
              color: root.soft
              font.pixelSize: Style.font.caption
            }
            Repeater {
              model: root.weather ? root.weather.days : []
              Row {
                required property var modelData
                width: parent.width
                Label {
                  width: parent.width * 0.42
                  text: { var d = new Date(String(modelData.date) + "T12:00:00"); var s = isNaN(d) ? "" : d.toLocaleDateString(root.loc, "ddd d"); return s.charAt(0).toUpperCase() + s.slice(1) }
                  font.pixelSize: Style.font.bodySmall
                }
                Label { width: parent.width * 0.18; text: root.weatherIcon(modelData.code); color: root.accent }
                Label { width: parent.width * 0.4; text: modelData.min + "° / " + modelData.max + "°"; horizontalAlignment: Text.AlignRight; font.pixelSize: Style.font.bodySmall }
              }
            }
            Rectangle { width: parent.width; height: 1; color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12) }
            Repeater {
              model: root.cities
              Row {
                required property var modelData
                width: parent.width
                Label { width: parent.width * 0.65; text: root.plain(modelData.name, 24); color: root.soft; font.pixelSize: Style.font.bodySmall }
                Label { width: parent.width * 0.35; text: root.cityTimes[modelData.zone] || "--:--"; horizontalAlignment: Text.AlignRight; font.pixelSize: Style.font.bodySmall }
              }
            }
          }
        }

        // --- Pomodoro
        Tile {
          id: overviewHeight
          width: parent.col
          height: Math.max(Style.space(330), clockCol.implicitHeight + Style.space(24))
          Column {
            anchors.fill: parent
            anchors.margins: Style.space(12)
            spacing: Style.space(10)
            Label {
              text: "\u{f051b}  Pomodoro"
              color: root.soft
              font.pixelSize: Style.font.bodySmall
            }
            Label {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.phase === "idle" ? root.workMinutes + ":00" : root.fmt(root.secondsLeft)
              font.pixelSize: Style.font.displayLarge * 1.6
              font.weight: Font.Light
              opacity: root.paused ? 0.5 : 1
            }
            Label {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.phase === "idle" ? "Prêt" : (root.phase === "work" ? "Travail" : "Pause") + (root.paused ? " · en pause" : "")
              color: root.soft
            }
            // Progress of the current phase
            Rectangle {
              width: parent.width
              height: Style.space(4)
              radius: height / 2
              color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
              Rectangle {
                height: parent.height
                radius: parent.radius
                color: root.phase === "break" ? "#30d158" : root.accent
                width: root.phase === "idle" ? 0 : parent.width * (1 - root.secondsLeft / Math.max(1, root.totalSeconds))
                Behavior on width { NumberAnimation { duration: Style.duration(300); easing.type: Easing.OutCubic } }
              }
            }
            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(6)
              Button {
                iconText: root.phase === "idle" || root.paused ? "\u{f040a}" : "\u{f03e4}"
                foreground: root.fg
                iconSize: Style.font.iconLarge
                tooltipText: root.phase === "idle" ? "Démarrer" : (root.paused ? "Reprendre" : "Pause")
                onClicked: root.togglePomodoro()
              }
              Button {
                iconText: "\u{f04ad}"; foreground: root.fg
                enabled: root.phase !== "idle"; opacity: enabled ? 1 : 0.4
                tooltipText: "Passer"
                onClicked: root.skipPhase()
              }
              Button {
                iconText: "\u{f04db}"; foreground: root.fg
                enabled: root.phase !== "idle"; opacity: enabled ? 1 : 0.4
                tooltipText: "Arrêter"
                onClicked: root.stopPomodoro()
              }
            }
            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(6)
              visible: root.phase === "idle"
              Button { iconText: "\u{f0374}"; foreground: root.fg; onClicked: root.workMinutes = Math.max(5, root.workMinutes - 5) }
              Label { anchors.verticalCenter: parent.verticalCenter; text: root.workMinutes + " min"; color: root.soft }
              Button { iconText: "\u{f0415}"; foreground: root.fg; onClicked: root.workMinutes = Math.min(90, root.workMinutes + 5) }
            }
            // One dot per session of the current set
            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(6)
              Repeater {
                model: root.longEvery
                Rectangle {
                  required property int index
                  width: Style.space(8); height: width; radius: width / 2
                  color: index < root.sessions % root.longEvery ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)
                }
              }
            }
          }
        }
      }

      // ===== Performances =====
      Grid {
        visible: root.tab === "perf"
        width: parent.width
        columns: 3
        spacing: Style.space(10)
        readonly property real cell: (width - spacing * 2) / 3

        Metric {
          width: parent.cell
          icon: "\u{f0ee0}"; name: "Processeur"; value: Math.round(root.perf.cpu) + " %"
          values: root.hist.cpu; maxValue: 100
        }
        Metric {
          width: parent.cell
          icon: "\u{f035b}"; name: "Mémoire"
          value: root.perf.memUsed.toFixed(1) + " Go"
          detail: "sur " + root.perf.memTotal.toFixed(0) + " Go"
          values: root.hist.mem; maxValue: 100
        }
        Metric {
          width: parent.cell
          icon: "\u{f050f}"; name: "Température"
          value: root.perf.temp >= 0 ? Math.round(root.perf.temp) + " °C" : "?"
          values: root.hist.temp; maxValue: 100
        }
        Metric {
          width: parent.cell
          icon: root.perf.batteryStatus === "Discharging" ? "\u{f0079}" : "\u{f0084}"; name: "Batterie"
          value: root.perf.battery >= 0 ? root.perf.battery + " %" : "—"
          detail: root.perf.watts >= 0 ? (root.perf.batteryStatus === "Discharging" ? "consomme " : "") + root.perf.watts + " W" : ""
          values: root.hist.watts
        }
        Metric {
          width: parent.cell
          icon: "\u{f02ca}"; name: "Disque /"
          value: root.perf.disk + " %"
          values: []
        }
        Metric {
          width: parent.cell
          icon: "\u{f06f3}"; name: "Réseau"
          value: "\u{f0045} " + root.rate(root.perf.down)
          detail: "\u{f005d} " + root.rate(root.perf.up) + (root.perf.iface ? " · " + root.perf.iface : "")
          values: root.hist.down
        }
      }
    }
  }

}
