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
  property string selectedPlayer: ""
  property var availablePlayers: []

  property string playerName: "Player"
  property string status: "Stopped"
  property string title: "No media playing"
  property string artist: ""
  property string album: ""
  property string artUrl: ""
  property real positionSec: 0
  property real lengthSec: 0
  property real volume: 1.0
  property string loopStatus: "None"
  property bool shuffle: false
  property bool isSeeking: false
  property real dragPosition: 0

  readonly property bool isPlaying: status.toLowerCase() === "playing"
  readonly property bool hasMedia: title !== "" && title !== "No media playing"

  readonly property string playerIcon: {
    var p = playerName.toLowerCase()
    if (p.indexOf("spotify") >= 0) return "󰓇"
    if (p.indexOf("youtube") >= 0) return "󰗃"
    if (p.indexOf("firefox") >= 0) return "󰈹"
    if (p.indexOf("brave") >= 0) return "󰖟"
    if (p.indexOf("chromium") >= 0 || p.indexOf("chrome") >= 0) return "󰊯"
    if (p.indexOf("vlc") >= 0) return "󰕼"
    if (p.indexOf("mpv") >= 0) return ""
    return "󰝚"
  }

  function formatTime(seconds) {
    if (isNaN(seconds) || seconds <= 0) return "00:00"
    var totalSec = Math.floor(seconds)
    var mins = Math.floor(totalSec / 60)
    var secs = totalSec % 60
    var h = Math.floor(mins / 60)
    if (h > 0) {
      mins = mins % 60
      return h + ":" + (mins < 10 ? "0" + mins : mins) + ":" + (secs < 10 ? "0" + secs : secs)
    }
    return (mins < 10 ? "0" + mins : mins) + ":" + (secs < 10 ? "0" + secs : secs)
  }

  visible: opened
  implicitWidth: 400
  implicitHeight: Math.min(contentCol.implicitHeight + 28, 540)
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "dotfiles-media-panel"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

  // Center horizontally beneath the waybar center mpris module
  anchors.top: true
  margins.top: 40

  HyprlandFocusGrab {
    windows: [ root ]
    active: root.opened
    onCleared: root.closePanel()
  }

  function closePanel() {
    opened = false
  }

  function refresh() {
    pollProc.running = false
    pollProc.running = true
  }

  function playerCmd(subcmd) {
    var pArg = selectedPlayer ? ("--player=" + selectedPlayer + " ") : ""
    runAction("playerctl " + pArg + subcmd)
  }

  function togglePlayPause() {
    playerCmd("play-pause")
  }

  function nextTrack() {
    playerCmd("next")
  }

  function prevTrack() {
    playerCmd("previous")
  }

  function toggleShuffle() {
    playerCmd("shuffle toggle")
  }

  function toggleLoop() {
    var nextLoop = "Playlist"
    if (loopStatus === "Playlist") nextLoop = "Track"
    else if (loopStatus === "Track") nextLoop = "None"
    else nextLoop = "Playlist"
    playerCmd("loop " + nextLoop)
  }

  function seekTo(sec) {
    var pArg = selectedPlayer ? ("--player=" + selectedPlayer + " ") : ""
    runAction("playerctl " + pArg + "position " + Math.round(sec))
    positionSec = sec
  }

  function setPlayerVolume(val) {
    volume = Math.max(0, Math.min(1.0, val))
    var pArg = selectedPlayer ? ("--player=" + selectedPlayer + " ") : ""
    runAction("playerctl " + pArg + "volume " + volume.toFixed(2))
  }

  function runAction(cmd) {
    actionProc.command = ["bash", "-lc", cmd]
    actionProc.running = false
    actionProc.running = true
  }

  IpcHandler {
    target: "media"
    function toggle() { root.opened = !root.opened; if (root.opened) root.refresh() }
    function open() { root.opened = true; root.refresh() }
    function close() { root.closePanel() }
  }

  Item {
    anchors.fill: parent
    focus: root.opened

    Keys.onEscapePressed: root.closePanel()
    Keys.onSpacePressed: root.togglePlayPause()
    Keys.onLeftPressed: root.prevTrack()
    Keys.onRightPressed: root.nextTrack()
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_S) root.toggleShuffle()
      if (event.key === Qt.Key_L) root.toggleLoop()
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
      // 1. PLAYER HEADER ROW (Player Badge & Switcher)
      // ==========================================
      RowLayout {
        width: parent.width
        spacing: 8

        // Player Name & Icon
        Row {
          spacing: 6
          Layout.alignment: Qt.AlignVCenter

          Text {
            text: root.playerIcon
            color: Theme.accent
            font.family: Theme.font
            font.pixelSize: 16
          }

          Text {
            text: root.playerName
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: 13
            font.bold: true
          }
        }

        Item { Layout.fillWidth: true }

        // Multiple Players Pills (if > 1 player)
        Row {
          spacing: 4
          visible: root.availablePlayers.length > 1

          Repeater {
            model: root.availablePlayers
            delegate: Rectangle {
              required property var modelData
              readonly property bool isSelected: (root.selectedPlayer === modelData) || (!root.selectedPlayer && modelData === root.availablePlayers[0])
              implicitWidth: pillText.implicitWidth + 12
              height: 22
              radius: 11
              color: isSelected ? Theme.surfaceActive : Theme.surfaceHover
              border.color: isSelected ? Theme.borderActive : Theme.border
              border.width: 1

              Text {
                id: pillText
                anchors.centerIn: parent
                text: modelData.split(".")[0]
                color: isSelected ? Theme.accent : Theme.fgMuted
                font.family: Theme.font
                font.pixelSize: 10
                font.bold: isSelected
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.selectedPlayer = modelData
                  root.refresh()
                }
              }
            }
          }
        }

        // Status Badge (Playing / Paused)
        Rectangle {
          implicitWidth: statusText.implicitWidth + 12
          height: 22
          radius: 11
          color: root.isPlaying ? Theme.accentDim : Theme.surfaceHover
          border.color: root.isPlaying ? Theme.borderActive : Theme.border
          border.width: 1

          Text {
            id: statusText
            anchors.centerIn: parent
            text: root.status
            color: root.isPlaying ? Theme.accent : Theme.fgMuted
            font.family: Theme.font
            font.pixelSize: 10
            font.bold: true
          }
        }
      }

      // ==========================================
      // 2. HERO TRACK CARD (Album Art + Metadata)
      // ==========================================
      Rectangle {
        width: parent.width
        implicitHeight: trackRow.implicitHeight + 20
        radius: Theme.cardRadius
        color: Theme.surface
        border.color: Theme.border
        border.width: 1

        RowLayout {
          id: trackRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: 12
          spacing: 12

          // Album Art Cover Container
          Rectangle {
            width: 72
            height: 72
            radius: Theme.cardRadius
            color: Theme.surfaceHover
            border.color: Theme.border
            border.width: 1
            clip: true

            Image {
              id: artImage
              anchors.fill: parent
              source: root.artUrl
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              visible: status === Image.Ready
            }

            Text {
              anchors.centerIn: parent
              visible: !artImage.visible
              text: root.isPlaying ? "󰝚" : "󰏤"
              color: Theme.accent
              font.family: Theme.font
              font.pixelSize: 28
            }
          }

          // Track Title & Artist Info
          Column {
            Layout.fillWidth: true
            spacing: 4

            Text {
              text: root.title
              color: Theme.fg
              font.family: Theme.font
              font.pixelSize: 14
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: root.artist ? root.artist : (root.hasMedia ? "Unknown Artist" : "")
              color: Theme.accent
              font.family: Theme.font
              font.pixelSize: 12
              elide: Text.ElideRight
              width: parent.width
              visible: text !== ""
            }

            Text {
              text: root.album
              color: Theme.fgMuted
              font.family: Theme.font
              font.pixelSize: 10
              elide: Text.ElideRight
              width: parent.width
              visible: root.album !== ""
            }
          }
        }
      }

      // ==========================================
      // 3. PROGRESS & SEEK BAR
      // ==========================================
      Rectangle {
        width: parent.width
        implicitHeight: progressCol.implicitHeight + 16
        radius: Theme.cardRadius
        color: Theme.surface
        border.color: Theme.border
        border.width: 1

        Column {
          id: progressCol
          anchors.fill: parent
          anchors.margins: 10
          spacing: 6

          // Seek Slider
          StyledSlider {
            width: parent.width
            from: 0
            to: Math.max(1, root.lengthSec)
            stepSize: 1
            value: root.isSeeking ? root.dragPosition : root.positionSec
            onMoved: function(val) {
              root.isSeeking = true
              root.dragPosition = val
              root.seekTo(val)
              seekReleaseTimer.restart()
            }
          }

          // Elapsed & Total Time Labels
          RowLayout {
            width: parent.width

            Text {
              text: root.formatTime(root.isSeeking ? root.dragPosition : root.positionSec)
              color: Theme.fg
              font.family: Theme.font
              font.pixelSize: 10
              font.bold: true
            }

            Item { Layout.fillWidth: true }

            Text {
              text: root.lengthSec > 0 ? root.formatTime(root.lengthSec) : "--:--"
              color: Theme.fgMuted
              font.family: Theme.font
              font.pixelSize: 10
            }
          }
        }
      }

      // ==========================================
      // 4. PLAYBACK CONTROLS ROW
      // ==========================================
      RowLayout {
        width: parent.width
        spacing: 12

        Item { Layout.fillWidth: true }

        // Shuffle Button
        Rectangle {
          width: 32
          height: 32
          radius: 16
          color: root.shuffle ? Theme.surfaceActive : shufMouse.containsMouse ? Theme.surfaceHover : Theme.surface
          border.color: root.shuffle ? Theme.borderActive : Theme.border
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "󰒞"
            color: root.shuffle ? Theme.accent : Theme.fgMuted
            font.family: Theme.font
            font.pixelSize: 14
          }

          MouseArea {
            id: shufMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleShuffle()
          }
        }

        // Previous Button
        Rectangle {
          width: 36
          height: 36
          radius: 18
          color: prevMouse.containsMouse ? Theme.surfaceActive : Theme.surface
          border.color: Theme.border
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "󰒮"
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: 16
          }

          MouseArea {
            id: prevMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.prevTrack()
          }
        }

        // Big Main Play/Pause Button
        Rectangle {
          width: 46
          height: 46
          radius: 23
          color: playMouse.containsMouse ? Theme.accentHover : Theme.accent
          border.color: Theme.borderActive
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: root.isPlaying ? "󰏤" : "󰐊"
            color: "#121218"
            font.family: Theme.font
            font.pixelSize: 20
            font.bold: true
          }

          MouseArea {
            id: playMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.togglePlayPause()
          }
        }

        // Next Button
        Rectangle {
          width: 36
          height: 36
          radius: 18
          color: nextMouse.containsMouse ? Theme.surfaceActive : Theme.surface
          border.color: Theme.border
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "󰒭"
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: 16
          }

          MouseArea {
            id: nextMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.nextTrack()
          }
        }

        // Loop Button
        Rectangle {
          width: 32
          height: 32
          radius: 16
          color: root.loopStatus !== "None" ? Theme.surfaceActive : loopMouse.containsMouse ? Theme.surfaceHover : Theme.surface
          border.color: root.loopStatus !== "None" ? Theme.borderActive : Theme.border
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: root.loopStatus === "Track" ? "󰑘" : "󰑖"
            color: root.loopStatus !== "None" ? Theme.accent : Theme.fgMuted
            font.family: Theme.font
            font.pixelSize: 14
          }

          MouseArea {
            id: loopMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleLoop()
          }
        }

        Item { Layout.fillWidth: true }
      }

      // ==========================================
      // 5. PLAYER VOLUME SLIDER CARD
      // ==========================================
      Rectangle {
        width: parent.width
        height: 36
        radius: Theme.cardRadius
        color: Theme.surface
        border.color: Theme.border
        border.width: 1

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 12
          anchors.rightMargin: 12
          spacing: 10

          Text {
            text: root.volume === 0 ? "󰝟" : root.volume < 0.5 ? "󰖀" : "󰕾"
            color: Theme.accent
            font.family: Theme.font
            font.pixelSize: 14
          }

          StyledSlider {
            Layout.fillWidth: true
            from: 0
            to: 1
            stepSize: 0.02
            value: root.volume
            onMoved: function(val) {
              root.setPlayerVolume(val)
            }
          }

          Text {
            text: Math.round(root.volume * 100) + "%"
            color: Theme.fgMuted
            font.family: Theme.font
            font.pixelSize: 10
            font.bold: true
          }
        }
      }
    }
  }

  // Timer to release seek lock after user interaction
  Timer {
    id: seekReleaseTimer
    interval: 800
    onTriggered: root.isSeeking = false
  }

  // Live Position Incrementor between polls when playing
  Timer {
    interval: 1000
    running: root.opened && root.isPlaying && !root.isSeeking
    repeat: true
    onTriggered: {
      if (root.positionSec < root.lengthSec || root.lengthSec <= 0) {
        root.positionSec += 1
      }
    }
  }

  // Periodic poll while open
  Timer {
    interval: 1500
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  // Process to query playerctl status and metadata
  Process {
    id: pollProc
    command: [
      "bash", "-lc",
      "PLAYERS=$(playerctl -l 2>/dev/null | tr '\\n' ' '); " +
      "TARGET='" + root.selectedPlayer + "'; " +
      "PARG=$([ -n \"$TARGET\" ] && echo \"--player=$TARGET\" || echo \"\"); " +
      "META=$(playerctl $PARG metadata --format '{\"player\":\"{{playerName}}\",\"status\":\"{{status}}\",\"title\":\"{{markup_escape(title)}}\",\"artist\":\"{{markup_escape(artist)}}\",\"album\":\"{{markup_escape(album)}}\",\"artUrl\":\"{{mpris:artUrl}}\",\"position\":{{position}},\"length\":{{mpris:length}},\"volume\":{{volume}},\"loop\":\"{{loop}}\",\"shuffle\":{{shuffle}}}' 2>/dev/null || echo '{}'); " +
      "jq -cn --arg players \"$PLAYERS\" --argjson meta \"$META\" '{players: ($players | split(\" \") | map(select(length > 0))), meta: $meta}'"
    ]
    stdout: StdioCollector {
      id: pollCollector
      waitForEnd: true
      onStreamFinished: {
        var raw = String(pollCollector.text || "").trim()
        if (!raw) return
        try {
          var data = JSON.parse(raw)
          root.availablePlayers = data.players || []

          var meta = data.meta || {}
          if (meta.player) {
            root.playerName = meta.player.charAt(0).toUpperCase() + meta.player.slice(1)
            root.status = meta.status || "Stopped"
            root.title = meta.title || "Unknown Title"
            root.artist = meta.artist || ""
            root.album = meta.album || ""
            root.artUrl = meta.artUrl || ""

            if (!root.isSeeking) {
              root.positionSec = (meta.position || 0) / 1000000.0
            }
            root.lengthSec = (meta.length || 0) / 1000000.0
            if (meta.volume !== undefined && meta.volume !== null) {
              root.volume = meta.volume
            }
            root.loopStatus = meta.loop || "None"
            root.shuffle = !!meta.shuffle
          } else {
            root.status = "Stopped"
            root.title = "No media playing"
            root.artist = ""
            root.album = ""
            root.artUrl = ""
            root.positionSec = 0
            root.lengthSec = 0
          }
        } catch (e) {}
      }
    }
  }

  // Action process for sending playback commands
  Process {
    id: actionProc
    onExited: {
      root.refresh()
    }
  }

  Component.onCompleted: {
    root.refresh()
  }
}

