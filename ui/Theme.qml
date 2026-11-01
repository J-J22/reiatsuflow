// Colours, fonts and motion. The theme comes from Settings → Appearance:
//   auto      matugen (end-4 and similar) if present, else pywal, else the system light/dark setting
//   matugen / pywal   follow those files live, so wallpaper or theme switches re-colour the app
//   system    built-in Light or Dark, following the desktop's colour-scheme preference
//   a built-in palette, or custom (any JSON file in matugen, pywal or ReiatsuFlow shape)
// While Settings is open with unsaved changes, the draft is previewed live.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "IconCodes.js" as Codes

Singleton {
    id: theme

    readonly property string home: Quickshell.env("HOME")
    readonly property string matugenPath: home + "/.local/state/quickshell/user/generated/colors.json"
    readonly property string pywalPath: home + "/.cache/wal/colors.json"
    readonly property string bleachPath: home + "/.local/state/nvim/bleach-character"

    // ── what the user picked (draft first, for live preview) ──
    readonly property var appearance: {
        const d = Cfg.draft && Cfg.dirty && Cfg.draft.appearance ? Cfg.draft.appearance : null
        return d || (Store.s && Store.s.appearance) || ({ theme: "auto", accent: "theme", motion: "full" })
    }
    readonly property bool reduced: appearance.motion === "reduced"
    function dur(ms) { return reduced ? 0 : ms }

    readonly property var builtins: ({
        "reiatsu":          { label: "Reiatsu", light: false, bg: "#15110e", surface: "#1f1914", surface2: "#2a221c", surface3: "#352b24", text: "#f0dfd7", textDim: "#c4b0a5", outline: "#4d4038", accent: "#ffb347", danger: "#ffb4ab" },
        "dark":             { label: "Dark", light: false, bg: "#121316", surface: "#1b1c20", surface2: "#24262b", surface3: "#2e3036", text: "#e6e6ea", textDim: "#a5a7b0", outline: "#43464e", accent: "#8ab4ff", danger: "#ff8a80" },
        "light":            { label: "Light", light: true, bg: "#f7f6f3", surface: "#ffffff", surface2: "#efede8", surface3: "#e4e1da", text: "#1d1b18", textDim: "#5f5a52", outline: "#d3cfc6", accent: "#c2410c", danger: "#b3261e" },
        "catppuccin-mocha": { label: "Catppuccin Mocha", light: false, bg: "#1e1e2e", surface: "#24273a", surface2: "#313244", surface3: "#45475a", text: "#cdd6f4", textDim: "#a6adc8", outline: "#585b70", accent: "#cba6f7", danger: "#f38ba8" },
        "catppuccin-latte": { label: "Catppuccin Latte", light: true, bg: "#eff1f5", surface: "#e6e9ef", surface2: "#dce0e8", surface3: "#ccd0da", text: "#4c4f69", textDim: "#6c6f85", outline: "#bcc0cc", accent: "#8839ef", danger: "#d20f39" },
        "nord":             { label: "Nord", light: false, bg: "#2e3440", surface: "#3b4252", surface2: "#434c5e", surface3: "#4c566a", text: "#eceff4", textDim: "#c8ced9", outline: "#5e6a80", accent: "#88c0d0", danger: "#bf616a" },
        "gruvbox":          { label: "Gruvbox", light: false, bg: "#282828", surface: "#32302f", surface2: "#3c3836", surface3: "#504945", text: "#ebdbb2", textDim: "#bdae93", outline: "#665c54", accent: "#fabd2f", danger: "#fb4934" },
        "tokyo-night":      { label: "Tokyo Night", light: false, bg: "#1a1b26", surface: "#1f2335", surface2: "#24283b", surface3: "#2f3549", text: "#c0caf5", textDim: "#9aa5ce", outline: "#414868", accent: "#7aa2f7", danger: "#f7768e" }
    })

    // ── source files (watched live) ──
    FileView { id: matugenFile; path: theme.matugenPath; watchChanges: true; onFileChanged: reload(); printErrors: false }
    FileView { id: pywalFile; path: theme.pywalPath; watchChanges: true; onFileChanged: reload(); printErrors: false }
    FileView { id: bleachFile; path: theme.bleachPath; watchChanges: true; onFileChanged: reload(); printErrors: false }
    FileView {
        id: customFile
        path: theme.appearance.theme === "custom" && theme.appearance.custom_path ? theme.expand(theme.appearance.custom_path) : ""
        watchChanges: true; onFileChanged: reload(); printErrors: false
    }
    function expand(p) { return p.startsWith("~/") ? home + p.slice(1) : p }
    function parse(fv) { try { const t = fv.text(); return t ? JSON.parse(t) : null } catch (e) { return null } }

    readonly property var matugen: parse(matugenFile)
    readonly property var pywal: parse(pywalFile)
    readonly property string character: bleachFile.text().trim()
    readonly property bool systemDark: Qt.styleHints.colorScheme !== Qt.ColorScheme.Light

    // ── turn any supported file into our palette ──
    function fromMatugen(m) {
        return { light: lum(m.background) > 0.5, bg: m.background, surface: m.surface_container_low, surface2: m.surface_container,
                 surface3: m.surface_container_high, text: m.on_surface, textDim: m.on_surface_variant,
                 outline: m.outline_variant, accent: m.primary, danger: m.error }
    }
    function fromPywal(w) {
        const bg = w.special.background, fg = w.special.foreground
        return { light: lum(bg) > 0.5, bg: bg, surface: hex(mixc(bg, fg, 0.05)), surface2: hex(mixc(bg, fg, 0.09)),
                 surface3: hex(mixc(bg, fg, 0.14)), text: fg, textDim: hex(mixc(fg, bg, 0.35)), outline: hex(mixc(fg, bg, 0.72)),
                 accent: w.colors.color4, danger: w.colors.color1 }
    }
    function fromAny(j) {
        if (!j) return null
        if (j.background && j.on_surface) return fromMatugen(j)
        if (j.special && j.colors) return fromPywal(j)
        if (j.bg && j.text) return Object.assign({ light: lum(j.bg) > 0.5, surface: j.bg, surface2: j.bg, surface3: j.bg,
                                                   textDim: j.text, outline: j.text, accent: j.text, danger: "#e05555" }, j)
        return null
    }

    readonly property string source: {
        const t = appearance.theme || "auto"
        if (t !== "auto") return t
        return matugen ? "matugen" : pywal ? "pywal" : "system"
    }
    readonly property var pal: {
        let p = null
        if (source === "matugen") p = matugen ? fromMatugen(matugen) : null
        else if (source === "pywal") p = pywal ? fromPywal(pywal) : null
        else if (source === "custom") p = fromAny(parse(customFile))
        else if (source === "system") p = builtins[systemDark ? "dark" : "light"]
        else p = builtins[source] || null
        return p || builtins[systemDark ? "reiatsu" : "light"]
    }

    readonly property var glow: ({ ichigo: "#ffb347", ulquiorra: "#b8f4ea", aizen: "#e8c98a", urahara: "#d4e88a", byakuya: "#ffc0dc" })
    readonly property bool hasBleach: character !== ""

    readonly property bool isLight: !!pal.light
    readonly property color bg: pal.bg
    readonly property color surface: pal.surface
    readonly property color surface2: pal.surface2
    readonly property color surface3: pal.surface3
    readonly property color text: pal.text
    readonly property color textDim: pal.textDim
    readonly property color outline: pal.outline
    readonly property color danger: pal.danger
    readonly property color accent: {
        const a = appearance.accent || "theme"
        if (a === "bleach" && glow[character]) return isLight ? Qt.darker(glow[character], 1.6) : glow[character]
        if (a && a.startsWith && a.startsWith("#")) return a
        return pal.accent
    }
    // text on an accent-filled surface: dark on light accents, white on dark ones
    readonly property color inkAccent: lum(accent) > 0.45 ? "#1a1612" : "#ffffff"

    // track colours are tuned for dark themes; deepen them on light ones so they stay readable
    function tc(c) { return isLight ? Qt.darker(c, 1.55) : c }

    // ── fonts (bundled, so every system looks the same) ──
    FontLoader { id: pixelFont; source: Qt.resolvedUrl("fonts/PressStart2P.ttf") }
    FontLoader { id: uiFont; source: Qt.resolvedUrl("fonts/Rubik.ttf") }
    FontLoader { id: iconFont; source: Qt.resolvedUrl("fonts/icons.ttf") }
    readonly property string pixel: pixelFont.name || "monospace"
    readonly property string ui: uiFont.name || "sans-serif"
    readonly property string icons: iconFont.name
    readonly property string mono: Qt.fontFamilies().indexOf("JetBrains Mono") >= 0 ? "JetBrains Mono"
                                  : Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") >= 0 ? "JetBrainsMono Nerd Font" : "monospace"
    function icon(name) { const c = Codes.codes[name]; return c ? String.fromCodePoint(c) : "" }

    // ── colour helpers ──
    function lum(c) { const x = Qt.darker(c, 1); return 0.2126 * x.r + 0.7152 * x.g + 0.0722 * x.b }
    function mixc(a, b, t) {
        const x = Qt.darker(a, 1), y = Qt.darker(b, 1)
        return Qt.rgba(x.r + (y.r - x.r) * t, x.g + (y.g - x.g) * t, x.b + (y.b - x.b) * t, 1)
    }
    function mix(a, b, t) { return mixc(a, b, t) }
    function hex(c) { const h = v => Math.round(v * 255).toString(16).padStart(2, "0"); return "#" + h(c.r) + h(c.g) + h(c.b) }

    // a theme change re-colours tracks too (their colours come from rf)
    onIsLightChanged: Store.refresh()
}
