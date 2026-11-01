import QtQuick
import QtQuick.Layouts
import Quickshell

// The separate Settings window (gear icon in the main window).
FloatingWindow {
    id: sw
    title: "ReiatsuFlow Settings"
    implicitWidth: 1060
    implicitHeight: 760
    color: Theme.bg
    visible: false

    property int page: 0
    readonly property var pages: [
        { icon: "view_list", label: "Tracks" },
        { icon: "calendar_view_week", label: "Week" },
        { icon: "date_range", label: "Phases" },
        { icon: "notifications", label: "Focus & alerts" },
        { icon: "auto_awesome", label: "Claude" }
    ]

    function open(p) { if (p !== undefined) page = p; if (!visible) Cfg.load(); visible = true }
    // from the main window's onboarding: open Settings straight into a new track of that template
    property string pendingTemplate: ""
    property var tracksPage: null
    function addTrack(key) {
        pendingTemplate = key
        open(0)
        flushPending()
    }
    function flushPending() {
        if (!pendingTemplate || Cfg.loading || !tracksPage) return   // retried after load / page creation
        const k = pendingTemplate
        pendingTemplate = ""
        Qt.callLater(() => tracksPage.openTemplate(k))
    }
    Connections { target: Cfg; function onLoaded() { sw.flushPending() } }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // nav
        Rectangle {
            Layout.fillHeight: true
            implicitWidth: 230
            color: Theme.surface
            ColumnLayout {
                anchors { fill: parent; margins: 18 }
                spacing: 6
                RowLayout {
                    spacing: 10
                    Layout.bottomMargin: 14
                    Icon { name: "settings"; color: Theme.accent; size: 22 }
                    Text { text: "SETTINGS"; color: Theme.text; font.family: Theme.pixel; font.pixelSize: 12 }
                }
                Repeater {
                    model: sw.pages
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 42
                        radius: 12
                        color: sw.page === index ? Theme.mix(Theme.surface, Theme.accent, 0.18) : (nh.hovered ? Theme.surface2 : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12 }
                            spacing: 12
                            Icon { name: modelData.icon; size: 19; color: sw.page === index ? Theme.accent : Theme.textDim }
                            Text { text: modelData.label; color: sw.page === index ? Theme.text : Theme.textDim; font.family: Theme.ui; font.pixelSize: 14 }
                            Item { Layout.fillWidth: true }
                        }
                        HoverHandler { id: nh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: sw.page = index }
                    }
                }
                Item { Layout.fillHeight: true }
                Text {
                    Layout.fillWidth: true; wrapMode: Text.Wrap
                    text: "Changes apply when you press Save. Today's untouched tasks are re-planned; finished ones stay."
                    color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 11; opacity: 0.8
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 26
                // crossfade between pages
                Repeater {
                    model: 5
                    delegate: Loader {
                        required property int index
                        anchors.fill: parent
                        active: Cfg.draft !== null
                        opacity: sw.page === index ? 1 : 0
                        visible: opacity > 0
                        y: sw.page === index ? 0 : 10
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        sourceComponent: [tracksC, weekC, phasesC, alertsC, claudeC][index]
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: Cfg.draft === null
                    text: Cfg.errors.length ? Cfg.errors.join("\n") : "Loading…"
                    color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 14
                }
            }

            // save bar
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 70
                color: Theme.surface
                RowLayout {
                    anchors { fill: parent; leftMargin: 26; rightMargin: 26 }
                    spacing: 12
                    Icon {
                        name: Cfg.errors.length ? "error" : (Cfg.dirty ? "edit" : "check_circle")
                        color: Cfg.errors.length ? Theme.danger : (Cfg.dirty ? Theme.accent : Theme.textDim)
                    }
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        text: Cfg.errors.length ? Cfg.errors.join(" · ") : Cfg.saving ? "Saving and re-planning…"
                              : Cfg.dirty ? "Unsaved changes" : (Cfg.message || "All saved")
                        color: Cfg.errors.length ? Theme.danger : Theme.textDim
                        font.family: Theme.ui; font.pixelSize: 13
                    }
                    Btn { visible: Cfg.dirty; label: "Discard"; onClicked: Cfg.load() }
                    Btn { label: Cfg.saving ? "Saving…" : "Save"; primary: Cfg.dirty; onClicked: Cfg.save() }
                }
            }
        }
    }

    Component {
        id: tracksC
        TracksPage {
            id: tp
            Component.onCompleted: {
                sw.tracksPage = tp
                sw.flushPending()
            }
            Component.onDestruction: if (sw.tracksPage === tp) sw.tracksPage = null
        }
    }
    Component { id: weekC; WeekPage {} }
    Component { id: phasesC; PhasesPage {} }
    Component { id: alertsC; AlertsPage {} }
    Component { id: claudeC; ClaudePage {} }
}
