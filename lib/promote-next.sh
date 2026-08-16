#!/usr/bin/env sh
# shellcheck shell=bash  # lint as bash: both bash (tests) and zsh (borg.zsh) source this file
# lib/promote-next.sh — chained auto-promotion candidate-scan and next-slug logic backing
# skills/borg-assimilate Step 4c ("Chained Auto-Promotion").
#
# Reuses Step 0.75's own scan idiom (grep directives/*.md for a `*Parent plan:*` line) run
# after archival instead of before it. Provides:
#   _borg_promote_next_candidates <directives_dir>
#   _borg_promote_next_pointer <shipped_plan_file>
#   _borg_promote_next_decide <directives_dir> [shipped_plan_file]

# List top-level directive candidate slugs in a directory: every `<dir>/*.md` file with no
# line matching `^\*Parent plan:`. Prints one slug (basename, no `.md`) per line. Silent
# no-op (prints nothing) when the directory doesn't exist or has no candidates.
_borg_promote_next_candidates() {
    local dir="$1" f slug
    [ -d "$dir" ] || return 0
    for f in "$dir"/*.md; do
        [ -f "$f" ] || continue
        grep -q '^\*Parent plan:' "$f" && continue
        slug="${f##*/}"
        slug="${slug%.md}"
        printf '%s\n' "$slug"
    done
}

# Extract the `*Next: <slug>*` pointer from a shipped-plan file, if present.
# Args: <shipped_plan_file>
# Prints the pointed-to slug, or nothing if the file/line is absent.
_borg_promote_next_pointer() {
    local file="$1"
    [ -f "$file" ] || return 0
    grep -m1 '^\*Next: ' "$file" | sed -E 's/^\*Next: ([A-Za-z0-9._-]+)\*.*/\1/'
}

# Decide the Step 4c outcome.
# Args: <directives_dir> [shipped_plan_file]
# Prints exactly one line to stdout:
#   AUTO <slug>   — a resolved *Next:* pointer, or exactly one top-level candidate
#   ASK <n>       — two or more candidates and no resolved *Next:* signal (n = candidate count)
#   NOOP          — zero candidates and no resolved *Next:* signal
#
# A `*Next:*` pointer to a nonexistent slug is ignored (falls through to the count branch)
# rather than treated as a resolved signal — it does not crash.
_borg_promote_next_decide() {
    local dir="$1" shipped="${2:-}"
    local candidates pointer count

    candidates=$(_borg_promote_next_candidates "$dir")

    pointer=""
    if [ -n "$shipped" ]; then
        pointer=$(_borg_promote_next_pointer "$shipped")
    fi

    if [ -n "$pointer" ] && [ -f "$dir/$pointer.md" ]; then
        printf 'AUTO %s\n' "$pointer"
        return 0
    fi

    count=0
    if [ -n "$candidates" ]; then
        count=$(printf '%s\n' "$candidates" | grep -c .)
    fi

    if [ "$count" -eq 0 ]; then
        printf 'NOOP\n'
    elif [ "$count" -eq 1 ]; then
        printf 'AUTO %s\n' "$candidates"
    else
        printf 'ASK %s\n' "$count"
    fi
}
