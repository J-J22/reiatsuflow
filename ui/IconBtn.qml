import QtQuick

// Round icon button with a hover halo.
Rectangle {
    id: b
    property string icon: ""
    property string tip: ""
    property color tint: Theme.text
    property bool filled: false
    signal clicked()
    implicitWidth: 38
    implicitHeight: 38
    radius: width / 2
    color: filled ? tint : (hover.hovered ? Theme.surface3 : "transparent")
    scale: tap.pressed ? 0.9 : 1
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 90 } }
    Icon {
        anchors.centerIn: parent
        name: b.icon
        size: 21
        color: b.filled ? Theme.inkAccent : b.tint
        rotation: hover.hovered && b.icon === "settings" ? 60 : 0
        Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; onTapped: b.clicked() }
}
