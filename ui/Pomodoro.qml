import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

// Pomodoro. The end time lives in rf's state.json, so the timer survives closing the window.
Rectangle {
    id: pomo
    readonly property var p: Store.s ? Store.s.pomo : null
    readonly property bool running: p && p.phase !== "idle" && p.ends
    property int remaining: 0
    readonly property var task: {
        if (!p || !Store.s) return null
        for (const t of Store.s.tasks) if (t.id === p.task) return t
        return null
    }
    readonly property color tint: task ? task.color : Theme.accent

    function tick() {
        if (!running) { remaining = 0; return }
        remaining = Math.max(0, Math.round(p.ends - Date.now() / 1000))
        if (remaining === 0) Store.run(["pomo", "tick"])
    }
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: pomo.tick() }
    onPChanged: tick()

    radius: 18
    color: Theme.surface
    implicitHeight: col.implicitHeight + 36

    ColumnLayout {
        id: col
        anchors { fill: parent; margins: 18 }
        spacing: 12

        Text {
            text: !pomo.running ? "POMODORO" : (pomo.p.phase === "work" ? "FOCUS" : "BREAK")
            color: pomo.running ? pomo.tint : Theme.textDim
            font.family: Theme.pixel; font.pixelSize: 10
        }

        // ring + time; the ring glows and slowly breathes while you focus
        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 190; implicitHeight: 190
            layer.enabled: pomo.running
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: pomo.tint; shadowBlur: 1.0
                shadowOpacity: breath.value
            }
            Item {
                id: breath
                visible: false
                property real value: 0.5
                SequentialAnimation on value {
                    running: pomo.running && pomo.p.phase === "work" && !Theme.reduced
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.9; duration: 2400; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.35; duration: 2400; easing.type: Easing.InOutSine }
                }
            }
            Canvas {
                id: ring
                anchors.fill: parent
                property real frac: pomo.running && pomo.p.length ? pomo.remaining / pomo.p.length : 0
                onFracChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d"); c.reset()
                    const r = width / 2 - 8
                    c.lineWidth = 10; c.lineCap = "round"
                    c.strokeStyle = Theme.surface3
                    c.beginPath(); c.arc(width / 2, height / 2, r, 0, 2 * Math.PI); c.stroke()
                    if (frac > 0) {
                        c.strokeStyle = pomo.tint
                        c.beginPath(); c.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * frac); c.stroke()
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                text: {
                    const sec = pomo.running ? pomo.remaining : (Store.s ? Store.s.pomodoro.work * 60 : 1500)
                    return String(Math.floor(sec / 60)).padStart(2, "0") + ":" + String(sec % 60).padStart(2, "0")
                }
                color: Theme.text
                font.family: Theme.pixel; font.pixelSize: 26
            }
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: pomo.task ? pomo.task.title : "Press ▶ on a task to start"
            color: pomo.task ? Theme.text : Theme.textDim
            font.family: Theme.ui; font.pixelSize: 13
            wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            Btn {
                visible: pomo.running
                label: "■  Stop"
                onClicked: Store.run(["pomo", "stop"])
            }
            Btn {
                visible: !pomo.running && pomo.p && pomo.p.task
                primary: true
                label: "▶  Next pomodoro"
                onClicked: Store.run(["pomo", "start", pomo.p.task])
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: (pomo.p && pomo.p.count ? pomo.p.count : 0) + " today"
            color: Theme.textDim
            font.family: Theme.ui; font.pixelSize: 12
        }
    }
}
