import QtQuick
import "."

Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property real stepSize: 0.01
    signal moved(real val)

    implicitWidth: 200
    implicitHeight: 22

    readonly property real liveValue: sliderMouse.pressed ? internalDragValue : root.value
    property real internalDragValue: root.value

    readonly property real normalizedValue: {
        var span = root.to - root.from
        if (span <= 0) return 0
        return Math.max(0, Math.min(1, (root.liveValue - root.from) / span))
    }

    Rectangle {
        id: trackBg
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: 3
        color: Theme.surfaceHover
        border.color: Theme.border
        border.width: 1

        Rectangle {
            id: trackFill
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(0, Math.min(parent.width, parent.width * root.normalizedValue))
            radius: 3
            color: Theme.accent
        }
    }

    Rectangle {
        id: handle
        width: 14
        height: 14
        radius: 7
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(root.width - width, (root.width - width) * root.normalizedValue))
        color: "#ffffff"
        border.color: sliderMouse.containsMouse || sliderMouse.pressed ? Theme.accent : Theme.border
        border.width: 2
        scale: sliderMouse.pressed ? 1.15 : sliderMouse.containsMouse ? 1.1 : 1.0

        Behavior on scale {
            NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
        }
    }

    MouseArea {
        id: sliderMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function updateFromMouse(mouseX) {
            var padding = handle.width / 2
            var availableWidth = root.width - handle.width
            if (availableWidth <= 0) return
            var ratio = Math.max(0, Math.min(1, (mouseX - padding) / availableWidth))
            var rawValue = root.from + ratio * (root.to - root.from)
            if (root.stepSize > 0) {
                rawValue = Math.round(rawValue / root.stepSize) * root.stepSize
            }
            rawValue = Math.max(root.from, Math.min(root.to, rawValue))
            root.internalDragValue = rawValue
            root.moved(rawValue)
        }

        onPressed: function(mouse) {
            updateFromMouse(mouse.x)
        }

        onPositionChanged: function(mouse) {
            if (pressed) {
                updateFromMouse(mouse.x)
            }
        }
    }
}

