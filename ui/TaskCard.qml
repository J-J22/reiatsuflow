import QtQuick
import QtQuick.Layouts

// One task of the day. Batches (lectures, topics) expand into their items, each tickable.
Rectangle {
    id: card
    property var task
    property bool expanded: false
    readonly property bool done: task.status === "done"
    readonly property bool focused: Store.s && Store.s.pomo && Store.s.pomo.task === task.id && Store.s.pomo.phase !== "idle"

    implicitHeight: col.implicitHeight + 24
    radius: 14
    color: focused ? Theme.mix(Theme.surface2, task.color, 0.12) : (hover.hovered ? Theme.surface2 : Theme.surface)
    border.width: focused ? 1 : 0
    border.color: task.color
    opacity: done ? 0.62 : 1
    Behavior on opacity { NumberAnimation { duration: 160 } }

    HoverHandler { id: hover }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; leftMargin: 14 }
        spacing: 6

        RowLayout {
            spacing: 12
            Layout.fillWidth: true

            Check {
                state_: card.task.status === "skipped" ? "todo" : card.task.status
                tint: card.task.color
                onToggled: Store.run([card.done || card.task.status === "partial" ? "undo" : "done", card.task.id])
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    spacing: 8
                    Rectangle {
                        radius: 6; implicitHeight: 20; implicitWidth: chip.implicitWidth + 14
                        color: Theme.mix(Theme.surface, card.task.color, 0.22)
                        Text {
                            id: chip; anchors.centerIn: parent
                            text: card.task.track_name
                            color: card.task.color
                            font.family: Theme.ui; font.pixelSize: 11; font.weight: Font.DemiBold
                        }
                    }
                    Text {
                        visible: card.task.pomos > 0
                        text: "● ".repeat(Math.min(card.task.pomos, 8)).trim()
                        color: card.task.color
                        font.pixelSize: 9
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: card.task.title
                    color: Theme.text
                    font.family: Theme.ui; font.pixelSize: 15; font.weight: Font.Medium
                    font.strikeout: card.done
                    wrapMode: Text.Wrap
                }
                Text {
                    Layout.fillWidth: true
                    text: card.task.sub
                    color: Theme.textDim
                    font.family: Theme.ui; font.pixelSize: 12
                    wrapMode: Text.Wrap
                    maximumLineCount: card.expanded ? 6 : 2
                    elide: Text.ElideRight
                }
            }

            Btn {
                visible: card.task.sub_items.length > 0
                label: card.expanded ? "▴" : card.task.sub_items.length + " ▾"
                onClicked: card.expanded = !card.expanded
            }
            Btn {
                visible: !card.done && card.task.track !== "dated"
                label: card.focused ? "■" : "▶"
                active: card.focused
                tint: card.task.color
                onClicked: Store.run(card.focused ? ["pomo", "stop"] : ["pomo", "start", card.task.id])
            }
        }

        // expanded batch items
        Repeater {
            model: card.expanded ? card.task.sub_items : []
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                Layout.leftMargin: 38
                spacing: 10
                Check {
                    size: 18
                    state_: modelData.done ? "done" : "todo"
                    tint: card.task.color
                    onToggled: Store.run(["item", card.task.id, modelData.id])
                }
                Text {
                    Layout.fillWidth: true
                    text: modelData.title
                    color: modelData.done ? Theme.textDim : Theme.text
                    font.family: Theme.ui; font.pixelSize: 13
                    font.strikeout: modelData.done
                    elide: Text.ElideRight
                }
                Text {
                    text: modelData.sub
                    color: Theme.textDim
                    font.family: Theme.mono; font.pixelSize: 11
                }
            }
        }
    }
}
