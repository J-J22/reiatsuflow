import datetime as dt
import os
import re
import shutil

from .util import expand, read_json, write_json

CONFIG_DIR = expand(os.environ.get("RF_CONFIG_DIR", "~/.config/reiatsuflow"))
CONFIG_PATH = os.path.join(CONFIG_DIR, "config.json")
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXAMPLE = os.path.join(REPO, "config.example.json")

DEFAULTS = {
    "data_dir": "~/.local/share/reiatsuflow",
    "day_starts_at": 4,
    "start": None,
    "notify": {"morning": "08:00", "evening": "21:30"},
    "pomodoro": {"work": 25, "short_break": 5, "long_break": 15, "long_every": 4},
    "terminal": ["kitty", "--class", "reiatsuflow-review", "--title", "ReiatsuFlow review"],
    "review_command": None,  # older setting; use "ai" now
    "ai": {"agent": "claude"},
    "rebalance": {"behind_days": 2, "donor": None, "horizon_days": 45},
    "auto_low_after": 3,
    "missed_max_rolls": 3,
    "dated_lookahead": 2,
    "tracks": {},
    "week": {},
    "phases": [],
    "schedule": [],
}

DAY_KEYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]


def raw(path=None):
    """The config file as written (no defaults merged), for the Settings window."""
    return read_json(path or CONFIG_PATH, {})


def save(data, path=None):
    """Validate and write the config; keeps one backup (config.json.bak)."""
    path = path or CONFIG_PATH
    errors = []
    tracks = data.get("tracks", {})
    for tid, t in tracks.items():
        if not re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,31}", tid):
            errors.append(f"track id '{tid}': use lowercase letters, digits, - or _")
        if not t.get("name"):
            errors.append(f"track '{tid}' needs a name")
        if not t.get("source"):
            errors.append(f"track '{tid}' needs a list (paste one or pick a file)")
    for day, w in data.get("week", {}).items():
        if day not in DAY_KEYS:
            errors.append(f"week: unknown day '{day}'")
        for tid in w.get("load", {}):
            if tid not in tracks:
                errors.append(f"week {day}: unknown track '{tid}'")
    for ph in data.get("phases", []):
        for k in ("from", "to"):
            if ph.get(k):
                try:
                    dt.date.fromisoformat(ph[k])
                except ValueError:
                    errors.append(f"phase '{ph.get('name')}': {k} must be YYYY-MM-DD")
    if errors:
        return errors
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path):
        shutil.copy(path, path + ".bak")
    write_json(path, {k: v for k, v in data.items() if not k.startswith("_")})
    return []


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
