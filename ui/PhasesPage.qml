import QtQuick
import QtQuick.Layouts

// Settings → Phases: date ranges (exam fortnight, holidays) with their own daily load.
Flickable {
    id: page
    readonly property var d: Cfg.draft
    readonly property var ids: d ? Object.keys(d.tracks) : []
    contentHeight: col.implicitHeight + 20
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    function setPh(i, key, value) { Cfg.edit(dd => { if (value === null || value === "") delete dd.phases[i][key]; else dd.phases[i][key] = value }) }

    ColumnLayout {
        id: col
        width: page.width
        spacing: 14
        Text { text: "Phases"; color: Theme.text; font.family: Theme.ui; font.pixelSize: 20; font.weight: Font.Medium }
        Text {
            Layout.fillWidth: true; wrapMode: Text.Wrap
            text: "A phase replaces the week grid between two dates, e.g. “Exams: semester only” or “Holidays: double course”. The first matching phase wins."
            color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 13
        }

        Repeater {
            model: page.d ? page.d.phases.length : 0
            delegate: Rectangle {
                id: card
                required property int index
                readonly property var ph: page.d.phases[index]
                Layout.fillWidth: true
                implicitHeight: pc.implicitHeight + 32
                radius: 16
                color: Theme.surface2
                ColumnLayout {
                    id: pc
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 10
                    RowLayout {
                        spacing: 10
                        Field { Layout.fillWidth: true; placeholder: "Phase name"; text: card.ph.name || ""; onEdited: x => page.setPh(card.index, "name", x) }
                        Field { implicitWidth: 140; mono: true; placeholder: "from YYYY-MM-DD"; text: card.ph.from || ""; onEdited: x => page.setPh(card.index, "from", x) }
                        Field { implicitWidth: 140; mono: true; placeholder: "to YYYY-MM-DD"; text: card.ph.to || ""; onEdited: x => page.setPh(card.index, "to", x) }
                        IconBtn { icon: "delete"; tint: Theme.danger; onClicked: Cfg.edit(dd => dd.phases.splice(card.index, 1)) }
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 10
                        Repeater {
                            model: page.ids
                            delegate: RowLayout {
                                required property string modelData
                                readonly property var tr: page.d.tracks[modelData]
                                spacing: 6
                                Rectangle { implicitWidth: 8; implicitHeight: 8; radius: 4; color: Theme.tc(tr.color) }
                                Text { text: tr.name; color: Theme.text; font.family: Theme.ui; font.pixelSize: 12 }
                                Stepper {
                                    compact: true; to: 9; tint: Theme.tc(tr.color)
                                    value: (card.ph.load || {})[modelData] || 0
                                    onChanged: v => Cfg.edit(dd => { dd.phases[card.index].load = dd.phases[card.index].load || {}; dd.phases[card.index].load[modelData] = v })
                                }
                            }
                        }
                    }
                    Area {
                        Layout.fillWidth: true
                        implicitHeight: 70
                        placeholder: "Routines during this phase, one per line (optional)"
                        text: (card.ph.routines || []).join("\n")
                        onEdited: {
                            const lines = text.split("\n").map(x => x.trim()).filter(x => x)
                            page.setPh(card.index, "routines", lines.length ? lines : null)
                        }
                    }
                }
            }
        }
        Btn {
            label: "+  Add phase"
            onClicked: Cfg.edit(dd => dd.phases.push({ name: "New phase", from: "", to: "", load: {} }))
        }
    }
}
