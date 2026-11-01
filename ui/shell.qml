// ReiatsuFlow: task-based study planner. Run with `qs -p <this dir>` (or `qs -c reiatsuflow`
// once linked into ~/.config/quickshell). All data comes from the `rf` CLI; see the README.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    FloatingWindow {
        id: win
        title: "ReiatsuFlow"
        implicitWidth: 1180
        implicitHeight: 760
        color: Theme.bg

        property int tab: 0
        readonly property var s: Store.s

        // `qs ipc call reiatsuflow tab 1` etc.
        IpcHandler {
            target: "reiatsuflow"
            function tab(n: int): void { win.tab = n }
            function refresh(): void { Store.refresh() }
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                if (e.key >= Qt.Key_1 && e.key <= Qt.Key_4) win.tab = e.key - Qt.Key_1
                else if (e.key === Qt.Key_R) Store.refresh()
            }
        }

        ColumnLayout {
            anchors { fill: parent; margins: 26 }
            spacing: 18

            // ── header ─────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                Row {
                    spacing: 0
                    Text { text: "REIATSU"; color: Theme.text; font.family: Theme.pixel; font.pixelSize: 22 }
                    Text { text: "FLOW"; color: Theme.accent; font.family: Theme.pixel; font.pixelSize: 22 }
                }
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: win.s ? new Date(win.s.date + "T12:00:00").toLocaleDateString(Qt.locale("en_GB"), "dddd d MMMM") : "…"
                        color: Theme.text; font.family: Theme.ui; font.pixelSize: 15; font.weight: Font.Medium
                    }
                    Text {
                        text: win.s ? win.s.rule + (win.s.mode === "low" ? " · low-energy day" : "") : ""
                        color: win.s && win.s.mode === "low" ? Theme.accent : Theme.textDim
                        font.family: Theme.ui; font.pixelSize: 12
                    }
                }
                Item { Layout.fillWidth: true }
                ColumnLayout {
                    spacing: 0
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: win.s ? win.s.done + "/" + win.s.total : "-"
                        color: Theme.text; font.family: Theme.pixel; font.pixelSize: 16
                    }
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: "today"; color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 11
                    }
                }
                ColumnLayout {
                    spacing: 0
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: win.s ? win.s.streak : "-"
                        color: Theme.accent; font.family: Theme.pixel; font.pixelSize: 16
                    }
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: "day streak"; color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 11
                    }
                }
                Btn {
                    label: win.s && win.s.mode === "low" ? "Normal day" : "Low-energy day"
                    active: win.s && win.s.mode === "low"
                    onClicked: Store.run(["low", win.s.mode === "low" ? "off" : "on"])
                }
                Btn {
                    label: "Review with Claude"
                    primary: true
                    onClicked: Store.run(["review"])
                }
            }

            // ── tabs ───────────────────────────────────────────
            RowLayout {
                spacing: 8
                Repeater {
                    model: ["Today", "Week", "Tracks", "Missed"]
                    delegate: Btn {
                        required property string modelData
                        required property int index
                        label: modelData + (index === 3 && win.s && win.s.missed.length ? "  " + win.s.missed.length : "")
                        active: win.tab === index
                        tint: index === 3 && win.s && win.s.missed.length ? Theme.danger : Theme.accent
                        onClicked: win.tab = index
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    visible: Store.error !== ""
                    text: Store.error
                    color: Theme.danger; font.family: Theme.mono; font.pixelSize: 11
                    elide: Text.ElideLeft; Layout.maximumWidth: 520
                }
            }

            // ── views ──────────────────────────────────────────
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: win.tab

                // Today
                RowLayout {
                    spacing: 20
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: list.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ColumnLayout {
                            id: list
                            width: parent.width
                            spacing: 10
                            Repeater {
                                model: win.s ? win.s.tasks : []
                                delegate: TaskCard {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    task: modelData
                                }
                            }
                            Text {
                                visible: win.s && win.s.tasks.length === 0
                                text: "Nothing planned today."
                                color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 15
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.preferredWidth: 330
                        Layout.maximumWidth: 330
                        Layout.fillHeight: true
                        spacing: 16
                        Pomodoro { Layout.fillWidth: true }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 18
                            color: Theme.surface
                            ColumnLayout {
                                anchors { fill: parent; margins: 18 }
                                spacing: 14
                                Text { text: "PACE"; color: Theme.textDim; font.family: Theme.pixel; font.pixelSize: 10 }
                                Repeater {
                                    model: win.s ? win.s.tracks.filter(t => t.active && t.pace) : []
                                    delegate: TrackRow {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        track: modelData
                                    }
                                }
                                Item { Layout.fillHeight: true }
                            }
                        }
                    }
                }

                // Week
                WeekView {}

                // Tracks
                Flickable {
                    contentHeight: tracksCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    GridLayout {
                        id: tracksCol
                        width: parent.width
                        columns: 2
                        columnSpacing: 14
                        rowSpacing: 14
                        Repeater {
                            model: win.s ? win.s.tracks : []
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: tr.implicitHeight + 32
                                radius: 16
                                color: Theme.surface
                                TrackRow {
                                    id: tr
                                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                                    track: modelData
                                    detailed: true
                                }
                            }
                        }
                    }
                }

                // Missed
                Flickable {
                    contentHeight: missed.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    MissedView { id: missed; width: parent.width }
                }
            }
        }
    }
}
