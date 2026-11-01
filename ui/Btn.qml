import QtQuick

// Small pill button. `primary` fills it with the accent colour.
Rectangle {
    id: btn
    property string label: ""
    property bool primary: false
    property bool active: false
    property color tint: Theme.accent
    signal clicked()

    implicitWidth: txt.implicitWidth + 28
    implicitHeight: 34
    radius: height / 2
    color: primary || active ? tint : (hover.hovered ? Theme.surface3 : Theme.surface2)
    border.width: primary || active ? 0 : 1
    border.color: Theme.outline
    Behavior on color { ColorAnimation { duration: Theme.dur(120) } }

    Text {
        id: txt
        anchors.centerIn: parent
        text: btn.label
        color: btn.primary || btn.active ? Theme.inkAccent : Theme.text
        font.family: Theme.ui
        font.pixelSize: 13
        font.weight: Font.Medium
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: btn.clicked() }
}
