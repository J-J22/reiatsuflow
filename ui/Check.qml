import QtQuick

// Round check: empty ring = todo, half = partly done, filled with a tick = done.
Item {
    id: root
    property string state_: "todo"
    property color tint: Theme.accent
    property int size: 26
    signal toggled()

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.state_ === "done" ? root.tint : "transparent"
        border.width: 2
        border.color: root.state_ === "todo" && !hover.hovered ? Theme.outline : root.tint
        Behavior on color { ColorAnimation { duration: 140 } }

        Rectangle {  // partial: left half filled
            visible: root.state_ === "partial"
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 4 }
            width: (parent.width - 8) / 2
            radius: width
            color: root.tint
        }
        Text {
            visible: root.state_ === "done"
            anchors.centerIn: parent
            text: "✓"
            color: Theme.inkAccent
            font.pixelSize: root.size * 0.6
            font.bold: true
        }
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.toggled() }
}
