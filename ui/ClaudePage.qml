import QtQuick
import QtQuick.Layouts

// Settings → Claude: set the planner up by describing it, or run the evening review now.
ColumnLayout {
    spacing: 16
    Text { text: "Claude"; color: Theme.text; font.family: Theme.ui; font.pixelSize: 20; font.weight: Font.Medium }
    Text {
        Layout.fillWidth: true; wrapMode: Text.Wrap
        text: "If you use Claude Code, it can do the setup and the daily review with you. It works through the same rf commands as this window, so you can always check or change what it did here."
        color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 13
    }
    Repeater {
        model: [
            { icon: "auto_awesome", title: "Set up with Claude", cmd: "setup",
              text: "Describe what you're studying or building (“an AWS course by February, DSA every day, my semester subjects”). Claude asks a few questions, writes the lists and the week for you." },
            { icon: "nightlight", title: "Review today", cmd: "review",
              text: "Go through what's left, record project progress and where to resume, and sort out missed deadlines. The evening notification opens this too." }
        ]
        delegate: Rectangle {
            id: card
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: cc.implicitHeight + 36
            radius: 18
            color: h.hovered ? Theme.mix(Theme.surface2, Theme.accent, 0.1) : Theme.surface2
            Behavior on color { ColorAnimation { duration: 140 } }
            RowLayout {
                id: cc
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                spacing: 16
                Icon { name: card.modelData.icon; size: 32; color: Theme.accent }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text { text: card.modelData.title; color: Theme.text; font.family: Theme.ui; font.pixelSize: 16; font.weight: Font.Medium }
                    Text { text: card.modelData.text; color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 12; wrapMode: Text.Wrap; Layout.fillWidth: true }
                }
                Btn { label: "Open"; primary: true; onClicked: Store.run([card.modelData.cmd]) }
            }
            HoverHandler { id: h }
        }
    }
    Text {
        Layout.fillWidth: true; wrapMode: Text.Wrap
        text: "Needs the claude command and a terminal (kitty by default; change “terminal” in the config file)."
        color: Theme.textDim; opacity: 0.8; font.family: Theme.ui; font.pixelSize: 12
    }
    Item { Layout.fillHeight: true }
}
