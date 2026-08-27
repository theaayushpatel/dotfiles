import QtQuick
import "."

Item {
    id: root

    property bool checked: false
    property bool interactive: true
    signal toggled(bool checked)

    implicitWidth: 38
    implicitHeight: 20

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.surfaceHover
        border.color: root.checked ? Theme.accentHover : Theme.border
        border.width: 1

        Behavior on color {
            ColorAnimation { duration: 150; easing.type: Easing.OutQuad }
        }
        Behavior on border.color {
            ColorAnimation { duration: 150; easing.type: Easing.OutQuad }
        }

        Rectangle {
            id: thumb
            width: parent.height - 6
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? (parent.width - width - 3) : 3
            color: root.checked ? "#ffffff" : Theme.fgMuted

            Behavior on x {
                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
            }
            Behavior on color {
                ColorAnimation { duration: 150; easing.type: Easing.OutQuad }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.toggled(!root.checked)
        }
    }
}

