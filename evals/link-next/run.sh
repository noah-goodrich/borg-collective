#!/usr/bin/env bash
# Offline harness for the two skills that paint a page: borg-link and borg-next. Directive:
# docs/plans/directives/2026-10-03-evals-for-everything.md, Phase 1b (B3, B4).
#
# THE MODEL HALF LIVES IN cases/ AND RUNS ONLY THROUGH live.sh (`claude plugin eval`, a developer command with a
# cost ceiling, never CI). THIS FILE NEVER REACHES A MODEL. What it proves, with no model call:
#
#   SANDBOX  every case builds its plugin sandbox (sandbox.sh), and the sandbox copy of the skill differs from
#            the shipped SKILL.md in exactly the one swapped span. A skill edit that removes the span fails here.
#   GRADERS  every `type: regex` grader of a case is applied (perl) to recorded replies: transcripts/<case>.good.md
#            must pass ALL of them, and each transcripts/<case>.bad-*.md must fail AT LEAST ONE. The known-bad
#            replies reproduce the 2026-10-20 shape (a reply saying nothing waits above a page that lists items;
#            a reply saying "declined") with invented names. A grader that passes everything, or one whose pattern
#            was blanked, turns a known-bad red here.
#   FLOORS   a case with no regex grader, no known-good or no known-bad transcript is a failure, not a skip.
#
# Flags (shared by every harness `make eval` globs; an unknown flag exits 2):
#   --skip-model, --skip-network   ACCEPTED AND INERT -- nothing here reads the model or the wire.
#
# Environment (for the bats cases that mutate a COPY of this directory):
#   BORG_EVAL_REPO   the checkout whose skills/ the sandbox copies   (default: two levels above this file)

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${BORG_EVAL_REPO:-$(cd "$HERE/../.." && pwd)}"
DIR="$HERE"

while [ $# -gt 0 ]; do
    case "$1" in
        --skip-model|--skip-network) ;;
        -h|--help) echo "usage: evals/link-next/run.sh [--skip-model] [--skip-network]"; exit 0 ;;
        *) echo "unknown flag: $1" >&2; exit 2 ;;
    esac
    shift
done

if [ ! -f "$REPO/borg.zsh" ]; then
    echo "ERROR: REPO does not look like the borg-collective checkout: $REPO" >&2
    exit 2
fi
command -v perl >/dev/null 2>&1 || { echo "ERROR: perl is required to apply the regex graders" >&2; exit 2; }

OUT="$HERE/out"
rm -rf "$OUT"
mkdir -p "$OUT"

PASS=0; FAIL=0
ok()  { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }

# The grader body is the text after the frontmatter's closing `---`, trimmed: one regex, matched as a search over
# the final message (the runner's `regex` grader does the same, "pattern not found in last_message").
grader_field() { awk -v k="$2" 'NR==1&&$0!="---"{exit} /^---$/{n++; next} n==1&&index($0,k":")==1{sub(/^[^:]*:[ \t]*/,""); print; exit}' "$1"; }
grader_body() { awk '/^---$/{n++; next} n>=2 && NF{print; exit}' "$1"; }

# grade <grader-file> <reply-file>: 0 = the reply satisfies the grader.
grade() {
    local pat
    pat="$(grader_body "$1")"
    [ -n "$pat" ] || return 2
    PAT="$pat" perl -0777 -ne 'exit(/$ENV{PAT}/ ? 0 : 1)' "$2"
}

for casedir in "$DIR"/cases/*/; do
    c="${casedir%/}"; c="${c##*/}"

    # SANDBOX
    sb="$OUT/$c"
    if BORG_EVAL_REPO="$REPO" bash "$HERE/sandbox.sh" "$c" "$sb" > "$OUT/$c.sandbox.log" 2>&1; then
        skill="$(sed -n 's/^skill=//p' "$casedir/sandbox.conf")"
        changed="$(diff "$REPO/skills/$skill/SKILL.md" "$sb/skills/$skill/SKILL.md" | grep -c '^<')"
        if [ "$changed" -eq 1 ] && diff -r -x SKILL.md "$REPO/skills/$skill" "$sb/skills/$skill" >/dev/null; then
            ok "$c: the sandbox copy of $skill differs from the shipped skill in exactly one line"
        else
            bad "$c: the sandbox copy of $skill changed $changed lines or touched other files"
        fi
    else
        bad "$c: sandbox build failed -- $(head -1 "$OUT/$c.sandbox.log")"
    fi

    # GRADERS
    graders=()
    for g in "$casedir"graders/*.md; do
        [ "$(grader_field "$g" type)" = regex ] && graders+=("$g")
    done
    good="$DIR/transcripts/$c.good.md"
    bads=("$DIR"/transcripts/"$c".bad-*.md)
    if [ "${#graders[@]}" -eq 0 ]; then
        bad "$c: no regex grader, so nothing can be graded offline"
        continue
    fi
    if [ ! -f "$good" ] || [ ! -f "${bads[0]}" ]; then
        bad "$c: needs a known-good and at least one known-bad transcript"
        continue
    fi

    failed_good=0; n_good=0
    for good in "$DIR/transcripts/$c.good.md" "$DIR"/transcripts/"$c".good-*.md; do
        [ -f "$good" ] || continue
        n_good=$((n_good+1))
        for g in "${graders[@]}"; do
            grade "$g" "$good"; rc=$?
            if [ "$rc" -ne 0 ]; then
                failed_good=$((failed_good+1))
                bad "$c: ${good##*/} fails grader ${g##*/} (rc $rc)"
            fi
        done
    done
    [ "$failed_good" -ne 0 ] || ok "$c: $n_good known-good replies pass all ${#graders[@]} regex graders"
    for b in "${bads[@]}"; do
        failed=0
        for g in "${graders[@]}"; do
            grade "$g" "$b"; rc=$?
            [ "$rc" -eq 1 ] && failed=$((failed+1))
            [ "$rc" -eq 2 ] && bad "$c: grader ${g##*/} has an empty pattern"
        done
        if [ "$failed" -ge 1 ]; then
            ok "$c: ${b##*/} is graded FAIL ($failed grader(s) reject it)"
        else
            bad "$c: ${b##*/} PASSED every grader; the graders no longer discriminate"
        fi
    done
done

echo
echo "RESULT: $PASS pass, $FAIL fail"
if [ $((PASS + FAIL)) -eq 0 ]; then
    echo "no case was graded: nothing was verified" >&2
    exit 1
fi
[ "$FAIL" -eq 0 ]
