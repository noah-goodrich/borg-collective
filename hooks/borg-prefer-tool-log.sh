#!/usr/bin/env bash
# PostToolUse (Bash) -> record when a LIVE prefer-tool preference was bypassed.
#
# WHAT THIS MEASURES, AND WHAT IT CANNOT. A `prefer-tool` extension is prose: it asks the model to
# delegate to a preferred tool. Prose is ignorable, and per CLAUDE.md's cairn entry this repository
# has already measured what uninstrumented voluntary compliance is worth -- four shipped, tested,
# exposed surfaces produced ONE real row in five months. So the preference ships with a number
# attached from day one.
#
# This hook witnesses BYPASSES only: a shell command ran that matches a live preference's
# `- Instead-of:` pattern. It cannot witness compliance, because invoking the preferred SKILL is not
# a Bash call and leaves no trace on this surface. A rising bypass count means the preference is not
# working; an empty log means either it is working or nobody performed the action. Reporting this as
# a "compliance rate" would be the same overclaim as a gate that passes by measuring nothing, so the
# log line is named `bypass` and nothing here computes a ratio.
#
# Advisory only. Always exits 0, never blocks, and does not rewrite the command -- silently
# redirecting what runs would break the standing posture that skills propose and the developer
# validates, and its failure mode would be invisible.

set -uo pipefail

BORG_DIR="${BORG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/borg}"
LOG="$BORG_DIR/prefer-tool.jsonl"

# FAST PATH, before any subprocess. This hook is PostToolUse/Bash, so it runs after EVERY bash
# command the agent issues. Measured on this machine: `python3 -m borg_core.extensions.cli check`
# costs ~60ms per call, and the hook also forked two `jq`s and a `git`. With no prefer-tool
# extension configured anywhere -- the default on every machine -- all of that was pure waste on
# every single Bash call. Two `[ -d ]` tests cost ~0.17ms per 100 and skip the whole chain.
#
# Checked against $PWD rather than the payload's cwd because reading the payload means `cat` +
# `jq`, which is part of what this gate exists to avoid. A repository-layer extension in some OTHER
# directory is missed by this test; that is the accepted cost of the gate, and the machine layer
# (where prefer-tool extensions belong, per the precedence rule) is always checked.
if [ ! -d "${BORG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/borg}/extensions" ] \
   && [ ! -d "$PWD/.borg/skill-extensions" ] && [ ! -d "$PWD/.borg/agent-extensions" ]; then
    exit 0
fi

payload=$(cat 2>/dev/null) || exit 0
[ -n "$payload" ] || exit 0

command -v jq >/dev/null 2>&1 || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

# LOCATING borg_core, and why this hook is not "self-contained" like its siblings.
# Every other hook here parses stdin JSON with stdlib python or inlined shell. This one delegates to
# `borg_core.extensions.cli`, because reimplementing layer precedence, `- Requires:` parsing and
# liveness in bash would create a SECOND reader of the same annotation -- the exact divergence AC7
# exists to end, and the thing docs/extensions.md warns about for `resolve`. One implementation,
# located at runtime:
#   1. script-relative (the repo checkout and any symlinked install)
#   2. $BORG_ROOT (exported by install.sh as the source-tree path)
# If neither yields the package, this hook is a NO-OP. That is deliberate and it is a real
# limitation, not a papered-over one: in a plugin-only distribution where borg_core is absent, the
# prefer-tool bypass log does not run, so an empty log there means "not instrumented" rather than
# "no bypasses". Stated here so nobody reads that silence as a measurement.
_hook_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P) || exit 0
_core_root=""
if [ -d "$_hook_dir/../borg_core" ]; then
    _core_root=$(CDPATH='' cd -- "$_hook_dir/.." && pwd -P) || exit 0
elif [ -n "${BORG_ROOT:-}" ] && [ -d "$BORG_ROOT/borg_core" ]; then
    _core_root="$BORG_ROOT"
fi
[ -n "$_core_root" ] || exit 0
cmd=$(printf '%s' "$payload" | jq -r 'if has("tool_input") then (.tool_input.command // "") else "" end' 2>/dev/null) || exit 0
[ -n "$cmd" ] || exit 0

cwd=$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null)
[ -n "$cwd" ] || cwd="$PWD"

# No `git rev-parse` here: borg_core.extensions.shell.repo_root() walks for `.git` with no
# subprocess at all, and survey() calls it on whatever --repository receives. Forking git to
# compute a value the callee recomputes for free was one wasted process per Bash call.

# `check` exits 0 and prints the matched preference only when a LIVE one covers this command.
matched=$(PYTHONPATH="$_core_root${PYTHONPATH:+:$PYTHONPATH}" python3 -m borg_core.extensions.cli \
    --repository "$cwd" check "$cmd" 2>/dev/null) || exit 0
[ -n "$matched" ] || exit 0

# Brace-group so the stderr redirect is established BEFORE the append target is opened: bash opens
# redirections left-to-right, so `>> "$LOG" 2>/dev/null` on one simple command still prints a
# missing-directory error to the real stderr -- which a consumer merging stderr into stdout splices
# ahead of any JSON. This bug kept CI red for weeks; see CLAUDE.md.
{
    mkdir -p "$BORG_DIR" 2>/dev/null
    printf '%s\n' "$(printf '%s' "$matched" | jq -c --arg cmd "$cmd" --arg cwd "$cwd" \
        '{event:"bypass", prefer:.prefer, instead_of:.instead_of, layer:.layer, command:$cmd, cwd:$cwd}' 2>/dev/null)" >> "$LOG"
} 2>/dev/null

exit 0
