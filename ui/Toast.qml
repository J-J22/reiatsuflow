import QtQuick
import QtQuick.Layouts

// Small message at the bottom, optionally with an action ("Undo").
Rectangle {
    id: toast
    property string text: ""
    property string action: ""
    property var actionCb: null
    function show(msg, actionLabel, cb) { text = msg; action = actionLabel || ""; actionCb = cb || null; anim.restart() }
    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height - (shown ? height + 26 : -10)
    z: 90
    property bool shown: false
    implicitWidth: row.implicitWidth + 32
    implicitHeight: 48
    radius: 24
    color: Theme.surface3
    border.width: 1
    border.color: Theme.outline
    opacity: shown ? 1 : 0
    Behavior on y { NumberAnimation { duration: Theme.dur(260); easing.type: Easing.OutBack } }
    Behavior on opacity { NumberAnimation { duration: Theme.dur(180) } }
    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 14
        Text { text: toast.text; color: Theme.text; font.family: Theme.ui; font.pixelSize: 14 }
        Text {
            visible: toast.action !== ""
            text: toast.action
            color: Theme.accent; font.family: Theme.ui; font.pixelSize: 14; font.weight: Font.DemiBold
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: { if (toast.actionCb) toast.actionCb(); toast.shown = false } }
        }
    }
    SequentialAnimation {
        id: anim
        PropertyAction { target: toast; property: "shown"; value: true }
        PauseAnimation { duration: 3800 }
        PropertyAction { target: toast; property: "shown"; value: false }
    }
}
