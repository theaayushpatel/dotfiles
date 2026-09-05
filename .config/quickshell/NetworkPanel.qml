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
  property var details: ({})
  property var networks: []
  property var knownNetworks: []

  readonly property var orderedNetworks: {
    var known = []
    var other = []
    for (var i = 0; i < networks.length; i++) {
      if (knownNetworks.indexOf(networks[i].ssid) >= 0) known.push(networks[i])
      else other.push(networks[i])
    }
    return known.concat(other)
  }

  property int selectedIndex: -1
  property string password: ""
  property string qrText: ""
  property string qrPassword: ""
  property string qrImagePath: ""
  property string qrFilePath: ""
  property int qrVersion: 0
  property bool qrReady: false
  property string notice: ""
  property bool scanning: false
  property bool busy: false
  property bool qrOpen: false
  property real downloadRate: 0
  property real uploadRate: 0
  property real totalRx: 0
  property real totalTx: 0
  property real baselineRx: 0
  property real baselineTx: 0
  property string currentConPath: ""
  property real previousRx: 0
  property real previousTx: 0
  property double previousSampleTime: 0
  property bool passwordOpen: false
  property string passwordNetwork: ""
  property string passwordInput: ""

  readonly property bool wifiEnabled: {
    var state = String(details.wifiEnabled || "").toLowerCase()
    return state === "enabled" || state === "yes" || state === "on" || state === "true"
  }

  visible: opened
  implicitWidth: 420
  implicitHeight: Math.min(content.implicitHeight + 36, 720)
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "dotfiles-network-panel"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  property real targetCenterX: -1

  anchors.top: true
  anchors.left: true
  anchors.right: false
  margins.top: 44
  margins.left: {
    var screenW = (root.screen ? root.screen.width : 1920)
    var panelW = root.implicitWidth || 420
    var cx = targetCenterX >= 0 ? targetCenterX : (screenW / 2)
    var left = cx - (panelW / 2)
    var minLeft = 12
    var maxLeft = screenW - panelW - 12
    return Math.round(Math.max(minLeft, Math.min(maxLeft, left)))
  }

  HyprlandFocusGrab {
    windows: [ root ]
    active: root.opened && !root.passwordOpen && !root.qrOpen
    onCleared: root.closePanel()
  }

  // --- Network Helpers & Parsers ---
  function parseDetails(raw) {
    var result = {}
    String(raw || "").split("\n").forEach(function(line) {
      var parts = line.split("\t")
      if (parts.length >= 2) result[parts[0]] = parts.slice(1).join("\t").trim()
    })
    return result
  }

  function parseNetworks(raw) {
    return String(raw || "").split("\n").filter(function(line) {
      return line.trim() !== ""
    }).map(function(line) {
      var parts = []
      var current = ""
      var escaped = false
      for (var i = 0; i < line.length; i++) {
        var character = line[i]
        if (escaped) {
          current += character
          escaped = false
        } else if (character === "\\") {
          escaped = true
        } else if (character === ":") {
          parts.push(current)
          current = ""
        } else {
          current += character
        }
      }
      parts.push(current)
      return {
        active: parts[0] === "yes" || parts[0] === "*",
        ssid: parts.slice(1, -2).join(":") || "Hidden network",
        signal: parseInt(parts[parts.length - 2], 10) || 0,
        security: parts[parts.length - 1] || ""
      }
    }).filter(function(network) { return network.ssid !== "Hidden network" })
  }

  function parseKnown(raw) {
    return String(raw || "").split("\n").map(function(value) {
      return value.trim()
    }).filter(function(value) { return value !== "" })
  }

  function wifiIcon(signal) {
    if (signal >= 80) return "󰤨"
    if (signal >= 60) return "󰤥"
    if (signal >= 40) return "󰤢"
    if (signal >= 20) return "󰤟"
    return "󰤯"
  }

  function formatBytes(value) {
    var number = Number(value) || 0
    if (number < 1024) return Math.round(number) + " B"
    if (number < 1048576) return (number / 1024).toFixed(1) + " KB"
    if (number < 1073741824) return (number / 1048576).toFixed(1) + " MB"
    return (number / 1073741824).toFixed(2) + " GB"
  }

  function rate(previousBytes, currentBytes, previousTime, currentTime) {
    var elapsed = (Number(currentTime) - Number(previousTime)) / 1000
    if (!isFinite(elapsed) || elapsed <= 0) return 0
    return Math.max(0, (Number(currentBytes) - Number(previousBytes)) / elapsed)
  }

  function escapeWifi(value) {
    return String(value || "").replace(/([\\;,":])/g, "\\$1")
  }

  function wifiQr(ssid, password, security) {
    var type = security && security !== "--" && security !== "NONE" ? "WPA" : "nopass"
    return "WIFI:T:" + type + ";S:" + escapeWifi(ssid) + ";P:" + escapeWifi(password) + ";;"
  }

  function shellQuote(value) {
    return "'" + String(value || "").replace(/'/g, "'\\''") + "'"
  }

  function run(command) {
    if (actionProc.running) return
    actionProc.command = ["bash", "-lc", command]
    actionProc.running = true
  }

  function refresh(scan) {
    if (!detailsProc.running) detailsProc.running = true
    if (!knownProc.running) knownProc.running = true
    wifiProc.command = ["bash", "-lc", scan ? "nmcli -t --escape yes -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list --rescan yes" : "nmcli -t --escape yes -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list --rescan no"]
    if (!wifiProc.running) wifiProc.running = true
    scanning = !!scan
  }

  function closePanel() {
    opened = false
    passwordOpen = false
    passwordInput = ""
    passwordNetwork = ""
    qrOpen = false
    qrText = ""
    qrPassword = ""
    qrImagePath = ""
    qrReady = false
    downloadRate = 0
    uploadRate = 0
    previousSampleTime = 0
    notice = ""
  }

  function toggleNetwork() {
    run("nmcli radio wifi " + (root.wifiEnabled ? "off" : "on"))
  }

  function connect(network) {
    if (!network || busy) return
    busy = true
    notice = "Connecting to " + network.ssid + "..."
    if (network.active) {
      run("nmcli connection down " + shellQuote(network.ssid))
    } else if (root.knownNetworks.indexOf(network.ssid) >= 0) {
      run("nmcli connection up id " + shellQuote(network.ssid))
    } else if (network.security && network.security !== "--" && network.security !== "NONE") {
      busy = false
      notice = ""
      passwordInput = ""
      passwordNetwork = network.ssid
      passwordOpen = true
    } else {
      run("nmcli device wifi connect " + shellQuote(network.ssid))
    }
  }

  function forget(network) {
    if (!network || busy) return
    busy = true
    notice = "Forgetting " + network.ssid + "..."
    run("nmcli connection delete " + shellQuote(network.ssid))
  }

  function makeQr() {
    if (!details.ssid) return
    qrOpen = true
    qrText = "Generating QR code..."
    qrReady = false
    qrImagePath = ""
    qrFilePath = "/tmp/dotfiles-wifi-qr-" + Date.now() + ".png"
    passwordProc.command = ["bash", "-lc", "connection=$(nmcli -g GENERAL.CONNECTION device show " + shellQuote(details.iface) + " 2>/dev/null); nmcli -s -g 802-11-wireless-security.psk connection show \"$connection\" 2>/dev/null"]
    passwordProc.running = false
    passwordProc.running = true
  }

  function submitPassword() {
    if (!passwordNetwork || !passwordInput) return
    var targetSsid = passwordNetwork
    var targetPass = passwordInput
    passwordOpen = false
    busy = true
    notice = "Connecting to " + targetSsid + "..."
    run("nmcli device wifi connect " + shellQuote(targetSsid) + " password " + shellQuote(targetPass))
    passwordInput = ""
    passwordNetwork = ""
  }

  IpcHandler {
    target: "network"
    function toggle() { root.opened = !root.opened; if (root.opened) root.refresh(true) }
    function open() { root.opened = true; root.refresh(true) }
    function close() { root.closePanel() }
  }

  Item {
    anchors.fill: parent
    focus: root.opened

    Keys.onEscapePressed: {
      if (root.passwordOpen) root.passwordOpen = false
      else if (root.qrOpen) root.qrOpen = false
      else root.closePanel()
    }
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_R) root.refresh(true)
      if (event.key === Qt.Key_W) root.toggleNetwork()
      if (event.key === Qt.Key_Q) root.makeQr()
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
      contentHeight: content.implicitHeight
      clip: true

      Column {
        id: content
        width: parent.width
        spacing: 14

        // Hero Header
        RowLayout {
          width: parent.width
          spacing: 14

          Text {
            text: root.details.type === "ethernet"
              ? "󰈀"
              : root.details.ssid ? root.wifiIcon(100) : root.wifiEnabled ? "󰤨" : "󰤮"
            color: root.details.ssid ? Theme.accent : !root.wifiEnabled ? Theme.fgMuted : Theme.fg
            font.family: Theme.font
            font.pixelSize: 28
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
              text: root.details.ssid || (root.details.type === "ethernet" ? "Ethernet" : "Not Connected")
              color: Theme.fg
              font.family: Theme.font
              font.pixelSize: 18
              font.bold: true
              elide: Text.ElideRight
              Layout.fillWidth: true
            }

            Text {
              text: root.notice || (root.details.type === "ethernet" ? "ETHERNET CONNECTED" : root.details.ssid ? ("CONNECTED  ·  " + (root.details.ip || "")) : root.wifiEnabled ? "DISCONNECTED" : "WI-FI OFF")
              color: root.notice ? Theme.accent : root.details.ssid ? Theme.fgMuted : Theme.warning
              font.family: Theme.font
              font.pixelSize: 11
              font.bold: true
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
          }

          Row {
            spacing: 8
            Rectangle {
              visible: !!root.details.ssid
              width: 28
              height: 28
              radius: 14
              color: qrBtnMouse.containsMouse ? Theme.surfaceActive : Theme.surface
              border.color: Theme.border
              border.width: 1

              Text {
                anchors.centerIn: parent
                text: "󰐲"
                color: Theme.accent
                font.family: Theme.font
                font.pixelSize: 14
              }

              MouseArea {
                id: qrBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.makeQr()
              }
            }

            StyledSwitch {
              checked: root.wifiEnabled
              onToggled: function(val) { root.toggleNetwork() }
            }
          }
        }

        // Live Network Stats Grid
        GridLayout {
          visible: !!root.details.iface && !!root.details.ssid
          width: parent.width
          columns: 4
          columnSpacing: 12
          rowSpacing: 6

          Text { text: "Ping"; color: Theme.fgMuted; font.family: Theme.font; font.pixelSize: 11 }
          Text { text: root.details.ping || "--"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight }
          Text { text: "Loss"; color: Theme.fgMuted; font.family: Theme.font; font.pixelSize: 11 }
          Text { text: root.details.loss || "--"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight }

          Text { text: "Down"; color: Theme.fgMuted; font.family: Theme.font; font.pixelSize: 11 }
          Text { text: root.formatBytes(root.downloadRate) + "/s"; color: Theme.accent; font.family: Theme.font; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight }
          Text { text: "Up"; color: Theme.fgMuted; font.family: Theme.font; font.pixelSize: 11 }
          Text { text: root.formatBytes(root.uploadRate) + "/s"; color: Theme.accent; font.family: Theme.font; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight }

          Text { text: "Total Down"; color: Theme.fgMuted; font.family: Theme.font; font.pixelSize: 11 }
          Text { text: root.formatBytes(root.totalRx); color: Theme.fg; font.family: Theme.font; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight }
          Text { text: "Total Up"; color: Theme.fgMuted; font.family: Theme.font; font.pixelSize: 11 }
          Text { text: root.formatBytes(root.totalTx); color: Theme.fg; font.family: Theme.font; font.pixelSize: 11; font.bold: true; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight }

          Text { text: "IP"; color: Theme.fgMuted; font.family: Theme.font; font.pixelSize: 11 }
          Text { text: root.details.ip || "--"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 11; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight }
          Text { text: "Gateway"; color: Theme.fgMuted; font.family: Theme.font; font.pixelSize: 11 }
          Text { text: root.details.gateway || "--"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 11; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight }
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        // Section Title & Refresh
        RowLayout {
          width: parent.width

          Text {
            text: "󰤨  WI-FI NETWORKS"
            color: Theme.fgMuted
            font.family: Theme.font
            font.pixelSize: 11
            font.bold: true
            Layout.fillWidth: true
          }

          Rectangle {
            visible: root.wifiEnabled
            width: scanRow.implicitWidth + 14
            height: 24
            radius: 12
            color: root.scanning ? Theme.surfaceActive : netScanMouse.containsMouse ? Theme.surfaceHover : Theme.surface
            border.color: root.scanning ? Theme.accent : Theme.border
            border.width: 1

            RowLayout {
              id: scanRow
              anchors.centerIn: parent
              spacing: 4

              Text {
                text: "󰑐"
                color: root.scanning ? Theme.accent : Theme.fgMuted
                font.family: Theme.font
                font.pixelSize: 11
              }

              Text {
                text: root.scanning ? "Scanning..." : "Refresh"
                color: root.scanning ? Theme.accent : Theme.fg
                font.family: Theme.font
                font.pixelSize: 11
              }
            }

            MouseArea {
              id: netScanMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.refresh(true)
            }
          }
        }

        Text {
          visible: root.networks.length === 0
          text: root.wifiEnabled ? (root.scanning ? "Scanning for Wi-Fi networks..." : "No networks found.") : "Wi-Fi is turned off"
          color: Theme.fgMuted
          font.family: Theme.font
          font.pixelSize: 12
        }

        // Networks List
        Repeater {
          model: root.orderedNetworks
          delegate: Rectangle {
            required property var modelData
            required property int index
            width: content.width
            readonly property bool isKnown: root.knownNetworks.indexOf(modelData.ssid) >= 0
            readonly property bool isFirstOther: !isKnown && (index === 0 || root.knownNetworks.indexOf(root.orderedNetworks[index - 1].ssid) >= 0)
            readonly property bool isCurrentConnected: (root.details.ssid && modelData.ssid === root.details.ssid) || modelData.active
            height: 50 + (isFirstOther ? 26 : 0)
            color: "transparent"

            Column {
              anchors.fill: parent
              spacing: 6

              Text {
                visible: parent.parent.isFirstOther
                text: "OTHER NETWORKS"
                color: Theme.fgMuted
                font.family: Theme.font
                font.bold: true
                font.pixelSize: 10
              }

              Rectangle {
                width: parent.width
                height: 46
                radius: Theme.cardRadius
                color: isCurrentConnected ? Theme.surfaceActive : netItemMouse.containsMouse ? Theme.surfaceHover : Theme.surface
                border.color: isCurrentConnected ? Theme.accent : Theme.border
                border.width: 1

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 12
                  anchors.rightMargin: 12
                  spacing: 10

                  Text {
                    text: root.wifiIcon(modelData.signal)
                    color: isCurrentConnected ? Theme.accent : Theme.fgMuted
                    font.family: Theme.font
                    font.pixelSize: 18
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                      text: modelData.ssid
                      color: Theme.fg
                      font.pixelSize: 12
                      font.bold: isCurrentConnected
                      font.family: Theme.font
                      Layout.fillWidth: true
                      elide: Text.ElideRight
                    }

                    RowLayout {
                      spacing: 6
                      Text {
                        text: isCurrentConnected ? "Connected" : (modelData.security && modelData.security !== "--" ? modelData.security : "Open")
                        color: isCurrentConnected ? Theme.accent : Theme.fgMuted
                        font.family: Theme.font
                        font.pixelSize: 10
                      }
                      Text {
                        visible: isCurrentConnected
                        text: "󰄬"
                        color: Theme.accent
                        font.family: Theme.font
                        font.pixelSize: 10
                      }
                    }
                  }

                  Text {
                    text: modelData.security && modelData.security !== "--" && modelData.security !== "NONE" ? "󰌾" : "󰖩"
                    color: Theme.fgMuted
                    font.family: Theme.font
                    font.pixelSize: 14
                  }

                  // Forget button for known networks
                  Rectangle {
                    visible: isKnown && !isCurrentConnected
                    width: 22
                    height: 22
                    radius: 11
                    color: forgetNetMouse.containsMouse ? Theme.surfaceActive : "transparent"

                    Text {
                      anchors.centerIn: parent
                      text: "󰅖"
                      color: forgetNetMouse.containsMouse ? Theme.critical : Theme.fgMuted
                      font.family: Theme.font
                      font.pixelSize: 11
                    }

                    MouseArea {
                      id: forgetNetMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.forget(modelData)
                    }
                  }
                }

                MouseArea {
                  id: netItemMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  z: -1
                  onClicked: root.connect(modelData)
                }
              }
            }
          }
        }
      }
    }

    // Password Prompt Modal Overlay
    Rectangle {
      visible: root.passwordOpen
      anchors.fill: parent
      radius: Theme.radius
      color: Qt.rgba(0.07, 0.07, 0.1, 0.95)
      z: 20

      Column {
        anchors.centerIn: parent
        width: parent.width - 48
        spacing: 14

        RowLayout {
          width: parent.width
          Text {
            text: "󰤨"
            color: Theme.accent
            font.family: Theme.font
            font.pixelSize: 22
          }
          ColumnLayout {
            Layout.fillWidth: true
            Text {
              text: "Connect to Network"
              color: Theme.fg
              font.family: Theme.font
              font.pixelSize: 14
              font.bold: true
            }
            Text {
              text: root.passwordNetwork
              color: Theme.accent
              font.family: Theme.font
              font.pixelSize: 12
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
          }
        }

        Rectangle {
          width: parent.width
          height: 38
          radius: Theme.cardRadius
          color: Theme.surface
          border.color: passField.activeFocus ? Theme.accent : Theme.border
          border.width: 1

          TextInput {
            id: passField
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: 13
            echoMode: TextInput.Password
            text: root.passwordInput
            onTextChanged: root.passwordInput = text
            onAccepted: root.submitPassword()

            Text {
              text: "Enter Wi-Fi password..."
              color: Theme.fgMuted
              font.family: Theme.font
              font.pixelSize: 12
              anchors.verticalCenter: parent.verticalCenter
              visible: !passField.text && !passField.activeFocus
            }
          }
        }

        Row {
          anchors.right: parent.right
          spacing: 8

          Rectangle {
            width: 70
            height: 30
            radius: Theme.cardRadius
            color: cancelMouse.containsMouse ? Theme.surfaceHover : Theme.surface
            border.color: Theme.border
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: "Cancel"
              color: Theme.fgMuted
              font.family: Theme.font
              font.pixelSize: 11
            }

            MouseArea {
              id: cancelMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: { root.passwordOpen = false; root.passwordInput = "" }
            }
          }

          Rectangle {
            width: 76
            height: 30
            radius: Theme.cardRadius
            color: root.passwordInput.length > 0 ? (joinMouse.containsMouse ? Theme.accentHover : Theme.accent) : Theme.surface
            border.color: root.passwordInput.length > 0 ? Theme.accent : Theme.border
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: "Connect"
              color: root.passwordInput.length > 0 ? "#121218" : Theme.fgMuted
              font.family: Theme.font
              font.pixelSize: 11
              font.bold: true
            }

            MouseArea {
              id: joinMouse
              anchors.fill: parent
              enabled: root.passwordInput.length > 0
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.submitPassword()
            }
          }
        }
      }
    }

    // QR Code Modal Overlay
    Rectangle {
      visible: root.qrOpen
      anchors.fill: parent
      radius: Theme.radius
      color: Qt.rgba(0.07, 0.07, 0.1, 0.96)
      z: 20

      Column {
        anchors.centerIn: parent
        width: parent.width - 48
        spacing: 12

        Text {
          width: parent.width
          text: (root.details.ssid || "Wi-Fi").toUpperCase()
          color: Theme.fg
          font.family: Theme.font
          font.pixelSize: 14
          font.bold: true
          horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
          width: 220
          height: 220
          radius: Theme.cardRadius
          color: "#ffffff"
          anchors.horizontalCenter: parent.horizontalCenter
          visible: root.qrReady

          Image {
            anchors.fill: parent
            anchors.margins: 10
            source: root.qrImagePath
            fillMode: Image.PreserveAspectFit
          }
        }

        Text {
          visible: !root.qrReady
          width: parent.width
          text: root.qrText
          color: Theme.fgMuted
          font.family: Theme.font
          font.pixelSize: 11
          wrapMode: Text.WrapAnywhere
          horizontalAlignment: Text.AlignHCenter
        }

        Text {
          visible: root.qrPassword !== ""
          width: parent.width
          text: "Password: " + root.qrPassword
          color: Theme.accent
          font.family: Theme.font
          font.pixelSize: 12
          font.bold: true
          horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
          width: 70
          height: 28
          radius: Theme.cardRadius
          color: closeQrMouse.containsMouse ? Theme.surfaceHover : Theme.surface
          border.color: Theme.border
          border.width: 1
          anchors.horizontalCenter: parent.horizontalCenter

          Text {
            anchors.centerIn: parent
            text: "Close"
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: 11
          }

          MouseArea {
            id: closeQrMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.qrOpen = false
          }
        }
      }
    }
  }

  Process {
    id: detailsProc
    command: ["/home/aayush/.config/quickshell/scripts/network_details.sh"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: function() {
        var next = root.parseDetails(text)
        var now = Date.now()
        if (root.previousSampleTime > 0) {
          root.downloadRate = root.rate(root.previousRx, next.rx, root.previousSampleTime, now)
          root.uploadRate = root.rate(root.previousTx, next.tx, root.previousSampleTime, now)
        }
        var rxNow = Number(next.rx || 0)
        var txNow = Number(next.tx || 0)
        var activeCon = next.conPath || next.connection || next.ssid || ""

        if (root.currentConPath !== activeCon) {
          if (root.currentConPath === "") {
            root.baselineRx = 0
            root.baselineTx = 0
          } else {
            root.baselineRx = rxNow
            root.baselineTx = txNow
          }
          root.currentConPath = activeCon
        }

        if (rxNow < root.baselineRx) root.baselineRx = 0
        if (txNow < root.baselineTx) root.baselineTx = 0

        root.totalRx = Math.max(0, rxNow - root.baselineRx)
        root.totalTx = Math.max(0, txNow - root.baselineTx)

        root.previousRx = rxNow
        root.previousTx = txNow
        root.previousSampleTime = now
        root.details = next
      }
    }
  }

  Process {
    id: wifiProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: function() {
        root.networks = root.parseNetworks(text)
        root.scanning = false
      }
    }
    onExited: function(exitCode) {
      root.scanning = false
    }
  }

  Process {
    id: knownProc
    command: ["bash", "-lc", "nmcli -t -f NAME connection show"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: function() {
        root.knownNetworks = root.parseKnown(text)
      }
    }
  }

  Timer {
    interval: 1000
    running: root.opened
    repeat: true
    onTriggered: {
      if (!detailsProc.running) detailsProc.running = true
      if (!knownProc.running) knownProc.running = true
    }
  }

  Timer {
    interval: 10000
    running: root.opened
    repeat: true
    onTriggered: {
      if (!wifiProc.running) {
        wifiProc.command = ["bash", "-lc", "nmcli -t --escape yes -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list --rescan no"]
        wifiProc.running = true
      }
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function() {
      root.busy = false
      root.notice = ""
      if (!detailsProc.running) detailsProc.running = true
      root.refresh(false)
    }
  }

  Process {
    id: passwordProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: function() {
        var password = String(text || "").trim()
        root.qrPassword = password
        var security = root.details.security || "WPA"
        var payload = root.wifiQr(root.details.ssid, password, security)
        root.qrText = "Could not render QR image.\n" + payload
        root.qrImagePath = ""
        qrCodeProc.command = ["bash", "-lc", "qrencode -o " + root.shellQuote(root.qrFilePath) + " " + root.shellQuote(payload)]
        qrCodeProc.running = false
        qrCodeProc.running = true
      }
    }
  }

  Process {
    id: qrCodeProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: function() {
        if (String(text || "").trim() !== "") root.qrText = text
      }
    }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.qrImagePath = "file://" + root.qrFilePath
        root.qrVersion++
        root.qrReady = true
      } else {
        root.qrText = "Could not generate the QR code."
      }
    }
  }

  Component.onCompleted: root.refresh(false)
}
