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
    # setup_temp_dirs sandboxes HOME/XDG_CONFIG_HOME/BORG_DIR/BORG_REGISTRY but NOT XDG_DATA_HOME.
    # Discovered during this file's own integration pass: on a developer machine that exports
    # XDG_DATA_HOME in its shell profile (common — e.g. `~/.local/share`), an unsandboxed vinculum
    # or doctor test silently reads (and for vinculum pub/sub, would WRITE to) the real
    # $XDG_DATA_HOME/borg/vinculum or $XDG_DATA_HOME/borg/*.log files instead of a fixture — a real
    # CRITICAL SAFETY RULE #2/#3 violation that a bare `HOME` override does not catch. Matches the
    # existing per-file convention already used in tests/doctor.bats, tests/vinculum.bats, and
    # tests/vinculum-watch.bats (each exports XDG_DATA_HOME locally rather than it living in the
    # shared setup_temp_dirs helper), so this follows established precedent rather than introducing
    # a new one.
    export XDG_DATA_HOME="${BATS_TEST_TMPDIR}/data"
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

@test "contract: briefing was removed and points at 'borg link --brief'" {
    run_zsh_borg briefing
    [ "$status" -ne 0 ]
    [[ "$output" == *"borg briefing"* ]] || false
    [[ "$output" == *"borg link --brief"* ]] || false
}

@test "contract: refresh was removed and points at 'borg link --refresh'" {
    run_zsh_borg refresh
    [ "$status" -ne 0 ]
    [[ "$output" == *"borg refresh"* ]] || false
    [[ "$output" == *"borg link --refresh"* ]] || false
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

# ══════════════════════════════════════════════════════════════════════════════
# PART 3 / C4 GATE CLOSURE (2026-08-12) — contract coverage for every remaining borg.zsh dispatch
# arm. Four groups drafted these in parallel against disjoint command sets; this integration pass
# re-read every cmd_* implementation against the drafted assertions (not just the groups' own
# self-reports) and fixed one recurring safety gap before merging: several drafted tests wrote a
# mock tmux/docker binary into $MOCK_BIN via setup_mock_bin but never exported BORG_PATH_PREFIX.
# borg.zsh resets $PATH from scratch at its own line 15 and ONLY honors BORG_PATH_PREFIX for
# prepending — plain `export PATH=...` from a test (which is all setup_mock_bin does on its own) is
# silently discarded by borg.zsh's own PATH reset, so those tests would have silently fallen through
# to the REAL system tmux/docker on PATH instead of the mock. That is the exact incident shape
# CRITICAL SAFETY RULE #2 exists to prevent — e.g. `borg add`/`borg color` unconditionally call
# `borg_tmux_window_exists`, which is a real (if read-only) `tmux has-session`/`list-windows` query
# against WHATEVER tmux session happens to be live on the machine running the suite; `borg color`'s
# live-window variant would have gone further and issued real `tmux set-option` calls against a real
# window if one happened to match the test's project name. Every mock in this section is now paired
# with an explicit `export BORG_PATH_PREFIX="$MOCK_BIN"`, matching the established precedent in
# tests/doctor.bats and tests/briefing.bats. Each group's documented "honest gaps" are preserved
# verbatim as comments near the relevant tests rather than silently dropped.
# ══════════════════════════════════════════════════════════════════════════════

# Shared tmux mock, used by several tests below (registry CRUD's `next`, and the whole
# tmux/session-interactive block). Logs every invocation (space-joined args) as one line to $TRACE
# and returns scripted responses for has-session / list-windows; everything else defaults to a
# harmless success. Same fake-executable-on-$MOCK_BIN convention as tests/drone_pane.bats. Tests
# that only need a single canned response (a cancelling fzf, a bare "no session" stub, a one-off
# docker/launchctl fake) still write their own narrower inline mock rather than overloading this one
# — reusing it there would mean immediately overwriting most of its behavior anyway.
#   TMUX_MOCK_HAS_SESSION=1   -> has-session succeeds (session already alive)
#   TMUX_MOCK_WINDOWS="a b"   -> list-windows prints these (one per line)
_mock_tmux() {
    cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
echo "tmux $*" >> "$TRACE"
case "$1" in
    has-session)
        [ "${TMUX_MOCK_HAS_SESSION:-0}" = "1" ] && exit 0 || exit 1 ;;
    list-windows)
        printf '%s\n' "${TMUX_MOCK_WINDOWS:-}" ;;
    list-panes)
        echo "0 %1" ;;
    display-message)
        echo "mock-window" ;;
    *)
        exit 0 ;;
esac
EOF
    chmod +x "$MOCK_BIN/tmux"
}

# ── registry CRUD: next, scan, add, rm, pin, unpin, color, image ─────────────

# cmd_next (borg.zsh:1074). Reads borg_registry_with_state, scores/sorts projects via jq, prints the
# top pick or "All clear". No unit-level test of this scoring exists anywhere else in tests/, so
# these are real behavioral checks, not just dispatch smoke. Every fixture project uses path:null so
# _borg_read_directives is a no-op, keeping the test inside the sandbox. NOTE: borg_registry_with_state
# unconditionally calls _borg_live_windows (inside borg_reap_overlay) once per invocation, regardless
# of whether any project is active/waiting or the registry is empty — so even these read-mostly tests
# reach real tmux unless mocked; a bare "no live session" stub is enough since neither fixture project
# is ever active/waiting.

@test "contract: next on an empty registry says all clear and exits 0" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$MOCK_BIN/tmux"

    run_zsh_borg next
    [ "$status" -eq 0 ]
    [[ "$output" == *"All clear"* ]] || false
}

@test "contract: next surfaces the pinned project over an unpinned one" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$MOCK_BIN/tmux"

    printf '%s' '{"projects":{"alpha":{"path":null,"pinned":false},"zulu-pinned":{"path":null,"pinned":true}}}' > "$BORG_REGISTRY"
    run_zsh_borg next
    [ "$status" -eq 0 ]
    [[ "$output" == *"Next up: zulu-pinned"* ]] || false
    [[ "$output" == *"[pinned]"* ]] || false
}

# --switch is only exercised here in the trivial empty-registry branch (tmux display-message with
# 2>/dev/null || true). The non-trivial --switch path calls _borg_do_switch, which is shared plumbing
# for the `switch` command — that command's own tests below own deeper coverage of it, so it isn't
# duplicated here; this just proves the --switch flag itself dispatches cleanly under real zsh.
@test "contract: next --switch on an empty registry exits 0 without needing a live tmux session" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$MOCK_BIN/tmux"

    run_zsh_borg next --switch
    [ "$status" -eq 0 ]
}

# cmd_scan (borg.zsh:838) fans out over claude/coco/desktop session-history sources and then, for
# every ALREADY-REGISTERED project, shells out to python3 summarize.py. Path-skip/discovery logic
# already has real unit coverage in tests/registry.bats (borg_scan_path_should_skip: 6 cases). The
# minimal safe CLI contract here is proving dispatch reaches cmd_scan and completes cleanly under a
# fully sandboxed/empty HOME — with zero registered projects and the claude/coco session logs absent
# under the sandboxed HOME, both the discovery loop and the summarize.py refresh loop have zero
# iterations, so no external process or real ~/.claude data is ever touched, and no tmux mock is
# needed either (cmd_scan reads the raw registry, not the state-overlaid/tmux-touching one).
#
# HONEST GAP (from the drafting group, preserved): full source-discovery/path-skip logic itself is
# not re-tested here — that's already covered in tests/registry.bats and re-testing it would mean
# faking real ~/.claude session-history files, which is more than a CLI dispatch contract needs.

@test "contract: scan dispatches under zsh and completes cleanly on an empty sandboxed HOME" {
    run_zsh_borg scan
    [ "$status" -eq 0 ]
    [[ "$output" == *"Scanning Claude session history"* ]] || false
    [[ "$output" == *"No new projects found"* ]] || false
}

@test "contract: scan --no-llm still dispatches and exits 0" {
    run_zsh_borg scan --no-llm
    [ "$status" -eq 0 ]
}

# cmd_add (borg.zsh:946) calls borg_tmux_window_exists unconditionally, which shells out to real
# tmux. Mocked per this suite's established convention (see tests/drone_pane.bats) so the test never
# depends on, or touches, any real tmux session/window on the host. has-session always fails here (no
# live window), which is the common case for a freshly-registered project.
#
# HONEST GAP (from the drafting group, preserved): cmd_add has no invalid-argument failure branch at
# all by design — `local ppath="${1:-$PWD}"` accepts any string, including a nonexistent path, and
# always "succeeds" (realpath falls back to echoing the raw string on failure). So unlike rm/pin/
# unpin/color, there is no clean-failure-on-bad-arg contract to test for `add`.
#
# KNOWN BUG (found during this integration pass, not by the drafting group — verified directly
# against a real zsh interpreter outside bats/mocking, same reproduction shape as the pre-existing
# "claude already inside tmux" bug elsewhere in this file, so it is not a mocking artifact). cmd_add's
# very last line is a bare, non-if/while `[[ -n "$session_id" ]] && info "Latest session: $session_id"`.
# For a freshly-added project with no discoverable Claude session history (the common case — this is
# the FIRST thing you run before ever opening Claude Code in that directory), $session_id is empty, so
# that line's own exit status is 1 ("false"), and because borg.zsh runs under `set -e`, errexit trips
# immediately — `borg add` on a brand-new project always exits 1 even though the registration itself
# (visible in both the "Registered: ..." output and the registry file below) fully succeeded. This
# pins the CURRENT (buggy) exit-1 contract on purpose, matching this file's established pattern for
# real-but-out-of-scope-to-fix bugs: a future fix (e.g. `[[ -n "$session_id" ]] && info "..."; true`)
# should show up here as a status-code flip to 0, not as a silent, undetected regression either way.
# Worth flagging as a real, everyday-command bug for a follow-up fix — out of scope for a
# test-coverage-only pass (constraints restrict this task to tests/cli_contract.bats).

@test "contract: add registers a new project keyed by the directory basename (currently exits 1 -- known bug)" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "has-session" ] && exit 1
exit 0
EOF
    chmod +x "$MOCK_BIN/tmux"

    local proj_dir="${BATS_TEST_TMPDIR}/sample-project"
    mkdir -p "$proj_dir"

    run_zsh_borg add "$proj_dir"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Registered: sample-project"* ]] || false

    run jq -e '.' "$BORG_REGISTRY"
    [ "$status" -eq 0 ]

    run jq -r '.projects["sample-project"].path' "$BORG_REGISTRY"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/sample-project" ]] || false

    run jq -r '.projects["sample-project"].source' "$BORG_REGISTRY"
    [ "$output" = "cli" ]
}

@test "contract: add with no path argument registers the current directory (currently exits 1 -- known bug)" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "has-session" ] && exit 1
exit 0
EOF
    chmod +x "$MOCK_BIN/tmux"

    local proj_dir="${BATS_TEST_TMPDIR}/cwd-project"
    mkdir -p "$proj_dir"

    run zsh -c "cd '$proj_dir' && '$BORG' add"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Registered: cwd-project"* ]] || false

    run jq -r '.projects["cwd-project"].path' "$BORG_REGISTRY"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/cwd-project" ]] || false
}

# cmd_rm (borg.zsh:993) never shells out (pure registry read/write), so no mocking is needed.

@test "contract: rm removes an existing project from the registry" {
    printf '%s' '{"projects":{"keep-me":{"path":"/tmp/keep"},"drop-me":{"path":"/tmp/drop"}}}' > "$BORG_REGISTRY"
    run_zsh_borg rm drop-me
    [ "$status" -eq 0 ]
    [[ "$output" == *"Removed: drop-me"* ]] || false

    run jq -e '.projects | has("drop-me") | not' "$BORG_REGISTRY"
    [ "$status" -eq 0 ]
    run jq -e '.projects | has("keep-me")' "$BORG_REGISTRY"
    [ "$status" -eq 0 ]
}

@test "contract: rm with no project argument fails cleanly without touching the registry" {
    printf '%s' '{"projects":{"keep-me":{"path":"/tmp/keep"}}}' > "$BORG_REGISTRY"
    run_zsh_borg rm
    [ "$status" -ne 0 ]
    [[ "$output" == *"usage: borg rm"* ]] || false

    run jq -e '.projects | has("keep-me")' "$BORG_REGISTRY"
    [ "$status" -eq 0 ]
}

@test "contract: rm of an unregistered project dies cleanly and leaves the registry valid" {
    printf '%s' '{"projects":{"keep-me":{"path":"/tmp/keep"}}}' > "$BORG_REGISTRY"
    run_zsh_borg rm ghost-project
    [ "$status" -ne 0 ]
    [[ "$output" == *"not in registry"* ]] || false

    run jq -e '.' "$BORG_REGISTRY"
    [ "$status" -eq 0 ]
    run jq -e '.projects | has("keep-me")' "$BORG_REGISTRY"
    [ "$status" -eq 0 ]
}

# cmd_pin/cmd_unpin (borg.zsh:1189, 1197) are pure registry read/write; no mocking needed.

@test "contract: pin sets pinned=true on an existing project" {
    printf '%s' '{"projects":{"alpha":{"path":"/tmp/alpha","pinned":false}}}' > "$BORG_REGISTRY"
    run_zsh_borg pin alpha
    [ "$status" -eq 0 ]
    [[ "$output" == *"Pinned: alpha"* ]] || false

    run jq -r '.projects.alpha.pinned' "$BORG_REGISTRY"
    [ "$output" = "true" ]
}

@test "contract: pin of an unregistered project dies cleanly without corrupting the registry" {
    printf '%s' '{"projects":{"alpha":{"path":"/tmp/alpha"}}}' > "$BORG_REGISTRY"
    run_zsh_borg pin ghost
    [ "$status" -ne 0 ]
    [[ "$output" == *"not in registry"* ]] || false

    run jq -e '.projects.alpha' "$BORG_REGISTRY"
    [ "$status" -eq 0 ]
}

@test "contract: pin with no argument falls back to the cwd basename and fails cleanly if unregistered" {
    local proj_dir="${BATS_TEST_TMPDIR}/unregistered-cwd"
    mkdir -p "$proj_dir"
    printf '%s' '{"projects":{}}' > "$BORG_REGISTRY"

    run zsh -c "cd '$proj_dir' && '$BORG' pin"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not in registry"* ]] || false
}

@test "contract: unpin sets pinned=false on an existing project" {
    printf '%s' '{"projects":{"alpha":{"path":"/tmp/alpha","pinned":true}}}' > "$BORG_REGISTRY"
    run_zsh_borg unpin alpha
    [ "$status" -eq 0 ]
    [[ "$output" == *"Unpinned: alpha"* ]] || false

    run jq -r '.projects.alpha.pinned' "$BORG_REGISTRY"
    [ "$output" = "false" ]
}

@test "contract: unpin of an unregistered project dies cleanly without corrupting the registry" {
    printf '%s' '{"projects":{"alpha":{"path":"/tmp/alpha"}}}' > "$BORG_REGISTRY"
    run_zsh_borg unpin ghost
    [ "$status" -ne 0 ]
    [[ "$output" == *"not in registry"* ]] || false

    run jq -e '.projects.alpha' "$BORG_REGISTRY"
    [ "$status" -eq 0 ]
}

# cmd_color (borg.zsh:1001) writes the registry field unconditionally, then, only if a matching live
# tmux window exists, also shells out to `tmux set-option` twice. Both tmux mocks follow the
# established convention in tests/drone_pane.bats (fake executable on $MOCK_BIN, invocations logged
# to a trace file), paired with BORG_PATH_PREFIX so borg.zsh's own PATH reset actually resolves to
# the mock instead of a real tmux binary — without it, the live-window variant below would issue real
# `tmux set-option` calls against a real window if one happened to match "alpha".

@test "contract: color sets a project's color field in the registry" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "has-session" ] && exit 1
exit 0
EOF
    chmod +x "$MOCK_BIN/tmux"

    printf '%s' '{"projects":{"alpha":{"path":"/tmp/alpha"}}}' > "$BORG_REGISTRY"
    run_zsh_borg color alpha blue
    [ "$status" -eq 0 ]
    [[ "$output" == *"Color for alpha"*"blue"* ]] || false
    [[ "$output" != *"Applied to live tmux window"* ]] || false

    run jq -r '.projects.alpha.color' "$BORG_REGISTRY"
    [ "$output" = "blue" ]
}

@test "contract: color also applies to a live matching tmux window" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    export TRACE="${BATS_TEST_TMPDIR}/tmux-trace.log"
    : > "$TRACE"
    cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
echo "tmux $*" >> "$TRACE"
case "$1" in
    has-session) exit 0 ;;
    list-windows) echo "alpha" ;;
    set-option) exit 0 ;;
esac
exit 0
EOF
    chmod +x "$MOCK_BIN/tmux"

    printf '%s' '{"projects":{"alpha":{"path":"/tmp/alpha"}}}' > "$BORG_REGISTRY"
    run_zsh_borg color alpha green
    [ "$status" -eq 0 ]
    [[ "$output" == *"Applied to live tmux window."* ]] || false

    run grep -c '^tmux set-option' "$TRACE"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

@test "contract: color with missing arguments dies cleanly with usage" {
    printf '%s' '{"projects":{"alpha":{"path":"/tmp/alpha"}}}' > "$BORG_REGISTRY"
    run_zsh_borg color alpha
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage: borg color"* ]] || false
}

@test "contract: color of an unregistered project dies cleanly" {
    printf '%s' '{"projects":{}}' > "$BORG_REGISTRY"
    run_zsh_borg color ghost blue
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown project: ghost"* ]] || false
}

# cmd_image (borg.zsh:1013) build/push/pull all shell out to real `docker`, and push/pull can also
# require BORG_IMAGE_REGISTRY plus an interactive confirmation prompt. `build` is contract-tested
# with a mocked docker (same tests/drone_pane.bats convention, paired with BORG_PATH_PREFIX — without
# it this test would invoke a REAL `docker build` on the host) so a real image build never runs. push
# is contract-tested only on its "registry unset" die path — the safe minimum per safety rule 5: it
# proves dispatch reaches the push subcommand and fails cleanly BEFORE the interactive confirm/real
# docker-push step, without ever needing to fake stdin or touch a registry.
#
# HONEST GAP (from the drafting group, preserved): `image push`/`image pull` with BORG_IMAGE_REGISTRY
# actually SET are not tested at all. That path requires either a real `docker push`/`pull` against a
# real registry, or faking an interactive `read -r` confirmation prompt (push only) plus a mocked
# docker — deeper than a single contract test justifies; the "registry unset" die path already proves
# dispatch reaches the subcommand and fails before anything real happens. `image pull` has zero
# coverage beyond what push's shared "registry unset" branch already demonstrates (both subcommands
# hit the identical `[[ -z "$registry" ]] && die ...` line).

@test "contract: image with no subcommand prints usage and exits 0" {
    run_zsh_borg image
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: borg image <build|push|pull>"* ]] || false
}

@test "contract: image push dies cleanly when BORG_IMAGE_REGISTRY is unset, never touching docker" {
    run zsh -c "unset BORG_IMAGE_REGISTRY; '$BORG' image push"
    [ "$status" -ne 0 ]
    [[ "$output" == *"BORG_IMAGE_REGISTRY not set"* ]] || false
}

@test "contract: image build dispatches to a mocked docker build with the local tag" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    export TRACE="${BATS_TEST_TMPDIR}/docker-trace.log"
    : > "$TRACE"
    cat > "$MOCK_BIN/docker" <<'EOF'
#!/usr/bin/env bash
echo "docker $*" >> "$TRACE"
exit 0
EOF
    chmod +x "$MOCK_BIN/docker"

    run zsh -c "unset BORG_IMAGE_REGISTRY; '$BORG' image build"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Built: devcontainer-base:local"* ]] || false

    run grep -c '^docker build' "$TRACE"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]

    run grep -c 'devcontainer-base:local' "$TRACE"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

# ── reporting / read-only: nanoprobes, nanoprobe-log, spend, watch, doctor, reap, ────────────────
# ── reap-worktrees, vinculum ──────────────────────────────────────────────────────────────────────

@test "contract: nanoprobes reports cleanly when agents.jsonl is absent" {
    run_zsh_borg nanoprobes
    [ "$status" -eq 0 ]
    [[ "$output" == *"No nanoprobes recorded yet."* ]] || false
    [[ "$output" != *"unknown command"* ]] || false
}

# CORRECTED 2026-08-12. An earlier version of this comment said this test relies on BSD `tail -r`
# and "would fail" on a GNU/Linux runner, treating that as acceptable by analogy with the #114
# stat split. It was not acceptable: the ubuntu `test` job runs `bats tests/*.bats`, which includes
# this file, so these tests ran on Linux and turned main red from the commit that added them.
#
# More importantly the analogy was backwards. #114's lesson was that a silently-empty result from a
# wrong-platform tool is a BUG, not a platform caveat to test around — `tail -r` on GNU emits
# nothing and exits nonzero with stderr suppressed, so `borg nanoprobes`/`nanoprobe-log`/`spend`/
# `watch` all rendered empty on Linux while looking like "no records yet". Fixed at the source via
# `_borg_reverse_lines` (borg.zsh); these tests now pass on both userlands and the ubuntu run is a
# deliberate portability canary rather than a known-failing duplicate.
@test "contract: nanoprobes renders fixture rows newest-first under zsh" {
    local log="$BORG_DIR/agents.jsonl"
    printf '{"id":"aaaa1111-1111-1111-1111-111111111111","agent_type":"borg-nanoprobe","summary":"Did the older thing","finished_at":"2026-08-01T10:00:00Z"}\n' > "$log"
    printf '{"id":"bbbb2222-2222-2222-2222-222222222222","agent_type":"borg-scout","summary":"Did the newer thing","finished_at":"2026-08-02T10:00:00Z"}\n' >> "$log"

    run_zsh_borg nanoprobes
    [ "$status" -eq 0 ]
    [[ "$output" == *"aaaa1111"* ]] || false
    [[ "$output" == *"bbbb2222"* ]] || false
    [[ "$output" == *"borg-nanoprobe"* ]] || false
    [[ "$output" == *"borg-scout"* ]] || false
    # Newest (bbbb2222) must render before the older (aaaa1111) row.
    [[ "$output" == *"bbbb2222"*"aaaa1111"* ]] || false
}

@test "contract: np alias reaches the same nanoprobes rendering as the full name" {
    local log="$BORG_DIR/agents.jsonl"
    printf '{"id":"cccc3333-3333-3333-3333-333333333333","agent_type":"borg-reviewer","summary":"np alias probe","finished_at":"2026-08-03T10:00:00Z"}\n' > "$log"

    run_zsh_borg np
    [ "$status" -eq 0 ]
    [[ "$output" == *"cccc3333"* ]] || false
    [[ "$output" == *"borg-reviewer"* ]] || false
}

@test "contract: nanoprobe-log with no argument errors with usage, no log needed" {
    run_zsh_borg nanoprobe-log
    [ "$status" -ne 0 ]
    [[ "$output" == *"usage: borg nanoprobe-log"* ]] || false
}

@test "contract: nanoprobe-log errors cleanly when agents.jsonl is absent" {
    run_zsh_borg nanoprobe-log some-id
    [ "$status" -ne 0 ]
    [[ "$output" == *"no nanoprobes recorded yet"* ]] || false
}

@test "contract: nanoprobe-log cats the transcript file when transcript_path exists" {
    local log="$BORG_DIR/agents.jsonl"
    local transcript="${BATS_TEST_TMPDIR}/transcript-dddd.txt"
    printf 'TRANSCRIPT-CONTENT-MARKER-12345\n' > "$transcript"
    printf '{"id":"dddd4444-4444-4444-4444-444444444444","agent_type":"borg-nanoprobe","summary":"has a transcript","finished_at":"2026-08-04T10:00:00Z","transcript_path":"%s"}\n' \
        "$transcript" > "$log"

    run_zsh_borg nanoprobe-log dddd4444
    [ "$status" -eq 0 ]
    [[ "$output" == *"TRANSCRIPT-CONTENT-MARKER-12345"* ]] || false
}

@test "contract: nanoprobe-log falls back to printing the JSON entry when no transcript_path" {
    local log="$BORG_DIR/agents.jsonl"
    printf '{"id":"eeee5555-5555-5555-5555-555555555555","agent_type":"borg-scout","summary":"no transcript here","finished_at":"2026-08-05T10:00:00Z"}\n' > "$log"

    run_zsh_borg nanoprobe-log eeee5555
    [ "$status" -eq 0 ]
    [[ "$output" == *'"agent_type": "borg-scout"'* ]] || false
}

@test "contract: nanoprobe-log errors cleanly on an id prefix with no match" {
    local log="$BORG_DIR/agents.jsonl"
    printf '{"id":"ffff6666-6666-6666-6666-666666666666","agent_type":"borg-nanoprobe","summary":"irrelevant","finished_at":"2026-08-06T10:00:00Z"}\n' > "$log"

    run_zsh_borg nanoprobe-log zzznotfound
    [ "$status" -ne 0 ]
    [[ "$output" == *"no nanoprobe matching 'zzznotfound'"* ]] || false
}

@test "contract: nanoprobe-log resolves an ambiguous prefix to the newest matching entry" {
    local log="$BORG_DIR/agents.jsonl"
    printf '{"id":"dupe1234-aaaa-older","agent_type":"borg-scout","summary":"OLDER-MARKER","finished_at":"2026-08-01T10:00:00Z"}\n' > "$log"
    printf '{"id":"dupe1234-bbbb-newer","agent_type":"borg-nanoprobe","summary":"NEWER-MARKER","finished_at":"2026-08-02T10:00:00Z"}\n' >> "$log"

    run_zsh_borg nanoprobe-log dupe1234
    [ "$status" -eq 0 ]
    [[ "$output" == *"NEWER-MARKER"* ]] || false
    [[ "$output" != *"OLDER-MARKER"* ]] || false
}

# cmd_spend already has exhaustive arithmetic/logic coverage in tests/spend.bats, but only via a bare
# `run "$BORG_CMD" spend` invocation that rides the shebang — never an explicit `zsh` interpreter,
# which is this whole suite's invariant. These two are deliberately lean: prove dispatch + render
# under a REAL zsh, not re-prove the math.

@test "contract: spend reports cleanly under zsh when token-spend.jsonl is absent" {
    run_zsh_borg spend
    [ "$status" -eq 0 ]
    [[ "$output" == *"No spend recorded"* ]] || false
    [[ "$output" != *"unknown command"* ]] || false
}

@test "contract: spend renders the main-vs-subagent header under zsh with a fixture" {
    mkdir -p "$HOME/.claude"
    printf '{"schema":1,"ts":"2026-08-01T10:00:00Z","session_id":"s-x","project":"x","cwd":"/x","end_reason":"clear","main":{"by_model":{},"est_cost_usd":5},"subagents":{"by_model":{},"agent_count":0,"est_cost_usd":1},"est_cost_usd":6}\n' \
        > "$HOME/.claude/token-spend.jsonl"

    run_zsh_borg spend
    [ "$status" -eq 0 ]
    [[ "$output" == *"Spend — main vs subagent split"* ]] || false
    [[ "$output" == *"THIS MACHINE only"* ]] || false
}

# cmd_watch (borg.zsh:2690) has no --once flag — it is a hardcoded `while true; do ...; sleep
# "$interval"; done`. `run_zsh_borg` / bats `run` block until the command exits, so it CANNOT be used
# here — it would hang the suite, and no `timeout`/`gtimeout` binary is assumed present on the target
# machines. Instead: background the real invocation with a generous interval so the loop cannot reach
# a second `sleep` cycle during the test, poll the redirected output file with a bounded, short-
# interval loop (no blind long sleep), then kill+wait unconditionally. Worst-case orphaned-child
# lifetime if `kill` somehow failed to land is bounded by the interval itself (30s) — short and
# self-cleaning, never a real hang. tmux is mocked because cmd_watch calls cmd_link ->
# borg_registry_with_state -> borg_reap_overlay -> _borg_live_windows -> the real `tmux` binary,
# unconditionally, even against an empty registry.
#
# THE POLL MUST WAIT FOR A COMPLETE FRAME, NOT FOR THE FIRST BYTE. This test failed 3/3 on the
# 2026-08-12 baseline and intermittently thereafter for a reason that had nothing to do with the code
# under test: `[ ! -s "$outfile" ]` goes false the moment the `BORG WATCH` header lands (borg.zsh:2646),
# but the assertions below also require `cmd_link`'s body (:2650) and the `RECENT NANOPROBES` section
# (:2653) — and `cmd_link` shells out to jq/tmux many times, so on a loaded runner the kill lands
# mid-frame and the later sections never get written. The wait condition has to be the LAST line a
# frame emits (`Ctrl-C to exit`, :2670); anything earlier is a race the assertions can lose. The
# ceiling is raised to 200 (10s) to give a slow runner room to finish one frame, and the interval to
# 30s so that ceiling still cannot reach a second frame — the invariant the paragraph above depends on.

@test "contract: watch dispatches into the live-refresh loop and renders under zsh (background+kill)" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$MOCK_BIN/tmux"

    local outfile="${BATS_TEST_TMPDIR}/watch.out"
    zsh "$BORG" watch 30 > "$outfile" 2>&1 &
    local pid=$!

    local waited=0
    while ! grep -q "Ctrl-C to exit" "$outfile" 2>/dev/null && [ "$waited" -lt 200 ]; do
        sleep 0.05
        waited=$((waited + 1))
    done

    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true

    [ -s "$outfile" ]
    local watch_output
    watch_output="$(cat "$outfile")"
    [[ "$watch_output" == *"BORG WATCH"* ]] || false
    [[ "$watch_output" == *"RECENT NANOPROBES"* ]] || false
    [[ "$watch_output" == *"No projects registered"* ]] || false
}

# cmd_doctor already has extensive coverage of its own launchd/freshness logic in tests/doctor.bats
# via a bare, non-explicit-zsh invocation. This contract test only needs to prove borg.zsh's "doctor"
# arm reaches cmd_doctor under a REAL zsh — mocking launchctl/docker per the drone_pane.bats
# convention so nothing touches the host's real launchd registrations or docker daemon.

@test "contract: doctor arm reaches cmd_doctor under zsh and renders the agent table" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    cat > "$MOCK_BIN/launchctl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$MOCK_BIN/launchctl"
    cat > "$MOCK_BIN/docker" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$MOCK_BIN/docker"

    run_zsh_borg doctor
    # All 4 launchd agents show MISSING against this empty mock registration list -> overall FAIL.
    [ "$status" -eq 1 ]
    [[ "$output" == *"AGENT"* ]] || false
    [[ "$output" == *"notifyd"* ]] || false
    [[ "$output" == *"MISSING"* ]] || false
    [[ "$output" != *"unknown command"* ]] || false
}

# cmd_reap wrapper had no prior coverage — tests/reap.bats only covers the lower-level
# _borg_should_reap / borg_reap_overlay predicates directly. tmux is mocked because
# borg_reap_persist -> borg_reap_overlay -> _borg_live_windows shells to the real `tmux` binary
# unconditionally, even against an empty registry.

@test "contract: reap reports nothing to reap against an empty registry" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$MOCK_BIN/tmux"

    run_zsh_borg reap
    [ "$status" -eq 0 ]
    [[ "$output" == *"Nothing to reap"* ]] || false
}

@test "contract: reap persists a stale active project to idle via state.json" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$MOCK_BIN/tmux"

    local proj_dir="${BATS_TEST_TMPDIR}/proj-stale"
    mkdir -p "$proj_dir/.borg"
    printf '{"status":"active","last_activity":"2020-01-01T00:00:00Z"}' > "$proj_dir/.borg/state.json"
    printf '{"projects":{"proj-stale":{"path":"%s","source":"cli"}}}' "$proj_dir" > "$BORG_REGISTRY"

    run_zsh_borg reap
    [ "$status" -eq 0 ]
    [[ "$output" == *"Reaped"* ]] || false
    [[ "$output" == *"proj-stale"* ]] || false
    [[ "$output" == *"1 stale session(s) downgraded to idle"* ]] || false

    local new_status
    new_status=$(jq -r '.status' "$proj_dir/.borg/state.json")
    [ "$new_status" = "idle" ]
}

# cmd_reap_worktrees had no prior CLI-level coverage — tests/reap_worktrees.bats only exercises
# lib/reaper.sh's _borg_worktree_is_stale / _borg_reap_worktrees directly, never the "borg
# reap-worktrees" arm or the registry-lookup wrapper around them. git is used for real here,
# unmocked, on a throwaway scratch repo under BATS_TEST_TMPDIR only — this mirrors the established,
# already-shipped convention in tests/reap_worktrees.bats, which is the only practical way to
# meaningfully exercise `git worktree` reaping; no real/host repo or remote is ever touched.
# BORG_WORKTREE_STATE_DIR is always overridden to a sandboxed path — its real-world default (see
# lib/reaper.sh) is an absolute path under the developer's actual ~/.local/state, and
# cmd_reap_worktrees must never be allowed to fall back to it.

@test "contract: reap-worktrees reports cleanly with no registered projects" {
    export BORG_WORKTREE_STATE_DIR="${BATS_TEST_TMPDIR}/borg-worktrees"
    run_zsh_borg reap-worktrees
    [ "$status" -eq 0 ]
    [[ "$output" == *"No registered projects found."* ]] || false
}

@test "contract: reap-worktrees errors cleanly on an unknown project name" {
    export BORG_WORKTREE_STATE_DIR="${BATS_TEST_TMPDIR}/borg-worktrees"
    run_zsh_borg reap-worktrees no-such-project
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown project 'no-such-project'"* ]] || false
}

@test "contract: reap-worktrees removes an age-expired worktree for a registered project" {
    export BORG_WORKTREE_STATE_DIR="${BATS_TEST_TMPDIR}/borg-worktrees"
    local repo="${BATS_TEST_TMPDIR}/repo-wt"
    mkdir -p "$repo" "$BORG_WORKTREE_STATE_DIR"
    git -C "$repo" init -q
    git -C "$repo" config user.email "test@test.com"
    git -C "$repo" config user.name "Test"
    echo init > "$repo/file.txt"
    git -C "$repo" add file.txt
    git -C "$repo" commit -q -m initial

    local repo_name="${repo##*/}"
    mkdir -p "${BORG_WORKTREE_STATE_DIR}/${repo_name}"
    local wt="${BORG_WORKTREE_STATE_DIR}/${repo_name}/feat-expired"
    git -C "$repo" worktree add -q "$wt" -b feat-expired
    touch -t 200001010000 "$wt"

    printf '{"projects":{"repo-wt":{"path":"%s","source":"cli"}}}' "$repo" > "$BORG_REGISTRY"

    run_zsh_borg reap-worktrees repo-wt
    [ "$status" -eq 0 ]
    # KNOWN BUG (found while writing this test, verified directly against a real zsh interpreter, not
    # introduced by it): lib/reaper.sh's removal loop globs "$wt_base"/*/ (trailing slash), so the
    # path it emits keeps that trailing slash; cmd_reap_worktrees's ${wt##*/} basename-strip in
    # borg.zsh therefore always yields an EMPTY worktree name in the "Reaped worktree ..." line (e.g.
    # "Reaped worktree  in repo-wt (stale (>12h))" with two spaces where the name should be).
    # Asserting on that empty segment would be asserting a display bug as a feature, so this test
    # checks the parts of the contract that are actually correct: the reason and repo name render,
    # and the worktree is actually gone on disk. Worth a follow-up ticket to fix `${wt##*/}` (or trim
    # the trailing slash in reaper.sh's printf) so `borg reap-worktrees` prints a useful name — out of
    # scope for this test-coverage pass.
    [[ "$output" == *"Reaped worktree"* ]] || false
    [[ "$output" == *"in repo-wt"* ]] || false
    [[ "$output" == *"stale"* ]] || false
    [[ "$output" == *"1 stale worktree(s) removed"* ]] || false
    [ ! -d "$wt" ]

    git -C "$repo" worktree remove --force "$wt" 2>/dev/null || true
}

# cmd_vinculum's pub/sub/ls/pull verb logic already has exhaustive coverage in tests/vinculum.bats and
# tests/vinculum-watch.bats. This contract test only needs to prove the top-level "vinculum"/"vinc"
# arm reaches cmd_vinculum's verb dispatch under a REAL zsh — using help, default-verb, and
# unknown-verb paths, which touch no tmux/watcher machinery (unlike sub/unsub, already covered
# elsewhere and deliberately not re-tested here). TMUX_PANE is unset defensively, matching
# tests/vinculum-watch.bats's own convention, even though none of the verbs exercised here read it.

@test "contract: vinculum help renders usage under zsh" {
    unset TMUX_PANE
    run_zsh_borg vinculum help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: borg vinculum"* ]] || false
    [[ "$output" != *"unknown command"* ]] || false
}

@test "contract: vinc alias reaches the same dispatch and errors cleanly on an unknown verb" {
    unset TMUX_PANE
    run_zsh_borg vinc bogus-verb
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown verb 'bogus-verb'"* ]] || false
    [[ "$output" == *"borg vinculum help"* ]] || false
}

@test "contract: bare vinculum with no verb defaults to ls and reports no channels" {
    unset TMUX_PANE
    run_zsh_borg vinculum
    [ "$status" -eq 0 ]
    [[ "$output" == *"No channels."* ]] || false
}

# ── tmux/session-interactive: switch, focus, init, claude, cortex-resume ─────────────────────────
# HIGHEST-RISK GROUP: these arms drive tmux directly or launch a real claude process. Every test
# below mocks tmux (and claude, where reached) via setup_mock_bin + BORG_PATH_PREFIX="$MOCK_BIN" —
# borg.zsh resets PATH from scratch at startup and only honors BORG_PATH_PREFIX for prepending, so
# plain `export PATH=...` from a test is silently discarded (see tests/briefing.bats, tests/doctor.bats
# for the established precedent). No test in this section ever leaves tmux/claude/cortex unmocked,
# even on the "clean failure" paths, because the registry-vs-live-tmux reap overlay shells out to
# `tmux has-session` on every registry read regardless of which project is being asked about — an
# unmocked tmux here would probe (or worse, actually drive) the real developer tmux session.

@test "contract: switch with a query matching exactly one registered project switches via tmux directly" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    export TRACE="${BATS_TEST_TMPDIR}/trace.log"
    : > "$TRACE"
    export TMUX_MOCK_HAS_SESSION=1
    # Guard against the interactive work/life boundary prompt (a `read -rk1`) ever firing here
    # regardless of what the host shell happens to export -- this project name should never be
    # a work project, but unsetting is cheap insurance against a hung test.
    unset BORG_WORK_PROJECTS
    _mock_tmux

    cat > "$BORG_REGISTRY" <<EOF
{
  "projects": {
    "demoproj": {
      "path": null,
      "source": "cli",
      "tmux_window": "demoproj",
      "summary": "Working on the thing."
    }
  }
}
EOF

    run_zsh_borg switch demoproj
    [ "$status" -eq 0 ]
    [[ "$output" == *"Switching to demoproj"* ]] || false
    run grep -c "tmux select-window -t borg:demoproj" "$TRACE"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

@test "contract: switch falls through to fzf and returns cleanly when no project matches" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    export TRACE="${BATS_TEST_TMPDIR}/trace.log"
    : > "$TRACE"
    _mock_tmux

    # Mock fzf as an Esc/cancel: cmd_switch's `selection=$(... | fzf ...) || return 0` must
    # take the graceful no-op path rather than crashing or hanging on a missing/real fzf.
    cat > "$MOCK_BIN/fzf" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
exit 1
EOF
    chmod +x "$MOCK_BIN/fzf"

    run_zsh_borg switch no-such-project-anywhere
    [ "$status" -eq 0 ]
    [[ "$output" != *"Switching to"* ]] || false
}

# cmd_focus is a one-line delegate to cmd_switch (borg.zsh: `cmd_focus() { cmd_switch "${@:-}"; }`).
# The direct-match / tmux-switch behavior is already proven above; this test instead exercises the
# no-live-session path per C4's literal "every arm" requirement, proving dispatch reaches cmd_focus
# (not cmd_switch called some other way) and that it fails cleanly rather than hanging or crashing
# when tmux has no session to switch into.

@test "contract: focus dispatches to switch and fails cleanly with no tmux session available" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    export TRACE="${BATS_TEST_TMPDIR}/trace.log"
    : > "$TRACE"
    export TMUX_MOCK_HAS_SESSION=0
    unset BORG_WORK_PROJECTS
    _mock_tmux

    cat > "$BORG_REGISTRY" <<EOF
{
  "projects": {
    "demoproj": {
      "path": null,
      "source": "cli",
      "tmux_window": null,
      "summary": "Working on the thing."
    }
  }
}
EOF

    run_zsh_borg focus demoproj
    [ "$status" -eq 0 ]
    [[ "$output" == *"No tmux window registered for demoproj"* ]] || false
    run grep -c "tmux has-session" "$TRACE"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

# Registry is deliberately left empty: _borg_print_briefing's early-return path
# ("No projects in registry. Run: borg scan") is the only way to safely exercise cmd_init without
# also needing to mock a `claude -p ...` LLM-briefing call -- a non-empty registry would route
# through that call too. TMUX is set (the direct-exec launch branch) so a real `claude` process is
# never spawned even in principle; only the mocked one on BORG_PATH_PREFIX is reachable.
# TMUX_MOCK_HAS_SESSION=1 also means cmd_init's own `if ! borg_tmux_alive; then tmux new-session -d
# ...` spawn branch is skipped entirely — the mocked "already alive" response prevents even a mocked
# `tmux new-session` invocation, let alone a real one.

@test "contract: init starts a tmux session when none is running and hands off to claude" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    export TRACE="${BATS_TEST_TMPDIR}/trace.log"
    : > "$TRACE"
    export TMUX_MOCK_HAS_SESSION=1
    _mock_tmux

    export TMUX="/tmp/tmux-mock/default,1234,0"
    export BORG_ORCHESTRATOR_ROOT="${BATS_TEST_TMPDIR}/orchestrator-root"
    mkdir -p "$BORG_ORCHESTRATOR_ROOT"

    cat > "$MOCK_BIN/claude" <<EOF
#!/usr/bin/env bash
echo "claude \$*" >> "$TRACE"
exit 0
EOF
    chmod +x "$MOCK_BIN/claude"

    run_zsh_borg init
    [ "$status" -eq 0 ]
    run grep -c "claude --name borg-orchestrator --append-system-prompt-file" "$TRACE"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

@test "contract: claude resumes the orchestrator session via claude --continue when invoked outside tmux" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    export TRACE="${BATS_TEST_TMPDIR}/trace.log"
    : > "$TRACE"
    unset TMUX
    export BORG_ORCHESTRATOR_ROOT="${BATS_TEST_TMPDIR}/orchestrator-root"
    mkdir -p "$BORG_ORCHESTRATOR_ROOT"
    # This branch writes a launcher script to $TMPDIR that a real tmux send-keys would later
    # exec-and-self-delete; the mock just logs the invocation and never runs it, so scope
    # TMPDIR into the sandbox to avoid leaving a stray borg-launch.*.zsh in the real temp dir.
    export TMPDIR="$BATS_TEST_TMPDIR"
    _mock_tmux

    run_zsh_borg claude
    [ "$status" -eq 0 ]
    [[ "$output" == *"Resuming orchestrator"* ]] || false
    run grep -c "tmux send-keys" "$TRACE"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
    run grep -c "tmux attach-session -t borg" "$TRACE"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

# KNOWN BUG (found while writing this contract test -- not introduced by it, verified directly
# against borg.zsh outside bats/mocking with `env -i ... TMUX=... zsh borg.zsh claude`, so it is
# not a mocking artifact). When `borg claude` runs from a shell that is ALREADY inside a tmux
# session ($TMUX set -- the common case in this environment, which runs almost everything under
# tmux with a Ctrl+Space prefix), cmd_claude reaches _borg_launch_in_tmux and correctly execs the
# resolved `claude --continue` binary (proven below), but the function's tail --
#     [[ -n "$cleanup_file" ]] && rm -f "$cleanup_file"
#     return
# -- always fails for cmd_claude specifically, because cmd_claude (unlike cmd_init) never sets
# cleanup_file. An empty guard makes that line's own exit status 1 ("false"), and because borg.zsh
# runs under `set -e`, errexit trips before the explicit `return` is reached -- so the function,
# and the whole script, exits 1 even though claude itself succeeded. This test pins the CURRENT
# (buggy) contract on purpose: a future fix should show up here as a status-code flip to 0, not as
# a silent, undetected regression either way.
@test "contract: claude reaches and execs claude --continue when already inside tmux (currently exits 1 -- known bug)" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    export TRACE="${BATS_TEST_TMPDIR}/trace.log"
    : > "$TRACE"
    export TMUX="/tmp/tmux-mock/default,1234,0"
    export BORG_ORCHESTRATOR_ROOT="${BATS_TEST_TMPDIR}/orchestrator-root"
    mkdir -p "$BORG_ORCHESTRATOR_ROOT"

    cat > "$MOCK_BIN/claude" <<EOF
#!/usr/bin/env bash
echo "claude \$*" >> "$TRACE"
exit 0
EOF
    chmod +x "$MOCK_BIN/claude"

    run_zsh_borg claude
    [ "$status" -eq 1 ]
    [[ "$output" == *"Resuming orchestrator"* ]] || false
    run grep -c "claude --continue" "$TRACE"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]
}

@test "contract: cortex-resume fails cleanly with no pending wakes state file" {
    run_zsh_borg cortex-resume
    [ "$status" -ne 0 ]
    [[ "$output" == *"no pending cortex wakes"* ]] || false
}

@test "contract: cortex-resume wakes the matching pane and drops the entry" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    export TRACE="${BATS_TEST_TMPDIR}/trace.log"
    : > "$TRACE"

    # list-panes -t %42 (existence probe) succeeds -> cmd_cortex_resume skips its
    # re-resolve-a-stale-pane-id fallback path and sends straight to %42.
    cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
echo "tmux $*" >> "$TRACE"
case "$1" in
    list-panes) exit 0 ;;
    send-keys)  exit 0 ;;
    *)          exit 0 ;;
esac
EOF
    chmod +x "$MOCK_BIN/tmux"

    cat > "$BORG_DIR/cortex-wakes.json" <<'EOF'
{
  "wakes": [
    {
      "pane_id": "%42",
      "project": "demoproj",
      "session": "borg",
      "window": "demoproj",
      "pane_index": "0"
    }
  ]
}
EOF

    run_zsh_borg cortex-resume demoproj
    [ "$status" -eq 0 ]
    [[ "$output" == *"sent 'wake up!' to demoproj"* ]] || false
    run grep -c "tmux send-keys -t %42 wake up! Enter" "$TRACE"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]

    run grep -c "demoproj" "$BORG_DIR/cortex-wakes.json"
    [ "$status" -ne 0 ]
}

# ── lifecycle / destructive-adjacent: sever(down), regenerate(tidy), setup, store-secret, ────────
# ── start ──────────────────────────────────────────────────────────────────────────────────────

# cmd_down tears down every borg tmux window + the tmux session itself, and can shell out to
# `drone down` / `docker compose down` / the shared stillpoint Supabase stack. Per CRITICAL SAFETY
# RULE #1/#2 this must never touch a REAL tmux server or docker daemon, regardless of what's actually
# running on the host at test time (e.g. a live "borg" tmux session on Noah's own machine). tmux,
# docker, and drone are all mocked via BORG_PATH_PREFIX — borg.zsh resets $PATH from scratch at
# startup, so a plain PATH export from the test would be silently discarded and a real tmux/docker
# elsewhere on $PATH would win.
#
# The mock tmux reports one alive session with one window that has no @project_dir option set, which
# routes cmd_down through its simpler "no project dir" branch (a direct tmux kill-window, skipping
# the interactive /borg-link-up checkpoint offer entirely — that path is exercised by unit-level
# coverage elsewhere, not needed again here). This proves the real teardown sequence (has-session ->
# list-windows -> per-window kill-window -> kill-session, plus the shared-Supabase docker inspect)
# actually fires against the real dispatch layer, entirely against mocks.
@test "contract: sever tears down mocked tmux/docker without touching real infrastructure" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    export BORG_TMUX_SESSION="borg"

    cat > "$MOCK_BIN/tmux" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "$MOCK_BIN/tmux.calls"
case "\$1" in
    has-session) exit 0 ;;
    list-windows) echo "testproj" ;;
    show-option) exit 1 ;;
esac
exit 0
EOF
    chmod +x "$MOCK_BIN/tmux"

    cat > "$MOCK_BIN/docker" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "$MOCK_BIN/docker.calls"
if [[ "\$1" == "inspect" ]]; then
    echo "false"
fi
exit 0
EOF
    chmod +x "$MOCK_BIN/docker"

    cat > "$MOCK_BIN/drone" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "$MOCK_BIN/drone.calls"
exit 0
EOF
    chmod +x "$MOCK_BIN/drone"

    run_zsh_borg sever

    [ "$status" -eq 0 ]
    local calls
    calls=$(cat "$MOCK_BIN/tmux.calls")
    [[ "$calls" == *"has-session -t borg"* ]] || false
    [[ "$calls" == *"kill-window -t borg:testproj"* ]] || false
    [[ "$calls" == *"kill-session -t borg"* ]] || false
}

# cmd_tidy archives projects idle >48h, but only after a `read -rk1` "Archive all? [y/N]"
# confirmation. zsh's `-k1` (single-keypress) read requires a real controlling terminal — under
# bats' non-interactive stdin it fails immediately, and because borg.zsh runs under `set -e`, the
# whole invocation dies right there. That makes the "stale project found" path safe to run for real
# against a sandboxed registry fixture: detection happens (proving the stale-scan logic and dispatch
# both work), but there is no reachable path in this suite to a real archive write.

@test "contract: regenerate reports no stale projects on a fresh, empty registry" {
    echo '{"projects":{}}' > "$BORG_REGISTRY"

    run_zsh_borg regenerate

    [ "$status" -eq 0 ]
    [[ "$output" == *"No stale projects"* ]] || false
}

@test "contract: regenerate finds a stale project and fails cleanly (non-interactive) without archiving it" {
    printf '{"projects":{"stale-proj":{"path":"/tmp/stale-proj","status":"idle","last_activity":"2020-01-01T00:00:00Z"}}}' \
        > "$BORG_REGISTRY"

    run_zsh_borg regenerate < /dev/null

    [ "$status" -ne 0 ]
    [[ "$output" == *"Stale projects"* ]] || false
    [[ "$output" == *"stale-proj"* ]] || false

    local registry_after
    registry_after=$(cat "$BORG_REGISTRY")
    [[ "$registry_after" != *"archived"* ]] || false
}

# cmd_setup is a first-run installer wizard: past its first prompt it can run a real dotfiles
# installer (a bash script from $BORG_HOME/dotfiles), offer `brew install`, register hooks with a
# real `cortex` CLI, chmod the real repo's own hooks/*.sh in place, and unconditionally shells out to
# scripts/build-plugin.sh — none of which are safe to actually let run here (CRITICAL SAFETY RULE
# #1/#2), and it takes no arguments and has no --dry-run flag to short-circuit into.
#
# `read -r _reply` at the very first wizard prompt ("Set up starter dotfiles?") returns nonzero on
# EOF, and because borg.zsh runs under `set -e`, the whole invocation dies right there — before the
# `if` that would even reference the dotfiles source, and long before hooks/skills/build-plugin are
# ever touched. That makes "run non-interactively" a genuinely safe, real contract test (same shape
# as the store-secret non-tty test below), not a dispatch-only fallback: confirmed by asserting no
# hooks/ or skills/ directory is created under the sandboxed $HOME/.claude afterward.
#
# HONEST GAP (from the drafting group, preserved): a full, faithfully-mocked end-to-end execution of
# cmd_setup (overriding BORG_HOME to a fixture dir, mocking cortex/tmux/fzf/nvim/brew) was
# investigated and rejected — with the default BORG_HOME (the real repo), cmd_setup runs
# `chmod +x "$BORG_HOME/hooks/"*.sh` unconditionally early in its hooks-install step, which mutates
# file mode bits on the REAL repo's own hook scripts (idempotent, but still a real filesystem touch
# outside BATS_TEST_TMPDIR). A fully safe alternative would need a from-scratch fixture mirroring
# lib/*.zsh, lib/*.sh, hooks/*.sh, skills/*, agents/*.md — more engineering/risk than this pass calls
# for. The hooks/skills/plugin-build install machinery inside cmd_setup remains untested beyond this
# safe non-interactive die path.
@test "contract: setup dispatches to cmd_setup and dies cleanly, non-interactively, before any install step" {
    run_zsh_borg setup < /dev/null

    [ "$status" -ne 0 ]
    [[ "$output" == *"Set up starter dotfiles?"* ]] || false
    [[ "$output" != *"unknown command"* ]] || false
    [ ! -d "$BORG_TEST_HOME/.claude/hooks" ]
    [ ! -d "$BORG_TEST_HOME/.claude/skills" ]
}

# cmd_store_secret writes to the real macOS Keychain via `security` — never safe to actually invoke
# (CRITICAL SAFETY RULE #2). It hard-requires an interactive terminal on stdin
# (`[[ -t 0 ]] || die ...`), checked immediately after arg validation and well before it ever touches
# `security`. bats' own invocation is exactly the non-interactive case this guards against, so this is
# a real, honest, safe contract test rather than something needing exotic mocking.

@test "contract: store-secret without a name errors on usage before touching the keychain" {
    run_zsh_borg store-secret

    [ "$status" -ne 0 ]
    [[ "$output" == *"usage: borg store-secret"* ]] || false
}

@test "contract: store-secret refuses to run non-interactively, before touching the keychain" {
    run_zsh_borg store-secret SOME_TEST_KEY < /dev/null

    [ "$status" -ne 0 ]
    [[ "$output" == *"interactive terminal"* ]] || false
}

# cmd_start promotes docs/plans/directives/<slug>.md to PROJECT_PLAN.md via `git mv` when the
# directive is git-tracked (falling back to a plain `mv` for untracked files). Tested against a
# fresh, throwaway git-initialized temp repo under BATS_TEST_TMPDIR — never the real borg-collective
# repo, and never with a bare `cd` in the test's own shell (which would leak across tests) — the cd
# happens inside a disposable `bash -c` subprocess instead.
#
# HONEST GAP (from the drafting group, preserved): only the git-tracked promotion path (`git mv`) is
# tested, not the untracked-file `mv` fallback branch. Per this repo's own docs/plans conventions,
# directives are checked into git before `borg start` promotes them, so the tracked path is the
# realistic case; a second full git-repo fixture purely to hit an `mv` one-liner was judged scope
# padding rather than a meaningful gap.

@test "contract: start promotes a tracked directive to PROJECT_PLAN.md via git mv" {
    local repo="${BATS_TEST_TMPDIR}/start_repo"
    mkdir -p "$repo/docs/plans/directives"
    git -C "$repo" init -q
    printf '# My Directive\n\nTest content.\n' > "$repo/docs/plans/directives/my-directive.md"
    git -C "$repo" add docs/plans/directives/my-directive.md
    git -C "$repo" -c user.email=test@example.com -c user.name=test commit -q -m "add directive"

    run bash -c "cd '$repo' && zsh '$BORG' start my-directive"

    [ "$status" -eq 0 ]
    [[ "$output" == *"in-flight: PROJECT_PLAN.md"* ]] || false
    [ -f "$repo/PROJECT_PLAN.md" ]
    [ ! -f "$repo/docs/plans/directives/my-directive.md" ]
}

@test "contract: start errors cleanly on a directive slug that does not exist" {
    local repo="${BATS_TEST_TMPDIR}/start_repo_missing"
    mkdir -p "$repo/docs/plans/directives"
    git -C "$repo" init -q

    run bash -c "cd '$repo' && zsh '$BORG' start no-such-directive"

    [ "$status" -ne 0 ]
    [[ "$output" == *"no such directive"* ]] || false
    [ ! -f "$repo/PROJECT_PLAN.md" ]
}

# ══════════════════════════════════════════════════════════════════════════════
# `borg link` PARITY HARNESS — Phase 0 of the Python-core port (PROJECT_PLAN A1)
#
# WHY THIS EXISTS. `borg link` is moving out of zsh into borg_core/link/ with human-readable output
# unchanged. A port needs contract tests written against TODAY's zsh that pass *unchanged* on
# Python — an edited assertion is not a parity proof (A4). Everything below is therefore written
# against the zsh implementation on `main` and must be green BEFORE any port work starts.
#
# HOW PARITY IS ASSERTED. The three primary renderers (--porcelain, overview, deep dive) are pinned
# with golden files under tests/fixtures/link/ and compared with `diff` on EXACT bytes — ANSI escape
# sequences, column padding and blank lines included. Substring assertions would pass against a
# renderer that quietly changed padding or dropped a color, which is precisely the drift this port
# can produce. Branch behavior that is time-, environment-, or exit-code-dependent is asserted
# directly instead, because a golden cannot express it.
#
# THE ONE NORMALIZATION. `$BATS_TEST_TMPDIR` is a fresh random path per run, and the deep dive
# prints the project's path. It is rewritten to `<TMP>` before the diff; nothing else is touched.
#
# DETERMINISM RULES followed by every fixture here:
#   - tmux is ALWAYS mocked. borg_reap_overlay shells out to the real tmux on every registry read,
#     so an unmocked `active` fixture is silently downgraded to `idle` (and probes the developer's
#     real session — CRITICAL SAFETY RULE #2).
#   - Modes that print a RAW timestamp (--porcelain, deep dive) use fixed ISO dates. The overview
#     prints a RELATIVE time, so its fixture timestamps are computed at run time and land in stable
#     buckets ("2h ago", "yesterday", "5d ago").
#   - The deep dive's summary is kept under 70 chars so `fold -s -w 70` is a no-op; GNU and BSD fold
#     do not agree on where to break, and this suite runs on both (ubuntu `test` + macos `contract`).
#
# REGENERATING GOLDENS: `BORG_UPDATE_GOLDEN=1 bats tests/cli_contract.bats`. Do NOT do this during
# the port. Regenerating is how a parity harness silently becomes a screenshot of the new behavior.
# ══════════════════════════════════════════════════════════════════════════════

LINK_GOLDEN_DIR="${BATS_TEST_DIRNAME}/fixtures/link"

# ISO-8601 UTC timestamp `$1` seconds in the past, computed at RUN time so the overview's relative
# -time column is stable in a golden. BSD takes an epoch via `-r`; GNU's `-r` means "reference file"
# and fails, falling through to `-d @epoch`. Same split as _borg_file_mtime / _borg_reverse_lines.
_link_iso_ago() {
    local secs="$1" now epoch
    now=$(date -u +%s)
    epoch=$((now - secs))
    date -u -r "$epoch" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
        || date -u -d "@$epoch" +"%Y-%m-%dT%H:%M:%SZ"
}

# Mock tmux so each project named in $1 (one per LINE) reads as a live window, exempting it from the
# reap overlay. TRACE must be exported before _mock_tmux's script runs: its `>> "$TRACE"` would
# otherwise fail to open and leak a shell error onto stderr, which the golden diff would catch as a
# spurious mismatch (same redirect-open-order trap documented in CLAUDE.md).
_link_mock_tmux() {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    export TRACE="${BATS_TEST_TMPDIR}/tmux-trace.log"
    : > "$TRACE"
    export TMUX_MOCK_HAS_SESSION=1
    export TMUX_MOCK_WINDOWS="$1"
    _mock_tmux
}

# Byte-compare a `borg link` invocation against tests/fixtures/link/<name>.golden.
_assert_link_golden() {
    local name="$1"; shift
    local raw="${BATS_TEST_TMPDIR}/${name}.raw" actual="${BATS_TEST_TMPDIR}/${name}.actual"
    zsh "$BORG" "$@" > "$raw" 2>&1
    sed "s|${BATS_TEST_TMPDIR}|<TMP>|g" "$raw" > "$actual"

    if [ -n "${BORG_UPDATE_GOLDEN:-}" ]; then
        mkdir -p "$LINK_GOLDEN_DIR"
        cp "$actual" "${LINK_GOLDEN_DIR}/${name}.golden"
    fi

    [ -f "${LINK_GOLDEN_DIR}/${name}.golden" ] || {
        echo "missing golden: ${name}.golden (regenerate with BORG_UPDATE_GOLDEN=1)" >&2
        false
    }
    run diff -u "${LINK_GOLDEN_DIR}/${name}.golden" "$actual"
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; false; }
}

# ── fixtures ─────────────────────────────────────────────────────────────────

# --porcelain and the deep dive print raw timestamps, so these are fixed dates. `alpha`'s summary is
# deliberately past 80 chars: _borg_link_porcelain cuts at 80 with NO ellipsis (the overview cuts at
# 50 WITH one), and the two limits have been silently different since the command was written.
#
# THREE PROJECTS SHARE THE IDLE+UNPINNED BUCKET ON PURPOSE. The sort has three keys (borg.zsh:255-262)
# and the third -- `last_activity` ASCENDING -- is only observable when two rows tie on the first two.
# With one project per bucket, reversing that key or dropping it entirely renders byte-identically,
# and "oldest first" is exactly the ordering a porter is most likely to assume is a bug and "fix".
# It is also the key that orders a REAL registry, where nearly every row is idle and unpinned.
# `golf` carries NO status field at all: borg_registry_with_state defaults it to "idle"
# (lib/registry.zsh:184), which is why _borg_link_porcelain's own `.status // "unknown"` fallback
# (borg.zsh:269) is unreachable in practice -- this pins the default that shadows it.
_link_registry_porcelain() {
    cat > "$BORG_REGISTRY" <<'EOF'
{
  "projects": {
    "alpha": {"path": null, "source": "cli", "status": "idle",
              "last_activity": "2026-08-01T10:00:00Z",
              "summary": "Alpha porcelain summary running well past the eighty character cut so truncation is pinned."},
    "bravo": {"path": null, "source": "desktop", "status": "waiting",
              "last_activity": "2026-08-02T10:00:00Z", "summary": "Bravo is waiting."},
    "charlie": {"path": null, "source": "coco", "status": "active",
                "last_activity": "2026-08-03T10:00:00Z", "summary": "Charlie is active."},
    "delta": {"path": null, "source": "cli", "status": "archived",
              "last_activity": "2026-08-04T10:00:00Z", "summary": "Delta is archived."},
    "echo": {"path": null, "source": "cli", "status": "idle", "pinned": true,
             "last_activity": "2026-08-05T10:00:00Z", "summary": "Echo is pinned."},
    "foxtrot": {"path": null, "source": "cli", "status": "idle",
                "last_activity": "2026-07-01T10:00:00Z", "summary": "Foxtrot ties alpha's bucket."},
    "golf": {"path": null, "source": "cli",
             "last_activity": "2026-06-01T10:00:00Z", "summary": "Golf has no status field."}
  }
}
EOF
}

# Workspaces backing the overview's two AGGREGATE sections. The fourth assimilated file exists so
# "newest 3 by filename DESC" is actually proven to drop one rather than just happening to fit.
_link_build_overview_ws() {
    local root="${BATS_TEST_TMPDIR}/ws"
    mkdir -p "$root/alpha/docs/plans/directives" "$root/alpha/docs/plans/assimilated" \
             "$root/bravo/docs/plans/directives" "$root/bravo/docs/plans/assimilated"

    printf '# Alpha directive one\n' > "$root/alpha/docs/plans/directives/2026-01-01-alpha-one.md"
    printf '# Alpha directive two\n' > "$root/alpha/docs/plans/directives/2026-01-02-alpha-two.md"
    printf '# Bravo directive\n'     > "$root/bravo/docs/plans/directives/2026-01-03-bravo-one.md"

    printf '# Alpha shipped first\nShipped: 2026-01-15\n' \
        > "$root/alpha/docs/plans/assimilated/2026-01-15-alpha-first.md"
    printf '# Alpha shipped old\nShipped: 2026-02-01\n' \
        > "$root/alpha/docs/plans/assimilated/2026-02-01-alpha-old.md"
    printf '# Bravo shipped\nShipped: 2026-02-02\n' \
        > "$root/bravo/docs/plans/assimilated/2026-02-02-bravo.md"
    printf '# Alpha shipped new\nShipped: 2026-02-03\n' \
        > "$root/alpha/docs/plans/assimilated/2026-02-03-alpha-new.md"
}

# Covers, in one render: the pin mark, the "waiting <<<" status decoration, all three source badges
# ([C]/[X]/[D]), the "(no summary)" default, the 50-char summary cut WITH ellipsis, the display_name
# override and its fallback, five relative-time buckets including "never", the idle+unpinned tie
# broken by last_activity ASC (see _link_registry_porcelain's note -- same reason), and both
# aggregate sections. active+waiting is 2, under the default BORG_MAX_ACTIVE=3, so the capacity
# warning stays out of this golden and is tested on its own.
#
# `just now` (<60s) is the one _borg_relative_time bucket deliberately NOT pinned in a golden: it has
# under a minute of headroom between fixture write and render, so a stalled runner would flip it to
# "1m ago" and fail on timing rather than on behavior. Every other bucket has >= 30 minutes of slack.
_link_registry_overview() {
    local root="${BATS_TEST_TMPDIR}/ws"
    local t_alpha t_bravo t_charlie t_echo t_foxtrot t_hotel
    t_alpha=$(_link_iso_ago 7200)      # "2h ago"
    t_bravo=$(_link_iso_ago 93600)     # "yesterday"
    t_charlie=$(_link_iso_ago 10800)   # "3h ago"
    t_echo=$(_link_iso_ago 432000)     # "5d ago"
    t_foxtrot=$(_link_iso_ago 1800)    # "30m ago"
    t_hotel=$(_link_iso_ago 172800)    # "2d ago"

    cat > "$BORG_REGISTRY" <<EOF
{
  "projects": {
    "alpha": {"path": "$root/alpha", "source": "cli", "status": "idle",
              "last_activity": "$t_alpha",
              "summary": "Alpha carries a long summary so the fifty character overview cut is pinned."},
    "bravo": {"path": "$root/bravo", "source": "desktop", "status": "waiting",
              "last_activity": "$t_bravo", "summary": "Bravo is waiting."},
    "charlie": {"path": null, "source": "coco", "status": "active",
                "last_activity": "$t_charlie"},
    "echo": {"path": null, "source": "cli", "status": "idle", "pinned": true,
             "last_activity": "$t_echo", "summary": "Echo is pinned."},
    "foxtrot": {"path": null, "source": "cli", "status": "idle",
                "last_activity": "$t_foxtrot", "summary": "Foxtrot ties alpha's bucket."},
    "golf": {"path": null, "source": "cli", "status": "idle",
             "summary": "Golf has never been active."},
    "hotel": {"path": null, "source": "cli", "status": "idle", "display_name": "Hotel Renamed",
              "last_activity": "$t_hotel", "summary": "Hotel renders under its display_name."},
    "india": {"path": null, "source": "cli", "status": "archived",
              "last_activity": "$t_hotel", "summary": "India is archived."}
  }
}
EOF
}

# Deep-dive workspace: every optional section populated at once.
#
# FIVE checkpoints, not three, and their mtimes deliberately CONTRADICT their filenames. The renderer
# does `find | sort -r | head -3` (borg.zsh:466) -- a sort by NAME, then a cap at 3 -- and then prints
# `head -20` of the first. With three same-length files whose mtimes agreed with their names, none of
# that was observable: a port that listed five, or sorted by mtime, or printed whole checkpoints,
# rendered byte-identically. Here the newest NAME (08-05) has the OLDEST mtime and carries 25 lines,
# so name-vs-mtime, the 3-cap and the 20-line cut each show up in the byte diff.
#
# Exactly ONE assimilated file, on purpose. Ordering there is a known bug this port is expected to
# FIX (_borg_read_assimilated's `(NOm)` -- see the dedicated flip test), and baking a 4-file ordering
# into the golden would mean fixing the bug forces a golden regeneration, which A4 rules out as a
# parity proof. The ordering fixture lives in _link_build_deep_assim_ws instead, feeding a substring
# test designed to flip.
_link_build_deep_ws() {
    local d="${BATS_TEST_TMPDIR}/ws/delta" i
    mkdir -p "$d/.borg/checkpoints" "$d/docs/plans/directives" "$d/docs/plans/assimilated"

    cat > "$d/PROJECT_PLAN.md" <<'EOF'
# Project Plan: Delta

## Objective

Keep the delta fixture stable so the deep dive renders identically on every run.

## Acceptance Criteria

- [x] First criterion, already met.
- [ ] Second criterion, outstanding.
- [ ] Third criterion, outstanding.
EOF

    printf '# Checkpoint one\n\nBody one.\n'   > "$d/.borg/checkpoints/2026-08-01-1000.md"
    printf '# Checkpoint two\n\nBody two.\n'   > "$d/.borg/checkpoints/2026-08-02-1000.md"
    printf '# Checkpoint three\n\nBody three.\n' > "$d/.borg/checkpoints/2026-08-03-1000.md"
    printf '# Checkpoint four\n\nBody four.\n'  > "$d/.borg/checkpoints/2026-08-04-1000.md"
    {
        printf '# Checkpoint five\n'
        for i in {2..25}; do printf 'body line %02d\n' "$i"; done
    } > "$d/.borg/checkpoints/2026-08-05-1000.md"
    # Newest name gets the oldest mtime and vice versa: proves the sort is by name, not mtime.
    touch -t 202601010000 "$d/.borg/checkpoints/2026-08-05-1000.md"
    touch -t 202602010000 "$d/.borg/checkpoints/2026-08-04-1000.md"
    touch -t 202603010000 "$d/.borg/checkpoints/2026-08-03-1000.md"
    touch -t 202604010000 "$d/.borg/checkpoints/2026-08-02-1000.md"
    touch -t 202605010000 "$d/.borg/checkpoints/2026-08-01-1000.md"

    printf '# Delta directive one\n' > "$d/docs/plans/directives/2026-04-01-delta-one.md"
    printf '# Delta directive two\n' > "$d/docs/plans/directives/2026-04-02-delta-two.md"

    printf '# Delta shipped only\nShipped: 2026-03-01\n' > "$d/docs/plans/assimilated/2026-03-01-delta-only.md"
}

# Replaces the single assimilated file with four, mtimes set explicitly because
# _borg_read_assimilated orders by mtime and file-creation order is not a contract. Used ONLY by the
# ordering test, so the deep-dive golden stays stable when the `(NOm)` bug is fixed.
_link_build_deep_assim_ws() {
    local d="${BATS_TEST_TMPDIR}/ws/delta"
    rm -f "$d/docs/plans/assimilated/"*.md
    printf '# Delta shipped A\nShipped: 2026-03-01\n' > "$d/docs/plans/assimilated/2026-03-01-delta-a.md"
    printf '# Delta shipped B\nShipped: 2026-03-02\n' > "$d/docs/plans/assimilated/2026-03-02-delta-b.md"
    printf '# Delta shipped C\nShipped: 2026-03-03\n' > "$d/docs/plans/assimilated/2026-03-03-delta-c.md"
    printf '# Delta shipped D\nShipped: 2026-03-04\n' > "$d/docs/plans/assimilated/2026-03-04-delta-d.md"
    touch -t 202603010000 "$d/docs/plans/assimilated/2026-03-01-delta-a.md"
    touch -t 202603020000 "$d/docs/plans/assimilated/2026-03-02-delta-b.md"
    touch -t 202603030000 "$d/docs/plans/assimilated/2026-03-03-delta-c.md"
    touch -t 202603040000 "$d/docs/plans/assimilated/2026-03-04-delta-d.md"
}

_link_registry_deep() {
    local d="${BATS_TEST_TMPDIR}/ws/delta"
    cat > "$BORG_REGISTRY" <<EOF
{
  "projects": {
    "delta": {
      "path": "$d",
      "source": "cli",
      "status": "active",
      "last_activity": "2026-08-03T10:00:00Z",
      "summary": "Delta keeps the deep dive deterministic.",
      "claude_session_id": "sess-delta-0001",
      "tmux_window": "delta"
    }
  }
}
EOF
}

# The whole deep-dive arrangement in one call. Mirrors _link_registry_busy's shape: folding the tmux
# mock into the fixture makes it unforgettable by construction rather than by three copies of the
# same three lines.
_link_setup_deep() {
    _link_mock_tmux "delta"
    _link_build_deep_ws
    _link_registry_deep
}

_link_setup_porcelain() {
    _link_mock_tmux $'bravo\ncharlie'
    _link_registry_porcelain
}

# Four projects -- three active plus one waiting -- each with a live window so none are reaped.
# _borg_active_count counts waiting AND active (borg.zsh:115), so the total is 4: one over the
# default BORG_MAX_ACTIVE=3, and exactly ON the limit when the tests override it to 4.
_link_registry_busy() {
    _link_mock_tmux $'p1\np2\np3\np4'
    cat > "$BORG_REGISTRY" <<'EOF'
{
  "projects": {
    "p1": {"path": null, "source": "cli", "status": "active", "last_activity": "2026-08-01T10:00:00Z"},
    "p2": {"path": null, "source": "cli", "status": "active", "last_activity": "2026-08-01T10:00:00Z"},
    "p3": {"path": null, "source": "cli", "status": "waiting", "last_activity": "2026-08-01T10:00:00Z"},
    "p4": {"path": null, "source": "cli", "status": "active", "last_activity": "2026-08-01T10:00:00Z"}
  }
}
EOF
}

# ── mode 1/4: --porcelain ────────────────────────────────────────────────────

@test "contract: link --porcelain renders byte-identically to its golden" {
    _link_setup_porcelain
    _assert_link_golden link-porcelain link --porcelain
}

# Archived projects are filtered out unless --all is passed; --all must also keep them LAST in the
# sort (status priority archived=3), not merely present somewhere in the listing.
@test "contract: link --porcelain --all admits archived projects and sorts them last" {
    _link_setup_porcelain

    run_zsh_borg link --porcelain
    [ "$status" -eq 0 ]
    [[ "$output" != *"delta"* ]] || false

    run_zsh_borg link --porcelain --all
    [ "$status" -eq 0 ]
    [[ "$output" == *"delta"* ]] || false
    [[ "$output" == *"alpha"*"delta"* ]] || false
}

# EXTERNAL CONSUMER (borg.zsh:689), stated precisely: cmd_switch's fzf call has TWO producers, and
# only one of them is `link`. The listing piped into fzf comes from `cmd_ls --porcelain`
# (borg.zsh:685) — a separate duplicate implementation that PROJECT_PLAN.md's scope boundaries keep
# in zsh — while `--preview "borg link {1}"` (borg.zsh:689) is the deep dive. So this pins both
# halves against the producer that actually feeds each: the 5-field/`--with-nth 1,3,5` shape against
# cmd_ls, and name-in-column-1-is-a-valid-deep-dive-argument against link.
#
# The two producers ALREADY diverge, which is why asserting the field shape against `link
# --porcelain` alone would have been asserting it in the wrong place: on an empty registry
# _borg_link_porcelain prints nothing (borg.zsh:264) while cmd_ls prints the human "No projects
# registered" line straight into the fzf stream (borg.zsh:528-531, before its porcelain branch).
@test "contract: the fzf picker's two producers each keep their half of the contract" {
    _link_setup_porcelain

    # cmd_ls --porcelain is what fzf reads. Sourced directly, as tests/cli_contract.bats already
    # does for _borg_file_mtime, because no CLI arm reaches it any more.
    run bash -c "zsh -c \"set -- help; source '$BORG' >/dev/null 2>&1; cmd_ls --porcelain\" | awk -F'\t' '{print NF}' | sort -u"
    [ "$status" -eq 0 ]
    [ "$output" = "5" ]

    # borg link --porcelain must keep the same shape: it is the surface the port carries forward.
    run bash -c "zsh '$BORG' link --porcelain | awk -F'\t' '{print NF}' | sort -u"
    [ "$status" -eq 0 ]
    [ "$output" = "5" ]

    # DO NOT CLOSE THIS PIPE EARLY. Reading column 1 of row 1 as `... | head -1 | cut -f1` is the
    # obvious spelling and it is the wrong one: `head` exits after the first line, the printf loop in
    # _borg_link_porcelain (borg.zsh:273) then takes EPIPE on the next row, and zsh reports that on
    # STDERR as `_borg_link_porcelain:printf:28: write error: broken pipe`. bats `run` merges stderr
    # into $output, so the comparison saw the row PLUS two zsh diagnostics. It failed on both CI lanes
    # while passing locally because whether the loop's next write loses the race to head's exit is
    # timing-dependent — the class of green-locally/red-on-CI bug this whole file exists to catch.
    # The two field-count assertions above are immune: awk and sort both drain to EOF, so nothing
    # closes the pipe early. Take the field from bats' own $lines instead, over the same unpiped
    # invocation shape the golden assertions already use.
    run_zsh_borg link --porcelain
    [ "$status" -eq 0 ]
    [ "${lines[0]%%$'\t'*}" = "echo" ] || {
        printf 'first field was [%s] (status %s)\n' "${lines[0]%%$'\t'*}" "$status" >&2
        printf -- '--- full porcelain, octal-escaped ---\n' >&2
        printf '%s\n' "$output" | od -c >&2
        false
    }

    # ...and that column-1 name must be something `borg link {1}` can render.
    run_zsh_borg link echo
    [ "$status" -eq 0 ]
    [[ "$output" == *"Session ID:"* ]] || false
}

# The empty-registry divergence noted above, pinned so the port cannot quietly adopt cmd_ls's
# behavior (which would push a human sentence into fzf's stream) or drop the silent-exit contract.
@test "contract: link --porcelain prints nothing at all on an empty registry" {
    _link_mock_tmux ""
    printf '%s' '{"projects":{}}' > "$BORG_REGISTRY"

    run_zsh_borg link --porcelain
    [ "$status" -eq 0 ]
    [ -z "$output" ]

    run bash -c "zsh -c \"set -- help; source '$BORG' >/dev/null 2>&1; cmd_ls --porcelain\""
    [[ "$output" == *"No projects registered"* ]] || false
}

# cmd_link's flag loop (borg.zsh:220-229) resolves porcelain BEFORE the project branch, so
# `--porcelain` wins over a project name; and the `*)` arm is last-wins, so `link a b` deep-dives b.
@test "contract: link flag precedence — porcelain beats a project name, last project name wins" {
    _link_setup_porcelain

    run_zsh_borg link --porcelain echo
    [ "$status" -eq 0 ]
    [[ "$output" == *$'\t'* ]] || false
    [[ "$output" != *"Session ID:"* ]] || false

    run_zsh_borg link alpha echo
    [ "$status" -eq 0 ]
    [[ "$output" == *"echo"* ]] || false
    [[ "$output" != *"Alpha porcelain summary"* ]] || false
}

# ── mode 2/4: overview ───────────────────────────────────────────────────────

@test "contract: link overview renders byte-identically to its golden" {
    _link_mock_tmux $'bravo\ncharlie'
    _link_build_overview_ws
    _link_registry_overview
    _assert_link_golden link-overview link
}

# The HUMAN --all path had no coverage at all: the only --all test went through --porcelain, and the
# all-archived test takes the early return before the table is ever built. So the archived ROW —
# its `*)` status-color arm (borg.zsh:353-354) and its position at the bottom of the sort — was
# unrendered by any test. Same fixture as the golden above; `india` is simply filtered out of it.
@test "contract: link overview --all renders archived rows byte-identically to its golden" {
    _link_mock_tmux $'bravo\ncharlie'
    _link_build_overview_ws
    _link_registry_overview

    run_zsh_borg link
    [[ "$output" != *"india"* ]] || false

    _assert_link_golden link-overview-all link --all
}

# The reap overlay (lib/registry.zsh:186) is the read-path downgrade: active/waiting with no live
# window and a stale last_activity renders as idle, without touching state.json. Every other fixture
# here mocks its projects as LIVE, which exempts them (lib/reaper.sh:24-26) — so with only those,
# deleting the overlay call entirely changed no assertion. This is the case that observes it.
@test "contract: link overview downgrades a stale active project with no live window to idle" {
    _link_mock_tmux "held"
    cat > "$BORG_REGISTRY" <<'EOF'
{
  "projects": {
    "ghosted": {"path": null, "source": "cli", "status": "active",
                "last_activity": "2020-01-01T00:00:00Z", "summary": "Stale and unwindowed."},
    "held": {"path": null, "source": "cli", "status": "active",
             "last_activity": "2020-01-01T00:00:00Z", "summary": "Stale but windowed."}
  }
}
EOF

    run_zsh_borg link
    [ "$status" -eq 0 ]
    # Strip ANSI so the status column can be matched as plain text. The ESC is written with bash
    # ANSI-C quoting rather than a `\x1b` escape inside the sed script: BSD sed does not understand
    # `\x1b`, so the GNU-only form would silently fail to strip on the macOS contract leg.
    local plain
    plain=$(printf '%s\n' "$output" | sed $'s/\033\\[[0-9;]*m//g')
    [[ "$plain" =~ ghosted[[:space:]]+\[C\][[:space:]]+idle ]] || false
    [[ "$plain" =~ held[[:space:]]+\[C\][[:space:]]+active ]] || false
}

# ONE project with an unparseable .borg/state.json used to blank the ENTIRE registry. jq's --argjson
# refuses the bad file, and the guard at lib/registry.zsh was `result=$(... | jq ...) ||
# result="$result"` — a no-op, because command substitution assigns BEFORE the `||` runs, so `result`
# was already empty when the fallback reassigned empty to empty. Every consumer of
# borg_registry_with_state saw an empty registry: `borg link` printed "No projects registered. Run:
# borg scan", and next/switch/init/reap/watch saw nothing either. A partial write from a hook or a
# killed session was enough. The healthy project must still receive its state overlay — asserted via
# `last_activity`, which exists ONLY in state.json here, so a merge that silently stopped merging
# would render "never".
@test "contract: link survives one project with a malformed state.json" {
    _link_mock_tmux ""
    local good="${BATS_TEST_TMPDIR}/ws/goodproj" bad="${BATS_TEST_TMPDIR}/ws/badproj"
    mkdir -p "$good/.borg" "$bad/.borg"
    printf '{"status":"idle","last_activity":"2026-08-01T10:00:00Z"}' > "$good/.borg/state.json"
    printf 'NOT JSON AT ALL' > "$bad/.borg/state.json"
    printf '{"projects":{"goodproj":{"path":"%s","source":"cli","summary":"Good."},"badproj":{"path":"%s","source":"cli","summary":"Bad."}}}' \
        "$good" "$bad" > "$BORG_REGISTRY"

    run_zsh_borg link
    [ "$status" -eq 0 ]
    [[ "$output" != *"No projects registered"* ]] || false
    [[ "$output" == *"goodproj"* ]] || false
    [[ "$output" == *"badproj"* ]] || false

    local plain
    plain=$(printf '%s\n' "$output" | sed $'s/\033\\[[0-9;]*m//g')
    # The overlay still ran for the healthy project: last_activity comes only from its state.json.
    [[ "$plain" != *"goodproj"*"never"* ]] || false
    # And nothing from the merge loop leaked onto stdout. A bare `local merged` inside that loop
    # re-declares an already-declared parameter, which zsh PRINTS — sending `merged=$'{...'` into the
    # caller's jq. Hit for real while fixing this; guarded here so it cannot come back.
    [[ "$output" != *"merged="* ]] || false
}

# The reap overlay used to match live windows with `grep -qx "$tw"` — no -F, so the window NAME was
# compiled as a basic regex. A project whose tmux_window is `troth.site` matched a live window named
# `troth-site` and was reported ALIVE while its session was dead. Domain-named projects are exactly
# the shape that hits it, and no test in the repo had ever exercised the match with a metacharacter.
#
# This also has to hold for the Python port: `name in live_windows` is a literal match, so leaving zsh
# on a regex would make the two implementations answer differently on the same registry — the
# divergence PROJECT_PLAN.md names as the port's top risk.
@test "contract: a live-window match is literal, not a regex" {
    _link_mock_tmux $'dotted-name\nplain'
    cat > "$BORG_REGISTRY" <<'EOF'
{
  "projects": {
    "dotted.name": {"path": null, "source": "cli", "status": "active",
                    "last_activity": "2020-01-01T00:00:00Z", "summary": "Regex bait."},
    "plain": {"path": null, "source": "cli", "status": "active",
              "last_activity": "2020-01-01T00:00:00Z", "summary": "Genuinely live."}
  }
}
EOF

    run_zsh_borg link
    [ "$status" -eq 0 ]

    local plain
    plain=$(printf '%s\n' "$output" | sed $'s/\033\\[[0-9;]*m//g')
    # `dotted.name` must NOT be rescued by the live window `dotted-name`.
    [[ "$plain" =~ dotted\.name[[:space:]]+\[C\][[:space:]]+idle ]] || false
    # ...while a genuine whole-string match still counts as live.
    [[ "$plain" =~ plain[[:space:]]+\[C\][[:space:]]+active ]] || false
}

# Same defect, same fix, in the other window-existence check the CLI uses (lib/tmux.zsh).
@test "contract: borg_tmux_window_exists matches a window name literally" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    has-session) exit 0 ;;
    list-windows) printf '%s\n' "dotted-name" ;;
esac
exit 0
EOF
    chmod +x "$MOCK_BIN/tmux"

    run zsh -c "set -- help; source '$BORG' >/dev/null 2>&1; borg_tmux_window_exists 'dotted.name'"
    [ "$status" -ne 0 ]

    run zsh -c "set -- help; source '$BORG' >/dev/null 2>&1; borg_tmux_window_exists 'dotted-name'"
    [ "$status" -eq 0 ]
}

@test "contract: link overview on an empty registry prints the scan hint and exits 0" {
    _link_mock_tmux ""
    printf '%s' '{"projects":{}}' > "$BORG_REGISTRY"

    run_zsh_borg link
    [ "$status" -eq 0 ]
    [[ "$output" == *"No projects registered. Run: borg scan"* ]] || false
}

@test "contract: link overview prints the discovery tip when only one project is registered" {
    _link_mock_tmux ""
    printf '%s' '{"projects":{"solo":{"path":null,"source":"cli","status":"idle"}}}' > "$BORG_REGISTRY"

    run_zsh_borg link
    [ "$status" -eq 0 ]
    [[ "$output" == *"run 'borg scan' to discover projects from session history"* ]] || false
}

# Distinct from the empty-registry branch above: projects EXIST but all are filtered out, so the
# hint points at --all rather than at scan. Two archived projects, not one, so the <=1 tip does not
# also fire and blur which branch produced the output.
@test "contract: link overview points at --all when every project is archived" {
    _link_mock_tmux ""
    printf '%s' '{"projects":{"a1":{"path":null,"status":"archived"},"a2":{"path":null,"status":"archived"}}}' \
        > "$BORG_REGISTRY"

    run_zsh_borg link
    [ "$status" -eq 0 ]
    [[ "$output" == *"No projects to show. Run: borg link --all"* ]] || false
}

@test "contract: link overview warns when active sessions exceed the default capacity" {
    _link_registry_busy

    run_zsh_borg link
    [ "$status" -eq 0 ]
    [[ "$output" == *"4 sessions need attention"* ]] || false
    [[ "$output" == *"(limit: 3)"* ]] || false
}

# A2 SEED. BORG_MAX_ACTIVE is assigned in borg.zsh WITHOUT `export`, so a `python3 -m` child inherits
# nothing — this asserts the knob is honored end to end and is the test that will catch it if the
# port forgets to pass it through. Under zsh today it passes because the var is read in-process.
#
# The positive anchors matter as much as the negative one: asserting only the ABSENCE of the warning
# would go green for any reason the overview rendered nothing at all — including the registry never
# reaching the child, which is precisely the failure this test exists to catch.
#
# The comparison is strict `>` (borg.zsh:408), so the boundary is the interesting value. 4-vs-3 fires
# and 4-vs-6 is silent, but BOTH of those hold under `>=` too; only 4-vs-4 tells them apart.
@test "contract: link overview honors an exported BORG_MAX_ACTIVE override, at and above the limit" {
    _link_registry_busy

    run env BORG_MAX_ACTIVE=6 zsh "$BORG" link
    [ "$status" -eq 0 ]
    [[ "$output" == *"p1"* ]] || false
    [[ "$output" == *"p4"* ]] || false
    [[ "$output" != *"sessions need attention"* ]] || false

    run env BORG_MAX_ACTIVE=4 zsh "$BORG" link
    [ "$status" -eq 0 ]
    [[ "$output" == *"p1"* ]] || false
    [[ "$output" != *"sessions need attention"* ]] || false

    run env BORG_MAX_ACTIVE=3 zsh "$BORG" link
    [ "$status" -eq 0 ]
    [[ "$output" == *"4 sessions need attention"* ]] || false
}

# The cortex pause row is the only per-project line rendered BELOW its own table row, and the only
# one sourced from outside the registry ($BORG_DIR/cortex-wakes.json). Its countdown is wall-clock
# derived, so it is asserted structurally rather than pinned in a golden.
@test "contract: link overview renders a cortex pause row under the paused project" {
    _link_mock_tmux ""
    # TWO projects, only one paused: the pause row is bound to its project by an awk join on the
    # project field (borg.zsh:374). With a single-project registry a port that printed the row under
    # EVERY project, or ignored the project field entirely, passed.
    printf '%s' '{"projects":{"awake":{"path":null,"source":"cli","status":"idle","summary":"Awake.","last_activity":"2026-08-01T10:00:00Z"},"paused":{"path":null,"source":"coco","status":"idle","summary":"Paused.","last_activity":"2026-08-02T10:00:00Z"}}}' \
        > "$BORG_REGISTRY"

    local future
    future=$(_link_iso_ago -7200)  # negative offset = two hours in the FUTURE, so a wake is pending
    printf '{"wakes":[{"project":"paused","reset_at":"%s"}]}\n' "$future" > "$BORG_DIR/cortex-wakes.json"

    run_zsh_borg link
    [ "$status" -eq 0 ]

    local plain
    plain=$(printf '%s\n' "$output" | sed $'s/\033\\[[0-9;]*m//g')
    # Pin the countdown's SHAPE, not just the label. `_borg_cortex_countdown` renders "?" when
    # _borg_iso_to_epoch fails (the BSD/GNU `date` fallback chain) and "now" when the wake is past —
    # both of which satisfy a bare "resumes in" match, so this is the only assertion here that can
    # detect that fallback breaking. +7200s always renders as 1h 59m or 2h 0m.
    [[ "$plain" =~ resumes\ in\ [0-9]+h\ [0-9]+m ]] || false
    # The row must follow `paused`, and `awake` must have no pause row at all.
    [[ "$plain" == *"paused"*"resumes in"* ]] || false
    printf '%s\n' "$plain" > "${BATS_TEST_TMPDIR}/plain.txt"
    run grep -c 'resumes in' "${BATS_TEST_TMPDIR}/plain.txt"
    [ "$output" = "1" ]
}

# ── mode 3/4: deep dive ──────────────────────────────────────────────────────

@test "contract: link <project> deep dive renders byte-identically to its golden" {
    _link_setup_deep
    _assert_link_golden link-deep link delta
}

# Every optional section is guarded by `[[ "$ppath" != "null" ]]`. A path-null project (the shape
# every Desktop-sourced entry has) must render the header block and NOTHING else — no plan, no
# checkpoints, no directives, no assimilated, and no error from reading a path that isn't there.
#
# It is also the only fixture that reaches the header's DEFAULT values (borg.zsh:433-436), so the
# assertions name the values, not just the labels: a port that dropped `// "(unknown)"` and printed
# an empty column still satisfies `*"Session ID:"*`.
@test "contract: link <project> deep dive omits every optional section for a path-null project" {
    _link_mock_tmux ""
    printf '%s' '{"projects":{"nopath":{"path":null,"source":"desktop","status":"idle"}}}' \
        > "$BORG_REGISTRY"

    run_zsh_borg link nopath
    [ "$status" -eq 0 ]

    local plain
    plain=$(printf '%s\n' "$output" | sed $'s/\033\\[[0-9;]*m//g')
    [[ "$plain" == *"Source:       desktop"* ]] || false
    [[ "$plain" == *"Last active:  (never)"* ]] || false
    [[ "$plain" == *"tmux window:  (none)"* ]] || false
    [[ "$plain" == *"Session ID:   (unknown)"* ]] || false
    [[ "$plain" == *"(no summary)"* ]] || false
    [[ "$plain" != *"Path:"* ]] || false
    [[ "$plain" != *"Active Plan"* ]] || false
    [[ "$plain" != *"Recent Checkpoints"* ]] || false
    [[ "$plain" != *"Directives:"* ]] || false
    [[ "$plain" != *"Recently assimilated"* ]] || false
}

# `fold -s -w 70` plus `sed '1!s/^/  /'` (borg.zsh:448) wraps a long summary and indents every
# continuation line. The golden fixture's summary is 41 chars precisely so fold is a no-op there
# (GNU and BSD fold disagree on break points, which would make a byte-exact golden platform-
# dependent) — which left the wrap and the indent pinned by nothing at all. Asserted structurally
# here so it holds on both userlands: more than one line, and every line after the first indented.
@test "contract: link <project> deep dive wraps and indents a summary longer than 70 columns" {
    _link_mock_tmux ""
    printf '%s' '{"projects":{"wordy":{"path":null,"source":"cli","status":"idle","summary":"This summary is deliberately far longer than seventy columns so that the fold pipeline has to break it across at least three separate rendered lines."}}}' \
        > "$BORG_REGISTRY"

    run_zsh_borg link wordy
    [ "$status" -eq 0 ]

    printf '%s\n' "$output" | sed $'s/\033\\[[0-9;]*m//g' | sed -n '/^  Summary$/,/^$/p' \
        | sed '1d;/^$/d' > "${BATS_TEST_TMPDIR}/summary.txt"

    run bash -c "cat '${BATS_TEST_TMPDIR}/summary.txt' | wc -l | tr -d ' '"
    [ "$output" -ge 2 ]

    # `fold -s` breaks after a blank and keeps it on the previous line, so continuation lines start
    # at column 0 until `sed '1!s/^/  /'` indents them to match the first line's two spaces. Drop the
    # sed and every line after the first starts flush left, which this catches.
    run bash -c "tail -n +2 '${BATS_TEST_TMPDIR}/summary.txt' | grep -cv '^  [^ ]'"
    [ "$output" = "0" ]
}

# FIXED BY THE PORT, as PROJECT_PLAN.md's signed Phase 1 deviation list records.
# `criteria_done=$(grep -c ... || echo 0)` (borg.zsh:459) used to capture BOTH grep's own "0" and
# the `|| echo 0` fallback when there was no match, because `grep -c` exits 1 on zero matches. The
# shell variable became the two-line string "0\n0" and the deep dive rendered
#   Progress: 0
#   0/2 criteria met
# across two lines. The golden fixture's leading `- [x]` is the only reason this never showed: a
# fresh plan with nothing completed — the common case — hit it every time. borg.zsh:458 mangled
# `criteria_total` the same way for a plan with no criteria at all. `core.plan_progress` returns
# ints, so the port renders this on one line, matching A4's amended text (cli_contract.bats:2078).
@test "contract: link <project> deep dive renders Progress on one line when no criteria are met" {
    _link_mock_tmux ""
    local d="${BATS_TEST_TMPDIR}/ws/nox"
    mkdir -p "$d"
    cat > "$d/PROJECT_PLAN.md" <<'EOF'
# Project Plan: Nox

## Objective

Nothing here is done yet.

## Acceptance Criteria

- [ ] First criterion, outstanding.
- [ ] Second criterion, outstanding.
EOF
    printf '{"projects":{"nox":{"path":"%s","source":"cli","status":"idle","summary":"Fresh plan."}}}' "$d" \
        > "$BORG_REGISTRY"

    run_zsh_borg link nox
    [ "$status" -eq 0 ]

    local plain
    plain=$(printf '%s\n' "$output" | sed $'s/\033\\[[0-9;]*m//g')
    [[ "$plain" == *"Progress: 0/2 criteria met"* ]] || false
}

@test "contract: link <project> dies non-zero on a project that is not registered" {
    _link_mock_tmux ""
    printf '%s' '{"projects":{"known":{"path":null,"status":"idle"}}}' > "$BORG_REGISTRY"

    run_zsh_borg link ghost-project
    [ "$status" -ne 0 ]
    [[ "$output" == *"project 'ghost-project' not in registry"* ]] || false
    [[ "$output" == *"Run: borg add"* ]] || false
}

# THE (NOm) FIX LANDED. borg.zsh's deep dive used to glob `(NOm)`: `om` is newest-first by mtime,
# and `O` REVERSES it, so the deep dive's "Recently assimilated" used to list the three OLDEST
# plans -- disagreeing with the overview's aggregate (filename DESC), so the two sections of one
# command answered "recent" differently. PROJECT_PLAN.md's signed Phase 1 deviation list records
# fixing this: borg_core/link/shell.py's read_assimilated sorts by filename DESC, the same key the
# aggregate already used, giving the JSON contract one ordering instead of two.
#
# The 4-file ordering fixture lives HERE and not in the golden's workspace on purpose. If the golden
# also encoded the buggy order, fixing the bug would have forced regenerating a parity golden
# mid-port -- exactly what A4 says is not a parity proof. This test was designed to flip and did.
@test "contract: link <project> assimilated is newest-first by filename (the (NOm) fix)" {
    _link_setup_deep
    _link_build_deep_assim_ws

    run_zsh_borg link delta
    [ "$status" -eq 0 ]
    [[ "$output" != *"Delta shipped A"* ]] || false
    [[ "$output" == *"Delta shipped B"* ]] || false
    [[ "$output" == *"Delta shipped C"* ]] || false
    [[ "$output" == *"Delta shipped D"* ]] || false
    [[ "$output" == *"Delta shipped D"*"Delta shipped C"* ]] || false
}

# ── mode 4/4: --brief ────────────────────────────────────────────────────────

# --brief stays in zsh this pass (PROJECT_PLAN scope boundary: _borg_print_briefing is contested
# ground with the briefing-fallback directive). What the port MUST preserve is the DISPATCH: the
# --brief arm of cmd_link reaches _borg_print_briefing rather than falling through to the overview.
#
# The empty-registry early return alone was not enough to prove that. It only exercises a function
# the plan puts out of scope, and it left `--llm` — the second name for this arm (borg.zsh:223,
# `--brief|--llm`) — untested anywhere, so dropping the alias in the port would silently reroute
# `borg link --llm` into the lenient `-*) shift` arm and render the overview instead, suite green.
# Mocking `claude` on BORG_PATH_PREFIX is this file's established way past a real LLM call, so the
# non-empty-registry path both names actually take is reachable.
@test "contract: link --brief and --llm both dispatch to the briefing path, not the overview" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    export TRACE="${BATS_TEST_TMPDIR}/tmux-trace.log"
    : > "$TRACE"
    export TMUX_MOCK_HAS_SESSION=1
    export TMUX_MOCK_WINDOWS=""
    _mock_tmux
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null 2>&1 || true
echo "BRIEFING-FROM-MOCKED-CLAUDE"
exit 0
EOF
    chmod +x "$MOCK_BIN/claude"

    printf '%s' '{"projects":{"solo":{"path":null,"source":"cli","status":"idle","summary":"Solo.","last_activity":"2026-08-01T10:00:00Z"}}}' \
        > "$BORG_REGISTRY"

    run_zsh_borg link --brief
    [ "$status" -eq 0 ]
    [[ "$output" == *"BRIEFING-FROM-MOCKED-CLAUDE"* ]] || false
    [[ "$output" != *"THE BORG COLLECTIVE"* ]] || false

    run_zsh_borg link --llm
    [ "$status" -eq 0 ]
    [[ "$output" == *"BRIEFING-FROM-MOCKED-CLAUDE"* ]] || false
    [[ "$output" != *"THE BORG COLLECTIVE"* ]] || false
}

# The empty-registry early return is a separate branch of the same arm: it must NOT reach `claude`.
@test "contract: link --brief on an empty registry returns early without an LLM call" {
    _link_mock_tmux ""
    printf '%s' '{"projects":{}}' > "$BORG_REGISTRY"

    run_zsh_borg link --brief
    [ "$status" -eq 0 ]
    [[ "$output" == *"No projects in registry. Run: borg scan"* ]] || false
    [[ "$output" != *"THE BORG COLLECTIVE"* ]] || false
}

# ── flag parity ──────────────────────────────────────────────────────────────

# cmd_link's `-*) shift` arm swallows ANY unknown flag and renders the overview at exit 0. A
# recon-shaped arm that `die`s on unknown flags would be a user-facing behavior change, so this pins
# the lenient behavior as the parity target. Both `--help` and a nonsense flag take the same path.
@test "contract: link tolerates an unknown flag and still renders the overview at exit 0" {
    _link_mock_tmux ""
    printf '%s' '{"projects":{"solo":{"path":null,"source":"cli","status":"idle","summary":"Solo."}}}' \
        > "$BORG_REGISTRY"

    run_zsh_borg link --totally-bogus
    [ "$status" -eq 0 ]
    [[ "$output" == *"THE BORG COLLECTIVE"* ]] || false

    run_zsh_borg link --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"THE BORG COLLECTIVE"* ]] || false
}

# ── external consumers ───────────────────────────────────────────────────────

# EXTERNAL CONSUMER (drone.zsh:964): `drone status` greps `Status:` out of the HUMAN deep dive and
# shows it as the `claude:<status>` column. That text format is an undeclared cross-CLI API with no
# test anywhere — break it and the column silently blanks. This runs drone's exact extraction
# pipeline against real `borg link` output.
#
# NOTE ON WHAT IS PINNED. borg.zsh emits color unconditionally (no isatty check), so the value drone
# actually captures today is a reset escape plus padding plus the status — `sed 's/.*Status:...'`
# stops at the ESC. Asserting those exact bytes would freeze an ANSI leak into the contract, so this
# asserts what drone's column depends on: the value ENDS in the status, and the deep dive emits
# exactly one `Status:` line for `grep -m1` to find. (An earlier `${#lines[@]} -eq 1` check here was
# vacuous — the pipeline's own `tr -d '\n'` guaranteed it.)
@test "contract: drone status can still extract Status: from the deep dive" {
    _link_setup_deep

    run bash -c "zsh '$BORG' link delta 2>/dev/null | grep -m1 'Status:' | sed 's/.*Status:[[:space:]]*//' | tr -d '\n'"
    [ "$status" -eq 0 ]
    [[ "$output" == *active ]] || false

    run bash -c "zsh '$BORG' link delta 2>/dev/null | grep -c 'Status:'"
    [ "$output" = "1" ]
}

# EXTERNAL CONSUMER (drone.zsh:1405): `drone link` is `exec borg link "${2:-${PWD##*/}}"`. It resolves
# `borg` from PATH, so this mocks `borg` (via BORG_DRONE_EXTRA_PATH, which drone.zsh honors after its
# own PATH reset) and asserts the forwarded argv — including the no-arg cwd-basename default, which
# is the ONLY caller that reaches _borg_link_deep's `${PWD##*/}` fallback.
@test "contract: drone link forwards the project name to borg link, defaulting to the cwd basename" {
    setup_mock_bin
    export TRACE="${BATS_TEST_TMPDIR}/borg-trace.log"
    : > "$TRACE"
    cat > "$MOCK_BIN/borg" <<'EOF'
#!/usr/bin/env bash
echo "borg $*" >> "$TRACE"
exit 0
EOF
    chmod +x "$MOCK_BIN/borg"

    local drone="${BATS_TEST_DIRNAME}/../drone.zsh"
    run zsh "$drone" link delta
    [ "$status" -eq 0 ]

    local cwd_proj="${BATS_TEST_TMPDIR}/ws/echo"
    mkdir -p "$cwd_proj"
    run bash -c "cd '$cwd_proj' && zsh '$drone' link"
    [ "$status" -eq 0 ]

    run cat "$TRACE"
    [[ "$output" == *"borg link delta"* ]] || false
    [[ "$output" == *"borg link echo"* ]] || false
}

# ── python child environment (_borg_py) ──────────────────────────────────────
#
# borg.zsh assigns every config variable it owns WITHOUT `export`: BORG_DIR (borg.zsh:24),
# BORG_MAX_ACTIVE / BORG_CORTEX_WAKES (borg.zsh:43-48), BORG_REGISTRY (lib/registry.zsh:15),
# BORG_TMUX_SESSION (lib/tmux.zsh:5), BORG_REAP_STALE_HOURS (lib/reaper.sh:11). An in-process zsh
# function sees all of them; a `python3 -m` child sees none.
#
# That shipped as a live defect: borg_core/recon/cli.py read BORG_REGISTRY from the environment with
# no fallback, so `borg recon` died with "borg recon: no registry at " on every real invocation
# except `--adapters` (which returns before the check). It was invisible to the whole test suite
# because everything that reaches the Python path puts BORG_REGISTRY in the environment ITSELF --
# tests/test_helper/setup.bash exports it, the pytest suites monkeypatch it -- so the inheritance
# path was never once executed under test. These two cases execute it.

@test "contract: recon resolves the registry with no BORG_REGISTRY in the environment" {
    run zsh -c "unset BORG_REGISTRY BORG_DIR; '$BORG' recon --sources deliberately-no-such-source"
    [ "$status" -ne 0 ]
    # Dying at adapter selection instead of the registry check is the proof it got that far.
    [[ "$output" != *"no registry at"* ]] || false
    [[ "$output" == *"no adapters matched"* ]] || false
}

# Mocks python3 itself and dumps the child's environment, so this asserts what the CHILD receives
# rather than what the parent happens to hold. Also pins that a caller-supplied value is carried
# through rather than the default being hardcoded -- which is the A2 mechanism the link port needs.
@test "contract: the python3 dispatch wrapper hands borg's config surface to the child" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    export ENVDUMP="${BATS_TEST_TMPDIR}/child-env.txt"
    cat > "$MOCK_BIN/python3" <<'EOF'
#!/usr/bin/env bash
env > "$ENVDUMP"
exit 0
EOF
    chmod +x "$MOCK_BIN/python3"

    run zsh "$BORG" rm some-project
    [ "$status" -eq 0 ]
    [ -f "$ENVDUMP" ]

    local var
    for var in BORG_DIR BORG_REGISTRY BORG_MAX_ACTIVE BORG_REAP_STALE_HOURS BORG_TMUX_SESSION \
               BORG_CORTEX_WAKES PYTHONPATH; do
        run grep -c "^${var}=" "$ENVDUMP"
        [ "$status" -eq 0 ]
        [ "$output" -ge 1 ]
    done

    run grep '^BORG_MAX_ACTIVE=' "$ENVDUMP"
    [ "$output" = "BORG_MAX_ACTIVE=3" ]

    run env BORG_MAX_ACTIVE=7 zsh "$BORG" rm some-project
    [ "$status" -eq 0 ]
    run grep '^BORG_MAX_ACTIVE=' "$ENVDUMP"
    [ "$output" = "BORG_MAX_ACTIVE=7" ]
}

# ── meta ─────────────────────────────────────────────────────────────────────

# The threshold used to be `>= 8` against a bare `grep -c 'zsh'`, which also matched every mention of
# `borg.zsh`/`drone.zsh` in prose. With 160+ matches it would still have passed after deleting every
# test in the file. This counts actual INVOCATIONS instead, and sits just under the current count so
# it fails on a real deletion rather than on adding one more test.
@test "contract: this suite actually invokes zsh (guards against a well-meaning refactor)" {
    run bash -c "grep -cE 'run_zsh_borg|zsh \"\\\$BORG\"|zsh -c|zsh '\\''\\\$BORG'\\''' '${BATS_TEST_DIRNAME}/cli_contract.bats'"
    [ "$status" -eq 0 ]
    [ "$output" -ge 60 ]
}

# ── Phase 2: the borg link --json seam (A3) ─────────────────────────────────

@test "contract: link --json emits a document whose order and projects agree" {
    _link_setup_porcelain

    run bash -c "zsh '$BORG' link --json | jq -e '.projects and .generated_at and (.order | length) == (.projects | length)'"
    [ "$status" -eq 0 ]

    run bash -c "zsh '$BORG' link --json | jq -r '.order | length'"
    [ "$status" -eq 0 ]
    [ "$output" = "6" ]  # delta (archived) is filtered out

    run bash -c "zsh '$BORG' link --json | jq -r '.version'"
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
}

@test "contract: link --json orders pinned first, then status, then last_activity ascending" {
    _link_setup_porcelain

    run bash -c "zsh '$BORG' link --json | jq -r '.order | join(\",\")'"
    [ "$status" -eq 0 ]
    [ "$output" = "echo,bravo,charlie,golf,foxtrot,alpha" ]
}

@test "contract: link --json --all restores archived projects to both order and projects" {
    _link_setup_porcelain

    run bash -c "zsh '$BORG' link --json --all | jq -r '.order | length'"
    [ "$status" -eq 0 ]
    [ "$output" = "7" ]

    run bash -c "zsh '$BORG' link --json --all | jq -r '.order[-1]'"
    [ "$status" -eq 0 ]
    [ "$output" = "delta" ]

    run bash -c "zsh '$BORG' link --json --all | jq -r '.projects.delta.status'"
    [ "$status" -eq 0 ]
    [ "$output" = "archived" ]

    run bash -c "zsh '$BORG' link --json --all | jq -r '.show_all'"
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

@test "contract: link --json stdout stays valid JSON when the registry write warning fires, and the focus path never triggers it" {
    if [ "$(id -u)" -eq 0 ]; then
        skip 'chmod force is a no-op for root'
    fi
    _link_setup_deep
    mkdir -p "$BORG_DIR/desktop"
    printf '{}' > "$BORG_DIR/desktop/one.json"
    chmod a-w "$BORG_DIR"

    # STEP 1 (anti-vacuity guard): the human path really does splice the warning onto stdout.
    zsh "$BORG" link --porcelain > "${BATS_TEST_TMPDIR}/p.out" 2> "${BATS_TEST_TMPDIR}/p.err"
    run grep -c 'registry write blocked' "${BATS_TEST_TMPDIR}/p.out"
    [ "$status" -eq 0 ]
    [ "$output" -ge 1 ]

    # STEP 2: the overview --json shape stays clean JSON and the warning lands on stderr instead.
    zsh "$BORG" link --json > "${BATS_TEST_TMPDIR}/j.out" 2> "${BATS_TEST_TMPDIR}/j.err"
    [ -s "${BATS_TEST_TMPDIR}/j.out" ]
    run bash -c "jq -e '.projects and .generated_at' < '${BATS_TEST_TMPDIR}/j.out'"
    [ "$status" -eq 0 ]
    run grep -c 'registry write blocked' "${BATS_TEST_TMPDIR}/j.out"
    [ "$output" -eq 0 ]
    run grep -c 'registry write blocked' "${BATS_TEST_TMPDIR}/j.err"
    [ "$output" -ge 1 ]

    # STEP 3: the desktop pre-pass is gated off the focus shape, so no warning appears at all.
    zsh "$BORG" link --json delta > "${BATS_TEST_TMPDIR}/f.out" 2> "${BATS_TEST_TMPDIR}/f.err"
    run grep -c 'registry write blocked' "${BATS_TEST_TMPDIR}/f.err"
    [ "$output" -eq 0 ]
    run bash -c "jq -e '.focus.name' < '${BATS_TEST_TMPDIR}/f.out'"
    [ "$status" -eq 0 ]

    chmod u+w "$BORG_DIR"
}

@test "contract: link --json <project> adds a focus block and leaves the deep dive alone" {
    _link_setup_deep

    run bash -c "zsh '$BORG' link --json delta | jq -r '.focus.name'"
    [ "$status" -eq 0 ]
    [ "$output" = "delta" ]

    run bash -c "zsh '$BORG' link --json delta | jq -r '.focus.plan.met'"
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]

    run bash -c "zsh '$BORG' link --json delta | jq -r '.focus.plan.total'"
    [ "$status" -eq 0 ]
    [ "$output" = "3" ]

    run bash -c "zsh '$BORG' link --json delta | jq -r '.focus.checkpoints | length'"
    [ "$status" -eq 0 ]
    [ "$output" = "3" ]

    run bash -c "zsh '$BORG' link --json delta | jq -r '.focus.checkpoints[0]'"
    [ "$status" -eq 0 ]
    [ "$output" = "2026-08-05-1000.md" ]

    run bash -c "zsh '$BORG' link --json delta | jq -r '.focus.directives | length'"
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
}

@test "contract: link --json --refresh keeps cmd_scan's info lines off stdout" {
    printf '%s' '{"projects":{"solo":{"path":null,"source":"cli","status":"idle","summary":"Solo."}}}' \
        > "$BORG_REGISTRY"

    zsh "$BORG" link --json --refresh > "${BATS_TEST_TMPDIR}/r.out" 2> "${BATS_TEST_TMPDIR}/r.err"
    run bash -c "jq -e '.projects and .generated_at' < '${BATS_TEST_TMPDIR}/r.out'"
    [ "$status" -eq 0 ]

    local word
    for word in Scanning Refreshing 'summary updated'; do
        run grep -c "$word" "${BATS_TEST_TMPDIR}/r.out"
        [ "$output" -eq 0 ]
    done
}

@test "contract: link --json dies on an unknown project with empty stdout" {
    printf '%s' '{"projects":{}}' > "$BORG_REGISTRY"

    run bash -c "zsh '$BORG' link --json ghost > '${BATS_TEST_TMPDIR}/o' 2> '${BATS_TEST_TMPDIR}/e'"
    [ "$status" -eq 1 ]
    [ ! -s "${BATS_TEST_TMPDIR}/o" ]
    run grep -c 'not in registry' "${BATS_TEST_TMPDIR}/e"
    [ "$output" -ge 1 ]
}

@test "contract: the link --json arm dispatches through the python3 config wrapper" {
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    export ENVDUMP="${BATS_TEST_TMPDIR}/link-child-env.txt"
    cat > "$MOCK_BIN/python3" <<'EOF'
#!/usr/bin/env bash
env > "$ENVDUMP"
exit 0
EOF
    chmod +x "$MOCK_BIN/python3"

    run zsh "$BORG" link --json
    [ "$status" -eq 0 ]
    [ -f "$ENVDUMP" ]

    local var
    for var in BORG_DIR BORG_REGISTRY BORG_MAX_ACTIVE BORG_REAP_STALE_HOURS BORG_TMUX_SESSION \
               BORG_CORTEX_WAKES BORG_NO_REAP PYTHONPATH; do
        run grep -c "^${var}=" "$ENVDUMP"
        [ "$status" -eq 0 ]
        [ "$output" -ge 1 ]
    done
}

@test "contract: link without --json still routes to the zsh renderer (the four goldens, unmodified)" {
    # Regression gate for Phase 2: the four EXISTING golden assertions, run again explicitly, must
    # still pass byte-for-byte with zero edits to this file's earlier golden tests.
    _link_setup_porcelain
    _assert_link_golden link-porcelain link --porcelain

    _link_mock_tmux $'bravo\ncharlie'
    _link_registry_overview
    _link_build_overview_ws
    _assert_link_golden link-overview link

    _link_mock_tmux $'bravo\ncharlie'
    _link_registry_overview
    _link_build_overview_ws
    _assert_link_golden link-overview-all link --all

    _link_setup_deep
    _assert_link_golden link-deep link delta
}

# ── Phase 3 entry gate ───────────────────────────────────────────────────────
#
# Three tests closing gaps a post-merge depth audit measured on the merged Phase 2 code (#134). See
# PROJECT_PLAN.md, "Phase 3 entry gate", for the full evidence for each. This file may only be
# APPENDED to (A4) -- nothing above this marker was touched to add these.

# Test 1 (part 2/2 -- part 1/2 is the parametrized pytest boundary assert in
# borg_core/link/test_core.py). The pytest half pins core.capacity() directly; this half proves the
# same boundary is reachable end to end through the real CLI on the --json path, which is what a
# user/skill actually observes. `_link_registry_busy` gives 4 active-or-waiting projects with live
# tmux windows (so none are reaped out from under the count), matching borg.zsh:408's semantics
# `(( active_count > BORG_MAX_ACTIVE ))`.
@test "contract: link --json reports capacity.over_limit on the strict > boundary" {
    _link_registry_busy

    run bash -c "env BORG_MAX_ACTIVE=4 zsh '$BORG' link --json | jq -r '.capacity.over_limit'"
    [ "$status" -eq 0 ]
    [ "$output" = "false" ]

    run bash -c "env BORG_MAX_ACTIVE=3 zsh '$BORG' link --json | jq -r '.capacity.over_limit'"
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

# Test 2. `.order` (the JSON/core.py path) and column 1 of a LIVE `link --porcelain` render (the
# zsh/jq path, borg.zsh:299-310) must agree on display order for the SAME fixture -- the exact
# fixture and exact command (`_link_setup_porcelain` + `link --porcelain`) that produces
# tests/fixtures/link/link-porcelain.golden. Deliberately NOT read from the frozen golden file: that
# static text only changes on a deliberate `BORG_UPDATE_GOLDEN=1` regeneration, so it cannot observe
# a mutation to the zsh/jq ranking table -- only a live re-render can. Neither side here is a
# hand-typed literal; both are read from a live command, which is what makes this catch BOTH
# directions: a `core.py` rank swap (breaks the json side vs. the still-correct zsh side) and a
# `borg.zsh` jq rank swap (breaks the zsh side vs. the still-correct json side).
#
# `jq -r '.order | join(",")'` and `awk`/`paste` over the porcelain output both fully drain their
# input -- no `head`/`grep -q` early close -- so this does not hit the zsh-EPIPE-under-bats-`run`
# trap documented at the top of this file.
@test "contract: link --json .order agrees with a live link --porcelain column-1 order" {
    _link_setup_porcelain

    local zsh_order json_order
    run bash -c "zsh '$BORG' link --porcelain | awk -F'\t' '{ print \$1 }' | paste -sd, -"
    [ "$status" -eq 0 ]
    zsh_order="$output"
    [ -n "$zsh_order" ]

    run bash -c "zsh '$BORG' link --json | jq -r '.order | join(\",\")'"
    [ "$status" -eq 0 ]
    json_order="$output"
    [ -n "$json_order" ]

    [ "$zsh_order" = "$json_order" ]
}

# Test 3. `status` is the field this tool exists to report, and the reap overlay is what keeps it
# honest when a session dies without a live window. `_link_mock_tmux ""` gives zero live windows, so
# `stale1` (status active, last_activity in 2020) is a reap candidate under the default
# BORG_REAP_STALE_HOURS=12 per lib/reaper.sh:_borg_should_reap. Unlike bats:2452 (which only greps
# the variable NAME out of a mocked python3's env dump), this asserts the VALUE end to end through a
# real borg_core execution, mirroring the A2 test's shape (bats:2298-2304).
@test "contract: link --json reaps a stale active project to idle, and BORG_NO_REAP restores it" {
    _link_mock_tmux ""
    printf '%s' '{"projects":{"stale1":{"path":null,"source":"cli","status":"active","last_activity":"2020-01-01T00:00:00Z"}}}' \
        > "$BORG_REGISTRY"

    run bash -c "zsh '$BORG' link --json | jq -r '.projects.stale1.status'"
    [ "$status" -eq 0 ]
    [ "$output" = "idle" ]

    run bash -c "env BORG_NO_REAP=1 zsh '$BORG' link --json | jq -r '.projects.stale1.status'"
    [ "$status" -eq 0 ]
    [ "$output" = "active" ]
}
