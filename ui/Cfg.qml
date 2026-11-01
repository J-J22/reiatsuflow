// Settings controller: loads the config through `rf config get`, keeps an editable draft,
// saves it back with `rf config save` (which validates, rebuilds tracks and replans today).
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: cfg

    readonly property var days: ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
    readonly property var dayNames: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    property var data: null          // whole `rf config get` reply
    property var draft: null         // config being edited
    property var sources: ({})       // track id -> pasted list text waiting to be saved
    property bool dirty: false
    property bool saving: false
    property var errors: []
    property string message: ""

    property bool loading: false
    signal saved()
    signal loaded()

    function clone(x) { return JSON.parse(JSON.stringify(x)) }
    function load() {
        loading = true
        runner.run(["config", "get"], v => {
            loading = false
            if (typeof v !== "object") { errors = ["Couldn't read the config: " + v]; return }
            data = v
            const d = clone(v.config)
            d.tracks = d.tracks || {}
            d.week = d.week || {}
            for (const k of days) { d.week[k] = d.week[k] || {}; d.week[k].load = d.week[k].load || {} }
            d.phases = d.phases || []
            d.notify = Object.assign({}, v.defaults.notify, d.notify || {})
            d.pomodoro = Object.assign({}, v.defaults.pomodoro, d.pomodoro || {})
            d.rebalance = Object.assign({}, v.defaults.rebalance, d.rebalance || {})
            for (const k of ["day_starts_at", "auto_low_after", "missed_max_rolls"])
                if (d[k] === undefined) d[k] = v.defaults[k]
            draft = d
            sources = {}
            dirty = false
            errors = []
            loaded()
        })
    }
    // mutate the draft through f(draft), then re-assign so bindings update
    function edit(f) { const d = clone(draft); f(d); draft = d; dirty = true; message = "" }
    function setSource(id, text) { const s = Object.assign({}, sources); s[id] = text; sources = s; dirty = true }

    function slug(s) { return (s || "track").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 24) || "track" }
    function addTrack(key) {
        const t = data.templates[key]
        let id = slug(t.label), n = 2
        while (draft.tracks[id]) id = slug(t.label) + "-" + n++
        const used = Object.values(draft.tracks).map(x => x.color)
        const color = data.colors.find(c => !used.includes(c)) || t.color
        edit(d => {
            d.tracks[id] = { name: t.label, color: color, template: key, kind: t.kind,
                             source: "sources/" + id + ".md", format: "list-md", chunk: clone(t.chunk) }
            if (t.revise) d.tracks[id].revise = t.revise
            for (const k of days) d.week[k].load[id] = (key === "project" && k !== "sun") ? 0 : 1
        })
        setSource(id, "")
        return id
    }
    function deleteTrack(id) {
        edit(d => {
            delete d.tracks[id]
            for (const k of days) delete d.week[k].load[id]
            for (const ph of d.phases) if (ph.load) delete ph.load[id]
            if (d.rebalance && d.rebalance.donor === id) d.rebalance.donor = null
        })
        const s = Object.assign({}, sources); delete s[id]; sources = s
    }

    function save() {
        if (!draft || saving) return
        saving = true; errors = []; message = ""
        for (const id in sources) runner.run(["source", "save", id, sources[id]], null)
        runner.run(["config", "save", JSON.stringify(draft)], v => {
            saving = false
            if (v && v.ok) { message = "Saved"; dirty = false; sources = {}; Store.refresh(); saved(); load() }
            else errors = v && v.errors ? v.errors : ["Save failed: " + v]
        })
    }

    Runner { id: runner }
    function run(args, cb) { runner.run(args, cb) }
}
