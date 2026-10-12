#!/usr/bin/env bash
# Regenerates .cursor/commands/*.md from commands/*.md, which is the canonical
# copy. Run after editing any file in commands/. Cursor commands have no
# frontmatter and no $ARGUMENTS placeholder, so both are rewritten.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$root/.cursor/commands"

for src in "$root"/commands/*.md; do
  dest="$root/.cursor/commands/$(basename "$src")"
  awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {fm=0; skip=1; next} fm {next} skip && /^$/ {skip=0; next} {skip=0; print}' "$src" \
    | sed \
      -e 's/^The user invoked this command with: `\$ARGUMENTS`$/Infer the optional session name from the text the user typed after the command./' \
      -e 's/If `\$ARGUMENTS` is non-empty, treat it as/If a session name is present, treat it as/' \
      -e 's/If `\$ARGUMENTS` is empty/If no session name is present/' \
      -e 's/Tool: claude-code/Tool: cursor/' \
    > "$dest"
  echo "synced ${dest#"$root"/}"
done
