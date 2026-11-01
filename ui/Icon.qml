import QtQuick

// Material Symbols icon by name, e.g. Icon { name: "settings" }. Uses the bundled subset
// (ui/fonts/icons.ttf); a new name needs `python3 tools/build_icons.py`.
Text {
    property string name: ""
    property real size: 20
    text: Theme.icon(name)
    font.family: Theme.icons
    font.pixelSize: size
    color: Theme.text
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
