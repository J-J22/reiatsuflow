import QtQuick
import QtQuick.Layouts

// A track's progress bar and its one honest pace number.
ColumnLayout {
    id: row
    property var track
    property bool detailed: false
    spacing: 5

    function paceText() {
        const p = track.pace
        if (!track.active) return track.until ? "finished " + track.until : "not started"
        if (!p) return track.done + " / " + track.total
        if (p.behind_days >= 1) return p.behind_days.toFixed(1) + " days behind for " + fmt(p.deadline)
        if (p.behind_days <= -1) return (-p.behind_days).toFixed(1) + " days ahead"
        return "on pace for " + fmt(p.deadline)
    }
    function fmt(d) {
        const x = new Date(d + "T12:00:00")
        return x.getDate() + " " + ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][x.getMonth()]
    }

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: row.track.name
            color: Theme.text
            font.family: Theme.ui; font.pixelSize: 13; font.weight: Font.Medium
        }
        Item { Layout.fillWidth: true }
        Text {
            text: row.paceText()
            color: row.track.pace && row.track.pace.behind_days >= 1 ? Theme.danger : Theme.textDim
            font.family: Theme.ui; font.pixelSize: 12
        }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 8
        radius: 4
        color: Theme.surface3
        Rectangle {
            width: parent.width * (row.track.total ? row.track.done / row.track.total : 0)
            height: parent.height
            radius: 4
            color: row.track.color
        }
        Rectangle {  // where you'd be on pace
            visible: !!row.track.pace && row.track.active
            x: row.track.pace ? Math.min(parent.width - 2, parent.width * row.track.pace.expected / row.track.total) : 0
            width: 2; height: parent.height + 6; y: -3
            color: Theme.text
            opacity: 0.6
        }
    }
    Text {
        visible: row.detailed && !!row.track.next
        Layout.fillWidth: true
        text: "Next: " + row.track.next + (row.track.pct ? "  ·  " + row.track.pct + "%" : "")
              + (row.track.resume ? "  ·  resume: " + row.track.resume : "")
        color: Theme.textDim
        font.family: Theme.ui; font.pixelSize: 12
        elide: Text.ElideRight
    }
    Text {
        visible: row.detailed
        text: row.track.done + " / " + row.track.total + (row.track.kind === "project" ? " milestones" : " done")
        color: Theme.textDim
        font.family: Theme.mono; font.pixelSize: 11
    }
}
