import datetime as dt
import json
import os
import shutil
import tempfile
import unittest

from rf import config
from rf.core import Planner

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MON = dt.date(2026, 1, 5)


class PlannerTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        shutil.copytree(os.path.join(ROOT, "examples", "sources"), os.path.join(self.tmp, "sources"))
        with open(os.path.join(ROOT, "examples", "config.json")) as f:
            cfg = json.load(f)
        cfg["data_dir"] = self.tmp
        path = os.path.join(self.tmp, "config.json")
        with open(path, "w") as f:
            json.dump(cfg, f)
        self.p = Planner(config.load(path))
        self.p.build()
        self.set_today(MON)

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def set_today(self, d):
        self.p.today = lambda: d

    def finish(self, d):
        for t in self.p.day(d)["tasks"]:
            self.p.done(t["id"])

    def test_build_counts_and_skip(self):
        course = self.p.tracks()["course"]["items"]
        self.assertEqual(len(course), 9)
        win = [it for it in course if "Windows" in it["title"]][0]
        self.assertEqual(win["status"], "skipped")

    def test_rebuild_keeps_progress(self):
        self.finish(MON)
        done = [it["id"] for it in self.p.tracks()["dsa"]["items"] if it["status"] == "done"]
        self.p._tracks = None
        self.p.build()
        again = [it["id"] for it in self.p.tracks()["dsa"]["items"] if it["status"] == "done"]
        self.assertEqual(done, again)

    def test_subjects_rotate_and_stop_at_unit(self):
        tasks = [t for t in self.p.day(MON)["tasks"] if t["track"] == "subjects"]
        self.assertEqual(len(tasks), 2)
        self.assertTrue(tasks[0]["title"].startswith("OS"))
        self.assertTrue(tasks[1]["title"].startswith("CN"))

    def test_lecture_batch_respects_minutes_and_section(self):
        t = [t for t in self.p.day(MON)["tasks"] if t["track"] == "course"][0]
        items = {it["id"]: it for it in self.p.tracks()["course"]["items"]}
        self.assertGreaterEqual(sum(items[i]["size"] for i in t["items"]), 19)
        self.assertEqual({items[i]["group"] for i in t["items"]}, {"1. Getting started"})

    def test_undone_queue_task_stays_first(self):
        first = self.p.day(MON)["tasks"]
        tue = MON + dt.timedelta(days=1)
        self.set_today(tue)
        second = self.p.day(tue)["tasks"]
        self.assertEqual([t["items"] for t in first if t["track"] == "dsa"],
                         [t["items"] for t in second if t["track"] == "dsa"])
        self.assertEqual(self.p.day(MON, create=False)["tasks"][0]["status"], "skipped")

    def test_auto_low_day_after_three_empty_days(self):
        for k in range(3):
            d = MON + dt.timedelta(days=k)
            self.set_today(d)
            self.p.day(d)
        d = MON + dt.timedelta(days=3)
        self.set_today(d)
        day = self.p.day(d)
        self.assertEqual(day["mode"], "low")
        self.assertEqual(len([t for t in day["tasks"] if t["track"] == "dsa"]), 1)

    def test_project_milestone_repeats_until_done(self):
        sun = MON + dt.timedelta(days=6)
        self.set_today(sun)
        t = [t for t in self.p.day(sun)["tasks"] if t["track"] == "proj"][0]
        self.p.done(t["id"])
        self.p.progress("proj", pct=50, resume="pipes")
        nxt = sun + dt.timedelta(days=7)
        self.set_today(nxt)
        t2 = [t for t in self.p.day(nxt)["tasks"] if t["track"] == "proj"][0]
        self.assertEqual(t["items"], t2["items"])
        self.assertIn("resume: pipes", t2["sub"])

    def test_missed_dated_rolls_then_archives(self):
        x = self.p.add_dated("Assignment", (MON + dt.timedelta(days=1)).isoformat())
        for k in range(1, 7):
            d = MON + dt.timedelta(days=k)
            self.set_today(d)
            self.p.day(d)
        st = {y["id"]: y for y in self.p.state()["dated"]}
        self.assertEqual(st[x["id"]]["status"], "archived")

    def test_revision_after_queue_is_empty(self):
        for it in self.p.tracks()["subjects"]["items"]:
            it["status"] = "done"
        self.p.save_track("subjects")
        tasks = [t for t in self.p.day(MON)["tasks"] if t["track"] == "subjects"]
        self.assertTrue(all(t["title"].startswith("Revise") for t in tasks))
        self.assertNotEqual(tasks[0]["title"], tasks[1]["title"])

    def test_partial_and_undo(self):
        t = [t for t in self.p.day(MON)["tasks"] if t["track"] == "subjects"][0]
        self.p.toggle_item(t["id"], t["items"][0])
        self.assertEqual(self.p.find_task(t["id"])[1]["status"], "partial")
        self.p.undo(t["id"])
        self.assertEqual(self.p.find_task(t["id"])[1]["status"], "todo")

    def test_streak(self):
        for k in range(3):
            d = MON + dt.timedelta(days=k)
            self.set_today(d)
            self.finish(d)
        self.assertEqual(self.p.streak(MON + dt.timedelta(days=2)), 3)
        self.assertEqual(self.p.streak(MON + dt.timedelta(days=3)), 3)


if __name__ == "__main__":
    unittest.main()


    def test_replan_keeps_done_and_does_not_double_load(self):
        day = self.p.day(MON)
        n = len(day["tasks"])
        first = [t for t in day["tasks"] if t["track"] == "subjects"][0]
        self.p.done(first["id"])
        day = self.p.replan(MON)
        self.assertEqual(len(day["tasks"]), n)
        self.assertIn(first["id"], [t["id"] for t in day["tasks"]])
        self.assertEqual(len({t["id"] for t in day["tasks"]}), n)
        low = self.p.replan(MON, low=True)
        self.assertEqual([t["track"] for t in low["tasks"]].count("subjects"), 1)

class ListFormatAndWeekTest(unittest.TestCase):
    def test_list_md(self):
        from rf.sources import list_md
        items = list_md("# OS\n## Unit 1\n- Processes | 12:30\n1. Threads | 25m\n* Pipes | 1h\nSockets\n# CN\nOSI\n", "x")
        self.assertEqual([i["title"] for i in items], ["Processes", "Threads", "Pipes", "Sockets", "OSI"])
        self.assertEqual([i["size"] for i in items], [13, 25, 60, 10, 10])
        self.assertEqual(items[0]["group"], "OS · Unit 1")
        self.assertEqual(items[4]["tag"], "CN")

    def test_week_grid_and_phases(self):
        tmp = tempfile.mkdtemp()
        try:
            os.makedirs(os.path.join(tmp, "sources"))
            with open(os.path.join(tmp, "sources", "a.md"), "w") as f:
                f.write("## S\n" + "\n".join(f"item {i}" for i in range(20)))
            cfg = {"data_dir": tmp, "tracks": {"a": {"name": "A", "source": "sources/a.md", "format": "list-md",
                                                     "chunk": {"by": "count", "target": 1}}},
                   "week": {"mon": {"load": {"a": 2}, "label": "Busy"}, "sun": {"routines": ["Review"]}},
                   "phases": [{"name": "Exams", "from": "2026-01-12", "to": "2026-01-18", "load": {"a": 3}}]}
            path = os.path.join(tmp, "config.json")
            self.assertEqual(config.save(cfg, path), [])
            p = Planner(config.load(path))
            p.build()
            p.today = lambda: MON
            day = p.day(MON)
            self.assertEqual(day["rule"], "Busy")
            self.assertEqual(len(day["tasks"]), 2)
            sun = MON + dt.timedelta(days=6)
            self.assertEqual([t["title"] for t in p.plan_tasks(sun, set(), {})[1]], ["Review"])
            exam = MON + dt.timedelta(days=8)
            rule, tasks = p.plan_tasks(exam, set(), {})
            self.assertEqual((rule["name"], len(tasks)), ("Exams", 3))
        finally:
            shutil.rmtree(tmp)

    def test_config_validation(self):
        errors = config.save({"tracks": {"Bad Id": {}}, "week": {"funday": {}}}, "/nonexistent/x.json")
        self.assertEqual(len(errors), 4)



class AiTest(unittest.TestCase):
    def test_agent_argv(self):
        from rf import agents
        self.assertEqual(agents.argv({"ai": {"agent": "claude"}}, "review")[0], "claude")
        self.assertEqual(agents.argv({"ai": {"agent": "gemini"}}, "setup")[:2], ["gemini", "--prompt-interactive"])
        self.assertIsNone(agents.argv({"ai": {"agent": "none"}}, "review"))
        custom = agents.argv({"ai": {"agent": "custom", "command": ["my-ai", "--chat"]}}, "review")
        self.assertEqual(custom[:2], ["my-ai", "--chat"])
        self.assertIn("AGENTS.md", custom[2])
        # older configs that only had review_command keep working
        self.assertEqual(agents.argv({"review_command": ["aider", "{prompt}"]}, "review")[0], "aider")

    def test_mcp_session(self):
        import io
        import sys
        from rf import mcp
        tmp = tempfile.mkdtemp()
        try:
            shutil.copytree(os.path.join(ROOT, "examples", "sources"), os.path.join(tmp, "sources"))
            with open(os.path.join(ROOT, "examples", "config.json")) as f:
                cfg = json.load(f)
            cfg["data_dir"] = tmp
            path = os.path.join(tmp, "config.json")
            with open(path, "w") as f:
                json.dump(cfg, f)
            Planner(config.load(path)).build()
            msgs = [{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-06-18"}},
                    {"jsonrpc": "2.0", "method": "notifications/initialized"},
                    {"jsonrpc": "2.0", "id": 2, "method": "tools/list"},
                    {"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "get_today", "arguments": {}}},
                    {"jsonrpc": "2.0", "id": 4, "method": "tools/call", "params": {"name": "complete_task", "arguments": {"task_id": "nope"}}}]
            old_in, old_out = sys.stdin, sys.stdout
            sys.stdin, sys.stdout = io.StringIO("\n".join(json.dumps(m) for m in msgs) + "\n"), io.StringIO()
            try:
                mcp.serve(path)
                out = [json.loads(x) for x in sys.stdout.getvalue().splitlines()]
            finally:
                sys.stdin, sys.stdout = old_in, old_out
            self.assertEqual([m["id"] for m in out], [1, 2, 3, 4])
            self.assertEqual(out[0]["result"]["serverInfo"]["name"], "reiatsuflow")
            self.assertIn("complete_task", [t["name"] for t in out[1]["result"]["tools"]])
            self.assertIn("tasks", json.loads(out[2]["result"]["content"][0]["text"]))
            self.assertTrue(out[3]["result"]["isError"])
        finally:
            shutil.rmtree(tmp)
