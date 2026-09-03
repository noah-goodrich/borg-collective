#!/usr/bin/env bats
# THE ORACLE FOR AC6'S FLOORS — EVERY ONE OF THEM, EACH IN A POSITIVE/NEGATIVE PAIR. Seven floors
# live across two artifacts at three altitudes:
#
#   Makefile `eval`   SELECTION     a glob that selects no harness is a FAILURE, not a no-op
#   Makefile `eval`   EVAL_ARGS     a value that would make the run verify nothing is REFUSED
#   evals/*/run.sh    GLOBAL        a run in which no case executed is a FAILURE
#   evals/*/run.sh    NETWORK MODE  the network sweep was asked for and none of it ran -> FAILURE
#   evals/*/run.sh    MODEL MODE    the model sweep was asked for and none of it ran -> FAILURE
#   evals/*/run.sh    E2a COUNT     `-k e2a` selecting fewer than the authored minimum -> FAILURE
#   evals/*/run.sh    E2a OUTCOME   collecting more tests than it executed as passes -> FAILURE
#
# Plus ONE guard in the same script that is not a floor and is oracled here for a stronger reason —
# it is the only invariant in this change whose failure mode is destructive rather than merely
# silent:
#
#   evals/*/run.sh    $REPO CHECKOUT  a $REPO that does not look like this checkout is REFUSED
#                                     BEFORE `rm -rf "$OUT"`, so an overridden or mis-derived
#                                     $REPO cannot aim that deletion outside the repository
#
# Until this file existed NONE of them had an oracle, and the first draft of this file covered only
# the first and third. Measured rather than assumed, twice. With the selection and global hunks
# stripped from the working tree, `make lint`, `make test` and shellcheck all stayed green -- no CI
# job invokes an eval target, no other bats case so much as names `evals/` (the one hit under tests/
# is a comment), and shellcheck does not model exit status. And with the two MODE-floor blocks
# deleted, `bats tests/*.bats` was 778/778 and every other gate green, while the harness invoked in
# the `make eval-live` shape with `gh` and `claude` hidden printed "RESULT: 1 pass, 0 fail, 4 skip"
# and exited ZERO -- the literal defect the mode floors were added to prevent, with nothing in the
# repository able to notice their removal.
#
# THAT IS THE PRINCIPLE THIS FILE IS FOR, AND IT RECURSES ON ITS OWN FIX: a floor with no oracle is
# the defect class the floor exists to prevent, one level up. PROJECT_PLAN.md asserted both the
# selection and the execution floors were armed while nothing could have contradicted it; the
# half-covered version of this file then asserted the general principle while naming oracles for
# half the floors. So a new floor lands WITH its pair, or it lands unobserved.
#
# TWELVE CASES. Each floor is checked in the firing direction AND in the direction that proves it
# discriminates, because a floor asserted only firing passes just as well for an artifact that
# always fails:
#    1  selection FIRES      -- no `evals/` at all, plus the subtler shape the recipe argues about:
#                               an `evals/` that EXISTS but holds no run.sh
#    2  selection HOLDS      -- one trivial harness makes the very same target exit 0
#    3  EVAL_ARGS validated  -- `--help` and a metacharacter word are refused BY NAME and the
#                               harness never runs; an explicit offline value is admitted and does
#    4  global FIRES         -- over the GLOB, every harness in the tree, inputs all hidden
#    5  global HOLDS         -- the same offline invocation, with an interpreter it can use
#    6  network mode FIRES   -- `--skip-model` only (so the sweep IS requested) with `gh` hidden
#    7  network mode HOLDS   -- the same invocation against a stub `gh` and one declared ref
#    8  model mode FIRES     -- `--skip-network` only with `claude` hidden
#    9  model mode HOLDS     -- the same invocation against a stub `claude` and a manifest-less repo
#   10  E2a count            -- a selection one short of the authored minimum fails naming the
#                               shortfall; the full count exits 0
#   11  E2a outcome          -- a full selection with one test collected-but-skipped fails naming
#                               it; the same sandbox without the marker exits 0
#   12  $REPO checkout guard -- a $REPO with no tracked root marker is refused BY NAME and a canary
#                               planted where `$OUT` would be SURVIVES; the same invocation against
#                               a $REPO that does carry the marker gets past the guard and deletes
#                               that canary
#
# WHY THE MODE FLOORS HAD NO ORACLE FOR AS LONG AS THEY DIDN'T. Every automated caller invokes the
# harness in OFFLINE mode (`--skip-model --skip-network`) -- that is what `make eval` forwards and
# what cases 4 and 5 must use -- so both per-mode conditions are false by construction in every
# gate and both `if` blocks are unreachable from a suite that only ever runs the offline shape.
# Cases 6-9 exist to invoke the other two modes, which nothing else in the tree does.
#
# HERMETIC BY CONSTRUCTION. No network, no real `gh`, no real `claude`, no writes outside
# BATS_TEST_TMPDIR, and never a mutation of the repository's own `evals/` tree or Makefile. Every
# case that executes a real harness redirects its evidence tree with the `BORG_EVAL_REPO` override
# instead of letting it `rm -rf` and recreate `evals/*/out` inside this checkout, and hands it a
# PATH built as an ALLOWLIST. Cases 1-3 copy the Makefile into a sandbox rather than running the
# repository's own, so the selection under test is the sandbox's (empty, or one fixture) and never
# this tree's real harness set.
#
# ── EVERY `[[ ... ]]` HERE ENDS IN `|| false`, AND THAT IS NOT STYLE ─────────────────────────────
# macOS ships GNU bash 3.2, which does NOT apply `set -e` to a failing double-bracket conditional
# that is not the final command of the function. bash 5 does. Reproduced both ways with a one-liner
# that runs `set -e`, then a false double-bracket test, then `echo REACHED`: bash 3.2 prints REACHED
# and exits 0, ubuntu's bash 5.3 prints nothing and exits 1. Appending `|| false` makes both exit 1,
# and grepping this file for a double-bracket line without that suffix must find nothing.
# Written bare, as this file's first draft wrote all ten of them, eight did not gate on the machine
# of record. Not a theory: with a `make` shim on PATH that printed `boom` and exited 1, case 1 still
# PASSED -- satisfied by any `make` that merely fails, never checking that the floor's reason reached
# the output. With a shim that exited 0 printing only `-- --skip-network`, case 2 still PASSED,
# having selected nothing and run nothing, which is exactly what its own comment says must not
# happen. The suite gated only on CI's ubuntu `test` job and was inert every time it was run
# locally -- the direction in which nobody notices.
#
# THE SIBLING COUNT IN THIS PARAGRAPH WAS WRONG TWICE AND IS NOW MEASURED. There are 39 SIBLINGS,
# not 40: 40 is every `tests/*.bats` file INCLUDING this one. And the convention was not universal
# among them -- `tests/link_parity_harness.bats` carried five bare double-bracket assertions, four
# of them non-final and therefore inert on the machine of record, which is this paragraph's own
# argument found in the wild rather than hypothesised. That file was fixed in the same round as this
# note, so the claim is phrased to be true either way: every sibling that makes a double-bracket
# assertion suffixes it with `|| false` (223 such lines in cli_contract.bats alone), and this file
# is the fortieth to do so without exception. Re-measure, never re-copy this claim, and note the
# check is scoped to THIS file, where the expected output is genuinely empty:
# `grep -n '^[[:space:]]*\[\[' tests/eval_floor.bats | grep -v '|| false'`.
# Run tree-wide it returns a handful of non-assertion forms -- `if` conditionals, `sed` character
# classes, generated stub bodies carrying their own `&&` or `|| continue`, and one `\`-continued
# assertion in `cli_contract.bats` whose action sits on the following line -- so a tree-wide grep is
# a starting point for a reader, not a passing condition.
#
# `[ ... ]` needs nothing and must not be "fixed" to match: a single-bracket test is an ordinary
# builtin command and 3.2 honours errexit for it (measured the same way, exit 1, no REACHED).
#
# ── AND EVERY HARNESS IS INVOKED AS `bash "$harness"`, NEVER `"$harness"` ────────────────────────
# That is how the target under test runs it: the recipe selects with `[ -e "$r" ]` and runs
# `bash "$r"`, so it needs no exec bit. Executing the path directly imposes a requirement `make
# eval` does not have, and a working-but-non-executable harness would then turn these cases red
# under a message blaming the floor.
#
# ── THE CI `test` JOB IS THE ONLY GATE THAT COLLECTS THIS FILE, AND IT HAD TO BE GIVEN A PREMISE ──
# `bats tests/*.bats` picks this file up by existing, so no new CI job is added: `make eval` is not,
# and must not become, a sixth job -- the harness's one always-runnable case is a pytest selection
# the `python` job already collects. But that job installed `zsh jq fzf` and nothing else, and SEVEN
# of the twelve cases below cannot run without an importable pytest. They used to `skip` for it, and
# bats prints `ok` for a skip: the one lane that gates these floors reported 11/11 GREEN having
# executed FOUR cases, so deleting either mode-floor block, the count floor or the outcome floor
# turned nothing red in CI. Reproduced in a CI-shaped sandbox (`rsync -a --exclude .venv --exclude
# .git` into a temp dir, then bats from there): `1..11`, `ok 1..4`, then `ok 5 ... # skip no python3
# with an importable pytest` for 5 through 11.
#
# BOTH HALVES OF THE FIX ARE REQUIRED AND NEITHER CLOSES IT ALONE. The `test` job gained a
# `setup-python` + `pip install --group dev` STEP -- a step in an existing job, which the build order
# allows where a sixth job would not -- and `_python_with_pytest` now FAILS instead of skipping, so a
# missing premise cannot read as a held floor on ANY machine, CI or otherwise. That absence and
# success printed the same thing is the defect class this whole file exists to end; it had recursed
# one level up, into the artifact built to end it.

load test_helper/setup

setup() {
    setup_temp_dirs
}

# ── the offline mode's flags ──────────────────────────────────────────────────────────────────────
# THE HARNESS PARTITIONS ITS CASES BY MODE, AND DROPPING A FLAG IS A REQUEST FOR THAT MODE'S SWEEP:
# omit `--skip-network` and a run that executed no network case fails, by design, because it was
# asked for a sweep it did not perform. So cases 4 and 5 must ask for the OFFLINE mode -- exactly
# what `make eval` forwards -- or case 5 would go red on a mode floor rather than on the
# zero-execution floor it means to discriminate. Cases 6-9 drop exactly one flag each and are the
# oracles for the two floors that go with it. The duplication with the Makefile's EVAL_ARGS default
# is closed rather than left to drift: case 2 asserts every member of this array appears in the line
# the recipe echoes, so a default that loses a flag turns this file red instead of quietly making
# cases 4 and 5 test a mode nobody runs.
_EVAL_OFFLINE_ARGS=(--skip-model --skip-network)

# ── the two hidden-input sets ─────────────────────────────────────────────────────────────────────
# Split, not one list, because the cases need different halves hidden. The NETWORK set is hidden in
# every case: `gh` reaches GitHub, `borg recon` reaches every adapter on the machine, `claude` spends
# money on a headless model run, and `gtimeout`/`timeout` only ever wrap those. Hiding them is what
# makes this suite hermetic while still running the real harness. The OFFLINE set is hidden wherever
# the case's subject is a run that can execute nothing -- it is precisely the input whose absence
# leaves the harness with nothing to do.
#
# A CASE THAT NEEDS ONE OF THESE REACHABLE STUBS IT, AND THE STUB LIVES SOMEWHERE ELSE (see
# _stub_dir). These arrays stay the whole truth about what the ALLOWLIST hides, so `_refute_resolvable`
# can keep being called with the entire set even by the cases that stub something.
_EVAL_HIDDEN_NETWORK=(gh borg claude gtimeout timeout)
_EVAL_HIDDEN_OFFLINE=(python python3)

# The infrastructure a harness needs whatever it is evaluating: an interpreter for its shebang, the
# path arithmetic in its prologue, the file plumbing under `$OUT`, and `git` for the fixture repos
# the deterministic pytest case builds.
#
# AN ALLOWLIST, NEVER A SUBTRACTION FROM PATH. `PATH=/usr/bin:/bin` is the tempting version and it
# is wrong: it assumes `gh` does not live in `/usr/bin`, which is true on macOS (Homebrew puts it in
# `/opt/homebrew/bin`) and FALSE on ubuntu-latest, which preinstalls `gh` at `/usr/bin/gh` -- and
# CI's `test` job runs this suite on ubuntu. That is CLAUDE.md's "a test's PREMISE can depend on the
# dev platform" lesson, third instance, recorded there as a bats case that hid `gh` exactly that way
# and passed on the one platform where its premise held. So the set is named POSITIVELY, and each
# name is resolved with `command -v` rather than assumed to sit in any particular directory.
#
# `bash` IS IN THE LIST FOR A REASON. The harness's `#!/usr/bin/env bash` shebang makes `env` search
# the PATH UNDER TEST for its interpreter; omit `bash` and the case fails with "no such file or
# directory" before a line of the harness runs, which satisfies "exits non-zero" for a reason that
# has nothing whatsoever to do with the floor.
_EVAL_ALLOWED_BINS=(bash sh env dirname basename mkdir rm cp mv ln cat grep sed awk sort head tail tr git)

# The subset whose ABSENCE would silently change what the execution-floor cases measure, so it is
# fatal rather than best-effort. Measured, and worth stating because it is not hypothetical: with
# `grep` missing from the allowlist the harness's `E2A_SELECTED=$(grep -c '::' ...)` yields the empty
# string, the `[ "$E2A_SELECTED" -lt "$E2A_MIN" ]` comparison errors out instead of taking either
# branch, and the case reports `PASS E2a contract: pytest green ( tests)` at rc 0 -- case 5 green
# over a count floor that never ran. The rest of `_EVAL_ALLOWED_BINS` is deliberately a superset of
# what today's single harness calls, so a future harness reaching for `awk` or `sort` finds it there.
_EVAL_REQUIRED_BINS=(bash dirname mkdir rm grep git)

# Extra names may be appended by a caller: E2's inline reader shells BARE `python3` (it imports only
# stdlib, so any stock interpreter runs it), which the offline hidden set removes on purpose --
# case 7 is the one case that needs it back, because it is the one case in which a network case must
# actually run to completion.
_allowlist_bin() {
    local dir="${BATS_TEST_TMPDIR}/allow-bin" name src
    mkdir -p "$dir"
    for name in "${_EVAL_ALLOWED_BINS[@]}" "$@"; do
        src="$(command -v "$name" 2>/dev/null || true)"
        # ONLY AN ABSOLUTE, EXECUTABLE PATH IS LINKABLE. `command -v` also answers with a bare word
        # for a builtin, function or alias, and linking that word into the allowlist under its own
        # name makes a symlink loop that reports "command not found" -- measured while writing this
        # file, where a shell whose profile defined `grep` as a function answered `grep` for `grep`
        # and produced exactly the degraded PASS described above.
        case "$src" in
            /*)
                if [ -x "$src" ]; then
                    ln -sf "$src" "$dir/$name"
                fi
                ;;
        esac
    done
    for name in "${_EVAL_REQUIRED_BINS[@]}"; do
        if [ ! -x "$dir/$name" ]; then
            echo "premise broken: no absolute, executable $name to put on the allowlist" >&2
            return 1
        fi
    done
    printf '%s\n' "$dir"
}

# A directory holding NOTHING but the stubs one case planted, kept SEPARATE from the allowlist and
# ordered ahead of it on the PATH the harness gets. Folding a stub into the allowlist directory
# instead would force every stubbing case to refute a hand-written SUBSET of the hidden sets, and a
# name added to `_EVAL_HIDDEN_NETWORK` later would then be refuted by the cases that hide it and
# silently not by the cases that stub something else. Two directories keep the allowlist's guarantee
# whole: `_refute_resolvable` still runs over the ENTIRE hidden set against the allowlist dir, and
# `_assert_stubbed` proves over the composite PATH that the reachable copy is the planted one.
_stub_dir() {
    local dir="${BATS_TEST_TMPDIR}/stub-bin"
    mkdir -p "$dir"
    printf '%s\n' "$dir"
}

# Write one stub, body on stdin. Every body starts `#!/bin/sh` -- an ABSOLUTE, universal interpreter
# path, so a stub can never depend on the PATH under test to find its own interpreter. That is the
# `#!/usr/bin/env bash` trap the allowlist's `bash` entry documents, one level in: a stub whose
# shebang needed a PATH search would die at 127 and be read as the stubbed tool failing.
_stub_bin() {
    local dir="$1" name="$2"
    cat > "$dir/$name"
    chmod +x "$dir/$name"
}

# Assert the hidden set really is unreachable on the PATH we are about to hand the harness. The
# premise of every execution-floor case is "these inputs are absent"; a suite that assumes it
# instead of checking it can be silently repaired by an allowlist entry someone adds later, and
# case 4 would then pass for a harness whose floor had been deleted. Resolved in a SUBSHELL so the
# assignment cannot leak into the test's own PATH.
_refute_resolvable() {
    local dir="$1" name
    shift
    for name in "$@"; do
        if ( PATH="$dir"; command -v "$name" >/dev/null 2>&1 ); then
            echo "premise broken: $name is still resolvable on the allowlist PATH" >&2
            return 1
        fi
    done
}

# `_refute_resolvable`'s mirror, and the reason a stubbing case is still hermetic. Absence is proved
# against the allowlist directory; PROVENANCE has to be proved against the COMPOSITE PATH, because
# that is the only place the stub directory and the allowlist are ordered against each other. A
# stub directory that failed to be created, or a stub written under the wrong name, would otherwise
# leave the case asserting a PASS produced by whatever `gh` the runner happens to ship.
_assert_stubbed() {
    local search="$1" dir="$2" name resolved
    shift 2
    for name in "$@"; do
        resolved="$( PATH="$search"; command -v "$name" 2>/dev/null || true )"
        if [ "$resolved" != "$dir/$name" ]; then
            echo "premise broken: $name resolved to '${resolved:-nothing}', not the stub $dir/$name" >&2
            return 1
        fi
    done
}

# A sandbox that satisfies the harness's `$REPO` contract without BEING this checkout. Every root
# entry is symlinked in EXCEPT `evals/`, which is left as a real (initially absent) directory --
# that is the whole point. `$OUT` is derived as `$REPO/evals/<harness>/out` and the harness
# `rm -rf`s it on every run to keep a stale artifact from reading as a fresh PASS, so a symlinked
# `evals/` would aim that deletion straight back at this tree. `borg.zsh` comes along because the
# harness's guard refuses to run against a directory that does not look like the checkout, and
# `borg_core/` plus `pyproject.toml` come along because the deterministic case runs pytest from
# `$REPO` and resolves both relative to it.
#
# DOTFILES ARE EXCLUDED BY THE GLOB, AND THAT IS LOAD-BEARING RATHER THAN INCIDENTAL, TWICE OVER.
# The harness resolves its interpreter down a three-rung ladder -- `$BORG_EVAL_PYTHON`, then
# `$REPO/.venv/bin/python`, then bare `python3` -- so a sandbox carrying `.venv` would hand case 4 a
# working pytest through the middle rung, the deterministic case would execute, and the case would
# assert nothing. Case 4 checks that the rung is absent rather than trusting this comment. It also
# leaves `.borg/` out, which is where `programs.discover` looks for manifests: an empty sweep is the
# right default for every case but case 7, which plants exactly one ref of its own.
_eval_sandbox_repo() {
    local sandbox="${BATS_TEST_TMPDIR}/eval-repo" entry name
    mkdir -p "$sandbox"
    for entry in "$BORG_HOME"/*; do
        name="${entry##*/}"
        if [ "$name" = "evals" ]; then
            continue
        fi
        ln -sfn "$entry" "$sandbox/$name"
    done
    printf '%s\n' "$sandbox"
}

# ONE declared ref in a sandbox `$REPO`, so E2 has something to resolve. Authored here rather than
# copied from this repository's own `.borg/programs/`: the count is then a fact of this file, which
# is what lets case 7 assert `checked=1` exactly instead of a digit that drifts whenever a real
# manifest gains a row. The shape is the minimum `programs.validate` accepts -- a `rows` list whose
# every entry carries a unique `ref` and an `order` -- and the ref names a repository that cannot
# exist, so a real `gh` reaching this fixture would report it UNRESOLVED and turn case 7 red rather
# than green on a live read.
_declare_one_ref() {
    mkdir -p "$1/.borg/programs"
    printf '%s\n' '{"rows": [{"order": "1", "ref": "borg-tests/nonexistent#1"}]}' \
        > "$1/.borg/programs/one-ref.json"
}

# A sandbox `$REPO` whose only content is a pytest file with an AUTHORED number of `e2a` tests, some
# of which may be collected-but-skipped. It is what gives cases 10 and 11 a selection they control:
# the real `borg_core/manifest/test_shell.py` is the contract under evaluation and must never be
# edited by a test, and pointing `-k e2a` at a tree with too few tests is the only way to reach the
# count floor at all.
#
# NO `pyproject.toml`, DELIBERATELY. The selection is by explicit path, so pytest needs no ini file;
# symlinking the real one instead would drag this sandbox's collection under `testpaths`, `addopts`
# and a marker allow-list that belong to the repository and not to a four-line fixture.
_shortfall_repo() {
    local dir="${BATS_TEST_TMPDIR}/short/$1" target="$2" total="$3" skipped="$4" i=1
    rm -rf "$dir"
    mkdir -p "$dir/${target%/*}"
    ln -sfn "$BORG_HOME/borg.zsh" "$dir/borg.zsh"
    printf 'import pytest\n\n\n' > "$dir/$target"
    while [ "$i" -le "$total" ]; do
        if [ "$i" -gt $((total - skipped)) ]; then
            printf '@pytest.mark.skip(reason="collected, deliberately not executed")\n' >> "$dir/$target"
        fi
        printf 'def test_e2a_stub_%s():\n    assert True\n\n\n' "$i" >> "$dir/$target"
        i=$((i + 1))
    done
    printf '%s\n' "$dir"
}

# The count floor's own threshold, READ OUT OF THE HARNESS rather than restated here. A literal 15
# in this file would keep passing after the harness raised its minimum, against a shortfall sandbox
# that no longer falls short -- the floor's oracle drifting off the floor. Refused below 2 because
# `total - 1` has to remain a NON-EMPTY selection. An empty one is a DIFFERENT fact, and the count
# floor is what names it -- `selected 0 of N authored` -- before the run phase is ever invoked, so
# pytest never produces an rc for it at all. The gap this floor exists for is "some but not enough",
# and a minimum of 1 would make the shortfall sandbox empty and quietly move the case off that gap.
_e2a_min() {
    local min
    min="$(sed -n 's/^E2A_MIN=\([0-9][0-9]*\)$/\1/p' "$1" | head -1)"
    if [ -z "$min" ] || [ "$min" -lt 2 ]; then
        echo "premise broken: no 'E2A_MIN=<n>' with n>=2 in $1" >&2
        return 1
    fi
    printf '%s\n' "$min"
}

# The path the count floor's selection is aimed at, read out of the harness for the same reason as
# the threshold: a harness that moves its pytest target would otherwise leave the shortfall sandbox
# planting a file nowhere near the `-k e2a` selection, pytest would collect zero, and the case would
# be asserting the empty-selection arm while claiming to test the count.
_e2a_target() {
    local target
    target="$(sed -n 's|.*-m pytest \([^ ][^ ]*\) -k e2a.*|\1|p' "$1" | head -1)"
    case "$target" in
        */*.py) printf '%s\n' "$target" ;;
        *)
            echo "premise broken: no '-m pytest <path> -k e2a' selection in $1" >&2
            return 1
            ;;
    esac
}

# The path the harness `rm -rf`s, read out of the harness for the same reason as the threshold and
# the target above. Case 12 plants a canary exactly where the deletion is aimed; a literal
# `evals/s4-k3/out` written here instead would keep passing after a harness moved its evidence tree,
# with the canary sitting somewhere nothing deletes -- so the negative half would be asserting that
# an unrelated file survived, which is a fact about nothing.
#
# MATCHED ON THE ASSIGNMENT, NOT ON THE `rm` LINE, WHICH NAMES A VARIABLE. The `$REPO/` prefix is
# part of the pattern rather than stripped afterwards, and that is the load-bearing half: a harness
# whose `$OUT` sat somewhere OTHER than under `$REPO` would not be protected by the checkout guard
# at all, so there would be nothing here to oracle and this helper must refuse rather than hand case
# 12 a path the guard does not stand in front of.
_eval_out_rel() {
    local rel
    rel="$(sed -n 's|^OUT="\$REPO/\([^"]*\)"$|\1|p' "$1" | head -1)"
    if [ -z "$rel" ]; then
        echo "premise broken: no 'OUT=\$REPO/<relative path>' assignment in $1" >&2
        return 1
    fi
    printf '%s\n' "$rel"
}

# The interpreter every case that must EXECUTE something needs: one that can `import pytest`. The
# harness's always-runnable case is a pytest selection and it guards on the import rather than on the
# interpreter -- a python3 without pytest SKIPs -- so without this the mode floors would be asserted
# over a missing dev dependency, and worse, the GLOBAL floor would fire first and print its reason
# instead of the mode reason the case is checking. Preference order is deliberate: the project's own
# `.venv` first, since CLAUDE.md records that this toolchain is NOT on the ambient PATH, then any
# python3 that happens to carry pytest.
#
# `BORG_EVAL_PYTHON` IS THE SEAM, and it has to be: the sandbox `$REPO` carries no `.venv` (the glob
# that builds it skips dotfiles), so the ladder's middle rung cannot fire there, and the bottom rung
# is bare `python3`, which the allowlist deliberately hides. The knob is the one rung these cases can
# reach -- which is also why it is the rung a CI checkout uses, where the `test` job's dev-group
# install puts pytest in the ambient interpreter and the third rung answers.
#
# ── ABSENCE IS A BROKEN PREMISE HERE, NOT A SKIP ─────────────────────────────────────────────────
# This used to hand each of the seven cases a `skip` with a reason, and that was the same defect one
# level up: bats prints `ok` for a skip, so "the oracle did not run" and "the floor holds" were the
# same line of TAP output. Measured on the only lane that collects this file -- 11 cases reported,
# four executed, and every floor the other seven observe deletable with nothing going red. `skip` is
# the right verdict for a case whose SUBJECT is absent (that is why the harness itself skips, and why
# case 9 is content that E4's second repository is missing); it is the wrong verdict for a case whose
# ORACLE is absent, which is what a missing pytest means here.
#
# WHAT THAT COSTS, DECIDED AND STATED RATHER THAN DISCOVERED: a contributor with no dev group
# installed now gets SEVEN RED CASES instead of seven skips, from a suite that has nothing to do with
# whatever they were changing. For an ordinary unit test that trade would be wrong -- red for a
# missing optional tool trains people to ignore red. It is right here for one reason: this file is a
# GATE on floors and nothing else, and a gate that yields to a missing dependency is precisely the
# thing this change exists to remove. The mitigation is that the reason is actionable and names the
# one command that fixes it, and that CI now installs it so the red is local-only and one command
# deep. NO CASE IS EXEMPTED: all seven observe floors whose deletion CI could not otherwise see, so
# exempting any one of them would leave exactly the hole the other six close. Case 12 needs no
# interpreter at all and never reaches this helper -- that is a property of where the checkout guard
# sits in the harness, not an exemption, and it is why that guard's oracle stays green on a bare
# checkout.
#
# CALL IT AS A PLAIN ASSIGNMENT -- `python="$(_python_with_pytest)"` -- AND NEVER `local python=$(...)`.
# bash discards a command substitution's exit status when it is an operand of `local`/`declare`, so
# the declare-and-assign form would swallow this failure and hand the case an empty interpreter path,
# which the harness would then treat as "not set" and fall back to a bare `python3` the allowlist
# hides. The plain form propagates: measured on bash 3.2, `set -e; x="$(f)"; echo REACHED` with a
# failing `f` prints nothing and exits 1. That is the same idiom `_allowlist_bin`, `_e2a_min` and
# `_e2a_target` are called with, which is why the `local` declarations in every case are separate
# from the assignments.
#
# THE LOUDNESS IS A HAND-MAINTAINED INVARIANT, AND THAT IS RECORDED RATHER THAN GATED. Reverting this
# helper's `return 1` to a `skip` would re-hide the removal of the `test` job's dev-group step, which
# is the other half of the same two-sided fix -- so this half has no oracle, and by the standard the
# rest of this file is held to that is worth naming out loud. It is not gated because the assertable
# rule and the real rule are different: a blanket "this file never calls `skip`" would gate it, but it
# would also forbid a future case from skipping for a reason that genuinely is an absent input rather
# than a missing toolchain, and codifying a rule that is wrong in cases nobody has written yet buys
# less than it costs. The narrow rule -- A MISSING DEV TOOLCHAIN MUST NOT SKIP -- is the one to keep,
# and it lives here, next to the helper that implements it, where a reader changing it will see it.
_python_with_pytest() {
    local candidate
    for candidate in "$BORG_HOME/.venv/bin/python" "$BORG_HOME/.venv/bin/python3" \
                     "$(command -v python3 2>/dev/null || true)"; do
        if [ -n "$candidate" ] && [ -x "$candidate" ] && "$candidate" -c 'import pytest' >/dev/null 2>&1; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    echo "premise broken: no interpreter with an importable pytest -- run 'pip install --group dev'" >&2
    return 1
}

# `run`-able wrapper for one harness invocation, in a FIXED argument order:
#
#   _run_harness <path> <repo> <python> <stillpoint> <troth> <harness> [flags...]
#
# Every override is positional and mandatory so a case cannot forget one. That is the point rather
# than tidiness: `BORG_EVAL_STILLPOINT` and `BORG_EVAL_TROTH` exported in the developer's own shell
# would otherwise hand a case the second repository whose ABSENCE is its premise, and an empty string
# is how the harness's `[ -n ... ]`/`[ -z ... ]` guards read "not set on this machine". Passing them
# empty is therefore an assertion, printed at every call site, that the case supplied its own inputs
# and inherited none. `BORG_EVAL_PYTHON` gets the same treatment: it is the ladder's FIRST rung, so
# an exported value on the machine of record is exactly the input the hiding cases are hiding.
#
# `bash "$harness"` and not `"$harness"`, for the reason in the header: that is the form the recipe
# uses, and it needs no exec bit.
_run_harness() {
    run env PATH="$1" BORG_EVAL_REPO="$2" BORG_EVAL_PYTHON="$3" \
        BORG_EVAL_STILLPOINT="$4" BORG_EVAL_TROTH="$5" PYTHONDONTWRITEBYTECODE=1 \
        bash "$6" "${@:7}"
}

# A sandbox holding nothing but a COPY of the repository's Makefile. A copy, because the recipe
# globs `evals/*/run.sh` relative to the CWD: the file has to be reachable from a directory that is
# not this checkout, and copying it is what keeps the real harness set out of the selection under
# test. Never a symlink -- `make` would run in the sandbox, but a symlinked Makefile is the same
# inode, so any accident that wrote to it would write to the tracked file.
_makefile_sandbox() {
    local dir="${BATS_TEST_TMPDIR}/mk/$1"
    mkdir -p "$dir"
    cp "$BORG_HOME/Makefile" "$dir/Makefile"
    printf '%s\n' "$dir"
}

# The minimum thing a harness is: it reports a RESULT line and exits 0.
#
# IT ALSO HONOURS `-h|--help` BY EXITING 0 BEFORE PRINTING A RESULT, WHICH IS NOT DECORATION. That
# is what the real harness's flag loop does, and it is the whole reason the recipe validates
# EVAL_ARGS: `make eval EVAL_ARGS=--help` used to report SUCCESS for a run that verified nothing.
# Delete the recipe's `-h|--help` rejection and this fixture is what makes case 3 go red instead of
# quietly agreeing -- a fixture that ignored the flag would print RESULT and exit 0 either way, so
# the case would pass whether or not the validator existed.
_fixture_harness() {
    local dir="$1/evals/x"
    mkdir -p "$dir"
    {
        printf '#!/usr/bin/env bash\n'
        printf 'while [ $# -gt 0 ]; do\n'
        printf '    case "$1" in\n'
        printf '        -h|--help) echo "usage: run.sh [--skip-model] [--skip-network]"; exit 0 ;;\n'
        printf '    esac\n'
        printf '    shift\n'
        printf 'done\n'
        printf 'echo "RESULT: 1 pass, 0 fail, 0 skip"\n'
    } > "$dir/run.sh"
    chmod +x "$dir/run.sh"
}

# `run`-able wrapper: the recipe's glob is relative to the CWD, so the case has to be IN the sandbox
# rather than pointing at it. `run` evaluates its argv inside a command substitution, so the `cd`
# cannot leak into the test. Trailing arguments are forwarded to `make` so a case can pass an
# EVAL_ARGS override -- which must be ONE argv word (`"EVAL_ARGS=--skip-model --skip-network"`), or
# make's getopt eats the second flag before any goal is built.
_make_eval() {
    local dir="$1"
    shift
    cd "$dir" || return 99
    make eval "$@"
}

# ── 1. the selection floor fires ─────────────────────────────────────────────────────────────────
# Both shapes, because they fail at different places in the recipe and only one of them is obvious.
# The recipe guards on `found`, a counter set inside the loop, precisely BECAUSE `[ -d evals ]`
# would pass the second shape: with no nullglob an unmatched glob expands to the literal pattern, so
# a bare `evals/` directory hands `evals/*/run.sh` to bash as a filename. The `[ -e "$r" ]` skip is
# what turns that into a zero selection, and `found` is what turns a zero selection into a failure.
@test "make eval: the selection floor fires when the glob selects no harness" {
    local sandbox
    sandbox="$(_makefile_sandbox no-evals)"
    run _make_eval "$sandbox"
    [ "$status" -ne 0 ]
    [[ "$output" == *"nothing was selected"* ]] || false

    sandbox="$(_makefile_sandbox bare-evals)"
    mkdir -p "$sandbox/evals"
    run _make_eval "$sandbox"
    [ "$status" -ne 0 ]
    [[ "$output" == *"nothing was selected"* ]] || false
    # The literal pattern must never have reached bash as a filename -- that is the failure mode the
    # `found` counter replaced, and it announces itself in bash's own words.
    [[ "$output" != *"No such file or directory"* ]] || false
}

# ── 2. the selection floor discriminates ─────────────────────────────────────────────────────────
# The negative for case 1. Without it, case 1 is satisfied by a recipe that fails unconditionally,
# which is the cheapest possible way to "arm a floor" and no way at all to run an eval.
@test "make eval: one selected harness that passes exits zero" {
    local sandbox flag
    sandbox="$(_makefile_sandbox one-harness)"
    _fixture_harness "$sandbox"

    run _make_eval "$sandbox"
    [ "$status" -eq 0 ]
    # SELECTED (the recipe echoes each harness it is about to run) and then actually RAN. Asserting
    # only the exit status would also pass for a target that selected the harness and skipped it.
    [[ "$output" == *"evals/x/run.sh"* ]] || false
    [[ "$output" == *"RESULT: 1 pass"* ]] || false
    [[ "$output" != *"nothing was selected"* ]] || false
    # `make eval` IS THE OFFLINE ONE, and the echoed line is where EVAL_ARGS becomes observable.
    # This is also the join that keeps _EVAL_OFFLINE_ARGS honest: cases 4 and 5 invoke the harness
    # with these flags because that is what this target forwards, so if the default ever drops one,
    # the drift surfaces here instead of silently redirecting those two cases at a mode nobody runs.
    for flag in "${_EVAL_OFFLINE_ARGS[@]}"; do
        [[ "$output" == *"$flag"* ]] || false
    done
}

# ── 3. the EVAL_ARGS validator has an oracle, in both directions ─────────────────────────────────
# THE OTHER MAKEFILE FLOOR, AND IT GUARDS THE FRONT DOOR THE SELECTION FLOOR DOES NOT COVER. A
# documented extension point must not also be a channel for a green run that ran nothing, and
# EVAL_ARGS was exactly that twice: `--help` reaches the harness's own flag loop, which prints usage
# and exits 0 before a single counter increments or any execution floor runs; and a word carrying a
# shell metacharacter used to terminate `bash "$r" ...` mid-recipe, detaching the harness's exit
# status from `|| failed=1` so `failed` reported on whatever ran last.
#
# THE FIXTURE HARNESS IS PRESENT FOR BOTH HALVES ON PURPOSE. The refusals must be shown to happen
# WITHOUT the harness running -- so the absence of its RESULT line is the assertion that the
# validator, and not the harness, is what refused -- and the admission must be shown to end in a
# harness that actually ran. One sandbox, one fixture, three invocations.
@test "make eval: EVAL_ARGS is refused by name when it would verify nothing, and admitted when it would not" {
    local sandbox
    sandbox="$(_makefile_sandbox eval-args)"
    _fixture_harness "$sandbox"

    run _make_eval "$sandbox" EVAL_ARGS=--help
    [ "$status" -ne 0 ]
    [[ "$output" == *"refusing EVAL_ARGS"* ]] || false
    [[ "$output" == *"--help"* ]] || false
    # NAMED, not merely refused: the reason has to say what --help does, or a reader of a red gate
    # learns only that their extension point was rejected.
    [[ "$output" == *"before its counters and floors run"* ]] || false
    # AND THE HARNESS NEVER RAN. This is the assertion that discriminates the validator from the
    # harness: the fixture honours -h/--help by exiting 0, so if the rejection were deleted the run
    # would be GREEN and silent, which is the whole defect.
    [[ "$output" != *"RESULT:"* ]] || false
    [[ "$output" != *"usage: run.sh"* ]] || false

    # The second rejection, which has its own reason and its own failure mode.
    run _make_eval "$sandbox" "EVAL_ARGS=--bogus; true"
    [ "$status" -ne 0 ]
    [[ "$output" == *"refusing EVAL_ARGS"* ]] || false
    [[ "$output" == *"contains a shell metacharacter"* ]] || false
    [[ "$output" != *"RESULT:"* ]] || false

    # THE NEGATIVE FOR BOTH, and distinct from case 2: case 2 exercises the DEFAULT value, this
    # exercises an EXPLICIT one, which is the only shape that reaches the validator's loop with
    # something a user typed. Without it the validator gets credit for refusing everything.
    run _make_eval "$sandbox" "EVAL_ARGS=${_EVAL_OFFLINE_ARGS[*]}"
    [ "$status" -eq 0 ]
    [[ "$output" != *"refusing EVAL_ARGS"* ]] || false
    [[ "$output" == *"RESULT: 1 pass"* ]] || false
}

# ── 4. the global execution floor fires ──────────────────────────────────────────────────────────
# OVER THE GLOB, NOT AGAINST `s4-k3` BY NAME, and that is the case rather than an implementation
# detail of it: a harness that forgets to self-police turns this red THE DAY IT LANDS, which is the
# only mechanism that makes "every harness owns its execution floor" a property of the tree instead
# of a property of the one harness someone remembered to test. Naming the file would make the case
# exactly as narrow as the bug it guards against.
#
# Hidden inputs, not a hidden harness: the invocation is the real script with the real offline
# flags, and the only thing removed is every optional input it probes for. What must come back is a
# non-zero exit, because "0 pass, 0 fail, N skip" is a report that nothing was verified, and the
# exit status that used to accompany it was 0 -- indistinguishable from "verified everything asked
# of it".
@test "evals/*/run.sh: the execution floor fires when every optional input is absent" {
    local allow sandbox harness harnesses=0
    allow="$(_allowlist_bin)"
    sandbox="$(_eval_sandbox_repo)"
    _refute_resolvable "$allow" "${_EVAL_HIDDEN_NETWORK[@]}" "${_EVAL_HIDDEN_OFFLINE[@]}"
    # The interpreter ladder's middle rung, asserted rather than assumed -- see _eval_sandbox_repo.
    [ ! -e "$sandbox/.venv" ]

    for harness in "$BORG_HOME"/evals/*/run.sh; do
        if [ ! -e "$harness" ]; then
            continue
        fi
        harnesses=$((harnesses + 1))
        _run_harness "$allow" "$sandbox" "" "" "" "$harness" "${_EVAL_OFFLINE_ARGS[@]}"
        [ "$status" -ne 0 ]
        # ANTI-VACUITY, and the reason it is not the wording of the floor's own message: that
        # wording is per-harness, while "the harness reached its cases at all" is the tree's shared
        # PASS/FAIL/SKIP vocabulary. A prologue that died -- a mis-set BORG_EVAL_REPO tripping the
        # checkout guard, say -- also exits non-zero, prints no case line, and would satisfy the
        # assertion above for a reason that has nothing to do with the floor. Case 5 is the other
        # half of this guard and a stronger one, but it needs an importable pytest and now FAILS
        # rather than skips without one; this case hides every interpreter ON PURPOSE, so it is the
        # half that still EXECUTES on a bare checkout and the reason that assertion earns its keep.
        [[ "$output" == *"SKIP"* ]] || false
    done

    # The loop must have had a member. Over an empty glob every assertion above is vacuous, which is
    # this file's own subject matter turned on itself.
    [ "$harnesses" -gt 0 ]
}

# ── 5. the global execution floor discriminates ──────────────────────────────────────────────────
# The negative for case 4, and the case that keeps the floor from being "the harness always fails
# offline". The network set stays hidden, so this run is every bit as offline as case 4's; the only
# difference is an interpreter that can run the deterministic case. Exit 0 here says the floor
# counts EXECUTED cases and not skipped ones -- the distinction the harness draws in its own comment
# and the reason its floor is satisfiable on a machine with no credentials at all.
@test "evals/*/run.sh: the execution floor holds when the deterministic case can run" {
    local allow python sandbox harness harnesses=0
    python="$(_python_with_pytest)"
    allow="$(_allowlist_bin)"
    sandbox="$(_eval_sandbox_repo)"
    # Handing the harness an interpreter must not hand it the wire as well: the network set stays
    # unreachable, so a green result here cannot have come from a case that reached GitHub.
    _refute_resolvable "$allow" "${_EVAL_HIDDEN_NETWORK[@]}"

    for harness in "$BORG_HOME"/evals/*/run.sh; do
        if [ ! -e "$harness" ]; then
            continue
        fi
        harnesses=$((harnesses + 1))
        _run_harness "$allow" "$sandbox" "$python" "" "" "$harness" "${_EVAL_OFFLINE_ARGS[@]}"
        [ "$status" -eq 0 ]
        # A case really executed. Exit 0 alone would also be produced by a harness whose floor had
        # been deleted and which then skipped everything, so the PASS line is what distinguishes
        # "the deterministic case ran" from "nothing ran and nobody minded".
        [[ "$output" == *"PASS"* ]] || false
        [[ "$output" != *"nothing was verified"* ]] || false
    done

    [ "$harnesses" -gt 0 ]
}

# ── 6. the network-mode floor fires ──────────────────────────────────────────────────────────────
# `--skip-model` ALONE, which is the invocation that ASKS for the network sweep. Nothing else in the
# tree makes it: `make eval` forwards both flags and `make eval-live` forwards neither, so the
# condition `SKIP_NETWORK -eq 0 && NETWORK_RAN -eq 0` was unreachable from every gate in the
# repository until this case existed. What it caught when it was written, measured with `gh` and
# `claude` hidden: the live shape printed "1 pass, 0 fail, 4 skip" and exited ZERO.
#
# THE INTERPRETER IS SUPPLIED HERE EVEN THOUGH THE SUBJECT IS THE NETWORK. The global floor is
# ordered FIRST in the harness and exits on the spot, so without an executable E2a this case would
# be reading "nothing was verified" -- passing on the wrong floor's reason, which is the vacuity
# this whole file is about. That is also why the global reason is refuted below rather than merely
# left unmentioned.
@test "evals/*/run.sh: the network-mode floor fires when the sweep is asked for and gh is absent" {
    local allow python sandbox harness harnesses=0
    python="$(_python_with_pytest)"
    allow="$(_allowlist_bin)"
    sandbox="$(_eval_sandbox_repo)"
    _refute_resolvable "$allow" "${_EVAL_HIDDEN_NETWORK[@]}" "${_EVAL_HIDDEN_OFFLINE[@]}"

    for harness in "$BORG_HOME"/evals/*/run.sh; do
        if [ ! -e "$harness" ]; then
            continue
        fi
        harnesses=$((harnesses + 1))
        _run_harness "$allow" "$sandbox" "$python" "" "" "$harness" --skip-model
        [ "$status" -ne 0 ]
        [[ "$output" == *"the network sweep was requested but no network case executed"* ]] || false
        # The reason is the NETWORK floor's and not either neighbour's. Without these two the case
        # would pass for a harness that fired the global floor (nothing executed) or one that fired
        # both mode floors regardless of which flag was dropped -- and the second is what "the
        # harness always fails when a flag is dropped" looks like from the outside.
        [[ "$output" != *"nothing was verified"* ]] || false
        [[ "$output" != *"the model sweep was requested"* ]] || false
        # E2a executed, which is what makes the sentence above true rather than lucky.
        [[ "$output" == *"PASS"* ]] || false
    done

    [ "$harnesses" -gt 0 ]
}

# ── 7. the network-mode floor discriminates ──────────────────────────────────────────────────────
# The negative for case 6, and without it the floor gets credit for "the harness always fails when a
# flag is dropped". Same `--skip-model` invocation, same allowlist, one difference: a stub `gh` that
# answers the two calls E2 makes, plus one declared ref for it to resolve. Exit 0 here says the mode
# floor counts EXECUTED cases and not skipped ones -- the same property case 5 establishes for the
# global floor, which the mode floors do not inherit.
#
# `python3` IS BACK ON THE ALLOWLIST FOR THIS CASE ONLY. E2's ref reader is an inline heredoc fed to
# bare `python3` (stdlib only, so any interpreter runs it), and with it hidden the reader dies, E2
# reports unresolved rows, and the case would go red on a FAIL while the floor it is checking worked
# perfectly.
@test "evals/*/run.sh: the network-mode floor holds when a network case can execute" {
    local allow python sandbox stubs harness harnesses=0
    python="$(_python_with_pytest)"
    allow="$(_allowlist_bin python3)"
    sandbox="$(_eval_sandbox_repo)"
    stubs="$(_stub_dir)"
    _declare_one_ref "$sandbox"
    # THE ALLOWLIST STILL HIDES EVERYTHING, INCLUDING `gh`. The stub is reachable only through the
    # composite PATH below, which is what keeps this assertion identical to the hiding cases' and
    # makes the provenance check meaningful.
    _refute_resolvable "$allow" "${_EVAL_HIDDEN_NETWORK[@]}"

    # `gh auth status` and `gh pr view <n> --repo <r> --json state` are the only two invocations E2
    # makes, and it reads the RETURN CODE of the second rather than its body -- the JSON is printed
    # so a future assertion on `state` has something well-formed to read. Anything else exits 3 and
    # is named: an unexpected call must make the case RED, never quietly satisfy a floor.
    _stub_bin "$stubs" gh <<'STUB'
#!/bin/sh
if [ "${1-}" = auth ] && [ "${2-}" = status ]; then
    exit 0
fi
if [ "${1-}" = pr ] && [ "${2-}" = view ]; then
    printf '{"state":"OPEN"}\n'
    exit 0
fi
echo "unexpected gh invocation: $*" >&2
exit 3
STUB
    _assert_stubbed "$stubs:$allow" "$stubs" gh

    for harness in "$BORG_HOME"/evals/*/run.sh; do
        if [ ! -e "$harness" ]; then
            continue
        fi
        harnesses=$((harnesses + 1))
        _run_harness "$stubs:$allow" "$sandbox" "$python" "" "" "$harness" --skip-model
        [ "$status" -eq 0 ]
        [[ "$output" != *"the network sweep was requested"* ]] || false
        # A NETWORK CASE REALLY RAN, AND RAN THROUGH THE STUB. `checked=1` is the count of refs E2
        # resolved: the sandbox carries exactly the one ref _declare_one_ref planted, so this line
        # cannot be produced by a harness that took either `gh` skip branch, and `unresolved=[]`
        # cannot be produced by anything but a `gh` that answered. Exit 0 alone would also come from
        # a harness whose mode floor had been deleted and which then skipped the whole sweep.
        [[ "$output" == *"E2 refs: all resolve"* ]] || false
        [[ "$output" == *"checked=1 unresolved=[]"* ]] || false
        [[ "$output" != *"gh is not installed"* ]] || false
        [[ "$output" != *"gh is not authenticated"* ]] || false
        [[ "$output" != *"unexpected gh invocation"* ]] || false
    done

    [ "$harnesses" -gt 0 ]
}

# ── 8. the model-mode floor fires ────────────────────────────────────────────────────────────────
# `--skip-network` ALONE, the mirror of case 6 and unreachable from every gate for the same reason.
# The refutation of the NETWORK reason is the load-bearing half here: it is what proves the two
# floors are independently wired to their own flag, rather than one condition that fires whenever
# any flag is missing.
@test "evals/*/run.sh: the model-mode floor fires when the sweep is asked for and claude is absent" {
    local allow python sandbox harness harnesses=0
    python="$(_python_with_pytest)"
    allow="$(_allowlist_bin)"
    sandbox="$(_eval_sandbox_repo)"
    _refute_resolvable "$allow" "${_EVAL_HIDDEN_NETWORK[@]}" "${_EVAL_HIDDEN_OFFLINE[@]}"

    for harness in "$BORG_HOME"/evals/*/run.sh; do
        if [ ! -e "$harness" ]; then
            continue
        fi
        harnesses=$((harnesses + 1))
        _run_harness "$allow" "$sandbox" "$python" "" "" "$harness" --skip-network
        [ "$status" -ne 0 ]
        [[ "$output" == *"the model sweep was requested but no model case executed"* ]] || false
        [[ "$output" != *"nothing was verified"* ]] || false
        [[ "$output" != *"the network sweep was requested"* ]] || false
        # WHY nothing executed, named: the model cases skipped for the input this case hid, not for
        # some unrelated collapse that also happens to leave the counter at zero.
        [[ "$output" == *"claude is not on PATH"* ]] || false
        [[ "$output" == *"PASS"* ]] || false
    done

    [ "$harnesses" -gt 0 ]
}

# ── 9. the model-mode floor discriminates ────────────────────────────────────────────────────────
# The negative for case 8. It runs E5, the fallback case, whose entire input set is "a `claude` on
# PATH and a directory with no manifest in it" -- both of which a bats temp dir supplies exactly as
# well as a real repository does, which is E5's own comment's point.
#
# E4 IS NOT REACHABLE HERMETICALLY AND IS NOT FAKED. It hardcodes a worktree at
# `/tmp/s4-eval-stillpoint`, `git fetch`es a named branch from `origin`, and copies a specific
# manifest out of the second repository; driving it would mean writing outside BATS_TEST_TMPDIR at a
# fixed path two concurrent runs would collide on. It skips here for the input it genuinely lacks,
# which is the correct behaviour and is asserted. The floor is PER MODE and not per case -- the
# harness's counters say so in their own declaration -- so one executed model case is exactly what
# satisfies it, and E5 is that case.
#
# `gtimeout` IS DELIBERATELY NOT STUBBED, AND THAT IS THIS CASE'S SECOND SUBJECT. The harness builds
# `TIMEOUT=()` when no `gtimeout` exists, and bash before 4.4 -- the 3.2 that macOS ships, the machine
# of record -- treats an empty array expansion under `set -u` as an unbound variable and kills the
# subshell. Expanded bare, E5 died with `TIMEOUT[@]: unbound variable` before its redirect opened, so
# the following grep read a missing file and the case reported FAIL for a reason unrelated to what it
# asserts. The harness now expands the guarded `${TIMEOUT[@]+"${TIMEOUT[@]}"}` form, and leaving
# `gtimeout` absent is what makes THIS case execute the empty branch that used to crash: revert either
# expansion site to the bare form and this case goes red on bash 3.2.
#
# An earlier draft stubbed `gtimeout` to force the POPULATED branch, on the reasoning that it made the
# case deterministic rather than bash-version-dependent. It did -- and it also meant the branch that
# actually crashed was executed by nothing in the tree, so the guard could be "simplified" back with
# all twelve cases green. That stub's own comment said to delete it once the harness stopped expanding
# an unguarded empty array. The harness stopped; this is the deletion.
#
# This oracle only bites where the bug exists, i.e. bash < 4.4, so it guards the developer's machine
# and the local `bats tests/*.bats` run, NOT the ubuntu lane, where the bare form is legal. Case 12b
# carries the platform-independent half as a static assertion for exactly that reason; neither
# replaces the other.
@test "evals/*/run.sh: the model-mode floor holds when a model case can execute" {
    local allow python sandbox stubs troth harness harnesses=0
    python="$(_python_with_pytest)"
    allow="$(_allowlist_bin)"
    sandbox="$(_eval_sandbox_repo)"
    stubs="$(_stub_dir)"
    troth="${BATS_TEST_TMPDIR}/manifest-less-repo"
    mkdir -p "$troth"
    _refute_resolvable "$allow" "${_EVAL_HIDDEN_NETWORK[@]}" "${_EVAL_HIDDEN_OFFLINE[@]}"

    # E5 greps its stdout for the fallback sentence, so that sentence is the whole stub. Matched on
    # the ARGV the harness passes rather than answering anything: a stub that replied to every
    # invocation would keep this case green after a change that stopped asking for /pr-description.
    _stub_bin "$stubs" claude <<'STUB'
#!/bin/sh
case "$*" in
    *"/pr-description"*) echo "No manifest declared." ;;
    *) echo "unexpected claude invocation: $*" >&2; exit 3 ;;
esac
STUB
    # NO `gtimeout` STUB, and none is coming -- see this case's header. Its absence is what drives the
    # harness's empty-array branch, which is the branch that crashed on bash 3.2. Refuting it here
    # rather than assuming it: `gtimeout` is on the hidden list, so a runner that happens to carry one
    # cannot silently move this case onto the populated branch and take the coverage away again.
    _refute_resolvable "$stubs:$allow" gtimeout timeout
    _assert_stubbed "$stubs:$allow" "$stubs" claude

    for harness in "$BORG_HOME"/evals/*/run.sh; do
        if [ ! -e "$harness" ]; then
            continue
        fi
        harnesses=$((harnesses + 1))
        _run_harness "$stubs:$allow" "$sandbox" "$python" "" "$troth" "$harness" --skip-network
        [ "$status" -eq 0 ]
        [[ "$output" != *"the model sweep was requested"* ]] || false
        # A MODEL CASE REALLY RAN. The stub was found (so no "not on PATH" skip), it was asked for
        # the right thing (so no "unexpected" line), and the case reported its own PASS label --
        # which exit 0 alone would not distinguish from a deleted floor over a fully skipped sweep.
        [[ "$output" == *"E5 fallback line present"* ]] || false
        [[ "$output" != *"claude is not on PATH"* ]] || false
        [[ "$output" != *"unexpected claude invocation"* ]] || false
        # E4's absent input is reported as absent, not as wrong -- the distinction the harness's
        # header is built around, and the reason this case can be green with no second repository.
        [[ "$output" == *"E4 chain position: needs the second repository"* ]] || false
    done

    [ "$harnesses" -gt 0 ]
}

# ── 10. the E2a count floor has an oracle, in both directions ────────────────────────────────────
# THE FLOOR THAT CATCHES A GATE SILENTLY EMPTIED RATHER THAN BROKEN. `-k e2a` is a contract with the
# test NAMES, and both ways of breaking it land on this one floor: rename ALL of them and the
# collected count is 0, which the floor reports as `selected 0 of N authored` without ever running
# pytest; rename all-but-one and the selection is 1, pytest exits 0, and without the floor the case
# would report PASS over a gate that has lost every assertion but one. The count is what closes both,
# and until this case existed nothing anywhere read it. (pytest's rc 5 for an empty selection is
# unreachable from any minimum of one or more -- the floor returns first -- which is why the harness
# carries no rc-5 arm and says so.)
#
# BOTH HALVES RUN AGAINST A SANDBOX WHOSE SELECTION THIS FILE AUTHORS, and the threshold and the
# target path are read back out of the harness so neither half can drift off the floor it checks.
# The shortfall is one short -- the smallest possible -- because that is the shape rc 5 cannot see.
@test "evals/*/run.sh: the E2a count floor fires one test short and holds at the authored minimum" {
    local allow python harness min target short full harnesses=0
    python="$(_python_with_pytest)"
    allow="$(_allowlist_bin)"
    _refute_resolvable "$allow" "${_EVAL_HIDDEN_NETWORK[@]}" "${_EVAL_HIDDEN_OFFLINE[@]}"

    for harness in "$BORG_HOME"/evals/*/run.sh; do
        if [ ! -e "$harness" ]; then
            continue
        fi
        # A harness with no count floor has no count floor to oracle. The `harnesses` guard below is
        # what keeps that from quietly emptying this case: if NO harness declares one, the whole
        # loop is vacuous and the case fails instead of passing over nothing.
        if ! grep -q '^E2A_MIN=' "$harness"; then
            continue
        fi
        harnesses=$((harnesses + 1))
        min="$(_e2a_min "$harness")"
        target="$(_e2a_target "$harness")"

        short="$(_shortfall_repo "short-$harnesses" "$target" "$((min - 1))" 0)"
        _run_harness "$allow" "$short" "$python" "" "" "$harness" "${_EVAL_OFFLINE_ARGS[@]}"
        [ "$status" -ne 0 ]
        # NAMES THE SHORTFALL, both numbers. "It failed" would also be produced by a sandbox pytest
        # could not collect at all, and the count is the fact a reader needs to tell "somebody
        # renamed the tests" from "the contract broke".
        [[ "$output" == *"selected $((min - 1)) of $min authored"* ]] || false
        [[ "$output" != *"selected no tests"* ]] || false

        # THE DISCRIMINATOR: the same synthetic sandbox, one test richer, must exit 0. Without it
        # the floor gets credit for "a sandbox this file builds always fails", which would hold for
        # a count floor comparing against infinity.
        full="$(_shortfall_repo "full-$harnesses" "$target" "$min" 0)"
        _run_harness "$allow" "$full" "$python" "" "" "$harness" "${_EVAL_OFFLINE_ARGS[@]}"
        [ "$status" -eq 0 ]
        [[ "$output" == *"PASS"* ]] || false
        [[ "$output" != *"authored"* ]] || false
    done

    [ "$harnesses" -gt 0 ]
}

# ── 11. the E2a executed-outcome floor has an oracle, in both directions ─────────────────────────
# THE FLOOR THE COUNT FLOOR CANNOT COVER, and the one the exit code is blind to. A selection can
# meet the minimum, pytest can exit 0, and the tests can still not have RUN: a `skip` marker, a
# collection-time short-circuit, an `xfail` -- all collected, none executed as a pass, rc 0
# throughout. The harness reads its own junit XML to count outcomes for exactly that.
#
# THE TWO HALVES DIFFER BY ONE DECORATOR. `_shortfall_repo`'s last argument marks that many of the
# generated tests `@pytest.mark.skip`; both runs collect the full authored minimum, so the count
# floor above is satisfied in both and cannot be what fires. That is the isolation this pair needs:
# the second run is deliberately identical to case 10's positive half rather than deferring to it,
# because a negative that lives in another case is not a negative for this one.
@test "evals/*/run.sh: the E2a outcome floor fires on a collected-but-unexecuted test and holds otherwise" {
    local allow python harness min target skipped executed harnesses=0
    python="$(_python_with_pytest)"
    allow="$(_allowlist_bin)"
    _refute_resolvable "$allow" "${_EVAL_HIDDEN_NETWORK[@]}" "${_EVAL_HIDDEN_OFFLINE[@]}"

    for harness in "$BORG_HOME"/evals/*/run.sh; do
        if [ ! -e "$harness" ]; then
            continue
        fi
        if ! grep -q '^E2A_MIN=' "$harness"; then
            continue
        fi
        harnesses=$((harnesses + 1))
        min="$(_e2a_min "$harness")"
        target="$(_e2a_target "$harness")"

        skipped="$(_shortfall_repo "skipped-$harnesses" "$target" "$min" 1)"
        _run_harness "$allow" "$skipped" "$python" "" "" "$harness" "${_EVAL_OFFLINE_ARGS[@]}"
        [ "$status" -ne 0 ]
        # NAMES THE GAP, not merely a failure: collected-vs-executed is the whole distinction, and a
        # reason that said only "E2a failed" would send a reader looking for a broken assertion.
        [[ "$output" == *"collected but not all executed"* ]] || false
        # AND NOT THE COUNT FLOOR'S REASON. The selection is the full authored minimum here, so a
        # run that fired the count floor instead would mean this case is checking the wrong one.
        [[ "$output" != *"authored"* ]] || false

        executed="$(_shortfall_repo "executed-$harnesses" "$target" "$min" 0)"
        _run_harness "$allow" "$executed" "$python" "" "" "$harness" "${_EVAL_OFFLINE_ARGS[@]}"
        [ "$status" -eq 0 ]
        [[ "$output" == *"PASS"* ]] || false
        [[ "$output" != *"collected but not all executed"* ]] || false
    done

    [ "$harnesses" -gt 0 ]
}

# ── 12. the checkout guard in front of `rm -rf "$OUT"`, in both directions ───────────────────────
# NOT A FLOOR, AND THE CASE WITH THE WORST FAILURE MODE IN THE FILE ANYWAY. Every floor above fails
# SILENT; this guard fails DELETING. `$OUT` is derived as `$REPO/<...>/out` and the harness `rm -rf`s
# it on every run so a stale artifact cannot read as a fresh PASS, which makes `$REPO` -- i.e.
# `BORG_EVAL_REPO`, which this suite overrides in every case above and any developer can export --
# the input that decides what gets deleted. The harness guards it by testing for a TRACKED marker at
# the root before the `rm`, and until this case existed NOTHING anywhere read that guard: delete the
# whole `if` block and every gate in the tree stays green.
#
# THE CANARY IS THE ASSERTION; THE EXIT CODE ALONE IS NOT. "Exits non-zero naming the checkout" is
# satisfied just as well by a harness that prints the refusal AFTER the deletion, which is precisely
# the bug worth catching, so both halves plant a file where `$OUT` would be and read it back
# afterwards: it must SURVIVE the refusal, and be GONE from the run that got past the guard. The
# second half is what proves the survival was the guard's doing rather than a `rm` that never runs.
#
# EXIT 2, NOT MERELY NON-ZERO: every execution floor above exits 1, so a case content with non-zero
# would also be satisfied by a guard deleted in favour of some later floor firing on the wreckage.
# And no interpreter is requested, deliberately -- nothing here needs pytest, so this guard keeps its
# oracle on a bare checkout where the seven cases above fail their premise.
@test "evals/*/run.sh: a REPO that is not this checkout is refused before the rm -rf" {
    local allow sandbox harness rel decoy harnesses=0
    allow="$(_allowlist_bin)"
    _refute_resolvable "$allow" "${_EVAL_HIDDEN_NETWORK[@]}" "${_EVAL_HIDDEN_OFFLINE[@]}"

    for harness in "$BORG_HOME"/evals/*/run.sh; do
        if [ ! -e "$harness" ]; then
            continue
        fi
        harnesses=$((harnesses + 1))
        rel="$(_eval_out_rel "$harness")"

        # A directory carrying NO tracked root marker -- the shape a typo'd, stale or inherited
        # BORG_EVAL_REPO produces, and the shape whose `rm -rf` lands outside the repository. Its
        # only content is the canary, at the path THIS harness would delete.
        decoy="${BATS_TEST_TMPDIR}/not-a-checkout-$harnesses"
        mkdir -p "$decoy/$rel"
        printf 'do not delete me\n' > "$decoy/$rel/canary"
        # The premise, checked rather than assumed: a marker landing here (a future sandbox helper
        # linking the whole root in, say) would make this half assert the guard from the wrong side.
        [ ! -e "$decoy/borg.zsh" ]

        _run_harness "$allow" "$decoy" "" "" "" "$harness" "${_EVAL_OFFLINE_ARGS[@]}"
        [ "$status" -eq 2 ]
        # NAMED, and named WITH THE PATH: a reader of this refusal has to be able to tell which
        # directory was rejected, because the whole point is that it was not the one they meant.
        [[ "$output" == *"does not look like the borg-collective checkout"* ]] || false
        [[ "$output" == *"$decoy"* ]] || false
        # IT REFUSED BEFORE THE DELETION. This is the invariant, and nothing else in this file can
        # tell it apart from a guard that runs after the `rm`.
        [ -f "$decoy/$rel/canary" ]
        # And it refused before any case ran, so this is the guard's doing and not a floor's.
        [[ "$output" != *"RESULT:"* ]] || false

        # THE DISCRIMINATOR: the same invocation with the same hidden inputs against a `$REPO` that
        # DOES carry the marker. Without it the guard gets credit for "the harness always refuses an
        # overridden REPO", which would hold for a guard that rejected every value -- and `make eval`
        # would then be unrunnable everywhere.
        sandbox="$(_eval_sandbox_repo)"
        [ -f "$sandbox/borg.zsh" ]
        mkdir -p "$sandbox/$rel"
        printf 'inside the sandbox, and expected to be deleted\n' > "$sandbox/$rel/canary"

        _run_harness "$allow" "$sandbox" "" "" "" "$harness" "${_EVAL_OFFLINE_ARGS[@]}"
        [[ "$output" != *"does not look like the borg-collective checkout"* ]] || false
        # The deletion really is aimed at `$REPO/<rel>`, which is what makes the surviving canary
        # above evidence about the guard rather than about a path nothing touches.
        [ ! -e "$sandbox/$rel/canary" ]
        # It reached its cases. With every optional input hidden the run ends on the GLOBAL floor at
        # exit 1 (case 4's subject), so the status is asserted to be something OTHER than the guard's
        # 2 -- a future guard that exited 1 could otherwise make this half pass by refusing too.
        [[ "$output" == *"SKIP"* ]] || false
        [ "$status" -ne 2 ]
    done

    [ "$harnesses" -gt 0 ]
}

# ── 13. the guarded array expansion has a platform-independent oracle ────────────────────────────
# THE ONLY STATIC ASSERTION IN THIS FILE, AND IT IS EARNED. Case 9 executes the harness's empty-array
# branch -- the branch that crashed -- but it can only FAIL where the bug exists, i.e. bash before 4.4,
# the macOS developer machine. On the ubuntu lane that runs `bats tests/*.bats` the bare form is
# perfectly legal, so "simplifying" the guard would sail through CI and land the crash on the one
# machine no lane covers. That is CLAUDE.md's "a test's PREMISE can depend on the dev platform" class
# with the platforms swapped: the green lane is the one where the premise holds. Reading the SOURCE is
# the only gate that fires on both, and it is the honest trade -- a behavioural case cannot assert this
# on bash 5, because bash 5 has no defect to observe.
#
# SCOPED TO THE OPTIONAL PREFIX ARRAY, NOT TO EVERY ARRAY, because "can this be empty" is not
# statically knowable and a blanket rule is wrong: `REPOS` is seeded with one element before it is
# ever expanded and `programs_dir_args` is built from it inside a branch that requires two, so both
# are correctly bare. Only the timeout prefix is legitimately EMPTY, which is what makes it the one
# expansion the guard is for.
#
# ARITHMETIC, NOT PATTERN SURGERY. The guarded form contains the bare form as its own default value,
# and the comment above it quotes both spellings in prose, so a naive grep for the bare shape matches
# the guard and its own documentation -- measured, three false positives on the first attempt. Instead:
# every legitimate mention in CODE is either the guard's test (`[@]+`) or the inner expansion that
# immediately follows it, so a correct file has exactly TWICE as many `TIMEOUT[@]` occurrences as
# `TIMEOUT[@]+` ones. A bare expansion adds one to the left side only.
@test "evals/*/run.sh: the optional prefix array is never expanded bare" {
    local harness harnesses=0 total guarded

    for harness in "$BORG_HOME"/evals/*/run.sh; do
        if [ ! -e "$harness" ]; then
            continue
        fi
        harnesses=$((harnesses + 1))

        # `grep -c` RETURNS 1 ON ZERO MATCHES, so neither count may be the last command whose status
        # is read -- the trap that once reported a bats run of 774 ok as a failure. Captured through
        # `|| true`, defaulted, then compared as their own statements.
        total="$(grep -v '^[[:space:]]*#' "$harness" | grep -o 'TIMEOUT\[@\]' | grep -c . || true)"
        guarded="$(grep -v '^[[:space:]]*#' "$harness" | grep -o 'TIMEOUT\[@\]+' | grep -c . || true)"
        total="${total:-0}"
        guarded="${guarded:-0}"

        # THE DISCRIMINATOR, and it must come first. Asserting only the ratio would also hold for a
        # harness that expands no prefix at all (0 == 2*0), which is what this case would silently
        # become if the model cases were rewritten or the array renamed. Requiring a guarded site to
        # EXIST means the thing being protected is still there for the protection to mean anything.
        [ "$guarded" -gt 0 ]

        if [ "$total" -ne $((2 * guarded)) ]; then
            echo "bare TIMEOUT[@] expansion in $harness ($total mentions, $guarded guarded):" >&2
            grep -vn '^[[:space:]]*#' "$harness" | grep 'TIMEOUT\[@\]' >&2 || true
            false
        fi
    done

    [ "$harnesses" -gt 0 ]
}
