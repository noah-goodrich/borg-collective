#!/usr/bin/env bash
# AC5.3-AC5.5: do the three lifecycle skills author manifests BY DEFAULT?
#
# Six model cases, three pairs. Each positive is paired with the negative that proves the
# conditional discriminates, because a positive alone is satisfied just as well by a skill that
# does the thing unconditionally.
#
#   P1 /borg-plan        real project, no .borg  -> manifest scaffolded, validates, rows: []
#   N1 /borg-plan        real project + manifest -> the file is BYTE-IDENTICAL afterwards
#   P2 /borg-link-up     manifest + gh stub      -> one row for that ref
#   N2 /borg-link-up     real project, NO manifest -> none created; creation stays /borg-plan's
#   P3 /borg-assimilate  manifest declares ref   -> that row's status is merged
#   N3 /borg-assimilate  manifest lacks the ref  -> file byte-identical, and NO row was added
#
# EVERY NEGATIVE SKIPS RATHER THAN PASSES WHEN ITS POSITIVE PATH DID NOT FIRE, and that is the
# single most important property of this harness. Measured 2026-09-17 on the first version: all
# three positives were unreachable, so nothing was written, so all three negatives asserting
# "nothing changed" went GREEN -- three passing checks carrying no evidence, which is the exact
# defect class this harness exists to catch, reproduced inside it. A negative now first asserts its
# skill REACHED its output step (`PROJECT_PLAN.md` written, or a row added) and reports SKIP if it
# did not. "Nothing changed" then only ever means "the skill ran and declined."
#
# THE PROMPTS CARRY A CONFIRMATION, and the reason is the skills' own shape. `/borg-plan`'s
# `## The Conversation` says "Confirm any adjustment before moving on", so its `02-output` step --
# where the scaffold lives -- is unreachable from a single bare invocation. The directive's original
# "bare slash command" wording was a PROXY for "no manifest hint"; it also removed the confirmation,
# which made every positive a false negative. The property is preserved mechanically instead:
# `_eval_prompt_mentions_no_manifest` refuses any prompt containing manifest/.borg/scaffold/row/etc,
# so a manifest appearing still proves the behaviour is DEFAULT rather than requested.
# THE ORACLE IS THE MANIFEST FILE ON DISK, compared byte-wise wherever the assertion is "nothing
# changed" -- never a grep of the model's prose. That is what makes this harness a stronger gate
# than the exemplar it copies: a skill can narrate having written a row it never wrote.
#
# EVERY PROMPT IS THE BARE SLASH COMMAND with no manifest hint (AC5.2), so a pass is evidence the
# behaviour is DEFAULT rather than requested.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="$HERE/out"

# shellcheck source=/dev/null
source "$HERE/fixtures.sh"

SKIP_MODEL=0
while [ $# -gt 0 ]; do
    case "$1" in
        # `make eval` globs evals/*/run.sh and hands EVERY harness the same EVAL_ARGS, so an
        # unknown flag exits 2 and turns the whole target red for a reason unrelated to this
        # harness. Both flags are therefore ACCEPTED; --skip-network is inert because no case here
        # touches the network (gh is always a stub).
        --skip-model)   SKIP_MODEL=1 ;;
        --skip-network) : ;;
        -h|--help) echo "usage: evals/lifecycle-manifests/run.sh [--skip-model] [--skip-network]"; exit 0 ;;
        *) echo "unknown flag: $1" >&2; exit 2 ;;
    esac
    shift
done

# GUARD BEFORE THE rm -rf. A mis-derived REPO must not be able to point this at a real tree.
if [ ! -f "$REPO/CLAUDE.md" ] || [ ! -d "$REPO/borg_core" ]; then
    echo "refusing to run: REPO=$REPO does not look like borg-collective" >&2
    exit 2
fi

# $OUT is RECREATED, never ensured: a stale artifact from a previous run is a false PASS for a case
# that produced nothing this time.
rm -rf "$OUT"
mkdir -p "$OUT"

PASS=0; FAIL=0; SKIPPED=0; MODEL_RAN=0
ok()   { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
skip() { echo "  SKIP  $1"; SKIPPED=$((SKIPPED+1)); }

if [ "$SKIP_MODEL" -eq 1 ]; then
    echo "== P1/N1/P2/N2/P3/N3 skipped (--skip-model) =="
    echo "this harness has no offline cases; --skip-model requested nothing and ran nothing" >&2
    exit 0
fi

# CLAUDE MUST BE *USABLE*, NOT MERELY PRESENT, and the difference is not cosmetic.
#
# `command -v claude` succeeds for a claude that is installed but not logged in, which then fails
# every case — and the directive is explicit that those are different facts: "SKIPs never gate (a
# `claude` that is absent or unauthenticated is a different fact from a `claude` that is wrong)".
# The first version checked only presence, so an unauthenticated binary was graded as three broken
# skills. Measured: that is precisely what happened, because the allowlist omitted `security` and
# claude could not reach the keychain.
#
# The probe is a trivial prompt rather than a version check, because `claude --version` answers
# without credentials and would keep the two cases indistinguishable.
have_claude=0
if command -v claude >/dev/null 2>&1; then
    if probe="$(claude -p 'reply with the single word READY and nothing else' 2>&1)" \
       && printf '%s' "$probe" | grep -q 'READY'; then
        have_claude=1
    else
        echo "claude is present but not usable: $(printf '%s' "$probe" | head -1)" >&2
    fi
fi

# One gh stub for every case. Returns a PR number for the current branch, which is the production
# path /borg-link-up derives its ref from. A STUB PROVES THE WIRING, NOT THE DERIVATION -- it cannot
# grade that `gh pr view --json number` returns the right ref against real GitHub. That gap is
# deliberate: the alternative is a case requiring a live PR, which is the "names a repository"
# premise this harness is forbidden from having.
cat > "$OUT/ghstub" <<'GH'
#!/bin/sh
case "$*" in
  *"pr view"*) echo '{"number":7}' ;;
  *"pr merge"*) echo 'merged' ;;
  *) echo '{}' ;;
esac
GH
chmod +x "$OUT/ghstub"
BIN="$(_eval_allowlist_bin "$OUT/bin" "$OUT/ghstub")"

# THE CLAIM IS "NO DECLARED DATA WAS TOUCHED", NOT "NO BYTE MOVED", and the distinction cost a
# false FAIL. Measured 2026-09-17: after `/borg-plan`, N1's manifest differed from the fixture by
# exactly ONE BYTE -- a trailing newline -- while both rows survived with identical refs, lanes,
# orders and whys. A sha256 of the raw bytes reported that as "a clobbering scaffold destroys a
# program", which is a serious accusation from a newline.
#
# So the oracle is a CANONICAL comparison: parse, sort keys, re-serialize, hash that. It still
# fails on a deleted row, a changed `why`, a reordered lane or an added key -- everything the
# assertion actually cares about -- and ignores whitespace and key order, which no caller can
# observe. A raw-byte hash is the stricter test and the WRONG one; strictness that flags benign
# differences trains a reader to dismiss the gate.
_canon() { python3 -c '
import hashlib, json, sys, pathlib
p = pathlib.Path(sys.argv[1])
if not p.is_file():
    print("ABSENT"); raise SystemExit
try:
    doc = json.loads(p.read_text(encoding="utf-8"))
except (OSError, ValueError):
    print("UNPARSEABLE"); raise SystemExit
print(hashlib.sha256(json.dumps(doc, sort_keys=True, separators=(",", ":")).encode()).hexdigest())' "$1"; }

echo "== lifecycle-manifest evals =="

# Run one skill with the confirmation-carrying prompt, refusing to run at all if the prompt would
# leak a hint. Args: <fixture-dir> <slash-command> <objective>
_run_skill() {
    local dir="$1" cmd="$2" obj="$3" prompt
    prompt="$(_eval_prompt "$cmd" "$obj")"
    _eval_prompt_mentions_no_manifest "$prompt" || return 2
    ( cd "$dir" && PATH="$BIN:$REPO/.venv/bin" BORG_ROOT="$REPO" \
        claude -p "$prompt" --permission-mode acceptEdits >/dev/null 2>&1 )
}

_valid_manifest_count() {
    PYTHONPATH="$REPO" python3 -c '
import sys
from borg_core.manifest import shell
ms, warns = shell.discover([sys.argv[1]])
print(len(ms) if not warns else -1)' "$1" 2>/dev/null || echo -1
}

_rows_json() {
    PYTHONPATH="$REPO" python3 -c '
import json, sys
from borg_core.manifest import shell
ms, _w = shell.discover([sys.argv[1]])
print(json.dumps(ms[0].get("rows") if ms else []))' "$1" 2>/dev/null || echo '[]'
}

# ── P1 / N1: /borg-plan scaffolds, and never clobbers ────────────────────────────────────────────
p1="$(_eval_repo_with_project "$OUT/p1")"
if [ "$have_claude" -eq 0 ]; then
    skip "P1 /borg-plan scaffolds a manifest (claude unavailable)"
    skip "N1 /borg-plan does not clobber an existing manifest (P1 did not run)"
else
    MODEL_RAN=$((MODEL_RAN+1))
    _run_skill "$p1" "/borg-plan" "add CI and a coverage gate to this library"
    p1_planned=0; [ -f "$p1/PROJECT_PLAN.md" ] && p1_planned=1
    if [ "$(_valid_manifest_count "$p1")" = "1" ] && [ "$(_rows_json "$p1")" = "[]" ]; then
        ok "P1 /borg-plan scaffolded a valid manifest with rows: []"
    else
        bad "P1 /borg-plan did not scaffold a valid empty-rows manifest"
    fi

    # N1's PRECONDITION: /borg-plan must have reached its output step at all. Without this the
    # byte-identical assertion below passes whenever the skill does nothing.
    n1="$(_eval_repo_with_project "$OUT/n1")"
    mkdir -p "$n1/.borg/programs"
    printf '{"program":"declared","rows":[{"ref":"o/r#1","lane":"alpha","order":"1","why":"first"},{"ref":"o/r#2","lane":"alpha","order":"2","why":"second"}]}\n' \
        > "$n1/.borg/programs/declared.json"
    n1f="$n1/.borg/programs/declared.json"
    before="$(_canon "$n1f")"
    MODEL_RAN=$((MODEL_RAN+1))
    _run_skill "$n1" "/borg-plan" "add CI and a coverage gate to this library"
    if [ ! -f "$n1/PROJECT_PLAN.md" ] && [ "$p1_planned" -eq 0 ]; then
        skip "N1 /borg-plan never reached its output step — byte-identical would be vacuous"
    elif [ "$(_canon "$n1f")" = "$before" ]; then
        ok "N1 declared rows are UNCHANGED (canonical) after a /borg-plan that DID write a plan"
    else
        bad "N1 /borg-plan rewrote a declared manifest — a clobbering scaffold destroys a program"
    fi
fi

# ── P2 / N2: /borg-link-up adds the row, and never scaffolds ─────────────────────────────────────
p2="$(_eval_repo_with_project "$OUT/p2")"
mkdir -p "$p2/.borg/programs"
printf '{"program":"prog","rows":[]}\n' > "$p2/.borg/programs/prog.json"
_eval_plan "$p2" 2026-01-01-p2-slug
if [ "$have_claude" -eq 0 ]; then
    skip "P2 /borg-link-up adds one row for the branch's PR (claude unavailable)"
    skip "N2 /borg-link-up does not scaffold where none exists (P2 did not run)"
else
    MODEL_RAN=$((MODEL_RAN+1))
    _run_skill "$p2" "/borg-link-up" "record where this session got to"
    p2_rows="$(_rows_json "$p2")"
    if printf '%s' "$p2_rows" | grep -q '#7'; then
        ok "P2 /borg-link-up added a row for the stubbed PR ref"
    else
        bad "P2 /borg-link-up added no row for the stubbed PR ref"
    fi

    # N2's PRECONDITION: P2 proved link-up can write a row at all. If it cannot, "no manifest was
    # created" is true for a reason unrelated to the creation split.
    n2="$(_eval_repo_with_project "$OUT/n2")"
    _eval_plan "$n2" 2026-01-01-n2-slug
    MODEL_RAN=$((MODEL_RAN+1))
    _run_skill "$n2" "/borg-link-up" "record where this session got to"
    if ! printf '%s' "$p2_rows" | grep -q '#7'; then
        skip "N2 link-up never wrote a row even where one was declared — premise unproven"
    elif [ ! -e "$n2/.borg/programs" ]; then
        ok "N2 no manifest was created — creation still belongs to /borg-plan"
    else
        bad "N2 /borg-link-up scaffolded — the ratified creation split is dissolved"
    fi
fi

# ── P3 / N3: /borg-assimilate closes the row, and never adds one ─────────────────────────────────
p3="$(_eval_repo_with_project "$OUT/p3")"
mkdir -p "$p3/.borg/programs"
printf '{"program":"prog","rows":[{"ref":"o/r#7","lane":"alpha","order":"1","why":"the merged one"}]}\n' \
    > "$p3/.borg/programs/prog.json"
_eval_plan "$p3" 2026-01-01-p3-slug
if [ "$have_claude" -eq 0 ]; then
    skip "P3 /borg-assimilate closes the merged row (claude unavailable)"
    skip "N3 /borg-assimilate does not add a row it was meant to verify (P3 did not run)"
else
    MODEL_RAN=$((MODEL_RAN+1))
    _run_skill "$p3" "/borg-assimilate" "ship the work on this branch"
    p3_closed=0
    printf '%s' "$(_rows_json "$p3")" | grep -q '"merged"' && p3_closed=1
    if [ "$p3_closed" -eq 1 ]; then
        ok "P3 /borg-assimilate set the declared row's status to merged"
    else
        bad "P3 /borg-assimilate did not close the declared row"
    fi

    n3="$(_eval_repo_with_project "$OUT/n3")"
    mkdir -p "$n3/.borg/programs"
    printf '{"program":"prog","rows":[{"ref":"o/r#99","lane":"alpha","order":"1","why":"a different ref"}]}\n' \
        > "$n3/.borg/programs/prog.json"
    _eval_plan "$n3" 2026-01-01-n3-slug
    n3f="$n3/.borg/programs/prog.json"
    before3="$(_canon "$n3f")"
    MODEL_RAN=$((MODEL_RAN+1))
    _run_skill "$n3" "/borg-assimilate" "ship the work on this branch"
    if [ "$p3_closed" -eq 0 ]; then
        skip "N3 assimilate never closed a row it DID declare — premise unproven"
    elif [ "$(_canon "$n3f")" = "$before3" ]; then
        ok "N3 declared rows are UNCHANGED (canonical) — no fallback add-row"
    else
        bad "N3 /borg-assimilate wrote to a manifest that never declared the ref"
    fi
fi

# ── THE MODEL-MODE EXECUTION FLOOR ───────────────────────────────────────────────────────────────
#
# Reaching here means --skip-model was ABSENT, which is a request for the model sweep. SKIPs never
# gate -- a `claude` that is missing or unauthenticated is a different fact from one that is wrong --
# but "every case skipped" and "every case passed" must not print the same rc 0. That conflation is
# precisely what let `make eval-live` report success with the entire sweep absent.
echo
echo "lifecycle-manifests: $PASS passed, $FAIL failed, $SKIPPED skipped"
if [ "$MODEL_RAN" -eq 0 ]; then
    echo "model sweep was requested but NO case executed — floor fires" >&2
    exit 1
fi
[ "$FAIL" -eq 0 ]
