import QtQuick
import QtQuick.Layouts

// First launch: no tracks yet. Pick a template (opens Settings) or let your AI agent set it up.
Item {
    id: ob
    signal pickTemplate(string key)
    signal agentSetup()
    property string agentLabel: "Claude Code"
    readonly property var templates: [
        { key: "course", icon: "play_lesson", label: "Course", color: "#ff9f43", text: "Videos or lessons, ~40 minutes a day" },
        { key: "studies", icon: "school", label: "Studies", color: "#6ea8fe", text: "Subjects and units, rotating daily" },
        { key: "project", icon: "rocket_launch", label: "Project", color: "#f687b3", text: "Milestones, one at a time" },
        { key: "custom", icon: "tune", label: "Custom", color: "#68d391", text: "Any list, your rules" }
    ]
    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width, 900)
        spacing: 22
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Let's set up your flow"
            color: Theme.text; font.family: Theme.ui; font.pixelSize: 30; font.weight: Font.Medium
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: 620
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: "ReiatsuFlow turns your lists into a few tasks a day. Add a track for each thing you're working on. You can add more later from the settings icon."
            color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 15
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: 14
            Repeater {
                model: ob.templates
                delegate: Rectangle {
                    id: c
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: 190
                    radius: 22
                    color: h.hovered ? Theme.mix(Theme.surface, modelData.color, 0.16) : Theme.surface
                    border.width: h.hovered ? 1 : 0
                    border.color: modelData.color
                    opacity: 0
                    transform: Translate { id: tr; y: 24 }
                    Component.onCompleted: enter.start()
                    SequentialAnimation {
                        id: enter
                        PauseAnimation { duration: Theme.dur(120 + c.index * 90) }
                        ParallelAnimation {
                            NumberAnimation { target: c; property: "opacity"; to: 1; duration: Theme.dur(350) }
                            NumberAnimation { target: tr; property: "y"; to: 0; duration: Theme.dur(450); easing.type: Easing.OutBack }
                        }
                    }
                    Behavior on color { ColorAnimation { duration: Theme.dur(150) } }
                    ColumnLayout {
                        anchors { fill: parent; margins: 20 }
                        spacing: 8
                        Icon {
                            name: c.modelData.icon; size: 40; color: Theme.tc(c.modelData.color)
                            scale: h.hovered ? 1.15 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.dur(200); easing.type: Easing.OutBack } }
                        }
                        Item { Layout.fillHeight: true }
                        Text { text: c.modelData.label; color: Theme.text; font.family: Theme.ui; font.pixelSize: 19; font.weight: Font.Medium }
                        Text { text: c.modelData.text; color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 13; wrapMode: Text.Wrap; Layout.fillWidth: true }
                    }
                    HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: ob.pickTemplate(c.modelData.key) }
                }
            }
        }
        RowLayout {
            visible: ob.agentLabel !== ""
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            Text { text: "Rather describe it?"; color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 14 }
            Btn { label: "✦  Set up with " + ob.agentLabel; onClicked: ob.agentSetup() }
        }
    }
}
