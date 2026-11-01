import argparse
import fcntl
import json
import os
import shutil
import subprocess
import sys

from . import config
from .core import Planner
from .util import parse_date, write_json

REVIEW_PROMPT = "Evening review: follow CLAUDE.md in this folder."


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
    repo = config.REPO
    for name in ("CLAUDE.md",):
        dst = p.p(name)
        if not os.path.exists(dst):
            shutil.copy(os.path.join(repo, "review", name), dst)
    settings = p.p(".claude", "settings.json")
    if not os.path.exists(settings):
        write_json(settings, {"permissions": {"allow": ["Bash(rf:*)", "Read", "Edit(./**)"]}})
    counts = p.build()
    for tid, n in counts.items():
        print(f"  {tid:<6} {n} items")
    print(f"rf: data in {p.dir}, config in {cfg['_path']}")


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
    sub.add_parser("review", help="open the evening review with Claude in a terminal")
    sub.add_parser("paths", help="print config and data paths")
    s = sub.add_parser("timers", help="install systemd user timers for the notify times in the config")
    s.add_argument("--remove", action="store_true")

    a = ap.parse_args(argv)
    cfg = config.load(a.config)
    p = Planner(cfg)
    os.makedirs(p.dir, exist_ok=True)
    # one rf at a time: the UI, the review and the terminal all read-modify-write the same files
    with open(p.p(".lock"), "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        return run(a, p, cfg)


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
            if notify("Review time", msg + "\nGo through the day with Claude?", {"review": "Review with Claude"}) == "review":
                return review(p, cfg)
        return
    elif a.cmd == "review":
        return review(p, cfg)
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


def review(p, cfg):
    cmd = list(cfg["terminal"]) + ["--directory", p.dir] + list(cfg["review_command"] or ["claude", REVIEW_PROMPT])
    subprocess.Popen(cmd, start_new_session=True)


if __name__ == "__main__":
    sys.exit(main())
