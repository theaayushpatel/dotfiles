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
  property int brightnessValue: 50
  property string deviceName: "amdgpu_bl1"
  property int currentRaw: 0
  property int maxRaw: 65535
  property string notice: ""

  readonly property string brightnessIcon: {
    if (brightnessValue >= 80) return "󰃠"
    if (brightnessValue >= 60) return "󰃟"
    if (brightnessValue >= 40) return "󰃞"
    if (brightnessValue >= 20) return "󰃝"
    return "󰃜"
  }

  readonly property var presets: [
    { label: "25%", value: 25, desc: "Low" },
    { label: "50%", value: 50, desc: "Medium" },
    { label: "75%", value: 75, desc: "High" },
    { label: "100%", value: 100, desc: "Max" }
  ]

  visible: opened
  implicitWidth: 360
  implicitHeight: Math.min(contentCol.implicitHeight + 28, 500)
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "dotfiles-brightness-panel"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

  anchors.top: true
  anchors.right: true
  margins.top: 40
  margins.right: 12

  HyprlandFocusGrab {
    windows: [ root ]
    active: root.opened
    onCleared: root.closePanel()
  }

  function closePanel() {
    opened = false
    notice = ""
  }

  function refresh() {
    readProc.running = false
    readProc.running = true
  }

  function setBrightness(percent) {
    var val = Math.max(1, Math.min(100, Math.round(percent)))
    brightnessValue = val
    setProc.command = ["bash", "-lc", "brightnessctl -d " + deviceName + " set " + val + "% || brightnessctl set " + val + "%"]
    setProc.running = false
    setProc.running = true
  }

  function adjustBrightness(delta) {
    setBrightness(brightnessValue + delta)
  }

  IpcHandler {
    target: "brightness"
    function toggle() { root.opened = !root.opened; if (root.opened) root.refresh() }
    function open() { root.opened = true; root.refresh() }
    function close() { root.closePanel() }
  }

  Item {
    anchors.fill: parent
    focus: root.opened

    Keys.onEscapePressed: root.closePanel()
    Keys.onLeftPressed: root.adjustBrightness(-5)
    Keys.onRightPressed: root.adjustBrightness(5)
    Keys.onDownPressed: root.adjustBrightness(-10)
    Keys.onUpPressed: root.adjustBrightness(10)
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_1) root.setBrightness(25)
      if (event.key === Qt.Key_2) root.setBrightness(50)
      if (event.key === Qt.Key_3) root.setBrightness(75)
      if (event.key === Qt.Key_4) root.setBrightness(100)
      if (event.key === Qt.Key_R) root.refresh()
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
      anchors.margins: 14
      spacing: 12

      // ==========================================
      // 1. HERO HEADER: Brightness Status
      // ==========================================
      Rectangle {
        width: parent.width
        implicitHeight: headerRow.implicitHeight + 20
        radius: Theme.cardRadius
        color: Theme.surface
        border.color: Theme.border
        border.width: 1

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: 12
          spacing: 12

          // Big Brightness Icon
          Text {
            text: root.brightnessIcon
            color: Theme.accent
            font.family: Theme.font
            font.pixelSize: 28
          }

          // Value & Device Title
          Column {
            Layout.fillWidth: true
            spacing: 2

            Row {
              spacing: 6
              Text {
                text: root.brightnessValue + "%"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: 20
                font.bold: true
              }
              Text {
                text: "Brightness"
                color: Theme.fgMuted
                font.family: Theme.font
                font.pixelSize: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
              }
            }

            Text {
              text: "Display • " + root.deviceName
              color: Theme.fgSubtle
              font.family: Theme.font
              font.pixelSize: 10
            }
          }

          // Step Adjust Buttons (-5% / +5%)
          Row {
            spacing: 4

            Rectangle {
              width: 28
              height: 28
              radius: Theme.cardRadius
              color: minusMouse.containsMouse ? Theme.surfaceActive : Theme.surfaceHover
              border.color: Theme.border
              border.width: 1

              Text {
                anchors.centerIn: parent
                text: "󰍴"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: 12
              }

              MouseArea {
                id: minusMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.adjustBrightness(-5)
              }
            }

            Rectangle {
              width: 28
              height: 28
              radius: Theme.cardRadius
              color: plusMouse.containsMouse ? Theme.surfaceActive : Theme.surfaceHover
              border.color: Theme.border
              border.width: 1

              Text {
                anchors.centerIn: parent
                text: "󰐕"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: 12
              }

              MouseArea {
                id: plusMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.adjustBrightness(5)
              }
            }
          }
        }
      }

      // ==========================================
      // 2. SLIDER CARD
      // ==========================================
      Rectangle {
        width: parent.width
        implicitHeight: sliderCol.implicitHeight + 20
        radius: Theme.cardRadius
        color: Theme.surface
        border.color: Theme.border
        border.width: 1

        Column {
          id: sliderCol
          anchors.fill: parent
          anchors.margins: 12
          spacing: 8

          RowLayout {
            width: parent.width
            Text {
              text: "Level"
              color: Theme.fgMuted
              font.family: Theme.font
              font.pixelSize: 11
              font.bold: true
              Layout.fillWidth: true
            }
            Text {
              text: root.brightnessValue + "%"
              color: Theme.accent
              font.family: Theme.font
              font.pixelSize: 11
              font.bold: true
            }
          }

          StyledSlider {
            width: parent.width
            from: 1
            to: 100
            stepSize: 1
            value: root.brightnessValue
            onMoved: function(val) {
              root.setBrightness(val)
            }
          }
        }
      }

      // ==========================================
      // 3. QUICK PRESET BUTTONS
      // ==========================================
      RowLayout {
        width: parent.width
        spacing: 6

        Repeater {
          model: root.presets
          delegate: Rectangle {
            id: presetItem
            required property var modelData
            required property int index

            readonly property bool isSelected: Math.abs(root.brightnessValue - modelData.value) <= 2
            readonly property bool isHovered: presetMouse.containsMouse

            Layout.fillWidth: true
            height: 38
            radius: Theme.cardRadius
            color: isSelected ? Theme.surfaceActive : isHovered ? Theme.surfaceHover : Theme.surface
            border.color: isSelected ? Theme.borderActive : isHovered ? Theme.borderActive : Theme.border
            border.width: 1

            Column {
              anchors.centerIn: parent
              spacing: 1

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData.label
                color: isSelected ? Theme.accent : isHovered ? Theme.fg : Theme.fgMuted
                font.family: Theme.font
                font.pixelSize: 11
                font.bold: isSelected
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData.desc
                color: isSelected ? Theme.fg : Theme.fgSubtle
                font.family: Theme.font
                font.pixelSize: 9
              }
            }

            MouseArea {
              id: presetMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.setBrightness(modelData.value)
            }
          }
        }
      }

      // ==========================================
      // 4. QUICK MODES: Dim (1%) & Max (100%)
      // ==========================================
      RowLayout {
        width: parent.width
        spacing: 6

        // Dim Mode (1%)
        Rectangle {
          Layout.fillWidth: true
          height: 34
          radius: Theme.cardRadius
          color: dimMouse.containsMouse ? Theme.surfaceHover : Theme.surface
          border.color: root.brightnessValue <= 2 ? Theme.borderActive : Theme.border
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 6

            Text {
              text: "󰌶"
              color: root.brightnessValue <= 2 ? Theme.accent : Theme.fgMuted
              font.family: Theme.font
              font.pixelSize: 13
            }

            Text {
              text: "Dim Mode (1%)"
              color: root.brightnessValue <= 2 ? Theme.fg : Theme.fgMuted
              font.family: Theme.font
              font.pixelSize: 10
              font.bold: root.brightnessValue <= 2
              Layout.fillWidth: true
            }
          }

          MouseArea {
            id: dimMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setBrightness(1)
          }
        }

        // Max Boost (100%)
        Rectangle {
          Layout.fillWidth: true
          height: 34
          radius: Theme.cardRadius
          color: maxMouse.containsMouse ? Theme.surfaceHover : Theme.surface
          border.color: root.brightnessValue === 100 ? Theme.borderActive : Theme.border
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 6

            Text {
              text: "󰃠"
              color: root.brightnessValue === 100 ? Theme.accent : Theme.fgMuted
              font.family: Theme.font
              font.pixelSize: 13
            }

            Text {
              text: "Max Boost (100%)"
              color: root.brightnessValue === 100 ? Theme.fg : Theme.fgMuted
              font.family: Theme.font
              font.pixelSize: 10
              font.bold: root.brightnessValue === 100
              Layout.fillWidth: true
            }
          }

          MouseArea {
            id: maxMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setBrightness(100)
          }
        }
      }
    }
  }

  // ==========================================
  // PROCESSES & TIMERS
  // ==========================================

  // Process to read current brightness
  Process {
    id: readProc
    command: ["bash", "-lc", "brightnessctl -d " + root.deviceName + " -m || brightnessctl -m"]
    stdout: StdioCollector {
      id: readCollector
      waitForEnd: true
      onStreamFinished: {
        var raw = String(readCollector.text || "").trim()
        if (raw) {
          var parts = raw.split("\n")[0].split(",")
          if (parts.length >= 5) {
            root.deviceName = parts[0]
            root.currentRaw = parseInt(parts[2], 10) || 0
            var pctStr = parts[3].replace("%", "").trim()
            root.brightnessValue = parseInt(pctStr, 10) || 0
            root.maxRaw = parseInt(parts[4], 10) || 65535
          }
        }
      }
    }
  }

  // Process to set brightness
  Process {
    id: setProc
  }

  // Periodic poll while open
  Timer {
    interval: 2000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: {
    root.refresh()
  }
}

