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
#   _borg_plan_declared_slug <plan_file>                   -- Step 0.75
#   _borg_child_directives <directives_dir> <slug>         -- Step 0.75

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

# ── Step 0.75: un-resolved child directives ──────────────────────────────────────────────────────
#
# WHY THIS IS CODE AND NOT FOUR LINES OF PROMPT. Step 0.75 is the gate that blocks shipping a plan
# while a directive parented to it is still open, and it lived only in skills/borg-assimilate as an
# instruction to COMPUTE the parent-plan slug from the plan's own Objective prose. No computation can
# produce it: the archived filename is a hand-written condensation. Measured 2026-09-15 on this
# repository, the computed form ran 268 characters and the real slug is
# `2026-08-24-one-front-door-link-derived-fact-surface`; the plan title does not yield it either,
# because the real slug drops `borg` and `as-the`. So the gate searched for a string nothing carried,
# found nothing, and was specified to "proceed to Step 1 without comment" -- while NINE directives
# named the plan. A gate that passes by measuring the wrong thing is worse than no gate: it certifies.
#
# The fix is a DECLARED slug: PROJECT_PLAN.md's `- Plan-slug:` annotation (AC5.9 of
# docs/plans/directives/2026-09-12-ac5-lifecycle-skills-author-manifests.md, Ruling 1), written by
# exactly one writer -- `/borg-plan` at `02-output` -- and read by everyone else.

# The plan's DECLARED slug, read from its `- Plan-slug:` annotation. Never derived.
# Args: <plan_file>
# Prints the slug on stdout and returns 0; prints nothing and returns 1 when the annotation is
# absent, empty, or unreadable.
#
# READ, NEVER COMPUTED, and the failure is LOUD. An archived filename is a condensation of an
# objective and there is no function from prose to condensation, so the only correct source is the
# plan declaring its own slug. When it has not, this returns non-zero rather than guessing, because
# the guess is what produced a silently passing gate. Callers must treat rc 1 as "cannot check", not
# as "nothing to find", and must name `- Plan-slug:` in the refusal so the reader knows what to add.
#
# `borg_core.manifest.cli resolve` is specified to read the SAME annotation (AC5.9) and does not
# exist yet. When it lands, the two readers must accept the same forms -- the backtick-wrapped value
# below is the form `/borg-plan` writes, and bare is accepted too. Two readers of one annotation is
# the divergence AC7 exists to end; if they drift, converge them rather than widening either.
_borg_plan_declared_slug() {
    local plan="$1" line
    [ -f "$plan" ] || return 1
    # `|| return 1` is a `set -e` SHIELD, not duplication of the `-n` check below: under `set -e`
    # a command substitution that exits non-zero aborts the whole shell at the assignment, so
    # without it a plan with no annotation kills the caller instead of returning 1.
    # Measured: `bash -c 'set -e; l=$(grep -m1 zzz /dev/null); echo reached'` never reaches.
    line=$(grep -m1 '^- Plan-slug:' "$plan" 2>/dev/null) || return 1
    line="${line#- Plan-slug:}"
    # Trim, then unwrap the backticks `/borg-plan` writes, then trim what they hid.
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    line="${line#\`}"
    line="${line%\`}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [ -n "$line" ] || return 1
    printf '%s\n' "$line"
}

# Directives still parented to <slug>, one path per line.
# Args: <directives_dir> <slug>
# Returns 0 with zero or more lines; returns 2 (and prints nothing) when <slug> is empty.
#
# AN EMPTY SLUG IS rc 2, NOT ZERO MATCHES. Those two outcomes are indistinguishable on stdout and
# mean opposite things -- "this plan has no open children" versus "I could not tell". Conflating them
# is the whole defect above, so the arity check comes first and is not a courtesy.
#
# Only `docs/plans/directives/` is scanned; assimilated/ and severed/ are resolved by definition.
# The match is anchored on the slug alone, never a path, mirroring the convention in
# docs/plans/directives/README.md.
_borg_child_directives() {
    local dir="$1" slug="$2" f
    [ -n "$slug" ] || return 2
    # Load-bearing under ZSH, where the bats suite cannot show it: zsh NOMATCH makes an unmatched
    # `"$dir"/*.md` a FATAL error, so deleting this line turns a missing directory into
    # `no matches found` (and, under `set -e`, an abort) -- while every bash case stays green,
    # because bash leaves the literal and the `-f` test below rejects it. Step 0.75 sources this
    # file from an interactive shell, so the zsh path is real. Pinned by the `zsh` bats case.
    [ -d "$dir" ] || return 0
    # `find`, NOT a bare glob, and NOT one grep per file. Two reasons, both measured.
    #
    # (1) zsh NOMATCH. A `for f in "$dir"/*.md` loop dies with `no matches found` on a directory
    # that EXISTS but holds no `.md` -- the `-d` guard above only covers a MISSING directory, so the
    # empty-but-present case is fatal under `set -e`. CLAUDE.md names this idiom: quoted `find`,
    # never bare globs.
    #
    # (2) One grep, not one per file. A per-file loop forks a grep per directive -- 33 processes on
    # this repository today, growing with the backlog, on every /borg-assimilate run.
    #
    # `|| true` because grep exits 1 when nothing matches and `find -exec +` propagates it, while
    # "no children" is a legitimate rc-0 answer rather than an error.
    find "$dir" -maxdepth 1 -type f -name '*.md' \
        -exec grep -l "^\*Parent plan: ${slug}\*" {} + 2>/dev/null || true
    return 0
}
