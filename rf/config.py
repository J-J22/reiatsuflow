import os
import shutil

from .util import expand, read_json

CONFIG_DIR = expand(os.environ.get("RF_CONFIG_DIR", "~/.config/reiatsuflow"))
CONFIG_PATH = os.path.join(CONFIG_DIR, "config.json")
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXAMPLE = os.path.join(REPO, "config.example.json")

DEFAULTS = {
    "data_dir": "~/Documents/planner",
    "day_starts_at": 4,
    "start": None,
    "notify": {"morning": "08:00", "evening": "21:30"},
    "pomodoro": {"work": 25, "short_break": 5, "long_break": 15, "long_every": 4},
    "terminal": ["kitty", "--class", "reiatsuflow-review", "--title", "ReiatsuFlow review"],
    "review_command": ["claude", "Evening review: follow CLAUDE.md in this folder."],
    "rebalance": {"behind_days": 2, "donor": "dsa", "horizon_days": 45},
    "auto_low_after": 3,
    "missed_max_rolls": 3,
    "dated_lookahead": 2,
    "tracks": {},
    "schedule": [],
}


def load(path=None):
    path = path or CONFIG_PATH
    if not os.path.exists(path):
        if path == CONFIG_PATH and os.path.exists(EXAMPLE):
            os.makedirs(CONFIG_DIR, exist_ok=True)
            shutil.copy(EXAMPLE, path)
        else:
            raise SystemExit(f"rf: no config at {path}")
    cfg = {**DEFAULTS, **read_json(path, {})}
    for k in ("notify", "pomodoro", "rebalance"):
        cfg[k] = {**DEFAULTS[k], **cfg.get(k, {})}
    cfg["data_dir"] = expand(cfg["data_dir"])
    cfg["_path"] = path
    return cfg
