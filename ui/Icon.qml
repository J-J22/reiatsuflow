import QtQuick

// Material Symbols icon by ligature name, e.g. Icon { name: "settings" }
Text {
    property string name: ""
    property real size: 20
    text: name
    font.family: "Material Symbols Rounded"
    font.pixelSize: size
    color: Theme.text
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    renderType: Text.NativeRendering
}
