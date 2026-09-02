#!/usr/bin/env bash
# S4 + K3/AC3 acceptance eval. Green here + merge-tree/test_s4_manifests.py green is the landing
# gate for S4 and the evidence for K3's AC3 ("correct chain position for a manifest-declared PR").
#
# Evals:
#   E2  live refs: every declared ref resolves on GitHub (no typo'd rows)
#   E3  gather integration: declared edges flow, zero contested refs
#   E4  K3 manifest path: /pr-description on a manifest-declared PR branch renders chain
#       position FROM THE MANIFEST (program, lane, gate) — not the fallback
#   E5  K3 fallback path: /pr-description in a manifest-less repo says "No manifest declared."
#       (proves the conditional discriminates; without this E4 could pass vacuously)
#
# NO PATH IS HARDCODED, AND NO CASE MAY REQUIRE A SECOND REPOSITORY TO EXIST. `REPO` derives from
# this script's own location; `STILLPOINT` and `TROTH` are OPTIONAL and default to empty. A case
# whose inputs are absent SKIPs with a named reason and never fails — "not present on this machine"
# is a different fact from "wrong", and conflating them is what made every case here report FAIL.
# The ${VAR:-default} override is the idiom three sibling scripts already use
# (scripts/check-agent-roster.sh, scripts/check-plugin-version.sh, lib/reaper.sh); this script was
# the only path-hardcoded one in the tree with NO override, and it pointed at /Users/noah, which
# does not exist on any machine that has ever run it.
#
# WHY THAT WAS INVISIBLE: `set -uo pipefail` carries no `-e`, so the prologue's `mkdir -p "$OUT"`
# failed against the dead prefix, execution continued, and all five cases reported FAIL for never
# having run. A harness that cannot execute reports the same shape as a harness that executed and
# found defects. Do not add `set -e` to fix it — the PASS/FAIL counters are a deliberate
# continue-on-error design so one broken case does not hide the others; the fix is that the
# prologue's paths are now derived and `$OUT` is re-created from scratch on every run.
#
# E1 (cross-repo discovery) LIVED HERE AND WAS DELETED 2026-09-02. It asserted that
# `discover([REPO, STILLPOINT])` returns both manifests with zero warnings — a property already
# green twice in CI over temp directories needing neither git nor a network
# (borg_core/manifest/test_shell.py's multi-repository sweep and the four-repo B6 case below it),
# plus merge-tree/test_s4_manifests.py over this repo's committed manifests. What E1 uniquely
# covered was "stillpoint's live manifest file is well-formed" — a smoke test of another
# repository's DATA, which belongs in that repository, not in this harness.
#
# Usage: evals/s4-k3/run.sh [--skip-model]
#   --skip-model   skip the cases that need a headless model run (E4/E5)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${BORG_EVAL_REPO:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
STILLPOINT="${BORG_EVAL_STILLPOINT:-}"
TROTH="${BORG_EVAL_TROTH:-}"

# Guard before the `rm -rf` below: a mis-derived or mis-overridden REPO must not be able to point
# the cleanup at an arbitrary directory. This script is the one file REPO is guaranteed to contain.
if [ ! -f "$REPO/evals/s4-k3/run.sh" ]; then
    echo "ERROR: REPO does not look like the borg-collective checkout: $REPO" >&2
    exit 2
fi

OUT="$REPO/evals/s4-k3/out"

SKIP_MODEL=0
while [ $# -gt 0 ]; do
    case "$1" in
        --skip-model) SKIP_MODEL=1 ;;
        -h|--help)    echo "usage: evals/s4-k3/run.sh [--skip-model]"; exit 0 ;;
        *)            echo "unknown flag: $1" >&2; exit 2 ;;
    esac
    shift
done

# Recreated, not merely ensured. Every case here writes its evidence into $OUT and then greps it,
# so a stale artifact from a previous run is a false PASS for a case that produced nothing this
# time — the same failure mode as reading a golden that was never regenerated.
rm -rf "$OUT"
mkdir -p "$OUT"

# The repository set every manifest-reading case sweeps. Optional members are included only when
# they are actually present, so an absent stillpoint narrows the sweep instead of injecting a
# nonexistent path (which `discover` would correctly report as a warning, failing a case for a
# reason that has nothing to do with what it asserts).
REPOS=("$REPO")
if [ -n "$STILLPOINT" ] && [ -d "$STILLPOINT" ]; then
    REPOS+=("$STILLPOINT")
fi
PROGRAMS_DIR_ARGS=()
for _r in "${REPOS[@]}"; do
    PROGRAMS_DIR_ARGS+=(--programs-dir "$_r")
done

PASS=0; FAIL=0; SKIPPED=0
ok()   { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
# A case that cannot run is reported as SKIP and does not affect the exit status. CLAUDE.md's
# platform-premise lesson in one line: a case that cannot pass here is not a weaker check, it is
# checking a different fact.
skip() { echo "  SKIP  $1"; SKIPPED=$((SKIPPED+1)); }

# ── E2: live refs ────────────────────────────────────────────────────────────────────────────────
# THE ONE ESSENTIAL NETWORK DEPENDENCY IN THIS FILE. "Does owner/repo#N exist, and can this token
# see it" is a claim about GitHub's present state; no committed artifact can establish it, because a
# frozen recording asserts only "it existed at T". Every OTHER property E2 appears to check — the
# ref's shape, its kind, its uniqueness, whether the fetch path can even address it — is already
# enforced offline by borg_core.manifest's validator, and belongs in pytest rather than here.
echo "== E2: every declared ref resolves on GitHub =="
if ! command -v gh >/dev/null 2>&1; then
    skip "E2 refs: gh is not installed"
elif ! gh auth status >/dev/null 2>&1; then
    # NEVER a FAIL. An unauthenticated `gh` makes every ref look unresolved, so failing here would
    # report "N typo'd rows" for what is actually a credential problem — the exact conflation this
    # case must not make, and the reason a bare CI runner saw all 17 refs as bad.
    skip "E2 refs: gh is not authenticated (a 401 is indistinguishable from a dead ref)"
else
    E2_FAILS=$(cd "$REPO/merge-tree" && python3 - "${REPOS[@]}" <<'PY'
import subprocess
import sys
import programs
manifests, _ = programs.discover(sys.argv[1:])
refs = set()
for m in manifests:
    for r in m.get("rows", []):
        refs.add(r["ref"])
    apex = m.get("apex")
    if isinstance(apex, dict) and apex.get("ref"):
        refs.add(apex["ref"])
bad = []
for ref in sorted(refs):
    repo, num = ref.rsplit("#", 1)
    p = subprocess.run(["gh", "pr", "view", num, "--repo", repo, "--json", "state"],
                       capture_output=True, text=True, timeout=30)
    if p.returncode != 0:
        bad.append(ref)
print(f"checked={len(refs)} unresolved={bad}")
sys.exit(1 if bad else 0)
PY
)
    E2_RC=$?
    echo "  $E2_FAILS"
    [ "$E2_RC" -eq 0 ] && ok "E2 refs: all resolve" || bad "E2 refs: unresolved rows"
fi

# ── E3: gather integration ───────────────────────────────────────────────────────────────────────
# GitHub is this case's INPUT, not its assertion. Both asserted quantities are pure functions of the
# discovered manifests: `edge_provenance.declared` counts declared edges in the merged set
# regardless of items, and `program_contested_refs` is built before the item loop runs at all. This
# case therefore passes against a completely failed sweep — measured. The live `borg recon` call is
# removable, and replacing it with a hand-authored recon fixture is the deferred half of AC6.
#
# ONE TRAP BEFORE THAT REWRITE. `program_contested_refs` reads each manifest's top-level `program`
# key and SKIPS any manifest without one. borg_core's discovery writes `_id` and is pinned never to
# invent `program`, so once AC7 finishes retiring the word this assertion can no longer fail and
# `program_regrouped_items` collapses to zero — green because the code stopped running. A rewrite
# onto borg_core must assert a ported `contested_refs()` reading `_id`, or carry a tripwire that
# goes red the day the retired key disappears.
echo "== E3: gather integration (live recon) =="
if [ "${#REPOS[@]}" -lt 2 ]; then
    # The `>= 14` threshold is calibrated for the two-repository set. With one repository the count
    # is legitimately lower, so running it would fail for a reason unrelated to what it asserts.
    skip "E3 gather: needs the second repository (set BORG_EVAL_STILLPOINT)"
elif ! command -v borg >/dev/null 2>&1; then
    skip "E3 gather: borg is not on PATH"
else
    # `&&`, not `;`. With a semicolon the assertion ran even when gather.py had failed, reading
    # whatever e3-gather.json a previous run left behind — a false PASS over stale evidence.
    E3=$(cd "$REPO/merge-tree" && borg recon --json --since 2026-08-01T00:00:00Z 2>/dev/null | \
         python3 gather.py --in - --out "$OUT/e3-gather.json" \
           "${PROGRAMS_DIR_ARGS[@]}" 2>"$OUT/e3-stderr.txt" && \
         python3 -c "
import json
g = json.load(open('$OUT/e3-gather.json'))
prov = g['meta']['edge_provenance']
print(f\"declared={prov['declared']} contested={g['meta']['program_contested_refs']} dangling={len(prov['dangling_endpoints'])}\")
exit(0 if prov['declared'] >= 14 and g['meta']['program_contested_refs'] == [] else 1)
")
    E3_RC=$?
    echo "  $E3"
    [ "$E3_RC" -eq 0 ] && ok "E3 gather: declared edges flow, zero contested" || bad "E3 gather"
fi

# macOS has no GNU `timeout`; use gtimeout when available, else rely on claude -p terminating.
# An ARRAY, not a string: the value is two words when gtimeout exists and zero words when it does
# not, and only an array expands to both correctly under quoting that shellcheck accepts.
TIMEOUT=()
command -v gtimeout >/dev/null 2>&1 && TIMEOUT=(gtimeout 420)

if [ "$SKIP_MODEL" -eq 1 ]; then
    echo "== E4/E5 skipped (--skip-model) =="
else
    # E4/E5 grade `/pr-description`, WHICH THIS REPOSITORY DOES NOT OWN — nothing under skills/
    # matches it; it is a claude-plugins skill. So a red here can mean a defect in a surface that
    # is not in this tree, and the case cannot be repaired from inside this repo. Recorded rather
    # than fixed: relocating these two cases is AC5's problem, not the harness's.
    echo "== E4: /pr-description reads the manifest (stillpoint#48 branch) =="
    if ! command -v claude >/dev/null 2>&1; then
        skip "E4 chain position: claude is not on PATH"
    elif [ -z "$STILLPOINT" ] || [ ! -d "$STILLPOINT" ]; then
        skip "E4 chain position: needs the second repository (set BORG_EVAL_STILLPOINT)"
    else
        WT=/tmp/s4-eval-stillpoint
        git -C "$STILLPOINT" worktree remove --force "$WT" 2>/dev/null
        git -C "$STILLPOINT" fetch origin write-freeze-design 2>/dev/null
        git -C "$STILLPOINT" worktree add "$WT" origin/write-freeze-design --detach 2>/dev/null
        mkdir -p "$WT/.borg/programs"
        cp "$STILLPOINT/.borg/programs/ingle-t1-cutover.json" "$WT/.borg/programs/"
        (cd "$WT" && "${TIMEOUT[@]}" claude -p "/pr-description" > "$OUT/e4-body.md" 2>"$OUT/e4-stderr.txt")
        if grep -q "ingle-t1-cutover" "$OUT/e4-body.md" && \
           grep -qi "cutover" "$OUT/e4-body.md" && \
           ! grep -q "No manifest declared" "$OUT/e4-body.md"; then
            ok "E4 chain position rendered from the manifest"
        else
            bad "E4 chain position (see $OUT/e4-body.md)"
        fi
        git -C "$STILLPOINT" worktree remove --force "$WT" 2>/dev/null
    fi

    # E5's input is "a repository with no manifest", which an ephemeral `git init` under a tmpdir
    # satisfies exactly as well as troth does — this case has no business naming a real repository.
    # NOT substituted here, deliberately: the substitution can only be verified against the real
    # `/pr-description`, which lives in claude-plugins, and a change that cannot be tested from this
    # tree is not an improvement. It is the first thing to do when these cases move.
    echo "== E5: fallback path in a manifest-less repo (troth) =="
    if ! command -v claude >/dev/null 2>&1; then
        skip "E5 fallback: claude is not on PATH"
    elif [ -z "$TROTH" ] || [ ! -d "$TROTH" ]; then
        skip "E5 fallback: needs a manifest-less repository (set BORG_EVAL_TROTH)"
    else
        (cd "$TROTH" && "${TIMEOUT[@]}" claude -p "/pr-description" > "$OUT/e5-body.md" 2>"$OUT/e5-stderr.txt")
        if grep -q "No manifest declared" "$OUT/e5-body.md"; then
            ok "E5 fallback line present"
        else
            bad "E5 fallback (see $OUT/e5-body.md)"
        fi
    fi
fi

echo
# SKIPs are reported but never gate. A case whose inputs are absent on this machine has not failed;
# printing the count keeps that visible instead of letting a mostly-skipped run read as a pass.
echo "RESULT: $PASS pass, $FAIL fail, $SKIPPED skip"
[ "$FAIL" -eq 0 ]
