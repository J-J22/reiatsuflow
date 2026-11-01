import QtQuick
import QtQuick.Layouts
import Quickshell

// Settings → AI. Three ways in: an agent opened in a terminal, any MCP app, or any chat AI by copy-paste.
Flickable {
    id: page
    readonly property var d: Cfg.draft
    readonly property string agent: d && d.ai ? d.ai.agent : "claude"
    readonly property var current: Cfg.data ? Cfg.data.agents.find(a => a.key === agent) : null
    contentHeight: col.implicitHeight + 20
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    component Section: Text { color: Theme.textDim; font.family: Theme.pixel; font.pixelSize: 9; Layout.topMargin: 12 }
    component Para: Text { Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 13 }

    function copy(text, what) { Quickshell.clipboardText = text; Cfg.message = what + " copied to the clipboard" }
    function splitCmd(s) { return (s.match(/"[^"]*"|'[^']*'|\S+/g) || []).map(x => x.replace(/^["']|["']$/g, "")) }
    readonly property var icons: ({ claude: "auto_awesome", codex: "terminal", gemini: "diamond", opencode: "code",
                                    custom: "build", none: "block" })

    ColumnLayout {
        id: col
        width: page.width
        spacing: 12

        Text { text: "AI assistant"; color: Theme.text; font.family: Theme.ui; font.pixelSize: 20; font.weight: Font.Medium }
        Para { text: "Optional. ReiatsuFlow works fully without AI. With one, it can set up your tracks from a conversation and go through each evening with you. Use any of the three ways below." }

        Section { text: "1 · AGENT IN A TERMINAL (SET UP + EVENING REVIEW)" }
        Para { text: "Opened in your data folder; it reads AGENTS.md and changes things only through rf. The buttons in the main window and the evening notification use this one." }
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 10; rowSpacing: 10
            Repeater {
                model: Cfg.data ? Cfg.data.agents : []
                delegate: Rectangle {
                    id: ac
                    required property var modelData
                    readonly property bool on: page.agent === modelData.key
                    Layout.fillWidth: true
                    implicitHeight: 74
                    radius: 14
                    color: on ? Theme.mix(Theme.surface2, Theme.accent, 0.16) : (ah.hovered ? Theme.surface3 : Theme.surface2)
                    border.width: on ? 1 : 0
                    border.color: Theme.accent
                    Behavior on color { ColorAnimation { duration: Theme.dur(130) } }
                    RowLayout {
                        anchors { fill: parent; margins: 12 }
                        spacing: 10
                        Icon { name: page.icons[ac.modelData.key] || "smart_toy"; size: 24; color: ac.on ? Theme.accent : Theme.textDim }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { text: ac.modelData.label; color: Theme.text; font.family: Theme.ui; font.pixelSize: 14; font.weight: Font.Medium }
                            Text {
                                text: ac.modelData.installed === null ? (ac.modelData.key === "none" ? "hide AI buttons" : "your own command")
                                      : ac.modelData.installed ? "installed" : "not installed"
                                color: ac.modelData.installed === false ? Theme.danger : Theme.textDim
                                font.family: Theme.ui; font.pixelSize: 11
                            }
                        }
                    }
                    HoverHandler { id: ah; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: Cfg.edit(dd => {
                            dd.ai = { agent: ac.modelData.key }
                            if (ac.modelData.key === "custom") dd.ai.command = (page.d.ai && page.d.ai.command) || []
                        })
                    }
                }
            }
        }
        ColumnLayout {
            visible: page.agent === "custom"
            Layout.fillWidth: true
            spacing: 6
            Para { text: "Command to run, with {prompt} where the opening message goes (added at the end if you leave it out)." }
            Field {
                Layout.fillWidth: true
                mono: true
                placeholder: "my-agent --interactive {prompt}"
                text: page.d && page.d.ai && page.d.ai.command ? page.d.ai.command.join(" ") : ""
                onEdited: x => Cfg.edit(dd => dd.ai = { agent: "custom", command: page.splitCmd(x) })
            }
        }
        Para {
            visible: !!page.current && page.current.installed === false
            color: Theme.danger
            text: page.current ? page.current.label + " (" + page.current.binary + ") isn't on your PATH yet. Install it" + (page.current.url ? " from " + page.current.url : "") + ", or pick another." : ""
        }
        RowLayout {
            visible: page.agent !== "none"
            spacing: 10
            Btn { label: "✦  Set up with " + (page.current ? page.current.label : "agent"); primary: true; onClicked: Store.run(["setup"]) }
            Btn { label: "Review today"; onClicked: Store.run(["review"]) }
            Para { visible: Cfg.dirty; text: "Save first so the buttons use your new choice."; Layout.fillWidth: true }
        }

        Section { text: "2 · ANY MCP APP (CLAUDE DESKTOP, CURSOR, VS CODE, LM STUDIO…)" }
        Para { text: "Add ReiatsuFlow as an MCP server and your AI app can read your day and tick tasks, update projects and sort deadlines itself. It comes with “review” and “setup” prompts." }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: snippet.implicitHeight + 28
            radius: 12
            color: Theme.surface2
            Text {
                id: snippet
                anchors { left: parent.left; right: copyMcp.left; top: parent.top; margins: 14 }
                text: Cfg.data ? JSON.stringify(Cfg.data.mcp, null, 2) : ""
                color: Theme.text; font.family: Theme.mono; font.pixelSize: 12
                wrapMode: Text.WrapAnywhere
            }
            IconBtn {
                id: copyMcp
                anchors { right: parent.right; top: parent.top; margins: 8 }
                icon: "content_copy"
                tint: Theme.textDim
                onClicked: page.copy(snippet.text, "MCP config")
            }
        }

        Section { text: "3 · ANY CHAT AI (CHATGPT, GEMINI, A LOCAL MODEL…)" }
        Para { text: "Copies a ready-made prompt with today's tasks, pace and missed deadlines (or the setup questions). Paste it into any chat, then apply what you decide here in the app." }
        RowLayout {
            spacing: 10
            Btn { label: "Copy review prompt"; onClicked: Cfg.run(["prompt", "review"], v => page.copy(typeof v === "string" ? v : JSON.stringify(v), "Review prompt")) }
            Btn { label: "Copy setup prompt"; onClicked: Cfg.run(["prompt", "setup"], v => page.copy(typeof v === "string" ? v : JSON.stringify(v), "Setup prompt")) }
        }
    }
}
