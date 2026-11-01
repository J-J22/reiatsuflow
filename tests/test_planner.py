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
