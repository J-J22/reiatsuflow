"""AI agents ReiatsuFlow can open for the setup and the evening review.

Each preset is a terminal command with `{prompt}` where the opening message goes. The agent works in
the data folder, reads AGENTS.md (CLAUDE.md / GEMINI.md point to it) and changes data only through
`rf`. Flags differ between versions of these tools; if a preset doesn't start yours, pick Custom and
write the command yourself.
"""
import shutil

PRESETS = {
    "claude": {"label": "Claude Code", "cmd": ["claude", "{prompt}"], "url": "https://claude.com/claude-code"},
    "codex": {"label": "Codex CLI", "cmd": ["codex", "{prompt}"], "url": "https://github.com/openai/codex"},
    "gemini": {"label": "Gemini CLI", "cmd": ["gemini", "--prompt-interactive", "{prompt}"],
               "url": "https://github.com/google-gemini/gemini-cli"},
    "opencode": {"label": "OpenCode", "cmd": ["opencode", "--prompt", "{prompt}"], "url": "https://opencode.ai"},
    "custom": {"label": "Custom command", "cmd": []},
    "none": {"label": "No AI", "cmd": []},
}

PROMPTS = {
    "review": "Evening review for ReiatsuFlow: follow the review steps in AGENTS.md in this folder.",
    "setup": ("Set up ReiatsuFlow with me: follow the Setup section of AGENTS.md in this folder. "
              "Ask what I want to study or build, one question at a time."),
}


def current(cfg):
    """(key, label, argv-with-{prompt}) of the configured agent."""
    ai = cfg.get("ai") or {}
    key = ai.get("agent")
    if not key:  # older configs: review_command, else Claude
        key = "custom" if cfg.get("review_command") and cfg["review_command"][0] != "claude" else "claude"
    if key == "custom":
        cmd = ai.get("command") or cfg.get("review_command") or []
        if cmd and not any("{prompt}" in c for c in cmd):
            cmd = list(cmd) + ["{prompt}"]
        return key, (cmd[0] if cmd else "Custom"), cmd
    p = PRESETS.get(key, PRESETS["none"])
    return key, p["label"], p["cmd"]


def listing():
    out = []
    for key, p in PRESETS.items():
        binary = p["cmd"][0] if p["cmd"] else None
        out.append({"key": key, "label": p["label"], "url": p.get("url"), "binary": binary,
                    "installed": bool(binary and shutil.which(binary)) if binary else None})
    return out


def argv(cfg, what):
    key, _, cmd = current(cfg)
    if key == "none" or not cmd:
        return None
    return [c.replace("{prompt}", PROMPTS[what]) for c in cmd]
