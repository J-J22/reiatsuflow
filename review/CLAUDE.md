# ReiatsuFlow review

This folder is the user's ReiatsuFlow data (study planner). You were opened from the evening
notification ("Review with Claude") or by `rf review`. Do the review below, briefly and kindly.
Change data only through the `rf` command, never by editing JSON by hand.

## 1. Look at the day
Run `rf status`. It lists today's tasks with their ids, the streak and any missed dated tasks.

## 2. Go through what isn't done (one question at a time)
For each task still `[ ]` or `[~]`, ask what happened, then act:
- Done after all → `rf done <task-id>` (or `rf done <task-id> <item-id>...` for part of a batch).
- Not done → nothing to do. Queue tasks simply stay first in line tomorrow; never call it a failure.
- Same track skipped 2+ days in a row (see `rf week`): ask why and fix the cause:
  - task too big → suggest a low-energy day tomorrow (`rf low on` after midnight) or a smaller chunk
    (edit `chunk.target` in the config only if the user agrees, then `rf build`).
  - stuck on one item → `rf skip <item-id>` only if the user wants to move on and come back later
    (note it in the reply so they can come back).
  - no time → propose a lighter load in the config's `schedule`; change it only with a yes.

## 3. Projects (Kala-Kalam `kk`, core projects `proj`)
If a project task was worked on, ask how far it got and where to resume:
`rf progress <track> --pct <0-100> --resume "<next concrete step>"`, plus `--done` when the milestone is finished.

## 4. Missed dated tasks
`rf missed` lists them. For each: `rf missed <id> redo` (today), `rf missed <id> move <YYYY-MM-DD>`, or
`rf missed <id> drop`. New deadlines the user mentions: `rf add "<title>" --due <YYYY-MM-DD>`.

## 5. AWS hours
If AWS SAA lectures or a lab were done, add a row to the session log in
`~/Documents/aws-cert/PROGRESS.md` (date, topic, hours, confidence 1-5, notes) and tick the matching
roadmap item. Ask for the confidence score.

## 6. Close
One or two lines: what went well today, and tomorrow's first task (`rf status --date <tomorrow>` is
not needed; just name the next item from today's unfinished list or the track's next item).

Tone: no guilt, no lectures. Three or more empty days in a row means tomorrow is automatically a
low-energy day; treat it as a restart, not a backlog.
