// All data goes through the rf CLI: `rf status --json` to read, `rf <action>` to change things.
// Changes made elsewhere (an AI review, MCP, the terminal) show up through the file watchers.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: store

    readonly property string rf: Quickshell.env("RF_BIN") || (Quickshell.env("HOME") + "/.local/bin/rf")
    property var s: null
    property string error: ""
    property var queue: []
    property bool again: false

    function refresh() {
        if (statusProc.running) { again = true; return }
        statusProc.running = true
    }
    signal acted(var args)
    function run(args) {
        queue = queue.concat([args])
        acted(args)
        next()
    }
    function next() {
        if (actProc.running || queue.length === 0) return
        actProc.command = [rf].concat(queue[0])
        queue = queue.slice(1)
        actProc.running = true
    }

    Process {
        id: statusProc
        command: [store.rf, "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const v = JSON.parse(text)
                    // track colours are tuned for dark themes; deepen them on light ones
                    for (const t of v.tasks) t.color = Theme.tc(t.color)
                    for (const t of v.tracks) t.color = Theme.tc(t.color)
                    for (const d of v.week) for (const t of d.tasks) t.color = Theme.tc(t.color || "#999999")
                    store.s = v; store.error = ""
                }
                catch (e) { store.error = "rf status failed: " + text.slice(0, 200) }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length) store.error = text.trim().split("\n").pop()
        }
        onExited: if (store.again) { store.again = false; store.refresh() }
    }
    Process {
        id: actProc
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length) store.error = text.trim().split("\n").pop()
        }
        onExited: { store.next(); if (store.queue.length === 0) store.refresh() }
    }

    // external edits (review, terminal) → refresh
    FileView {
        path: store.s ? store.s.data_dir + "/state.json" : ""
        watchChanges: true
        onFileChanged: store.refresh()
    }
    FileView {
        path: store.s ? store.s.data_dir + "/days/" + store.s.date + ".json" : ""
        watchChanges: true
        onFileChanged: store.refresh()
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: store.refresh() }
    Component.onCompleted: refresh()
}
