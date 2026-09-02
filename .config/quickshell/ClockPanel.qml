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

  // Calendar Events state
  property bool calendarLoading: false
  property var calendarEvents: []
  property string calendarError: ""
  property var selectedDayEvents: []

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
    fetchCalendar()
  }

  function fetchCalendar() {
    calendarLoading = true
    if (typeof calendarProc !== "undefined" && calendarProc) {
      calendarProc.running = false
      calendarProc.running = true
    }
  }

  function formatDateKey(y, m, d) {
    var mm = (m + 1) < 10 ? "0" + (m + 1) : String(m + 1)
    var dd = d < 10 ? "0" + d : String(d)
    return y + "-" + mm + "-" + dd
  }

  function getEventsForDate(y, m, d) {
    var key = formatDateKey(y, m, d)
    var res = []
    if (!calendarEvents || calendarEvents.length === 0) return res
    for (var i = 0; i < calendarEvents.length; i++) {
      if (calendarEvents[i].date === key) {
        res.push(calendarEvents[i])
      }
    }
    return res
  }

  function updateSelectedDayEvents() {
    selectedDayEvents = getEventsForDate(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate())
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
    updateSelectedDayEvents()
  }

  function selectDate(year, month, day) {
    selectedDate = new Date(year, month, day)
    viewYear = year
    viewMonth = month
    updateCalendarModel()
    updateSelectedDayEvents()
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

    function makeCell(dNum, mNum, yNum, isCurr) {
      var evts = getEventsForDate(yNum, mNum, dNum)
      var colors = []
      for (var k = 0; k < evts.length; k++) {
        var c = evts[k].color || "#47c8ff"
        if (colors.indexOf(c) === -1 && colors.length < 3) {
          colors.push(c)
        }
      }
      return {
        day: dNum,
        month: mNum,
        year: yNum,
        isCurrentMonth: isCurr,
        isToday: isSameDay(today, yNum, mNum, dNum),
        isSelected: isSameDay(selectedDate, yNum, mNum, dNum),
        hasEvents: evts.length > 0,
        eventCount: evts.length,
        eventColors: colors
      }
    }

    // Previous month trailing days
    var pMonth = viewMonth === 0 ? 11 : viewMonth - 1
    var pYear = viewMonth === 0 ? viewYear - 1 : viewYear
    for (var i = firstDayOfWeek - 1; i >= 0; i--) {
      var dNum = prevMonthLastDate - i
      cells.push(makeCell(dNum, pMonth, pYear, false))
    }

    // Current month days
    for (var d = 1; d <= daysInCurrentMonth; d++) {
      cells.push(makeCell(d, viewMonth, viewYear, true))
    }

    // Next month leading days (42 cells grid = 6 rows x 7 cols)
    var totalCells = 42
    var nextDays = totalCells - cells.length
    var nMonth = viewMonth === 11 ? 0 : viewMonth + 1
    var nYear = viewMonth === 11 ? viewYear + 1 : viewYear
    for (var n = 1; n <= nextDays; n++) {
      cells.push(makeCell(n, nMonth, nYear, false))
    }

    calendarGridModel = cells
    updateSelectedDayEvents()
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
    if (typeof weatherProc !== "undefined" && weatherProc) {
      weatherProc.running = false
      weatherProc.running = true
    }
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

  function getTzOffsetMinutes(zone, d) {
    var targetDate = d || root.now
    var year = targetDate.getUTCFullYear()

    var isUsDst = function() {
      var march = new Date(Date.UTC(year, 2, 1))
      var marchFirstSun = 1 + ((7 - march.getUTCDay()) % 7)
      var marchSecondSun = marchFirstSun + 7
      var dstStart = new Date(Date.UTC(year, 2, marchSecondSun, 7, 0, 0))

      var nov = new Date(Date.UTC(year, 10, 1))
      var novFirstSun = 1 + ((7 - nov.getUTCDay()) % 7)
      var dstEnd = new Date(Date.UTC(year, 10, novFirstSun, 6, 0, 0))

      return targetDate >= dstStart && targetDate < dstEnd
    }

    var isEuDst = function() {
      var march31 = new Date(Date.UTC(year, 2, 31))
      var marchLastSun = 31 - march31.getUTCDay()
      var dstStart = new Date(Date.UTC(year, 2, marchLastSun, 1, 0, 0))

      var oct31 = new Date(Date.UTC(year, 9, 31))
      var octLastSun = 31 - oct31.getUTCDay()
      var dstEnd = new Date(Date.UTC(year, 9, octLastSun, 1, 0, 0))

      return targetDate >= dstStart && targetDate < dstEnd
    }

    var isAusDst = function() {
      var oct = new Date(Date.UTC(year, 9, 1))
      var octFirstSun = 1 + ((7 - oct.getUTCDay()) % 7)
      var dstStart = new Date(Date.UTC(year, 9, octFirstSun, 16, 0, 0))

      var apr = new Date(Date.UTC(year, 3, 1))
      var aprFirstSun = 1 + ((7 - apr.getUTCDay()) % 7)
      var dstEnd = new Date(Date.UTC(year, 3, aprFirstSun, 16, 0, 0))

      return targetDate >= dstStart || targetDate < dstEnd
    }

    switch (zone) {
      case "UTC":
      case "Etc/UTC":
      case "GMT":
        return 0
      case "Asia/Kolkata":
      case "IST":
        return 330
      case "America/New_York":
      case "EST":
      case "EDT":
        return isUsDst() ? -240 : -300
      case "America/Los_Angeles":
      case "PST":
      case "PDT":
        return isUsDst() ? -420 : -480
      case "America/Chicago":
      case "CST":
      case "CDT":
        return isUsDst() ? -300 : -360
      case "America/Denver":
      case "MST":
      case "MDT":
        return isUsDst() ? -360 : -420
      case "Europe/London":
      case "BST":
        return isEuDst() ? 60 : 0
      case "Europe/Paris":
      case "Europe/Berlin":
      case "Europe/Rome":
      case "Europe/Madrid":
      case "CET":
      case "CEST":
        return isEuDst() ? 120 : 60
      case "Asia/Tokyo":
      case "JST":
        return 540
      case "Asia/Shanghai":
      case "Asia/Hong_Kong":
      case "Asia/Singapore":
      case "SGT":
      case "CST_ASIA":
        return 480
      case "Asia/Dubai":
      case "GST":
        return 240
      case "Australia/Sydney":
      case "AEST":
      case "AEDT":
        return isAusDst() ? 660 : 600
      case "Pacific/Auckland":
      case "NZST":
      case "NZDT":
        return isAusDst() ? 780 : 720
      default:
        if (typeof zone === "number") return zone
        return 0
    }
  }

  function getWorldDateObj(tz) {
    var d = root.now
    var offsetMin = root.getTzOffsetMinutes(tz, d)
    return new Date(d.getTime() + offsetMin * 60000)
  }

  function getWorldDate(tz) {
    try {
      var target = getWorldDateObj(tz)
      var shortMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
      var shortDays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
      var dayName = shortDays[target.getUTCDay()]
      var monthName = shortMonths[target.getUTCMonth()]
      var dateNum = target.getUTCDate()
      return dayName + ", " + monthName + " " + dateNum
    } catch (e) {
      return "--"
    }
  }

  function getWorldTime(tz) {
    try {
      var target = getWorldDateObj(tz)
      var h = pad(target.getUTCHours())
      var m = pad(target.getUTCMinutes())
      return h + ":" + m
    } catch (e) {
      return "--:--"
    }
  }

  function getWorldOffset(tz) {
    try {
      var offsetMin = root.getTzOffsetMinutes(tz, root.now)
      var sign = offsetMin >= 0 ? "+" : "-"
      var absMin = Math.abs(offsetMin)
      var h = Math.floor(absMin / 60)
      var m = absMin % 60
      return sign + h + ":" + (m < 10 ? "0" + m : m)
    } catch (e) {
      return "+0:00"
    }
  }

  readonly property var worldTimezones: [
    { name: "UTC", zone: "UTC", city: "Universal Time" },
    { name: "IST", zone: "Asia/Kolkata", city: "Kolkata" },
    { name: "CET", zone: "Europe/Berlin", city: "Berlin" },
    { name: "EST", zone: "America/New_York", city: "New York" },
    { name: "GMT", zone: "Europe/London", city: "London" },
    { name: "JST", zone: "Asia/Tokyo", city: "Tokyo" }
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
                  text: ""
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
                    height: 32
                    radius: 6

                    color: isToday ? Theme.accent :
                           isSelected ? Theme.surfaceActive :
                           isHovered ? Theme.surfaceHover : "transparent"

                    border.color: isToday ? Theme.accentHover :
                                  isSelected ? Theme.borderActive : "transparent"
                    border.width: isSelected || isToday ? 1 : 0

                    Column {
                      anchors.centerIn: parent
                      spacing: 1

                      Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: String(modelData.day)
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.bold: isToday || isSelected

                        color: isToday ? "#121218" :
                               isSelected ? Theme.accent :
                               !isCurrent ? Theme.fgSubtle :
                               isWeekend ? Theme.warning : Theme.fg
                      }

                      Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2
                        visible: modelData.hasEvents

                        Repeater {
                          model: modelData.eventColors
                          delegate: Rectangle {
                            required property var modelData
                            width: 4
                            height: 4
                            radius: 2
                            color: dayCell.isToday ? "#121218" : modelData
                          }
                        }
                      }
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
                height: 26
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
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignVCenter
                  }

                  Text {
                    text: root.formattedSelectedDate
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.bold: true
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    Layout.alignment: Qt.AlignVCenter
                  }

                  Text {
                    text: root.calendarLoading ? "Syncing..." : (root.selectedDayEvents.length + (root.selectedDayEvents.length === 1 ? " event" : " events"))
                    color: root.selectedDayEvents.length > 0 ? Theme.accent : Theme.fgMuted
                    font.family: Theme.font
                    font.pixelSize: 10
                    Layout.alignment: Qt.AlignVCenter
                  }
                }
              }

              // Events List for Selected Day
              Column {
                width: parent.width
                spacing: 6
                visible: root.selectedDayEvents && root.selectedDayEvents.length > 0

                Repeater {
                  model: root.selectedDayEvents
                  delegate: Rectangle {
                    id: eventCard
                    required property var modelData
                    required property int index
                    width: calendarCol.width
                    height: eventLayout.implicitHeight + 16
                    radius: Theme.cardRadius
                    color: Theme.surfaceHover
                    border.color: Theme.border
                    border.width: 1

                    RowLayout {
                      id: eventLayout
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.top: parent.top
                      anchors.margins: 8
                      spacing: 8

                      // Left color strip
                      Rectangle {
                        width: 3
                        Layout.fillHeight: true
                        Layout.minimumHeight: 20
                        radius: 1.5
                        color: modelData.color || Theme.accent
                      }

                      Column {
                        Layout.fillWidth: true
                        spacing: 4

                        RowLayout {
                          width: parent.width
                          spacing: 6

                          // Calendar Tag Badge
                          Rectangle {
                            implicitWidth: calNameText.implicitWidth + 8
                            implicitHeight: 18
                            radius: 3
                            color: Theme.surfaceActive
                            border.color: modelData.color || Theme.accent
                            border.width: 1

                            Text {
                              id: calNameText
                              anchors.centerIn: parent
                              text: modelData.calendar || "Event"
                              color: modelData.color || Theme.accent
                              font.family: Theme.font
                              font.pixelSize: 9
                              font.bold: true
                            }
                          }

                          // Time badge
                          Text {
                            text: "󰥔 " + (modelData.timeStr || "All Day")
                            color: Theme.fgMuted
                            font.family: Theme.font
                            font.pixelSize: 10
                            Layout.fillWidth: true
                          }
                        }

                        // Event Title
                        Text {
                          width: parent.width
                          text: modelData.title || ""
                          color: Theme.fg
                          font.family: Theme.font
                          font.pixelSize: 12
                          font.bold: true
                          wrapMode: Text.Wrap
                        }

                        // Event Location (if available)
                        Text {
                          width: parent.width
                          text: "󰍎 " + modelData.location
                          color: Theme.fgSubtle
                          font.family: Theme.font
                          font.pixelSize: 10
                          visible: modelData.location ? (modelData.location.length > 0) : false
                          elide: Text.ElideRight
                        }
                      }
                    }
                  }
                }
              }

              // Empty state when 0 events
              Rectangle {
                width: parent.width
                height: 28
                radius: Theme.cardRadius
                color: "transparent"
                visible: root.selectedDayEvents.length === 0

                Text {
                  anchors.centerIn: parent
                  text: "No events scheduled for this day"
                  color: Theme.fgSubtle
                  font.family: Theme.font
                  font.pixelSize: 10
                  font.italic: true
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

                Column {
                  Layout.fillWidth: true
                  spacing: 2
                  Layout.alignment: Qt.AlignVCenter

                  Text {
                    text: modelData.name + " • " + modelData.city
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                  }

                  Text {
                    text: root.getWorldOffset(modelData.zone)
                    color: Theme.fgMuted
                    font.family: Theme.font
                    font.pixelSize: 10
                  }
                }

                Text {
                  text: root.getWorldDate(modelData.zone)
                  color: Theme.fgMuted
                  font.family: Theme.font
                  font.pixelSize: 10
                  Layout.alignment: Qt.AlignVCenter
                }

                Text {
                  text: root.getWorldTime(modelData.zone)
                  color: Theme.accent
                  font.family: Theme.font
                  font.pixelSize: 18
                  font.bold: true
                  Layout.alignment: Qt.AlignVCenter
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

  // Calendar fetch process
  Process {
    id: calendarProc
    command: ["bash", "-lc", "python3 /home/aayush/dotfiles/.config/quickshell/scripts/fetch_calendar.py"]
    stdout: StdioCollector {
      id: calendarCollector
      waitForEnd: true
      onStreamFinished: {
        root.calendarLoading = false
        var raw = String(calendarCollector.text || "").trim()
        if (!raw) {
          root.calendarEvents = []
          root.updateCalendarModel()
          return
        }
        try {
          var data = JSON.parse(raw)
          root.calendarEvents = Array.isArray(data) ? data : []
          root.calendarError = ""
        } catch (e) {
          root.calendarError = "Failed to parse calendar events"
        }
        root.updateCalendarModel()
      }
    }
    stderr: StdioCollector {
      id: calendarErrCollector
      waitForEnd: true
      onStreamFinished: {
        root.calendarLoading = false
        var errText = String(calendarErrCollector.text || "").trim()
        if (errText) {
          console.log("[CALENDAR SYNC STDERR]:", errText)
        }
      }
    }
  }

  // Periodic Calendar sync timer (every 15 minutes)
  Timer {
    interval: 900000
    running: root.opened
    repeat: true
    onTriggered: root.fetchCalendar()
  }

  Component.onCompleted: {
    root.refresh()
  }
}
