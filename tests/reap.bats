#!/usr/bin/env bats
# Tests for the session reaper in lib/registry.zsh: the _borg_should_reap
# predicate and the borg_reap_overlay non-destructive display filter.
# The reaper downgrades stale active/waiting sessions (no live tmux window AND
# last_activity missing or older than BORG_REAP_STALE_HOURS) to idle.

load test_helper/setup

setup() {
    setup_temp_dirs
}

# ─── _borg_should_reap predicate ─────────────────────────────────────────────
# Args: <status> <last_activity_iso> <live: 1|0>. Exit 0 = reap, 1 = keep.

@test "_borg_should_reap keeps idle status" {
    run run_zsh_fn registry _borg_should_reap idle "" 0
    [ "$status" -ne 0 ]
}

@test "_borg_should_reap keeps a session with a live window" {
    run run_zsh_fn registry _borg_should_reap active "2020-01-01T00:00:00Z" 1
    [ "$status" -ne 0 ]
}

@test "_borg_should_reap reaps active with no live window and missing last_activity" {
    run run_zsh_fn registry _borg_should_reap active "" 0
    [ "$status" -eq 0 ]
}

@test "_borg_should_reap reaps active with no live window and old last_activity" {
    run run_zsh_fn registry _borg_should_reap active "2020-01-01T00:00:00Z" 0
    [ "$status" -eq 0 ]
}

@test "_borg_should_reap reaps waiting with no live window and old last_activity" {
    run run_zsh_fn registry _borg_should_reap waiting "2020-01-01T00:00:00Z" 0
    [ "$status" -eq 0 ]
}

@test "_borg_should_reap keeps active with recent last_activity" {
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    run run_zsh_fn registry _borg_should_reap active "$now" 0
    [ "$status" -ne 0 ]
}

@test "_borg_should_reap honors BORG_REAP_STALE_HOURS override" {
    # A years-old activity is reaped under the 12h default (see test above) but
    # kept under a very large threshold — proving the env override is honored.
    export BORG_REAP_STALE_HOURS=1000000
    run run_zsh_fn registry _borg_should_reap active "2020-01-01T00:00:00Z" 0
    [ "$status" -ne 0 ]
    unset BORG_REAP_STALE_HOURS
}

@test "_borg_should_reap boundary: activity STALE_HOURS+1h ago must reap (TZ-independent)" {
    # Compute a UTC timestamp BORG_REAP_STALE_HOURS+1 hours in the past.
    # Uses `date -u` so the assertion holds regardless of the host timezone.
    # This test would FAIL under the old buggy local-time parse on a non-UTC host
    # (e.g. America/Denver) because the age would be under-counted by 6-7h.
    local threshold=12
    local stale_ts
    stale_ts=$(date -u -v-"$((threshold + 1))"H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
        || date -u -d "$((threshold + 1)) hours ago" +%Y-%m-%dT%H:%M:%SZ)
    export BORG_REAP_STALE_HOURS=$threshold
    run run_zsh_fn registry _borg_should_reap active "$stale_ts" 0
    [ "$status" -eq 0 ]
    unset BORG_REAP_STALE_HOURS
}

@test "_borg_should_reap boundary: activity STALE_HOURS-1h ago must be kept (TZ-independent)" {
    # Compute a UTC timestamp BORG_REAP_STALE_HOURS-1 hours in the past.
    # Under a correct UTC parse this is fresh enough to keep. Under the old buggy
    # local-time parse on a non-UTC host the age would be wrong, but the test
    # verifies correct behavior post-fix.
    local threshold=12
    local fresh_ts
    fresh_ts=$(date -u -v-"$((threshold - 1))"H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
        || date -u -d "$((threshold - 1)) hours ago" +%Y-%m-%dT%H:%M:%SZ)
    export BORG_REAP_STALE_HOURS=$threshold
    run run_zsh_fn registry _borg_should_reap active "$fresh_ts" 0
    [ "$status" -ne 0 ]
    unset BORG_REAP_STALE_HOURS
}

# ─── borg_reap_overlay stream filter ─────────────────────────────────────────
# No tmux helper is loaded in the test, so _borg_live_windows is empty and every
# project is treated as having no live window.

@test "borg_reap_overlay downgrades a stale project to idle and records _reaped_from" {
    local json
    json='{"projects":{"stale":{"status":"active","last_activity":"2020-01-01T00:00:00Z","path":"/tmp/stale"}}}'
    result=$(printf '%s' "$json" | run_zsh_fn registry borg_reap_overlay)
    status=$(printf '%s' "$result" | jq -r '.projects.stale.status')
    from=$(printf '%s' "$result" | jq -r '.projects.stale._reaped_from')
    [ "$status" = "idle" ]
    [ "$from" = "active" ]
}

@test "borg_reap_overlay preserves a fresh active project" {
    local now json
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    json="{\"projects\":{\"fresh\":{\"status\":\"active\",\"last_activity\":\"${now}\",\"path\":\"/tmp/fresh\"}}}"
    result=$(printf '%s' "$json" | run_zsh_fn registry borg_reap_overlay)
    status=$(printf '%s' "$result" | jq -r '.projects.fresh.status')
    from=$(printf '%s' "$result" | jq -r '.projects.fresh._reaped_from // "none"')
    [ "$status" = "active" ]
    [ "$from" = "none" ]
}

@test "borg_reap_overlay leaves an already-idle project untouched" {
    local json
    json='{"projects":{"done":{"status":"idle","path":"/tmp/done"}}}'
    result=$(printf '%s' "$json" | run_zsh_fn registry borg_reap_overlay)
    status=$(printf '%s' "$result" | jq -r '.projects.done.status')
    from=$(printf '%s' "$result" | jq -r '.projects.done._reaped_from // "none"')
    [ "$status" = "idle" ]
    [ "$from" = "none" ]
}
