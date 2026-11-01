import QtQuick
import QtQuick.Layouts

// Settings → Week: tracks × days grid of "tasks per day", day labels and routines.
Flickable {
    id: page
    readonly property var d: Cfg.draft
    readonly property var ids: d ? Object.keys(d.tracks) : []
    property string routineDay: ""
    contentHeight: col.implicitHeight + 20
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    function total(day) {
        let n = 0
        for (const id of ids) n += (d.week[day].load[id] || 0)
        return n + (d.week[day].routines || []).length
    }

    ColumnLayout {
        id: col
        width: page.width
        spacing: 14

        Text { text: "Your week"; color: Theme.text; font.family: Theme.ui; font.pixelSize: 20; font.weight: Font.Medium }
        Text {
            Layout.fillWidth: true; wrapMode: Text.Wrap
            text: "How many tasks each track gets on each day. A task is one chunk of that track (set on the Tracks page). Phases can override this for date ranges."
            color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 13
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 8
            columnSpacing: 6
            rowSpacing: 8

            Item { implicitWidth: 150; implicitHeight: 1 }
            Repeater {
                model: Cfg.dayNames
                delegate: Text {
                    required property string modelData
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData.toUpperCase()
                    color: Theme.textDim; font.family: Theme.pixel; font.pixelSize: 9
                }
            }

            Repeater {
                model: page.ids.length * 8
                delegate: Item {
                    id: cell
                    required property int index
                    readonly property string tid: page.ids[Math.floor(index / 8)]
                    readonly property int col: index % 8
                    readonly property var tr: page.d.tracks[tid]
                    Layout.fillWidth: col > 0
                    implicitWidth: col === 0 ? 150 : st.implicitWidth
                    implicitHeight: 34
                    RowLayout {
                        visible: cell.col === 0
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Rectangle { implicitWidth: 10; implicitHeight: 10; radius: 5; color: cell.tr ? Theme.tc(cell.tr.color) : "gray" }
                        Text {
                            text: cell.tr ? cell.tr.name : ""; color: Theme.text; elide: Text.ElideRight; Layout.maximumWidth: 125
                            font.family: Theme.ui; font.pixelSize: 13
                        }
                    }
                    Stepper {
                        id: st
                        visible: cell.col > 0
                        anchors.centerIn: parent
                        compact: true
                        tint: cell.tr ? Theme.tc(cell.tr.color) : Theme.accent
                        to: 9
                        value: cell.col > 0 && cell.tr ? (page.d.week[Cfg.days[cell.col - 1]].load[cell.tid] || 0) : 0
                        onChanged: v => Cfg.edit(dd => { dd.week[Cfg.days[cell.col - 1]].load[cell.tid] = v })
                    }
                }
            }

            // totals
            Text { text: "Tasks"; color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 12 }
            Repeater {
                model: Cfg.days
                delegate: Text {
                    required property string modelData
                    Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                    text: page.d ? page.total(modelData) : ""
                    color: Theme.text; font.family: Theme.pixel; font.pixelSize: 11
                }
            }
            // labels
            Text { text: "Day name"; color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 12 }
            Repeater {
                model: Cfg.days
                delegate: Field {
                    required property string modelData
                    Layout.fillWidth: true
                    implicitWidth: 60
                    implicitHeight: 32
                    compact: true
                    placeholder: "—"
                    text: page.d ? (page.d.week[modelData].label || "") : ""
                    onEdited: x => Cfg.edit(dd => { if (x) dd.week[modelData].label = x; else delete dd.week[modelData].label })
                }
            }
            // routines
            Text { text: "Routines"; color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 12 }
            Repeater {
                model: Cfg.days
                delegate: Btn {
                    required property string modelData
                    Layout.fillWidth: true
                    readonly property int n: page.d ? (page.d.week[modelData].routines || []).length : 0
                    label: n ? n + "" : "+"
                    active: page.routineDay === modelData
                    onClicked: page.routineDay = page.routineDay === modelData ? "" : modelData
                }
            }
        }

        Text {
            visible: page.ids.length === 0
            text: "Add a track first (Tracks page)."
            color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 13
        }

        ColumnLayout {
            visible: page.routineDay !== ""
            Layout.fillWidth: true
            spacing: 6
            Text {
                text: "Routines on " + (page.routineDay ? Cfg.dayNames[Cfg.days.indexOf(page.routineDay)] : "") + " (one per line): fixed tasks like “Weekly review”"
                color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 12
            }
            Area {
                id: routines
                Layout.fillWidth: true
                implicitHeight: 110
                text: page.routineDay && page.d ? (page.d.week[page.routineDay].routines || []).join("\n") : ""
                onEdited: {
                    const lines = text.split("\n").map(x => x.trim()).filter(x => x)
                    const day = page.routineDay
                    Cfg.edit(dd => { if (lines.length) dd.week[day].routines = lines; else delete dd.week[day].routines })
                }
            }
        }
    }
}
