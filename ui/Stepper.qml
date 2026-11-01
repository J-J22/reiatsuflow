import QtQuick
import QtQuick.Layouts

// − value + ; zero shows as a dim dash so a week grid reads at a glance.
Rectangle {
    id: s
    property int value: 0
    property int from: 0
    property int to: 99
    property int step: 1
    property string suffix: ""
    property color tint: Theme.accent
    property bool compact: false
    signal changed(int value)
    implicitWidth: row.implicitWidth + 8
    implicitHeight: compact ? 32 : 36
    radius: height / 2
    color: s.value > 0 ? Theme.mix(Theme.surface2, s.tint, 0.18) : Theme.surface2
    Behavior on color { ColorAnimation { duration: 140 } }
    // emits only: the owner writes the new value to its data and the binding brings it back
    function set(v) { v = Math.max(from, Math.min(to, v)); if (v !== value) changed(v) }
    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 2
        Repeater {
            model: [-1, 0, 1]
            delegate: Item {
                required property int modelData
                implicitWidth: modelData === 0 ? Math.max(s.compact ? 18 : 26, lbl.implicitWidth + 4) : (s.compact ? 22 : 26)
                implicitHeight: s.implicitHeight
                Text {
                    id: lbl
                    anchors.centerIn: parent
                    text: modelData === 0 ? (s.value === 0 && s.suffix === "" ? "–" : s.value + s.suffix)
                                          : (modelData < 0 ? "−" : "+")
                    color: modelData === 0 ? (s.value > 0 ? s.tint : Theme.textDim) : (h.hovered ? Theme.text : Theme.textDim)
                    font.family: modelData === 0 ? Theme.pixel : Theme.ui
                    font.pixelSize: modelData === 0 ? (s.compact ? 10 : 11) : 16
                    scale: modelData === 0 && bump.running ? 1.25 : 1
                    Behavior on scale { NumberAnimation { duration: 120 } }
                }
                HoverHandler { id: h; enabled: modelData !== 0; cursorShape: Qt.PointingHandCursor }
                TapHandler { enabled: modelData !== 0; onTapped: { s.set(s.value + modelData * s.step); bump.restart() } }
            }
        }
    }
    Timer { id: bump; interval: 140 }
}
