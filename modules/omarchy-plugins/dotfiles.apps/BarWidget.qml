import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.Commons
import qs.Ui

// "Applications": the apps' tray icons (Discord, VLC…), always shown in a row,
// with no drawer to hover. Click: the app; middle click: its second action;
// right click (or click when it only has a menu): its menu. Passive icons
// (apps saying they have nothing to show) stay hidden, like in Omarchy's tray.
BarWidget {
  id: root
  moduleName: "dotfiles.apps"

  readonly property var items: SystemTray.items ? SystemTray.items.values.filter(function(i) { return i && i.status !== Status.Passive }) : []
  readonly property real iconSize: Math.round(Style.font.iconLarge * 1.05)

  visible: items.length > 0
  implicitWidth: visible ? row.implicitWidth + Style.space(12) : 0
  implicitHeight: barSize

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(8)

    Repeater {
      model: root.items

      Item {
        id: app
        required property var modelData
        width: root.iconSize
        height: root.iconSize
        anchors.verticalCenter: parent.verticalCenter

        IconImage {
          anchors.fill: parent
          source: String(app.modelData.icon || "")
          implicitSize: root.iconSize
          asynchronous: true
        }

        MouseArea {
          id: mouse
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
          cursorShape: Qt.PointingHandCursor
          function menu() {
            if (!app.modelData.hasMenu) return
            var p = app.mapToItem(null, 0, app.height)
            app.modelData.display(app.QsWindow.window, p.x, p.y)
          }
          onClicked: function(m) {
            if (m.button === Qt.RightButton) menu()
            else if (m.button === Qt.MiddleButton) app.modelData.secondaryActivate()
            else if (app.modelData.onlyMenu) menu()
            else app.modelData.activate()
          }
          onWheel: function(w) { app.modelData.scroll(w.angleDelta.y, false) }
          onEntered: if (root.bar) root.bar.showTooltip(app, "Applications · " + String(app.modelData.tooltipTitle || app.modelData.title || app.modelData.id || "").slice(0, 60))
          onExited: if (root.bar) root.bar.hideTooltip(app)
        }
      }
    }
  }
}
