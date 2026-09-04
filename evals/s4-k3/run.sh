#!/usr/bin/env bash
# S4 + K3/AC3 acceptance eval. Green here + merge-tree/test_s4_manifests.py green is the landing
# gate for S4 and the evidence for K3's AC3 ("correct chain position for a manifest-declared PR").
#
# Evals:
#   E2a manifest round-trip contract, via pytest: the one case that is deterministic on EVERY
#       machine — no network, no `gh`, no second repository, no model
#   E2  live refs: every declared ref resolves on GitHub (no typo'd rows)
#   E3  gather integration: declared edges flow, zero contested refs
#
# E4/E5 (the /pr-description chain-position pair) RELOCATED 2026-09-03 to claude-plugins,
# evals/pr-description/. See the tombstone above the floors for why, and for why the model mode
# and its floor went with them.
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
# Usage: evals/s4-k3/run.sh [--skip-model] [--skip-network]
#   --skip-model     ACCEPTED AND INERT -- no case here needs a model since E4/E5 relocated
#                    (see the tombstone below); kept because `EVAL_ARGS` passes it to every
#                    harness and the unknown-flag arm exits 2
#   --skip-network   skip the cases that read the wire (E2/E3)
#
# THE FLAGS USED TO PARTITION THE CASES INTO THREE MODES, which is why the execution floors at
# the bottom are per-mode and not merely global. Since E4/E5 relocated there are TWO: offline
# and network. `--skip-model --skip-network` is the OFFLINE mode and
# is what `make eval` passes: E2a alone, deterministic on every machine. DROPPING a flag is a
# REQUEST for that mode's sweep, so a run that asked for a sweep and executed none of it is a
# failure, not a 0-of-N pass. `--skip-network` exists because `make eval` was documented as the safe
# target while E2 still shelled one `gh pr view` per declared ref: with `gh` authenticated and the
# wire down, the safe target exited non-zero and blamed three manifest rows as unresolved — the same
# conflation E2's own comment forbids for the 401 case, a transport failure being that class.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${BORG_EVAL_REPO:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
STILLPOINT="${BORG_EVAL_STILLPOINT:-}"
TROTH="${BORG_EVAL_TROTH:-}"

# THE INTERPRETER IS AN INPUT AND IS DERIVED LIKE THE PATHS ABOVE. E2a needs an importable pytest,
# which in this repository is a dev-group dependency installed into `.venv` and NOT on the ambient
# PATH: in the author's default shell `python3` resolves to Homebrew's interpreter and
# `python3 -m pytest` exits 1 with "No module named pytest". `make test` and `make lint` carry the
# same unstated precondition — they invoke `coverage`, `ruff`, `mypy` and `pylint` bare — so this is
# a property of the toolchain's location, not of this harness; the difference is that the harness
# STATES it, which is what keeps `make eval` from being red on the machine of record. Same
# ${VAR:-default} override idiom as REPO, except the default is conditional rather than a single
# expression: the venv interpreter when it is there, bare `python3` when it is not, so a CI job that
# installs the dev group into the ambient environment keeps working untouched.
if [ -n "${BORG_EVAL_PYTHON:-}" ]; then
    PYTHON="$BORG_EVAL_PYTHON"
elif [ -x "$REPO/.venv/bin/python" ]; then
    PYTHON="$REPO/.venv/bin/python"
else
    PYTHON="python3"
fi

# Guard before the `rm -rf` below: a mis-derived or mis-overridden REPO must not be able to point
# the cleanup at an arbitrary directory. `borg.zsh` is the marker because it is TRACKED and sits at
# the root -- it knows nothing about where this harness lives, so moving the harness cannot break
# the guard. Not `.borg-project`, which looks like the obvious repository marker and is gitignored:
# it does not exist in a fresh CI checkout, so the guard would abort every CI run.
if [ ! -f "$REPO/borg.zsh" ]; then
    echo "ERROR: REPO does not look like the borg-collective checkout: $REPO" >&2
    exit 2
fi

OUT="$REPO/evals/s4-k3/out"

SKIP_MODEL=0
SKIP_NETWORK=0
while [ $# -gt 0 ]; do
    case "$1" in
        --skip-model)   SKIP_MODEL=1 ;;
        --skip-network) SKIP_NETWORK=1 ;;
        -h|--help)      echo "usage: evals/s4-k3/run.sh [--skip-model] [--skip-network]"; exit 0 ;;
        *)              echo "unknown flag: $1" >&2; exit 2 ;;
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
PASS=0; FAIL=0; SKIPPED=0
# PER-MODE EXECUTION COUNTERS, incremented by the branch that actually RAN a case rather than by
# `ok`/`bad`, so "this mode swept something" is recorded once per case regardless of its verdict.
# They exist because the global PASS+FAIL floor cannot tell "E2a ran" from "the live sweep ran": E2a
# always executes, so it satisfies a global floor single-handed, and `make eval-live` on a machine
# with neither `gh` nor `claude` therefore printed "1 pass, 0 fail, 4 skip" and exited 0 with the
# ENTIRE live sweep absent — the exit code asserting a sweep that never happened.
#
# GRANULARITY IS ONE FLOOR PER MODE, NOT ONE PER CASE, and deliberately so: "at least one network
# case executed" is the strongest claim a mode gate can honestly make here, because E2 needs an
# authenticated `gh` and E4/E5 need `claude`. A per-case floor would fail for an absent input,
# which is the exact thing this file exists not to do and the reason `skip` is a first-class
# verdict above. E3 USED TO BE LISTED HERE as needing a second repository on disk and no longer
# does -- it stages its own two-repository tree from committed fixtures, so its inputs are now as
# present as E2a's.
NETWORK_RAN=0
ok()   { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
# A case that cannot run is reported as SKIP and does not affect the exit status. CLAUDE.md's
# platform-premise lesson in one line: a case that cannot pass here is not a weaker check, it is
# checking a different fact.
skip() { echo "  SKIP  $1"; SKIPPED=$((SKIPPED+1)); }

# ── E2a: manifest round-trip contract (offline, deterministic) ───────────────────────────────────
# THE CASE THAT RUNS ON EVERY MACHINE. No network, no `gh`, no second repository, no model — which
# is the entire reason it exists. The EXECUTION FLOOR at the bottom of this file is satisfiable
# rather than a permanent red on a bare checkout only because this case always executes, so E2a is
# the case that must never SKIP in practice: if it does, the floor fires and the harness says so.
#
# ONE IMPLEMENTATION, TWO CALLERS. The assertions live in pytest, where CI's `python` job already
# collects them through `make test`; `make eval` is not, and must not become, a sixth CI job. This
# case therefore delegates to the same node selection instead of restating one assertion of its own.
# Do not "inline the check here so the harness is self-contained" — that creates a second copy of a
# contract, and the two copies are then free to disagree about what the manifest writer promises.
#
# `-k e2a` IS A CONTRACT WITH THE TEST NAMES, AND THE CONTRACT IS A COUNT, NOT A NON-ZERO. Rename or
# delete 14 of the 15 `test_e2a_*` functions and `-k e2a` selects 1, pytest exits 0, and this case
# reports PASS over a gate that has been silently emptied of all but one assertion; rename all 15 and
# the selection is empty. So the count is floored against an authored minimum below, and E2A_MIN is
# not a guess: it is what `--collect-only` reports for this selection today, verified by running it.
#
# THE COUNT FLOOR IS THE LIVE GUARD AGAINST EVERY RENAME, PARTIAL OR TOTAL, AND IT IS THE ONLY ONE.
# It is checked FIRST, off its own `--collect-only` pass, so the all-or-nothing rename reaches it too
# and is named as "selected 0 of 15" — which keeps "the tests were renamed" and "the contract broke"
# apart, the distinction this file once shipped a bug for conflating and the whole reason the count is
# read at all.
#
# WHICH IS ALSO WHY THERE IS NO rc-5 ARM, AND WHY ONE MUST NOT BE ADDED BACK. pytest returns 5 for an
# empty selection; an empty selection collects zero node ids; zero is below any authored minimum of
# one or more, so the floor above has already returned with a better message before the run phase is
# invoked. The arm was unreachable for every value E2A_MIN can hold and had no oracle it could ever
# get — tests/eval_floor.bats's count-floor case can only assert its string is ABSENT — so it was
# deleted rather than reworded a third time. An rc 5 that arrives anyway means the whole selection was
# renamed BETWEEN this case's two pytest invocations, milliseconds apart: a race, not a control-flow
# path, and one the "pytest exited N" arm still reports as a FAIL, with the rc named and an evidence
# file that reads "no tests ran". Only a nicer sentence in an unobservable window was given up.
#
# AND A COLLECTED TEST IS NOT AN EXECUTED ONE — THE COUNT FLOOR CANNOT SEE THE SKIP DOOR AT ALL.
# pytest COLLECTS a skipped test, so a selection in which every case carries a skip marker still
# reports 15 selected, still exits 0, and printed a PASS line whose stdout was BYTE-IDENTICAL to a
# real pass: measured on a sandbox copy, where the control's evidence read "15 passed, 87 deselected"
# and the mutant's read "15 skipped, 87 deselected". The partial case is the same shape — 14 of 15
# skipped reported PASS over an evidence file reading "1 passed, 14 skipped". Not a contrived
# mutation, either: this very test module legitimately skips a chmod case when it runs as root in a
# devcontainer, so one marker that drifts to module scope is all it takes.
#
# SO THE VERDICT READS THE EXECUTED OUTCOME, AND READS IT FROM `--junit-xml` RATHER THAN FROM `-q`'s
# SUMMARY. The summary's wording is pytest's to change; the XML's element shape is a published
# contract, and the interpreter that can parse it is already resolved above. A `<testcase>` executed
# as a pass iff it carries no `skipped`, `failure` or `error` child, and the whole selection must
# account for itself that way. That closes both doors rc 0 leaves open, because a skip and an xfail
# BOTH render as `<skipped>` (measured) while every failure and error forces rc non-zero — so the
# floor below is the discriminator for exactly the outcomes the exit code cannot show, and the arms
# after it keep naming the ones it can.
#
# `-o xfail_strict=true` CLOSES THE THIRD DOOR, WHICH THE XML ALONE CANNOT. A non-strict xpass
# renders byte-identically to a pass — no child element, nothing to count — so no reading of this XML
# could see it; under `xfail_strict` it becomes a `<failure>` at rc 1 and lands in the "pytest exited
# N" arm with `[XPASS(strict)]` named in the evidence file. An `-o` override rather than a pyproject
# key, deliberately: strictness is this gate's demand on its own selection, not a rule this harness
# gets to impose on every other suite the `python` job collects.
echo "== E2a: manifest round-trip contract (pytest, offline) =="
E2A_MIN=15
if ! "$PYTHON" -c "import pytest" >/dev/null 2>&1; then
    # GUARDED ON THE INPUT THE CASE ACTUALLY NEEDS, which is an importable pytest and not merely an
    # interpreter. E2 and E3 shell into bare `python3` and are right to — `merge-tree/programs.py`
    # and `gather.py` import only stdlib, so any stock interpreter runs them — but E2a needs a
    # THIRD-PARTY DEV DEPENDENCY, which no interpreter carries by construction. "python3 is on PATH"
    # is therefore a different fact from "this case can execute", and a harness that checks the
    # first and then reports FAIL prints the manifest contract's name for what is a missing package:
    # the conflation the header forbids, one layer in from where it was first found.
    skip "E2a contract: pytest is not importable by $PYTHON"
else
    (cd "$REPO" && "$PYTHON" -m pytest borg_core/manifest/test_shell.py -k e2a -q --collect-only) \
        > "$OUT/e2a-collect.txt" 2>&1
    # `grep -c` RETURNS 1 ON ZERO MATCHES, so it must never be the last command of a chain whose
    # status is read — under `pipefail` an empty collection would surface as a shell failure instead
    # of as the count 0 this floor wants to name. Captured into a variable and compared as its own
    # statement for exactly that reason. Counting node-id lines, not parsing the trailing "N/M tests
    # collected" summary, because the summary's wording is pytest's to change and a node id's `::`
    # is the stable part of `--collect-only -q` output.
    E2A_SELECTED=$(grep -c '::' "$OUT/e2a-collect.txt")
    # DEFAULTED SO THE COMPARISON CANNOT FAIL OPEN. `grep -c` writes a count to stdout or nothing at
    # all, and the nothing case — grep missing, output file unreadable — left this empty, whereupon
    # `[ "" -lt 15 ]` is not false but an ERROR (status 2, "integer expression expected"), which the
    # `if` reads as "not less than" and E2a reported PASS with an empty count in its own message.
    # Measured, not imagined: it is what a PATH-allowlist probe of `make eval-live` printed. A floor
    # that cannot compute its input must fail CLOSED, so an absent count becomes 0 and trips it.
    E2A_SELECTED="${E2A_SELECTED:-0}"
    if [ "$E2A_SELECTED" -lt "$E2A_MIN" ]; then
        bad "E2a contract: -k e2a selected $E2A_SELECTED of $E2A_MIN authored (see $OUT/e2a-collect.txt)"
    else
        (cd "$REPO" && "$PYTHON" -m pytest borg_core/manifest/test_shell.py -k e2a -q \
            -o xfail_strict=true --junit-xml="$OUT/e2a-junit.xml") \
            > "$OUT/e2a-pytest.txt" 2>&1
        E2A_RC=$?
        if [ "$E2A_RC" -eq 0 ]; then
            # THE EXECUTED-OUTCOME FLOOR, INSIDE THE rc-0 ARM BECAUSE THAT IS THE ONLY PLACE IT IS
            # NEEDED: a failure or an error already forces rc non-zero and keeps its own reason
            # below, so what remains to be caught here is the class the exit code is blind to. The
            # reader's stderr goes to a file rather than to the terminal so a traceback names its
            # reason without splicing itself into the PASS/FAIL stream this harness's callers grep.
            E2A_PASSED=$("$PYTHON" - "$OUT/e2a-junit.xml" 2>"$OUT/e2a-junit-read.txt" <<'PY'
import sys
import xml.etree.ElementTree as ET

# Not "has no children": `properties` and `system-out` are legal children of a PASSING testcase
# under a `junit_logging` setting this harness does not control. The outcome tags are the fact.
NOT_A_PASS = ("skipped", "failure", "error")
root = ET.parse(sys.argv[1]).getroot()
print(sum(1 for case in root.iter("testcase") if not any(k.tag in NOT_A_PASS for k in case)))
PY
)
            # CLASSIFIED BEFORE IT IS COMPARED, NEVER `-lt` ON AN UNKNOWN VALUE. The count floor
            # above learned this one the expensive way: `[ "" -lt 15 ]` is not false but an ERROR
            # (status 2, "integer expression expected"), which `if` reads as "not less than", so the
            # empty case printed PASS. A `case` over the digits admits nothing else to the
            # comparison, so an absent XML, a malformed one, or a reader that raised gets a reason of
            # its own instead of a fail-open. An XML recording zero testcases needs no special arm:
            # it yields 0, which is less than any selection the floor above let through.
            case "$E2A_PASSED" in
                ''|*[!0-9]*)
                    bad "E2a contract: could not read the executed outcome from $OUT/e2a-junit.xml"
                    ;;
                *)
                    if [ "$E2A_PASSED" -lt "$E2A_SELECTED" ]; then
                        # The tail is assembled in a variable only because `bad` takes ONE argument
                        # and the whole sentence does not fit the wrap at this indent; a second
                        # argument would be silently dropped by the reporter rather than printed.
                        E2A_EVIDENCE="($E2A_PASSED passed, see $OUT/e2a-junit.xml)"
                        bad "E2a contract: $E2A_SELECTED collected but not all executed $E2A_EVIDENCE"
                    else
                        ok "E2a contract: pytest green ($E2A_PASSED of $E2A_SELECTED executed as passes)"
                    fi
                    ;;
            esac
        else
            # EVERY NON-ZERO rc LANDS HERE BY NAME, INCLUDING 5 — see the count floor's comment for
            # why 5 is not special-cased: it cannot be reached from a floor of one or more, and the
            # rc plus the evidence file say what happened when a race produces it anyway.
            bad "E2a contract: pytest exited $E2A_RC (see $OUT/e2a-pytest.txt)"
        fi
    fi
fi

# ── E2: live refs ────────────────────────────────────────────────────────────────────────────────
# THE ONE ESSENTIAL NETWORK DEPENDENCY IN THIS FILE. "Does owner/repo#N exist, and can this token
# see it" is a claim about GitHub's present state; no committed artifact can establish it, because a
# frozen recording asserts only "it existed at T". Every OTHER property E2 appears to check — the
# ref's shape, its kind, its uniqueness, whether the fetch path can even address it — is already
# enforced offline by borg_core.manifest's validator, and belongs in pytest rather than here.
echo "== E2: every declared ref resolves on GitHub =="
if [ "$SKIP_NETWORK" -eq 1 ]; then
    # FIRST in the chain, ahead of the `gh` probes: once the caller has said "offline", whether a
    # `gh` exists and holds a credential is not a fact this run is entitled to consult, and probing
    # it anyway would make the reason printed depend on the machine rather than on the request.
    skip "E2 refs: --skip-network (resolving a ref is a live read of GitHub's present state)"
elif ! command -v gh >/dev/null 2>&1; then
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
    NETWORK_RAN=$((NETWORK_RAN+1))
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
if [ "$SKIP_NETWORK" -eq 1 ]; then
    # E3 IS A NETWORK CASE TOO, which the case header above already concedes by calling GitHub its
    # input: `borg recon` fans out over the adapters, and this repository's reference adapter shells
    # `gh`. That the assertion survives a completely failed sweep (measured) does not make the sweep
    # offline — it makes the case's coupling incidental, which is a claim about the deferred rewrite
    # and not a licence to reach the wire under a flag that says not to.
    skip "E3 gather: --skip-network (borg recon fans out over the github adapter)"
elif ! command -v borg >/dev/null 2>&1; then
    skip "E3 gather: borg is not on PATH"
else
    # THE SECOND REPOSITORY IS NOW STAGED, NOT REQUIRED. This case used to skip unless
    # BORG_EVAL_STILLPOINT named a real checkout, which made it unrunnable on any machine that
    # happened not to have that repository cloned -- and the machines are three (personal,
    # ontra, stillpoint), so "present locally" was never a property of the case, only of the
    # laptop. What E3 asserts is that DECLARED EDGES FLOW through gather and that no ref is
    # contested; the identity of the repositories carrying those manifests is incidental to both
    # halves. So it stages a two-repository tree from committed fixtures.
    #
    # AND THE THRESHOLD BECOMES AN EQUALITY, which is the real gain. `>= 14` was calibrated
    # against whatever two live repositories held on the day it was written -- a number nobody
    # could re-derive, that drifts silently as those repositories change, and that a fixture
    # producing 200 edges would satisfy just as well as one producing 14. The staged pair is
    # hand-authored, so the count is EXACT and falsifiable by its own inputs: add or remove a row
    # in either fixture and this case goes red, naming both numbers.
    #
    # `discover` globs `.borg/programs/*.json` and never shells git, so the staged tree needs no
    # `git init` -- two directories and two files is the whole fixture.
    fixture_root="$OUT/fixtures"
    programs_dir_args=()
    for fixture_repo in platform warehouse; do
        mkdir -p "$fixture_root/$fixture_repo/.borg/programs"
        programs_dir_args+=(--programs-dir "$fixture_root/$fixture_repo")
    done
    cp "$SCRIPT_DIR/fixtures/programs/atlas-cutover.json" \
       "$fixture_root/platform/.borg/programs/"
    cp "$SCRIPT_DIR/fixtures/programs/warehouse-window.json" \
       "$fixture_root/warehouse/.borg/programs/"

    # THE OPT-IN REAL-DATA UPGRADE. When a real second repository IS on this machine it is swept
    # IN ADDITION to the fixtures, so nothing that used to be covered stops being covered -- but
    # its presence can only ADD edges, so the assertion below compares against the authored
    # fixture total with a floor rather than an equality in that mode. Absent, the equality holds
    # and is the stronger claim.
    # AUTHORED, NOT MEASURED-AND-PINNED. 15 is what the two fixtures above derive: nine apex
    # edges (six rows under platform#900, three under warehouse#920) plus six stacked edges. It
    # was verified against BOTH implementations before being written down, and they agree on the
    # TOTAL while disagreeing on two members -- borg_core honours `after:` and emits
    # platform#903 -> warehouse#912 and platform#902 -> warehouse#923, merge-tree ignores it and
    # emits the lane-consecutive warehouse#911 -> #912 and #922 -> #923 instead. That is AC7
    # decision (3)'s reader/writer divergence in nine rows, and it is the reason this number is
    # safe across AC7's repoint of gather.py: the count survives, only the membership moves. If a
    # future change makes the totals differ, THIS COMMENT is the thing that was wrong, not the
    # fixture.
    E3_AUTHORED_EDGES=15
    E3_EXACT=1
    for repository in "${REPOS[@]:1}"; do
        programs_dir_args+=(--programs-dir "$repository")
        E3_EXACT=0
    done
    # `&&`, not `;`. With a semicolon the assertion ran even when gather.py had failed, reading
    # whatever e3-gather.json a previous run left behind — a false PASS over stale evidence.
    E3=$(cd "$REPO/merge-tree" && borg recon --json --since 2026-08-01T00:00:00Z 2>/dev/null | \
         python3 gather.py --in - --out "$OUT/e3-gather.json" \
           "${programs_dir_args[@]}" 2>"$OUT/e3-stderr.txt" && \
         python3 -c "
import json
g = json.load(open('$OUT/e3-gather.json'))
prov = g['meta']['edge_provenance']
declared, contested = prov['declared'], g['meta']['program_contested_refs']
exact, authored = $E3_EXACT, $E3_AUTHORED_EDGES
verdict = declared == authored if exact else declared >= authored
mode = 'exact' if exact else 'floor'
print(f\"declared={declared} authored={authored} ({mode}) contested={contested} dangling={len(prov['dangling_endpoints'])}\")
if not verdict:
    print(f\"  declared edge count {declared} != authored {authored}\" if exact
          else f\"  declared edge count {declared} below authored floor {authored}\")
exit(0 if verdict and contested == [] else 1)
")
    E3_RC=$?
    echo "  $E3"
    [ "$E3_RC" -eq 0 ] && ok "E3 gather: declared edges flow, zero contested" || bad "E3 gather"
    NETWORK_RAN=$((NETWORK_RAN+1))
fi

# THE `TIMEOUT` ARRAY AND ITS GUARD LEFT WITH E4/E5 and this is deliberately a pointer rather than
# the paragraph that used to be here. That paragraph was live-voice instruction about this script's
# own code -- "An ARRAY, not a string", "EVERY EXPANSION OF IT IS `${TIMEOUT[@]+...}`", "DO NOT
# 'SIMPLIFY' THE GUARD BACK" -- and there is now no `TIMEOUT` assignment and no expansion anywhere in
# this file, so a maintainer told not to simplify a guard back went looking for a guard that is not
# there. The invariant is real and still matters; it is just not this file's any more.
#
# It moved to `claude-plugins/evals/pr-description/`, which is where the only remaining expansion of
# an optional prefix lives, and it is oracled there in BOTH directions: a static count (every
# `TIMEOUT[@]` mention is either the guard's test or the expansion immediately after it, so a correct
# file has exactly twice as many as it has guards) plus a case that drives the model path
# behaviourally so the empty-array branch is actually executed. The bug it guards is worth keeping
# named: on bash before 4.4 -- `/bin/bash` on macOS is 3.2 -- the `[@]` expansion of an EMPTY array
# is an unbound variable under `set -u`, and the empty branch is precisely "no gtimeout", the default
# macOS state. Measured before the guard existed: E5 died BEFORE its `>` redirect opened, the
# following `grep` read a file that was never written, and the case reported FAIL for a crash rather
# than for what it asserts.
#
# E4 AND E5 LIVED HERE AND WERE RELOCATED 2026-09-03 to claude-plugins,
# evals/pr-description/{run.sh,floor-tests.sh}. Two reasons, and the first was already recorded in
# the comment this tombstone replaces: they graded `/pr-description`, which THIS REPOSITORY DOES
# NOT OWN -- nothing under skills/ matches it, so a red here could mean a defect in a surface not
# in this tree and the case could not be repaired from inside this repo. A gate belongs in the tree
# that owns the surface it grades, the same altitude argument as borg_core/recon/cli.py owning the
# recon retirement gate rather than its zsh caller.
#
# The second reason is that they could not RUN. E4 required a stillpoint checkout plus a fetchable
# `origin/write-freeze-design` branch plus a specific manifest file; E5 required a troth checkout.
# Measured 2026-09-03: neither was present, both SKIPped, and `make eval-live` exited non-zero on
# the model floor with the whole model sweep absent. Both are now synthesized from `git init` there
# and PASS -- the substitution E5's old comment named as "the first thing to do when these cases
# move", deferred then because it could only be verified against the real `/pr-description`.
#
# SO THE MODEL MODE LEFT WITH THEM, AND ITS FLOOR HAD TO GO TOO. With no model case in this
# harness, `[ "$SKIP_MODEL" -eq 0 ] && [ "$MODEL_RAN" -eq 0 ]` would fire on every invocation that
# did not pass `--skip-model` -- a floor NOTHING can satisfy, which AC6 decision (3) forbids in as
# many words: "a floor nothing can satisfy is a permanent red, not a gate". The mode floor now
# lives in the harness that owns the model cases.
#
# `--skip-model` IS STILL ACCEPTED, and inertly so. The Makefile's `EVAL_ARGS` default passes
# `--skip-model --skip-network` to every harness the glob selects, and the unknown-flag arm above
# exits 2, so removing the flag would break `make eval` for a harness that no longer has anything
# to skip. Accepted-and-inert is the honest form; the flag stays meaningful in the relocated
# harness, so the vocabulary is still shared across both.

echo
# SKIPs are reported but never gate. A case whose inputs are absent on this machine has not failed;
# printing the count keeps that visible instead of letting a mostly-skipped run read as a pass.
echo "RESULT: $PASS pass, $FAIL fail, $SKIPPED skip"

# THE EXECUTION FLOORS — one GLOBAL, then one PER MODE. SKIPs still never gate: that part above is
# correct and stays, because an input that is absent on this machine is not a defect, which is why
# these conditions count the cases that EXECUTED instead of comparing $SKIPPED against a total. But
# a run in which nothing executed is a different and worse fact than a run in which cases ran and
# passed, and the old exit status could not tell them apart: on a machine with no authenticated `gh`
# and no second repository this printed "0 pass, 0 fail, 3 skip" and exited 0, so "verified nothing"
# was indistinguishable from "verified everything asked of it". Two halves, deliberately: something
# must have run, AND nothing that ran may have failed. E2a is what keeps the first half satisfiable
# everywhere instead of a standing red on a machine with no credentials, so if the global floor ever
# fires the thing to check is why E2a did not execute.
#
# AND THAT IS ALSO WHY THE GLOBAL FLOOR IS NOT SUFFICIENT ON ITS OWN. E2a always executes, so it
# satisfies PASS+FAIL>0 single-handed and the global floor cannot distinguish the offline mode from
# a live sweep that found no inputs — `make eval-live` on a machine with neither `gh` nor `claude`
# reported "1 pass, 0 fail, 4 skip" at rc 0 with the whole live sweep missing, and rc 0 is the only
# thing the plan's "on demand" gate and the Ship Definition's one required run actually read. The
# mode floors close that by treating the ABSENCE of a skip flag as a request: ask for the network
# sweep and none of it ran, and the run failed to do the thing it was asked to do. Ordered before
# the FAIL check so the more specific reason is the one that gets printed; either way the exit is
# non-zero. Per-mode, never per-case — see the counters' declaration for why that ceiling is where
# an honest claim stops.
if [ $((PASS + FAIL)) -eq 0 ]; then
    echo "every case skipped: nothing was verified" >&2
    exit 1
fi
if [ "$SKIP_NETWORK" -eq 0 ] && [ "$NETWORK_RAN" -eq 0 ]; then
    echo "the network sweep was requested but no network case executed" >&2
    exit 1
fi
[ "$FAIL" -eq 0 ]
