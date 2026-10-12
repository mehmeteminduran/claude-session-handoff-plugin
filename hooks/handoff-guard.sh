#!/usr/bin/env bash
# Handoff hooks for Claude Code. One script, two modes:
#
#   precompact   (PreCompact, manual only) blocks a user-typed /compact when no
#                recent handoff file exists, and tells the user to run /handoff
#                first. Auto-compaction is never blocked: a block there is
#                either skipped silently or fails the in-flight request.
#   postcompact  (SessionStart, source=compact) points Claude at the freshest
#                handoff file right after any compaction, so state saved before
#                the summary can be re-read.
#
# Handoff files are `HANDOFF.md` (default) and `HANDOFF.<session>.md` at the
# repo root, the same place /handoff writes them. The freshest mtime wins.

set -u

MODE="${1:-precompact}"

[ "${HANDOFF_GUARD:-on}" = "off" ] && exit 0

STALE_SECONDS=${HANDOFF_STALE_SECONDS:-600}   # 10 minutes default

# Hook input arrives as JSON on stdin; only the trigger is needed.
input=""
[ -t 0 ] || input=$(cat)

# Resolve the repo root like the commands do, so launching Claude from a
# subdirectory still finds the files. Fall back to the project dir outside git.
start_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
ROOT=$(git -C "$start_dir" rev-parse --show-toplevel 2>/dev/null) || ROOT=""
[ -n "$ROOT" ] || ROOT="$start_dir"

mtime_of() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null
}

newest_mtime=0
newest_file=""

# Match HANDOFF.md and HANDOFF.<anything>.md at the repo root.
shopt -s nullglob
for f in "$ROOT"/HANDOFF.md "$ROOT"/HANDOFF.*.md; do
  [ -f "$f" ] || continue
  m=$(mtime_of "$f")
  [ -z "$m" ] && continue
  if [ "$m" -gt "$newest_mtime" ]; then
    newest_mtime=$m
    newest_file=$f
  fi
done
shopt -u nullglob

age=0
base=""
if [ -n "$newest_file" ]; then
  age=$(( $(date +%s) - newest_mtime ))
  base=$(basename "$newest_file")
fi

case "$MODE" in
  precompact)
    case "$input" in
      *'"trigger":"auto"'*|*'"trigger": "auto"'*) exit 0 ;;
    esac

    reason=""
    if [ -z "$newest_file" ]; then
      reason="No HANDOFF.md or HANDOFF.<session>.md found at the repo root."
    elif [ "$age" -gt "$STALE_SECONDS" ]; then
      reason="Freshest handoff ($base) is ${age}s old (threshold ${STALE_SECONDS}s)."
    fi

    if [ -n "$reason" ]; then
      # Exit 2 blocks compaction; stderr is shown to the user.
      echo "$reason Run /handoff (or /handoff <session>) to save this session's state, then run /compact again. Set HANDOFF_GUARD=off to skip this check." >&2
      exit 2
    fi
    ;;

  postcompact)
    # stdout from a SessionStart hook is added to Claude's context.
    if [ -n "$newest_file" ]; then
      echo "Context was just compacted. The handoff file $base at the repo root was last updated ${age}s ago. If it describes the current task, read it to recover decisions, rejected approaches and next steps that the summary may have dropped. If it is out of date or about a different task, suggest that the user run /handoff."
    fi
    ;;
esac

exit 0
