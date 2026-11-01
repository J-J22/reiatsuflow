import QtQuick
import QtQuick.Layouts

// Switch with a label.
RowLayout {
    id: t
    property bool checked: false
    property string label: ""
    property string hint: ""
    signal toggled(bool checked)
    spacing: 12
    Rectangle {
        implicitWidth: 44; implicitHeight: 24; radius: 12
        color: t.checked ? Theme.accent : Theme.surface3
        Behavior on color { ColorAnimation { duration: Theme.dur(150) } }
        Rectangle {
            width: 18; height: 18; radius: 9; y: 3
            x: t.checked ? 23 : 3
            color: t.checked ? Theme.inkAccent : Theme.textDim
            Behavior on x { NumberAnimation { duration: Theme.dur(180); easing.type: Easing.OutBack } }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: t.toggled(!t.checked) }  // owner updates `checked` through its binding
    }
    ColumnLayout {
        spacing: 1
        Layout.fillWidth: true
        Text { text: t.label; color: Theme.text; font.family: Theme.ui; font.pixelSize: 14 }
        Text {
            visible: t.hint !== ""; text: t.hint; color: Theme.textDim
            font.family: Theme.ui; font.pixelSize: 12; wrapMode: Text.Wrap; Layout.fillWidth: true
        }
    }
}
