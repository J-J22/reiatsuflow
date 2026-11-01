"""`rf mcp`: a Model Context Protocol server over stdio, so any MCP client (Claude Desktop, Cursor,
VS Code, LM Studio, ...) can read your day and act on it with the same operations as the app.

Client config:  {"mcpServers": {"reiatsuflow": {"command": "rf", "args": ["mcp"]}}}

Plain JSON-RPC 2.0, one message per line; standard library only.
"""
import fcntl
import json
import os
import sys

from . import config
from .core import Planner

PROTOCOL = "2025-06-18"


def _s(desc, **props):
    req = [k for k, v in props.items() if not v.pop("optional", False)]
    return {"description": desc, "inputSchema": {"type": "object", "properties": props, "required": req}}


STR = lambda d, **kw: {"type": "string", "description": d, **kw}  # noqa: E731
TOOLS = {
    "get_today": _s("Today's plan: tasks with ids, status (todo/partial/done/skipped), batch items, "
                    "streak, pace per track, missed and upcoming dated tasks."),
    "get_week": _s("Monday to Sunday of this week: what happened on past days and what's queued."),
    "complete_task": _s("Mark a task done, or only some items of a batch task.",
                        task_id=STR("Task id from get_today, e.g. 2026-11-09:saa:4 (or dated:<id>)"),
                        item_ids={"type": "array", "items": {"type": "string"}, "optional": True,
                                  "description": "Only these items of the task"}),
    "undo_task": _s("Undo a completed task (or some of its items).",
                    task_id=STR("Task id"),
                    item_ids={"type": "array", "items": {"type": "string"}, "optional": True}),
    "update_project": _s("Record progress on a project track's current milestone.",
                         track=STR("Track id"),
                         pct={"type": "integer", "minimum": 0, "maximum": 100, "optional": True},
                         resume=STR("The next concrete step, shown on the next task", optional=True),
                         milestone_done={"type": "boolean", "optional": True}),
    "set_low_energy": _s("Turn today's low-energy mode on or off (re-plans untouched tasks).",
                         on={"type": "boolean"}),
    "add_deadline": _s("Add a dated task (assignment, booking...).",
                       title=STR("What is due"), due=STR("YYYY-MM-DD")),
    "resolve_missed": _s("Decide what happens to a missed dated task.",
                         id=STR("Dated task id"), action=STR("redo | move | drop", enum=["redo", "move", "drop"]),
                         date=STR("New date for move, YYYY-MM-DD", optional=True)),
    "start_pomodoro": _s("Start a focus timer on a task.", task_id=STR("Task id")),
    "stop_pomodoro": _s("Stop the focus timer."),
    "get_settings": _s("The whole config (tracks, week grid, phases, alerts) plus templates."),
    "save_settings": _s("Replace the whole config. Show the user the change and get a yes first. "
                        "Validated; tracks are rebuilt and today is re-planned.",
                        config={"type": "object", "description": "Full config, as returned by get_settings"}),
    "save_list": _s("Write a track's list (simple format: # Subject, ## Section, one item per line, "
                    "optional '| 25m').", track=STR("Track id"), text=STR("The list")),
}


def _instructions(p):
    path = p.p("AGENTS.md")
    if not os.path.exists(path):
        path = os.path.join(config.REPO, "review", "AGENTS.md")
    with open(path, encoding="utf-8") as f:
        return f.read()


def _call(name, a, cfg_path):
    cfg = config.load(cfg_path)
    p = Planner(cfg)
    os.makedirs(p.dir, exist_ok=True)
    with open(p.p(".lock"), "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if name == "get_today":
            s = p.status()
            for k in ("week", "now", "data_dir", "pomodoro"):
                s.pop(k, None)
            return s
        if name == "get_week":
            return p.week()
        if name == "complete_task":
            return p.done(a["task_id"], a.get("item_ids") or None)
        if name == "undo_task":
            return p.undo(a["task_id"], a.get("item_ids") or None)
        if name == "update_project":
            return p.progress(a["track"], a.get("pct"), a.get("resume"), bool(a.get("milestone_done")))
        if name == "set_low_energy":
            return {"mode": p.replan(low=bool(a["on"]))["mode"]}
        if name == "add_deadline":
            return p.add_dated(a["title"], a["due"])
        if name == "resolve_missed":
            act = a["action"]
            if act == "drop":
                return p.dated_set(a["id"], "dropped")
            return p.dated_set(a["id"], "open", a.get("date") if act == "move" else p.today().isoformat())
        if name == "start_pomodoro":
            return p.pomo_start(a["task_id"])
        if name == "stop_pomodoro":
            p.pomo_stop()
            return {"ok": True}
        if name == "get_settings":
            from .templates import TEMPLATES
            return {"config": config.raw(cfg["_path"]), "templates": TEMPLATES}
        if name == "save_settings":
            errors = config.save(a["config"], cfg["_path"])
            if errors:
                return {"ok": False, "errors": errors}
            p2 = Planner(config.load(cfg["_path"]))
            counts = p2.build()
            p2.replan()
            return {"ok": True, "tracks": counts}
        if name == "save_list":
            path = p.p("sources", f"{a['track']}.md")
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as f:
                f.write(a["text"])
            if a["track"] not in cfg["tracks"]:
                return {"path": f"sources/{a['track']}.md", "note": "now add the track with save_settings"}
            return {"path": f"sources/{a['track']}.md", "items": p.build().get(a["track"])}
    raise ValueError(f"unknown tool {name}")


PROMPTS = {
    "review": "Evening review: go through today with me (unfinished tasks, projects, missed deadlines).",
    "setup": "Set up ReiatsuFlow with me: tracks, lists and the week.",
}


def serve(cfg_path=None):
    def send(msg):
        sys.stdout.write(json.dumps(msg, ensure_ascii=False) + "\n")
        sys.stdout.flush()

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            send({"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": "parse error"}})
            continue
        mid, method, params = msg.get("id"), msg.get("method"), msg.get("params") or {}
        if mid is None:  # notification
            continue
        try:
            if method == "initialize":
                p = Planner(config.load(cfg_path))
                result = {"protocolVersion": params.get("protocolVersion", PROTOCOL),
                          "capabilities": {"tools": {}, "prompts": {}},
                          "serverInfo": {"name": "reiatsuflow", "version": "0.2.0"},
                          "instructions": _instructions(p)}
            elif method == "ping":
                result = {}
            elif method == "tools/list":
                result = {"tools": [{"name": n, **t} for n, t in TOOLS.items()]}
            elif method == "tools/call":
                try:
                    out = _call(params["name"], params.get("arguments") or {}, cfg_path)
                    result = {"content": [{"type": "text", "text": json.dumps(out, ensure_ascii=False)}]}
                except (SystemExit, Exception) as e:  # tool errors go back to the model, not the protocol
                    result = {"content": [{"type": "text", "text": str(e)}], "isError": True}
            elif method == "prompts/list":
                result = {"prompts": [{"name": k, "description": v} for k, v in PROMPTS.items()]}
            elif method == "prompts/get":
                p = Planner(config.load(cfg_path))
                text = (_instructions(p) + "\n\nStart now: call get_today, then do the "
                        + ("review" if params.get("name") == "review" else "Setup") + " steps above with me, "
                        "using the tools instead of the rf commands.")
                result = {"description": PROMPTS.get(params.get("name"), ""),
                          "messages": [{"role": "user", "content": {"type": "text", "text": text}}]}
            else:
                send({"jsonrpc": "2.0", "id": mid, "error": {"code": -32601, "message": f"no method {method}"}})
                continue
            send({"jsonrpc": "2.0", "id": mid, "result": result})
        except Exception as e:  # keep the server alive
            send({"jsonrpc": "2.0", "id": mid, "error": {"code": -32603, "message": str(e)}})
