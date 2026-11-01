import QtQuick
import QtQuick.Layouts

// Settings → Tracks: list on the left, the selected track's editor on the right.
// "Add" shows the four templates; each fills in sensible defaults that stay editable.
RowLayout {
    id: page
    property string selected: ""
    property bool picking: false
    readonly property var d: Cfg.draft
    readonly property var t: d && selected && d.tracks[selected] ? d.tracks[selected] : null
    spacing: 18

    function openTemplate(key) { selected = Cfg.addTrack(key); picking = false }

    // ── track list ──
    ColumnLayout {
        Layout.preferredWidth: 250
        Layout.maximumWidth: 250
        Layout.fillWidth: false
        Layout.fillHeight: true
        spacing: 8
        Repeater {
            model: page.d ? Object.keys(page.d.tracks) : []
            delegate: Rectangle {
                id: row
                required property string modelData
                readonly property var tr: page.d.tracks[modelData]
                readonly property var info: Cfg.data && Cfg.data.tracks_info[modelData]
                Layout.fillWidth: true
                implicitHeight: 58
                radius: 14
                color: page.selected === modelData && !page.picking ? Theme.surface3 : (h.hovered ? Theme.surface2 : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 10
                    Rectangle {
                        implicitWidth: 34; implicitHeight: 34; radius: 10
                        color: Theme.mix(Theme.surface, Theme.tc(row.tr.color), 0.25)
                        Icon {
                            anchors.centerIn: parent; size: 19; color: Theme.tc(row.tr.color)
                            name: Cfg.data && Cfg.data.templates[row.tr.template] ? Cfg.data.templates[row.tr.template].icon : "list"
                        }
                    }
                    ColumnLayout {
                        spacing: 1; Layout.fillWidth: true
                        Text {
                            text: row.tr.name; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true
                            font.family: Theme.ui; font.pixelSize: 14; font.weight: Font.Medium
                            opacity: row.tr.paused ? 0.5 : 1
                        }
                        Text {
                            text: row.info ? row.info.done + " / " + row.info.items + (row.tr.paused ? " · paused" : "") : "new"
                            color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 11
                        }
                    }
                }
                HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: { page.selected = row.modelData; page.picking = false } }
            }
        }
        Btn {
            Layout.fillWidth: true
            label: "+  Add track"
            primary: page.picking
            onClicked: page.picking = true
        }
        Item { Layout.fillHeight: true }
    }

    Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: Theme.outline }

    // ── template picker ──
    Flickable {
        visible: page.picking || !page.t
        Layout.fillWidth: true
        Layout.preferredWidth: 1   // take the leftover width, never the content's
        Layout.fillHeight: true
        contentHeight: pick.implicitHeight
        clip: true
        ColumnLayout {
            id: pick
            width: parent.width
            spacing: 14
            Text { text: "What do you want to track?"; color: Theme.text; font.family: Theme.ui; font.pixelSize: 20; font.weight: Font.Medium }
            Text {
                text: "Pick a starting point. Everything can be changed afterwards."
                color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 13
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 12; rowSpacing: 12
                Repeater {
                    model: Cfg.data ? Object.keys(Cfg.data.templates) : []
                    delegate: Rectangle {
                        id: tcard
                        required property string modelData
                        required property int index
                        readonly property var tp: Cfg.data.templates[modelData]
                        Layout.fillWidth: true
                        implicitHeight: 150
                        radius: 18
                        color: th.hovered ? Theme.mix(Theme.surface2, tp.color, 0.14) : Theme.surface2
                        border.width: th.hovered ? 1 : 0
                        border.color: tp.color
                        scale: tt.pressed ? 0.97 : 1
                        opacity: 0; y: 12
                        Component.onCompleted: appear.start()
                        ParallelAnimation {
                            id: appear
                            PauseAnimation { duration: Theme.dur(tcard.index * 60) }
                            NumberAnimation { target: tcard; property: "opacity"; to: 1; duration: Theme.dur(260) }
                        }
                        Behavior on color { ColorAnimation { duration: Theme.dur(140) } }
                        Behavior on scale { NumberAnimation { duration: Theme.dur(90) } }
                        ColumnLayout {
                            anchors { fill: parent; margins: 16 }
                            spacing: 6
                            Icon { name: tcard.tp.icon; size: 30; color: Theme.tc(tcard.tp.color) }
                            Text { text: tcard.tp.label; color: Theme.text; font.family: Theme.ui; font.pixelSize: 17; font.weight: Font.Medium }
                            Text {
                                text: tcard.tp.desc; color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 12
                                wrapMode: Text.Wrap; Layout.fillWidth: true; maximumLineCount: 3; elide: Text.ElideRight
                            }
                        }
                        HoverHandler { id: th; cursorShape: Qt.PointingHandCursor }
                        TapHandler { id: tt; onTapped: page.openTemplate(tcard.modelData) }
                    }
                }
            }
        }
    }

    // ── editor ──
    Flickable {
        visible: !page.picking && !!page.t
        Layout.fillWidth: true
        Layout.preferredWidth: 1   // take the leftover width, never the content's
        Layout.fillHeight: true
        contentHeight: ed.implicitHeight + 20
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        TrackEditor {
            id: ed
            width: parent.width
            tid: page.selected
            onDeleted: page.selected = ""
        }
    }
}
