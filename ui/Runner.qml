import QtQuick
import Quickshell
import Quickshell.Io

// Runs rf commands one at a time and hands their stdout (parsed as JSON when possible) to a callback.
Scope {
    id: r
    property var queue: []
    readonly property bool busy: proc.running || queue.length > 0
    function run(args, cb) { queue = queue.concat([{ args: args, cb: cb }]); next() }
    function next() {
        if (proc.running || queue.length === 0) return
        proc.job = queue[0]
        queue = queue.slice(1)
        proc.command = [Store.rf].concat(proc.job.args)
        proc.running = true
    }
    Process {
        id: proc
        property var job
        stdout: StdioCollector {
            onStreamFinished: {
                let v = text
                try { v = JSON.parse(text) } catch (e) {}
                if (proc.job && proc.job.cb) proc.job.cb(v)
                Qt.callLater(r.next)
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) console.warn("rf:", text.trim()) }
    }
}
