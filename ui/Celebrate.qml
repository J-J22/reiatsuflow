import QtQuick
import QtQuick.Particles
import QtQuick.Effects

// Reiatsu sparks when a task is ticked, and a BANKAI moment when the whole day is cleared.
// Event-driven only: nothing animates while you're not doing something.
Item {
    id: fx
    anchors.fill: parent
    z: 100
    enabled: false   // never steals clicks

    function burst(x, y, color, n) {
        if (Theme.reduced) return
        sparks.color = color
        emitter.burst(n || 36, x, y)
    }
    function bankai() {
        const cols = ["#ffffff", Theme.accent]
        for (let i = 0; i < 5; i++)
            Qt.callLater(() => burst(width * (0.2 + Math.random() * 0.6), height * (0.3 + Math.random() * 0.3), Theme.accent, 70))
        banner.play()
    }

    ParticleSystem { id: sys }
    ImageParticle {
        id: sparks
        system: sys
        source: "qrc:///particleresources/glowdot.png"
        color: Theme.accent
        colorVariation: 0.15
        alpha: 0.9
        entryEffect: ImageParticle.Scale
    }
    Emitter {
        id: emitter
        system: sys
        enabled: false
        lifeSpan: 750
        lifeSpanVariation: 250
        size: 16
        sizeVariation: 10
        endSize: 2
        velocity: AngleDirection { angleVariation: 360; magnitude: 170; magnitudeVariation: 120 }
        acceleration: PointDirection { y: 160 }
    }

    // BANKAI banner
    Item {
        id: banner
        anchors.centerIn: parent
        width: col.width; height: col.height
        opacity: 0
        scale: 0.6
        function play() { anim.restart() }
        Column {
            id: col
            spacing: 14
            Text {
                id: word
                anchors.horizontalCenter: parent.horizontalCenter
                text: "BANKAI"
                color: Theme.accent
                font.family: Theme.pixel
                font.pixelSize: 72
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.accent; shadowBlur: 1.0; shadowScale: 1.04 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Day cleared. Every task done."
                color: Theme.text
                font.family: Theme.ui
                font.pixelSize: 18
            }
        }
        SequentialAnimation {
            id: anim
            ParallelAnimation {
                NumberAnimation { target: banner; property: "opacity"; to: 1; duration: Theme.dur(220) }
                NumberAnimation { target: banner; property: "scale"; from: 0.6; to: 1.08; duration: Theme.dur(320); easing.type: Easing.OutBack }
            }
            NumberAnimation { target: banner; property: "scale"; to: 1; duration: Theme.dur(160) }
            PauseAnimation { duration: 1700 }
            NumberAnimation { target: banner; property: "opacity"; to: 0; duration: Theme.dur(500) }
        }
    }
}
