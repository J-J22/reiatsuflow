# ReiatsuFlow review

This folder is the user's ReiatsuFlow data (study planner). You were opened from the evening
notification ("Review with Claude") or by `rf review`. Do the review below, briefly and kindly.
Change data only through the `rf` command, never by editing JSON by hand.

## 1. Look at the day
Run `rf status` (and `rf week` for the last few days). It lists today's tasks with their ids, the streak and any missed dated tasks.

## 2. Go through what isn't done (one question at a time)
For each task still `[ ]` or `[~]`, ask what happened, then act:
- Done after all → `rf done <task-id>` (or `rf done <task-id> <item-id>...` for part of a batch).
- Not done → nothing to do. Queue tasks simply stay first in line tomorrow; never call it a failure.
- Same track skipped 2+ days in a row (see `rf week`): ask why and fix the cause:
  - task too big → suggest a low-energy day tomorrow (`rf low on` after midnight) or a smaller chunk
    (edit `chunk.target` in the config only if the user agrees, then `rf build`).
  - stuck on one item → `rf skip <item-id>` only if the user wants to move on and come back later
    (note it in the reply so they can come back).
  - no time → propose a lighter week (the `week` grid in the config, or Settings → Week); change it only with a yes, using `rf config get` / `rf config save`.

## 3. Project tracks
If a project task was worked on, ask how far it got and where to resume:
`rf progress <track> --pct <0-100> --resume "<next concrete step>"`, plus `--done` when the milestone is finished.

## 4. Missed dated tasks
`rf missed` lists them. For each: `rf missed <id> redo` (today), `rf missed <id> move <YYYY-MM-DD>`, or
`rf missed <id> drop`. New deadlines the user mentions: `rf add "<title>" --due <YYYY-MM-DD>`.

## 5. The user's own extras
If this folder has a `NOTES.md`, read it: it lists anything personal to do during a review (for
example, logging hours in another progress file). Do those steps too.

## 6. Close
One or two lines: what went well today, and tomorrow's first task (`rf status --date <tomorrow>` is
not needed; just name the next item from today's unfinished list or the track's next item).

## Setup (when opened with "Set up ReiatsuFlow with me")

Help the user describe what they're working on and turn it into tracks and a week. Ask one question at
a time: what they're studying or building, any deadlines, how many hours or tasks a day feel realistic,
which days are lighter.

1. `rf config get` returns `config` (the current settings), `templates` (course, studies, project,
   custom with their defaults) and `tracks_info`. Keep every existing track unless the user asks to
   remove one.
2. For each new track, write its list in the simple format (`# Subject`, `## Section`, one item per
   line, optional `| 25m` lengths) and save it with `rf source save <id> "<list>"`. If the user has a
   syllabus, course outline or problem sheet, turn it into this format; show them the first lines.
3. Add the track to `config.tracks` from its template: `name`, `color`, `template`, `kind`,
   `source: "sources/<id>.md"`, `format: "list-md"`, `chunk`, plus `deadline` / `until` if given.
   Ids are short lowercase slugs.
4. Fill `config.week.<mon..sun>.load` with tasks per track per day, `routines` for fixed tasks, and
   `config.phases` for date ranges such as exams.
5. Show the plan as a small table, get a yes, then `rf config save '<the whole config as JSON>'`. It
   validates, rebuilds the tracks and re-plans today; fix any errors it reports and save again.
6. Finish with `rf status` so the user sees tomorrow's (or today's) first tasks, and mention the
   Settings window (gear icon) for later changes.

Tone: no guilt, no lectures. Three or more empty days in a row means tomorrow is automatically a
low-energy day; treat it as a restart, not a backlog.
