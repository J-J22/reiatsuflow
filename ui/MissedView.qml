import QtQuick
import QtQuick.Layouts

// Dated tasks only: missed ones need a decision, upcoming ones can be added here.
// Queue tasks never land here: they just wait as the next item in their track.
ColumnLayout {
    id: view
    spacing: 14

    function tomorrow() {
        const d = new Date(Store.s.date + "T12:00:00"); d.setDate(d.getDate() + 1)
        return d.toISOString().slice(0, 10)
    }

    Text {
        text: "MISSED"
        color: Theme.danger
        font.family: Theme.pixel; font.pixelSize: 11
    }
    Text {
        visible: Store.s && Store.s.missed.length === 0
        text: "Nothing missed. Queue tasks never pile up here; they wait as the next item in their track."
        color: Theme.textDim
        font.family: Theme.ui; font.pixelSize: 13
        wrapMode: Text.Wrap; Layout.fillWidth: true
    }
    Repeater {
        model: Store.s ? Store.s.missed : []
        delegate: Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: r.implicitHeight + 24
            radius: 14
            color: Theme.surface
            RowLayout {
                id: r
                anchors { fill: parent; margins: 12 }
                spacing: 10
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: modelData.title; color: Theme.text; font.family: Theme.ui; font.pixelSize: 15 }
                    Text {
                        text: "was due " + modelData.due + " · rolled " + modelData.rolls + "/" + 3 + " (archived after 3)"
                        color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 12
                    }
                }
                Btn { label: "Redo today"; primary: true; onClicked: Store.run(["missed", modelData.id, "redo"]) }
                Btn { label: "Tomorrow"; onClicked: Store.run(["missed", modelData.id, "move", view.tomorrow()]) }
                Btn { label: "Drop"; onClicked: Store.run(["missed", modelData.id, "drop"]) }
            }
        }
    }

    Text {
        Layout.topMargin: 10
        text: "DATED TASKS"
        color: Theme.textDim
        font.family: Theme.pixel; font.pixelSize: 11
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 54
        radius: 14
        color: Theme.surface
        RowLayout {
            anchors { fill: parent; margins: 10 }
            spacing: 10
            Rectangle {
                Layout.fillWidth: true; implicitHeight: 34; radius: 10; color: Theme.surface2
                TextInput {
                    id: titleIn
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text; font.family: Theme.ui; font.pixelSize: 14
                    clip: true
                    Text {
                        visible: !parent.text && !parent.activeFocus
                        anchors.verticalCenter: parent.verticalCenter
                        text: "New deadline, e.g. OS assignment 4"
                        color: Theme.textDim; font: parent.font
                    }
                }
            }
            Rectangle {
                implicitWidth: 130; implicitHeight: 34; radius: 10; color: Theme.surface2
                TextInput {
                    id: dueIn
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text; font.family: Theme.mono; font.pixelSize: 13
                    inputMask: "0000-00-00;_"
                    text: Store.s ? view.tomorrow() : ""
                }
            }
            Btn {
                label: "Add"
                primary: true
                onClicked: if (titleIn.text.trim()) { Store.run(["add", titleIn.text.trim(), "--due", dueIn.text]); titleIn.text = "" }
            }
        }
    }
    Repeater {
        model: Store.s ? Store.s.upcoming : []
        delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true
            Text { text: modelData.due; color: Theme.textDim; font.family: Theme.mono; font.pixelSize: 12 }
            Text { Layout.fillWidth: true; text: modelData.title; color: Theme.text; font.family: Theme.ui; font.pixelSize: 13 }
            Btn { label: "Drop"; onClicked: Store.run(["missed", modelData.id, "drop"]) }
        }
    }
    Repeater {
        model: Store.s ? Store.s.archived : []
        delegate: Text {
            required property var modelData
            text: "archived · " + modelData.title + " (due " + modelData.due + ")"
            color: Theme.textDim; opacity: 0.7
            font.family: Theme.ui; font.pixelSize: 12
        }
    }
    Item { Layout.fillHeight: true }
}
