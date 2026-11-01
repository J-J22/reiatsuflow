"""Track templates offered by Settings → Add track. Each is a starting point; every field stays editable."""

TEMPLATES = {
    "course": {
        "label": "Course", "icon": "play_lesson", "color": "#ff9f43", "kind": "queue",
        "desc": "Videos or lessons in order. Each day takes about 40 minutes of them "
                "(untimed lessons count as 10 minutes each).",
        "chunk": {"by": "size", "target": 40, "stop_at_group": True},
        "example": "## 1. Getting started\nWelcome | 3:10\nInstalling the tools | 8:45\n\n## 2. Basics\nVariables | 12:00\nFunctions | 14:30",
    },
    "studies": {
        "label": "Studies", "icon": "school", "color": "#6ea8fe", "kind": "queue",
        "desc": "Subjects split into units and topics. Days rotate between subjects, and when the "
                "list is done the track turns into revision blocks.",
        "chunk": {"by": "count", "target": 3, "rotate": "tag", "stop_at_group": True},
        "revise": "re-read your notes, then solve past questions for this unit",
        "example": "# Operating Systems\n## Unit 1: Processes\nProcess vs program\nProcess states\nSchedulers\n\n"
                   "# Computer Networks\n## Unit 1: Basics\nOSI model\nTCP/IP model",
    },
    "project": {
        "label": "Project", "icon": "rocket_launch", "color": "#f687b3", "kind": "project",
        "desc": "Milestones worked on one at a time. The evening review records how far you got "
                "and where to pick up next time.",
        "chunk": {"by": "count", "target": 1},
        "example": "## Tiny shell\nRead-eval loop with fork/exec/wait\nPipes and redirection\nBackground jobs and signals",
    },
    "custom": {
        "label": "Custom", "icon": "tune", "color": "#68d391", "kind": "queue",
        "desc": "Any list: problems, chapters, songs to learn. You choose the chunk size, rotation "
                "and deadline.",
        "chunk": {"by": "count", "target": 2},
        "example": "## Arrays\nReverse an array\nRotate an array\nKadane's algorithm\n\n## Hashing\nTwo sum\nLongest consecutive sequence",
    },
}

COLORS = ["#ff9f43", "#6ea8fe", "#68d391", "#f687b3", "#b794f6", "#4fd1c5", "#f6c453", "#fc8181", "#90cdf4", "#cbd5e0"]
