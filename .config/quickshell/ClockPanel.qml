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
  property date now: new Date()
  property date selectedDate: new Date()
  property int viewYear: new Date().getFullYear()
  property int viewMonth: new Date().getMonth()
  property var calendarGridModel: []

  // Weather state
  property bool weatherLoading: false
  property var weatherData: null
  property string weatherError: ""
  property string weatherCity: "Vijapur, Gujarat"
  property string weatherTemp: "--"
  property string weatherFeels: "--"
  property string weatherDesc: "Loading weather..."
  property string weatherIcon: "󰖙"
  property string weatherHumidity: "--"
  property string weatherWind: "--"
  property string weatherUv: "--"
  property string weatherPrecip: "--"
  property string weatherPressure: "--"
  property string weatherSunrise: "--"
  property string weatherSunset: "--"
  property string weatherMoon: "--"
  property var weatherForecast: []

  // Active section tab: 0 = "Calendar & Weather", 1 = "World Clocks"
  property int activeTab: 0

  visible: opened
  implicitWidth: 440
  implicitHeight: Math.min(scrollContent.implicitHeight + 32, 740)
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "dotfiles-clock-panel"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

  // Placed directly below the left-side Waybar clock module
  anchors.top: true
  anchors.left: true
  margins.top: 40
  margins.left: 12

  HyprlandFocusGrab {
    windows: [ root ]
    active: root.opened
    onCleared: root.closePanel()
  }

  function closePanel() {
    opened = false
  }

  function refresh() {
    now = new Date()
    updateCalendarModel()
    fetchWeather()
  }

  function prevMonth() {
    if (viewMonth === 0) {
      viewMonth = 11
      viewYear--
    } else {
      viewMonth--
    }
    updateCalendarModel()
  }

  function nextMonth() {
    if (viewMonth === 11) {
      viewMonth = 0
      viewYear++
    } else {
      viewMonth++
    }
    updateCalendarModel()
  }

  function goToToday() {
    var today = new Date()
    viewYear = today.getFullYear()
    viewMonth = today.getMonth()
    selectedDate = today
    updateCalendarModel()
  }

  function selectDate(year, month, day) {
    selectedDate = new Date(year, month, day)
    viewYear = year
    viewMonth = month
    updateCalendarModel()
  }

  function isSameDay(d, y, m, day) {
    if (!d) return false
    return d.getFullYear() === y && d.getMonth() === m && d.getDate() === day
  }

  function updateCalendarModel() {
    var today = new Date()
    var firstDayDate = new Date(viewYear, viewMonth, 1)
    var lastDayDate = new Date(viewYear, viewMonth + 1, 0)
    var daysInCurrentMonth = lastDayDate.getDate()

    // ISO day of week: Monday is 0, Sunday is 6
    var firstDayOfWeek = (firstDayDate.getDay() + 6) % 7
    var prevMonthLastDate = new Date(viewYear, viewMonth, 0).getDate()

    var cells = []

    // Previous month trailing days
    var pMonth = viewMonth === 0 ? 11 : viewMonth - 1
    var pYear = viewMonth === 0 ? viewYear - 1 : viewYear
    for (var i = firstDayOfWeek - 1; i >= 0; i--) {
      var dNum = prevMonthLastDate - i
      cells.push({
        day: dNum,
        month: pMonth,
        year: pYear,
        isCurrentMonth: false,
        isToday: isSameDay(today, pYear, pMonth, dNum),
        isSelected: isSameDay(selectedDate, pYear, pMonth, dNum)
      })
    }

    // Current month days
    for (var d = 1; d <= daysInCurrentMonth; d++) {
      cells.push({
        day: d,
        month: viewMonth,
        year: viewYear,
        isCurrentMonth: true,
        isToday: isSameDay(today, viewYear, viewMonth, d),
        isSelected: isSameDay(selectedDate, viewYear, viewMonth, d)
      })
    }

    // Next month leading days (42 cells grid = 6 rows x 7 cols)
    var totalCells = 42
    var nextDays = totalCells - cells.length
    var nMonth = viewMonth === 11 ? 0 : viewMonth + 1
    var nYear = viewMonth === 11 ? viewYear + 1 : viewYear
    for (var n = 1; n <= nextDays; n++) {
      cells.push({
        day: n,
        month: nMonth,
        year: nYear,
        isCurrentMonth: false,
        isToday: isSameDay(today, nYear, nMonth, n),
        isSelected: isSameDay(selectedDate, nYear, nMonth, n)
      })
    }

    calendarGridModel = cells
  }

  function getWeatherIcon(code) {
    var c = parseInt(code, 10)
    switch (c) {
      case 113: return "󰖙" // Sunny / Clear
      case 116: return "󰖕" // Partly Cloudy
      case 119:
      case 122: return "󰖐" // Cloudy / Overcast
      case 143:
      case 248:
      case 260: return "󰖑" // Fog / Mist
      case 176:
      case 263:
      case 266:
      case 281:
      case 293:
      case 296: return "󰖗" // Light Rain / Drizzle
      case 299:
      case 302:
      case 305:
      case 308:
      case 311:
      case 314:
      case 353:
      case 356:
      case 359: return "󰖖" // Heavy Rain
      case 179:
      case 182:
      case 185:
      case 227:
      case 230:
      case 323:
      case 326:
      case 329:
      case 332:
      case 335:
      case 338:
      case 368:
      case 371: return "󰖘" // Snow
      case 200:
      case 386:
      case 389:
      case 392:
      case 395: return "󰖓" // Thunderstorm
      default: return "󰖙"
    }
  }

  function fetchWeather() {
    weatherLoading = true
    weatherProc.running = false
    weatherProc.running = true
  }

  function pad(num) {
    return num < 10 ? "0" + num : String(num)
  }

  readonly property var monthNames: [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ]

  readonly property var weekDayNames: [
    "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"
  ]

  readonly property var fullDayNames: [
    "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
  ]

  readonly property string formattedTime: {
    var h = pad(now.getHours())
    var m = pad(now.getMinutes())
    return h + ":" + m
  }

  readonly property string formattedSeconds: pad(now.getSeconds())

  readonly property string formattedFullDate: {
    var dayName = fullDayNames[now.getDay()]
    var monthName = monthNames[now.getMonth()]
    return dayName + ", " + monthName + " " + now.getDate() + ", " + now.getFullYear()
  }

  readonly property string formattedSelectedDate: {
    var dayName = fullDayNames[selectedDate.getDay()]
    var monthName = monthNames[selectedDate.getMonth()]
    return dayName + ", " + monthName + " " + selectedDate.getDate() + ", " + selectedDate.getFullYear()
  }

  readonly property int weekNumber: {
    var target = new Date(now.valueOf())
    var dayNr = (now.getDay() + 6) % 7
    target.setDate(target.getDate() - dayNr + 3)
    var firstThursday = target.valueOf()
    target.setMonth(0, 1)
    if (target.getDay() !== 4) {
      target.setMonth(0, 1 + ((4 - target.getDay()) + 7) % 7)
    }
    return 1 + Math.ceil((firstThursday - target) / 604800000)
  }

  function getWorldTime(tz) {
    try {
      var d = new Date()
      return d.toLocaleTimeString("en-US", { timeZone: tz, hour: "2-digit", minute: "2-digit", hour12: false })
    } catch (e) {
      return "--:--"
    }
  }

  readonly property var worldTimezones: [
    { name: "UTC", zone: "UTC", icon: "󰡛", city: "Universal Time" },
    { name: "IST", zone: "Asia/Kolkata", icon: "󰀵", city: "New Delhi / Mumbai" },
    { name: "EST", zone: "America/New_York", icon: "󰀵", city: "New York" },
    { name: "GMT", zone: "Europe/London", icon: "󰀵", city: "London" },
    { name: "JST", zone: "Asia/Tokyo", icon: "󰀵", city: "Tokyo" },
    { name: "PST", zone: "America/Los_Angeles", icon: "󰀵", city: "San Francisco" }
  ]

  IpcHandler {
    target: "clock"
    function toggle() { root.opened = !root.opened; if (root.opened) root.refresh() }
    function open() { root.opened = true; root.refresh() }
    function close() { root.closePanel() }
  }

  Item {
    anchors.fill: parent
    focus: root.opened

    Keys.onEscapePressed: root.closePanel()
    Keys.onLeftPressed: root.prevMonth()
    Keys.onRightPressed: root.nextMonth()
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_R) root.refresh()
      if (event.key === Qt.Key_T) root.goToToday()
    }

    Rectangle {
      anchors.fill: parent
      color: Theme.panelBg
      radius: Theme.radius
      border.color: Theme.border
      border.width: 1
    }

    Flickable {
      id: flick
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
        // 1. HERO HEADER: Digital Clock & Date
        // ==========================================
        Rectangle {
          width: parent.width
          implicitHeight: headerLayout.implicitHeight + 20
          radius: Theme.cardRadius
          color: Theme.surface
          border.color: Theme.border
          border.width: 1

          ColumnLayout {
            id: headerLayout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 6

            // Time and Quick Badges Row
            RowLayout {
              Layout.fillWidth: true
              spacing: 8

              // Digital Time Display
              Row {
                spacing: 4
                Layout.alignment: Qt.AlignVCenter

                Text {
                  text: root.formattedTime
                  color: Theme.accent
                  font.family: Theme.font
                  font.pixelSize: 30
                  font.bold: true
                }

                Text {
                  text: ":" + root.formattedSeconds
                  color: Theme.fgMuted
                  font.family: Theme.font
                  font.pixelSize: 18
                  font.bold: true
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: 3
                }
              }

              Item { Layout.fillWidth: true }

              // Week number badge
              Rectangle {
                implicitWidth: weekText.implicitWidth + 12
                implicitHeight: 24
                radius: 12
                color: Theme.surfaceHover
                border.color: Theme.border
                border.width: 1

                Text {
                  id: weekText
                  anchors.centerIn: parent
                  text: "Wk " + root.weekNumber
                  color: Theme.fgMuted
                  font.family: Theme.font
                  font.pixelSize: 11
                  font.bold: true
                }
              }
            }

            // Full Date Text
            Text {
              text: root.formattedFullDate
              color: Theme.fg
              font.family: Theme.font
              font.pixelSize: 13
              font.bold: true
            }
          }
        }

        // ==========================================
        // 2. TAB SWITCHER: [ Calendar & Weather | World Clocks ]
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

            // Tab 1: Calendar & Weather
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

                Text {
                  text: ""
                  color: root.activeTab === 0 ? Theme.accent : Theme.fgMuted
                  font.family: Theme.font
                  font.pixelSize: 12
                }
                Text {
                  text: "Calendar & Weather"
                  color: root.activeTab === 0 ? Theme.fg : Theme.fgMuted
                  font.family: Theme.font
                  font.pixelSize: 11
                  font.bold: root.activeTab === 0
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activeTab = 0
              }
            }

            // Tab 2: World Clocks
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

                Text {
                  text: "󰡛"
                  color: root.activeTab === 1 ? Theme.accent : Theme.fgMuted
                  font.family: Theme.font
                  font.pixelSize: 12
                }
                Text {
                  text: "World Clocks"
                  color: root.activeTab === 1 ? Theme.fg : Theme.fgMuted
                  font.family: Theme.font
                  font.pixelSize: 11
                  font.bold: root.activeTab === 1
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activeTab = 1
              }
            }
          }
        }

        // ==========================================
        // 3. TAB CONTENT: CALENDAR & WEATHER
        // ==========================================
        Column {
          width: parent.width
          spacing: 12
          visible: root.activeTab === 0

          // ----------------------------------------
          // 3A. INTERACTIVE CALENDAR CARD
          // ----------------------------------------
          Rectangle {
            width: parent.width
            implicitHeight: calendarCol.implicitHeight + 20
            radius: Theme.cardRadius
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            Column {
              id: calendarCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: 12
              spacing: 10

              // Month Navigator Header
              RowLayout {
                width: parent.width
                spacing: 8

                Text {
                  text: root.monthNames[root.viewMonth] + " " + root.viewYear
                  color: Theme.fg
                  font.family: Theme.font
                  font.pixelSize: 14
                  font.bold: true
                  Layout.fillWidth: true
                }

                // Today jump button
                Rectangle {
                  implicitWidth: todayBtnText.implicitWidth + 12
                  implicitHeight: 24
                  radius: Theme.cardRadius
                  color: todayBtnMouse.containsMouse ? Theme.surfaceActive : Theme.surfaceHover
                  border.color: Theme.border
                  border.width: 1

                  Text {
                    id: todayBtnText
                    anchors.centerIn: parent
                    text: "Today"
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.bold: true
                  }

                  MouseArea {
                    id: todayBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.goToToday()
                  }
                }

                // Previous Month Button
                Rectangle {
                  width: 24
                  height: 24
                  radius: Theme.cardRadius
                  color: prevBtnMouse.containsMouse ? Theme.surfaceActive : Theme.surfaceHover
                  border.color: Theme.border
                  border.width: 1

                  Text {
                    anchors.centerIn: parent
                    text: ""
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 11
                  }

                  MouseArea {
                    id: prevBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.prevMonth()
                  }
                }

                // Next Month Button
                Rectangle {
                  width: 24
                  height: 24
                  radius: Theme.cardRadius
                  color: nextBtnMouse.containsMouse ? Theme.surfaceActive : Theme.surfaceHover
                  border.color: Theme.border
                  border.width: 1

                  Text {
                    anchors.centerIn: parent
                    text: ""
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 11
                  }

                  MouseArea {
                    id: nextBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.nextMonth()
                  }
                }
              }

              // Weekdays Header Row (Mo, Tu, We, Th, Fr, Sa, Su)
              Row {
                width: parent.width
                spacing: 0

                Repeater {
                  model: root.weekDayNames
                  delegate: Item {
                    required property var modelData
                    required property int index
                    width: calendarCol.width / 7
                    height: 20

                    Text {
                      anchors.centerIn: parent
                      text: modelData
                      color: index >= 5 ? Theme.warning : Theme.fgSubtle
                      font.family: Theme.font
                      font.pixelSize: 11
                      font.bold: true
                    }
                  }
                }
              }

              // Days Grid (6 rows x 7 cols = 42 cells)
              Grid {
                id: daysGrid
                width: parent.width
                columns: 7
                rowSpacing: 4
                columnSpacing: 0

                Repeater {
                  model: root.calendarGridModel
                  delegate: Rectangle {
                    id: dayCell
                    required property var modelData
                    required property int index

                    readonly property int colIndex: index % 7
                    readonly property bool isWeekend: colIndex >= 5
                    readonly property bool isCurrent: modelData.isCurrentMonth
                    readonly property bool isToday: modelData.isToday
                    readonly property bool isSelected: modelData.isSelected
                    readonly property bool isHovered: dayMouse.containsMouse

                    width: calendarCol.width / 7
                    height: 30
                    radius: 6

                    color: isToday ? Theme.accent :
                           isSelected ? Theme.surfaceActive :
                           isHovered ? Theme.surfaceHover : "transparent"

                    border.color: isToday ? Theme.accentHover :
                                  isSelected ? Theme.borderActive : "transparent"
                    border.width: isSelected || isToday ? 1 : 0

                    Text {
                      anchors.centerIn: parent
                      text: String(modelData.day)
                      font.family: Theme.font
                      font.pixelSize: 12
                      font.bold: isToday || isSelected

                      color: isToday ? "#121218" :
                             isSelected ? Theme.accent :
                             !isCurrent ? Theme.fgSubtle :
                             isWeekend ? Theme.warning : Theme.fg
                    }

                    MouseArea {
                      id: dayMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.selectDate(modelData.year, modelData.month, modelData.day)
                    }
                  }
                }
              }

              // Selected Date Indicator
              Rectangle {
                width: parent.width
                height: 24
                radius: Theme.cardRadius
                color: Theme.surfaceHover
                border.color: Theme.border
                border.width: 1

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: 8
                  anchors.rightMargin: 8
                  spacing: 6

                  Text {
                    text: "󰸗"
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: 11
                  }

                  Text {
                    text: "Selected: " + root.formattedSelectedDate
                    color: Theme.fgMuted
                    font.family: Theme.font
                    font.pixelSize: 10
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                  }
                }
              }
            }
          }

          // ----------------------------------------
          // 3B. WEATHER CARD
          // ----------------------------------------
          Rectangle {
            width: parent.width
            implicitHeight: weatherCol.implicitHeight + 20
            radius: Theme.cardRadius
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            Column {
              id: weatherCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: 12
              spacing: 10

              // Weather Header Row
              RowLayout {
                width: parent.width
                spacing: 8

                Row {
                  spacing: 6
                  Layout.alignment: Qt.AlignVCenter

                  Text {
                    text: "󰖐"
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: 14
                  }

                  Text {
                    text: "Weather"
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.bold: true
                  }

                  Text {
                    text: "• " + root.weatherCity
                    color: Theme.fgMuted
                    font.family: Theme.font
                    font.pixelSize: 11
                  }
                }

                Item { Layout.fillWidth: true }

                // Refresh Button
                Rectangle {
                  width: 24
                  height: 24
                  radius: Theme.cardRadius
                  color: weatherRefreshMouse.containsMouse ? Theme.surfaceActive : Theme.surfaceHover
                  border.color: Theme.border
                  border.width: 1

                  Text {
                    anchors.centerIn: parent
                    text: "󰑐"
                    color: root.weatherLoading ? Theme.accent : Theme.fgMuted
                    font.family: Theme.font
                    font.pixelSize: 12

                    NumberAnimation on rotation {
                      from: 0
                      to: 360
                      duration: 800
                      loops: Animation.Infinite
                      running: root.weatherLoading
                    }
                  }

                  MouseArea {
                    id: weatherRefreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.fetchWeather()
                  }
                }
              }

              // Main Condition Row
              Rectangle {
                width: parent.width
                implicitHeight: mainCondRow.implicitHeight + 16
                radius: Theme.cardRadius
                color: Theme.surfaceHover
                border.color: Theme.border
                border.width: 1

                RowLayout {
                  id: mainCondRow
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: 10
                  spacing: 12

                  // Big Weather Icon
                  Text {
                    text: root.weatherIcon
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: 34
                  }

                  // Temp & Description
                  Column {
                    Layout.fillWidth: true
                    spacing: 2

                    Row {
                      spacing: 8
                      Text {
                        text: root.weatherTemp
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: 22
                        font.bold: true
                      }
                      Text {
                        text: "Feels " + root.weatherFeels
                        color: Theme.fgMuted
                        font.family: Theme.font
                        font.pixelSize: 12
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                      }
                    }

                    Text {
                      text: root.weatherDesc
                      color: Theme.fg
                      font.family: Theme.font
                      font.pixelSize: 12
                      elide: Text.ElideRight
                    }
                  }
                }
              }

              // Weather Metrics Grid (2 columns x 4 rows)
              GridLayout {
                width: parent.width
                columns: 2
                rowSpacing: 6
                columnSpacing: 6

                // Humidity
                Rectangle {
                  Layout.fillWidth: true
                  height: 28
                  radius: Theme.cardRadius
                  color: Theme.surfaceHover
                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    Text { text: "󰖎"; color: Theme.accent; font.family: Theme.font; font.pixelSize: 12 }
                    Text { text: "Humidity"; color: Theme.fgMuted; font.family: Theme.font; font.pixelSize: 10; Layout.fillWidth: true }
                    Text { text: root.weatherHumidity; color: Theme.fg; font.family: Theme.font; font.pixelSize: 11; font.bold: true }
                  }
                }

                // Wind
                Rectangle {
                  Layout.fillWidth: true
                  height: 28
                  radius: Theme.cardRadius
                  color: Theme.surfaceHover
                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    Text { text: "󰖝"; color: Theme.accent; font.family: Theme.font; font.pixelSize: 12 }
                    Text { text: "Wind"; color: Theme.fgMuted; font.family: Theme.font; font.pixelSize: 10; Layout.fillWidth: true }
                    Text { text: root.weatherWind; color: Theme.fg; font.family: Theme.font; font.pixelSize: 11; font.bold: true }
                  }
                }

                // UV Index
                Rectangle {
                  Layout.fillWidth: true
                  height: 28
                  radius: Theme.cardRadius
                  color: Theme.surfaceHover
                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    Text { text: "󰼫"; color: Theme.warning; font.family: Theme.font; font.pixelSize: 12 }
                    Text { text: "UV Index"; color: Theme.fgMuted; font.family: Theme.font; font.pixelSize: 10; Layout.fillWidth: true }
                    Text { text: root.weatherUv; color: Theme.fg; font.family: Theme.font; font.pixelSize: 11; font.bold: true }
                  }
                }

                // Rain / Precip
                Rectangle {
                  Layout.fillWidth: true
                  height: 28
                  radius: Theme.cardRadius
                  color: Theme.surfaceHover
                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    Text { text: "󰔏"; color: Theme.accent; font.family: Theme.font; font.pixelSize: 12 }
                    Text { text: "Precip"; color: Theme.fgMuted; font.family: Theme.font; font.pixelSize: 10; Layout.fillWidth: true }
                    Text { text: root.weatherPrecip; color: Theme.fg; font.family: Theme.font; font.pixelSize: 11; font.bold: true }
                  }
                }

                // Pressure
                Rectangle {
                  Layout.fillWidth: true
                  height: 28
                  radius: Theme.cardRadius
                  color: Theme.surfaceHover
                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    Text { text: "󰙾"; color: Theme.accent; font.family: Theme.font; font.pixelSize: 12 }
                    Text { text: "Pressure"; color: Theme.fgMuted; font.family: Theme.font; font.pixelSize: 10; Layout.fillWidth: true }
                    Text { text: root.weatherPressure; color: Theme.fg; font.family: Theme.font; font.pixelSize: 11; font.bold: true }
                  }
                }

                // Moon Phase
                Rectangle {
                  Layout.fillWidth: true
                  height: 28
                  radius: Theme.cardRadius
                  color: Theme.surfaceHover
                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    Text { text: "󰽧"; color: Theme.fgMuted; font.family: Theme.font; font.pixelSize: 12 }
                    Text { text: "Moon"; color: Theme.fgMuted; font.family: Theme.font; font.pixelSize: 10; Layout.fillWidth: true }
                    Text { text: root.weatherMoon; color: Theme.fg; font.family: Theme.font; font.pixelSize: 10; font.bold: true; elide: Text.ElideRight }
                  }
                }

                // Sunrise
                Rectangle {
                  Layout.fillWidth: true
                  height: 28
                  radius: Theme.cardRadius
                  color: Theme.surfaceHover
                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    Text { text: "󰖜"; color: Theme.warning; font.family: Theme.font; font.pixelSize: 12 }
                    Text { text: "Sunrise"; color: Theme.fgMuted; font.family: Theme.font; font.pixelSize: 10; Layout.fillWidth: true }
                    Text { text: root.weatherSunrise; color: Theme.fg; font.family: Theme.font; font.pixelSize: 11; font.bold: true }
                  }
                }

                // Sunset
                Rectangle {
                  Layout.fillWidth: true
                  height: 28
                  radius: Theme.cardRadius
                  color: Theme.surfaceHover
                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    Text { text: "󰖛"; color: Theme.accent; font.family: Theme.font; font.pixelSize: 12 }
                    Text { text: "Sunset"; color: Theme.fgMuted; font.family: Theme.font; font.pixelSize: 10; Layout.fillWidth: true }
                    Text { text: root.weatherSunset; color: Theme.fg; font.family: Theme.font; font.pixelSize: 11; font.bold: true }
                  }
                }
              }

              // 3-Day Forecast Strip
              RowLayout {
                width: parent.width
                spacing: 6
                visible: root.weatherForecast.length > 0

                Repeater {
                  model: root.weatherForecast
                  delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 54
                    radius: Theme.cardRadius
                    color: Theme.surfaceHover
                    border.color: Theme.border
                    border.width: 1

                    ColumnLayout {
                      anchors.fill: parent
                      anchors.margins: 4
                      spacing: 2

                      Text {
                        text: modelData.day
                        color: Theme.fgMuted
                        font.family: Theme.font
                        font.pixelSize: 10
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                      }

                      Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4

                        Text {
                          text: modelData.icon
                          color: Theme.accent
                          font.family: Theme.font
                          font.pixelSize: 13
                        }

                        Text {
                          text: modelData.temp
                          color: Theme.fg
                          font.family: Theme.font
                          font.pixelSize: 11
                          font.bold: true
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
        // 4. TAB CONTENT: WORLD CLOCKS
        // ==========================================
        Column {
          width: parent.width
          spacing: 8
          visible: root.activeTab === 1

          Repeater {
            model: root.worldTimezones
            delegate: Rectangle {
              required property var modelData
              required property int index
              width: scrollContent.width
              height: 52
              radius: Theme.cardRadius
              color: Theme.surface
              border.color: Theme.border
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                Text {
                  text: modelData.icon
                  color: Theme.accent
                  font.family: Theme.font
                  font.pixelSize: 18
                }

                Column {
                  Layout.fillWidth: true
                  spacing: 2

                  Text {
                    text: modelData.name + " • " + modelData.city
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                  }

                  Text {
                    text: modelData.zone
                    color: Theme.fgMuted
                    font.family: Theme.font
                    font.pixelSize: 10
                  }
                }

                Text {
                  text: root.getWorldTime(modelData.zone)
                  color: Theme.accent
                  font.family: Theme.font
                  font.pixelSize: 18
                  font.bold: true
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

  // Live seconds clock timer
  Timer {
    interval: 1000
    running: root.opened
    repeat: true
    onTriggered: {
      root.now = new Date()
    }
  }

  // Weather fetch process
  Process {
    id: weatherProc
    command: ["bash", "-lc", "curl -sf --max-time 6 'https://wttr.in/Vijapur,Gujarat?format=j1' || curl -sf --max-time 6 'https://wttr.in/?format=j1'"]
    stdout: StdioCollector {
      id: weatherCollector
      waitForEnd: true
      onStreamFinished: {
        root.weatherLoading = false
        var raw = String(weatherCollector.text || "").trim()
        if (!raw) {
          root.weatherError = "Failed to load weather"
          return
        }
        try {
          var data = JSON.parse(raw)
          root.weatherData = data

          var curr = (data.current_condition && data.current_condition[0]) ? data.current_condition[0] : {}
          var area = (data.nearest_area && data.nearest_area[0]) ? data.nearest_area[0] : null
          var astro = (data.weather && data.weather[0] && data.weather[0].astronomy && data.weather[0].astronomy[0]) ? data.weather[0].astronomy[0] : {}

          if (area && area.areaName && area.areaName[0]) {
            var cityName = area.areaName[0].value || ""
            var regName = (area.region && area.region[0]) ? area.region[0].value : ""
            root.weatherCity = regName ? (cityName + ", " + regName) : cityName
          }

          root.weatherTemp = (curr.temp_C || "--") + "°C"
          root.weatherFeels = (curr.FeelsLikeC || "--") + "°C"
          root.weatherDesc = (curr.weatherDesc && curr.weatherDesc[0]) ? curr.weatherDesc[0].value.trim() : "Clear"
          root.weatherIcon = root.getWeatherIcon(curr.weatherCode || 113)

          root.weatherHumidity = (curr.humidity || "--") + "%"
          root.weatherWind = (curr.windspeedKmph || "--") + " km/h " + (curr.winddir16Point || "")
          root.weatherUv = curr.uvIndex || "--"
          root.weatherPrecip = (curr.precipMM || "0") + " mm"
          root.weatherPressure = (curr.pressure || "--") + " hPa"

          root.weatherSunrise = astro.sunrise || "--"
          root.weatherSunset = astro.sunset || "--"
          root.weatherMoon = astro.moon_phase || "--"

          // Forecast for next days
          var fList = []
          if (data.weather && data.weather.length > 0) {
            for (var f = 0; f < Math.min(3, data.weather.length); f++) {
              var dayObj = data.weather[f]
              var fDate = new Date(dayObj.date + "T12:00:00")
              var label = (f === 0) ? "Today" : root.fullDayNames[fDate.getDay()].slice(0, 3)
              var fIcon = "󰖙"
              if (dayObj.hourly && dayObj.hourly[4]) {
                fIcon = root.getWeatherIcon(dayObj.hourly[4].weatherCode)
              }
              fList.push({
                day: label,
                icon: fIcon,
                temp: (dayObj.maxtempC || "-") + "° / " + (dayObj.mintempC || "-") + "°"
              })
            }
          }
          root.weatherForecast = fList
        } catch (e) {
          root.weatherError = "Parse error"
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.weatherLoading = false
      }
    }
  }

  Component.onCompleted: {
    root.refresh()
  }
}
