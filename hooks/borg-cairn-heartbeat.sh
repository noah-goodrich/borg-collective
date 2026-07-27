#!/usr/bin/env bash
# borg-cairn-heartbeat.sh — Stop hook: throttled cairn health heartbeat.
#
# Prints ONE line reporting cairn health + recording freshness, at most once per
# BORG_CAIRN_HEARTBEAT_INTERVAL_SEC (default 1800s = 30min), via the same timestamp-file
# throttle idiom used elsewhere in this repo (see bin/borg-usage-watch's guardian-state
# idempotence and hooks/borg-dispatch-guard.sh's sample-freshness check). Green: dim single
# line. Red (DEGRADED): loud stderr line so an outage is impossible to miss across a session.
#
# CONTRACT — fail OPEN, never blocking. Any uncertainty (jq/cairn/timeout absent, throttle-state
# unreadable, health call failing) degrades to silence or a best-effort line — never a non-zero
# exit, never a hang (the underlying `cairn health` call is itself wrapped in `timeout`).
#
# Env knobs:
#   BORG_CAIRN_HEARTBEAT_ENABLED       master switch (default 1 — fail-open, print-only)
#   BORG_CAIRN_HEARTBEAT_INTERVAL_SEC  throttle window, seconds (default 1800)
#   BORG_CAIRN_HEARTBEAT_STATE         throttle timestamp file
#                                        (default ~/.local/state/borg/cairn-heartbeat-last)
#
# Registered as a Stop hook via scripts/build-plugin.sh.

set -euo pipefail

[[ "${BORG_CAIRN_HEARTBEAT_ENABLED:-1}" == "1" ]] || exit 0

# shellcheck source=../lib/borg-hooks.sh
source "${HOME}/.claude/lib/borg-hooks.sh" 2>/dev/null || exit 0

INTERVAL="${BORG_CAIRN_HEARTBEAT_INTERVAL_SEC:-1800}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/borg"
STATE_FILE="${BORG_CAIRN_HEARTBEAT_STATE:-$STATE_DIR/cairn-heartbeat-last}"

now=$(date +%s)

# Throttle: skip silently if we fired within the last INTERVAL seconds.
if [[ -f "$STATE_FILE" ]]; then
    last=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
    [[ "$last" =~ ^[0-9]+$ ]] || last=0
    if (( now - last < INTERVAL )); then
        exit 0
    fi
fi

line=$(_borg_cairn_health_line 2>/dev/null) || line=""
[[ -z "$line" ]] && exit 0

if [[ "$line" == cairn:\ DEGRADED* ]]; then
    printf '\n\033[1;31m▸ %s\033[0m\n\n' "$line" >&2
else
    printf '\033[2m▸ %s\033[0m\n' "$line" >&2
fi

mkdir -p "$STATE_DIR" 2>/dev/null || true
printf '%s' "$now" > "${STATE_FILE}.tmp.$$" 2>/dev/null && mv "${STATE_FILE}.tmp.$$" "$STATE_FILE" 2>/dev/null || true

exit 0
