"""Planner: tracks (queues of items), days (tasks picked from tracks), state.

Data dir layout:
    tracks/<id>.json   items with status todo/done/skipped (+ pct/resume for projects)
    days/<date>.json   the tasks planned for that day and what happened to them
    state.json         rotation pointers, dated tasks, pomodoro, last rollover
    log.jsonl          append-only event log
"""
import copy
import datetime as dt
import json
import os
import re
import time

from . import sources
from .util import DAYS, daterange, expand, parse_date, read_json, weekday, write_json


class Planner:
    def __init__(self, cfg):
        self.cfg = cfg
        self.dir = cfg["data_dir"]
        self._tracks = None

    # ---------- paths & storage ----------
    def p(self, *parts):
        return os.path.join(self.dir, *parts)

    def tracks(self):
        if self._tracks is None:
            self._tracks = {}
            for tid in self.cfg["tracks"]:
                t = read_json(self.p("tracks", f"{tid}.json"))
                if t:
                    self._tracks[tid] = t
        return self._tracks

    def save_track(self, tid):
        write_json(self.p("tracks", f"{tid}.json"), self.tracks()[tid])

    def state(self):
        s = read_json(self.p("state.json"), {})
        s.setdefault("rot", {})
        s.setdefault("dated", [])
        s.setdefault("pomo", None)
        s.setdefault("last_rollover", None)
        s.setdefault("low", [])
        return s

    def save_state(self, s):
        write_json(self.p("state.json"), s)

    def log(self, event, **kw):
        os.makedirs(self.dir, exist_ok=True)
        with open(self.p("log.jsonl"), "a", encoding="utf-8") as f:
            f.write(json.dumps({"t": dt.datetime.now().isoformat(timespec="seconds"), "e": event, **kw}, ensure_ascii=False) + "\n")

    def today(self):
        if os.environ.get("RF_TODAY"):  # for testing and screenshots
            return parse_date(os.environ["RF_TODAY"])
        return (dt.datetime.now() - dt.timedelta(hours=self.cfg["day_starts_at"])).date()

    def day_path(self, d):
        return self.p("days", f"{d.isoformat()}.json")

    # ---------- building tracks from sources ----------
    def build(self):
        old = {tid: {it["id"]: it for it in t["items"]} for tid, t in self.tracks().items()}
        self._tracks = {}
        for tid, tc in self.cfg["tracks"].items():
            src = tc["source"]
            path = expand(src) if src.startswith(("~", "/")) else self.p(src)
            if not os.path.exists(path):
                print(f"rf: {tid}: source not found: {path} (skipped)")
                continue
            extra = {}
            if tc.get("wrapups"):
                extra["wrapups"] = read_json(path)
            parse = sources.FORMATS[tc["format"]]
            with open(path, encoding="utf-8") as f:
                items = parse(f.read(), tid, include=tc.get("include", ()), **extra)
            pre = [dict(id=f"{tid}:pre:{i}", title=x["title"], group=x.get("group", "Start"), sub=x.get("sub", ""),
                        size=x.get("size", 1), tag=x.get("tag", "")) for i, x in enumerate(tc.get("prepend", []))]
            items = pre + items
            for it in items:
                prev = old.get(tid, {}).get(it["id"])
                it["status"] = prev["status"] if prev else "todo"
                for k in ("done", "pct", "resume"):
                    if prev and k in prev:
                        it[k] = prev[k]
                if not prev and any(s in it["title"] for s in tc.get("skip", [])):
                    it["status"] = "skipped"
            self._tracks[tid] = {"id": tid, "name": tc["name"], "kind": tc.get("kind", "queue"), "items": items}
            self.save_track(tid)
        return {tid: len(t["items"]) for tid, t in self._tracks.items()}

    # ---------- schedule ----------
    def rule_for(self, d):
        start = self.cfg.get("start")
        if start and d < parse_date(start):
            return {"name": f"Plan starts {parse_date(start).strftime('%a %d %b')}", "load": {}}
        wd = weekday(d)
        for r in self.cfg["schedule"]:
            if r.get("from") and d < parse_date(r["from"]):
                continue
            if r.get("to") and d > parse_date(r["to"]):
                continue
            days = r.get("days", "all")
            if days != "all" and wd not in days:
                continue
            return r
        return {"name": "Free day", "load": {}}

    def active(self, tid, d):
        tc = self.cfg["tracks"].get(tid, {})
        if tc.get("until") and d > parse_date(tc["until"]):
            return False
        start = tc.get("start") or self.cfg.get("start")
        if start and d < parse_date(start):
            return False
        return tid in self.tracks()

    def base_load(self, d):
        r = self.rule_for(d)
        return r, {t: n for t, n in r.get("load", {}).items() if n > 0 and self.active(t, d)}

    # ---------- picking items ----------
    def _unlocked(self, tid, it):
        need = self.cfg["tracks"][tid].get("unlock", {}).get(it.get("tag"))
        if not need:
            return True
        ntid, group = need.split(":", 1)
        items = self.tracks().get(ntid, {}).get("items", [])
        idx = [i for i, x in enumerate(items) if x["group"] == group]
        if not idx:
            return True
        return all(x["status"] != "todo" for x in items[: idx[-1] + 1])

    def next_chunk(self, tid, taken, rot, low=False):
        t = self.tracks()[tid]
        tc = self.cfg["tracks"][tid]
        if t["kind"] == "project":  # a milestone spans days: it stays the task until marked done
            todo = [it for it in t["items"] if it["status"] == "todo"]
            return todo[:1]
        todo = [it for it in t["items"] if it["status"] == "todo" and it["id"] not in taken and self._unlocked(tid, it)]
        if not todo:
            return []
        ch = tc.get("chunk", {"by": "count", "target": 1})
        if ch.get("rotate"):
            tags = []
            for it in todo:
                if it[ch["rotate"]] not in tags:
                    tags.append(it[ch["rotate"]])
            order = sorted(tags, key=lambda g: self._tag_order(t, ch["rotate"]).index(g))
            last = rot.get(tid)
            all_order = self._tag_order(t, ch["rotate"])
            nxt = order[0]
            if last in all_order:
                after = [g for g in all_order[all_order.index(last) + 1:] + all_order[: all_order.index(last) + 1] if g in order]
                nxt = after[0]
            rot[tid] = nxt
            todo = [it for it in todo if it[ch["rotate"]] == nxt]
        out, acc = [], 0
        target = 1 if low else ch.get("target", 1)
        for it in todo:
            if out and ch.get("stop_at_group") and it["group"] != out[0]["group"]:
                break
            out.append(it)
            acc += 1 if ch["by"] == "count" else it["size"]
            if acc >= target:
                break
        return out

    @staticmethod
    def _tag_order(t, key):
        seen = []
        for it in t["items"]:
            if it[key] not in seen:
                seen.append(it[key])
        return seen

    def make_task(self, d, tid, items, i):
        t = self.tracks()[tid]
        if t["kind"] == "project":
            it = items[0]
            sub = it["group"]
            if it.get("pct"):
                sub += f" · {it['pct']}%"
            if it.get("resume"):
                sub += f" · resume: {it['resume']}"
            return dict(id=f"{d}:{tid}:{i}", track=tid, title=it["title"], sub=sub, items=[it["id"]],
                        status="todo", done_items=[], pomos=0)
        by_size = self.cfg["tracks"][tid].get("chunk", {}).get("by") == "size"
        group = items[0]["group"]
        nums = [re.match(r"^(\d+\.\d+) ", x["title"]) for x in items]
        if len(items) == 1:
            title = items[0]["title"]
            sub = " · ".join(s for s in (group, items[0]["sub"]) if s)
        elif any(nums):
            # numbered topics: "OS 1.1–1.4 · Introduction and OS structure"
            subject, _, unit = group.partition(" · ")
            ns = [m.group(1) for m in nums if m]
            extra = " + wrap-up" if len(ns) < len(items) else ""
            rng = ns[0] if ns[0] == ns[-1] else f"{ns[0]}–{ns[-1]}"
            title = f"{subject} {rng}{extra} · {unit.split(': ', 1)[-1]}"
            sub = "; ".join(x["title"].split(" ", 1)[1] if m else x["title"] for x, m in zip(items, nums))
        else:
            noun = "lectures" if by_size else "items"
            title = f"{group} · {len(items)} {noun}"
            sub = items[0]["title"] + " → " + items[-1]["title"]
        if by_size and len(items) > 1:
            sub += f" · ~{sum(x['size'] for x in items)} min"
        return dict(id=f"{d}:{tid}:{i}", track=tid, title=title, sub=sub, items=[x["id"] for x in items],
                    status="todo", done_items=[], pomos=0)

    def plan_tasks(self, d, taken, rot, low=False, rebalance=True):
        rule, load = self.base_load(d)
        if rebalance and not low:
            load = self._rebalance(d, load)
        tasks = []
        for tid, n in load.items():
            for _ in range(1 if low else n):
                items = self.next_chunk(tid, taken, rot, low)
                fb = self.cfg["tracks"][tid].get("fallback")
                if not items and fb and not low and self.active(fb, d):
                    items, tid_used = self.next_chunk(fb, taken, rot, low), fb
                else:
                    tid_used = tid
                if not items and self.cfg["tracks"][tid].get("revise"):
                    tasks.append(self._revision_task(d, tid, rot, len(tasks)))
                    continue
                if not items:
                    break
                taken.update(x["id"] for x in items)
                tasks.append(self.make_task(d, tid_used, items, len(tasks)))
                if self.tracks()[tid_used]["kind"] == "project":
                    break
        for i, title in enumerate(rule.get("fixed", [])):
            tasks.append(dict(id=f"{d}:fixed:{i}", track="fixed", title=title, sub=rule["name"], items=[],
                              status="todo", done_items=[], pomos=0))
        return rule, tasks

    def _revision_task(self, d, tid, rot, i):
        """Queue finished: rotate through its units as revision blocks."""
        t = self.tracks()[tid]
        groups = []
        for it in t["items"]:
            if it["group"] not in groups:
                groups.append(it["group"])
        by_tag = {}
        for g in groups:
            by_tag.setdefault(g.split(" · ")[0], []).append(g)
        order = [g for row in zip(*by_tag.values()) for g in row] or groups
        key = f"{tid}:rev"
        k = (rot.get(key, -1) + 1) % len(order)
        rot[key] = k
        return dict(id=f"{d}:{tid}:{i}", track=tid, title=f"Revise {order[k]}",
                    sub=self.cfg["tracks"][tid]["revise"], items=[], status="todo", done_items=[], pomos=0)

    def _rebalance(self, d, load):
        rb = self.cfg["rebalance"]
        donor = rb["donor"]
        load = dict(load)
        for tid in list(load):
            dl = self.cfg["tracks"][tid].get("deadline")
            if not dl or (parse_date(dl) - d).days > rb["horizon_days"] or tid == donor:
                continue
            p = self.pace(tid, d)
            if p and p["behind_days"] >= rb["behind_days"] and load.get(donor, 0) > self.cfg["tracks"].get(donor, {}).get("min", 1):
                load[tid] += 1
                load[donor] -= 1
        return load

    # ---------- days ----------
    def day(self, d=None, create=True):
        d = d or self.today()
        path = self.day_path(d)
        day = read_json(path)
        if day or not create:
            return day
        st = self.state()
        self.rollover(d, st)
        low = self.auto_low(d) or d.isoformat() in st["low"]
        taken = set()
        rule, tasks = self.plan_tasks(d, taken, st["rot"], low)
        day = {"date": d.isoformat(), "rule": rule["name"], "mode": "low" if low else "normal", "tasks": tasks}
        write_json(path, day)
        self.save_state(st)
        self.log("plan", date=d.isoformat(), tasks=len(tasks), mode=day["mode"])
        return day

    def save_day(self, day):
        write_json(self.day_path(parse_date(day["date"])), day)

    def replan(self, d=None, low=None):
        """Rebuild today's untouched tasks (keeps anything done or partly done)."""
        d = d or self.today()
        day = self.day(d)
        st = self.state()
        if low is not None:
            key = d.isoformat()
            st["low"] = [x for x in st["low"] if x != key] + ([key] if low else [])
            day["mode"] = "low" if low else "normal"
        keep = [t for t in day["tasks"] if t["status"] != "todo" or t["done_items"] or t["pomos"]]
        taken = {i for t in keep for i in t["items"]}
        _, fresh = self.plan_tasks(d, taken, st["rot"], day["mode"] == "low")
        kept_tracks = [t["track"] for t in keep]
        for t in fresh:
            if t["track"] == "fixed" and any(k["title"] == t["title"] for k in keep):
                continue
            if t["track"] in kept_tracks and self.tracks()[t["track"]]["kind"] == "project":
                continue
            keep.append(t)
        for i, t in enumerate(keep):
            t["id"] = f"{d}:{t['track']}:{i}"
        day["tasks"] = keep
        self.save_day(day)
        self.save_state(st)
        self.log("replan", date=d.isoformat(), mode=day["mode"], kept=len(kept_tracks))
        return day

    def auto_low(self, d):
        n = self.cfg["auto_low_after"]
        if not n:
            return False
        for k in range(1, n + 1):
            prev = read_json(self.day_path(d - dt.timedelta(days=k)))
            if not prev or not prev["tasks"] or any(t["status"] in ("done", "partial") or t["done_items"] for t in prev["tasks"]):
                return False
        return True

    def rollover(self, d, st):
        last = parse_date(st["last_rollover"]) if st["last_rollover"] else None
        if last and last >= d:
            return
        steps = (d - last).days if last else 1
        for x in st["dated"]:
            if x["status"] == "open" and parse_date(x["due"]) < d:
                x["status"], x["rolls"] = "missed", 0
            elif x["status"] == "missed":
                x["rolls"] = x.get("rolls", 0) + steps
                if x["rolls"] >= self.cfg["missed_max_rolls"]:
                    x["status"] = "archived"
                    self.log("archived", id=x["id"], title=x["title"])
        if last:
            prev = read_json(self.day_path(d - dt.timedelta(days=1)))
            if prev:
                for t in prev["tasks"]:
                    if t["status"] == "todo":
                        t["status"] = "skipped" if not t["done_items"] else "partial"
                self.save_day(prev)
        st["last_rollover"] = d.isoformat()

    # ---------- actions ----------
    def find_task(self, task_id, d=None):
        if task_id.startswith("dated:"):
            return None, None
        dd = parse_date(task_id.split(":")[0]) if task_id[:4].isdigit() else (d or self.today())
        day = self.day(dd)
        for t in day["tasks"]:
            if t["id"] == task_id:
                return day, t
        raise SystemExit(f"rf: no task {task_id}")

    def _item(self, item_id):
        tid = item_id.split(":")[0]
        for it in self.tracks()[tid]["items"]:
            if it["id"] == item_id:
                return tid, it
        raise SystemExit(f"rf: no item {item_id}")

    def done(self, task_id, items=None):
        if task_id.startswith("dated:"):
            return self.dated_set(task_id.split(":", 1)[1], "done")
        day, t = self.find_task(task_id)
        project = t["track"] in self.tracks() and self.tracks()[t["track"]]["kind"] == "project"
        targets = items or t["items"]
        if not project:
            for iid in targets:
                tid, it = self._item(iid)
                it["status"], it["done"] = "done", day["date"]
                self.save_track(tid)
                if iid not in t["done_items"]:
                    t["done_items"].append(iid)
        if project or set(t["done_items"]) >= set(t["items"]):
            t["status"] = "done"
        else:
            t["status"] = "partial"
        self.save_day(day)
        self.log("done", task=task_id, items=targets)
        return t

    def undo(self, task_id, items=None):
        if task_id.startswith("dated:"):
            return self.dated_set(task_id.split(":", 1)[1], "open")
        day, t = self.find_task(task_id)
        for iid in items or list(t["done_items"]):
            tid, it = self._item(iid)
            if it.get("done") == day["date"]:
                it["status"] = "todo"
                it.pop("done", None)
                self.save_track(tid)
            if iid in t["done_items"]:
                t["done_items"].remove(iid)
        t["status"] = "partial" if t["done_items"] else "todo"
        self.save_day(day)
        self.log("undo", task=task_id)
        return t

    def toggle_item(self, task_id, item_id):
        _, t = self.find_task(task_id)
        return self.undo(task_id, [item_id]) if item_id in t["done_items"] else self.done(task_id, [item_id])

    def progress(self, tid, pct=None, resume=None, done=False):
        t = self.tracks()[tid]
        todo = [it for it in t["items"] if it["status"] == "todo"]
        if not todo:
            raise SystemExit(f"rf: {tid} has nothing left")
        it = todo[0]
        if pct is not None:
            it["pct"] = pct
        if resume is not None:
            it["resume"] = resume
        if done:
            it["status"], it["done"], it["pct"] = "done", self.today().isoformat(), 100
        self.save_track(tid)
        self.log("progress", track=tid, item=it["id"], pct=it.get("pct"), resume=it.get("resume"), done=done)
        return it

    def skip_item(self, item_id):
        tid, it = self._item(item_id)
        it["status"] = "skipped"
        self.save_track(tid)
        self.log("skip", item=item_id)

    def add_dated(self, title, due):
        st = self.state()
        x = {"id": f"d{time.time_ns() // 1000 % 10**10}", "title": title, "due": due, "status": "open", "rolls": 0,
             "created": self.today().isoformat()}
        st["dated"].append(x)
        self.save_state(st)
        self.log("dated-add", **x)
        return x

    def dated_set(self, did, status, due=None):
        st = self.state()
        for x in st["dated"]:
            if x["id"] == did:
                x["status"] = status
                if due:
                    x["due"], x["rolls"] = due, 0
                self.save_state(st)
                self.log("dated", id=did, status=status, due=due)
                return x
        raise SystemExit(f"rf: no dated task {did}")

    # ---------- pomodoro ----------
    def pomo_start(self, task_id):
        st = self.state()
        w = self.cfg["pomodoro"]["work"]
        prev = st["pomo"] or {}
        st["pomo"] = {"task": task_id, "phase": "work", "ends": time.time() + w * 60, "length": w * 60,
                      "count": prev.get("count", 0) if prev.get("date") == self.today().isoformat() else 0,
                      "date": self.today().isoformat()}
        self.save_state(st)
        return st["pomo"]

    def pomo_stop(self):
        st = self.state()
        if st["pomo"]:
            st["pomo"] = {**st["pomo"], "phase": "idle", "ends": None}
        self.save_state(st)

    def pomo_tick(self, notify=None):
        st = self.state()
        p = st["pomo"]
        if not p or p["phase"] == "idle" or time.time() < p["ends"]:
            return p
        pc = self.cfg["pomodoro"]
        if p["phase"] == "work":
            p["count"] += 1
            try:
                day, t = self.find_task(p["task"])
                t["pomos"] += 1
                self.save_day(day)
            except SystemExit:
                pass
            long_ = p["count"] % pc["long_every"] == 0
            b = pc["long_break"] if long_ else pc["short_break"]
            p.update(phase="break", ends=time.time() + b * 60, length=b * 60)
            if notify:
                notify("Pomodoro done", f"{p['count']} today. Take {b} minutes.")
        else:
            p.update(phase="idle", ends=None)
            if notify:
                notify("Break over", "Start the next pomodoro when you're ready.")
        self.save_state(st)
        return p

    # ---------- pace & status ----------
    def pace(self, tid, d=None):
        d = d or self.today()
        tc = self.cfg["tracks"].get(tid, {})
        t = self.tracks().get(tid)
        if not t or not tc.get("deadline"):
            return None
        start = parse_date(tc.get("start") or self.cfg.get("start") or d.isoformat())
        end = parse_date(tc["deadline"])
        days = [x for x in daterange(start, end) if self.base_load(x)[1].get(tid)]
        if not days:
            return None
        items = [it for it in t["items"] if it["status"] != "skipped"]
        total = len(items)
        done = sum(1 for it in items if it["status"] == "done")
        elapsed = sum(1 for x in days if x < d)
        rate = total / len(days)
        expected = rate * elapsed
        return {"total": total, "done": done, "expected": round(expected, 1),
                "behind_days": round((expected - done) / rate, 1) if rate else 0, "deadline": tc["deadline"]}

    def streak(self, d=None):
        """Days in a row with at least one task done. Today only adds, it never breaks the streak."""
        d = d or self.today()

        def active(x):
            day = read_json(self.day_path(x))
            return bool(day) and any(t["status"] in ("done", "partial") or t["done_items"] for t in day["tasks"])

        n = 1 if active(d) else 0
        x = d - dt.timedelta(days=1)
        while active(x):
            n += 1
            x -= dt.timedelta(days=1)
        return n

    def week(self, d=None):
        d = d or self.today()
        monday = d - dt.timedelta(days=d.weekday())
        today = self.day(d)
        taken = {i for t in today["tasks"] for i in t["items"]}
        rot = copy.deepcopy(self.state()["rot"])
        out = []
        for k in range(7):
            x = monday + dt.timedelta(days=k)
            if x < d:
                day = read_json(self.day_path(x))
                tasks = day["tasks"] if day else []
                kind = "past"
            elif x == d:
                tasks, kind = today["tasks"], "today"
            else:
                tasks, kind = self.plan_tasks(x, taken, rot, rebalance=False)[1], "future"
            done = sum(1 for t in tasks if t["status"] == "done")
            out.append({"date": x.isoformat(), "dow": DAYS[k], "kind": kind, "rule": self.rule_for(x)["name"],
                        "planned": len(tasks), "done": done,
                        "tasks": [{"track": t["track"], "title": t["title"], "status": t["status"]} for t in tasks]})
        return out

    def status(self, d=None):
        d = d or self.today()
        p = self.pomo_tick()
        day = self.day(d)
        st = self.state()
        look = d + dt.timedelta(days=self.cfg["dated_lookahead"])
        dated = [x for x in st["dated"] if x["status"] == "open" and parse_date(x["due"]) <= look]
        tracks = []
        for tid, tc in self.cfg["tracks"].items():
            t = self.tracks().get(tid)
            if not t:
                continue
            todo = [it for it in t["items"] if it["status"] == "todo"]
            done = sum(1 for it in t["items"] if it["status"] == "done")
            total = sum(1 for it in t["items"] if it["status"] != "skipped")
            nxt = todo[0] if todo else None
            tracks.append({"id": tid, "name": tc["name"], "color": tc.get("color", "#999999"), "kind": t["kind"],
                           "done": done, "total": total, "active": self.active(tid, d),
                           "until": tc.get("until"), "pace": self.pace(tid, d),
                           "next": nxt["title"] if nxt else None, "next_group": nxt["group"] if nxt else None,
                           "pct": nxt.get("pct") if nxt else None, "resume": nxt.get("resume") if nxt else None})
        colors = {tid: tc.get("color", "#999999") for tid, tc in self.cfg["tracks"].items()}
        names = {tid: tc["name"] for tid, tc in self.cfg["tracks"].items()}
        colors.update(fixed="#a0a0a0", dated="#ff7a7a")
        names.update(fixed="Routine", dated="Due")
        tasks = []
        for t in day["tasks"]:
            sub_items = []
            if t["track"] in self.tracks() and self.tracks()[t["track"]]["kind"] != "project" and len(t["items"]) > 1:
                for iid in t["items"]:
                    _, it = self._item(iid)
                    sub_items.append({"id": iid, "title": it["title"], "sub": it["sub"], "done": iid in t["done_items"]})
            tasks.append({**t, "color": colors.get(t["track"]), "track_name": names.get(t["track"], t["track"]),
                          "sub_items": sub_items})
        for x in dated:
            tasks.append({"id": f"dated:{x['id']}", "track": "dated", "track_name": "Due " + x["due"], "title": x["title"],
                          "sub": "overdue" if parse_date(x["due"]) < d else f"due {x['due']}", "status": "todo",
                          "items": [], "done_items": [], "pomos": 0, "color": colors["dated"], "sub_items": []})
        total = sum(1 for t in tasks if t["track"] != "dated")
        return {
            "date": d.isoformat(), "dow": DAYS[d.weekday()], "rule": day["rule"], "mode": day["mode"],
            "streak": self.streak(d), "tasks": tasks,
            "done": sum(1 for t in tasks if t["status"] == "done" and t["track"] != "dated"), "total": total,
            "missed": [x for x in st["dated"] if x["status"] == "missed"],
            "upcoming": [x for x in st["dated"] if x["status"] == "open"],
            "archived": [x for x in st["dated"] if x["status"] == "archived"][-10:],
            "tracks": tracks, "week": self.week(d),
            "pomo": {**p, "remaining": max(0, int(p["ends"] - time.time())) if p and p.get("ends") else 0} if p else None,
            "pomodoro": self.cfg["pomodoro"], "now": time.time(), "data_dir": self.dir,
        }
