#!/usr/bin/env bats
# The machine-local state root, one resolver per shell (Python is pinned in borg_core/test_paths.py):
#
#   root = ${XDG_STATE_HOME:-$HOME/.local/state}/borg      (blank XDG_STATE_HOME == unset)
#
# Every case UNSETS XDG_STATE_HOME and derives the default from the sandboxed HOME, so the value
# under test is never pre-supplied by the harness. The set/blank cases set it deliberately.

load test_helper/setup

STATE_LIB_ZSH="${BATS_TEST_DIRNAME}/../lib/state-root.zsh"
STATE_LIB_BASH="${BATS_TEST_DIRNAME}/../lib/borg-hooks.sh"

setup() {
    setup_temp_dirs
    unset XDG_STATE_HOME
}

_zsh() { zsh -c "source '$STATE_LIB_ZSH' && _borg_state_root"; }
_bash() { bash -c "source '$STATE_LIB_BASH' && _borg_state_root"; }

@test "zsh resolver: unset XDG_STATE_HOME derives from HOME" {
    run _zsh
    [ "$status" -eq 0 ]
    [ "$output" = "$HOME/.local/state/borg" ]
}

@test "zsh resolver: XDG_STATE_HOME wins" {
    XDG_STATE_HOME="$BATS_TEST_TMPDIR/xdg" run _zsh
    [ "$output" = "$BATS_TEST_TMPDIR/xdg/borg" ]
}

@test "zsh resolver: blank XDG_STATE_HOME is treated as unset" {
    XDG_STATE_HOME="" run _zsh
    [ "$output" = "$HOME/.local/state/borg" ]
}

@test "bash resolver: unset XDG_STATE_HOME derives from HOME" {
    run _bash
    [ "$status" -eq 0 ]
    [ "$output" = "$HOME/.local/state/borg" ]
}

@test "bash resolver: XDG_STATE_HOME wins" {
    XDG_STATE_HOME="$BATS_TEST_TMPDIR/xdg" run _bash
    [ "$output" = "$BATS_TEST_TMPDIR/xdg/borg" ]
}

@test "bash resolver: blank XDG_STATE_HOME is treated as unset" {
    XDG_STATE_HOME="" run _bash
    [ "$output" = "$HOME/.local/state/borg" ]
}

# ─── _borg_operational_file: the reader-side dual lookup (expand phase) ──────────────────────────
# Sandbox: HOME, XDG_CONFIG_HOME, XDG_STATE_HOME all point inside BATS_TEST_TMPDIR, and BORG_DIR is
# unset so the helper must derive the old location itself.

_dual_setup() {
    unset BORG_DIR
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/cfg" XDG_STATE_HOME="$BATS_TEST_TMPDIR/st"
    OLD="$XDG_CONFIG_HOME/borg"
    NEW="$XDG_STATE_HOME/borg"
}

_zsh_op() { zsh -c "source '$STATE_LIB_ZSH' && _borg_operational_file '$1'"; }
_bash_op() { bash -c "source '$STATE_LIB_BASH' && _borg_operational_file '$1'"; }

@test "zsh operational_file: old-only resolves to the config location" {
    _dual_setup
    mkdir -p "$OLD" && : > "$OLD/agents.jsonl"
    run _zsh_op agents.jsonl
    [ "$output" = "$OLD/agents.jsonl" ]
}

@test "zsh operational_file: both present, the state root wins" {
    _dual_setup
    mkdir -p "$OLD" "$NEW" && : > "$OLD/agents.jsonl" && : > "$NEW/agents.jsonl"
    run _zsh_op agents.jsonl
    [ "$output" = "$NEW/agents.jsonl" ]
}

@test "zsh operational_file: neither present names the old path, and a subdir name works" {
    _dual_setup
    run _zsh_op recon/last-run
    [ "$output" = "$OLD/recon/last-run" ]
}

@test "bash operational_file: old-only resolves to the config location" {
    _dual_setup
    mkdir -p "$OLD" && : > "$OLD/agents.jsonl"
    run _bash_op agents.jsonl
    [ "$output" = "$OLD/agents.jsonl" ]
}

@test "bash operational_file: both present, the state root wins" {
    _dual_setup
    mkdir -p "$OLD" "$NEW" && : > "$OLD/agents.jsonl" && : > "$NEW/agents.jsonl"
    run _bash_op agents.jsonl
    [ "$output" = "$NEW/agents.jsonl" ]
}

@test "bash operational_file: neither present names the old path" {
    _dual_setup
    run _bash_op memory-hits.log
    [ "$output" = "$OLD/memory-hits.log" ]
}

# ─── real readers ────────────────────────────────────────────────────────────────────────────────

@test "reader (bash): memory-hits-report reads an old-only log" {
    _dual_setup
    mkdir -p "$OLD" "$HOME/.claude/projects/-p"
    printf '{}' > "$HOME/.claude/projects/-p/s1.jsonl"
    printf '%s\ts1\tp\tM.md\t1\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$OLD/memory-hits.log"
    BORG_DIR="$OLD" run bash "${BATS_TEST_DIRNAME}/../bin/memory-hits-report"
    [[ "$output" == *"reads:    1"* ]] || false
}

@test "reader (bash): memory-hits-report prefers the state root's log when both exist" {
    _dual_setup
    mkdir -p "$OLD" "$NEW" "$HOME/.claude/projects/-p"
    printf '{}' > "$HOME/.claude/projects/-p/s1.jsonl"
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '%s\ts1\tp\tM.md\t1\n' "$ts" > "$OLD/memory-hits.log"
    printf '%s\ts1\tp\tM.md\t1\n%s\ts1\tp\tM.md\t1\n%s\ts1\tp\tM.md\t1\n' "$ts" "$ts" "$ts" > "$NEW/memory-hits.log"
    BORG_DIR="$OLD" run bash "${BATS_TEST_DIRNAME}/../bin/memory-hits-report"
    [[ "$output" == *"reads:    3"* ]] || false
}

_agents_line() { printf '{"id":"%s0000000","agent_type":"borg-nanoprobe","summary":"s","finished_at":"t"}\n' "$1"; }

@test "reader (zsh): borg nanoprobes reads an old-only agents.jsonl" {
    _dual_setup
    mkdir -p "$OLD" && _agents_line oldonly > "$OLD/agents.jsonl"
    BORG_DIR="$OLD" run zsh "${BATS_TEST_DIRNAME}/../borg.zsh" nanoprobes
    [ "$status" -eq 0 ]
    [[ "$output" == *"oldonly0"* ]] || false
}

@test "reader (zsh): borg nanoprobes prefers the state root's agents.jsonl when both exist" {
    _dual_setup
    mkdir -p "$OLD" "$NEW" && _agents_line oldside > "$OLD/agents.jsonl" && _agents_line newside > "$NEW/agents.jsonl"
    BORG_DIR="$OLD" run zsh "${BATS_TEST_DIRNAME}/../borg.zsh" nanoprobes
    [[ "$output" == *"newside0"* ]] || false
    [[ "$output" != *"oldside0"* ]] || false
}
