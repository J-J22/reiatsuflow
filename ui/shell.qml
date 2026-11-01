// ReiatsuFlow: task-based study planner. Run with `qs -c reiatsuflow` (installed) or `qs -p <this dir>`.
// All data comes from the `rf` CLI; see the README.
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io

ShellRoot {
    SettingsWindow { id: settings }

    FloatingWindow {
        id: win
        title: "ReiatsuFlow"
        implicitWidth: 1180
        implicitHeight: 760
        color: Theme.bg

        property int tab: 0
        readonly property var s: Store.s
        readonly property bool empty: !!s && s.tracks.length === 0
        readonly property real progress: s && s.total ? s.done / s.total : 0
        property int lastDone: -1

        // BANKAI when the last task of the day gets ticked (not when the window opens)
        onSChanged: {
            if (!s) return
            if (lastDone >= 0 && s.total > 0 && s.done === s.total && lastDone < s.total) fx.bankai()
            lastDone = s.done
        }

        function greeting() {
            const h = new Date().getHours()
            return h < 5 ? "Late night" : h < 12 ? "Good morning" : h < 17 ? "Good afternoon" : "Good evening"
        }
        function mood() {
            if (!s) return ""
            if (empty) return "Welcome. Let's turn your lists into a flow."
            if (s.total === 0) return s.rule.startsWith("Plan starts") ? s.rule + ". Rest up." : "Nothing planned today."
            if (s.mode === "low") return "Low-energy day: one small thing per track is plenty."
            if (s.done === s.total) return "Bankai. Every task done."
            if (s.done === 0) return "Reiatsu is calm. Start with the smallest task."
            if (progress < 0.5) return "Reiatsu rising · " + s.done + " of " + s.total
            return "Reiatsu surging · " + (s.total - s.done) + " to go"
        }

        Connections {
            target: Store
            function onActed(args) {
                if (args[0] === "done" && args[1].indexOf(":") > 0)
                    toast.show(["Nice.", "Done.", "One less.", "Clean."][Math.floor(Math.random() * 4)], "Undo", () => Store.run(["undo", args[1]]))
                else if (args[0] === "low") toast.show(args[1] === "on" ? "Low-energy day: smallest task per track" : "Back to a normal day")
                else if (args[0] === "pomo" && args[1] === "start") toast.show("Focus on. " + (Store.s ? Store.s.pomodoro.work : 25) + " minutes")
            }
        }

        // `qs ipc call reiatsuflow tab 1`, `… settings`
        IpcHandler {
            target: "reiatsuflow"
            function tab(n: int): void { win.tab = n }
            function refresh(): void { Store.refresh() }
            function settings(): void { settings.open() }
            function settingsPage(n: int): void { settings.open(n) }
            function addTrack(key: string): void { settings.addTrack(key) }
            function editTrack(id: string): void { settings.open(0); if (settings.tracksPage) settings.tracksPage.selected = id }
            function closeSettings(): void { settings.visible = false }
            function showMain(show: bool): void { win.visible = show }
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                if (e.key >= Qt.Key_1 && e.key <= Qt.Key_4) win.tab = e.key - Qt.Key_1
                else if (e.key === Qt.Key_R) Store.refresh()
                else if (e.key === Qt.Key_Comma) settings.open()
            }
        }

        ColumnLayout {
            anchors { fill: parent; margins: 26 }
            spacing: 16

            // ── header ─────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 18
                ColumnLayout {
                    spacing: 6
                    Row {
                        Text { text: "REIATSU"; color: Theme.text; font.family: Theme.pixel; font.pixelSize: 22 }
                        Text {
                            text: "FLOW"; color: Theme.accent; font.family: Theme.pixel; font.pixelSize: 22
                            layer.enabled: true
                            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.accent; shadowBlur: 0.6; shadowOpacity: 0.7 }
                        }
                    }
                    Text {
                        text: win.greeting() + (win.s ? " · " + new Date(win.s.date + "T12:00:00").toLocaleDateString(Qt.locale("en_GB"), "dddd d MMMM") : "")
                        color: Theme.text; font.family: Theme.ui; font.pixelSize: 15; font.weight: Font.Medium
                    }
                    Text {
                        text: win.mood()
                        color: win.s && (win.s.mode === "low" || (win.s.total && win.s.done === win.s.total)) ? Theme.accent : Theme.textDim
                        font.family: Theme.ui; font.pixelSize: 13
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }
                Item { Layout.fillWidth: true }

                // today ring
                Item {
                    implicitWidth: 58; implicitHeight: 58
                    visible: !win.empty
                    Canvas {
                        id: ring
                        anchors.fill: parent
                        property real p: win.progress
                        Behavior on p { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                        onPChanged: requestPaint()
                        onPaint: {
                            const c = getContext("2d"); c.reset()
                            c.lineWidth = 6; c.lineCap = "round"
                            c.strokeStyle = Theme.surface3
                            c.beginPath(); c.arc(29, 29, 25, 0, 2 * Math.PI); c.stroke()
                            if (p > 0) { c.strokeStyle = Theme.accent; c.beginPath(); c.arc(29, 29, 25, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * p); c.stroke() }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: win.s ? win.s.done + "/" + win.s.total : ""
                        color: Theme.text; font.family: Theme.pixel; font.pixelSize: 10
                    }
                }
                // streak
                ColumnLayout {
                    visible: !win.empty
                    spacing: 0
                    RowLayout {
                        spacing: 2
                        Icon {
                            id: flame
                            name: "local_fire_department"; size: 24
                            color: win.s && win.s.streak > 0 ? Theme.accent : Theme.textDim
                            SequentialAnimation on scale {
                                running: win.s && win.s.streak > 0
                                loops: 1
                                NumberAnimation { to: 1.3; duration: 160 }
                                NumberAnimation { to: 1; duration: 260; easing.type: Easing.OutBack }
                            }
                        }
                        Text { text: win.s ? win.s.streak : "0"; color: Theme.text; font.family: Theme.pixel; font.pixelSize: 16 }
                    }
                    Text { text: "day streak"; color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 11 }
                }
                Btn {
                    visible: !win.empty
                    label: win.s && win.s.mode === "low" ? "◐  Low-energy" : "◐  Low-energy day"
                    active: win.s && win.s.mode === "low"
                    onClicked: Store.run(["low", win.s.mode === "low" ? "off" : "on"])
                }
                Btn {
                    visible: !win.empty
                    label: "✦  Review with Claude"
                    primary: true
                    onClicked: Store.run(["review"])
                }
                IconBtn { icon: "settings"; tint: Theme.textDim; onClicked: settings.open() }
            }

            // reiatsu bar: today's progress with a glow
            Item {
                visible: !win.empty
                Layout.fillWidth: true
                implicitHeight: 6
                Rectangle { anchors.fill: parent; radius: 3; color: Theme.surface2 }
                Rectangle {
                    id: bar
                    height: parent.height
                    radius: 3
                    width: parent.width * win.progress
                    Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.mix(Theme.accent, Theme.bg, 0.4) }
                        GradientStop { position: 1; color: Theme.accent }
                    }
                    layer.enabled: win.progress > 0
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.accent; shadowBlur: 0.8; shadowOpacity: 0.9 }
                }
            }

            // ── tabs with a sliding indicator ──────────────────
            RowLayout {
                visible: !win.empty
                spacing: 6
                Item {
                    implicitWidth: tabRow.implicitWidth
                    implicitHeight: 38
                    Rectangle {
                        id: indicator
                        property int ver: 0   // bumped when tab items appear, so itemAt() is re-read
                        readonly property Item cur: { ver; return tabRep.itemAt(win.tab) }
                        x: cur ? cur.x : 0
                        width: cur ? cur.width : 0
                        height: parent.height
                        radius: height / 2
                        color: win.tab === 3 && win.s && win.s.missed.length ? Theme.danger : Theme.accent
                        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    }
                    Row {
                        id: tabRow
                        spacing: 4
                        Repeater {
                            id: tabRep
                            onItemAdded: indicator.ver++
                            model: [{ l: "Today", i: "today" }, { l: "Week", i: "calendar_view_week" },
                                    { l: "Tracks", i: "stacked_line_chart" }, { l: "Missed", i: "event_busy" }]
                            delegate: Item {
                                required property var modelData
                                required property int index
                                readonly property bool on: win.tab === index
                                width: tl.implicitWidth + 30
                                height: 38
                                RowLayout {
                                    id: tl
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Icon { name: modelData.i; size: 17; color: on ? Theme.inkAccent : Theme.textDim }
                                    Text {
                                        text: modelData.l + (index === 3 && win.s && win.s.missed.length ? " " + win.s.missed.length : "")
                                        color: on ? Theme.inkAccent : (th.hovered ? Theme.text : Theme.textDim)
                                        font.family: Theme.ui; font.pixelSize: 13; font.weight: Font.Medium
                                    }
                                }
                                HoverHandler { id: th; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: win.tab = index }
                            }
                        }
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

            // ── views (crossfade) ──────────────────────────────
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Onboarding {
                    anchors.fill: parent
                    visible: win.empty
                    onPickTemplate: k => settings.addTrack(k)
                    onClaude: Store.run(["setup"])
                }

                Repeater {
                    model: win.empty ? 0 : 4
                    delegate: Loader {
                        required property int index
                        anchors.fill: parent
                        opacity: win.tab === index ? 1 : 0
                        visible: opacity > 0
                        transform: Translate { y: win.tab === index ? 0 : 14; Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        sourceComponent: [todayC, weekC, tracksC, missedC][index]
                    }
                }
            }
        }

        Component {
            id: todayC
            RowLayout {
                spacing: 20
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: list.implicitHeight + 70
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ColumnLayout {
                        id: list
                        width: parent.width
                        spacing: 10
                        Repeater {
                            // by count, so cards stay alive (and keep their state) across refreshes
                            model: win.s ? win.s.tasks.length : 0
                            delegate: TaskCard {
                                required property int index
                                Layout.fillWidth: true
                                task: win.s.tasks[index]
                                order: index
                                onSparked: (x, y, c) => fx.burst(x, y, c)
                            }
                        }
                        ColumnLayout {
                            visible: win.s && win.s.tasks.length === 0
                            Layout.topMargin: 60
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 10
                            Icon { Layout.alignment: Qt.AlignHCenter; name: "spa"; size: 48; color: Theme.accent }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: win.s ? (win.s.rule.startsWith("Plan starts") ? win.s.rule : "Nothing planned today") : ""
                                color: Theme.text; font.family: Theme.ui; font.pixelSize: 18
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "Rest is part of the flow."
                                color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 13
                            }
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
                            RowLayout {
                                Icon { name: "speed"; size: 18; color: Theme.textDim }
                                Text { text: "PACE"; color: Theme.textDim; font.family: Theme.pixel; font.pixelSize: 10 }
                            }
                            Repeater {
                                model: win.s ? win.s.tracks.filter(t => t.active && t.pace) : []
                                delegate: TrackRow {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    track: modelData
                                }
                            }
                            Text {
                                visible: win.s && win.s.tracks.filter(t => t.active && t.pace).length === 0
                                Layout.fillWidth: true; wrapMode: Text.Wrap
                                text: "Give a track a “finish by” date in Settings to see whether you're on pace."
                                color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 12
                            }
                            Item { Layout.fillHeight: true }
                        }
                    }
                }
            }
        }
        Component { id: weekC; WeekView {} }
        Component {
            id: tracksC
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
        }
        Component {
            id: missedC
            Flickable {
                contentHeight: missed.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                MissedView { id: missed; width: parent.width }
            }
        }

        Toast { id: toast }
        Celebrate { id: fx }
    }
}
