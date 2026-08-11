#!/usr/bin/env bats
# CLI CONTRACT SUITE — the only tests that execute borg.zsh under a real zsh.
#
# WHY THIS FILE EXISTS. Every other suite in tests/ sources or invokes code from bats, which runs
# under BASH. borg.zsh is ZSH. On 2026-08-11 two bugs were found that had been live since #95
# precisely because nothing ever ran the CLI in its own interpreter:
#
#   1. `${BASH_SOURCE[0]:-$0}` — BASH_SOURCE is a bash-only array that expands to EMPTY in zsh, and
#      zsh's $0 inside a sourced file has no directory component, so `dirname` returned "." and the
#      repo's shipped recon adapters fell out of the search path entirely.
#   2. `IFS=:; set -- $var` — zsh does NOT word-split unquoted parameter expansions, so this yielded
#      ONE positional parameter under zsh and TWO under bash. Adapter discovery iterated zero dirs.
#
# Both are invisible to a bash harness by construction. `borg recon` reported "No recon adapters
# found" and exited 0 while the bats suite stayed green.
#
# WHAT THIS SUITE IS. Black-box. It shells out to the real script and asserts on observable exit
# codes and output. It will NOT localize a fault to a function — that is the unit suites' job. Its
# value is that it runs the real interpreter on the real userland.
#
# INVARIANT: every test here must invoke the CLI via `zsh` explicitly. Do not "simplify" these to
# direct invocation — the shebang would still be honored, but making zsh explicit is the point of
# the file and is asserted by the meta-test at the bottom.

load test_helper/setup

BORG="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs
}

# Run the CLI under an explicit zsh. Stdout+stderr merged; callers assert on $output/$status.
run_zsh_borg() {
    run zsh "$BORG" "$@"
}

# ── dispatch ─────────────────────────────────────────────────────────────────

@test "contract: help exits 0 and renders under zsh" {
    run_zsh_borg help
    [ "$status" -eq 0 ]
    [[ "$output" == *"THE BORG COLLECTIVE"* ]] || false
}

@test "contract: unknown command exits non-zero with a pointer to help" {
    run_zsh_borg definitely-not-a-command
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown command"* ]] || false
}

@test "contract: version exits 0 and prints a bare version string" {
    run_zsh_borg version
    [ "$status" -eq 0 ]
    [[ "$output" == *.*.* ]] || false
}

# ── guards the alias removal (2026-08-11) ────────────────────────────────────
# These aliases were removed because six names for one command meant the docs, the skills, and the
# research all disagreed about what to call it. Removal must (a) actually take effect and (b) point
# somewhere useful — a bare "unknown command" would send years of muscle memory into a dead end.
# The unit-level version of this test previously passed VACUOUSLY: it asserted `borg help` output
# contained "ls", which stayed true after removal because the help text lists the removed names.

@test "contract: removed aliases exit non-zero and name 'borg link'" {
    for alias_name in ls status hail brief; do
        run_zsh_borg "$alias_name"
        [ "$status" -ne 0 ]
        [[ "$output" == *"borg link"* ]] || false
    done
}

@test "contract: link is still dispatched and is not itself reported as removed" {
    run_zsh_borg link --help
    [[ "$output" != *"unknown command"* ]] || false
    [[ "$output" != *"was removed"* ]] || false
}

# ── guards #113: zsh-only adapter discovery ──────────────────────────────────
# THE regression gate for this whole file. Under bash this passed for weeks while being broken in
# zsh. Asserting the shipped reference adapter is discovered exercises _recon_lib_dir() (bug 1) and
# the colon-path split (bug 2) together, in the interpreter where both failed.

@test "contract: recon discovers the repo's shipped github adapter under zsh (#113)" {
    run zsh -c "unset BORG_RECON_ADAPTER_PATH; '$BORG' recon --adapters"
    [ "$status" -eq 0 ]
    [[ "$output" == *"github"* ]] || false
    [[ "$output" != *"No recon adapters found"* ]] || false
}

@test "contract: recon adapter path resolves an absolute repo dir, never '.' (#113)" {
    run zsh -c "unset BORG_RECON_ADAPTER_PATH; '$BORG' recon --adapters"
    [[ "$output" != *":./recon/adapters"* ]] || false
    [[ "$output" != *" ./recon"* ]] || false
}

# ── guards #114: BSD-vs-GNU stat, only observable on a real BSD userland ──────
# `stat -f %m` is BSD, `stat -c %Y` is GNU. A `bsd || gnu` chain is broken on GNU because GNU's -f
# prints a filesystem block to STDOUT before failing, so command substitution captured garbage
# concatenated with the real epoch. This test is meaningful on the macOS leg specifically: it proves
# the mtime helper returns a usable integer on whichever userland is running it.

@test "contract: file-mtime helper returns a plain integer on this platform (#114)" {
    local probe="${BATS_TEST_TMPDIR}/probe"
    touch "$probe"
    run zsh -c "set -- help; source '$BORG' >/dev/null 2>&1; _borg_file_mtime '$probe'"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]] || false
}

@test "contract: file-mtime helper fails cleanly on a missing file, printing nothing" {
    run zsh -c "set -- help; source '$BORG' >/dev/null 2>&1; _borg_file_mtime '/no/such/file/here'"
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

# ── blocking guards must still block ─────────────────────────────────────────
# The three PreToolUse guards are the only interrupts that pass the Phase-2 D4 four-part test
# (urgent, actionable, judgment-requiring, user-visible). If one silently stops blocking, the
# advisory-nudge noise would be the least of the problems.

@test "contract: bash-guard blocks a destructive rm and exits non-zero" {
    local hook="${BATS_TEST_DIRNAME}/../hooks/bash-guard.sh"
    run bash -c "printf '%s' '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"rm -rf /\"}}' | '$hook'"
    [ "$status" -ne 0 ] || [[ "$output" == *"deny"* ]] || [[ "$output" == *"block"* ]] || false
}

@test "contract: hooks exit 0 on empty stdin (fail-open contract)" {
    for h in borg-link-up borg-link-down borg-notify tool-count-nudge pre-commit-remind; do
        local hook="${BATS_TEST_DIRNAME}/../hooks/${h}.sh"
        if [ -f "$hook" ]; then
            run bash -c "printf '' | '$hook'"
            [ "$status" -eq 0 ]
        fi
    done
}

# ── meta ─────────────────────────────────────────────────────────────────────

@test "contract: this suite actually invokes zsh (guards against a well-meaning refactor)" {
    run grep -c 'zsh' "${BATS_TEST_DIRNAME}/cli_contract.bats"
    [ "$status" -eq 0 ]
    [ "$output" -ge 8 ]
}
