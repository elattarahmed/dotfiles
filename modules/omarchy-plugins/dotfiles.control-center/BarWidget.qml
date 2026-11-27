import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// "Gestionnaire": one bar icon (Wi-Fi, Bluetooth, VPN at a glance) and a card
// that manages them on its own, without Omarchy's bar widgets:
//   Wi-Fi      on/off, networks by signal; click connects / disconnects, or
//              opens a password field (connectWithPsk: the passphrase never
//              goes through a command line)
//   Bluetooth  on/off, devices with battery; click connects / disconnects;
//              search and pair new ones (omarchy-bluetooth-device)
//   AirPods    battery and noise mode, through the AirPods plugin's service
//   VPN        state (WireGuard or tun interface)
//   Écran      brightness and scale, resize the active window
// hover opens it, a click keeps it open. Names from the air (SSIDs, device
// names) are PlainText and cut short.
BarWidget {
  id: root
  moduleName: "dotfiles.control-center"

  readonly property color fg: bar ? bar.foreground : Commons.Color.foreground
  readonly property color accent: Commons.Color.accent
  readonly property color soft: Qt.rgba(fg.r, fg.g, fg.b, 0.6)
  readonly property color tileColor: Qt.rgba(fg.r, fg.g, fg.b, 0.06)
  readonly property string font: bar ? bar.fontFamily : Style.font.family
  function plain(s, n) { s = String(s === undefined || s === null ? "" : s).replace(/[\u0000-\u001f]/g, " "); return s.length > n ? s.slice(0, n) : s }

  // ---- Open state ---------------------------------------------------------
  property bool hoverOpen: false
  property bool pinned: false
  readonly property bool cardOpen: pinned || hoverOpen
  function close() { pinned = false; hoverOpen = false; passwordFor = ""; password = "" }

  // ---- Wi-Fi --------------------------------------------------------------
  readonly property var devices: Networking.devices ? Networking.devices.values : []
  readonly property var wifiDevice: {
    for (var i = 0; i < devices.length; i++) if (devices[i] && devices[i].type === DeviceType.Wifi) return devices[i]
    return null
  }
  readonly property bool wifiOn: Networking.wifiEnabled === true
  readonly property var networks: {
    var list = wifiDevice && wifiDevice.networks ? wifiDevice.networks.values.slice() : []
    var seen = {}, out = []
    list.sort(function(a, b) {
      if (!!a.connected !== !!b.connected) return a.connected ? -1 : 1
      if (!!a.known !== !!b.known) return a.known ? -1 : 1
      return (b.signalStrength || 0) - (a.signalStrength || 0)
    })
    for (var i = 0; i < list.length; i++) {
      var n = list[i]
      if (!n || !n.name || seen[n.name]) continue
      seen[n.name] = true
      out.push(n)
    }
    return out.slice(0, 8)
  }
  readonly property var connectedNetwork: networks.length && networks[0].connected ? networks[0] : null
  property string passwordFor: ""
  property string password: ""
  function needsPassword(n) { return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe }
  function wifiClicked(n) {
    if (!n) return
    if (n.connected) { n.disconnect(); return }
    if (n.known || !needsPassword(n)) { n.connect(); return }
    password = ""
    passwordFor = n.name
  }
  function joinWithPassword() {
    for (var i = 0; i < networks.length; i++) {
      if (networks[i].name === passwordFor && password.length > 0) { networks[i].connectWithPsk(password); break }
    }
    password = ""
    passwordFor = ""
  }
  // A scan while the card is open, and a moment after asking for one
  Timer { id: scanStop; interval: 12000; onTriggered: if (root.wifiDevice && !root.cardOpen) root.wifiDevice.scannerEnabled = false }
  onCardOpenChanged: {
    if (wifiDevice) wifiDevice.scannerEnabled = cardOpen
    if (cardOpen) { refreshStatus() } else if (adapter && adapter.discovering) adapter.discovering = false
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
  readonly property var btDevices: {
    var all = Bluetooth.devices ? Bluetooth.devices.values.slice() : []
    return all.filter(function(d) { return d && (d.paired || d.bonded || d.trusted || d.connected) })
      .sort(function(a, b) { return (!!b.connected) - (!!a.connected) })
  }
  readonly property var btFound: {
    if (!adapter || !adapter.discovering) return []
    var all = Bluetooth.devices ? Bluetooth.devices.values.slice() : []
    return all.filter(function(d) { return d && !(d.paired || d.bonded || d.trusted) && (d.name || d.deviceName) }).slice(0, 6)
  }
  readonly property bool btConnected: btDevices.some(function(d) { return d.connected })
  function btName(d) { return plain(d.name || d.deviceName || d.address, 32) }
  function btAction(d) {
    if (!d || !/^([0-9A-F]{2}:){5}[0-9A-F]{2}$/i.test(String(d.address || ""))) return
    var action = d.connected ? "disconnect" : ((d.paired || d.bonded || d.trusted) ? "connect" : "pair")
    Quickshell.execDetached(["omarchy-bluetooth-device", action, String(d.address)])
  }
  Timer { id: discoveryStop; interval: 20000; onTriggered: if (root.adapter) root.adapter.discovering = false }

  // ---- AirPods ------------------------------------------------------------------
  // A plugin can't reach another plugin's service, so this reads the state
  // file the AirPods plugin keeps and changes the mode with its own command.
  readonly property string airpodsState: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-airpods.json"
  readonly property string airpodsCli: Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.sotoaugusto.airpods/bin/omarchy-airpods"
  property var airpods: ({})
  readonly property bool airpodsOn: airpods.connected === true && airpods.daemon === true
  FileView {
    path: root.airpodsState
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { var d = JSON.parse(text()); root.airpods = d && typeof d === "object" ? d : ({}) } catch (e) { root.airpods = ({}) } }
    onLoadFailed: root.airpods = ({})
  }
  function airpodsBattery(part) {
    var b = airpods.battery && airpods.battery[part]
    var level = b ? Number(b.level) : -1
    return level >= 0 && level <= 100 ? Math.round(level) + " %" + (b.charging ? " \u{f0084}" : "") : "—"
  }
  function setAirpodsMode(mode) {
    if (["anc", "transparency", "adaptive", "off"].indexOf(mode) < 0) return
    Quickshell.execDetached([airpodsCli, "--state", airpodsState, "set-mode", mode])
  }

  // ---- VPN, brightness, scale -----------------------------------------------
  property string vpnIface: ""
  property int brightness: -1
  property string scale: ""
  Process {
    id: statusProc
    command: ["sh", "-c",
      "v=$(ip -o link show type wireguard 2>/dev/null | awk -F': ' 'NR == 1 {print $2}');" +
      "[ -n \"$v\" ] || v=$(ip -o link show 2>/dev/null | grep -oE 'tun[0-9]+' | head -n 1);" +
      "echo \"vpn=$v\";" +
      "echo \"bright=$(brightnessctl -m 2>/dev/null | head -n 1 | cut -d, -f4 | tr -d '%')\";" +
      "echo \"scale=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .scale')\""]
    stdout: StdioCollector {
      onStreamFinished: {
        var v = {}
        text.split("\n").forEach(function(line) { var i = line.indexOf("="); if (i > 0) v[line.slice(0, i)] = line.slice(i + 1).trim() })
        root.vpnIface = /^[A-Za-z0-9_.-]{1,20}$/.test(v.vpn || "") ? v.vpn : ""
        var b = parseInt(v.bright, 10)
        root.brightness = isFinite(b) ? b : -1
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
      + (root.btConnected ? "  \u{f00b1}" : "")
      + (root.vpnIface ? "  \u{f099d}" : "")
    onPressed: function(b) { root.pinned = !root.pinned; root.hoverOpen = root.pinned }
  }
  Timer { id: openDelay; interval: 300; onTriggered: if (button.tooltipHovered) root.hoverOpen = true }
  Timer { id: closeDelay; interval: 450; onTriggered: if (!button.tooltipHovered && !popup.containsMouse && !root.pinned) root.hoverOpen = false }
  Connections {
    target: button
    function onTooltipHoveredChanged() { if (button.tooltipHovered) { closeDelay.stop(); openDelay.restart() } else { openDelay.stop(); closeDelay.restart() } }
  }
  Connections {
    target: popup
    function onContainsMouseChanged() { if (popup.containsMouse) closeDelay.stop(); else if (root.passwordFor === "") closeDelay.restart() }
  }

  // ---- Pieces (inline components use Omarchy's tokens, not `root`) -----------------
  component Label: Text {
    textFormat: Text.PlainText
    color: Commons.Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    elide: Text.ElideRight
  }

  component Section: Rectangle {
    default property alias content: inner.data
    width: parent ? parent.width : 0
    height: inner.implicitHeight + Style.space(20)
    radius: Style.cornerRadius
    color: Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.06)
    Column {
      id: inner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.space(10)
      spacing: Style.space(6)
    }
  }

  // A clickable row: icon, text, detail on the right
  component Row2: Rectangle {
    id: row2
    property string icon: ""
    property string label: ""
    property string detail: ""
    property bool strong: false
    signal activated()
    width: parent ? parent.width : 0
    height: Style.space(30)
    radius: Style.cornerRadius
    color: rowMouse.containsMouse ? Qt.rgba(Commons.Color.foreground.r, Commons.Color.foreground.g, Commons.Color.foreground.b, 0.08) : "transparent"
    Label { id: rowIcon; anchors.left: parent.left; anchors.leftMargin: Style.space(6); anchors.verticalCenter: parent.verticalCenter; text: row2.icon; color: Commons.Color.accent }
    Label {
      anchors.left: rowIcon.right; anchors.leftMargin: Style.space(8); anchors.right: rowDetail.left; anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: row2.label; font.bold: row2.strong
    }
    Label { id: rowDetail; anchors.right: parent.right; anchors.rightMargin: Style.space(6); anchors.verticalCenter: parent.verticalCenter; text: row2.detail; opacity: 0.6; font.pixelSize: Style.font.bodySmall }
    MouseArea { id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: row2.activated() }
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
        spacing: Style.space(10)

        Text {
          textFormat: Text.PlainText
          text: "Gestionnaire"
          color: root.soft
          font.family: root.font
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }

        // ===== Wi-Fi =====
        Section {
          Item {
            width: parent.width
            height: wifiToggle.implicitHeight
            Label { anchors.verticalCenter: parent.verticalCenter; text: "\u{f05a9}  Wi-Fi"; font.bold: true }
            Button {
              id: wifiToggle
              anchors.right: parent.right
              text: root.wifiOn ? "Activé" : "Désactivé"; selected: root.wifiOn; foreground: root.fg
              onClicked: Networking.wifiEnabled = !root.wifiOn
            }
          }
          Repeater {
            model: root.wifiOn ? root.networks : []
            Column {
              id: netRow
              required property var modelData
              width: parent.width
              Row2 {
                icon: root.wifiIcon(netRow.modelData.signalStrength || 0)
                label: root.plain(netRow.modelData.name, 32) + (root.needsPassword(netRow.modelData) ? "  \u{f033e}" : "")
                detail: netRow.modelData.connected ? "connecté" : (netRow.modelData.known ? "connu" : "")
                strong: !!netRow.modelData.connected
                onActivated: root.wifiClicked(netRow.modelData)
              }
              // Password, in place, for a new protected network
              Row {
                visible: root.passwordFor === netRow.modelData.name
                width: parent.width
                spacing: Style.space(6)
                Rectangle {
                  width: parent.width - joinButton.width - Style.space(6)
                  height: joinButton.height
                  radius: Style.cornerRadius
                  color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                  TextInput {
                    id: pw
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
                    Component.onCompleted: if (visible) forceActiveFocus()
                    onVisibleChanged: if (visible) forceActiveFocus()
                  }
                }
                Button { id: joinButton; text: "Rejoindre"; foreground: root.fg; onClicked: root.joinWithPassword() }
              }
            }
          }
          Row2 {
            visible: root.wifiOn
            icon: "\u{f0450}"; label: "Rechercher des réseaux"; detail: root.wifiDevice && root.wifiDevice.scannerEnabled ? "en cours…" : ""
            onActivated: if (root.wifiDevice) { root.wifiDevice.scannerEnabled = true; scanStop.restart() }
          }
        }

        // ===== Bluetooth =====
        Section {
          Item {
            width: parent.width
            height: btToggle.implicitHeight
            Label { anchors.verticalCenter: parent.verticalCenter; text: "\u{f00af}  Bluetooth"; font.bold: true }
            Button {
              id: btToggle
              anchors.right: parent.right
              text: root.btOn ? "Activé" : "Désactivé"; selected: root.btOn; foreground: root.fg
              onClicked: if (root.adapter) root.adapter.enabled = !root.btOn
            }
          }
          Repeater {
            model: root.btOn ? root.btDevices : []
            Row2 {
              required property var modelData
              icon: modelData.connected ? "\u{f00b1}" : "\u{f00af}"
              label: root.btName(modelData)
              detail: (modelData.connected ? "connecté" : "") + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + " %" : "")
              strong: !!modelData.connected
              onActivated: root.btAction(modelData)
            }
          }
          Repeater {
            model: root.btFound
            Row2 {
              required property var modelData
              icon: "\u{f0337}"; label: root.btName(modelData); detail: "associer"
              onActivated: root.btAction(modelData)
            }
          }
          Row2 {
            visible: root.btOn
            icon: "\u{f0450}"
            label: root.adapter && root.adapter.discovering ? "Recherche d'appareils…" : "Associer un appareil"
            onActivated: if (root.adapter) { root.adapter.discovering = !root.adapter.discovering; if (root.adapter.discovering) discoveryStop.restart() }
          }
        }

        // ===== AirPods =====
        Section {
          visible: root.airpodsOn
          Label { text: "\u{f02cb}  " + root.plain(root.airpods.name || "AirPods", 32); font.bold: true }
          Label {
            text: "Gauche " + root.airpodsBattery("left") + "   ·   Droit " + root.airpodsBattery("right") + "   ·   Boîtier " + root.airpodsBattery("case")
            opacity: 0.7; font.pixelSize: Style.font.bodySmall
          }
          Flow {
            width: parent.width
            spacing: Style.space(6)
            Repeater {
              model: [["anc", "\u{f04c3}", "Réduction"], ["transparency", "\u{f05cb}", "Transparence"], ["adaptive", "\u{f04e6}", "Adaptatif"], ["off", "\u{f073a}", "Désactivé"]]
              Button {
                required property var modelData
                iconText: modelData[1]; text: modelData[2]; foreground: root.fg
                selected: root.airpods.mode === modelData[0]
                onClicked: root.setAirpodsMode(modelData[0])
              }
            }
          }
        }

        // ===== VPN and screen =====
        Section {
          Row2 {
            icon: root.vpnIface ? "\u{f099d}" : "\u{f099e}"
            label: root.vpnIface ? "VPN actif" : "Pas de VPN"
            detail: root.vpnIface
            strong: root.vpnIface !== ""
          }
          Item {
            width: parent.width
            height: brightRow.implicitHeight
            Label { anchors.verticalCenter: parent.verticalCenter; text: "\u{f00df}  Luminosité" + (root.brightness >= 0 ? "  " + root.brightness + " %" : "") }
            Row {
              id: brightRow
              anchors.right: parent.right
              spacing: Style.space(4)
              Button { iconText: "\u{f0374}"; foreground: root.fg; onClicked: root.act(["omarchy-brightness-display", "5%-"]) }
              Button { iconText: "\u{f0415}"; foreground: root.fg; onClicked: root.act(["omarchy-brightness-display", "+5%"]) }
            }
          }
          Item {
            width: parent.width
            height: scaleRow.implicitHeight
            Label { anchors.verticalCenter: parent.verticalCenter; text: "\u{f0349}  Échelle" + (root.scale ? "  " + root.scale : "") }
            Row {
              id: scaleRow
              anchors.right: parent.right
              spacing: Style.space(4)
              Button { iconText: "\u{f0374}"; foreground: root.fg; onClicked: root.act(["omarchy-hyprland-monitor-scaling", "down"]) }
              Button { iconText: "\u{f0415}"; foreground: root.fg; onClicked: root.act(["omarchy-hyprland-monitor-scaling", "up"]) }
            }
          }
          Row2 {
            icon: "\u{f0a6a}"; label: "Redimensionner la fenêtre active"; detail: "Super+R"
            onActivated: { root.close(); Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.submap("resize")']) }
          }
        }
      }
    }
  }
}
