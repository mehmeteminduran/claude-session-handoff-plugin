Save the current AI coding session into a handoff file so Cursor, Claude Code, Codex, or another AI session can continue without losing context.

## Session name

Infer the optional session name from the text the user typed after `/handoff`.

- If a session name is present, slugify it: lowercase, replace spaces and `/` with `-`, and strip anything outside `[a-z0-9._-]`. Write `HANDOFF.<slug>.md` at the repo root.
- If no session name is present, write `HANDOFF.md` at the repo root.

Use `git rev-parse --show-toplevel` to find the repo root. From here on, "the handoff file" means the resolved path.

## What to do

1. Read the existing handoff file if present. Preserve useful prior content, but rewrite stale details.
2. Review the current chat context and the repository state. Identify:
   - The current active task, not just the original request.
   - What is done, in flight, blocked, or ruled out.
   - Key decisions and why they were made.
   - Open questions or unknowns.
   - The next concrete action another AI should take.
3. Run `git status --short --branch` and `git diff --stat HEAD`.
4. Write the handoff file using exactly the template below.
5. After saving, print exactly one line:

`Handoff saved -> <relative-path> · next: <next concrete step in <=15 words>`

## Rules

- Current State must reflect the actual working tree. Verify with Git before writing.
- Next Steps must be concrete enough for another AI to execute without asking first.
- Use `file:line` references wherever possible.
- Rewrite "Context for the next tool" from scratch every time.
- Keep the top-level section structure stable.
- Write the handoff in English so it can move across tools.
- One handoff equals one session. If the existing file clearly describes a different active task, warn the user once and ask whether to overwrite or choose a different session.

## Template

```markdown
# Handoff — <session-name-or-branch>
_Last updated: <ISO 8601 timestamp with timezone> · Tool: cursor · Session: <session-slug or "default">_

## Active Task
<One sentence: what we're doing and why. The current task, not the original ask.>

## Current State
**Done:**
- <bullet with file:line refs>

**In flight:**
- <bullet>

**Tried and rejected:**
- <approach> — <why rejected>

## Next Steps
1. <concrete action with file refs>
2. <next>
3. <next>

## Key Decisions
- **Decision:** <what> · **Why:** <reasoning> · **Alternative considered:** <what was rejected and why>

## Open Questions
- [ ] <question that needs human input>

## Working Environment
- Branch: `<name>` · Base: `<main|master>`
- Commands to run: `<build/test/lint commands>`
- Known broken / skipped: <failing tests, lint issues, skipped checks>
- Changed files (`git diff --stat HEAD`):
  ```
  <paste output>
  ```

## Context for the next tool (3-5 sentences)
<Self-contained narrative: what file/system we're touching, what constraint shapes the work, and what an outsider needs to know to make sense of "Next Steps". Mention that Cursor wrote this handoff.>
```

