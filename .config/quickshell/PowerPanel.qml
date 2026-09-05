import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "."

PanelWindow {
  id: root

  property bool opened: false
  property int selectedIndex: 0

  readonly property var options: [
    {
      label: "Lock",
      icon: "󰌾",
      command: "hyprlock",
      color: Theme.accent
    },
    {
      label: "Log Out",
      icon: "󰍃",
      command: "hyprctl dispatch exit",
      color: Theme.fg
    },
    {
      label: "Restart",
      icon: "󰜉",
      command: "systemctl reboot",
      color: Theme.warning
    },
    {
      label: "Shutdown",
      icon: "󰐥",
      command: "systemctl poweroff",
      color: Theme.critical
    }
  ]

  visible: opened
  implicitWidth: 220
  implicitHeight: contentCol.implicitHeight + 24
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "dotfiles-power-panel"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  property real targetCenterX: -1

  anchors.top: true
  anchors.left: true
  anchors.right: false
  margins.top: 44
  margins.left: {
    var screenW = (root.screen ? root.screen.width : 1920)
    var panelW = root.implicitWidth || 220
    var cx = targetCenterX >= 0 ? targetCenterX : (screenW / 2)
    var left = cx - (panelW / 2)
    var minLeft = 12
    var maxLeft = screenW - panelW - 12
    return Math.round(Math.max(minLeft, Math.min(maxLeft, left)))
  }

  HyprlandFocusGrab {
    windows: [ root ]
    active: root.opened
    onCleared: root.closePanel()
  }

  function closePanel() {
    opened = false
    selectedIndex = 0
  }

  function execute(option) {
    if (!option || !option.command) return
    closePanel()
    execProc.command = ["bash", "-lc", option.command]
    execProc.running = false
    execProc.running = true
  }

  IpcHandler {
    target: "power"
    function toggle() { root.opened = !root.opened }
    function open() { root.opened = true }
    function close() { root.closePanel() }
  }

  Item {
    anchors.fill: parent
    focus: root.opened

    Keys.onEscapePressed: root.closePanel()
    Keys.onUpPressed: {
      if (root.selectedIndex > 0) root.selectedIndex--
      else root.selectedIndex = root.options.length - 1
    }
    Keys.onDownPressed: {
      if (root.selectedIndex < root.options.length - 1) root.selectedIndex++
      else root.selectedIndex = 0
    }
    Keys.onReturnPressed: {
      root.execute(root.options[root.selectedIndex])
    }

    Rectangle {
      anchors.fill: parent
      color: Theme.panelBg
      radius: Theme.radius
      border.color: Theme.border
      border.width: 1
    }

    Column {
      id: contentCol
      anchors.fill: parent
      anchors.margins: 10
      spacing: 6

      Repeater {
        model: root.options
        delegate: Rectangle {
          id: optionItem
          required property var modelData
          required property int index
          width: contentCol.width
          height: 42
          radius: Theme.cardRadius

          readonly property bool isHovered: itemMouse.containsMouse
          readonly property bool isSelected: index === root.selectedIndex

          color: isSelected || isHovered ? Theme.surfaceHover : Theme.surface
          border.color: isSelected ? modelData.color : isHovered ? Theme.borderActive : Theme.border
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            Text {
              text: modelData.icon
              color: modelData.color
              font.family: Theme.font
              font.pixelSize: 16
            }

            Text {
              text: modelData.label
              color: isSelected || isHovered ? Theme.fg : Theme.fgMuted
              font.family: Theme.font
              font.pixelSize: 12
              font.bold: isSelected || isHovered
              Layout.fillWidth: true
            }
          }

          MouseArea {
            id: itemMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.selectedIndex = index
            onClicked: root.execute(modelData)
          }
        }
      }
    }
  }

  Process {
    id: execProc
  }
}

