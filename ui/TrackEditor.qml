import QtQuick
import QtQuick.Layouts

// One track's settings. Lists in the simple format can be pasted and edited here, with a live
// preview of how they'll be read; tracks that use a special format show their file instead.
ColumnLayout {
    id: ed
    property string tid: ""
    readonly property var t: Cfg.draft && tid ? Cfg.draft.tracks[tid] : null
    readonly property var tp: t && Cfg.data ? Cfg.data.templates[t.template || "custom"] : null
    readonly property bool listFormat: !t || !t.format || t.format === "list-md"
    readonly property bool isProject: t && t.kind === "project"
    property var preview: null
    property bool confirmDelete: false
    signal deleted()
    spacing: 18

    function set(key, value) { Cfg.edit(d => { if (value === null || value === "") delete d.tracks[tid][key]; else d.tracks[tid][key] = value }) }
    function setChunk(key, value) { Cfg.edit(d => { d.tracks[tid].chunk = d.tracks[tid].chunk || {}; d.tracks[tid].chunk[key] = value }) }
    function chunk(key, dflt) { return t && t.chunk && t.chunk[key] !== undefined ? t.chunk[key] : dflt }

    onTidChanged: {
        confirmDelete = false; preview = null; listArea.text = ""
        if (!tid) return
        if (Cfg.sources[tid] !== undefined) { listArea.text = Cfg.sources[tid]; previewTimer.restart() }
        else if (listFormat) Cfg.run(["source", "get", tid], v => { if (v && v.text !== undefined) { listArea.text = v.text; previewTimer.restart() } })
    }
    Timer {
        id: previewTimer; interval: 350
        onTriggered: Cfg.run(["source", "preview", "list-md", listArea.text], v => ed.preview = (typeof v === "object") ? v : null)
    }

    component Label: Text { color: Theme.textDim; font.family: Theme.pixel; font.pixelSize: 9; Layout.topMargin: 4 }
    component Hint: Text { color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 12; wrapMode: Text.Wrap; Layout.fillWidth: true }

    // header
    RowLayout {
        visible: !!ed.t
        spacing: 12
        Rectangle {
            implicitWidth: 46; implicitHeight: 46; radius: 14
            color: ed.t ? Theme.mix(Theme.surface, Theme.tc(ed.t.color), 0.25) : "transparent"
            Icon { anchors.centerIn: parent; size: 26; color: ed.t ? Theme.tc(ed.t.color) : Theme.text; name: ed.tp ? ed.tp.icon : "list" }
        }
        ColumnLayout {
            spacing: 0
            Text { text: ed.tp ? ed.tp.label + " track" : ""; color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 12 }
            Text { text: ed.t ? ed.t.name : ""; color: Theme.text; font.family: Theme.ui; font.pixelSize: 20; font.weight: Font.Medium }
        }
    }

    Label { text: "NAME" }
    Field {
        Layout.fillWidth: true
        text: ed.t ? ed.t.name : ""
        placeholder: "e.g. AWS course"
        onEdited: txt => ed.set("name", txt)
    }

    Label { text: "COLOUR" }
    Flow {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: Cfg.data ? Cfg.data.colors : []
            delegate: Rectangle {
                required property string modelData
                width: 30; height: 30; radius: 15
                color: modelData
                border.width: ed.t && ed.t.color === modelData ? 3 : 0
                border.color: Theme.text
                scale: sh.hovered ? 1.15 : 1
                Behavior on scale { NumberAnimation { duration: Theme.dur(100) } }
                HoverHandler { id: sh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: ed.set("color", modelData) }
            }
        }
    }

    Label { text: "WHAT KIND OF LIST" }
    Chips {
        current: ed.t ? ed.t.kind : "queue"
        options: [{ key: "queue", label: "Tasks in order" }, { key: "project", label: "Milestones (one at a time)" }]
        onPicked: k => ed.set("kind", k)
    }

    Label { text: "THE LIST" }
    Hint {
        visible: ed.listFormat
        text: "One item per line. “## Section” headings group items" + (ed.t && ed.t.chunk && ed.t.chunk.rotate ? "; “# Subject” headings are rotated between days" : "")
              + ". Add “| 12:30” or “| 25m” to give an item a length."
    }
    Area {
        id: listArea
        visible: ed.listFormat
        Layout.fillWidth: true
        implicitHeight: 230
        placeholder: ed.tp ? "Paste or type your list, e.g.\n\n" + ed.tp.example : ""
        onEdited: { Cfg.setSource(ed.tid, text); previewTimer.restart() }
    }
    RowLayout {
        visible: ed.listFormat && !!ed.preview
        spacing: 10
        Icon { name: ed.preview && ed.preview.count ? "check_circle" : "info"; size: 18; color: ed.preview && ed.preview.count ? (ed.t ? Theme.tc(ed.t.color) : Theme.accent) : Theme.textDim }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 12
            text: !ed.preview ? "" : ed.preview.count === 0 ? "Nothing read yet."
                : ed.preview.count + " items in " + ed.preview.groups.length + " section" + (ed.preview.groups.length === 1 ? "" : "s")
                  + (ed.preview.minutes ? " · about " + Math.round(ed.preview.minutes / 60) + " h" : "")
                  + " · starts with “" + ed.preview.first[0] + "”"
        }
    }
    Rectangle {
        visible: !ed.listFormat
        Layout.fillWidth: true
        implicitHeight: fileRow.implicitHeight + 24
        radius: 12
        color: Theme.surface2
        RowLayout {
            id: fileRow
            anchors { fill: parent; margins: 12 }
            Icon { name: "description"; color: Theme.textDim }
            Text {
                Layout.fillWidth: true
                text: (ed.t ? ed.t.source : "") + "  ·  format " + (ed.t ? ed.t.format : "")
                      + "\nThis track reads a special-format file. Edit that file directly, then Save here to rebuild."
                color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 12; wrapMode: Text.Wrap
            }
        }
    }

    // daily chunk
    Label { visible: !ed.isProject; text: "HOW MUCH PER TASK" }
    Flow {
        visible: !ed.isProject
        Layout.fillWidth: true
        spacing: 12
        Chips {
            current: ed.chunk("by", "count")
            options: [{ key: "count", label: "Items" }, { key: "size", label: "Minutes" }, { key: "weight", label: "Weighted topics" }]
            onPicked: k => { ed.setChunk("by", k); ed.setChunk("target", k === "size" ? 40 : (k === "weight" ? 3 : 2)) }
        }
        Stepper {
            value: ed.chunk("target", 1)
            from: 1; to: ed.chunk("by", "count") === "size" ? 240 : 20
            step: ed.chunk("by", "count") === "size" ? 5 : 1
            suffix: ed.chunk("by", "count") === "size" ? "m" : ""
            tint: ed.t ? Theme.tc(ed.t.color) : Theme.accent
            onChanged: v => ed.setChunk("target", v)
        }
    }
    Hint {
        visible: !ed.isProject
        text: ed.chunk("by", "count") === "size" ? "Each task takes items until their lengths add up to this (untimed items count as 10 min)."
            : ed.chunk("by", "count") === "weight" ? "Quick topics count ½, Exam 1, Go deep 1½."
            : "How many items one task holds. The Week grid sets how many tasks a day."
    }
    Toggle {
        visible: !ed.isProject
        Layout.fillWidth: true
        label: "Keep a task inside one section"
        hint: "A task never mixes items from two sections."
        checked: ed.chunk("stop_at_group", false)
        onToggled: c => ed.setChunk("stop_at_group", c)
    }
    Toggle {
        visible: !ed.isProject
        Layout.fillWidth: true
        label: "Rotate between subjects"
        hint: "With “# Subject” headings, each task comes from the next subject in turn."
        checked: ed.chunk("rotate", "") === "tag"
        onToggled: c => ed.setChunk("rotate", c ? "tag" : "")
    }
    Toggle {
        visible: !ed.isProject
        Layout.fillWidth: true
        label: "Switch to revision when the list is done"
        hint: "Tasks become “Revise <section>” blocks, rotating through the sections."
        checked: !!(ed.t && ed.t.revise)
        onToggled: c => ed.set("revise", c ? "re-read your notes, then practise questions" : null)
    }

    Label { text: "DATES (OPTIONAL)" }
    Flow {
        Layout.fillWidth: true
        spacing: 12
        Repeater {
            model: [{ k: "deadline", l: "Finish by" }, { k: "start", l: "Starts" }, { k: "until", l: "Ends" }]
            delegate: ColumnLayout {
                required property var modelData
                spacing: 4
                Hint { text: modelData.l; Layout.fillWidth: false }
                Field {
                    implicitWidth: 150; mono: true; placeholder: "YYYY-MM-DD"
                    text: ed.t && ed.t[modelData.k] || ""
                    onEdited: x => ed.set(modelData.k, /^\d{4}-\d\d-\d\d$/.test(x) ? x : null)
                }
            }
        }
    }
    Hint { text: "“Finish by” powers the pace line (“2 days behind for 6 Dec”). “Ends” switches the track off after that day." }

    Toggle {
        Layout.fillWidth: true
        label: "Paused"
        hint: "Keeps the track and its progress, but plans nothing from it."
        checked: !!(ed.t && ed.t.paused)
        onToggled: c => ed.set("paused", c ? true : null)
    }

    RowLayout {
        Layout.topMargin: 8
        spacing: 10
        Btn {
            label: ed.confirmDelete ? "Really delete " + (ed.t ? ed.t.name : "") + "?" : "Delete track"
            tint: Theme.danger
            active: ed.confirmDelete
            onClicked: {
                if (!ed.confirmDelete) { ed.confirmDelete = true; return }
                Cfg.deleteTrack(ed.tid); ed.deleted()
            }
        }
        Hint { visible: ed.confirmDelete; text: "Progress is kept in the data folder if you add it back with the same list."; Layout.fillWidth: true }
    }
}
