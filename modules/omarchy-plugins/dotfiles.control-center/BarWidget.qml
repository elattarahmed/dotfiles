import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// "Gestionnaire": one bar icon (Wi-Fi, Bluetooth, VPN at a glance) and a card
// laid out like macOS's Control Center:
//   1. icon tiles: Wi-Fi, Bluetooth (on/off), VPN (state), resize; titles on hover
//   2. "Connecté": what is connected, as tinted cards — the Wi-Fi network,
//      the Bluetooth devices (AirPods with battery and noise modes in place)
//   3. sliders: sound (and output device), brightness; scale
//   4. lists, folded: known networks, other networks, paired devices
// Managed on its own: Quickshell's Networking (connectWithPsk: a passphrase
// never goes through a command line), Bluetooth and PipeWire, the AirPods
// plugin's state file and command (a plugin can't reach another plugin's
// service), omarchy-bluetooth-device. Hover opens it, a click keeps it open.
// Names from the air (SSIDs, devices) are PlainText and cut short.
BarWidget {
  id: root
  moduleName: "dotfiles.control-center"

  readonly property color fg: bar ? bar.foreground : Commons.Color.foreground
  readonly property color accent: Commons.Color.accent
  readonly property string font: bar ? bar.fontFamily : Style.font.family
  function plain(s, n) { s = String(s === undefined || s === null ? "" : s).replace(/[\u0000-\u001f]/g, " "); return s.length > n ? s.slice(0, n) : s }

  // ---- Open state ---------------------------------------------------------
  property bool hoverOpen: false
  property bool pinned: false
  readonly property bool cardOpen: pinned || hoverOpen
  property bool showKnown: true
  property bool showOthers: false
  property bool showPaired: false
  function close() { pinned = false; hoverOpen = false; passwordFor = ""; password = ""; showOthers = false }

  // ---- Wi-Fi --------------------------------------------------------------
  readonly property var netDevices: Networking.devices ? Networking.devices.values : []
  readonly property var wifiDevice: {
    for (var i = 0; i < netDevices.length; i++) if (netDevices[i] && netDevices[i].type === DeviceType.Wifi) return netDevices[i]
    return null
  }
  readonly property bool wifiOn: Networking.wifiEnabled === true
  readonly property var allNetworks: {
    var list = wifiDevice && wifiDevice.networks ? wifiDevice.networks.values.slice() : []
    list.sort(function(a, b) { return (b.signalStrength || 0) - (a.signalStrength || 0) })
    var seen = {}, out = []
    for (var i = 0; i < list.length; i++) {
      var n = list[i]
      if (!n || !n.name || seen[n.name]) continue
      seen[n.name] = true
      out.push(n)
    }
    return out
  }
  readonly property var connectedNetwork: { for (var i = 0; i < allNetworks.length; i++) if (allNetworks[i].connected) return allNetworks[i]; return null }
  readonly property var knownNetworks: allNetworks.filter(function(n) { return n.known && !n.connected })
  readonly property var otherNetworks: allNetworks.filter(function(n) { return !n.known && !n.connected }).slice(0, 10)
  property string passwordFor: ""
  property string password: ""
  property bool scanning: false
  function needsPassword(n) { return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe }
  function wifiClicked(n) {
    if (!n) return
    if (n.connected) { n.disconnect(); return }
    if (n.known || !needsPassword(n)) { n.connect(); return }
    password = ""
    passwordFor = n.name
  }
  function joinWithPassword() {
    for (var i = 0; i < allNetworks.length; i++)
      if (allNetworks[i].name === passwordFor && password.length > 0) { allNetworks[i].connectWithPsk(password); break }
    password = ""
    passwordFor = ""
  }
  function scan() { if (!wifiDevice) return; wifiDevice.scannerEnabled = true; scanning = true; scanStop.restart() }
  Timer { id: scanStop; interval: 10000; onTriggered: { root.scanning = false; if (root.wifiDevice && !root.cardOpen) root.wifiDevice.scannerEnabled = false } }
  onCardOpenChanged: {
    if (wifiDevice) wifiDevice.scannerEnabled = cardOpen
    if (cardOpen) refreshStatus()
    else if (adapter && adapter.discovering) adapter.discovering = false
  }
  function wifiIcon(strength) {
    if (strength >= 0.75) return "\u{f0928}"
    if (strength >= 0.5) return "\u{f0925}"
    if (strength >= 0.25) return "\u{f0922}"
    return "\u{f091f}"
  }

  // ---- Bluetooth ----------------------------------------------------------
  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool btOn: !!adapter && adapter.enabled
  readonly property var btAll: Bluetooth.devices ? Bluetooth.devices.values.slice() : []
  readonly property var btConnected: btAll.filter(function(d) { return d && d.connected })
  readonly property var btPaired: btAll.filter(function(d) { return d && !d.connected && (d.paired || d.bonded || d.trusted) })
  readonly property var btFound: adapter && adapter.discovering
    ? btAll.filter(function(d) { return d && !(d.paired || d.bonded || d.trusted) && (d.name || d.deviceName) }).slice(0, 6) : []
  function btName(d) { return plain(d.name || d.deviceName || d.address, 32) }
  function btAction(d) {
    if (!d || !/^([0-9A-F]{2}:){5}[0-9A-F]{2}$/i.test(String(d.address || ""))) return
    var action = d.connected ? "disconnect" : ((d.paired || d.bonded || d.trusted) ? "connect" : "pair")
    Quickshell.execDetached(["omarchy-bluetooth-device", action, String(d.address)])
  }
  Timer { id: discoveryStop; interval: 20000; onTriggered: if (root.adapter) root.adapter.discovering = false }

  // ---- AirPods (state file + command of the AirPods plugin) ------------------------
  readonly property string airpodsStatePath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-airpods.json"
  readonly property string airpodsCli: Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.sotoaugusto.airpods/bin/omarchy-airpods"
  property var airpods: ({})
  readonly property bool airpodsOn: airpods.connected === true && airpods.daemon === true
  FileView {
    path: root.airpodsStatePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { var d = JSON.parse(text()); root.airpods = d && typeof d === "object" ? d : ({}) } catch (e) { root.airpods = ({}) } }
    onLoadFailed: root.airpods = ({})
  }
  function isAirpods(d) { return airpodsOn && String(d.address || "").toUpperCase() === String(airpods.mac || "").toUpperCase() }
  function airpodsBattery(part) {
    var b = airpods.battery && airpods.battery[part]
    var level = b ? Number(b.level) : -1
    return level >= 0 && level <= 100 ? Math.round(level) + " %" : "—"
  }
  function setAirpodsMode(mode) {
    if (["anc", "transparency", "adaptive", "off"].indexOf(mode) < 0) return
    Quickshell.execDetached([airpodsCli, "--state", airpodsStatePath, "set-mode", mode])
  }

  // ---- Sound (PipeWire) -----------------------------------------------------------
  readonly property var sink: Pipewire.defaultAudioSink
  PwObjectTracker { objects: root.sink ? [root.sink] : [] }
  readonly property var sinks: Pipewire.nodes ? Pipewire.nodes.values.filter(function(n) { return n && n.audio && n.isSink && !n.isStream }) : []
  function sinkName(n) { return plain(n.description || n.nickname || n.name, 40) }

  // ---- VPN, brightness, scale -------------------------------------------------------
  property string vpnIface: ""
  property real brightness: -1
  property string scale: ""
  Process {
    id: statusProc
    command: ["sh", "-c",
      "v=$(ip -o link show type wireguard 2>/dev/null | awk -F': ' 'NR == 1 {print $2}');" +
      "[ -n \"$v\" ] || v=$(ip -o link show 2>/dev/null | grep -oE 'tun[0-9]+' | head -n 1);" +
      "echo \"vpn=$v\";" +
      "echo \"bright=$(brightnessctl -c backlight -m 2>/dev/null | head -n 1 | cut -d, -f4 | tr -d '%')\";" +
      "echo \"scale=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .scale')\""]
    stdout: StdioCollector {
      onStreamFinished: {
        var v = {}
        text.split("\n").forEach(function(line) { var i = line.indexOf("="); if (i > 0) v[line.slice(0, i)] = line.slice(i + 1).trim() })
        root.vpnIface = /^[A-Za-z0-9_.-]{1,20}$/.test(v.vpn || "") ? v.vpn : ""
        var b = parseInt(v.bright, 10)
        if (!brightSlider.dragging) root.brightness = isFinite(b) ? b / 100 : -1
        root.scale = /^[0-9.]+$/.test(v.scale || "") ? (Math.round(Number(v.scale) * 100) + " %") : ""
      }
    }
  }
  function refreshStatus() { if (!statusProc.running) statusProc.running = true }
  Timer { interval: root.cardOpen ? 2000 : 15000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refreshStatus() }
  function act(argv) { Quickshell.execDetached(argv); refreshLater.restart() }
  Timer { id: refreshLater; interval: 400; onTriggered: root.refreshStatus() }

  // ---- Bar icon ---------------------------------------------------------------
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  readonly property real openPanelIndicatorWidth: button.labelWidth

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: (root.wifiOn ? (root.connectedNetwork ? root.wifiIcon(root.connectedNetwork.signalStrength) : "\u{f05a9}") : "\u{f05aa}")
      + (root.btConnected.length ? "  \u{f00b1}" : "")
      + (root.vpnIface ? "  \u{f099d}" : "")
    onPressed: function(b) { root.pinned = !root.pinned; root.hoverOpen = root.pinned }
  }
  Timer { id: openDelay; interval: 500; onTriggered: if (button.tooltipHovered) root.hoverOpen = true }
  Timer { id: closeDelay; interval: 450; onTriggered: if (!button.tooltipHovered && !popup.containsMouse && !root.pinned) root.hoverOpen = false }
  Connections {
    target: button
    function onTooltipHoveredChanged() { if (button.tooltipHovered) { closeDelay.stop(); openDelay.restart() } else { openDelay.stop(); closeDelay.restart() } }
  }
  Connections {
    target: popup
    function onContainsMouseChanged() { if (popup.containsMouse) closeDelay.stop(); else if (root.passwordFor === "") closeDelay.restart() }
  }

  // ---- Pieces (inline components see Omarchy's tokens, not `root`) -----------------
  component Label: Text {
    textFormat: Text.PlainText
    color: Commons.Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    elide: Text.ElideRight
  }

  component Caption: Text {
    textFormat: Text.PlainText
    color: Commons.Color.foreground
    opacity: 0.55
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.bold: true
  }

  // A square icon tile: filled with the accent while on, its title on hover
  component Tile: Rectangle {
    id: tile
    property string icon: ""
    property string title: ""
    property bool on: false
    property bool clickable: true
    signal activated()
    width: Style.space(56)
    height: Style.space(56)
    radius: Style.cornerRadius + Style.space(4)
    color: on ? Commons.Color.accent : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, tileMouse.containsMouse && clickable ? 0.14 : 0.08)
    Behavior on color { ColorAnimation { duration: Style.duration(150) } }
    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: tile.icon
      color: tile.on ? Commons.Color.background : Commons.Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.iconLarge * 1.2
    }
    ToolTipArea { id: tileMouse; anchors.fill: parent; text: tile.title; clickable: tile.clickable; onClicked: tile.activated() }
  }

  // Hover area with a small title above it (no bar tooltip inside a popup)
  component ToolTipArea: MouseArea {
    id: tipArea
    property string text: ""
    property bool clickable: true
    hoverEnabled: true
    cursorShape: clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
    Rectangle {
      visible: tipArea.containsMouse && tipArea.text !== ""
      z: 10
      anchors.bottom: parent.top
      anchors.bottomMargin: Style.space(4)
      anchors.horizontalCenter: parent.horizontalCenter
      width: tipText.implicitWidth + Style.space(12)
      height: tipText.implicitHeight + Style.space(6)
      radius: Style.cornerRadius
      color: Commons.Color.tooltip.background
      Text {
        id: tipText
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: tipArea.text
        color: Commons.Color.tooltip.text
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }

  // An icon-only action button with its title on hover
  component IconAction: Rectangle {
    id: ia
    property string icon: ""
    property string title: ""
    property bool on: false
    signal activated()
    width: Style.space(32)
    height: Style.space(32)
    radius: Style.cornerRadius
    color: on ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.3)
              : Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, iaMouse.containsMouse ? 0.14 : 0.06)
    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: ia.icon
      color: Commons.Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body * 1.2
    }
    ToolTipArea { id: iaMouse; anchors.fill: parent; text: ia.title; onClicked: ia.activated() }
  }

  // A list row: icon, name, detail on the right
  component ListRow: Rectangle {
    id: lr
    property string icon: ""
    property string label: ""
    property string detail: ""
    signal activated()
    width: parent ? parent.width : 0
    height: Style.space(30)
    radius: Style.cornerRadius
    color: lrMouse.containsMouse ? Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.08) : "transparent"
    Label { id: lrIcon; anchors.left: parent.left; anchors.leftMargin: Style.space(6); anchors.verticalCenter: parent.verticalCenter; text: lr.icon; opacity: 0.8 }
    Label {
      anchors.left: lrIcon.right; anchors.leftMargin: Style.space(8); anchors.right: lrDetail.left; anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter; text: lr.label
    }
    Label { id: lrDetail; anchors.right: parent.right; anchors.rightMargin: Style.space(6); anchors.verticalCenter: parent.verticalCenter; text: lr.detail; opacity: 0.55; font.pixelSize: Style.font.bodySmall }
    MouseArea { id: lrMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: lr.activated() }
  }

  // A tinted card for something connected
  component Connected: Rectangle {
    default property alias content: cInner.data
    width: parent ? parent.width : 0
    height: cInner.implicitHeight + Style.space(20)
    radius: Style.cornerRadius + Style.space(2)
    color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.14)
    border.width: 1
    border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.35)
    Column { id: cInner; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Style.space(10); spacing: Style.space(6) }
  }

  // ---- The card ---------------------------------------------------------------------
  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.cardOpen
    triggerMode: root.pinned || root.passwordFor !== "" ? "click" : "hover"
    contentWidth: popup.fittedContentWidth(Style.space(380))
    contentHeight: popup.fittedContentHeight(content.implicitHeight)

    Flickable {
      anchors.fill: parent
      contentHeight: content.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        Text {
          textFormat: Text.PlainText
          text: "Gestionnaire"
          color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.6)
          font.family: root.font
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }

        // 1. Tiles
        Row {
          spacing: Style.space(10)
          Tile {
            icon: root.wifiOn ? "\u{f05a9}" : "\u{f05aa}"
            title: root.wifiOn ? "Wi-Fi activé · clic pour couper" : "Wi-Fi coupé · clic pour activer"
            on: root.wifiOn
            onActivated: Networking.wifiEnabled = !root.wifiOn
          }
          Tile {
            icon: root.btOn ? "\u{f00af}" : "\u{f00b2}"
            title: root.btOn ? "Bluetooth activé · clic pour couper" : "Bluetooth coupé · clic pour activer"
            on: root.btOn
            onActivated: if (root.adapter) root.adapter.enabled = !root.btOn
          }
          Tile {
            icon: root.vpnIface ? "\u{f099d}" : "\u{f099e}"
            title: root.vpnIface ? "VPN actif (" + root.vpnIface + ")" : "Pas de VPN"
            on: root.vpnIface !== ""
            clickable: false
          }
          Tile {
            icon: "\u{f0a6a}"
            title: "Redimensionner la fenêtre active (Super+R)"
            onActivated: { root.close(); Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.submap("resize")']) }
          }
        }

        // 2. Connected
        Caption { text: "CONNECTÉ" }
        Connected {
          visible: root.wifiOn && root.connectedNetwork !== null
          Row {
            spacing: Style.space(10)
            Label { text: root.connectedNetwork ? root.wifiIcon(root.connectedNetwork.signalStrength) : ""; color: Commons.Color.accent; font.pixelSize: Style.font.iconLarge * 1.2; anchors.verticalCenter: parent.verticalCenter }
            Column {
              anchors.verticalCenter: parent.verticalCenter
              Label { text: root.connectedNetwork ? root.plain(root.connectedNetwork.name, 32) : ""; font.bold: true }
              Label {
                text: root.connectedNetwork ? "Wi-Fi · signal " + Math.round((root.connectedNetwork.signalStrength || 0) * 100) + " %" : ""
                opacity: 0.6; font.pixelSize: Style.font.bodySmall
              }
            }
          }
        }
        Repeater {
          model: root.btOn ? root.btConnected : []
          Connected {
            id: devCard
            required property var modelData
            Item {
              width: parent.width
              height: Style.space(32)
              Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(10)
                Label { text: root.isAirpods(devCard.modelData) ? "\u{f02cb}" : "\u{f00b1}"; color: Commons.Color.accent; font.pixelSize: Style.font.iconLarge * 1.2; anchors.verticalCenter: parent.verticalCenter }
                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  Label { text: root.btName(devCard.modelData); font.bold: true }
                  Label {
                    text: root.isAirpods(devCard.modelData)
                      ? "G " + root.airpodsBattery("left") + " · D " + root.airpodsBattery("right") + " · boîtier " + root.airpodsBattery("case")
                      : "Bluetooth" + (devCard.modelData.batteryAvailable ? " · " + Math.round(devCard.modelData.battery * 100) + " %" : "")
                    opacity: 0.6; font.pixelSize: Style.font.bodySmall
                  }
                }
              }
              IconAction {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "\u{f0156}"; title: "Déconnecter"
                onActivated: root.btAction(devCard.modelData)
              }
            }
            // AirPods noise modes, as icons
            Row {
              visible: root.isAirpods(devCard.modelData)
              spacing: Style.space(6)
              Repeater {
                model: [["anc", "\u{f04c3}", "Réduction de bruit"], ["transparency", "\u{f05cb}", "Transparence"], ["adaptive", "\u{f04e6}", "Adaptatif"], ["off", "\u{f073a}", "Désactivé"]]
                IconAction {
                  required property var modelData
                  icon: modelData[1]; title: modelData[2]
                  on: root.airpods.mode === modelData[0]
                  onActivated: root.setAirpodsMode(modelData[0])
                }
              }
            }
          }
        }
        Label {
          visible: !(root.wifiOn && root.connectedNetwork) && !(root.btOn && root.btConnected.length)
          text: root.wifiOn ? "Rien de connecté" : "Wi-Fi coupé"
          opacity: 0.55
        }

        // 3. Sound, brightness, scale
        Caption { text: "SON ET ÉCRAN" }
        Row {
          width: parent.width
          spacing: Style.space(8)
          IconAction {
            anchors.verticalCenter: parent.verticalCenter
            icon: root.sink && root.sink.audio && root.sink.audio.muted ? "\u{f075f}" : "\u{f057e}"
            title: root.sink && root.sink.audio && root.sink.audio.muted ? "Rétablir le son" : "Couper le son"
            onActivated: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted
          }
          PanelSlider {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Style.space(40)
            bar: root.bar
            value: root.sink && root.sink.audio ? Math.min(1, root.sink.audio.volume) : 0
            onMoved: function(v) { if (root.sink && root.sink.audio) root.sink.audio.volume = v }
          }
        }
        Flow {
          width: parent.width
          spacing: Style.space(6)
          visible: root.sinks.length > 1
          Repeater {
            model: root.sinks
            Rectangle {
              required property var modelData
              readonly property bool current: root.sink === modelData
              width: sinkText.implicitWidth + Style.space(16)
              height: Style.space(26)
              radius: height / 2
              color: current ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.3) : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06)
              Text { id: sinkText; anchors.centerIn: parent; textFormat: Text.PlainText; text: root.sinkName(modelData); color: root.fg; font.family: root.font; font.pixelSize: Style.font.caption }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Pipewire.preferredDefaultAudioSink = modelData }
            }
          }
        }
        Row {
          width: parent.width
          spacing: Style.space(8)
          IconAction { anchors.verticalCenter: parent.verticalCenter; icon: "\u{f00df}"; title: "Luminosité" + (root.brightness >= 0 ? " " + Math.round(root.brightness * 100) + " %" : "") }
          PanelSlider {
            id: brightSlider
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Style.space(40)
            bar: root.bar
            minimum: 0.01
            value: Math.max(0.01, root.brightness)
            onReleased: function(v) { root.brightness = v; root.act(["brightnessctl", "-q", "-c", "backlight", "set", Math.round(v * 100) + "%"]) }
          }
        }
        Row {
          spacing: Style.space(8)
          IconAction { icon: "\u{f0374}"; title: "Plus petit"; onActivated: root.act(["omarchy-hyprland-monitor-scaling", "down"]) }
          Label { anchors.verticalCenter: parent.verticalCenter; text: "\u{f0349}  Échelle " + root.scale; opacity: 0.8 }
          IconAction { icon: "\u{f0415}"; title: "Plus grand"; onActivated: root.act(["omarchy-hyprland-monitor-scaling", "up"]) }
        }

        // 4. Wi-Fi networks, folded
        Item {
          visible: root.wifiOn
          width: parent.width
          height: wifiHead.implicitHeight
          Caption { id: wifiHead; anchors.verticalCenter: parent.verticalCenter; text: "RÉSEAUX WI-FI" }
          IconAction {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            icon: root.scanning ? "\u{f0450}" : "\u{f0453}"; title: root.scanning ? "Recherche en cours…" : "Rechercher des réseaux"
            on: root.scanning
            onActivated: root.scan()
          }
        }
        Column {
          visible: root.wifiOn
          width: parent.width
          spacing: Style.space(2)
          Repeater {
            model: root.knownNetworks
            Column {
              id: kn
              required property var modelData
              width: parent.width
              ListRow {
                icon: root.wifiIcon(kn.modelData.signalStrength || 0)
                label: root.plain(kn.modelData.name, 32)
                detail: "connu"
                onActivated: root.wifiClicked(kn.modelData)
              }
            }
          }
          ListRow {
            icon: root.showOthers ? "\u{f0140}" : "\u{f0142}"
            label: "Autres réseaux (" + root.otherNetworks.length + ")"
            onActivated: root.showOthers = !root.showOthers
          }
          Repeater {
            model: root.showOthers ? root.otherNetworks : []
            Column {
              id: on_
              required property var modelData
              width: parent.width
              ListRow {
                icon: root.wifiIcon(on_.modelData.signalStrength || 0)
                label: root.plain(on_.modelData.name, 32)
                detail: root.needsPassword(on_.modelData) ? "\u{f033e}" : "ouvert"
                onActivated: root.wifiClicked(on_.modelData)
              }
              Row {
                visible: root.passwordFor === on_.modelData.name
                width: parent.width
                spacing: Style.space(6)
                Rectangle {
                  width: parent.width - joinButton.width - Style.space(6)
                  height: joinButton.height
                  radius: Style.cornerRadius
                  color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                  TextInput {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(8)
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: root.fg
                    font.family: root.font
                    font.pixelSize: Style.font.body
                    text: root.password
                    onTextChanged: root.password = text
                    onAccepted: root.joinWithPassword()
                    onVisibleChanged: if (visible) forceActiveFocus()
                  }
                }
                IconAction { id: joinButton; icon: "\u{f0054}"; title: "Rejoindre"; onActivated: root.joinWithPassword() }
              }
            }
          }
        }

        // 5. Bluetooth devices, folded
        Item {
          visible: root.btOn
          width: parent.width
          height: btHead.implicitHeight
          Caption { id: btHead; anchors.verticalCenter: parent.verticalCenter; text: "APPAREILS BLUETOOTH" }
          IconAction {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            icon: root.adapter && root.adapter.discovering ? "\u{f0450}" : "\u{f0415}"
            title: root.adapter && root.adapter.discovering ? "Recherche en cours…" : "Associer un appareil"
            on: !!root.adapter && root.adapter.discovering
            onActivated: if (root.adapter) { root.adapter.discovering = !root.adapter.discovering; if (root.adapter.discovering) discoveryStop.restart() }
          }
        }
        Column {
          visible: root.btOn
          width: parent.width
          spacing: Style.space(2)
          Repeater {
            model: root.btPaired
            ListRow {
              required property var modelData
              icon: "\u{f00af}"; label: root.btName(modelData); detail: "connecter"
              onActivated: root.btAction(modelData)
            }
          }
          Repeater {
            model: root.btFound
            ListRow {
              required property var modelData
              icon: "\u{f0337}"; label: root.btName(modelData); detail: "associer"
              onActivated: root.btAction(modelData)
            }
          }
          Label { visible: root.btPaired.length === 0 && root.btFound.length === 0; text: "Aucun autre appareil"; opacity: 0.5; font.pixelSize: Style.font.bodySmall }
        }
      }
    }
  }
}
