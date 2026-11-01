import QtQuick
import QtQuick.Layouts

// Segmented choice: options = [{key, label}], current = key.
RowLayout {
    id: c
    property var options: []
    property var current
    property color tint: Theme.accent
    signal picked(var key)
    spacing: 6
    Repeater {
        model: c.options
        delegate: Btn {
            required property var modelData
            label: modelData.label
            active: c.current === modelData.key
            tint: c.tint
            onClicked: c.picked(modelData.key)
        }
    }
}
