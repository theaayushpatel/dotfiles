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
  property int activeTab: 0 // 0 = Controls, 1 = Devices, 2 = Media

  // Output State
  property string defaultSink: ""
  property string activeSinkName: "Default Output"
  property int outputVolume: 50
  property bool outputMuted: false
  property var sinks: []

  // Input State
  property string defaultSource: ""
  property string activeSourceName: "Default Microphone"
  property int inputVolume: 100
  property bool inputMuted: false
  property var sources: []

  // MPRIS Media State
  property string mprisTitle: ""
  property string mprisArtist: ""
  property string mprisStatus: ""
  property string mprisPlayer: ""
  property bool mprisAvailable: mprisTitle !== ""

  readonly property string outputIcon: {
    if (outputMuted || outputVolume === 0) return "󰝟"
    if (outputVolume >= 70) return "󰕾"
    if (outputVolume >= 30) return "󰖀"
    return "󰕿"
  }

  readonly property string inputIcon: {
    if (inputMuted || inputVolume === 0) return "󰍭"
    return "󰍬"
  }

  function getDeviceIcon(name) {
    var n = (name || "").toLowerCase()
    if (n.indexOf("bluez") >= 0) return "󰂯"
    if (n.indexOf("headphone") >= 0 || n.indexOf("headset") >= 0) return "󰋋"
    if (n.indexOf("hdmi") >= 0 || n.indexOf("displayport") >= 0) return "󰍹"
    if (n.indexOf("mic") >= 0) return "󰍬"
    return "󰓃"
  }

  visible: opened
  implicitWidth: 420
  implicitHeight: Math.min(scrollContent.implicitHeight + 28, 680)
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "dotfiles-audio-panel"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

  // Placed directly below the pulseaudio modules on the right side of Waybar
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
  }

  function refresh() {
    readProc.running = false
    readProc.running = true
  }

  function setOutputVolume(percent) {
    var val = Math.max(0, Math.min(100, Math.round(percent)))
    outputVolume = val
    if (outputMuted && val > 0) outputMuted = false
    runAction("pactl set-sink-volume @DEFAULT_SINK@ " + val + "%")
  }

  function toggleOutputMute() {
    outputMuted = !outputMuted
    runAction("pactl set-sink-mute @DEFAULT_SINK@ toggle")
  }

  function setInputVolume(percent) {
    var val = Math.max(0, Math.min(100, Math.round(percent)))
    inputVolume = val
    if (inputMuted && val > 0) inputMuted = false
    runAction("pactl set-source-volume @DEFAULT_SOURCE@ " + val + "%")
  }

  function toggleInputMute() {
    inputMuted = !inputMuted
    runAction("pactl set-source-mute @DEFAULT_SOURCE@ toggle")
  }

  function selectSink(name) {
    defaultSink = name
    var q = shellQuote(name)
    runAction("pactl set-default-sink " + q + " && pactl list short sink-inputs 2>/dev/null | while read -r id _; do [ -n \"$id\" ] && pactl move-sink-input \"$id\" " + q + " 2>/dev/null || true; done")
  }

  function selectSource(name) {
    defaultSource = name
    var q = shellQuote(name)
    runAction("pactl set-default-source " + q + " && pactl list short source-outputs 2>/dev/null | while read -r id _; do [ -n \"$id\" ] && pactl move-source-output \"$id\" " + q + " 2>/dev/null || true; done")
  }

  function mediaControl(action) {
    runAction("playerctl " + action)
  }

  function shellQuote(val) {
    return "'" + String(val || "").replace(/'/g, "'\\''") + "'"
  }

  function runAction(cmd) {
    actionProc.command = ["bash", "-lc", cmd]
    actionProc.running = false
    actionProc.running = true
  }

  IpcHandler {
    target: "audio"
    function toggle() { root.opened = !root.opened; if (root.opened) root.refresh() }
    function open() { root.opened = true; root.refresh() }
    function close() { root.closePanel() }
  }

  Item {
    anchors.fill: parent
    focus: root.opened

    Keys.onEscapePressed: root.closePanel()
    Keys.onLeftPressed: root.setOutputVolume(root.outputVolume - 5)
    Keys.onRightPressed: root.setOutputVolume(root.outputVolume + 5)
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_1) root.activeTab = 0
      if (event.key === Qt.Key_2) root.activeTab = 1
      if (event.key === Qt.Key_3) root.activeTab = 2
      if (event.key === Qt.Key_M) root.toggleOutputMute()
      if (event.key === Qt.Key_N) root.toggleInputMute()
      if (event.key === Qt.Key_R) root.refresh()
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
      anchors.margins: 14
      contentWidth: width
      contentHeight: scrollContent.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: scrollContent
        width: parent.width
        spacing: 12

        // ==========================================
        // 1. TAB SWITCHER: [ Controls | Devices | Media ]
        // ==========================================
        Rectangle {
          width: parent.width
          height: 32
          radius: Theme.cardRadius
          color: Theme.surface
          border.color: Theme.border
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.margins: 3
            spacing: 4

            // Tab 1: Controls
            Rectangle {
              Layout.fillWidth: true
              Layout.fillHeight: true
              radius: Theme.cardRadius - 2
              color: root.activeTab === 0 ? Theme.surfaceHover : "transparent"
              border.color: root.activeTab === 0 ? Theme.borderActive : "transparent"
              border.width: 1

              Row {
                anchors.centerIn: parent
                spacing: 6
                Text { text: "󰕾"; color: root.activeTab === 0 ? Theme.accent : Theme.fgMuted; font.family: Theme.font; font.pixelSize: 12 }
                Text { text: "Controls"; color: root.activeTab === 0 ? Theme.fg : Theme.fgMuted; font.family: Theme.font; font.pixelSize: 11; font.bold: root.activeTab === 0 }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activeTab = 0
              }
            }

            // Tab 2: Devices
            Rectangle {
              Layout.fillWidth: true
              Layout.fillHeight: true
              radius: Theme.cardRadius - 2
              color: root.activeTab === 1 ? Theme.surfaceHover : "transparent"
              border.color: root.activeTab === 1 ? Theme.borderActive : "transparent"
              border.width: 1

              Row {
                anchors.centerIn: parent
                spacing: 6
                Text { text: "󰓃"; color: root.activeTab === 1 ? Theme.accent : Theme.fgMuted; font.family: Theme.font; font.pixelSize: 12 }
                Text { text: "Devices (" + (root.sinks.length + root.sources.length) + ")"; color: root.activeTab === 1 ? Theme.fg : Theme.fgMuted; font.family: Theme.font; font.pixelSize: 11; font.bold: root.activeTab === 1 }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activeTab = 1
              }
            }

            // Tab 3: Media (if available)
            Rectangle {
              visible: root.mprisAvailable
              Layout.fillWidth: true
              Layout.fillHeight: true
              radius: Theme.cardRadius - 2
              color: root.activeTab === 2 ? Theme.surfaceHover : "transparent"
              border.color: root.activeTab === 2 ? Theme.borderActive : "transparent"
              border.width: 1

              Row {
                anchors.centerIn: parent
                spacing: 6
                Text { text: "󰝚"; color: root.activeTab === 2 ? Theme.accent : Theme.fgMuted; font.family: Theme.font; font.pixelSize: 12 }
                Text { text: "Media"; color: root.activeTab === 2 ? Theme.fg : Theme.fgMuted; font.family: Theme.font; font.pixelSize: 11; font.bold: root.activeTab === 2 }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activeTab = 2
              }
            }
          }
        }

        // ==========================================
        // 2. TAB 0: CONTROLS (VOLUME & MIC SLIDERS)
        // ==========================================
        Column {
          width: parent.width
          spacing: 12
          visible: root.activeTab === 0

          // Output Volume Card
          Rectangle {
            width: parent.width
            implicitHeight: outCardCol.implicitHeight + 20
            radius: Theme.cardRadius
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            Column {
              id: outCardCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: 12
              spacing: 10

              // Header Row
              RowLayout {
                width: parent.width
                spacing: 10

                Text {
                  text: root.outputIcon
                  color: root.outputMuted ? Theme.critical : Theme.accent
                  font.family: Theme.font
                  font.pixelSize: 24
                }

                Column {
                  Layout.fillWidth: true
                  spacing: 2

                  Row {
                    spacing: 6
                    Text {
                      text: root.outputMuted ? "Muted" : (root.outputVolume + "%")
                      color: root.outputMuted ? Theme.critical : Theme.fg
                      font.family: Theme.font
                      font.pixelSize: 16
                      font.bold: true
                    }
                    Text {
                      text: "Speaker Output"
                      color: Theme.fgMuted
                      font.family: Theme.font
                      font.pixelSize: 11
                      anchors.bottom: parent.bottom
                      anchors.bottomMargin: 1
                    }
                  }

                  // Clickable Device Switcher Badge
                  Row {
                    spacing: 4
                    Rectangle {
                      implicitWidth: devBadgeText.implicitWidth + 14
                      implicitHeight: 20
                      radius: 10
                      color: devBadgeMouse.containsMouse ? Theme.surfaceActive : Theme.surfaceHover
                      border.color: Theme.borderActive
                      border.width: 1

                      Row {
                        id: devBadgeText
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                          text: root.getDeviceIcon(root.defaultSink)
                          color: Theme.accent
                          font.family: Theme.font
                          font.pixelSize: 10
                        }
                        Text {
                          text: root.activeSinkName
                          color: Theme.fg
                          font.family: Theme.font
                          font.pixelSize: 10
                          font.bold: true
                          elide: Text.ElideRight
                          width: Math.min(implicitWidth, 180)
                        }
                        Text {
                          text: "⇄"
                          color: Theme.accent
                          font.family: Theme.font
                          font.pixelSize: 10
                          font.bold: true
                        }
                      }

                      MouseArea {
                        id: devBadgeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeTab = 1
                      }
                    }
                  }
                }

                // Mute Toggle Button
                Rectangle {
                  width: 32
                  height: 32
                  radius: Theme.cardRadius
                  color: root.outputMuted ? Theme.critical : outMuteBtnMouse.containsMouse ? Theme.surfaceActive : Theme.surfaceHover
                  border.color: root.outputMuted ? Theme.critical : Theme.border
                  border.width: 1

                  Text {
                    anchors.centerIn: parent
                    text: root.outputMuted ? "󰝟" : "󰕾"
                    color: root.outputMuted ? "#ffffff" : Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 14
                  }

                  MouseArea {
                    id: outMuteBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleOutputMute()
                  }
                }
              }

              // Output Volume Slider
              StyledSlider {
                width: parent.width
                from: 0
                to: 100
                stepSize: 1
                value: root.outputVolume
                onMoved: function(val) {
                  root.setOutputVolume(val)
                }
              }

              // Presets
              RowLayout {
                width: parent.width
                spacing: 6

                Repeater {
                  model: [
                    { label: "-5%", action: function() { root.setOutputVolume(root.outputVolume - 5) } },
                    { label: "25%", action: function() { root.setOutputVolume(25) } },
                    { label: "50%", action: function() { root.setOutputVolume(50) } },
                    { label: "75%", action: function() { root.setOutputVolume(75) } },
                    { label: "100%", action: function() { root.setOutputVolume(100) } },
                    { label: "+5%", action: function() { root.setOutputVolume(root.outputVolume + 5) } }
                  ]
                  delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    height: 26
                    radius: Theme.cardRadius
                    color: preMouse.containsMouse ? Theme.surfaceActive : Theme.surfaceHover
                    border.color: Theme.border
                    border.width: 1

                    Text {
                      anchors.centerIn: parent
                      text: modelData.label
                      color: Theme.fgMuted
                      font.family: Theme.font
                      font.pixelSize: 10
                      font.bold: true
                    }

                    MouseArea {
                      id: preMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: modelData.action()
                    }
                  }
                }
              }
            }
          }

          // Input (Microphone) Card
          Rectangle {
            width: parent.width
            implicitHeight: inCardCol.implicitHeight + 20
            radius: Theme.cardRadius
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            Column {
              id: inCardCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: 12
              spacing: 10

              // Header Row
              RowLayout {
                width: parent.width
                spacing: 10

                Text {
                  text: root.inputIcon
                  color: root.inputMuted ? Theme.critical : Theme.accent
                  font.family: Theme.font
                  font.pixelSize: 24
                }

                Column {
                  Layout.fillWidth: true
                  spacing: 2

                  Row {
                    spacing: 6
                    Text {
                      text: root.inputMuted ? "Muted" : (root.inputVolume + "%")
                      color: root.inputMuted ? Theme.critical : Theme.fg
                      font.family: Theme.font
                      font.pixelSize: 16
                      font.bold: true
                    }
                    Text {
                      text: "Microphone Input"
                      color: Theme.fgMuted
                      font.family: Theme.font
                      font.pixelSize: 11
                      anchors.bottom: parent.bottom
                      anchors.bottomMargin: 1
                    }
                  }

                  // Clickable Device Switcher Badge
                  Row {
                    spacing: 4
                    Rectangle {
                      implicitWidth: inDevBadgeText.implicitWidth + 14
                      implicitHeight: 20
                      radius: 10
                      color: inDevBadgeMouse.containsMouse ? Theme.surfaceActive : Theme.surfaceHover
                      border.color: Theme.borderActive
                      border.width: 1

                      Row {
                        id: inDevBadgeText
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                          text: root.getDeviceIcon(root.defaultSource)
                          color: Theme.accent
                          font.family: Theme.font
                          font.pixelSize: 10
                        }
                        Text {
                          text: root.activeSourceName
                          color: Theme.fg
                          font.family: Theme.font
                          font.pixelSize: 10
                          font.bold: true
                          elide: Text.ElideRight
                          width: Math.min(implicitWidth, 180)
                        }
                        Text {
                          text: "⇄"
                          color: Theme.accent
                          font.family: Theme.font
                          font.pixelSize: 10
                          font.bold: true
                        }
                      }

                      MouseArea {
                        id: inDevBadgeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeTab = 1
                      }
                    }
                  }
                }

                // Mic Mute Toggle Button
                Rectangle {
                  width: 32
                  height: 32
                  radius: Theme.cardRadius
                  color: root.inputMuted ? Theme.critical : inMuteBtnMouse.containsMouse ? Theme.surfaceActive : Theme.surfaceHover
                  border.color: root.inputMuted ? Theme.critical : Theme.border
                  border.width: 1

                  Text {
                    anchors.centerIn: parent
                    text: root.inputMuted ? "󰍭" : "󰍬"
                    color: root.inputMuted ? "#ffffff" : Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 14
                  }

                  MouseArea {
                    id: inMuteBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleInputMute()
                  }
                }
              }

              // Mic Volume Slider
              StyledSlider {
                width: parent.width
                from: 0
                to: 100
                stepSize: 1
                value: root.inputVolume
                onMoved: function(val) {
                  root.setInputVolume(val)
                }
              }

              // Presets
              RowLayout {
                width: parent.width
                spacing: 6

                Repeater {
                  model: [
                    { label: "-5%", action: function() { root.setInputVolume(root.inputVolume - 5) } },
                    { label: "50%", action: function() { root.setInputVolume(50) } },
                    { label: "75%", action: function() { root.setInputVolume(75) } },
                    { label: "100%", action: function() { root.setInputVolume(100) } },
                    { label: "+5%", action: function() { root.setInputVolume(root.inputVolume + 5) } }
                  ]
                  delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    height: 26
                    radius: Theme.cardRadius
                    color: inPreMouse.containsMouse ? Theme.surfaceActive : Theme.surfaceHover
                    border.color: Theme.border
                    border.width: 1

                    Text {
                      anchors.centerIn: parent
                      text: modelData.label
                      color: Theme.fgMuted
                      font.family: Theme.font
                      font.pixelSize: 10
                      font.bold: true
                    }

                    MouseArea {
                      id: inPreMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: modelData.action()
                    }
                  }
                }
              }
            }
          }
        }

        // ==========================================
        // 3. TAB 1: DEDICATED AUDIO DEVICES SWITCHER
        // ==========================================
        Column {
          width: parent.width
          spacing: 12
          visible: root.activeTab === 1

          // 3A. OUTPUT DEVICES LIST
          Rectangle {
            width: parent.width
            implicitHeight: outDevCol.implicitHeight + 20
            radius: Theme.cardRadius
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            Column {
              id: outDevCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: 12
              spacing: 8

              RowLayout {
                width: parent.width
                Text {
                  text: "󰕾 Output Devices (Playback)"
                  color: Theme.fg
                  font.family: Theme.font
                  font.pixelSize: 12
                  font.bold: true
                  Layout.fillWidth: true
                }
                Text {
                  text: root.sinks.length + " available"
                  color: Theme.fgMuted
                  font.family: Theme.font
                  font.pixelSize: 10
                }
              }

              Repeater {
                model: root.sinks
                delegate: Rectangle {
                  id: sinkCard
                  required property var modelData
                  readonly property bool isSelected: modelData.name === root.defaultSink
                  readonly property bool isHovered: sinkCardMouse.containsMouse

                  width: outDevCol.width
                  height: 48
                  radius: Theme.cardRadius
                  color: isSelected ? Theme.surfaceActive : isHovered ? Theme.surfaceHover : Theme.panelBg
                  border.color: isSelected ? Theme.borderActive : isHovered ? Theme.borderActive : Theme.border
                  border.width: 1

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    // Device Icon
                    Text {
                      text: root.getDeviceIcon(modelData.name)
                      color: isSelected ? Theme.accent : Theme.fgMuted
                      font.family: Theme.font
                      font.pixelSize: 18
                    }

                    // Device Name & Volume
                    Column {
                      Layout.fillWidth: true
                      spacing: 2

                      Text {
                        text: modelData.description || modelData.name
                        color: isSelected ? Theme.fg : Theme.fgMuted
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.bold: isSelected
                        elide: Text.ElideRight
                        width: parent.width
                      }

                      Text {
                        text: modelData.name.indexOf("bluez") >= 0 ? "Bluetooth Audio" : "Built-in / ALSA"
                        color: Theme.fgSubtle
                        font.family: Theme.font
                        font.pixelSize: 10
                      }
                    }

                    // Active Checkmark Badge
                    Rectangle {
                      visible: isSelected
                      implicitWidth: 62
                      height: 22
                      radius: 11
                      color: Theme.accentDim
                      border.color: Theme.borderActive
                      border.width: 1

                      Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "󰄬"; color: Theme.accent; font.family: Theme.font; font.pixelSize: 10; font.bold: true }
                        Text { text: "Active"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 10; font.bold: true }
                      }
                    }
                  }

                  MouseArea {
                    id: sinkCardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectSink(modelData.name)
                  }
                }
              }
            }
          }

          // 3B. INPUT DEVICES LIST
          Rectangle {
            width: parent.width
            implicitHeight: inDevCol.implicitHeight + 20
            radius: Theme.cardRadius
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            Column {
              id: inDevCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: 12
              spacing: 8

              RowLayout {
                width: parent.width
                Text {
                  text: "󰍬 Input Devices (Microphones)"
                  color: Theme.fg
                  font.family: Theme.font
                  font.pixelSize: 12
                  font.bold: true
                  Layout.fillWidth: true
                }
                Text {
                  text: root.sources.length + " available"
                  color: Theme.fgMuted
                  font.family: Theme.font
                  font.pixelSize: 10
                }
              }

              Repeater {
                model: root.sources
                delegate: Rectangle {
                  id: sourceCard
                  required property var modelData
                  readonly property bool isSelected: modelData.name === root.defaultSource
                  readonly property bool isHovered: sourceCardMouse.containsMouse

                  width: inDevCol.width
                  height: 48
                  radius: Theme.cardRadius
                  color: isSelected ? Theme.surfaceActive : isHovered ? Theme.surfaceHover : Theme.panelBg
                  border.color: isSelected ? Theme.borderActive : isHovered ? Theme.borderActive : Theme.border
                  border.width: 1

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    // Mic Icon
                    Text {
                      text: root.getDeviceIcon(modelData.name)
                      color: isSelected ? Theme.accent : Theme.fgMuted
                      font.family: Theme.font
                      font.pixelSize: 18
                    }

                    // Source Name
                    Column {
                      Layout.fillWidth: true
                      spacing: 2

                      Text {
                        text: modelData.description || modelData.name
                        color: isSelected ? Theme.fg : Theme.fgMuted
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.bold: isSelected
                        elide: Text.ElideRight
                        width: parent.width
                      }

                      Text {
                        text: modelData.name.indexOf("bluez") >= 0 ? "Bluetooth Headset Mic" : "Internal / Hardware Mic"
                        color: Theme.fgSubtle
                        font.family: Theme.font
                        font.pixelSize: 10
                      }
                    }

                    // Active Checkmark Badge
                    Rectangle {
                      visible: isSelected
                      implicitWidth: 62
                      height: 22
                      radius: 11
                      color: Theme.accentDim
                      border.color: Theme.borderActive
                      border.width: 1

                      Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { text: "󰄬"; color: Theme.accent; font.family: Theme.font; font.pixelSize: 10; font.bold: true }
                        Text { text: "Active"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 10; font.bold: true }
                      }
                    }
                  }

                  MouseArea {
                    id: sourceCardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectSource(modelData.name)
                  }
                }
              }
            }
          }
        }

        // ==========================================
        // 4. TAB 2: MEDIA PLAYBACK (MPRIS)
        // ==========================================
        Column {
          width: parent.width
          spacing: 12
          visible: root.activeTab === 2

          Rectangle {
            width: parent.width
            implicitHeight: mprisTabCol.implicitHeight + 20
            radius: Theme.cardRadius
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            ColumnLayout {
              id: mprisTabCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: 12
              spacing: 8

              RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text { text: "󰝚"; color: Theme.accent; font.family: Theme.font; font.pixelSize: 16 }

                Column {
                  Layout.fillWidth: true
                  spacing: 1

                  Text {
                    text: root.mprisTitle
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width
                  }

                  Text {
                    text: root.mprisArtist ? (root.mprisArtist + " • " + root.mprisPlayer) : root.mprisPlayer
                    color: Theme.fgMuted
                    font.family: Theme.font
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    width: parent.width
                  }
                }

                Row {
                  spacing: 4

                  Rectangle {
                    width: 28
                    height: 28
                    radius: Theme.cardRadius
                    color: pPrevMouse.containsMouse ? Theme.surfaceActive : Theme.surfaceHover
                    border.color: Theme.border
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "󰒮"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 12 }
                    MouseArea { id: pPrevMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.mediaControl("previous") }
                  }

                  Rectangle {
                    width: 28
                    height: 28
                    radius: Theme.cardRadius
                    color: pPlayMouse.containsMouse ? Theme.surfaceActive : Theme.surfaceHover
                    border.color: Theme.borderActive
                    border.width: 1
                    Text { anchors.centerIn: parent; text: root.mprisStatus.toLowerCase() === "playing" ? "󰏤" : "󰐊"; color: Theme.accent; font.family: Theme.font; font.pixelSize: 12 }
                    MouseArea { id: pPlayMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.mediaControl("play-pause") }
                  }

                  Rectangle {
                    width: 28
                    height: 28
                    radius: Theme.cardRadius
                    color: pNextMouse.containsMouse ? Theme.surfaceActive : Theme.surfaceHover
                    border.color: Theme.border
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "󰒭"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 12 }
                    MouseArea { id: pNextMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.mediaControl("next") }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  // ==========================================
  // PROCESSES & TIMERS
  // ==========================================

  // Process to read audio sinks, sources, and MPRIS
  Process {
    id: readProc
    command: [
      "bash", "-lc",
      "SINKS=$(pactl --format=json list sinks 2>/dev/null | jq '[.[] | {name: .name, description: (.description // .name), mute: .mute, volume: ((.volume[\"front-left\"].value_percent // .volume[\"mono\"].value_percent // \"0%\") | rtrimstr(\"%\") | tonumber)}]'); " +
      "SOURCES=$(pactl --format=json list sources 2>/dev/null | jq '[.[] | select(.name | endswith(\".monitor\") | not) | {name: .name, description: (.description // .name), mute: .mute, volume: ((.volume[\"front-left\"].value_percent // .volume[\"mono\"].value_percent // \"0%\") | rtrimstr(\"%\") | tonumber)}]'); " +
      "DEF_SINK=$(pactl get-default-sink 2>/dev/null); " +
      "DEF_SOURCE=$(pactl get-default-source 2>/dev/null); " +
      "MPRIS=$(playerctl metadata --format '{{title}}///{{artist}}///{{status}}///{{playerName}}' 2>/dev/null || echo ''); " +
      "jq -cn --arg defSink \"$DEF_SINK\" --arg defSource \"$DEF_SOURCE\" --argjson sinks \"${SINKS:-[]}\" --argjson sources \"${SOURCES:-[]}\" --arg mpris \"$MPRIS\" '{defaultSink: $defSink, defaultSource: $defSource, sinks: $sinks, sources: $sources, mpris: $mpris}'"
    ]
    stdout: StdioCollector {
      id: readCollector
      waitForEnd: true
      onStreamFinished: {
        var raw = String(readCollector.text || "").trim()
        if (!raw) return
        try {
          var data = JSON.parse(raw)

          root.defaultSink = data.defaultSink || ""
          root.defaultSource = data.defaultSource || ""
          root.sinks = data.sinks || []
          root.sources = data.sources || []

          // Find active sink
          var foundSink = false
          for (var i = 0; i < root.sinks.length; i++) {
            if (root.sinks[i].name === root.defaultSink) {
              root.activeSinkName = root.sinks[i].description || root.sinks[i].name
              root.outputVolume = root.sinks[i].volume || 0
              root.outputMuted = !!root.sinks[i].mute
              foundSink = true
              break
            }
          }
          if (!foundSink && root.sinks.length > 0) {
            root.activeSinkName = root.sinks[0].description || root.sinks[0].name
            root.outputVolume = root.sinks[0].volume || 0
            root.outputMuted = !!root.sinks[0].mute
          }

          // Find active source
          var foundSource = false
          for (var j = 0; j < root.sources.length; j++) {
            if (root.sources[j].name === root.defaultSource) {
              root.activeSourceName = root.sources[j].description || root.sources[j].name
              root.inputVolume = root.sources[j].volume || 0
              root.inputMuted = !!root.sources[j].mute
              foundSource = true
              break
            }
          }
          if (!foundSource && root.sources.length > 0) {
            root.activeSourceName = root.sources[0].description || root.sources[0].name
            root.inputVolume = root.sources[0].volume || 0
            root.inputMuted = !!root.sources[0].mute
          }

          // MPRIS parsing
          if (data.mpris && data.mpris.indexOf("///") >= 0) {
            var mpParts = data.mpris.split("///")
            root.mprisTitle = mpParts[0] || ""
            root.mprisArtist = mpParts[1] || ""
            root.mprisStatus = mpParts[2] || ""
            root.mprisPlayer = mpParts[3] || ""
          } else {
            root.mprisTitle = ""
            root.mprisArtist = ""
            root.mprisStatus = ""
            root.mprisPlayer = ""
          }
        } catch (e) {}
      }
    }
  }

  // Process for running audio control actions
  Process {
    id: actionProc
    onExited: {
      root.refresh()
    }
  }

  // Periodic poll while panel is open
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
