import datetime as dt
import json
import os
import re
import tempfile

DAYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")[:48] or "x"


def expand(p):
    return os.path.expanduser(os.path.expandvars(p))


def read_json(path, default=None):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return default


def write_json(path, data):
    """Atomic write, so the UI never reads half a file."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), suffix=".tmp")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    os.replace(tmp, path)


def parse_date(s):
    return dt.date.fromisoformat(s)


def daterange(a, b):
    d = a
    while d <= b:
        yield d
        d += dt.timedelta(days=1)


def weekday(d):
    return DAYS[d.weekday()]
