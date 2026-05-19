Resume work from a `HANDOFF.md` or `HANDOFF.<session>.md` file created by Cursor, Claude Code, Codex, or another AI coding session.

## Session name

Infer the optional session name from the text the user typed after `/resume`.

- If a session name is present, slugify it: lowercase, replace spaces and `/` with `-`, and strip anything outside `[a-z0-9._-]`. Read `HANDOFF.<slug>.md` at the repo root.
- If no session name is present, read `HANDOFF.md` at the repo root.

Use `git rev-parse --show-toplevel` to find the repo root.

## Steps

1. Locate and read the resolved handoff file.
   - If it does not exist, list sibling files at the repo root matching `HANDOFF*.md`.
   - Stop and tell the user:

```text
No <resolved-path> found.
Available sessions: <comma-separated list of HANDOFF.*.md slugs, or "(none)">
Run /handoff <session> in the source tool, or pass a different session name.
```

2. Verify the handoff against reality before trusting it.
   - Run `git status --short --branch`.
   - Run `git rev-parse --abbrev-ref HEAD`.
   - Run `git log --oneline -5`.
   - Compare the current branch, dirty files, timestamp, and `Session:` header with the handoff.
   - If there is a blocking mismatch, stop and ask the user how to proceed.

3. Print this resume summary, then continue:

```text
Resuming from <resolved-path> (updated <relative time>, written by <tool from header>)
Task: <one line from "Active Task">
Next: <first item from "Next Steps">
<optional: Mismatch: <one-line description>>
```

4. Execute the first concrete item from `Next Steps` unless verification found a blocking mismatch.

5. When that step is done, ask whether to continue with the next item or stop. Do not automatically complete every listed step.

## Rules

- Treat the handoff as a starting point; the code and Git state are ground truth.
- Do not modify the handoff file from `/resume` unless the user explicitly asks.
- Preserve the session name when suggesting follow-up `/handoff`.
- If `Next Steps` is empty or vague, ask the user to clarify.
- If `Open Questions` contains a blocker, surface it before editing.
- Read "Context for the next tool" carefully before touching files.

