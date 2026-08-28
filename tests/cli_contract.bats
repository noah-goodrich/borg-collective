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

# PROBED THROUGH A SHAPE THAT ACTUALLY DISPATCHES. Until 2026-08-26 this ran `borg link --help`,
# which fell into _borg_link_dispatch's lenient `-*)` arm and rendered the whole overview. S4 gave
# `--help` an explicit arm that returns at the TOP of the function, so the same invocation now
# touches no dispatch arm at all. Measured: replacing the entire overview arm with
# `die "overview deleted by mutation"` left this case AND its cli_smoke twin green. `--local`
# because a bare `borg link` sweeps the network post-S3; the seeded registry because the empty
# default short-circuits to "No projects registered" before any document is built. The `--help`
# WORDING is asserted separately, by the AC1 case further down this file.
@test "contract: link is still dispatched and is not itself reported as removed" {
    _link_mock_tmux ""
    printf '%s' '{"projects":{"solo":{"path":null,"source":"cli","status":"idle","summary":"Solo."}}}' \
        > "$BORG_REGISTRY"

    run_zsh_borg link --local
    [ "$status" -eq 0 ]
    [[ "$output" == *"THE BORG COLLECTIVE"* ]] || false
    [[ "$output" == *"solo"* ]] || false
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

# ── AC1: `recon` retires as a human-facing verb, engine intact (2026-08-26) ───
# The 2026-08-10 removals above deleted whole commands. This one is narrower and the difference is
# the whole test: the HUMAN digest retires, the MACHINE surface survives, because `borg recon --json`
# and `borg recon --adapters` have real consumers (skills/borg-recon/SKILL.md, merge-tree/gather.py,
# evals/s4-k3/run.sh) that AC1 never asked to break.

@test "contract: bare recon exits non-zero and points at 'borg link' (AC1)" {
    run_zsh_borg recon
    [ "$status" -ne 0 ]
    [[ "$output" == *"borg link"* ]] || false
}

@test "contract: a recon modifier alone is not a machine flag (AC1)" {
    # --since/--projects/--sources modify a mode, they do not select one. Without this, moving the
    # gate ahead of the parse loop -- or setting the machine flag from any recognised flag -- reads
    # correctly and leaves the human digest reachable.
    #
    # ALL THREE MODIFIERS, DRIVEN OFF ONE LIST, so the case and its own comment cannot drift apart
    # again. --sources was the one originally left out, and it was not a theoretical gap: adding
    # `_recon_machine=1;` to borg.zsh's `--sources)` arm was measured to leave all 143 cases in this
    # file GREEN while `borg recon --sources github` rendered the full retired human digest
    # ("Recon sweep — since ...", 14 repos, exit 0) on a machine with real adapters.
    local -a probes=(
        "--since 2026-01-01T00:00:00Z"
        "--projects nosuchproject"
        "--sources github"
    )
    local probe
    for probe in "${probes[@]}"; do
        # Deliberately unquoted: each element is a flag plus its value, two argv words.
        # shellcheck disable=SC2086
        run_zsh_borg recon $probe
        [ "$status" -ne 0 ] || { echo "modifier '$probe' reached the engine" >&2; false; }
        [[ "$output" == *"borg link"* ]] || false
        [[ "$output" == *"was retired"* ]] || false
    done
}

@test "contract: bare module invocation agrees with 'borg recon' (AC2)" {
    # The retirement gate lives in borg_core/recon/cli.py::main() now (S4 originally put it in
    # borg.zsh's dispatch arm). This is the one bats case that reaches the module directly instead
    # of going through the zsh wrapper, so it is the only guard that a fix at the zsh layer alone
    # (leaving `python3 -m borg_core.recon.cli` ungated) would not catch.
    # See docs/plans/assimilated/2026-08-26-recon-retirement-gate-altitude.md.
    run_zsh_borg recon
    local zsh_status="$status"
    local zsh_output="$output"
    [ "$zsh_status" -ne 0 ]
    [[ "$zsh_output" == *"borg link"* ]] || false

    run bash -c "PYTHONPATH='${BATS_TEST_DIRNAME}/..' python3 -m borg_core.recon.cli"
    [ "$status" -ne 0 ]
    [[ "$output" == *"borg link"* ]] || false
    [[ "$output" == *"was retired"* ]] || false
}

@test "contract: the recon MACHINE surface survives the retirement (AC1)" {
    # THE SURVIVAL CONTROL. Without it, "bare recon dies" is satisfied by deleting the verb
    # outright, which is the one implementation of this change that breaks four other bats cases,
    # the /borg-recon skill, and the merge-tree pipeline.
    #
    # ASSERT ON THE MESSAGE, NOT ON THE EXIT CODE, for --json: setup_temp_dirs neutralizes
    # BORG_RECON_ADAPTER_PATH to an empty directory, so the ENGINE's own "no recon adapters found"
    # die is what a healthy machine surface produces here — and it is the proof the engine was
    # reached at all, because the retirement gate fires in borg.zsh before any Python runs and says
    # something else entirely. (The two #113 cases above run --adapters with the real search path.)
    printf '%s' '{"projects":{}}' > "$BORG_REGISTRY"

    run_zsh_borg recon --json
    [[ "$output" != *"was retired"* ]] || false
    [[ "$output" == *"no recon adapters found"* ]] || false

    run_zsh_borg recon --adapters
    [ "$status" -eq 0 ]
    [[ "$output" != *"was retired"* ]] || false
    [[ "$output" == *"No recon adapters found on:"* ]] || false
}

@test "contract: recon --help is the retirement's discoverability path, not a dead end (AC1)" {
    # `--help` is the one shape a human who typed `borg recon` out of habit will try next, and after
    # S4 it is NEW user-facing output with no other coverage: the three cases above run bare recon,
    # a lone modifier, and the two machine flags. Drop the `-h|--help)` arm and `--help` falls to the
    # `*)` catch-all, which prints "unknown flag '--help' (see borg recon --help)" -- an instruction
    # to re-run the command that just failed -- at exit 1, with no mention of `borg link`. The whole
    # suite stays green through that. The 2026-08-10 removal this retirement is modeled on is pinned
    # by cli_smoke.bats for exactly this reason.
    run_zsh_borg recon --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"borg link"* ]] || false
    [[ "$output" == *"--json"* ]] || false
    [[ "$output" == *"--adapters"* ]] || false
    [[ "$output" != *"unknown flag"* ]] || false

    run_zsh_borg recon -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"borg link"* ]] || false
}

@test "contract: every runnable borg-recon line in the skill carries a machine flag (AC1)" {
    # THE CONSUMER THE RETIREMENT SPARED, GATED. skills/borg-recon/SKILL.md is named in three
    # comments in this change as the reason the engine survives, and it is the one file carrying a
    # pass-through flag list. Before S4 it authorized `--since`/`--projects`/`--sources` as
    # standalone flags; every one of those shapes now dies at exit 1, and the failure is invisible to
    # every other test here because the skill is prose an agent reads at RUNTIME.
    #
    # FENCED CODE BLOCKS ONLY. The prose deliberately quotes the retired shapes as counter-examples
    # ("never `borg recon --since ...`"), so a whole-file grep would be permanently red. The fenced
    # blocks are what an agent copies.
    run awk '/^```/{f=!f; next} f && /borg recon/' \
        "${BATS_TEST_DIRNAME}/../skills/borg-recon/SKILL.md"
    [ "$status" -eq 0 ]
    # ANTI-VACUITY: a skill that stopped invoking the engine at all would otherwise pass.
    [ "${#lines[@]}" -ge 1 ]
    local l
    for l in "${lines[@]}"; do
        [[ "$l" == *"--json"* || "$l" == *"--adapters"* ]] \
            || { echo "retired recon shape in SKILL.md: $l" >&2; false; }
    done
}

# PROJECT_PLAN.md asks for this mechanically: "bats asserts `borg help` is net one command shorter
# than at plan start."
#
# WHY 26, AND HOW TO RE-DERIVE IT. Plan start is `b984616^` (= 638b7c4), the parent of the commit
# that landed PROJECT_PLAN.md. 638b7c4's own subject says "feat(S4): land the viz-program manifest"
# — that is a DIFFERENT plan's S4; it is the plan-start ref by ancestry, not by name. Both it and
# the pre-S4 HEAD render 27 COMMANDS entries:
#     git show 638b7c4:borg.zsh | awk '/^  COMMANDS$/{f=1;next} f && /^  [A-Z]/{f=0} \
#                                      f && /^    [a-z]/{n++} END{print n+0}'   # -> 27
# S4 deletes exactly one entry (`recon`, plus its five 26-space continuation lines) and adds no
# verb. 27 - 1 = 26. If this goes red, ask which entry moved, not what the number is.
#
# WHY A COUNT AND NOT A SUBSTRING. cli_smoke.bats records the exact trap from the 2026-08-10
# removal: `[[ "$output" == *"ls"* ]]` stayed green afterwards because the REMOVED block still names
# the removed commands. "recon" likewise still appears in `borg help` after S4 — in the REMOVED
# block and in `program`'s `--recon <file>` line. Only a count discriminates.
#
# WHY THE SECTION SLICE. `borg help | grep -c '^    [a-z]'` over the WHOLE output is 32, not 27: the
# REMOVED body and the four STATUS entries share the 4-space entry shape. The awk range is what
# keeps this honest, and `^  [A-Z]` (any section header) rather than `^  REMOVED` is what keeps it
# honest if the REMOVED heading is ever retitled again.
@test "contract: borg help is net one command shorter than at plan start (AC1)" {
    # 25 SINCE THE 2026-08-27 RETIREMENT, and the criterion is still satisfied: AC1 asks for "net one
    # command shorter than at plan start", which is a FLOOR on shrinkage, not a target to hit exactly.
    # 27 at plan start, -1 for `recon` (S4), -1 for `watch`
    # (2026-08-27-retire-unused-link-surfaces.md: zero typed invocations in six months of shell
    # history). No verb has been added at any point. If this goes red, ask which entry moved.
    run bash -c "zsh '$BORG' help | awk '/^  COMMANDS\$/{f=1;next} f && /^  [A-Z]/{f=0} f && /^    [a-z]/{n++} END{print n+0}'"
    [ "$status" -eq 0 ]
    [ "$output" = "25" ]
}

# The count alone reaches 26 if someone deletes `doctor` instead of `recon` — and four dispatch
# verbs (color, image, focus, vinculum) have no COMMANDS entry, so a well-meaning "document these
# while I'm here" edit cancels the arithmetic in the other direction. This names the entry.
@test "contract: recon is gone from COMMANDS and named in REMOVED (AC1)" {
    run bash -c "zsh '$BORG' help | awk '/^  COMMANDS\$/{f=1;next} f && /^  [A-Z]/{f=0} f && /^    [a-z]/{print \$1}'"
    [ "$status" -eq 0 ]
    [[ "$output" != *recon* ]] || false
    [[ "$output" == *link* ]] || false
    [[ "$output" == *doctor* ]] || false

    run bash -c "zsh '$BORG' help | sed -n '/^  REMOVED/,/^  HOTKEY/p'"
    [ "$status" -eq 0 ]
    [[ "$output" == *recon* ]] || false
    [[ "$output" == *"borg link"* ]] || false
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
#   - The deep dive's summary is kept under 70 chars so `fold -s -w 70` is a no-op; this leaves the
#     wrap path itself unexercised by this golden (a known weakness, not a strength) — see the wrap
#     assertion comment at ~:2030 for why wrap output is pinned structurally rather than byte-exact.
#
# REGENERATING GOLDENS: `BORG_UPDATE_GOLDEN=1 bats tests/cli_contract.bats`. Regeneration is
# legitimate only when the output change is the deliberate, intended result of a change you made —
# review the resulting diff line by line. Never regenerate to make a failure disappear.
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
#
# WHAT KEEPS THESE REPRODUCIBLE NOW THAT `link` SWEEPS (B7). Two things, and only two:
#   1. setup_temp_dirs points BORG_RECON_ADAPTER_PATH at an empty directory, so zero adapters are
#      discovered, no `since` is resolved and no subprocess runs. Without it these four goldens
#      would byte-capture whatever GitHub returned that minute — and `BORG_UPDATE_GOLDEN=1` would
#      freeze one machine's network state as the oracle.
#   2. render.py does not print any part of `grid`. The sweep lands in the DOCUMENT only, so the
#      human output these goldens capture is byte-identical to what it was pre-S3.
#
# AC2 LANDED AND (2) IS NOW FALSE — render.document prints the grid. These four goldens keep working
# on (1) ALONE, and deliberately so: none of their fixture registries carries a `.borg/programs`
# directory, so `selected_refs` is empty, `start_fetch` returns before forking, and the only
# sweep-derived text in them is the deterministic
# `sweep: no recon adapters found on <TMP>/no-adapters` warning. That warning is the LIVE TRIPWIRE
# for setup_temp_dirs' adapter neutralization, which is why the sweep fixture is NOT exported
# globally here: doing so would replace it with a "replayed from fixture" line in every link test and
# delete the only thing that notices if adapter discovery starts finding the developer's real
# adapters. The manifest-bearing goldens have their own helper, `_assert_link_grid_golden`, which
# exports both seams.
#
# THE SCRUB HAS THREE EXPRESSIONS, not one. `$BATS_TEST_TMPDIR` is a fresh random path per run and the
# IN FOCUS card prints the project's path; `$BATS_TEST_DIRNAME` is this checkout's `tests/` directory
# and reaches the page through the fixture-replay warnings, which name their fixture by ABSOLUTE
# path. With only the first expression the grid goldens would be green on the authoring machine and
# red everywhere else — the class of bug that is invisible precisely where it is being tested.
#
# The third normalizes the IN FOCUS card's RAW `Last active:` value, and it is addressed to that ONE
# LINE rather than applied globally: `--porcelain` emits raw timestamps as its actual contract and
# its golden must keep pinning them byte for byte. See `_link_registry_deep` for why a fixed fixture
# date stopped being the deterministic choice the moment one page carried both the raw form and the
# board's relative one.
_assert_link_golden() {
    local name="$1"; shift
    local raw="${BATS_TEST_TMPDIR}/${name}.raw" actual="${BATS_TEST_TMPDIR}/${name}.actual"
    zsh "$BORG" "$@" > "$raw" 2>&1
    sed -e "s|${BATS_TEST_TMPDIR}|<TMP>|g" \
        -e "s|${BATS_TEST_DIRNAME}|<TESTS>|g" \
        -e '/Last active:/ s|[0-9-]\{10\}T[0-9:]\{8\}Z|<TS>|g' "$raw" > "$actual"

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

# `last_activity` MOVED FROM A FIXED DATE TO A RUN-TIME ONE IN AC2, and the reason is that one
# document now prints BOTH forms of it. Pre-AC2 the deep dive printed only the RAW timestamp, so a
# fixed date was the deterministic choice; post-AC2 the same page also carries the board, whose
# LAST ACTIVE column is relative -- and `core.relative_time`'s day bucket is `diff // 86400` with no
# saturation, so a fixed date renders "24d ago" today and "25d ago" tomorrow. Run-time now, landing
# in a stable bucket, with `_assert_link_golden` scrubbing the raw form. Either half alone leaves
# this golden failing on a calendar.
_link_registry_deep() {
    local d="${BATS_TEST_TMPDIR}/ws/delta" t_delta
    t_delta=$(_link_iso_ago 10800)  # "3h ago"
    cat > "$BORG_REGISTRY" <<EOF
{
  "projects": {
    "delta": {
      "path": "$d",
      "source": "cli",
      "status": "active",
      "last_activity": "$t_delta",
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

# ══════════════════════════════════════════════════════════════════════════════
# AC2 — the topological grid, in BOTH contexts, against two new goldens
# ══════════════════════════════════════════════════════════════════════════════
#
# ONE HARNESS, TWO CONTEXTS, THE SAME FIXTURES. That is what "the two contexts differ in breadth
# only" has to mean to be checkable: the same workspace, the same manifests, the same recorded sweep
# and fetch, rendered from a repository and from the workspace root, and the difference between the
# two goldens is a row set — never a header, never an order, never a section.
#
# WHAT IS RECORDED AND WHY IT IS THE FAN-OUT'S OUTPUT RATHER THAN THE FINISHED GRID.
# `sweep-acme.json` is `{"since", "tracks": [<recon track>]}` — exactly what recon.shell.fanout
# returns — so the Item validator, the resolve ladder, level assignment and the per-source receipt
# all still run on production code between the fixture and the page. A fixture of the finished grid
# would prove that JSON round-trips. `fetch-acme.json` records the ANSWERS for the same reason;
# see grid.replayed_items for why a raw GraphQL body would be the wrong depth.
#
# THE FETCH RECORDING COVERS ALL ELEVEN DECLARED REFS, not only the three the sweep omits, because
# that is what an unconditional targeted fetch actually asks for (cli._grid starts it over
# `selected_refs`, before the sweep, so it cannot be narrowed to "what the sweep missed"). The sweep
# still wins for the eight it answered — `resolve_state`'s ladder is swept > fetched > declared — so
# eight nodes read `state: from the sweep` and three read `from a targeted fetch`, and a precedence
# inversion moves eight lines of both goldens.

# Two sandbox repositories with REAL git origins, the two fixture manifests, and a seven-project
# registry. Mirrors the shape a live machine has: a manifest declaring rows across three
# repositories lives under exactly ONE of them, and a repository with a git origin and no manifest
# (ledger) is the modal case — 13 of ~14 registered repositories.
#
# `infra` deliberately has NO git repository, so `borg link infra` exercises the first of the three
# CHAINS diagnoses (no origin -> nothing to scope a chain to) without a fixture of its own.
_link_build_grid_ws() {
    local root="${BATS_TEST_TMPDIR}/ws" p
    export BORG_ORCHESTRATOR_ROOT="$root"

    for p in platform warehouse ledger; do
        mkdir -p "$root/$p"
        git -C "$root/$p" init -q >/dev/null 2>&1
        git -C "$root/$p" remote add origin "https://github.com/acme/${p}.git" >/dev/null 2>&1
    done
    mkdir -p "$root/infra" "$root/atlas" "$root/relay" "$root/archive-tools"

    mkdir -p "$root/platform/.borg/programs" "$root/warehouse/.borg/programs"
    cp "${LINK_GOLDEN_DIR}/manifests/auth-hardening.json" "$root/platform/.borg/programs/"
    cp "${LINK_GOLDEN_DIR}/manifests/warehouse-rollout.json" "$root/warehouse/.borg/programs/"

    mkdir -p "$root/platform/docs/plans/directives" "$root/platform/docs/plans/assimilated" \
             "$root/warehouse/docs/plans/directives" "$root/warehouse/docs/plans/assimilated" \
             "$root/atlas/docs/plans/directives" \
             "$root/ledger/docs/plans/directives" "$root/ledger/docs/plans/assimilated"

    printf '# Scope keypair rotation to the warehouse tier\n' \
        > "$root/platform/docs/plans/directives/2026-08-21-scope-keypair-rotation.md"
    printf '# Retire password auth from the inventory service\n' \
        > "$root/platform/docs/plans/directives/2026-08-22-retire-password-auth.md"
    printf '# Schedule the eu maintenance window\n' \
        > "$root/warehouse/docs/plans/directives/2026-08-23-schedule-eu-window.md"
    printf '# Decide the tenant schema split\n' \
        > "$root/atlas/docs/plans/directives/2026-08-24-tenant-schema-split.md"
    printf '# Nightly close: move the reconciliation to the worker\n' \
        > "$root/ledger/docs/plans/directives/2026-08-25-nightly-close-worker.md"

    printf '# Base migration for scoped tokens\nShipped: 2026-08-20\n' \
        > "$root/platform/docs/plans/assimilated/2026-08-20-base-migration.md"
    printf '# Region cutover runbook\nShipped: 2026-08-18\n' \
        > "$root/warehouse/docs/plans/assimilated/2026-08-18-region-cutover-runbook.md"
    printf '# Close-of-day parity harness\nShipped: 2026-08-17\n' \
        > "$root/ledger/docs/plans/assimilated/2026-08-17-close-of-day-parity.md"

    _link_registry_grid
}

# The seven-repository registry the board renders in BOTH contexts.
#
# NO CORTEX PAUSE ROW HERE, deliberately. Its countdown is wall-clock derived and cannot be pinned in
# a golden without pinning a timing race; it keeps its own structural case ("link overview renders a
# cortex pause row under the paused project"). active+waiting is 4 against the default
# BORG_MAX_ACTIVE=3, so the capacity warning DOES land in SIGNALS in both goldens — capacity is a
# property of the registry, not of the scope, and rendering it in only one context would be the
# breadth rule leaking into a section it does not govern.
_link_registry_grid() {
    local root="${BATS_TEST_TMPDIR}/ws"
    local t_platform t_warehouse t_infra t_ledger t_atlas t_relay
    t_platform=$(_link_iso_ago 7200)     # "2h ago"
    t_warehouse=$(_link_iso_ago 93600)   # "yesterday"
    t_infra=$(_link_iso_ago 10800)       # "3h ago"
    t_ledger=$(_link_iso_ago 1800)       # "30m ago"
    t_atlas=$(_link_iso_ago 432000)      # "5d ago"
    t_relay=$(_link_iso_ago 172800)      # "2d ago"

    cat > "$BORG_REGISTRY" <<EOF
{
  "projects": {
    "platform": {"path": "$root/platform", "source": "cli", "status": "active", "pinned": true,
                 "last_activity": "$t_platform", "tmux_window": "platform",
                 "claude_session_id": "sess-platform-0007",
                 "summary": "Scoped keypair auth rollout."},
    "warehouse": {"path": "$root/warehouse", "source": "desktop", "status": "waiting",
                  "last_activity": "$t_warehouse",
                  "summary": "Key cutover blocked on the rollout run."},
    "infra": {"path": "$root/infra", "source": "coco", "status": "active",
              "last_activity": "$t_infra"},
    "ledger": {"path": "$root/ledger", "source": "cli", "status": "idle",
               "last_activity": "$t_ledger", "summary": "Nightly close reconciliation."},
    "atlas": {"path": "$root/atlas", "source": "cli", "status": "waiting",
              "last_activity": "$t_atlas", "summary": "Waiting on a schema decision."},
    "relay": {"path": "$root/relay", "source": "cli", "status": "idle",
              "last_activity": "$t_relay", "summary": "Relay has no summary yet."},
    "archive-tools": {"path": "$root/archive-tools", "source": "cli", "status": "idle",
                      "summary": "Nothing here since the fork."}
  }
}
EOF
}

# The whole grid arrangement in one call, tmux mock included so it cannot be forgotten. The four
# active/waiting projects need live windows or the reap overlay silently downgrades them to idle and
# the board's status column — and the capacity count — stop describing the fixture.
#
# `gh` IS MOCKED WITH A TRACE, not hidden from PATH. Hiding a binary asserts that a code path could
# not have run; a mock that APPENDS to $TRACE asserts that it did not. (Hiding is also the shape that
# broke on ubuntu-latest once already: `PATH=/usr/bin:/bin` assumes `gh` lives outside those
# directories, which is true on Homebrew and false on a GitHub runner.)
_link_setup_grid() {
    _link_mock_tmux $'platform\nwarehouse\ninfra\natlas'
    cat > "$MOCK_BIN/gh" <<'EOF'
#!/usr/bin/env bash
echo "gh $*" >> "$TRACE"
exit 1
EOF
    chmod +x "$MOCK_BIN/gh"
    _link_build_grid_ws
}

# Point both network seams at their recordings. Exported UNCONDITIONALLY, including on the
# BORG_UPDATE_GOLDEN path: a regeneration that ran a live sweep would freeze one machine's network
# state as the oracle, which is the whole reason these seams exist.
_link_grid_seams() {
    export BORG_LINK_SWEEP_FIXTURE="${LINK_GOLDEN_DIR}/sweep-acme.json"
    export BORG_LINK_FETCH_FIXTURE="${LINK_GOLDEN_DIR}/fetch-acme.json"
}

# `zsh borg <args...>` from `$1`, stdout+stderr merged into `$2`.
_link_grid_run() {
    local dir="$1" out="$2"; shift 2
    ( cd "$dir" && zsh "$BORG" "$@" ) > "$out" 2>&1
}

# THE TRIPWIRE, AND IT RUNS BEFORE THE DIFF *AND* ON THE UPDATE PATH.
#
# A mistyped fixture path does not fail — `shell._read_sweep_fixture` degrades to a NAMED warning and
# a not-swept grid, exactly as it should for a human — and the first `BORG_UPDATE_GOLDEN=1` run would
# then freeze that degradation as the oracle. That is instance five of "a check pointed at the wrong
# thing does not fail, it reads as a pass". So the grid goldens are only allowed to exist if the
# document says the recordings actually replayed.
#
# DELIBERATE DEVIATION FROM THE AC2 SPEC, hand-executed rather than transcribed. The spec's predicate
# is `.grid.fetch.resolved == .grid.fetch.requested`. That cannot hold in both contexts and is not
# the property worth asserting: `requested` is the SCOPED ask (7 refs in repository scope, 11 in
# orchestrator scope) while `resolved` counts the rows in the recording, which is 11 either way —
# `_read_fetch_fixture` replays the whole file regardless of what was asked. The predicate below
# asserts what the spec was reaching for, and does it more directly: both replay warnings are present
# by name (a mistyped path produces "unreadable or invalid JSON" instead), the fetch reports `ok`, and
# NOTHING fell through to the bottom of the resolve ladder.
#
# AMENDED FOR AC4's PRECONDITION (2026-08-27). The predicate used to assert `unresolved == 0` and
# `fetch.status == "ok"`. Both became FALSE BY DESIGN the moment the precondition's own requirement
# landed: it says outright that "the AC2 fixtures cannot catch a regression here in either direction
# — neither manifest declares a `status` on any row", so a row that declares one had to be added, and
# a declared-only ref is by definition unresolved and by definition one the fetch could not answer.
# `warehouse-rollout.json`'s `acme/warehouse#75` is that row and it is the ONLY one.
#
# So the numbers are pinned EXACTLY rather than loosened to `>= 0`, which would have retired the
# tripwire while looking like a repair. A mistyped fixture path makes EVERY ref fall through, so an
# exact `unresolved == <the deliberate count>` still catches it — and now also catches a second
# accidental unresolved ref, which the old `== 0` could not distinguish from the first.
_link_grid_tripwire() {
    local probe="$1" name="$2" expect_unresolved="${3:-0}"
    jq -e --argjson unresolved "$expect_unresolved" '
        .grid.swept == true
        and .grid.since == "2026-05-28"
        and .grid.declared > 0
        and .grid.unresolved == $unresolved
        and .grid.fetch.status == (if $unresolved == 0 then "ok" else "degraded" end)
        and .grid.fetch.requested > 0
        and .grid.fetch.resolved > 0
        and (.grid.fetch.requested - .grid.fetch.resolved) <= $unresolved
        and ((.grid.warnings | map(select(startswith("sweep: replayed from fixture"))) | length) == 1)
        and ((.grid.warnings | map(select(startswith("fetch: replayed from fixture"))) | length) == 1)
    ' "$probe" > /dev/null || {
        echo "grid golden ${name}: the seams did not replay — refusing to diff or regenerate" >&2
        jq -c '{swept: .grid.swept, since: .grid.since, declared: .grid.declared,
                unresolved: .grid.unresolved, fetch: .grid.fetch, warnings: .grid.warnings}' "$probe" >&2 \
            || cat "$probe" >&2
        false
    }
}

# Byte-compare one manifest-bearing `borg link` invocation against its golden, from a chosen cwd.
# Usage: _assert_link_grid_golden <golden-name> <cwd> <borg args...>
_assert_link_grid_golden() {
    local name="$1" dir="$2"; shift 2
    _link_grid_seams

    local probe="${BATS_TEST_TMPDIR}/${name}.probe.json"
    _link_grid_run "$dir" "$probe" "$@" --json
    # HOW MANY REFS ARE DELIBERATELY UNRESOLVED IN THIS SCOPE. `warehouse-rollout.json`'s
    # `acme/warehouse#75` is the AC4-precondition row — declared `merged`, absent from both
    # recordings — so it resolves `declared` and counts as unresolved wherever its manifest is
    # SELECTED. Orchestrator scope selects both manifests; repository scope on `platform` selects
    # only `auth-hardening`, whose rows all resolve. Kept beside the call rather than inside the
    # tripwire so the number is visibly a property of the fixtures, not of the assertion.
    local expect_unresolved=0
    [ "$name" = "link-grid-orchestrator" ] && expect_unresolved=1
    _link_grid_tripwire "$probe" "$name" "$expect_unresolved"

    local raw="${BATS_TEST_TMPDIR}/${name}.raw" actual="${BATS_TEST_TMPDIR}/${name}.actual"
    _link_grid_run "$dir" "$raw" "$@"
    sed -e "s|${BATS_TEST_TMPDIR}|<TMP>|g" \
        -e "s|${BATS_TEST_DIRNAME}|<TESTS>|g" \
        -e '/Last active:/ s|[0-9-]\{10\}T[0-9:]\{8\}Z|<TS>|g' "$raw" > "$actual"

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
# `--porcelain` wins over a project name; and the `*)` arm is last-wins, so `link a b` focuses b.
#
# THE SECOND HALF'S ASSERTION MOVED IN AC2, and the reason is the point of AC2 rather than a
# concession to it. Pre-AC2 the deep dive rendered ONE project, so "alpha did not win" could be
# asserted as "alpha's summary is nowhere on the page". Post-AC2 every page carries the whole board,
# so alpha's summary is on it BY DESIGN and that assertion would now be asserting the board is
# broken. What "last name wins" actually means is which repository is IN FOCUS, so that is what this
# reads -- off the card, not off the page.
@test "contract: link flag precedence — porcelain beats a project name, last project name wins" {
    _link_setup_porcelain

    run_zsh_borg link --porcelain echo
    [ "$status" -eq 0 ]
    [[ "$output" == *$'\t'* ]] || false
    [[ "$output" != *"Session ID:"* ]] || false

    run bash -c "zsh '$BORG' link alpha echo 2>&1 | sed \$'s/\033\\\\[[0-9;]*m//g' \
        | sed -n '/^▸ IN FOCUS/,/^▸ REPOSITORIES/p'"
    [ "$status" -eq 0 ]
    [[ "$output" == "▸ IN FOCUS  echo"* ]] || false
    [[ "$output" == *"Echo is pinned."* ]] || false
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
# continuation line. The golden fixture's summary is 41 chars precisely so fold is a no-op there,
# which left the wrap and the indent pinned by nothing at all.
#
# CORRECTED (see docs/plans/assimilated/2026-08-12-port-borg-link-to-the-python-core.md, A4): GNU
# and BSD `fold -s` do NOT disagree on ASCII — measured 1000/1000 agreement, and `_fold_s`'s PR
# #140 fix matches both. The real reason a byte-exact golden is the wrong tool here is that there
# are three DIFFERENT counting algorithms in play, not two disagreeing vendors: `_fold_s` counts
# codepoints, BSD `fold` counts display columns, GNU `fold` counts bytes (splitting a UTF-8
# sequence mid-codepoint). They diverge on non-ASCII — an em dash, the single most likely
# non-ASCII character in an LLM-written summary — so pinning wrap output byte-for-byte would work
# today (this fixture is ASCII) but silently stop holding the moment a summary carries a non-ASCII
# character, and would do so differently depending on the CI/dev-host userland. Asserted
# structurally instead, so it holds regardless of which fold implementation runs it: more than one
# line, and every line after the first indented.
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
# ints, so the port renders this on one line, matching A4's amended text for the case below. (The
# pointer here used to be a `cli_contract.bats:<N>` self-reference; it was stale, and every numeric
# pointer at this file in the tree has since been re-anchored by @test name.)
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

# THE EMPTY-DATE FIX. Reproduced against the owner's real registry post-merge, NOT by any fixture in
# this file: zsh's `IFS=$'\t' read -r slug title ship aproject` COLLAPSES consecutive tabs (tab is a
# whitespace IFS char), so a plan with no "Shipped:" line shifted `project` left into `ship`'s slot
# and rendered a bare, empty "()" after the title. See PROJECT_PLAN.md's A4 fourth deviation.
#
# A DEDICATED workspace/registry, not _link_build_overview_ws / _link_registry_overview: every
# assimilated fixture those builders feed carries a "Shipped:" line (see their own docstrings), and
# adding a Shipped:-less file to either would perturb link-overview.golden / link-overview-all.golden
# / link-deep.golden, which A4 forbids. "kilo" exists ONLY here. Two files so the aggregate section
# also proves a PRESENT ship date still renders its parens (the title-trailing-"(K1)" is verbatim
# title text, never the date's parens, and must survive untouched).
_link_build_noshipdate_ws() {
    local root="${BATS_TEST_TMPDIR}/ws-noshipdate"
    mkdir -p "$root/kilo/docs/plans/assimilated"
    printf '# Kilo unshipped (K1)\n' > "$root/kilo/docs/plans/assimilated/2026-05-02-kilo-noshipdate.md"
    printf '# Kilo shipped\nShipped: 2026-05-01\n' > "$root/kilo/docs/plans/assimilated/2026-05-01-kilo-dated.md"
}

_link_registry_noshipdate() {
    local root="${BATS_TEST_TMPDIR}/ws-noshipdate"
    cat > "$BORG_REGISTRY" <<EOF
{
  "projects": {
    "kilo": {"path": "$root/kilo", "source": "cli", "status": "idle",
             "summary": "Kilo has one assimilated plan with no Shipped: line."}
  }
}
EOF
}

@test "contract: link overview assimilated omits parens when a plan has no Shipped: date" {
    _link_mock_tmux ""
    _link_build_noshipdate_ws
    _link_registry_noshipdate

    run_zsh_borg link
    [ "$status" -eq 0 ]
    [[ "$output" == *"[kilo] Kilo unshipped (K1)"$'\033''[0m'* ]] || false
    [[ "$output" != *"[kilo] Kilo unshipped (K1) ("* ]] || false
    [[ "$output" == *"[kilo] Kilo shipped (2026-05-01)"* ]] || false
    [[ "$output" != *"()"* ]] || false
}

@test "contract: link <project> deep dive assimilated omits parens when a plan has no Shipped: date" {
    _link_mock_tmux ""
    _link_build_noshipdate_ws
    _link_registry_noshipdate

    run_zsh_borg link kilo
    [ "$status" -eq 0 ]
    [[ "$output" == *"Kilo unshipped (K1)"$'\033''[0m'* ]] || false
    [[ "$output" != *"Kilo unshipped (K1) ("* ]] || false
    [[ "$output" == *"Kilo shipped (2026-05-01)"* ]] || false
    [[ "$output" != *"()"* ]] || false
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
# ── the topological grid: B1–B16 ─────────────────────────────────────────────

@test "contract: link renders the repository context byte-identically to its golden" {
    _link_setup_grid
    _assert_link_grid_golden link-grid-repository "${BATS_TEST_TMPDIR}/ws" link platform
}

# B2. THE SAME GOLDEN, TWICE, FROM TWO INVOCATION SHAPES. `cd <repo> && borg link` is the modal human
# invocation and it is the one a scope-derived-but-argv-fed `_focus` silently breaks: the positional
# leg keeps IN FOCUS, `Status:`, QUEUED and SHIPPED while the cwd leg loses all four, and a harness
# that only ever renders the positional leg cannot see it. Diffing both against ONE file is what makes
# the equality a property rather than a pair of independent snapshots.
@test "contract: link renders the repository context identically from the positional and from the cwd" {
    _link_setup_grid
    _assert_link_grid_golden link-grid-repository "${BATS_TEST_TMPDIR}/ws" link platform
    _assert_link_grid_golden link-grid-repository "${BATS_TEST_TMPDIR}/ws/platform" link
}

@test "contract: link renders the orchestrator context byte-identically to its golden" {
    _link_setup_grid
    _assert_link_grid_golden link-grid-orchestrator "${BATS_TEST_TMPDIR}/ws" link
}

# B4. THE INVARIANT IS AGAINST THE CONSTANT, NEVER AGAINST THE OTHER GOLDEN. Comparing the two
# renderings' header lists to each other goes green if both drift together; comparing each to
# `render.SECTIONS` cannot. This is the executable form of "the two contexts differ in breadth only".
@test "contract: both link contexts render the same section headers in the same order" {
    _link_setup_grid
    _link_grid_seams

    local expected
    expected=$(PYTHONPATH="$BORG_HOME" python3 -c \
        'from borg_core.link import render; print("\n".join(t for t, _ in render.SECTIONS if t))')
    [ -n "$expected" ]

    local ctx
    for ctx in "${BATS_TEST_TMPDIR}/ws/platform:link" "${BATS_TEST_TMPDIR}/ws:link"; do
        _link_grid_run "${ctx%%:*}" "${BATS_TEST_TMPDIR}/spine.raw" "${ctx##*:}"
        run bash -c "sed \$'s/\033\\\\[[0-9;]*m//g' '${BATS_TEST_TMPDIR}/spine.raw' \
            | grep '^▸ ' | sed 's/  .*//' | sed 's/^▸ //'"
        [ "$output" = "$expected" ] || {
            printf 'context %s rendered:\n%s\nexpected:\n%s\n' "$ctx" "$output" "$expected" >&2
            false
        }
    done
}

# B5/B6. THE `Status:` INVARIANT, AND IT IS STRUCTURAL RATHER THAN LEXICAL. `sweep-acme.json`
# deliberately carries a pull request titled `chore(auth): Status: normalise the rollout report`,
# which is what a real sweep can hand the renderer at any moment. IN FOCUS being SECTION 2 — above
# REPOSITORIES and above CHAINS — is what keeps `grep -m1` landing on the session status instead of
# on a stranger's PR title. Move IN FOCUS below CHAINS and both halves go red.
@test "contract: exactly one Status: line in repository context and none in orchestrator context" {
    _link_setup_grid
    _link_grid_seams

    _link_grid_run "${BATS_TEST_TMPDIR}/ws" "${BATS_TEST_TMPDIR}/repo.txt" link platform
    # The poisoned title really is on the page -- otherwise this case proves nothing.
    run grep -c 'Status: normalise the rollout report' "${BATS_TEST_TMPDIR}/repo.txt"
    [ "$output" = "1" ]
    run grep -c 'Status:' "${BATS_TEST_TMPDIR}/repo.txt"
    [ "$output" = "2" ]
    # ...and the FIRST hit is the card's, not the PR's.
    run bash -c "grep -m1 'Status:' '${BATS_TEST_TMPDIR}/repo.txt' | sed \$'s/\033\\\\[[0-9;]*m//g'"
    [[ "$output" == "  Status:"*"active" ]] || false

    _link_grid_run "${BATS_TEST_TMPDIR}/ws" "${BATS_TEST_TMPDIR}/orch.txt" link
    run bash -c "grep -c '^  .Status:' '${BATS_TEST_TMPDIR}/orch.txt' || true"
    [ "$output" = "0" ]
}

# B7. `scope_for` honours a positional only when it is IN THE REGISTRY, so `borg link ghost` from the
# workspace root resolves to ORCHESTRATOR scope — the exact shape where a purely scope-derived
# `need_focus` skips `_focus`, skips the raise, and exits 0 with a full board. `bool(project) or ...`
# preserves it.
#
# B8 (the raise happening BEFORE any aggregate collector runs) is not observable from bats — nothing
# the shell can see distinguishes "raised early" from "raised late". It lives in
# borg_core/link/test_cli.py as `test_an_unregistered_positional_raises_before_any_aggregate_collector_runs`,
# which monkeypatches both collectors to raise. Recorded here so the gap is a decision, not an
# oversight.
@test "contract: link <unregistered> dies non-zero from an orchestrator cwd too" {
    _link_setup_grid
    _link_grid_seams

    run bash -c "cd '${BATS_TEST_TMPDIR}/ws' && zsh '$BORG' link ghost-project 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"project 'ghost-project' not in registry"* ]] || false
    [[ "$output" != *"▸ REPOSITORIES"* ]] || false
}

# B9. skills/borg-link/SKILL.md runs a bare `borg link --json | jq '.directives |= (...)'`, and only
# borg-collective carries a `.borg-project` marker — so that call routes from INSIDE whatever
# repository the session is in. Scope-gating the aggregates would report zero directives for the whole
# collective at `.version == 2`, which SKILL.md maps to "CLI path. Never fall back." A WRONG answer,
# not a missing one, and it is why DOCUMENT_VERSION could stay 2.
@test "contract: link --json carries every project's directives from inside a repository" {
    _link_setup_grid
    _link_grid_seams

    _link_grid_run "${BATS_TEST_TMPDIR}/ws" "${BATS_TEST_TMPDIR}/root.json" link --json
    _link_grid_run "${BATS_TEST_TMPDIR}/ws/platform" "${BATS_TEST_TMPDIR}/inside.json" link --json

    run jq -r '.scope.kind' "${BATS_TEST_TMPDIR}/inside.json"
    [ "$output" = "repository" ]
    run jq -e '.version == 2' "${BATS_TEST_TMPDIR}/inside.json"
    run jq -S '{directives, assimilated}' "${BATS_TEST_TMPDIR}/inside.json"
    local inside="$output"
    run jq -S '{directives, assimilated}' "${BATS_TEST_TMPDIR}/root.json"
    [ "$output" = "$inside" ]
    run jq '.directives | length' "${BATS_TEST_TMPDIR}/inside.json"
    [ "$output" = "5" ]
}

# B10. REPOSITORIES is the one section breadth does not touch. skills/borg-switch/SKILL.md runs
# exactly this from a project session's cwd and reads the whole table out of it; borg.zsh's 5s watch
# redraw does the same. Applying the scope filter to the board turns both into a one-row list.
@test "contract: borg link --local --all from inside a repository still lists every project" {
    _link_setup_grid
    _link_grid_seams

    _link_grid_run "${BATS_TEST_TMPDIR}/ws/platform" "${BATS_TEST_TMPDIR}/board.txt" link --local --all
    local p
    for p in platform warehouse infra ledger atlas relay archive-tools; do
        run grep -c -- "$p" "${BATS_TEST_TMPDIR}/board.txt"
        [ "$output" != "0" ] || { echo "board lost $p" >&2; false; }
    done
    # ...and exactly one row carries the scoped marker.
    run bash -c "grep -c '◀' '${BATS_TEST_TMPDIR}/board.txt'"
    [ "$output" = "1" ]
}

# B11. The tripwire as a NAMED case, so a reader can see what the goldens are allowed to be cut from.
# Mistype either fixture path and this is what turns red — today that degrades to a warning and the
# first regeneration freezes the degradation as the oracle.
@test "contract: the grid goldens replayed a populated sweep and a populated fetch" {
    _link_setup_grid
    _link_grid_seams

    _link_grid_run "${BATS_TEST_TMPDIR}/ws" "${BATS_TEST_TMPDIR}/probe.json" link --json
    _link_grid_tripwire "${BATS_TEST_TMPDIR}/probe.json" "orchestrator-probe" 1

    run jq '[.grid.manifests[].nodes[] | select(.state_source == "swept")] | length' "${BATS_TEST_TMPDIR}/probe.json"
    [ "$output" = "8" ]
    run jq '[.grid.manifests[].nodes[] | select(.state_source == "fetched")] | length' "${BATS_TEST_TMPDIR}/probe.json"
    [ "$output" = "3" ]
    # A degraded seam would still satisfy a count; assert the sweep's own PAYLOAD arrived.
    run jq -r '.grid.sources[0].source' "${BATS_TEST_TMPDIR}/probe.json"
    [ "$output" = "github" ]
}

# B12. HIDING A BINARY ASSERTS A PATH COULD NOT RUN; A TRACED MOCK ASSERTS IT DID NOT. `gh` is on
# PATH here and exits 1 if called, so removing the `if fixture:` short-circuit from `shell.sweep` or
# `shell.start_fetch` turns this red rather than silently producing a different grid.
@test "contract: the grid goldens spawn zero gh and zero adapter subprocesses" {
    _link_setup_grid
    _link_grid_seams
    : > "$TRACE"

    _link_grid_run "${BATS_TEST_TMPDIR}/ws" "${BATS_TEST_TMPDIR}/traced.txt" link
    _link_grid_run "${BATS_TEST_TMPDIR}/ws" "${BATS_TEST_TMPDIR}/traced2.txt" link platform

    run bash -c "grep -c '^gh ' '$TRACE' || true"
    [ "$output" = "0" ]
    # The adapter search path stays setup_temp_dirs' empty directory as belt and braces: with the
    # sweep seam live, `discover_adapters` is never even reached.
    run bash -c "ls -A '$BORG_RECON_ADAPTER_PATH' | wc -l | tr -d ' '"
    [ "$output" = "0" ]
    # ...and the render really did happen, so this is not passing on an empty run.
    run grep -c '▸ CHAINS' "${BATS_TEST_TMPDIR}/traced.txt"
    [ "$output" = "1" ]
}

# B13. The fixture-replay warnings name their fixture by ABSOLUTE path and those fixtures live under
# `tests/`, NOT under $BATS_TEST_TMPDIR — so the single-expression scrub the four older goldens use
# does not cover them. Without the `<TESTS>` expression both grid goldens are green only on the
# machine that authored them.
@test "contract: the grid goldens carry no absolute checkout path" {
    local g
    for g in link-grid-repository link-grid-orchestrator; do
        [ -f "${LINK_GOLDEN_DIR}/${g}.golden" ]
        run bash -c "grep -c '${BATS_TEST_DIRNAME}' '${LINK_GOLDEN_DIR}/${g}.golden' || true"
        [ "$output" = "0" ] || { echo "$g leaks \$BATS_TEST_DIRNAME" >&2; false; }
        run bash -c "grep -c '/Users/\\|/home/\\|/private/tmp' '${LINK_GOLDEN_DIR}/${g}.golden' || true"
        [ "$output" = "0" ] || { echo "$g leaks an absolute path" >&2; false; }
        # ...and the scrubbed placeholders really are there, so this is not green on an empty file.
        run bash -c "grep -c '<TESTS>/fixtures/link/' '${LINK_GOLDEN_DIR}/${g}.golden'"
        [ "$output" = "2" ]
    done
}

# B14. Node ids are a JUMP TARGET: each appears exactly twice on the page — once in a picture cell,
# once as a detail heading — so `*` in vim toggles between them with no plugin. Numbering per manifest
# instead of globally puts four `n1`s on the orchestrator page and breaks the jump for both projects.
@test "contract: every node id appears exactly twice in each grid golden" {
    local g
    for g in link-grid-repository link-grid-orchestrator; do
        run bash -c "sed \$'s/\033\\\\[[0-9;]*m//g' '${LINK_GOLDEN_DIR}/${g}.golden' \
            | grep -oE '\\bn[0-9]+\\b' | sort | uniq -c | awk '{print \$1}' | sort -u"
        [ "$output" = "2" ] || { echo "$g node id counts: $output" >&2; false; }
    done

    # ...and the ids are contiguous from n1, globally across manifests.
    run bash -c "sed \$'s/\033\\\\[[0-9;]*m//g' '${LINK_GOLDEN_DIR}/link-grid-orchestrator.golden' \
        | grep -oE '\\bn[0-9]+\\b' | sort -u | sed 's/^n//' | sort -n | tr '\n' ' '"
    # n12 is `acme/warehouse#75`, the AC4-precondition row added to warehouse-rollout.json. The list
    # is spelled out rather than counted so that a node QUIETLY VANISHING from the picture — which is
    # what a renderer bug looks like from here — turns this red instead of shortening a number nobody
    # reads.
    [ "$output" = "1 2 3 4 5 6 7 8 9 10 11 12 " ]

    run bash -c "sed \$'s/\033\\\\[[0-9;]*m//g' '${LINK_GOLDEN_DIR}/link-grid-repository.golden' \
        | grep -oE '\\bn[0-9]+\\b' | sort -u | sed 's/^n//' | sort -n | tr '\n' ' '"
    [ "$output" = "1 2 3 4 5 6 7 " ]
}

# B15. MEASURES THE GOLDEN, THEN PARSES THE CONFIG — never greps for a config string. A grep for
# `right:70:wrap` asserts that somebody typed a number, not that the picture fits inside it. The
# widest row is measured with `picture.visible_len`, the same primitive the renderer pads with, so a
# hyperlinked or coloured cell counts as its VISIBLE width rather than its byte length.
@test "contract: the fzf preview window is at least as wide as the widest picture row" {
    local width pane
    width=$(PYTHONPATH="$BORG_HOME" python3 -c '
import sys
from borg_core.link import picture

# A picture row is INDENTED by picture.INDENT and its first visible character is a glyph or a box
# character. The leading-indent test is load-bearing rather than belt-and-braces: the board`s
# horizontal rule is 90 unindented U+2500s, and without it this measures THAT and reports a page
# that blows the budget by 22 columns while every picture row fits.
frame = set("✔✗○●◌│├┤┬┴┼┌┐└┘─")
rows = []
# SCOPED TO THE CHAINS SECTION, and that scoping arrived with AC4 rather than being belt-and-braces.
# `▸ NEXT` renders indented rows whose first visible character is a state glyph -- the exact
# heuristic below -- but they carry FULL refs, not the picture`s short ones, so measuring them
# reported the page as blowing PICTURE_BUDGET while every actual picture row fit. The old scan
# measured "any indented glyph-leading line anywhere on the page", which was only ever a proxy for
# "a picture row" and stopped being one the moment a second section printed a glyph.
inside = False
for line in open(sys.argv[1], encoding="utf-8").read().split("\n"):
    plain = picture._SGR_RE.sub("", picture._OSC8_RE.sub("", line))
    if plain.startswith("▸ "):
        inside = plain.startswith("▸ CHAINS")
        continue
    if inside and plain.startswith(" " * picture.INDENT) and plain.strip()[:1] in frame:
        rows.append(line)
if not rows:
    raise SystemExit("no picture rows matched")
print(max(picture.visible_len(r) for r in rows))
' "${LINK_GOLDEN_DIR}/link-grid-orchestrator.golden")
    [ "$width" -gt 0 ] || { echo "measured no picture rows at all" >&2; false; }
    [ "$width" -le "$(PYTHONPATH="$BORG_HOME" python3 -c 'from borg_core.link import picture; print(picture.PICTURE_BUDGET)')" ]

    # THE PANE COMPARISON IS GONE BECAUSE THE PANE IS. `borg switch`'s fzf preview was retired on
    # 2026-08-27 (zero typed invocations in six months), taking `--preview-window right:70:wrap` with
    # it, so there is no longer a second number to check against. PICTURE_BUDGET is now the whole
    # bound — which is what `docs/plans/directives/2026-08-27-retire-unused-link-surfaces.md` requires
    # of the retirement: it must not silently take out the only executable check that the picture fits
    # anything. The budget stays 68 on its own merits; a future consumer that reintroduces a width
    # constraint should assert against ITS number here, not resurrect the deleted one.
    run grep -c -- '--preview-window' "$BORG"
    [ "$output" -eq 0 ]
}

# B16. `--deep` is parsed and IGNORED. It stays in the parser because ONE live copy of the dispatcher
# passes it — borg.zsh's positional arm, which every `borg link <project>` routes through; delete the
# argument and argparse exits 2 wherever a caller swallows failure silently. The fzf preview and
# `drone status` were the two such callers named here until both were retired on 2026-08-27; the arm
# they shared is still live and still passes the flag.
#
# Corrected in AC2/S4: this said THREE copies, also naming bin/link-parity-harness and its byte-copy
# at ~/.claude/bin/. Neither ever passed `--deep` — the harness looped a bare positional — and S4
# retired the leg that looped. One copy on a silently-swallowing hot path is the entire argument.
@test "contract: link --local --deep <p> and link --local <p> render byte-identically" {
    _link_setup_grid
    _link_grid_seams

    _link_grid_run "${BATS_TEST_TMPDIR}/ws" "${BATS_TEST_TMPDIR}/with-deep.txt" link --local --deep platform
    _link_grid_run "${BATS_TEST_TMPDIR}/ws" "${BATS_TEST_TMPDIR}/no-deep.txt" link --local platform

    run diff -u "${BATS_TEST_TMPDIR}/no-deep.txt" "${BATS_TEST_TMPDIR}/with-deep.txt"
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; false; }
    run grep -c '▸ IN FOCUS' "${BATS_TEST_TMPDIR}/with-deep.txt"
    [ "$output" = "1" ]
}

# `--local` opts down from BOTH network rungs, so the grid still renders from what each manifest
# DECLARES -- which for these fixtures is nothing, so every node reaches the renderer with the state
# nobody resolved. That is the hottest path in the tree (per-keypress fzf preview, per-window
# `drone status`) and the one a renderer that raised on an unrecognized token would take out.
@test "contract: link --local renders every node without naming the unresolved token" {
    _link_setup_grid
    _link_grid_seams

    _link_grid_run "${BATS_TEST_TMPDIR}/ws" "${BATS_TEST_TMPDIR}/local.txt" link --local platform
    run grep -c 'platform#400' "${BATS_TEST_TMPDIR}/local.txt"
    [ "$output" != "0" ]
    run bash -c "grep -ci 'unknown' '${BATS_TEST_TMPDIR}/local.txt' || true"
    [ "$output" = "0" ]
    run grep -c 'nobody has an answer for this ref' "${BATS_TEST_TMPDIR}/local.txt"
    [ "$output" = "7" ]
    run grep -c 'declared refs unresolved' "${BATS_TEST_TMPDIR}/local.txt"
    [ "$output" = "1" ]
}

# The MODAL repository: a git origin, no manifest. Six of its seven sections are strictly richer than
# what `borg link <project>` showed before AC2 (which had no board and no chains at all), and the one
# empty section carries a DIAGNOSIS rather than a blank frame.
@test "contract: a repository with no manifest renders the same spine and names why CHAINS is empty" {
    _link_setup_grid
    _link_grid_seams

    _link_grid_run "${BATS_TEST_TMPDIR}/ws" "${BATS_TEST_TMPDIR}/ledger.txt" link ledger
    # SEVEN `▸` HEADERS SINCE AC4 (the eighth section is the header block, which carries no `▸` line).
    run grep -c '▸ ' "${BATS_TEST_TMPDIR}/ledger.txt"
    [ "$output" = "7" ]
    run grep -c 'no project manifest declares work in acme/ledger' "${BATS_TEST_TMPDIR}/ledger.txt"
    [ "$output" = "1" ]
    run grep -c 'none declaring a row in acme/ledger' "${BATS_TEST_TMPDIR}/ledger.txt"
    [ "$output" = "1" ]

    # ...and a directory with no git origin at all gets the OTHER diagnosis.
    _link_grid_run "${BATS_TEST_TMPDIR}/ws" "${BATS_TEST_TMPDIR}/infra.txt" link infra
    run grep -c 'no GitHub origin' "${BATS_TEST_TMPDIR}/infra.txt"
    [ "$output" = "1" ]
}

# THE THIRD DIAGNOSIS, AND IT WAS DEAD CODE UNTIL THE GENERATED GOLDEN WAS READ. `repository_dir`
# returns "" for orchestrator scope BY CONTRACT, so a ladder that tests the slug before the scope
# answers "this directory has no GitHub origin" for `borg link` from the workspace root -- and the
# registry-wide sentence never renders anywhere. A pytest case that varies only `slug` against a
# hand-built grid block cannot see that; this runs the real document from the real cwd.
@test "contract: an orchestrator context with no manifests anywhere names the registry, not a directory" {
    _link_mock_tmux ""
    local root="${BATS_TEST_TMPDIR}/ws"
    mkdir -p "$root/solo"
    export BORG_ORCHESTRATOR_ROOT="$root"
    printf '{"projects":{"solo":{"path":"%s","source":"cli","status":"idle","summary":"No manifests here."}}}' \
        "$root/solo" > "$BORG_REGISTRY"

    _link_grid_run "$root" "${BATS_TEST_TMPDIR}/orch-empty.txt" link
    run grep -c 'no project manifests in the registry yet' "${BATS_TEST_TMPDIR}/orch-empty.txt"
    [ "$output" = "1" ]
    run bash -c "grep -c 'no GitHub origin' '${BATS_TEST_TMPDIR}/orch-empty.txt' || true"
    [ "$output" = "0" ]
}

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
# the lenient behavior as the parity target.
#
# `--help` USED TO BE ASSERTED HERE TOO, and its removal is a deliberate PRODUCT change, not a test
# edited to go green: swallowing `--help` meant `borg link --help` rendered the swept overview
# (0.85s of network) instead of a usage line. S4 gave it an explicit arm, so the two shapes no
# longer take the same path. The lenient arm itself is byte-unchanged, and this case plus the
# gh-trace control in link_sweep.bats are together what pin that it still carries NO semantics.
@test "contract: link tolerates an unknown flag and still renders the overview at exit 0" {
    _link_mock_tmux ""
    printf '%s' '{"projects":{"solo":{"path":null,"source":"cli","status":"idle","summary":"Solo."}}}' \
        > "$BORG_REGISTRY"

    run_zsh_borg link --totally-bogus
    [ "$status" -eq 0 ]
    [[ "$output" == *"THE BORG COLLECTIVE"* ]] || false
}

# S4 / AC1. All three assertions are load-bearing:
#   exit 0                       -- an implementation that `die`s also satisfies "no overview"
#   contains "usage: borg link"  -- the house style borg.zsh's `recon)` -h arm already uses
#   NOT "THE BORG COLLECTIVE"    -- rejects the overview AND a lazy reroute to cmd_help, which
#                                   prints the SAME cube banner as borg_core/link/render.py. It
#                                   also catches a missing `return`, which would print usage and
#                                   then sweep and render anyway, still at exit 0.
@test "contract: link --help and -h print usage instead of the overview (AC1)" {
    _link_mock_tmux ""
    printf '%s' '{"projects":{"solo":{"path":null,"source":"cli","status":"idle","summary":"Solo."}}}' \
        > "$BORG_REGISTRY"

    local flag
    for flag in --help -h; do
        run_zsh_borg link "$flag"
        [ "$status" -eq 0 ]
        [[ "$output" == *"usage: borg link"* ]] || false
        [[ "$output" != *"THE BORG COLLECTIVE"* ]] || false
    done

    # Help outranks every other arm, including the one that shells out to `claude`. The scan banner
    # is what makes that falsifiable: move the help check below the --refresh block and
    # `borg link --refresh --help` fires a real `cmd_scan --llm` before printing its one line, and
    # both assertions above would still pass.
    run_zsh_borg link --refresh --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"usage: borg link"* ]] || false
    [[ "$output" != *"THE BORG COLLECTIVE"* ]] || false
    [[ "$output" != *"Scanning Claude session history"* ]] || false
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
    # BORG_RECON_ADAPTER_PATH is unset here for the same reason the two #113 cases above unset it,
    # and it is load-bearing for THIS assertion specifically. setup_temp_dirs now points that
    # variable at an empty directory (B7, so `borg link`'s sweep never shells to `gh`), and
    # `_select_adapters` dies with "no recon adapters found" BEFORE it can ever reach the
    # "no adapters matched" branch this test asserts on. Without the unset the test fails on a
    # message that has nothing to do with registry resolution.
    #
    # `--json` IS REQUIRED, NOT DECORATION (S4). `recon` retired as a human verb, so the dispatch
    # arm now `die`s before any Python runs unless a machine flag is present. Without `--json` this
    # case would still be non-zero and still not say "no registry at" -- two of its three assertions
    # would pass against a message that never reached the registry at all. `--json` changes nothing
    # else: borg_core/recon/cli.py:_run checks the registry BEFORE _sweep/_select_adapters and only
    # switches the RENDERER on json_only, so the guard's teeth are byte-identical. `--adapters` is
    # NOT interchangeable here -- _run_list_adapters returns before the registry check, which is the
    # exact escape hatch that let `borg recon` ship dead for a month.
    #
    # WHAT THIS CASE PROVES AND WHAT IT DOES NOT. It falsifies borg_core/paths.py losing its own
    # BORG_REGISTRY/BORG_DIR/XDG fallback. It does NOT falsify `_borg_py` dropping the variable:
    # borg.zsh:24 and lib/registry.zsh:14-15 derive the same path from the same inherited
    # environment that borg_core/paths.py derives, so both sides land on the same file either way.
    # The forwarding half needs a value no derivation can reach -- see the B8 case below.
    run zsh -c \
        "unset BORG_REGISTRY BORG_DIR BORG_RECON_ADAPTER_PATH; '$BORG' recon --json --sources deliberately-no-such-source"
    [ "$status" -ne 0 ]
    # Dying at adapter selection instead of the registry check is the proof it got that far.
    [[ "$output" != *"no registry at"* ]] || false
    [[ "$output" == *"no adapters matched"* ]] || false
}

# The link-side half of the same guard (the hardened spec's B8). `borg link --json` has NEITHER trap
# the recon case above relies on: borg_core/registry/shell.py:34-36 CREATES {"projects":{}} when the
# file is absent, so a wrongly-resolved registry exits 0 with a structurally valid empty document
# and zero diagnostics.
#
# WHY config.zsh AND NOT "SEED THE DERIVED DEFAULT". B8's literal instruction — seed a uniquely
# named project at the derived default and run with both variables unset — is worthless here, and
# that was measured rather than reasoned: borg.zsh:24 and lib/registry.zsh:14-15 derive
# BORG_DIR/BORG_REGISTRY with the SAME formula borg_core/paths.py uses, from the SAME environment
# the python3 child inherits, so deleting BOTH forwarding lines from _borg_py leaves the child
# resolving the identical sandbox path and the test green. $BORG_DIR/config.zsh (sourced at
# borg.zsh:41, after every default is applied) assigns a PLAIN, unexported shell variable that no
# derivation can reproduce — the child sees it ONLY if _borg_py names it. Same idiom and the same
# reason as the BORG_ORCHESTRATOR_ROOT probe further down this file.
#
# THE `unset` IS LOAD-BEARING. setup_temp_dirs EXPORTS both names and zsh keeps the export attribute
# across a bare reassignment, so without it config.zsh's value lands in the ENVIRONMENT and the
# child inherits the sentinel even with _borg_py gutted.
#
# ASSERT ON THE SENTINEL, NEVER ON STATUS. A mis-resolved registry is auto-created empty and exits
# 0; only a uniquely-named project that cannot appear in an auto-created file discriminates.
@test "contract: link --json resolves the registry through a value no derivation can reach (B8)" {
    _link_mock_tmux ""
    local alt="${BATS_TEST_TMPDIR}/elsewhere/registry.json"
    mkdir -p "${BATS_TEST_TMPDIR}/elsewhere"
    printf '%s' \
        '{"projects":{"b8-sentinel-zarquon":{"path":null,"source":"cli","status":"idle","summary":"S."}}}' \
        > "$alt"
    printf '%s' '{"projects":{}}' > "$BORG_REGISTRY"
    printf 'BORG_REGISTRY=%s\n' "$alt" > "$BORG_DIR/config.zsh"

    run bash -c "zsh -c \"unset BORG_REGISTRY BORG_DIR; '$BORG' link --json\" | jq -r '.order[]'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"b8-sentinel-zarquon"* ]] || false
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

    # THE `unset` IS WHAT GIVES THE LOOP BELOW TEETH FOR BORG_DIR AND BORG_REGISTRY, and it was
    # missing until S4. setup_temp_dirs EXPORTS both, and zsh keeps the export attribute across
    # borg.zsh:24 / lib/registry.zsh:15's bare reassignment, so the child inherited both through
    # the environment whether or not _borg_py named them -- vacuous for exactly the two names the
    # hardened spec's B8 is about. Measured after this change: deleting `BORG_DIR="$BORG_DIR"` from
    # _borg_py fails at `var=BORG_DIR count=0`; deleting `BORG_REGISTRY="$BORG_REGISTRY"` fails at
    # `var=BORG_REGISTRY count=0`. The `env BORG_MAX_ACTIVE=7` sub-assertion at the bottom keeps
    # its own inheritance and is deliberately left alone.
    run zsh -c "unset BORG_DIR BORG_REGISTRY; '$BORG' rm some-project"
    [ "$status" -eq 0 ]
    [ -f "$ENVDUMP" ]

    local var
    for var in BORG_DIR BORG_REGISTRY BORG_MAX_ACTIVE BORG_REAP_STALE_HOURS BORG_TMUX_SESSION \
               BORG_ORCHESTRATOR_ROOT BORG_CORTEX_WAKES PYTHONPATH; do
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
               BORG_ORCHESTRATOR_ROOT BORG_CORTEX_WAKES BORG_NO_REAP PYTHONPATH; do
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

# ── Phase 3 (A4+A5) verification ────────────────────────────────────────────
#
# A5's original verify ("grep -c 'cmd_link' borg.zsh returns 0") is the weakest possible form of its
# own criterion: satisfiable while 8 of 9 functions linger as orphaned dead code, satisfiable by a
# pure rename, three of its six matches were COMMENTS (so it can go red on prose after a perfect
# deletion, or green by editing prose while code survives), and `grep -c` EXITS 1 on a zero count --
# as literally written it signals failure exactly when it passes. These three tests replace it.

# Check 1: definition-anchored, repo-wide absence. Catches a rename or a relocation grep alone would
# miss if it only scanned for the bare string "cmd_link".
@test "contract: the nine deleted link helpers are absent as function definitions repo-wide" {
    run bash -c "grep -rnE '^[[:space:]]*(function[[:space:]]+)?(cmd_link|_borg_link_porcelain|_borg_link_overview|_borg_link_deep|_borg_cortex_pending|_borg_cortex_countdown|_borg_collect_all_directives|_borg_collect_all_assimilated|_borg_read_assimilated)[[:space:]]*\\(\\)' '$BORG_HOME/borg.zsh' '$BORG_HOME'/lib/*.zsh"
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

# Check 2: runtime absence via `whence -w`, which catches a helper relocated into lib/*.zsh (sourced
# by glob) or defined via eval -- grep on borg.zsh alone cannot see either. The SAME test asserts the
# positive half: _borg_read_directives and cmd_ls must SURVIVE (cmd_next:1106 still calls
# _borg_read_directives). Verified on the pre-flip tree to print "STILL DEFINED" for 9/9; this must be
# green only after a real deletion. `cmd_watch` MOVED from the survivor list to the deleted one on
# 2026-08-27 — zero typed invocations in six months, see
# docs/plans/directives/2026-08-27-retire-unused-link-surfaces.md.
@test "contract: the nine deleted link helpers are undefined at runtime, and their survivors are not" {
    run zsh -c "set -- help; source '$BORG_HOME/borg.zsh' >/dev/null 2>&1
        for f in cmd_link _borg_link_porcelain _borg_link_overview _borg_link_deep \
                 _borg_cortex_pending _borg_cortex_countdown _borg_collect_all_directives \
                 _borg_collect_all_assimilated _borg_read_assimilated cmd_watch; do
            whence -w \$f >/dev/null 2>&1 && { print -r -- \"STILL DEFINED: \$f\"; exit 1; }
        done
        for f in _borg_read_directives cmd_ls; do
            whence -w \$f >/dev/null 2>&1 || { print -r -- \"MISSING: \$f\"; exit 1; }
        done
        exit 0"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# Check 3: positive non-vacuity. The only one of the three that proves the renderer actually MOVED
# rather than being renamed, re-pointed, or left behind a surviving zsh fallback. Injects a python3
# that exits non-zero via BORG_PATH_PREFIX (the same mock-binary seam used throughout this file — see
# "watch dispatches into the live-refresh loop", which mocks tmux the same way) and asserts all
# three human modes fail. On the pre-flip tree (zero python3 dependency in any human mode) this was
# RED; it can only pass after a real flip with no zsh renderer left standing behind the dispatch.
@test "contract: all three human link modes fail when python3 is unavailable" {
    _link_mock_tmux ""
    printf '%s' '{"projects":{"solo":{"path":null,"source":"cli","status":"idle","summary":"Solo."}}}' \
        > "$BORG_REGISTRY"
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    cat > "$MOCK_BIN/python3" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$MOCK_BIN/python3"

    run_zsh_borg link
    [ "$status" -ne 0 ]

    run_zsh_borg link --porcelain
    [ "$status" -ne 0 ]

    run_zsh_borg link solo
    [ "$status" -ne 0 ]
}

# The fzf split-brain tripwire. After the flip, cmd_ls (borg.zsh:539-551 in the pre-flip numbering)
# is the LAST surviving zsh copy of a sort whose authority now lives in core.order_projects. All
# three jq copies were byte-identical before the deletion, so there is no disagreement on flip day --
# this is the tripwire for the day someone changes one sort and not the other.
@test "contract: cmd_ls --porcelain column 1 still agrees with link --json .order after the flip" {
    _link_setup_porcelain

    run bash -c "zsh -c \"set -- help; source '$BORG' >/dev/null 2>&1; cmd_ls --porcelain\" | awk -F'\t' '{ print \$1 }' | paste -sd, -"
    [ "$status" -eq 0 ]
    local ls_order="$output"
    [ -n "$ls_order" ]

    run bash -c "zsh '$BORG' link --json | jq -r '.order | join(\",\")'"
    [ "$status" -eq 0 ]
    [ "$output" = "$ls_order" ]
}

# ── recon adapter: credentials must never reach item refs ────────────────────────────────────────
# Found 2026-08-14 running the pipeline end to end on live data for the first time. The adapter
# derived $REPO by stripping two exact prefixes (`git@github.com:` and `https://github.com/`). A
# remote of the form https://x-access-token:<token>@github.com/owner/repo.git matches NEITHER, so the
# whole URL -- including a live gho_ credential -- became $REPO and flowed into every item's `ref`,
# and from there into data.json, story.json, and the rendered HTML.
#
# These extract the REAL sed expression from the shipped adapter and run it, rather than testing a
# copied-out duplicate that could drift from the file it is meant to guard.

_repo_norm() {
    local url="$1" expr
    expr=$(grep -E '^\s*REPO="\$\(printf' "${BATS_TEST_DIRNAME}/../lib/recon/adapters/recon-adapter-github" \
        | sed -E "s/.*sed -E '([^']*)'.*/\1/")
    [ -n "$expr" ] || return 1
    printf '%s' "$url" | sed -E "$expr"
}

@test "recon adapter: a credentialed remote never leaks into the repo name" {
    run _repo_norm "https://x-access-token:gho_EXAMPLETOKEN123456789@github.com/owner/repo.git"
    [ "$status" -eq 0 ]
    [ "$output" = "owner/repo" ]
    [[ "$output" != *"gho_"* ]] || false
    [[ "$output" != *"@"* ]] || false
}

@test "recon adapter: basic-auth credentials in a remote are stripped too" {
    run _repo_norm "https://user:hunter2@github.com/owner/repo.git"
    [ "$output" = "owner/repo" ]
    [[ "$output" != *"hunter2"* ]] || false
}

@test "recon adapter: ordinary ssh and https remotes still normalize correctly" {
    run _repo_norm "git@github.com:owner/repo.git"
    [ "$output" = "owner/repo" ]
    run _repo_norm "https://github.com/owner/repo.git"
    [ "$output" = "owner/repo" ]
    run _repo_norm "ssh://git@github.com/owner/repo.git"
    [ "$output" = "owner/repo" ]
}

# ── guards: borg program arg handling (opus round-2 findings 3-5, round-3 finding 3) ──────────────
# These bugs are the class only execution catches: zsh hard-errors a bare `shift` at $#==0 (bash
# does not), and set -e turns that into a silent death. Same blind-spot shape as the BORG_REGISTRY
# inheritance bug — reading the code proved nothing until a test ran it.

@test "contract: argless 'borg program' reaches the list default instead of a shift crash" {
    echo '{"projects": {"p": {"path": "'"$BATS_TEST_TMPDIR"'/proj"}}}' > "$BORG_REGISTRY"
    mkdir -p "$BATS_TEST_TMPDIR/proj"
    run zsh -c "'$BORG' program"
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 program(s)"* ]] || false
}

@test "contract: 'borg program list' sweeps a registry manifest end to end" {
    mkdir -p "$BATS_TEST_TMPDIR/proj/.borg/programs"
    echo '{"projects": {"p": {"path": "'"$BATS_TEST_TMPDIR"'/proj"}}}' > "$BORG_REGISTRY"
    echo '{"program": "auth", "rows": [{"order": "1", "ref": "o/r#1"}]}' \
        > "$BATS_TEST_TMPDIR/proj/.borg/programs/auth.json"
    run zsh -c "'$BORG' program list"
    [ "$status" -eq 0 ]
    [[ "$output" == *"auth: 1 row(s)"* ]] || false
}

@test "contract: --recon outside plan dies named, not via argparse exit 2" {
    echo '{"projects": {}}' > "$BORG_REGISTRY"
    run zsh -c "'$BORG' program list --recon /tmp/x.json"
    [ "$status" -ne 0 ]
    [[ "$output" == *"--recon is only valid with 'plan'"* ]] || false
}

@test "contract: a trailing valueless --programs-dir dies named, not via a shift crash" {
    run zsh -c "'$BORG' program plan --programs-dir"
    [ "$status" -ne 0 ]
    [[ "$output" == *"--programs-dir needs a path"* ]] || false
    [[ "$output" != *"shift count"* ]] || false
}

@test "contract: an unknown program action prints usage including --recon" {
    run zsh -c "'$BORG' program bogus"
    [ "$status" -ne 0 ]
    [[ "$output" == *"list|plan|sync"* ]] || false
}

# ── scope + --local (S1) ─────────────────────────────────────────────────────
#
# Every case here traces to a defect the blind adversarial review found in the first-pass design of
# the one-front-door work; see docs/plans/directives/2026-08-25-link-front-door-hardened-spec.md.

_scope_two_repos() {
    mkdir -p "${BATS_TEST_TMPDIR}/ws/alpha" "${BATS_TEST_TMPDIR}/ws/beta"
    cat > "$BORG_REGISTRY" <<JSON
{"projects": {
  "alpha": {"path": "${BATS_TEST_TMPDIR}/ws/alpha", "status": "idle"},
  "beta":  {"path": "${BATS_TEST_TMPDIR}/ws/beta",  "status": "idle"}
}}
JSON
}

@test "contract: _borg_py forwards BORG_ORCHESTRATOR_ROOT from a NON-exported config value" {
    # THE INHERITANCE PROBE, and it must never put the variable in the environment.
    #
    # An earlier version of this test used `env BORG_ORCHESTRATOR_ROOT=... zsh "$BORG" ...` and was
    # WORTHLESS: zsh preserves the export attribute across borg.zsh:23's bare reassignment
    # (`FOO="${FOO:-default}"` keeps the export bit), so the child inherited the value whether or
    # not _borg_py named it. Deleting the _borg_py line left that test green -- verified by
    # mutation. It was the exact `test supplies the derived value` shape its own comment claimed to
    # be avoiding, which is why this file now uses config.zsh instead.
    #
    # config.zsh is sourced at borg.zsh:41, AFTER line 23's default, and assigns a PLAIN shell
    # variable with no export. The child therefore sees it ONLY if _borg_py forwards it by name.
    # Set the root to the repository's own path, where forwarded and defaulted disagree:
    #   forwarded  => cwd == root exactly    => "orchestrator"
    #   dropped    => Python defaults ~/dev  => cwd prefix-matches the registry => "repository"
    _scope_two_repos
    echo "BORG_ORCHESTRATOR_ROOT=\"${BATS_TEST_TMPDIR}/ws/alpha\"" > "$BORG_DIR/config.zsh"
    cd "${BATS_TEST_TMPDIR}/ws/alpha"
    run zsh "$BORG" link --json
    [ "$status" -eq 0 ]
    run bash -c "printf '%s' '$output' | jq -r '.scope.kind'"
    [ "$output" = "orchestrator" ]
}

@test "contract: link --json resolves scope to the repository containing cwd" {
    _scope_two_repos
    cd "${BATS_TEST_TMPDIR}/ws/beta"
    run env BORG_ORCHESTRATOR_ROOT="${BATS_TEST_TMPDIR}/ws" zsh "$BORG" link --json
    [ "$status" -eq 0 ]
    run bash -c "printf '%s' '$output' | jq -r '.scope.kind + \":\" + .scope.repository'"
    [ "$output" = "repository:beta" ]
}

@test "contract: an explicit project dominates cwd when resolving scope" {
    # B3, found independently by all three reviewers. Standing in alpha and asking for beta must
    # scope to BETA -- otherwise beta's header renders alpha's facts, a wrong answer not a missing
    # one. Every scripted caller passes a name from a fixed cwd (drone.zsh:964, borg.zsh:266).
    _scope_two_repos
    cd "${BATS_TEST_TMPDIR}/ws/alpha"
    run env BORG_ORCHESTRATOR_ROOT="${BATS_TEST_TMPDIR}/ws" zsh "$BORG" link --json beta
    [ "$status" -eq 0 ]
    run bash -c "printf '%s' '$output' | jq -r '.scope.repository + \"/\" + .focus.name'"
    [ "$output" = "beta/beta" ]
}

@test "contract: --local reaches the document through the dispatcher" {
    # The lenient `-*)` arm in _borg_link_dispatch silently swallows unknown flags and exits 0, so a
    # half-wired --local fails OPEN: the caller believes it opted down and the expensive path runs
    # anyway. This pins that the flag is actually matched and forwarded, not eaten.
    _scope_two_repos
    cd "${BATS_TEST_TMPDIR}/ws/alpha"
    run env BORG_ORCHESTRATOR_ROOT="${BATS_TEST_TMPDIR}/ws" zsh "$BORG" link --json --local
    [ "$status" -eq 0 ]
    run bash -c "printf '%s' '$output' | jq -r '.scope.local'"
    [ "$output" = "true" ]
}

@test "contract: --local defaults to false on the --json arm" {
    _scope_two_repos
    cd "${BATS_TEST_TMPDIR}/ws/alpha"
    run env BORG_ORCHESTRATOR_ROOT="${BATS_TEST_TMPDIR}/ws" zsh "$BORG" link --json
    run bash -c "printf '%s' '$output' | jq -r '.scope.local'"
    [ "$output" = "false" ]
}

@test "contract: --local is forwarded on the DEEP and OVERVIEW arms, asserted on the child's argv" {
    # The arms every hot call site actually uses, and the ones the document cannot prove:
    #   fzf preview (borg.zsh:266) -> bare positional -> DEEP
    #   drone status (drone.zsh:964) -> `borg link --local "$wname"` -> DEEP
    #   cmd_watch (borg.zsh:2222) -> `_borg_link_dispatch --local` with no args -> OVERVIEW
    #
    # This MUST assert argv, not the emitted document. An earlier version ran `link --json --local
    # beta` and claimed deep-arm coverage, but dispatch precedence is json > porcelain > deep, so it
    # returned from the --json block and never executed the deep arm at all. Deleting the deep arm's
    # forwarding line left the whole new test block green -- verified by mutation. render.deep reads
    # only `focus`, so `link beta` and `link --local beta` are byte-identical on stdout too: no
    # document-level or human-output assertion can ever pin this wire. Mock python3 and read "$@",
    # the same idiom as the config-surface test above.
    _scope_two_repos
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    export ARGVDUMP="${BATS_TEST_TMPDIR}/child-argv.txt"
    cat > "$MOCK_BIN/python3" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$ARGVDUMP"
exit 0
EOF
    chmod +x "$MOCK_BIN/python3"
    cd "${BATS_TEST_TMPDIR}/ws/alpha"

    run zsh "$BORG" link --local beta
    [ "$status" -eq 0 ]
    run cat "$ARGVDUMP"
    [[ "$output" == *"--deep"* ]] || false
    [[ "$output" == *"--local"* ]] || false
    [[ "$output" == *"-- beta"* ]] || false

    # ...and absent by default, so the assertion above is discriminating rather than always-true.
    run zsh "$BORG" link beta
    run cat "$ARGVDUMP"
    [[ "$output" == *"--deep"* ]] || false
    [[ "$output" != *"--local"* ]] || false

    run zsh "$BORG" link --local
    run cat "$ARGVDUMP"
    [[ "$output" == *"--local"* ]] || false

    run zsh "$BORG" link
    run cat "$ARGVDUMP"
    [[ "$output" != *"--local"* ]] || false
}
