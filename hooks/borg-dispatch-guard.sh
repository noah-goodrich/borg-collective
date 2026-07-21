#!/usr/bin/env bash
# borg-dispatch-guard.sh — PreToolUse hook: the >=92% dispatch hard-stop veto.
#
# Denies NEW nanoprobe/workflow dispatch (Agent|Workflow tool calls) when the usage guardian's
# latest sample shows session_pct at/above the halt threshold, so a near-cap session stops opening
# fresh long-running work it cannot finish before the 5-hour window resets. The checkpoint SWEEP
# (bin/borg-usage-watch) preserves in-flight work; this hook stops NEW work from piling on.
#
# CONTRACT — fail OPEN. A guardian problem must NEVER wedge dispatch. Every uncertainty exits 0
# (allow): disabled, missing/garbage/stale sample, non-ok row, non-numeric pct, missing jq, empty
# stdin, or a non-dispatch tool. It denies (exit 2, reason on stderr) ONLY when armed AND the last
# sample is a FRESH ok row at/above the threshold.
#
# DEFAULT-OFF: inert unless BORG_USAGE_HALT_ENABLED=1. Ships off until live-cap validation + data
# support arming (see docs/plans/directives/2026-07-08-usage-guardian-build.md).
#
# Env knobs:
#   BORG_USAGE_HALT_ENABLED   master switch (default 0 = off)
#   BORG_USAGE_HALT_PCT       threshold (default 92)
#   BORG_USAGE_HALT_TTL_SEC   max sample age to trust, seconds (default 300)
#   BORG_USAGE_SAMPLES        samples file (default ~/.local/state/borg/usage-samples.jsonl)
#   BORG_USAGE_NOW_EPOCH      "now" override (tests only)
#
# Registered as a PreToolUse (matcher Agent|Workflow) hook via scripts/build-plugin.sh.

set -euo pipefail

# ── Master switch: default-OFF, ships inert ──────────────────────────────────
[[ "${BORG_USAGE_HALT_ENABLED:-0}" == "1" ]] || exit 0

# ── jq absent => fail open (never block on a missing dependency) ─────────────
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat /dev/stdin 2>/dev/null || true)
[[ -z "$INPUT" ]] && exit 0

# ── Only gate dispatch tools; anything else passes untouched ─────────────────
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || true)
case "$TOOL_NAME" in
    Agent|Workflow) ;;
    *) exit 0 ;;
esac

HALT_PCT="${BORG_USAGE_HALT_PCT:-92}"
TTL="${BORG_USAGE_HALT_TTL_SEC:-300}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/borg"
SAMPLES="${BORG_USAGE_SAMPLES:-$STATE_DIR/usage-samples.jsonl}"

# ── No sample yet => fail open ───────────────────────────────────────────────
[[ -f "$SAMPLES" ]] || exit 0

last=$(tail -n 1 "$SAMPLES" 2>/dev/null || true)
[[ -z "$last" ]] && exit 0

# ── Only an ok row carries a trustworthy reading; idle/error/suspect => open ──
status=$(printf '%s' "$last" | jq -r '.status // ""' 2>/dev/null || true)
[[ "$status" == "ok" ]] || exit 0

# ── session_pct must be a real number; anything else => open ─────────────────
session_pct=$(printf '%s' "$last" | jq -r 'if (.session_pct|type) == "number" then (.session_pct|floor) else "" end' 2>/dev/null || true)
[[ "$session_pct" =~ ^[0-9]+$ ]] || exit 0

# ── Freshness: a stale sample (poller stopped) must NOT freeze dispatch ───────
ts=$(printf '%s' "$last" | jq -r '.ts // ""' 2>/dev/null || true)
[[ -n "$ts" ]] || exit 0

# ISO-8601 UTC -> epoch (both date dialects); unparseable => 0 => fail open.
_iso_to_epoch() {
    TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$1" +%s 2>/dev/null \
        || date -u -d "$1" +%s 2>/dev/null \
        || echo 0
}

now="${BORG_USAGE_NOW_EPOCH:-$(date +%s)}"
row_epoch=$(_iso_to_epoch "$ts")
[[ "$row_epoch" -gt 0 ]] || exit 0
age=$(( now - row_epoch ))
# Negative age (future ts / clock skew) is suspicious => fail open. Stale => fail open.
if (( age < 0 || age > TTL )); then
    exit 0
fi

# ── Below threshold => allow ─────────────────────────────────────────────────
if (( session_pct < HALT_PCT )); then
    exit 0
fi

# ── DENY: fresh, ok, at/above threshold, armed ───────────────────────────────
resets=$(printf '%s' "$last" | jq -r '.resets_at // "unknown"' 2>/dev/null || echo "unknown")
printf 'borg dispatch guard: session usage at %s%% (>= halt threshold %s%%), resets %s.\nNew Agent/Workflow dispatch is halted to preserve headroom for in-flight work — finish or checkpoint current work, then use /borg-resume after the reset. (Disable with BORG_USAGE_HALT_ENABLED=0.)\n' \
    "$session_pct" "$HALT_PCT" "$resets" >&2
exit 2
