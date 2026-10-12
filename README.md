# session-handoff

A Claude Code plugin that lets you **hand off** an in-flight task from one AI tool to another — Claude Code → Codex, Codex → Cursor, Cursor → a fresh Claude session — without losing decisions, dead-ends, or "what to do next." Sessions are named, so multiple parallel threads of work can coexist in the same repo.

Ships:

- `/handoff [session]` — write the current session's state into `HANDOFF.<session>.md`
- `/resume [session]` — read that file, reconcile with `git status`, and execute the next concrete step
- `/handoffs` — list the saved sessions with their age, branch and task
- A **compaction guard**: a manual `/compact` is stopped until a fresh handoff exists, and after any compaction Claude is pointed back at the handoff file

In Claude Code, plugin commands are namespaced. If a bare `/resume` opens Claude Code's own conversation picker instead, use `/session-handoff:resume` (likewise `/session-handoff:handoff` and `/session-handoff:handoffs`).

---

## The case — why this exists

Modern AI-assisted development is multi-tool. You start a refactor in Claude Code because its planning is sharp, hit a wall on a tricky regex and ask Codex for a second opinion, then jump to Cursor to wire the change through three files at once. Each tool has its own context window. None of them can see what the others tried, rejected, or decided.

The default workaround is **"copy the conversation into the next tool."** That fails three ways:

1. **You lose nuance.** The conversation contains the *what*, not the *why*. The next tool can read 400 lines of transcript and still not know that you already ruled out approach X because it deadlocks under load.
2. **You lose state.** Half-staged edits, the test you skipped, the lint failure you're tolerating until end-of-day — none of it survives a copy-paste.
3. **You lose the next step.** "Where were we?" is a real cost. Re-deriving "the next concrete action" from a transcript wastes the first 10 minutes of every new session.

`session-handoff` makes the handoff explicit. `/handoff` produces a small, structured Markdown file with five things every AI tool needs to pick up:

- **Active Task** — one sentence, current state of the work (not the original ask)
- **Current State** — what's done, what's in flight, what was tried and rejected
- **Next Steps** — concrete actions with `file:line` references
- **Key Decisions** — the *why*, including alternatives that were ruled out
- **Working Environment** — branch, base, build/test commands, dirty files

Any tool can produce this file. Any tool can consume it. The format is the lingua franca.

### Why "session-based" naming?

In a real codebase you're often juggling more than one thread:

- A refactor of the auth middleware
- A bug fix on the DLQ consumer
- A spike on the new analytics pipeline

A single `HANDOFF.md` collapses all three into one document and loses fidelity. With `/handoff auth-refactor`, `/handoff dlq-bug`, `/handoff analytics-spike`, each thread keeps its own file (`HANDOFF.auth-refactor.md`, etc.) and you can resume whichever you want with `/resume auth-refactor`. Run `/handoffs` to see them all.

### Why a compaction guard?

When Claude Code's context fills up, it summarizes older turns to make room. Summarization is lossy. If you haven't run `/handoff` before that compaction fires, the decisions and dead-ends from the first half of the session can disappear into a five-sentence summary. The plugin does two things about it:

- **Before a manual `/compact`:** if no handoff file was updated in the last 10 minutes, the compaction is stopped and you are told to run `/handoff`, then `/compact` again.
- **After any compaction, manual or automatic:** Claude is told which handoff file is freshest and how old it is, so it can re-read what the summary dropped.

Automatic compaction is never blocked. Claude Code either skips a blocked auto-compaction without telling Claude why, or fails the request that triggered it, so blocking there does more harm than good. Run `/handoff` at natural checkpoints in a long session; that is what protects you when auto-compaction fires.

One limit to know: the guard checks the freshest handoff file in the repo, whichever session it belongs to. A recent handoff for a different thread of work will satisfy it.

---

## Example flow

```text
# In Claude Code, mid-refactor
> /handoff auth-jwt-rotation
Handoff saved → HANDOFF.auth-jwt-rotation.md · next: replace JWKS cache TTL in auth/jwt.ts:142

# Switch to Codex in the same repo (see "Codex" below for setup)
$ codex
> resume auth-jwt-rotation
Resuming from HANDOFF.auth-jwt-rotation.md (updated 2m ago, written by claude-code)
Task: rotate JWT signing keys without invalidating live sessions
Next: replace JWKS cache TTL in auth/jwt.ts:142

# Codex executes the next step, hands back
> handoff auth-jwt-rotation
Handoff saved → HANDOFF.auth-jwt-rotation.md · next: add jwks-rotation integration test in test/auth.spec.ts

# Back in Claude Code, possibly hours later
> /resume auth-jwt-rotation
Resuming from HANDOFF.auth-jwt-rotation.md (updated 1h ago, written by codex)
...
```

Three tools, one task, zero context loss. The PR description practically writes itself from the handoff file's "Key Decisions" section.

---

## Install

```text
/plugin marketplace add eminnduran/claude-handoff-plugin
/plugin install session-handoff@eduran-marketplace
```

Local development (before pushing to GitHub):

```text
/plugin marketplace add C:/Users/you/path/to/claude-handoff-plugin
/plugin install session-handoff@eduran-marketplace
```

After install, the three slash commands are available globally and the hooks are registered automatically.

## Cursor commands and rules

Cursor does not install Claude Code plugins directly, but this repo also ships a Cursor-native version of the workflow:

```text
.cursor/commands/handoff.md
.cursor/commands/resume.md
.cursor/commands/handoffs.md
.cursor/rules/session-handoff.mdc
```

Copy the `.cursor` directory into any project you open with Cursor. After that, Cursor exposes the commands as project slash commands:

```text
/handoff auth-jwt-rotation
/resume auth-jwt-rotation
/handoffs
```

The Cursor commands read and write the same `HANDOFF.md` / `HANDOFF.<session>.md` files as the Claude Code plugin, so sessions can move between Claude Code, Cursor, Codex, and fresh AI sessions. The Cursor rule keeps the handoff protocol available in normal chats too.

Claude Code's compaction hooks have no Cursor equivalent, so the Cursor version ships commands and rules only.

## Codex

Codex reads project instructions from `AGENTS.md`. Append the contents of [codex/AGENTS.md](codex/AGENTS.md) to the `AGENTS.md` at the root of your project. After that, tell Codex `resume auth-jwt-rotation` or `handoff auth-jwt-rotation` in plain words and it follows the same protocol and file format.

---

## Should handoff files be committed?

By default, no. A handoff is working state for one person's in-flight task, and it changes on every `/handoff`. Add this to your project's `.gitignore`:

```text
HANDOFF*.md
```

`/handoff` prints a one-line tip when the file it wrote is neither ignored nor tracked. Commit a handoff only when you mean to pass the task to someone else through the repo. `/resume` treats a tracked handoff file with more caution: it shows the next step and asks before running it, because the file may have come from a clone or pull rather than from your own session.

`/handoff` is told to refer to tokens and keys by variable name only, but that is an instruction to a model, not a guarantee. Skim the file before you commit or share it.

---

## Configuration

The compaction guard reads two environment variables:

| Variable                  | Default | Effect                                                                                  |
| ------------------------- | ------- | --------------------------------------------------------------------------------------- |
| `HANDOFF_STALE_SECONDS`   | `600`   | A manual `/compact` is stopped when the freshest `HANDOFF*.md` at the repo root is older. |
| `HANDOFF_GUARD`           | `on`    | Set to `off` to disable both hooks.                                                     |

Set them in your shell, under `env` in `~/.claude/settings.json` for every project, or under `env` in a project's `.claude/settings.json` for that project only.

---

## File naming reference

| Invocation                       | File written / read                  |
| -------------------------------- | ------------------------------------ |
| `/handoff` (no args)             | The session already saved or resumed in this conversation, else `HANDOFF.md` |
| `/handoff dlq-bug`               | `HANDOFF.dlq-bug.md`                 |
| `/handoff "Auth / JWT rotation"` | `HANDOFF.auth-jwt-rotation.md` (slugified) |
| `/resume dlq-bug`                | `HANDOFF.dlq-bug.md`                 |
| `/resume` (no args)              | `HANDOFF.md`; if it is missing, the only other session, or a list to choose from |

Slug rules: lowercase, spaces and `/` become `-`, anything outside `[a-z0-9._-]` is stripped.

When a task is finished, `/handoff` writes "None — task complete" under Next Steps and `/resume` offers to delete the file, so finished sessions do not pile up.

---

## Contributing

`commands/` is the canonical copy of the command prompts. After editing a file there, run `bash scripts/sync-cursor.sh` to regenerate `.cursor/commands/`. Keep `codex/AGENTS.md` in step by hand; it is a condensed version.

---

## Windows / Git Bash

The compaction guard is a Bash script. On Windows it runs through Git Bash, which Claude Code locates via `CLAUDE_CODE_GIT_BASH_PATH` in `settings.json`. If you've already configured this for other hooks, no extra work is needed.

If you fork the plugin and edit the hook on Windows, make sure your editor saves with **LF** line endings — the bundled `.gitattributes` enforces this, but some editors override it.

---

## License

MIT. See [LICENSE](LICENSE).
