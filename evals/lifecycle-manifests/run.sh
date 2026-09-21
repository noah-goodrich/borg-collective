#!/usr/bin/env bash
# AC5.3-AC5.5: do the three lifecycle skills author manifests BY DEFAULT?
#
# One deterministic case, then six model cases in three pairs. Each positive is paired with the
# negative that proves the conditional discriminates, because a positive alone is satisfied just as
# well by a skill that does the thing unconditionally.
#
#   VERBS               offline, pytest  -> the four `manifest.cli` verbs the skills shell to hold
#   P1 /borg-plan        real project, no .borg  -> manifest scaffolded, validates, rows: []
#   N1 /borg-plan        real project + manifest -> the file is BYTE-IDENTICAL afterwards
#   P2 /borg-link-up     manifest + gh stub      -> one row for that ref
#   N2 /borg-link-up     real project, NO manifest -> none created; creation stays /borg-plan's
#   P3 /borg-assimilate  manifest declares ref   -> that row's status is merged
#   N3 /borg-assimilate  manifest lacks the ref  -> file byte-identical, and NO row was added
#
# VERBS IS WHAT KEEPS THE GLOBAL FLOOR SATISFIABLE ON A MACHINE WITH NO `claude`. `make eval` runs
# every harness in `evals/` with `--skip-model --skip-network`, and `tests/eval_floor.bats` holds
# every one of them to the same contract: a run in which NO case executed is a failure, and a run
# with an interpreter must execute SOMETHING. The first version of this file had only model cases,
# so `--skip-model` "requested nothing and ran nothing" at rc 0 -- a green run of nothing, which is
# the defect the floors exist to name. VERBS runs `borg_core/manifest/test_cli.py`, the suite for
# `scaffold`, `add-row`, `close` and `resolve` -- exactly the four verbs `skills/borg-plan`,
# `skills/borg-link-up` and `skills/borg-assimilate` invoke -- so the offline case is the mechanical
# half of the same question the model cases ask: the verbs work; do the skills call them?
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
# Flags, shared with every harness `make eval` globs (an unknown flag exits 2 and turns the whole
# target red, so BOTH are accepted):
#   --skip-model     skip the six model cases; VERBS still runs
#   --skip-network   ACCEPTED AND INERT -- no case here reads the wire, `gh` is always a stub
#
# THIS HARNESS HAS NO NETWORK MODE, AND SAYS SO BY OMISSION. `tests/eval_floor.bats` scopes its two
# network-mode cases to harnesses that declare a `NETWORK_RAN=` counter, the same way it scopes the
# E2a count floor to harnesses that declare `E2A_MIN=`. Declaring one here to satisfy a glob would
# mean adding a live `gh` call to a harness whose fixtures rule 2 forbids exactly that.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# `BORG_EVAL_REPO` IS THE SEAM THE SHARED ORACLE USES. `tests/eval_floor.bats` redirects every
# harness's evidence tree into a sandbox through it, so a harness deriving `$REPO` from its own
# location alone `rm -rf`s inside the real checkout under test -- which is what the first version
# of this file did with `OUT="$HERE/out"`. Fixtures are still sourced from `$HERE`: the sandbox
# carries no `evals/` on purpose, and the builders are this file's, not the checkout's.
REPO="${BORG_EVAL_REPO:-$(cd "$HERE/../.." && pwd)}"

# shellcheck source=/dev/null
source "$HERE/fixtures.sh"

# THE INTERPRETER IS AN INPUT, derived like `$REPO` -- see `_eval_python` for the ladder.
PYTHON="$(_eval_python "$REPO")"

# GUARD BEFORE THE rm -rf. A mis-derived or mis-overridden REPO must not be able to point the
# cleanup at an arbitrary directory. `borg.zsh` is the marker because it is TRACKED and sits at the
# root -- it knows nothing about where this harness lives, so moving the harness cannot break it.
if [ ! -f "$REPO/borg.zsh" ]; then
    echo "ERROR: REPO does not look like the borg-collective checkout: $REPO" >&2
    exit 2
fi

OUT="$REPO/evals/lifecycle-manifests/out"

SKIP_MODEL=0
while [ $# -gt 0 ]; do
    case "$1" in
        --skip-model)   SKIP_MODEL=1 ;;
        --skip-network) : ;;
        -h|--help) echo "usage: evals/lifecycle-manifests/run.sh [--skip-model] [--skip-network]"; exit 0 ;;
        *) echo "unknown flag: $1" >&2; exit 2 ;;
    esac
    shift
done

# $OUT is RECREATED, never ensured: a stale artifact from a previous run is a false PASS for a case
# that produced nothing this time.
rm -rf "$OUT"
mkdir -p "$OUT"

PASS=0; FAIL=0; SKIPPED=0
# THE MODEL-MODE EXECUTION COUNTER, incremented by the branch that actually RAN a case rather than
# by `ok`/`bad`, so "the sweep ran something" is recorded once per case regardless of verdict. It
# exists because the global PASS+FAIL floor cannot see the model sweep at all once VERBS is in the
# file: VERBS always executes, so it satisfies a global floor single-handed, and `make eval-live`
# with `claude` absent would print one PASS and six SKIPs at rc 0 with the ENTIRE sweep missing.
MODEL_RAN=0
ok()   { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
skip() { echo "  SKIP  $1"; SKIPPED=$((SKIPPED+1)); }

# ── VERBS: the manifest CLI the three skills shell to (pytest, offline) ─────────────────────────
echo "== VERBS: manifest.cli contract (pytest, offline) =="
VERBS_TESTS=borg_core/manifest/test_cli.py
if ! "$PYTHON" -c "import pytest" >/dev/null 2>&1; then
    # GUARDED ON THE INPUT THE CASE NEEDS -- an importable pytest, not merely an interpreter. A
    # python3 without the dev group is a missing package, not a broken contract, and printing FAIL
    # for it is the conflation the header forbids.
    skip "VERBS manifest.cli contract: pytest is not importable by $PYTHON"
else
    # SELECTED BY PATH, NOT BY `-k`. A name selection is a contract with test NAMES that can be
    # emptied by a rename with every gate green (the E2a count floor in s4-k3 exists for exactly
    # that); a whole-file selection has no names to drift, and pytest itself names the two ways it
    # can go hollow: rc 4 for a path that is not there, rc 5 for a file that collected nothing.
    (cd "$REPO" && "$PYTHON" -m pytest "$VERBS_TESTS" -q) > "$OUT/verbs-pytest.txt" 2>&1
    VERBS_RC=$?
    case "$VERBS_RC" in
        0) ok "VERBS manifest.cli contract: $VERBS_TESTS is green" ;;
        5) bad "VERBS manifest.cli contract: pytest collected NOTHING from $VERBS_TESTS (see $OUT/verbs-pytest.txt)" ;;
        *) bad "VERBS manifest.cli contract: pytest exited $VERBS_RC (see $OUT/verbs-pytest.txt)" ;;
    esac
fi

# ── the model sweep's one precondition ──────────────────────────────────────────────────────────
#
# `model_off` is the reason the six model cases will SKIP, or empty when they can run. Two reasons,
# kept distinct in the SKIP line because they are different facts: the caller asked for offline
# mode, or the caller asked for the sweep and this machine cannot supply it.
#
# CLAUDE MUST BE *USABLE*, NOT MERELY PRESENT, and the difference is not cosmetic.
#
# `command -v claude` succeeds for a claude that is installed but not logged in, which then fails
# every case -- and the directive is explicit that those are different facts: "SKIPs never gate (a
# `claude` that is absent or unauthenticated is a different fact from a `claude` that is wrong)".
# The first version checked only presence, so an unauthenticated binary was graded as three broken
# skills. Measured: that is precisely what happened, because the allowlist omitted `security` and
# claude could not reach the keychain.
#
# The probe is a trivial prompt rather than a version check, because `claude --version` answers
# without credentials and would keep the two cases indistinguishable. It runs ONLY when the sweep
# was requested: under `--skip-model` a probe would spend a model call to decide nothing.
model_off=""
if [ "$SKIP_MODEL" -eq 1 ]; then
    model_off="--skip-model"
elif ! command -v claude >/dev/null 2>&1; then
    model_off="claude unavailable"
elif ! probe="$(claude -p 'reply with the single word READY and nothing else' 2>&1)" \
     || ! printf '%s' "$probe" | grep -q 'READY'; then
    echo "claude is present but not usable: $(printf '%s' "$probe" | head -1)" >&2
    model_off="claude unavailable"
fi

if [ -z "$model_off" ]; then
    # One gh stub for every case. Returns a PR number for the current branch, which is the
    # production path /borg-link-up derives its ref from. A STUB PROVES THE WIRING, NOT THE
    # DERIVATION -- it cannot grade that `gh pr view --json number` returns the right ref against
    # real GitHub. That gap is deliberate: the alternative is a case requiring a live PR, which is
    # the "names a repository" premise this harness is forbidden from having.
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
fi

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
_canon() { "$PYTHON" -c '
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
    PYTHONPATH="$REPO" "$PYTHON" -c '
import sys
from borg_core.manifest import shell
ms, warns = shell.discover([sys.argv[1]])
print(len(ms) if not warns else -1)' "$1" 2>/dev/null || echo -1
}

_rows_json() {
    PYTHONPATH="$REPO" "$PYTHON" -c '
import json, sys
from borg_core.manifest import shell
ms, _w = shell.discover([sys.argv[1]])
print(json.dumps(ms[0].get("rows") if ms else []))' "$1" 2>/dev/null || echo '[]'
}

# ── P1 / N1: /borg-plan scaffolds, and never clobbers ────────────────────────────────────────────
if [ -n "$model_off" ]; then
    skip "P1 /borg-plan scaffolds a manifest ($model_off)"
    skip "N1 /borg-plan does not clobber an existing manifest (P1 did not run)"
else
    p1="$(_eval_repo_with_project "$OUT/p1")"
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
    mkdir -p "$n1/$_EVAL_MANIFEST_DIR"
    printf '{"program":"declared","rows":[{"ref":"o/r#1","lane":"alpha","order":"1","why":"first"},{"ref":"o/r#2","lane":"alpha","order":"2","why":"second"}]}\n' \
        > "$n1/$_EVAL_MANIFEST_DIR/declared.json"
    n1f="$n1/$_EVAL_MANIFEST_DIR/declared.json"
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
if [ -n "$model_off" ]; then
    skip "P2 /borg-link-up adds one row for the branch's PR ($model_off)"
    skip "N2 /borg-link-up does not scaffold where none exists (P2 did not run)"
else
    p2="$(_eval_repo_with_project "$OUT/p2")"
    mkdir -p "$p2/$_EVAL_MANIFEST_DIR"
    printf '{"program":"prog","rows":[]}\n' > "$p2/$_EVAL_MANIFEST_DIR/prog.json"
    _eval_plan "$p2" 2026-01-01-p2-slug
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
    # BOTH SPELLINGS, because the writer under test may know either. `.borg/programs` is being
    # renamed to `.borg/chains` as expand -> migrate -> contract (#222); during the expand phase a
    # scaffold could land under whichever name the writer resolves first, and checking one of them
    # would let a scaffold under the other read as "nothing was created".
    elif [ ! -e "$n2/.borg/programs" ] && [ ! -e "$n2/.borg/chains" ]; then
        ok "N2 no manifest was created — creation still belongs to /borg-plan"
    else
        bad "N2 /borg-link-up scaffolded — the ratified creation split is dissolved"
    fi
fi

# ── P3 / N3: /borg-assimilate closes the row, and never adds one ─────────────────────────────────
if [ -n "$model_off" ]; then
    skip "P3 /borg-assimilate closes the merged row ($model_off)"
    skip "N3 /borg-assimilate does not add a row it was meant to verify (P3 did not run)"
else
    p3="$(_eval_repo_with_project "$OUT/p3")"
    mkdir -p "$p3/$_EVAL_MANIFEST_DIR"
    printf '{"program":"prog","rows":[{"ref":"o/r#7","lane":"alpha","order":"1","why":"the merged one"}]}\n' \
        > "$p3/$_EVAL_MANIFEST_DIR/prog.json"
    _eval_plan "$p3" 2026-01-01-p3-slug
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
    mkdir -p "$n3/$_EVAL_MANIFEST_DIR"
    printf '{"program":"prog","rows":[{"ref":"o/r#99","lane":"alpha","order":"1","why":"a different ref"}]}\n' \
        > "$n3/$_EVAL_MANIFEST_DIR/prog.json"
    _eval_plan "$n3" 2026-01-01-n3-slug
    n3f="$n3/$_EVAL_MANIFEST_DIR/prog.json"
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

# ── THE EXECUTION FLOORS: one GLOBAL, then the MODEL mode's ─────────────────────────────────────
#
# SKIPs are reported and never gate: a `claude` that is missing or unauthenticated is a different
# fact from one that is wrong. But "every case skipped" and "every case passed" must not print the
# same rc 0, and once VERBS is in the file the global floor alone cannot tell the offline mode from a
# live sweep that found no `claude` -- VERBS satisfies PASS+FAIL>0 single-handed. So the ABSENCE of
# `--skip-model` is read as a request: ask for the model sweep and none of it ran, and the run failed
# to do the thing it was asked to do. The more specific reason is ordered first so it is the one
# that gets printed; either way the exit is non-zero.
echo
echo "RESULT: $PASS pass, $FAIL fail, $SKIPPED skip"
if [ $((PASS + FAIL)) -eq 0 ]; then
    echo "every case skipped: nothing was verified" >&2
    exit 1
fi
if [ "$SKIP_MODEL" -eq 0 ] && [ "$MODEL_RAN" -eq 0 ]; then
    echo "the model sweep was requested but no model case executed" >&2
    exit 1
fi
[ "$FAIL" -eq 0 ]
