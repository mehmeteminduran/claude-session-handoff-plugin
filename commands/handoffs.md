---
description: List the handoff sessions saved in this repo with their age, branch and active task
---

List the handoff files in this repository so the user can choose one to resume. This command is read-only: do not edit, delete, or resume anything.

## Steps

1. Use `git rev-parse --show-toplevel` to find the repo root. Outside a git repository, use the current working directory.
2. Find `HANDOFF.md` and `HANDOFF.*.md` at the repo root with a `Glob` for `HANDOFF*.md`, so untracked files are included.
3. If there are none, print `No handoff files found. Run /handoff [session] to create one.` and stop.
4. Read the header line, the "Active Task" section and the "Branch" line of each file.
5. Print one row per file, newest first:

   ```
   Session        Updated   Branch          Tool         Task
   kafka-dlq      2h ago    fix/dlq-retry   claude-code  wire DLQ retry header in the consumer
   default        9d ago ⚠  main            cursor       rotate JWT signing keys
   ```

   - `Session` is the slug from the file name; `HANDOFF.md` is `default`.
   - Mark a row with ⚠ when "Last updated" is more than 7 days old.
   - Write `(task complete)` in the Task column when "Next Steps" says the task is complete.

6. End with one line: `Resume with /resume <session>.`
