import QtQuick

// Single-line text input. `mask` for dates/times, `placeholder` when empty.
Rectangle {
    id: f
    property alias text: input.text
    property string placeholder: ""
    property string mask: ""
    property bool mono: false
    property bool compact: false
    signal edited(string text)
    implicitWidth: 220
    implicitHeight: 38
    radius: 10
    color: Theme.surface2
    border.width: 1
    border.color: input.activeFocus ? Theme.accent : Theme.outline
    Behavior on border.color { ColorAnimation { duration: 120 } }
    TextInput {
        id: input
        anchors { fill: parent; leftMargin: f.compact ? 6 : 12; rightMargin: f.compact ? 6 : 12 }
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.inkAccent
        font.family: f.mono ? Theme.mono : Theme.ui
        font.pixelSize: f.compact ? 12 : 14
        horizontalAlignment: f.compact ? TextInput.AlignHCenter : TextInput.AlignLeft
        clip: true
        inputMask: f.mask
        onTextEdited: f.edited(text)
        Text {
            visible: !parent.text && !parent.activeFocus
            anchors.verticalCenter: parent.verticalCenter
            text: f.placeholder
            color: Theme.textDim
            opacity: 0.7
            font: parent.font
        }
    }
}
