#!/usr/bin/env bash
# AC5.3-AC5.5: do the three lifecycle skills author manifests BY DEFAULT?
#
# Six model cases, three pairs. Each positive is paired with the negative that proves the
# conditional discriminates, because a positive alone is satisfied just as well by a skill that
# does the thing unconditionally.
#
#   P1 /borg-plan        git init, no .borg      -> .borg/programs/<slug>.json exists, validates, rows: []
#   N1 /borg-plan        manifest present, 2 rows -> the file is BYTE-IDENTICAL afterwards
#   P2 /borg-link-up     manifest + gh stub      -> one row for that ref, correct lane and order
#   N2 /borg-link-up     NO manifest             -> none created, exit 0, the proposal is named
#   P3 /borg-assimilate  manifest declares ref   -> that row's status is merged, no other byte moved
#   N3 /borg-assimilate  manifest lacks the ref  -> file byte-identical, and NO row was added
#
# N1/N2/N3 are deliberately NOT "the input is absent". Each is a real regression surface: a
# clobbering scaffold destroys a declared program, a scaffolding link-up dissolves the ratified
# split (creation belongs to /borg-plan), and a close that falls back to add-row manufactures the
# very row it was meant to verify.
#
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

have_claude=0
command -v claude >/dev/null 2>&1 && have_claude=1

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

# Run one bare slash command inside a fixture, with only the allowlist on PATH.
# Args: <fixture-dir> <slash-command>
_run_skill() {
    local dir="$1" cmd="$2"
    ( cd "$dir" && PATH="$BIN:$REPO/.venv/bin" BORG_ROOT="$REPO" \
        claude -p "$cmd" --permission-mode acceptEdits >/dev/null 2>&1 )
}

_sha() { python3 -c '
import hashlib, sys, pathlib
p = pathlib.Path(sys.argv[1])
print(hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else "ABSENT")' "$1"; }

echo "== lifecycle-manifest evals =="

# ── P1 / N1: /borg-plan scaffolds, and never clobbers ────────────────────────────────────────────
p1="$(_eval_repo_without_manifest "$OUT/p1")"
_eval_plan "$p1" 2026-01-01-p1-slug
if [ "$have_claude" -eq 0 ]; then
    skip "P1 /borg-plan scaffolds a manifest (claude unavailable)"
else
    MODEL_RAN=$((MODEL_RAN+1))
    _run_skill "$p1" "/borg-plan"
    if PYTHONPATH="$REPO" python3 -c '
import sys
from borg_core.manifest import shell
ms, warns = shell.discover([sys.argv[1]])
sys.exit(0 if len(ms) == 1 and (ms[0].get("rows") == []) and not warns else 1)' "$p1" 2>/dev/null; then
        ok "P1 /borg-plan scaffolded a valid manifest with rows: []"
    else
        bad "P1 /borg-plan did not scaffold a valid empty-rows manifest"
    fi
fi

n1="$(_eval_repo_with_manifest "$OUT/n1" declared \
    '[{"ref":"o/r#1","lane":"alpha","order":"1","why":"first"},{"ref":"o/r#2","lane":"alpha","order":"2","why":"second"}]')"
_eval_plan "$n1" 2026-01-01-n1-slug
n1f="$n1/.borg/programs/declared.json"
before="$(_sha "$n1f")"
if [ "$have_claude" -eq 0 ]; then
    skip "N1 /borg-plan does not clobber an existing manifest (claude unavailable)"
else
    MODEL_RAN=$((MODEL_RAN+1))
    _run_skill "$n1" "/borg-plan"
    if [ "$(_sha "$n1f")" = "$before" ]; then
        ok "N1 existing manifest is BYTE-IDENTICAL after /borg-plan"
    else
        bad "N1 /borg-plan rewrote a declared manifest — a clobbering scaffold destroys a program"
    fi
fi

# ── P2 / N2: /borg-link-up adds the row, and never scaffolds ─────────────────────────────────────
p2="$(_eval_repo_with_manifest "$OUT/p2" prog)"
_eval_plan "$p2" 2026-01-01-p2-slug
if [ "$have_claude" -eq 0 ]; then
    skip "P2 /borg-link-up adds one row for the branch's PR (claude unavailable)"
else
    MODEL_RAN=$((MODEL_RAN+1))
    _run_skill "$p2" "/borg-link-up"
    if PYTHONPATH="$REPO" python3 -c '
import sys
from borg_core.manifest import shell
ms, _w = shell.discover([sys.argv[1]])
rows = ms[0].get("rows") if ms else []
sys.exit(0 if any("#7" in str(r.get("ref")) for r in rows) else 1)' "$p2" 2>/dev/null; then
        ok "P2 /borg-link-up added a row for the stubbed PR ref"
    else
        bad "P2 /borg-link-up added no row for the stubbed PR ref"
    fi
fi

n2="$(_eval_repo_without_manifest "$OUT/n2")"
_eval_plan "$n2" 2026-01-01-n2-slug
if [ "$have_claude" -eq 0 ]; then
    skip "N2 /borg-link-up does not scaffold where no manifest exists (claude unavailable)"
else
    MODEL_RAN=$((MODEL_RAN+1))
    _run_skill "$n2" "/borg-link-up"
    if [ ! -e "$n2/.borg/programs" ]; then
        ok "N2 no manifest was created — creation still belongs to /borg-plan"
    else
        bad "N2 /borg-link-up scaffolded — the ratified creation split is dissolved"
    fi
fi

# ── P3 / N3: /borg-assimilate closes the row, and never adds one ─────────────────────────────────
p3="$(_eval_repo_with_manifest "$OUT/p3" prog \
    '[{"ref":"o/r#7","lane":"alpha","order":"1","why":"the merged one"}]')"
_eval_plan "$p3" 2026-01-01-p3-slug
if [ "$have_claude" -eq 0 ]; then
    skip "P3 /borg-assimilate closes the merged row (claude unavailable)"
else
    MODEL_RAN=$((MODEL_RAN+1))
    _run_skill "$p3" "/borg-assimilate"
    if PYTHONPATH="$REPO" python3 -c '
import sys
from borg_core.manifest import shell
ms, _w = shell.discover([sys.argv[1]])
rows = ms[0].get("rows") if ms else []
sys.exit(0 if any(str(r.get("ref")).endswith("#7") and r.get("status") == "merged"
                  for r in rows) else 1)' "$p3" 2>/dev/null; then
        ok "P3 /borg-assimilate set the declared row's status to merged"
    else
        bad "P3 /borg-assimilate did not close the declared row"
    fi
fi

n3="$(_eval_repo_with_manifest "$OUT/n3" prog \
    '[{"ref":"o/r#99","lane":"alpha","order":"1","why":"a different ref"}]')"
_eval_plan "$n3" 2026-01-01-n3-slug
n3f="$n3/.borg/programs/prog.json"
before3="$(_sha "$n3f")"
if [ "$have_claude" -eq 0 ]; then
    skip "N3 /borg-assimilate does not add a row it was meant to verify (claude unavailable)"
else
    MODEL_RAN=$((MODEL_RAN+1))
    _run_skill "$n3" "/borg-assimilate"
    if [ "$(_sha "$n3f")" = "$before3" ]; then
        ok "N3 manifest is BYTE-IDENTICAL — no fallback add-row"
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
