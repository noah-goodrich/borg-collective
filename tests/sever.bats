#!/usr/bin/env bats
# Tests for the checkpoint-freshness helpers used by `borg sever` (cmd_down):
# _borg_has_recent_checkpoint and _borg_offer_checkpoint (borg.zsh).
# Regression coverage for #98: checkpoint freshness must be judged by file
# mtime, not by the timestamp embedded in the checkpoint filename.

load test_helper/setup

BORG_CMD="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs
    PDIR="$BATS_TEST_TMPDIR/project"
    CP_DIR="$PDIR/.borg/checkpoints"
    mkdir -p "$CP_DIR"
}

# Source borg.zsh (dispatching a harmless `help` invocation, output discarded)
# so its top-level functions are defined in the current zsh, then invoke the
# named function with the real arguments.
run_borg_fn() {
    local fn="$1"
    shift
    zsh -c "
        BORG_HOME='${BATS_TEST_DIRNAME}/..'
        orig_args=(\"\$@\")
        set -- help
        source '$BORG_CMD' >/dev/null 2>&1
        $fn \"\${orig_args[@]}\"
    " -- "$@"
}

# ─── _borg_has_recent_checkpoint ─────────────────────────────────────────────

@test "_borg_has_recent_checkpoint returns true for a fresh checkpoint" {
    touch "$CP_DIR/2026-08-10-0000.md"
    run run_borg_fn _borg_has_recent_checkpoint "$PDIR" 8
    [ "$status" -eq 0 ]
}

@test "_borg_has_recent_checkpoint returns false for a stale checkpoint" {
    touch -t 202001010000 "$CP_DIR/2020-01-01-0000.md"
    run run_borg_fn _borg_has_recent_checkpoint "$PDIR" 8
    [ "$status" -ne 0 ]
}

@test "_borg_has_recent_checkpoint returns false when .borg/checkpoints is missing" {
    rm -rf "$PDIR/.borg"
    run run_borg_fn _borg_has_recent_checkpoint "$PDIR" 8
    [ "$status" -ne 0 ]
}

@test "_borg_has_recent_checkpoint uses mtime, not the filename timestamp (#98)" {
    # File name looks stale/skewed, but the mtime is fresh (just touched) —
    # the function must report fresh, proving it doesn't parse the filename.
    touch "$CP_DIR/2026-01-01-0000.md"
    run run_borg_fn _borg_has_recent_checkpoint "$PDIR" 8
    [ "$status" -eq 0 ]
}

@test "_borg_has_recent_checkpoint honors a non-default threshold_hours" {
    # 30 hours old: stale under the 8h default, fresh under a 48h threshold.
    local stale_ts
    stale_ts=$(date -v-30H +%Y%m%d%H%M 2>/dev/null || date -d "30 hours ago" +%Y%m%d%H%M)
    touch -t "$stale_ts" "$CP_DIR/2026-08-01-0000.md"

    run run_borg_fn _borg_has_recent_checkpoint "$PDIR" 8
    [ "$status" -ne 0 ]

    run run_borg_fn _borg_has_recent_checkpoint "$PDIR" 48
    [ "$status" -eq 0 ]
}

# ─── _borg_offer_checkpoint message ──────────────────────────────────────────
# Declining ("n") returns immediately without touching tmux, so we can assert
# on the warning text alone.

@test "_borg_offer_checkpoint interpolates the actual threshold_hours into its message" {
    run bash -c "printf 'n\n' | run_borg_fn=1 zsh -c \"
        BORG_HOME='${BATS_TEST_DIRNAME}/..'
        set -- help
        source '$BORG_CMD' >/dev/null 2>&1
        _borg_offer_checkpoint mywindow '$PDIR' 5 48
    \""
    [[ "$output" == *"last 48 hours"* ]] || false
}

@test "_borg_offer_checkpoint falls back to the default 8h message when no threshold is passed" {
    run bash -c "zsh -c \"
        BORG_HOME='${BATS_TEST_DIRNAME}/..'
        set -- help
        source '$BORG_CMD' >/dev/null 2>&1
        _borg_offer_checkpoint mywindow '$PDIR' 5
    \" <<< 'n'"
    [[ "$output" == *"last 8 hours"* ]] || false
}
