#!/usr/bin/env bats
# The changed-files eval selector and its make wiring -- `make eval-changed`.
#
# Everything runs in a SANDBOX copy of the Makefile and the selector with two stub harnesses that
# record that they ran, so a case can prove WHICH harnesses a change selected without a real eval.
# Pairs, as in tests/eval_floor.bats: a change that selects runs only its harness; a change that
# selects nothing is a clean exit 0 that runs none -- and `make eval`, the full run, still fails the
# selection floor on a tree with no harness, so the new "nothing to run" is not a hole in that floor.

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    SB="${BATS_TEST_TMPDIR}/tree"
    mkdir -p "$SB/borg_core" "$SB/evals/e1" "$SB/evals/e2"

    # GIVE THE SANDBOX A GIT IDENTITY. This test runs git commit (line 57) in the isolated sandbox.
    # The identity must be set via environment variables because this setup function doesn't use the
    # shared test_helper/setup harness. See tests/test_helper/setup.bash for the rationale: macOS
    # auto-derives from getpwuid + hostname, but Linux containers refuse outright.
    export GIT_AUTHOR_NAME="borg tests"    GIT_AUTHOR_EMAIL="tests@borg.invalid"
    export GIT_COMMITTER_NAME="borg tests" GIT_COMMITTER_EMAIL="tests@borg.invalid"
    export GIT_CONFIG_NOSYSTEM=1

    cp "$REPO_ROOT/Makefile" "$SB/Makefile"
    cp "$REPO_ROOT/borg_core/__init__.py" "$SB/borg_core/__init__.py"
    cp -R "$REPO_ROOT/borg_core/evals" "$SB/borg_core/evals"
    for e in e1 e2; do
        printf '#!/usr/bin/env bash\necho "ran-%s" >> "${EVAL_RAN_LOG:?}"\n' "$e" > "$SB/evals/$e/run.sh"
    done
    cat > "$SB/evals/ledger.json" <<'JSON'
{"version": 1,
 "evals": {"evals/e1": {"covers": ["evals/e1/**", "lib/one/**"]},
           "evals/e2": {"covers": ["evals/e2/**", "lib/two/**"]}},
 "items": {}}
JSON
    export EVAL_RAN_LOG="${BATS_TEST_TMPDIR}/ran.log"
    : > "$EVAL_RAN_LOG"
}

sel() { run env "PYTHONPATH=${SB}" python3 -m borg_core.evals.cli select --root "$SB" "$@"; }
mk() { run make -C "$SB" --no-print-directory "$@"; }

@test "selector: a change under one eval's covers selects only that eval" {
    sel --files lib/one/x.sh
    [ "$status" -eq 0 ]
    [ "${lines[${#lines[@]}-1]}" = "evals/e1" ]
    [[ "$output" != *"evals/e2"* ]] || false
}

@test "selector: a change touching nothing covered says so and exits 0" {
    sel --files README.md docs/x.md
    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing to run"* ]] || false
}

@test "selector: the ledger, the Makefile and the selector itself each select ALL" {
    for f in evals/ledger.json Makefile borg_core/evals/core.py; do
        sel --files README.md "$f"
        [ "$status" -eq 0 ]
        [[ "$output" == *"selecting all 2"* ]] || false
        [[ "$output" == *"evals/e1"* && "$output" == *"evals/e2"* ]] || false
    done
}

@test "selector: a git range selects from the files that range changed" {
    git -C "$SB" init -q -b main
    git -C "$SB" add -A && git -C "$SB" commit -qm base
    git -C "$SB" update-ref refs/remotes/origin/main HEAD
    mkdir -p "$SB/lib/two" && echo x > "$SB/lib/two/f.sh"
    git -C "$SB" add -A && git -C "$SB" commit -qm change
    sel
    [ "$status" -eq 0 ]
    [ "${lines[${#lines[@]}-1]}" = "evals/e2" ]
    [[ "$output" != *"evals/e1"* ]] || false
}

@test "make eval-changed: runs only the selected harness" {
    mk eval-changed EVAL_FILES="lib/two/y.sh"
    [ "$status" -eq 0 ]
    [ "$(cat "$EVAL_RAN_LOG")" = "ran-e2" ]
}

@test "make eval-changed: a selection of zero is a clean 'nothing to run', not a floor violation" {
    mk eval-changed EVAL_FILES="README.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"nothing to run"* ]] || false
    [ ! -s "$EVAL_RAN_LOG" ]
}

@test "make eval: the full run still fails the selection floor on a tree with no harness" {
    rm "$SB/evals/e1/run.sh" "$SB/evals/e2/run.sh"
    mk eval
    [ "$status" -ne 0 ]
    [[ "$output" == *"nothing was selected"* ]] || false
}

@test "make eval-changed: a selected harness that is missing FAILS rather than skipping" {
    rm "$SB/evals/e2/run.sh"
    mk eval-changed EVAL_FILES="lib/two/y.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"selected harness missing"* ]] || false
}

@test "make eval-changed: a ledger change runs every harness" {
    mk eval-changed EVAL_FILES="evals/ledger.json"
    [ "$status" -eq 0 ]
    [ "$(sort "$EVAL_RAN_LOG" | tr '\n' ' ')" = "ran-e1 ran-e2 " ]
}

@test "make eval-changed: EVAL_ARGS validation still applies to the selected run" {
    mk eval-changed EVAL_FILES="lib/two/y.sh" EVAL_ARGS="--help"
    [ "$status" -ne 0 ]
    [[ "$output" == *"refusing EVAL_ARGS"* ]] || false
    [ ! -s "$EVAL_RAN_LOG" ]
}

@test "make eval-live-changed: forwards no offline flags to the selected harness" {
    mk -n eval-live-changed EVAL_FILES="lib/two/y.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"EVAL_ARGS="* ]] || false
    [[ "$output" != *"--skip-model"* ]] || false
}

@test "ci: the workflow runs eval-changed on pull requests and never a live target" {
    run grep -n "make eval-changed" "$REPO_ROOT/.github/workflows/test.yml"
    [ "$status" -eq 0 ]
    run bash -c "grep -vE '^[[:space:]]*#' '$REPO_ROOT/.github/workflows/test.yml' | grep -E 'make +eval-live'"
    [ "$status" -ne 0 ]
}
