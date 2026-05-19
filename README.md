# session-handoff

A Claude Code plugin that lets you **hand off** an in-flight task from one AI tool to another — Claude Code → Codex, Codex → Cursor, Cursor → a fresh Claude session — without losing decisions, dead-ends, or "what to do next." Sessions are named, so multiple parallel threads of work can coexist in the same repo.

Ships:

- `/handoff [session]` — write the current session's state into `HANDOFF.<session>.md`
- `/resume [session]` — read that file, reconcile with `git status`, and execute the next concrete step
- A **PreCompact hook** that blocks context compaction until a fresh handoff exists, so Claude Code never silently summarizes away your unsaved state

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

A single `HANDOFF.md` collapses all three into one document and loses fidelity. With `/handoff auth-refactor`, `/handoff dlq-bug`, `/handoff analytics-spike`, each thread keeps its own file (`HANDOFF.auth-refactor.md`, etc.) and you can resume whichever you want with `/resume auth-refactor`. The plugin's PreCompact hook looks at the freshest handoff across all sessions, so naming is purely organizational — it doesn't change the safety net.

### Why a PreCompact hook?

When Claude Code's context fills up, it summarizes older turns to make room. Summarization is lossy — and worse, it's silent. If you haven't run `/handoff` before that compaction fires, the decisions and dead-ends from the first half of the session can disappear into a five-sentence summary. The hook blocks compaction (auto or manual) and tells Claude: *"run /handoff first."* You stay in control of what gets preserved.

---

## Example flow

```text
# In Claude Code, mid-refactor
> /handoff auth-jwt-rotation
Handoff saved → HANDOFF.auth-jwt-rotation.md · next: replace JWKS cache TTL in auth/jwt.ts:142

# Switch to Codex in the same repo
$ codex
> /resume auth-jwt-rotation
Resuming from HANDOFF.auth-jwt-rotation.md (updated 2m ago, written by claude-code)
Task: rotate JWT signing keys without invalidating live sessions
Next: replace JWKS cache TTL in auth/jwt.ts:142

# Codex executes the next step, hands back
> /handoff auth-jwt-rotation
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

After install, the two slash commands are available globally and the PreCompact hook is registered automatically.

## Cursor commands and rules

Cursor does not install Claude Code plugins directly, but this repo also ships a Cursor-native version of the workflow:

```text
.cursor/commands/handoff.md
.cursor/commands/resume.md
.cursor/rules/session-handoff.mdc
```

Copy the `.cursor` directory into any project you open with Cursor. After that, Cursor exposes the commands as project slash commands:

```text
/handoff auth-jwt-rotation
/resume auth-jwt-rotation
```

The Cursor commands read and write the same `HANDOFF.md` / `HANDOFF.<session>.md` files as the Claude Code plugin, so sessions can move between Claude Code, Cursor, Codex, and fresh AI sessions. The Cursor rule keeps the handoff protocol available in normal chats too.

Claude Code's `PreCompact` hook has no exact Cursor equivalent, so the Cursor version focuses on commands and rules rather than blocking context compaction.

---

## Configuration

The PreCompact hook accepts one environment variable:

| Variable                  | Default | Effect                                                                                  |
| ------------------------- | ------- | --------------------------------------------------------------------------------------- |
| `HANDOFF_STALE_SECONDS`   | `600`   | Compaction is blocked when the freshest `HANDOFF*.md` in the project root is older.     |

Set it in your shell or in `~/.claude/settings.json` under `env` to make it project-wide.

---

## File naming reference

| Invocation                       | File written / read                  |
| -------------------------------- | ------------------------------------ |
| `/handoff` (no args)             | `HANDOFF.md` (legacy default)        |
| `/handoff dlq-bug`               | `HANDOFF.dlq-bug.md`                 |
| `/handoff "Auth / JWT rotation"` | `HANDOFF.auth-jwt-rotation.md` (slugified) |
| `/resume dlq-bug`                | `HANDOFF.dlq-bug.md`                 |
| `/resume` (no args)              | `HANDOFF.md`                         |

Slug rules: lowercase, spaces and `/` become `-`, anything outside `[a-z0-9._-]` is stripped.

---

## Windows / Git Bash

The PreCompact hook is a Bash script. On Windows it runs through Git Bash, which Claude Code locates via `CLAUDE_CODE_GIT_BASH_PATH` in `settings.json`. If you've already configured this for other hooks, no extra work is needed.

If you fork the plugin and edit the hook on Windows, make sure your editor saves with **LF** line endings — the bundled `.gitattributes` enforces this, but some editors override it.

---

## License

MIT. See [LICENSE](LICENSE).
