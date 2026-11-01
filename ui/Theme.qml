// Colours come from the end-4 / matugen palette (follows the wallpaper), the accent from the
// current Bleach character (bleach.sh writes it), so ReiatsuFlow re-themes with the rice.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme

    readonly property var glow: ({
        ichigo: "#ffb347", ulquiorra: "#b8f4ea", aizen: "#e8c98a",
        urahara: "#d4e88a", byakuya: "#ffc0dc"
    })
    property var pal: {
        try { return JSON.parse(paletteFile.text()) } catch (e) { return {} }
    }
    readonly property string character: characterFile.text().trim()

    readonly property color bg: pal.background ?? "#15110e"
    readonly property color surface: pal.surface_container_low ?? "#1f1914"
    readonly property color surface2: pal.surface_container ?? "#251e19"
    readonly property color surface3: pal.surface_container_high ?? "#302823"
    readonly property color text: pal.on_surface ?? "#f0dfd7"
    readonly property color textDim: pal.on_surface_variant ?? "#d7c2b8"
    readonly property color outline: pal.outline_variant ?? "#52443c"
    readonly property color accent: glow[character] ?? pal.primary ?? "#ffb68e"
    readonly property color inkAccent: "#1a120d"
    readonly property color danger: pal.error ?? "#ffb4ab"

    readonly property string pixel: "Press Start 2P"
    readonly property string ui: "Rubik"
    readonly property string mono: "JetBrainsMono Nerd Font"

    // blend two colours (strings or colors); Qt.darker(x, 1) turns a "#rrggbb" string into a color
    function mix(a, b, t) {
        const x = Qt.darker(a, 1), y = Qt.darker(b, 1)
        return Qt.rgba(x.r + (y.r - x.r) * t, x.g + (y.g - x.g) * t, x.b + (y.b - x.b) * t, 1)
    }

    FileView {
        id: paletteFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell/user/generated/colors.json"
        watchChanges: true
        onFileChanged: reload()
    }
    FileView {
        id: characterFile
        path: Quickshell.env("HOME") + "/.local/state/nvim/bleach-character"
        watchChanges: true
        onFileChanged: reload()
    }
}
