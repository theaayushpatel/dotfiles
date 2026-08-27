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
  property bool powered: false
  property bool scanning: false
  property var devices: []
  property string notice: ""

  visible: opened
  implicitWidth: 420
  implicitHeight: Math.min(panel.implicitHeight + 36, 640)
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "dotfiles-bluetooth-panel"
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

  function shellQuote(value) {
    return "'" + String(value || "").replace(/'/g, "'\\''") + "'"
  }

  function refresh() {
    powerProc.running = false
    powerProc.running = true
    devicesProc.running = false
    devicesProc.running = true
  }

  function runAction(command, message) {
    notice = message
    actionProc.running = false
    actionProc.command = ["bash", "-lc", command]
    actionProc.running = true
  }

  function togglePower() {
    var nextState = !powered
    powered = nextState
    runAction("bluetoothctl power " + (nextState ? "on" : "off"), nextState ? "Turning on..." : "Turning off...")
  }

  function toggleScan() {
    if (scanning) {
      scanning = false
      runAction("bluetoothctl scan off", "Stopping scan...")
    } else {
      scanning = true
      notice = "Scanning for devices..."
      scanProc.running = false
      scanProc.command = ["bash", "-lc", "bluetoothctl --timeout 10 scan on"]
      scanProc.running = true
    }
  }

  function deviceAction(device) {
    if (!device || !device.address) return
    if (device.connected) {
      runAction("bluetoothctl disconnect " + shellQuote(device.address), "Disconnecting " + device.name + "...")
    } else if (device.paired) {
      runAction("bluetoothctl connect " + shellQuote(device.address), "Connecting " + device.name + "...")
    } else {
      runAction("bluetoothctl pair " + shellQuote(device.address) + " && bluetoothctl connect " + shellQuote(device.address), "Pairing " + device.name + "...")
    }
  }

  function forget(device) {
    if (!device || !device.address) return
    runAction("bluetoothctl remove " + shellQuote(device.address), "Removing " + device.name + "...")
  }

  function closePanel() {
    opened = false
    notice = ""
    if (scanning) {
      scanning = false
      scanProc.running = false
    }
  }

  IpcHandler {
    target: "bluetooth"
    function toggle() { root.opened = !root.opened; if (root.opened) root.refresh() }
    function open() { root.opened = true; root.refresh() }
    function close() { root.closePanel() }
  }

  Item {
    anchors.fill: parent
    focus: root.opened
    Keys.onEscapePressed: root.closePanel()
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_R) root.refresh()
      if (event.key === Qt.Key_B) root.togglePower()
    }

    Rectangle {
      anchors.fill: parent
      color: Theme.panelBg
      radius: Theme.radius
      border.color: Theme.border
      border.width: 1
    }

    Flickable {
      anchors.fill: parent
      anchors.margins: 16
      contentWidth: width
      contentHeight: panel.implicitHeight
      clip: true

      Column {
        id: panel
        width: parent.width
        spacing: 14

        // Hero Header
        RowLayout {
          width: parent.width
          spacing: 14

          Text {
            text: root.powered ? (root.devices.some(function(d) { return d.connected }) ? "󰂱" : "󰂯") : "󰂲"
            color: !root.powered ? Theme.fgMuted : root.devices.some(function(d) { return d.connected }) ? Theme.accent : Theme.fg
            font.family: Theme.font
            font.pixelSize: 28
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
              text: "Bluetooth"
              color: Theme.fg
              font.family: Theme.font
              font.pixelSize: 18
              font.bold: true
            }

            Text {
              text: root.notice || (root.powered ? (root.scanning ? "SCANNING..." : "ENABLED") : "DISABLED")
              color: root.notice ? Theme.accent : root.powered ? Theme.fgMuted : Theme.critical
              font.family: Theme.font
              font.pixelSize: 11
              font.bold: true
            }
          }

          StyledSwitch {
            checked: root.powered
            onToggled: function(val) { root.togglePower() }
          }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        // Section Title & Scan Button
        RowLayout {
          width: parent.width

          Text {
            text: "󰂯  DEVICES"
            color: Theme.fgMuted
            font.family: Theme.font
            font.pixelSize: 11
            font.bold: true
            Layout.fillWidth: true
          }

          Rectangle {
            visible: root.powered
            width: scanRow.implicitWidth + 14
            height: 24
            radius: 12
            color: root.scanning ? Theme.surfaceActive : scanBtnMouse.containsMouse ? Theme.surfaceHover : Theme.surface
            border.color: root.scanning ? Theme.accent : Theme.border
            border.width: 1

            RowLayout {
              id: scanRow
              anchors.centerIn: parent
              spacing: 4

              Text {
                text: root.scanning ? "󰑐" : "󰐲"
                color: root.scanning ? Theme.accent : Theme.fgMuted
                font.family: Theme.font
                font.pixelSize: 11
              }

              Text {
                text: root.scanning ? "Stop" : "Scan"
                color: root.scanning ? Theme.accent : Theme.fg
                font.family: Theme.font
                font.pixelSize: 11
              }
            }

            MouseArea {
              id: scanBtnMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleScan()
            }
          }
        }

        // Empty state
        Text {
          visible: root.devices.length === 0
          text: root.powered ? (root.scanning ? "Searching for nearby devices..." : "No devices found. Click Scan to discover.") : "Turn Bluetooth on to discover devices"
          color: Theme.fgMuted
          font.family: Theme.font
          font.pixelSize: 12
        }

        // Devices List
        Repeater {
          model: root.devices
          delegate: Rectangle {
            id: deviceCard
            required property var modelData
            width: panel.width
            height: 52
            radius: Theme.cardRadius
            color: modelData.connected ? Theme.surfaceActive : cardMouse.containsMouse ? Theme.surfaceHover : Theme.surface
            border.color: modelData.connected ? Theme.accent : Theme.border
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 12
              anchors.rightMargin: 12
              spacing: 10

              Text {
                text: modelData.connected ? "󰂱" : "󰂯"
                color: modelData.connected ? Theme.accent : Theme.fgMuted
                font.family: Theme.font
                font.pixelSize: 18
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                  text: modelData.name || modelData.address
                  color: modelData.connected ? Theme.fg : Theme.fg
                  font.family: Theme.font
                  font.pixelSize: 12
                  font.bold: modelData.connected
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                RowLayout {
                  spacing: 6
                  Text {
                    text: modelData.connected ? "Connected" : modelData.paired ? "Paired" : "Available"
                    color: modelData.connected ? Theme.accent : Theme.fgMuted
                    font.family: Theme.font
                    font.pixelSize: 10
                  }
                  Text {
                    visible: modelData.connected
                    text: "󰄬"
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: 10
                  }
                }
              }

              // Forget / Unpair button
              Rectangle {
                visible: modelData.paired
                width: 24
                height: 24
                radius: 12
                color: forgetMouse.containsMouse ? Theme.surfaceActive : "transparent"

                Text {
                  anchors.centerIn: parent
                  text: "󰅖"
                  color: forgetMouse.containsMouse ? Theme.critical : Theme.fgMuted
                  font.family: Theme.font
                  font.pixelSize: 12
                }

                MouseArea {
                  id: forgetMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.forget(modelData)
                }
              }
            }

            MouseArea {
              id: cardMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              z: -1
              onClicked: root.deviceAction(modelData)
            }
          }
        }
      }
    }
  }

  Process {
    id: powerProc
    command: ["bash", "-lc", "bluetoothctl show | awk -F': ' '/Powered/ {print tolower($2)}'"]
    stdout: StdioCollector {
      id: powerCollector
      waitForEnd: true
      onStreamFinished: function() {
        root.powered = powerCollector.text.trim() === "yes"
      }
    }
  }

  Process {
    id: devicesProc
    command: ["bash", "-lc", "bluetoothctl devices | while read -r _ addr name; do [ -z \"$addr\" ] && continue; info=$(bluetoothctl info \"$addr\" 2>/dev/null); paired=$(echo \"$info\" | awk -F': ' '/Paired/ {print tolower($2)}'); conn=$(echo \"$info\" | awk -F': ' '/Connected/ {print tolower($2)}'); printf '%s\\t%s\\t%s\\t%s\\n' \"$addr\" \"$paired\" \"$conn\" \"$name\"; done"]
    stdout: StdioCollector {
      id: devicesCollector
      waitForEnd: true
      onStreamFinished: function() {
        var result = []
        String(devicesCollector.text).trim().split("\n").forEach(function(line) {
          var p = line.split("\t")
          if (p.length >= 4 && p[0]) {
            result.push({
              address: p[0],
              paired: p[1] === "yes",
              connected: p[2] === "yes",
              name: p.slice(3).join(" ")
            })
          }
        })
        result.sort(function(a, b) {
          if (a.connected !== b.connected) return a.connected ? -1 : 1
          if (a.paired !== b.paired) return a.paired ? -1 : 1
          return (a.name || "").localeCompare(b.name || "")
        })
        root.devices = result
      }
    }
  }

  Process {
    id: scanProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function() {
      root.scanning = false
      root.notice = ""
      root.refresh()
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function() {
      root.notice = ""
      root.refresh()
    }
  }

  Timer {
    interval: 3000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: root.refresh()
}
