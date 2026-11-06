import argparse
import fcntl
import json
import os
import shutil
import subprocess
import sys

from . import agents, config
from .core import Planner
from .util import expand, parse_date, write_json

THEME_FILES = {"matugen": "~/.local/state/quickshell/user/generated/colors.json",
               "pywal": "~/.cache/wal/colors.json", "bleach": "~/.local/state/nvim/bleach-character"}
MANAGED = "<!-- ReiatsuFlow: generated, safe to delete; personal steps go in NOTES.md -->"


def notify(title, body, actions=None, wait=False):
    cmd = ["notify-send", "-a", "ReiatsuFlow", "-i", "appointment-soon", title, body]
    for key, label in (actions or {}).items():
        cmd[1:1] = ["-A", f"{key}={label}"]
    if not shutil.which("notify-send"):
        print(f"{title}: {body}")
        return ""
    if wait or actions:
        return subprocess.run(cmd, capture_output=True, text=True).stdout.strip()
    subprocess.Popen(cmd)
    return ""


def print_today(s):
    print(f"{s['dow'].title()} {s['date']} · {s['rule']}" + (" · low-energy day" if s["mode"] == "low" else "")
          + f" · {s['done']}/{s['total']} done · streak {s['streak']}")
    for t in s["tasks"]:
        mark = {"done": "x", "partial": "~"}.get(t["status"], " ")
        print(f"  [{mark}] {t['track_name']:<12} {t['title']}")
        print(f"      {t['sub']}   ({t['id']})")
    if s["missed"]:
        print(f"  Missed: {len(s['missed'])} (rf missed)")


def init(p, cfg):
    os.makedirs(p.dir, exist_ok=True)
    os.makedirs(p.p("sources"), exist_ok=True)
    write_instructions(p)
    settings = p.p(".claude", "settings.json")
    if not os.path.exists(settings):
        write_json(settings, {"permissions": {"allow": ["Bash(rf:*)", "Read", "Edit(./**)"]}})
    counts = p.build()
    for tid, n in counts.items():
        print(f"  {tid:<6} {n} items")
    print(f"rf: data in {p.dir}, config in {cfg['_path']}")


def write_instructions(p):
    """AGENTS.md for any agent, plus CLAUDE.md / GEMINI.md that import it. Files the user wrote
    themselves are left alone; ours are refreshed so instructions follow app updates."""
    with open(os.path.join(config.REPO, "review", "AGENTS.md"), encoding="utf-8") as f:
        body = f.read()
    files = {"AGENTS.md": MANAGED + "\n" + body,
             "CLAUDE.md": MANAGED + "\n@AGENTS.md\n\nAll ReiatsuFlow instructions are in AGENTS.md.\n",
             "GEMINI.md": MANAGED + "\n@AGENTS.md\n\nAll ReiatsuFlow instructions are in AGENTS.md.\n"}
    for name, text in files.items():
        dst = p.p(name)
        if os.path.exists(dst):
            with open(dst, encoding="utf-8") as f:
                old = f.read()
            if not (old.startswith(MANAGED) or old.startswith("# ReiatsuFlow")):
                continue
        with open(dst, "w", encoding="utf-8") as f:
            f.write(text)


def main(argv=None):
    ap = argparse.ArgumentParser(prog="rf", description="ReiatsuFlow: task-based study planner")
    ap.add_argument("--config")
    sub = ap.add_subparsers(dest="cmd")
    sub.add_parser("init", help="create data dir and build tracks from sources")
    sub.add_parser("build", help="rebuild tracks from sources (keeps progress)")
    s = sub.add_parser("status", help="today, as text or JSON")
    s.add_argument("--json", action="store_true")
    s.add_argument("--date")
    sub.add_parser("week", help="this week as JSON")
    s = sub.add_parser("done", help="mark a task (or some of its items) done")
    s.add_argument("task")
    s.add_argument("items", nargs="*")
    s = sub.add_parser("undo", help="undo a task (or some of its items)")
    s.add_argument("task")
    s.add_argument("items", nargs="*")
    s = sub.add_parser("item", help="toggle one item of a task")
    s.add_argument("task")
    s.add_argument("item")
    s = sub.add_parser("skip", help="mark an item skipped (it leaves the queue)")
    s.add_argument("item")
    s = sub.add_parser("progress", help="update a project track's current milestone")
    s.add_argument("track")
    s.add_argument("--pct", type=int)
    s.add_argument("--resume")
    s.add_argument("--done", action="store_true", help="milestone finished")
    s = sub.add_parser("add", help="add a dated task (assignment, booking...)")
    s.add_argument("title")
    s.add_argument("--due", required=True)
    s = sub.add_parser("missed", help="list missed tasks, or redo/move/drop one")
    s.add_argument("id", nargs="?")
    s.add_argument("action", nargs="?", choices=["redo", "move", "drop"])
    s.add_argument("date", nargs="?")
    s = sub.add_parser("low", help="low-energy day on/off (replans today)")
    s.add_argument("onoff", nargs="?", default="on", choices=["on", "off"])
    sub.add_parser("replan", help="rebuild today's untouched tasks")
    s = sub.add_parser("pomo", help="pomodoro: start TASK | stop | tick")
    s.add_argument("action", choices=["start", "stop", "tick"])
    s.add_argument("task", nargs="?")
    s = sub.add_parser("notify", help="send the morning or evening notification")
    s.add_argument("when", choices=["morning", "evening"])
    sub.add_parser("review", help="open the evening review with your AI agent in a terminal")
    sub.add_parser("paths", help="print config and data paths")
    s = sub.add_parser("config", help="settings: get (JSON for the Settings window) | save JSON")
    s.add_argument("action", choices=["get", "save"])
    s.add_argument("json", nargs="?")
    s = sub.add_parser("source", help="track lists: preview FORMAT TEXT | save TRACK TEXT | get TRACK")
    s.add_argument("action", choices=["preview", "save", "get"])
    s.add_argument("target")
    s.add_argument("text", nargs="?")
    sub.add_parser("setup", help="set up tracks and the week by talking to your AI agent")
    s = sub.add_parser("prompt", help="print a review/setup prompt to paste into any chat AI")
    s.add_argument("what", choices=["review", "setup"])
    s = sub.add_parser("ai", help="list agents, or set one: rf ai set claude|codex|gemini|opencode|none|custom [-- CMD…]")
    s.add_argument("action", nargs="?", default="list", choices=["list", "set"])
    s.add_argument("agent", nargs="?")
    s.add_argument("command", nargs=argparse.REMAINDER)
    sub.add_parser("mcp", help="run the MCP server on stdio (for Claude Desktop, Cursor, VS Code, ...)")
    s = sub.add_parser("timers", help="install systemd user timers for the notify times in the config")
    s.add_argument("--remove", action="store_true")

    a = ap.parse_args(argv)
    if a.cmd == "mcp":  # long-running; takes the lock per tool call instead
        from . import mcp
        return mcp.serve(a.config)
    cfg = config.load(a.config)
    p = Planner(cfg)
    os.makedirs(p.dir, exist_ok=True)
    # one rf at a time: the UI, the review and the terminal all read-modify-write the same files
    with open(p.p(".lock"), "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        out = run(a, p, cfg)
    # anything that waits on the user (a notification's buttons) runs after the lock is released,
    # or a notification nobody clicks blocks every other rf call (the UI included)
    return out() if callable(out) else out


def run(a, p, cfg):
    out = None

    if a.cmd == "init":
        return init(p, cfg)
    if a.cmd == "build":
        print(json.dumps(p.build()))
        return
    if a.cmd == "paths":
        print(f"config {cfg['_path']}\ndata   {p.dir}")
        return
    if a.cmd in (None, "status"):
        s = p.status(parse_date(a.date) if getattr(a, "date", None) else None)
        if getattr(a, "json", False):
            print(json.dumps(s, ensure_ascii=False))
        else:
            print_today(s)
        return
    if a.cmd == "week":
        out = p.week()
    elif a.cmd == "done":
        out = p.done(a.task, a.items or None)
    elif a.cmd == "undo":
        out = p.undo(a.task, a.items or None)
    elif a.cmd == "item":
        out = p.toggle_item(a.task, a.item)
    elif a.cmd == "skip":
        p.skip_item(a.item)
    elif a.cmd == "progress":
        out = p.progress(a.track, a.pct, a.resume, a.done)
    elif a.cmd == "add":
        out = p.add_dated(a.title, parse_date(a.due).isoformat())
    elif a.cmd == "missed":
        if not a.id:
            out = [x for x in p.state()["dated"] if x["status"] == "missed"]
        elif a.action == "redo":
            out = p.dated_set(a.id, "open", p.today().isoformat())
        elif a.action == "move":
            out = p.dated_set(a.id, "open", parse_date(a.date).isoformat())
        elif a.action == "drop":
            out = p.dated_set(a.id, "dropped")
    elif a.cmd == "low":
        out = p.replan(low=a.onoff == "on")
    elif a.cmd == "replan":
        out = p.replan()
    elif a.cmd == "pomo":
        if a.action == "start":
            out = p.pomo_start(a.task)
        elif a.action == "stop":
            p.pomo_stop()
        else:
            out = p.pomo_tick(notify=notify)
    elif a.cmd == "notify":
        s = p.status()
        if not s["tasks"]:
            return  # nothing planned (before the start date, or a free day): stay quiet
        if a.when == "morning":
            lines = [f"• {t['track_name']}: {t['title']}" for t in s["tasks"]]
            head = f"Today · {len(lines)} tasks" + (" (low-energy day)" if s["mode"] == "low" else "")
            notify(head, "\n".join(lines[:9]) or "Nothing planned. Enjoy the day.")
        else:
            left = s["total"] - s["done"]
            msg = f"{s['done']}/{s['total']} done" + (f", {left} left" if left else ". Clean sweep.")
            key, label, _ = agents.current(cfg)
            if key == "none":
                notify("Review time", msg)
            else:
                def ask():
                    if notify("Review time", msg + f"\nGo through the day with {label}?", {"review": f"Review with {label}"}) == "review":
                        return review(p, cfg, "review")
                return ask
        return
    elif a.cmd == "review":
        return review(p, cfg, "review")
    elif a.cmd == "prompt":
        print(chat_prompt(p, a.what))
        return
    elif a.cmd == "ai":
        return ai_cmd(a, cfg)
    elif a.cmd == "config":
        return config_cmd(a, p, cfg)
    elif a.cmd == "source":
        out = source_cmd(a, p, cfg)
    elif a.cmd == "setup":
        return review(p, cfg, "setup")
    elif a.cmd == "timers":
        return timers(cfg, a.remove)
    if out is not None:
        print(json.dumps(out, ensure_ascii=False, indent=1))


UNIT_DIR = os.path.expanduser("~/.config/systemd/user")


def timers(cfg, remove=False):
    """One oneshot service + timer per notification, times taken from config["notify"]."""
    rf = shutil.which("rf") or os.path.join(config.REPO, "bin", "rf")
    names = []
    for when, at in cfg["notify"].items():
        name = f"reiatsuflow-{when}"
        names.append(name)
        if remove:
            subprocess.run(["systemctl", "--user", "disable", "--now", f"{name}.timer"], check=False)
            for ext in ("service", "timer"):
                path = os.path.join(UNIT_DIR, f"{name}.{ext}")
                if os.path.exists(path):
                    os.remove(path)
            continue
        os.makedirs(UNIT_DIR, exist_ok=True)
        with open(os.path.join(UNIT_DIR, f"{name}.service"), "w") as f:
            f.write(f"[Unit]\nDescription=ReiatsuFlow {when} notification\n\n"
                    f"[Service]\nType=simple\nExecStart={rf} notify {when}\n")
        with open(os.path.join(UNIT_DIR, f"{name}.timer"), "w") as f:
            f.write(f"[Unit]\nDescription=ReiatsuFlow {when} notification at {at}\n\n"
                    f"[Timer]\nOnCalendar=*-*-* {at}:00\n\n[Install]\nWantedBy=timers.target\n")
    subprocess.run(["systemctl", "--user", "daemon-reload"], check=False)
    if not remove:
        subprocess.run(["systemctl", "--user", "enable", "--now"] + [f"{n}.timer" for n in names], check=False)
    print(("removed " if remove else "installed ") + ", ".join(f"{n}.timer" for n in names))


def config_cmd(a, p, cfg):
    from .templates import COLORS, TEMPLATES
    if a.action == "get":
        info = {}
        for tid, t in p.tracks().items():
            items = [it for it in t["items"] if it["status"] != "skipped"]
            info[tid] = {"items": len(items), "done": sum(1 for it in items if it["status"] == "done")}
        key, label, cmd = agents.current(cfg)
        rf = shutil.which("rf") or os.path.join(config.REPO, "bin", "rf")
        print(json.dumps({"config": config.raw(cfg["_path"]), "defaults": config.DEFAULTS, "templates": TEMPLATES,
                          "colors": COLORS, "tracks_info": info, "path": cfg["_path"], "data_dir": p.dir,
                          "agents": agents.listing(), "ai": {"agent": key, "label": label, "command": cmd},
                          "mcp": {"mcpServers": {"reiatsuflow": {"command": rf, "args": ["mcp"]}}},
                          "theme_sources": {k: os.path.exists(os.path.expanduser(v)) for k, v in THEME_FILES.items()}},
                         ensure_ascii=False))
        return
    data = json.loads(a.json)
    errors = config.save(data, cfg["_path"])
    if errors:
        print(json.dumps({"ok": False, "errors": errors}))
        return 1
    p2 = Planner(config.load(cfg["_path"]))
    counts = p2.build()
    p2.replan()
    if cfg["notify"] != p2.cfg["notify"] and shutil.which("systemctl"):
        timers(p2.cfg)
    print(json.dumps({"ok": True, "tracks": counts}))


def source_cmd(a, p, cfg):
    from . import sources
    if a.action == "preview":
        items = sources.FORMATS[a.target](a.text or "", "preview")
        groups = []
        for it in items:
            if it["group"] not in groups:
                groups.append(it["group"])
        return {"count": len(items), "groups": groups[:12], "first": [it["title"] for it in items[:5]],
                "minutes": sum(it["size"] for it in items) if any(it["sub"] for it in items) else None}
    path = p.p("sources", f"{a.target}.md")
    if a.action == "get":
        tc = cfg["tracks"].get(a.target, {})
        src = tc.get("source", f"sources/{a.target}.md")
        full = expand(src) if src.startswith(("~", "/")) else p.p(src)
        try:
            with open(full, encoding="utf-8") as f:
                return {"path": full, "text": f.read()}
        except FileNotFoundError:
            return {"path": full, "text": ""}
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(a.text or "")
    return {"path": f"sources/{a.target}.md"}


def review(p, cfg, what):
    """Open the configured agent in a terminal, in the data folder, for the review or the setup."""
    argv = agents.argv(cfg, what)
    if not argv:
        print("rf: no AI agent configured (Settings → AI, or `rf ai set <agent>`). `rf prompt "
              f"{what}` prints a prompt you can paste into any chat AI instead.")
        return 1
    if not shutil.which(argv[0]):
        notify("ReiatsuFlow", f"Couldn't find `{argv[0]}`. Install it or pick another agent in Settings → AI.")
        return 1
    write_instructions(p)
    subprocess.Popen(list(cfg["terminal"]) + argv, cwd=p.dir, start_new_session=True)


def ai_cmd(a, cfg):
    if a.action == "list":
        key, label, cmd = agents.current(cfg)
        for x in agents.listing():
            mark = "*" if x["key"] == key else " "
            inst = "" if x["installed"] is None else (" (installed)" if x["installed"] else " (not found)")
            print(f" {mark} {x['key']:<9} {x['label']}{inst}")
        return
    if a.agent not in agents.PRESETS:
        raise SystemExit(f"rf: unknown agent {a.agent}; one of {', '.join(agents.PRESETS)}")
    data = config.raw(cfg["_path"])
    cmd = [c for c in (a.command or []) if c != "--"]
    data["ai"] = {"agent": a.agent, **({"command": cmd} if a.agent == "custom" else {})}
    errors = config.save(data, cfg["_path"])
    if errors:
        raise SystemExit("rf: " + "; ".join(errors))
    print(f"agent: {agents.PRESETS[a.agent]['label']}")


def chat_prompt(p, what):
    """A self-contained prompt for AIs that can't run commands (any chat app). The user applies the result."""
    if what == "review":
        s = p.status()
        lines = [f"- [{ {'done': 'x', 'partial': '~'}.get(t['status'], ' ') }] {t['track_name']}: {t['title']} ({t['sub']})"
                 for t in s["tasks"]]
        pace = [f"- {t['name']}: {t['pace']['behind_days']:+.1f} days vs plan (deadline {t['pace']['deadline']})"
                for t in s["tracks"] if t["pace"] and t["active"]]
        missed = [f"- {x['title']} (was due {x['due']})" for x in s["missed"]]
        return "\n".join([
            "You're helping me with my evening review in ReiatsuFlow, a task-based planner. You can't change",
            "my data; at the end I'll apply what we decide in the app.",
            "",
            f"Today, {s['dow'].title()} {s['date']} ({s['rule']}): {s['done']}/{s['total']} done, streak {s['streak']} days.",
            *lines, "",
            *(["Pace (positive = behind):", *pace, ""] if pace else []),
            *(["Missed deadlines:", *missed, ""] if missed else []),
            "Please:",
            "1. Ask me about each unfinished task, one at a time. No guilt: unfinished tasks simply stay first",
            "   in line tomorrow. If a track keeps getting skipped, help me find out why (too big, stuck, no time).",
            "2. For project tasks, ask how far I got (%) and the next concrete step.",
            "3. For missed deadlines, ask: redo today, move to a date, or drop.",
            "4. End with a short checklist of what to tick or change in the app, and tomorrow's first task.",
        ])
    from .templates import TEMPLATES
    tmpl = "\n".join(f"- {t['label']}: {t['desc']}" for t in TEMPLATES.values())
    return "\n".join([
        "Help me set up ReiatsuFlow, a task-based planner. It turns lists into a few tasks a day.",
        "Ask me one question at a time: what I'm studying or building, deadlines, how many tasks a day feel",
        "realistic, and which days are lighter.",
        "",
        "Tracks are made from these templates:", tmpl, "",
        "Each track needs a list in this format (I'll paste it into Settings → Tracks):",
        "  # Subject (optional)", "  ## Section", "  One item per line | optional length like 25m", "",
        "When we're done, give me: (1) each track's name, template and list in that format, (2) a table of",
        "tasks per track for Monday to Sunday, (3) any date ranges (exams, holidays) with their own load.",
    ])


if __name__ == "__main__":
    sys.exit(main())
