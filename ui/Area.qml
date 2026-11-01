import QtQuick

// Multi-line text area (paste a list here).
Rectangle {
    id: a
    property alias text: edit.text
    property string placeholder: ""
    signal edited()
    implicitHeight: 200
    radius: 12
    color: Theme.surface2
    border.width: 1
    border.color: edit.activeFocus ? Theme.accent : Theme.outline
    Flickable {
        id: flick
        anchors { fill: parent; margins: 12 }
        contentHeight: edit.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        TextEdit {
            id: edit
            width: flick.width
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.inkAccent
            font.family: Theme.mono
            font.pixelSize: 13
            wrapMode: TextEdit.Wrap
            onTextChanged: if (activeFocus) a.edited()
            onCursorRectangleChanged: {
                if (cursorRectangle.y < flick.contentY) flick.contentY = cursorRectangle.y
                else if (cursorRectangle.y + cursorRectangle.height > flick.contentY + flick.height)
                    flick.contentY = cursorRectangle.y + cursorRectangle.height - flick.height
            }
            Text {
                visible: !parent.text
                text: a.placeholder
                color: Theme.textDim
                opacity: 0.6
                font: parent.font
                width: parent.width
                wrapMode: Text.Wrap
            }
        }
    }
}
