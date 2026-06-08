#!/usr/bin/env sh
# shellcheck shell=bash
# lib/reaper.sh — shared reaper predicate for borg hooks and the zsh CLI.
#
# Sourceable from both bash (hooks) and zsh (lib/registry.zsh). Provides:
#   BORG_REAP_STALE_HOURS — staleness threshold in hours (default 12)
#   _borg_should_reap <status> <last_activity_iso> <has_live_window: 1|0>
#
# NOTE: _borg_should_reap uses `date -j -f` without `-u`, so the computed age is
# off by the host's UTC offset. This is a known bug tracked in:
#   docs/plans/directives/2026-06-06-reaper-utc-timezone-offset.md
# Do not "fix" it here — the directive has the acceptance criteria.

BORG_REAP_STALE_HOURS="${BORG_REAP_STALE_HOURS:-12}"

# Predicate: should this project's active/waiting status be reaped to idle?
# Args: <status> <last_activity_iso> <has_live_window: 1|0>
# Returns 0 (reap) when status is active/waiting AND no live window AND
# last_activity is missing or older than BORG_REAP_STALE_HOURS. Returns 1 (keep).
_borg_should_reap() {
    local st="$1" last="$2" live="${3:-0}"
    if [ "$st" != "active" ] && [ "$st" != "waiting" ]; then
        return 1
    fi
    if [ "$live" = "1" ]; then
        return 1
    fi
    local threshold="${BORG_REAP_STALE_HOURS:-12}"
    if [ -z "$last" ] || [ "$last" = "null" ]; then
        return 0
    fi
    local epoch_ts epoch_now age_h
    epoch_ts=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last" +%s 2>/dev/null \
        || date -d "$last" +%s 2>/dev/null) || return 0
    epoch_now=$(date +%s)
    age_h=$(( (epoch_now - epoch_ts) / 3600 ))
    [ "$age_h" -ge "$threshold" ]
}
