import QtQuick
import QtQuick.Layouts

// Monday–Sunday: what happened on past days, today, and what's queued for the rest of the week.
RowLayout {
    id: week
    spacing: 10

    Repeater {
        model: Store.s ? Store.s.week : []
        delegate: Rectangle {
            id: dayCard
            required property var modelData
            required property int index
            opacity: 0
            transform: Translate { id: rise; y: 20 }
            Component.onCompleted: enter.start()
            SequentialAnimation {
                id: enter
                PauseAnimation { duration: dayCard.index * 50 }
                ParallelAnimation {
                    NumberAnimation { target: dayCard; property: "opacity"; to: 1; duration: 260 }
                    NumberAnimation { target: rise; property: "y"; to: 0; duration: 360; easing.type: Easing.OutCubic }
                }
            }
            readonly property bool today: modelData.kind === "today"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            radius: 14
            color: today ? Theme.surface2 : Theme.surface
            border.width: today ? 1 : 0
            border.color: Theme.accent

            ColumnLayout {
                anchors { fill: parent; margins: 12 }
                spacing: 6
                Text {
                    text: dayCard.modelData.dow.toUpperCase()
                    color: dayCard.today ? Theme.accent : Theme.textDim
                    font.family: Theme.pixel; font.pixelSize: 10
                }
                Text {
                    text: dayCard.modelData.date.slice(8) + " · " + dayCard.modelData.rule
                    color: Theme.textDim
                    font.family: Theme.ui; font.pixelSize: 11
                    elide: Text.ElideRight; Layout.fillWidth: true
                }
                Text {
                    text: dayCard.modelData.kind === "future" ? dayCard.modelData.planned + " planned"
                          : dayCard.modelData.done + " / " + dayCard.modelData.planned
                    color: Theme.text
                    font.family: Theme.ui; font.pixelSize: 16; font.weight: Font.Medium
                }
                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outline }
                Repeater {
                    model: dayCard.modelData.tasks
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 6
                        Rectangle {
                            implicitWidth: 8; implicitHeight: 8; radius: 4
                            readonly property var tr: Store.s.tracks.find(t => t.id === modelData.track)
                            color: modelData.status === "done" ? (tr ? tr.color : Theme.textDim) : "transparent"
                            border.width: 1.5
                            border.color: tr ? tr.color : Theme.textDim
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.title
                            color: modelData.status === "skipped" ? Theme.textDim : Theme.text
                            opacity: modelData.status === "skipped" ? 0.6 : 1
                            font.family: Theme.ui; font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
    }
}
