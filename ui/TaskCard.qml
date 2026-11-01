import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

// One task of the day. Batches (lectures, topics) expand into their items, each tickable.
Rectangle {
    id: card
    property var task
    property int order: 0
    property bool expanded: false
    readonly property bool done: task.status === "done"
    readonly property bool focused: Store.s && Store.s.pomo && Store.s.pomo.task === task.id && Store.s.pomo.phase !== "idle"
    signal sparked(real x, real y, color c)

    implicitHeight: col.implicitHeight + 24
    radius: 16
    color: focused ? Theme.mix(Theme.surface2, task.color, 0.14) : (hover.hovered ? Theme.surface2 : Theme.surface)
    border.width: focused || hover.hovered ? 1 : 0
    border.color: focused ? task.color : Theme.outline
    Behavior on color { ColorAnimation { duration: Theme.dur(160) } }

    // entrance: fade + rise, staggered by position
    opacity: 0
    transform: Translate { id: shift; y: 18 }
    Component.onCompleted: enter.start()
    SequentialAnimation {
        id: enter
        PauseAnimation { duration: Theme.dur(Math.min(card.order, 10) * 45) }
        ParallelAnimation {
            NumberAnimation { target: card; property: "opacity"; to: card.done ? 0.6 : 1; duration: Theme.dur(280) }
            NumberAnimation { target: shift; property: "y"; to: 0; duration: Theme.dur(380); easing.type: Easing.OutCubic }
        }
    }
    onDoneChanged: if (!enter.running) fade.restart()
    NumberAnimation { id: fade; target: card; property: "opacity"; to: card.done ? 0.6 : 1; duration: Theme.dur(400) }

    // glow when focused
    layer.enabled: focused
    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: card.task.color; shadowBlur: 0.7; shadowOpacity: 0.5 }

    HoverHandler { id: hover }

    function toggle() {
        const finishing = !(done || task.status === "partial")
        if (finishing) {
            const p = check.mapToItem(null, check.width / 2, check.height / 2)
            sparked(p.x, p.y, task.color)
        }
        Store.run([finishing ? "done" : "undo", task.id])
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; leftMargin: 14 }
        spacing: 6

        RowLayout {
            spacing: 12
            Layout.fillWidth: true

            Check {
                id: check
                state_: card.task.status === "skipped" ? "todo" : card.task.status
                tint: card.task.color
                onToggled: card.toggle()
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
                    Repeater {
                        model: Math.min(card.task.pomos, 8)
                        delegate: Icon { name: "timer"; size: 13; color: card.task.color }
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

            IconBtn {
                visible: card.task.sub_items.length > 0
                icon: card.expanded ? "expand_less" : "expand_more"
                tint: Theme.textDim
                onClicked: card.expanded = !card.expanded
            }
            IconBtn {
                visible: !card.done && card.task.track !== "dated"
                icon: card.focused ? "stop" : "play_arrow"
                tint: card.task.color
                filled: card.focused
                onClicked: Store.run(card.focused ? ["pomo", "stop"] : ["pomo", "start", card.task.id])
            }
        }

        // expanded batch items
        Repeater {
            model: card.expanded ? card.task.sub_items : []
            delegate: RowLayout {
                id: sub
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.leftMargin: 38
                spacing: 10
                opacity: 0
                Component.onCompleted: subIn.start()
                SequentialAnimation {
                    id: subIn
                    PauseAnimation { duration: Theme.dur(sub.index * 25) }
                    NumberAnimation { target: sub; property: "opacity"; to: 1; duration: Theme.dur(180) }
                }
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
