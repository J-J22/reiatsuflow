import QtQuick
import QtQuick.Layouts

// Settings → Appearance: theme source, accent and motion. Changes preview live; Save keeps them.
Flickable {
    id: page
    readonly property var d: Cfg.draft
    readonly property var ap: d && d.appearance ? d.appearance : ({})
    readonly property var src: Cfg.data ? Cfg.data.theme_sources : ({})
    contentHeight: col.implicitHeight + 20
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    component Section: Text { color: Theme.textDim; font.family: Theme.pixel; font.pixelSize: 9; Layout.topMargin: 12 }
    component Para: Text { Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 13 }

    function set(k, v) { Cfg.edit(dd => { dd.appearance = Object.assign({}, dd.appearance || {}); dd.appearance[k] = v }) }

    // live theme sources first, then the built-ins
    readonly property var options: {
        const o = [
            { key: "auto", label: "Auto", hint: src.matugen ? "using matugen" : src.pywal ? "using pywal" : "using system light/dark", icon: "auto_awesome" },
            { key: "matugen", label: "Wallpaper (matugen)", hint: src.matugen ? "follows your wallpaper" : "not found", icon: "wallpaper", off: !src.matugen },
            { key: "pywal", label: "pywal", hint: src.pywal ? "follows wal" : "not found", icon: "palette", off: !src.pywal },
            { key: "system", label: "System", hint: "light or dark, like your desktop", icon: "contrast" }
        ]
        for (const k in Theme.builtins) o.push({ key: k, label: Theme.builtins[k].label, pal: Theme.builtins[k] })
        o.push({ key: "custom", label: "Custom file", hint: "any colours JSON", icon: "folder_open" })
        return o
    }

    ColumnLayout {
        id: col
        width: page.width
        spacing: 12

        Text { text: "Appearance"; color: Theme.text; font.family: Theme.ui; font.pixelSize: 20; font.weight: Font.Medium }
        Para { text: "Pick where colours come from. Wallpaper and pywal themes follow your theme switches live. Changes preview right away; Save keeps them." }

        Section { text: "THEME" }
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 10; rowSpacing: 10
            Repeater {
                model: page.options
                delegate: Rectangle {
                    id: tcard
                    required property var modelData
                    readonly property bool on: (page.ap.theme || "auto") === modelData.key
                    readonly property var p: modelData.pal
                    Layout.fillWidth: true
                    implicitHeight: 84
                    radius: 14
                    opacity: modelData.off ? 0.5 : 1
                    color: p ? p.bg : (h.hovered ? Theme.surface3 : Theme.surface2)
                    border.width: on ? 2 : 1
                    border.color: on ? Theme.accent : (p ? p.outline : "transparent")
                    Behavior on border.color { ColorAnimation { duration: Theme.dur(130) } }
                    ColumnLayout {
                        anchors { fill: parent; margins: 12 }
                        spacing: 6
                        RowLayout {
                            spacing: 8
                            Icon { visible: !tcard.p; name: tcard.modelData.icon || ""; size: 20; color: tcard.on ? Theme.accent : Theme.textDim }
                            Text {
                                text: tcard.modelData.label
                                color: tcard.p ? tcard.p.text : Theme.text
                                font.family: Theme.ui; font.pixelSize: 14; font.weight: Font.Medium
                            }
                        }
                        // palette strip for built-ins, a hint for live sources
                        Row {
                            visible: !!tcard.p
                            spacing: 4
                            Repeater {
                                model: tcard.p ? [tcard.p.surface2, tcard.p.surface3, tcard.p.textDim, tcard.p.accent, tcard.p.danger] : []
                                delegate: Rectangle { required property var modelData; width: 18; height: 18; radius: 9; color: modelData }
                            }
                        }
                        Text {
                            visible: !tcard.p
                            text: tcard.modelData.hint || ""
                            color: tcard.modelData.off ? Theme.danger : Theme.textDim
                            font.family: Theme.ui; font.pixelSize: 11
                        }
                    }
                    HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: page.set("theme", tcard.modelData.key) }
                }
            }
        }
        ColumnLayout {
            visible: page.ap.theme === "custom"
            Layout.fillWidth: true
            spacing: 6
            Para { text: "Path to a JSON file in matugen shape, pywal shape (special + colors), or {\"bg\", \"surface\", \"surface2\", \"surface3\", \"text\", \"textDim\", \"outline\", \"accent\", \"danger\"}. It's watched, so tools that rewrite it re-theme the app live." }
            Field {
                Layout.fillWidth: true
                mono: true
                placeholder: "~/.config/mytheme/colors.json"
                text: page.ap.custom_path || ""
                onEdited: x => page.set("custom_path", x)
            }
        }

        Section { text: "ACCENT" }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Btn { label: "From the theme"; active: (page.ap.accent || "theme") === "theme"; onClicked: page.set("accent", "theme") }
            Btn {
                visible: !!page.src.bleach
                label: "Bleach character" + (Theme.character ? " (" + Theme.character + ")" : "")
                active: page.ap.accent === "bleach"
                onClicked: page.set("accent", "bleach")
            }
            Repeater {
                model: Cfg.data ? Cfg.data.colors : []
                delegate: Rectangle {
                    required property string modelData
                    width: 34; height: 34; radius: 17
                    color: modelData
                    border.width: page.ap.accent === modelData ? 3 : 0
                    border.color: Theme.text
                    scale: sh.hovered ? 1.12 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.dur(100) } }
                    HoverHandler { id: sh; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: page.set("accent", modelData) }
                }
            }
            Field {
                implicitWidth: 110
                mono: true
                placeholder: "#rrggbb"
                text: page.ap.accent && page.ap.accent.startsWith("#") ? page.ap.accent : ""
                onEdited: x => { if (/^#[0-9a-fA-F]{6}$/.test(x)) page.set("accent", x) }
            }
        }

        Section { text: "MOTION" }
        Toggle {
            Layout.fillWidth: true
            label: "Reduced motion"
            hint: "No sparks, slides or breathing; changes appear instantly. The BANKAI banner still shows, without animation."
            checked: page.ap.motion === "reduced"
            onToggled: c => page.set("motion", c ? "reduced" : "full")
        }

        Section { text: "FONTS" }
        Para { text: "Press Start 2P, Rubik and the icons are bundled, so the app looks the same everywhere. Numbers and code use JetBrains Mono when installed, else your monospace font." }
    }
}
