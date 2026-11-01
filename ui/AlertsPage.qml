import QtQuick
import QtQuick.Layouts

// Settings → Focus & alerts: notifications, pomodoro, day rollover and the "be kind" rules.
Flickable {
    id: page
    readonly property var d: Cfg.draft
    contentHeight: col.implicitHeight + 20
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    component Section: Text { color: Theme.textDim; font.family: Theme.pixel; font.pixelSize: 9; Layout.topMargin: 10 }
    component Row2: RowLayout {
        property string label: ""
        property string hint: ""
        default property alias content: slot.data
        Layout.fillWidth: true
        spacing: 14
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text { text: label; color: Theme.text; font.family: Theme.ui; font.pixelSize: 14 }
            Text { visible: hint !== ""; text: hint; color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 12; wrapMode: Text.Wrap; Layout.fillWidth: true }
        }
        RowLayout { id: slot; spacing: 8 }
    }

    ColumnLayout {
        id: col
        width: page.width
        spacing: 12
        Text { text: "Focus & alerts"; color: Theme.text; font.family: Theme.ui; font.pixelSize: 20; font.weight: Font.Medium }

        Section { text: "NOTIFICATIONS" }
        Row2 {
            label: "Morning plan"; hint: "A desktop notification with today's tasks."
            Field { implicitWidth: 90; mono: true; mask: "99:99"; text: page.d ? page.d.notify.morning : ""; onEdited: x => Cfg.edit(dd => dd.notify.morning = x) }
        }
        Row2 {
            label: "Evening review"; hint: "Shows how the day went, with a “Review with Claude” button."
            Field { implicitWidth: 90; mono: true; mask: "99:99"; text: page.d ? page.d.notify.evening : ""; onEdited: x => Cfg.edit(dd => dd.notify.evening = x) }
        }

        Section { text: "POMODORO" }
        Row2 { label: "Focus"; Stepper { suffix: "m"; from: 5; to: 90; step: 5; value: page.d ? page.d.pomodoro.work : 25; onChanged: v => Cfg.edit(dd => dd.pomodoro.work = v) } }
        Row2 { label: "Short break"; Stepper { suffix: "m"; from: 1; to: 30; value: page.d ? page.d.pomodoro.short_break : 5; onChanged: v => Cfg.edit(dd => dd.pomodoro.short_break = v) } }
        Row2 { label: "Long break"; Stepper { suffix: "m"; from: 5; to: 60; step: 5; value: page.d ? page.d.pomodoro.long_break : 15; onChanged: v => Cfg.edit(dd => dd.pomodoro.long_break = v) } }
        Row2 { label: "Long break every"; Stepper { suffix: "×"; from: 2; to: 8; value: page.d ? page.d.pomodoro.long_every : 4; onChanged: v => Cfg.edit(dd => dd.pomodoro.long_every = v) } }

        Section { text: "DAYS" }
        Row2 {
            label: "Plan starts"; hint: "Nothing is planned before this date (optional)."
            Field { implicitWidth: 140; mono: true; placeholder: "YYYY-MM-DD"; text: page.d && page.d.start || ""; onEdited: x => Cfg.edit(dd => { if (/^\d{4}-\d\d-\d\d$/.test(x)) dd.start = x; else delete dd.start }) }
        }
        Row2 {
            label: "Day rolls over at"; hint: "Work after midnight still counts for the evening before."
            Stepper { suffix: ":00"; from: 0; to: 8; value: page.d ? page.d.day_starts_at : 4; onChanged: v => Cfg.edit(dd => dd.day_starts_at = v) }
        }
        Row2 {
            label: "Low-energy day after"; hint: "Empty days in a row before the next day automatically shrinks to one small task per track. 0 turns it off."
            Stepper { suffix: " d"; from: 0; to: 7; value: page.d ? page.d.auto_low_after : 3; onChanged: v => Cfg.edit(dd => dd.auto_low_after = v) }
        }
        Row2 {
            label: "Missed deadlines archive after"; hint: "Days a missed dated task waits for a decision."
            Stepper { suffix: " d"; from: 1; to: 14; value: page.d ? page.d.missed_max_rolls : 3; onChanged: v => Cfg.edit(dd => dd.missed_max_rolls = v) }
        }

        Section { text: "CATCH-UP" }
        Row2 {
            label: "Borrow a slot when behind by"; hint: "A track with a “finish by” date that falls this far behind takes one task a day from the donor track below."
            Stepper { suffix: " d"; from: 1; to: 14; value: page.d ? page.d.rebalance.behind_days : 2; onChanged: v => Cfg.edit(dd => dd.rebalance.behind_days = v) }
        }
        Text { text: "Donor track"; color: Theme.text; font.family: Theme.ui; font.pixelSize: 14 }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: page.d ? [""].concat(Object.keys(page.d.tracks)) : []
                delegate: Btn {
                    required property string modelData
                    label: modelData === "" ? "None" : page.d.tracks[modelData].name
                    active: (page.d.rebalance.donor || "") === modelData
                    onClicked: Cfg.edit(dd => dd.rebalance.donor = modelData || null)
                }
            }
        }

        Section { text: "FILES" }
        Text {
            Layout.fillWidth: true; wrapMode: Text.Wrap
            text: Cfg.data ? "Config: " + Cfg.data.path + "\nData: " + Cfg.data.data_dir : ""
            color: Theme.textDim; font.family: Theme.mono; font.pixelSize: 12
        }
    }
}
