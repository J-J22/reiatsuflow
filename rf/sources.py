"""Turn source lists (markdown / JSON) into track items.

Every parser returns a list of item dicts:
    {"id", "title", "group", "sub", "size", "tag"}
`size` is minutes for lecture lists and a weight (1 = a normal topic) elsewhere.
Ids are built from the content, so rebuilding a track keeps progress.
"""
import json
import re

from .util import slug

LAB_HEADING = re.compile(r"^###\s+([A-Z]\d+)\s+—\s+(.+?)(?:\s+\(|\s+·|$)")


def _ids(items, prefix):
    seen = {}
    for it in items:
        base = f"{prefix}:{slug(it['group'])}:{slug(it['title'])}"
        n = seen.get(base, 0)
        seen[base] = n + 1
        it["id"] = base if n == 0 else f"{base}-{n + 1}"
    return items


def roadmap_md(text, prefix, **_):
    """`## Section` headings, then `Category : a, b, c` lines.
    `Theory` lines become one reading item each; `Hard` categories are tagged."""
    items, group = [], None
    for line in text.splitlines():
        if line.startswith("## "):
            group = line[3:].strip()
            continue
        if line.startswith("#") or " : " not in line or not group:
            continue
        cat, rest = (s.strip() for s in line.split(" : ", 1))
        names = [n.strip() for n in rest.split(", ") if n.strip()]
        if cat == "Theory":
            items.append(dict(title="Theory: " + ", ".join(names), group=group, sub="reading", size=1, tag="theory"))
            continue
        for n in names:
            items.append(dict(title=n, group=group, sub=cat, size=1, tag="hard" if cat == "Hard" else ""))
    return _ids(items, prefix)


def lectures_md(text, prefix, **_):
    """`## Section` headings, then `Lecture title | mm:ss` (or `| quiz`)."""
    items, group = [], None
    for line in text.splitlines():
        if line.startswith("## "):
            group = line[3:].strip()
            continue
        if line.startswith("#") or " | " not in line or not group:
            continue
        title, dur = (s.strip() for s in line.rsplit(" | ", 1))
        m = re.match(r"^(\d+):(\d\d)$", dur)
        if m:
            size, tag = int(m.group(1)) + (1 if int(m.group(2)) >= 30 else 0), ""
        else:
            size, tag = 10, dur  # quiz / exam
        items.append(dict(title=title, group=group, sub=dur, size=max(size, 1), tag=tag))
    return _ids(items, prefix)


def milestones_md(text, prefix, **_):
    """`## Project` headings, then `- M1 text` milestone lines."""
    items, group = [], None
    for line in text.splitlines():
        if line.startswith("## "):
            group = line[3:].strip()
            continue
        m = re.match(r"^-\s+(\S+)\s+(.*)$", line)
        if m and group:
            items.append(dict(title=f"{m.group(1)} {m.group(2).strip()}", group=group, sub=m.group(1), size=1, tag="milestone"))
    return _ids(items, prefix)


TAG_WEIGHT = {"Quick": 0.5, "Exam": 1, "Go deep": 1.5}


def topics_json(text, prefix, wrapups=None, **_):
    """{"topics": [{"s": subject, "u": unit, "unit": name, "n", "t", "tag"}]}.
    `wrapups` (optional) adds one "Try it + PYQs" item at the end of each unit."""
    topics = json.loads(text)["topics"]
    items, last_key = [], None
    for t in topics:
        key = (t["s"], t["u"])
        if wrapups and last_key and key != last_key:
            items.append(_wrap(last_key, wrapups))
        last_key = key
        items.append(dict(
            title=f"{t['n']} {t['t']}", group=f"{t['s']} · Unit {t['u']}: {t['unit']}",
            sub=t["tag"], size=TAG_WEIGHT.get(t["tag"], 1), tag=t["s"]))
    if wrapups and last_key:
        items.append(_wrap(last_key, wrapups))
    return _ids(items, prefix)


def _wrap(key, wrapups):
    s, u = key
    unit_items = [t for t in wrapups["topics"] if (t["s"], t["u"]) == key]
    try_it = wrapups.get("try", {}).get(f"{s}.{u}", "")
    return dict(title=f"{s} Unit {u} wrap-up: Try it + PYQs", group=f"{s} · Unit {u}: {unit_items[0]['unit']}",
                sub=try_it or "previous-year questions for this unit", size=1, tag=s)


def labs_md(text, prefix, include=(), **_):
    """`### S1 — Title (Week 3) · cost` headings from an AWS LABS.md."""
    items = []
    for line in text.splitlines():
        m = LAB_HEADING.match(line)
        if m and (not include or m.group(1) in include):
            cost = line.split("·", 1)[1].strip() if "·" in line else "free"
            items.append(dict(title=f"Lab {m.group(1)}: {m.group(2).strip()}", group="AWS labs",
                              sub=cost, size=1, tag=m.group(1)))
    return _ids(items, prefix)


DURATION = re.compile(r"\s*\|\s*(?:(\d+):(\d\d)|(\d+)\s*(m|min|mins|h|hr|hrs)?)\s*$", re.I)
BULLET = re.compile(r"^\s*(?:[-*+]|\d+[.)]|\[[ xX]\])\s+")


def list_md(text, prefix, **_):
    """The everyday format. `# Subject` (optional) and `## Section` headings, then one item per line.
    Bullets and numbering are fine. An optional `| 12:30`, `| 25m` or `| 1h` sets the item's length.
    Untimed items count as 10 minutes when a track is chunked by minutes."""
    items, h1, h2 = [], "", ""
    for raw in text.splitlines():
        line = raw.rstrip()
        if not line.strip() or line.lstrip().startswith((">", "<!--")):
            continue
        if line.startswith("# "):
            h1, h2 = line[2:].strip(), ""
            continue
        if line.startswith("## "):
            h2 = line[3:].strip()
            continue
        if line.startswith("#"):
            continue
        title = BULLET.sub("", line).strip()
        size, sub = 10, ""
        m = DURATION.search(title)
        if m:
            title = title[: m.start()].strip()
            if m.group(1):
                size = int(m.group(1)) + (1 if int(m.group(2)) >= 30 else 0)
                sub = f"{m.group(1)}:{m.group(2)}"
            else:
                n = int(m.group(3))
                size = n * 60 if (m.group(4) or "m").lower().startswith("h") else n
                sub = f"{size} min"
        if not title:
            continue
        group = " · ".join(x for x in (h1, h2) if x) or "List"
        items.append(dict(title=title, group=group, sub=sub, size=max(size, 1), tag=h1 or h2 or "List"))
    return _ids(items, prefix)


FORMATS = {
    "list-md": list_md,
    "roadmap-md": roadmap_md,
    "lectures-md": lectures_md,
    "milestones-md": milestones_md,
    "topics-json": topics_json,
    "labs-md": labs_md,
}
