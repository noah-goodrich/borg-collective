#!/usr/bin/env bash
# borg-supabase-guard.sh — PreToolUse hook (matcher: Bash): shared-Supabase-stack hard-stop.
#
# There is ONE shared local Supabase stack, owned by the stillpoint repo
# ($BORG_STILLPOINT_SUPABASE_DIR, default $HOME/dev/stillpoint). Containers are named
# supabase_*_stillpoint. Every other project attaches to it over the external
# supabase_network_stillpoint Docker network; only stillpoint's own borg-hooks/pre-up.sh (or a
# human working directly in the stillpoint repo) may boot, stop, or reset it.
#
# 2026-07-24 outage: a drone ran `supabase start` from a non-stillpoint project directory to
# "un-wedge" a stack, which booted a COMPETING local stack that collided on host ports
# 54321/54322 and took the shared stack down for every project. Docs alone did not prevent this —
# this hook is the hard guard.
#
# DENY (exit 2, reason on stderr) when EITHER:
#   1. `supabase start` / `supabase stop` / `supabase db reset` is invoked with an effective
#      target directory that is NOT the shared stillpoint dir. Effective dir is resolved PER
#      lifecycle segment, in the order the shell would actually apply it: (a) the supabase
#      command's own `--workdir <path>`/`--workdir=<path>` if present; else (b) the target of the
#      nearest preceding `cd <dir>` in the SAME `&&`/`;` chain (a relative cd is resolved against
#      whatever directory the chain is in at that point, starting from `.cwd`); else (c) `.cwd`.
#      The directory the command would ACTUALLY run in always wins — `.cwd` never overrides an
#      explicit in-chain `cd`.
#   2. The command force-stops the shared stack from outside stillpoint: `docker stop|kill|rm`
#      targeting a `supabase_*_stillpoint` container name, or any docker/xargs invocation that
#      filters on `name=stillpoint` (the `docker ps --filter name=stillpoint -q | xargs -r docker
#      stop` trick that caused the outage).
#
# ALLOW (exit 0, no output) everything else, including:
#   - The same `supabase start`/`stop`/`db reset` commands run FROM the stillpoint dir (so
#     borg-hooks/pre-up.sh and stillpoint's own reset/reseed workflows are unaffected).
#   - `supabase db push`, `supabase migration list|up`, `supabase link`, and any other `supabase`
#     subcommand — only `start`, `stop`, and `db reset` boot/kill a local stack.
#   - Any command unrelated to supabase/docker-stillpoint.
#
# Fail-open on parse trouble (missing jq, empty/garbage stdin) — this hook must never wedge
# unrelated Bash calls; it only actively blocks the specific dangerous shapes above.
#
# Env knobs:
#   BORG_STILLPOINT_SUPABASE_DIR   shared stack dir (default $HOME/dev/stillpoint)
#
# Registered as a PreToolUse (matcher Bash) hook via scripts/build-plugin.sh.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat /dev/stdin 2>/dev/null)
[[ -z "$INPUT" ]] && exit 0

COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
[[ -z "$COMMAND" || "$COMMAND" == "null" ]] && exit 0

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)

STILLPOINT_DIR="${BORG_STILLPOINT_SUPABASE_DIR:-$HOME/dev/stillpoint}"
# Normalize: strip a single trailing slash so comparisons are exact-path, not prefix.
STILLPOINT_DIR="${STILLPOINT_DIR%/}"

_deny() {
    # shellcheck disable=SC2016  # backtick is literal markdown formatting, not substitution
    printf 'borg supabase guard: %s\n\nThis project shares the single stillpoint Supabase stack. Booting/killing a local stack collides on ports 54321/54322 and takes the shared stack down for every project. To reset/reseed LOCAL data, run it from the stillpoint repo (~/dev/stillpoint). `supabase db push`/migrations against Cloud are fine.\n' \
        "$1" >&2
    exit 2
}

# ── Trim leading/trailing whitespace ──────────────────────────────────────────
_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# ── Strip surrounding quotes, a trailing slash, and expand a leading ~ ───────
_normalize_dir() {
    local dir="$1"
    dir="${dir%\"}"; dir="${dir#\"}"
    dir="${dir%\'}"; dir="${dir#\'}"
    dir="${dir%/}"

    # shellcheck disable=SC2088  # glob-pattern comparison, not a literal path we execute
    if [[ "$dir" == "~" ]]; then
        dir="$HOME"
    elif [[ "$dir" == "~/"* ]]; then
        dir="$HOME/${dir#\~/}"
    fi

    printf '%s' "$dir"
}

# ── Collapse `.`/`..`/duplicate-slash components in a (possibly relative) path.
# "/a/b/../c" -> "/a/c"; a leading "/" is preserved iff the input had one.
# Uses ${out[$((n-1))]}/unset 'out[n-1]' (NOT the bash-4.3+ out[-1] form) — macOS ships bash 3.2,
# and this hook must run under it.
_collapse_path() {
    local path="$1" abs=0
    [[ "$path" == /* ]] && abs=1
    local -a parts out
    IFS='/' read -ra parts <<< "$path"
    local p last_idx
    for p in "${parts[@]}"; do
        case "$p" in
            ""|".") continue ;;
            "..")
                last_idx=$(( ${#out[@]} - 1 ))
                if (( last_idx >= 0 )) && [[ "${out[$last_idx]}" != ".." ]]; then
                    unset "out[$last_idx]"
                    out=("${out[@]}")
                else
                    if (( abs == 0 )); then
                        out+=("..")
                    fi
                fi
                ;;
            *) out+=("$p") ;;
        esac
    done
    local joined
    joined=$(IFS=/; printf '%s' "${out[*]:-}")
    if (( abs )); then
        printf '/%s' "$joined"
    else
        printf '%s' "$joined"
    fi
}

# ── Resolve a `cd` target against the chain's current dir (base) ────────────
_resolve_cd_target() {
    local base="$1" target
    target=$(_normalize_dir "$2")
    if [[ "$target" == /* ]]; then
        _collapse_path "$target"
    else
        _collapse_path "${base%/}/$target"
    fi
}

# ── --workdir <path> / --workdir=<path> on a single segment, if present ─────
_extract_workdir() {
    local cmd="$1" dir=""
    if [[ "$cmd" =~ --workdir=([^[:space:]]+) ]]; then
        dir="${BASH_REMATCH[1]}"
    elif [[ "$cmd" =~ --workdir[[:space:]]+([^[:space:]]+) ]]; then
        dir="${BASH_REMATCH[1]}"
    fi
    printf '%s' "$dir"
}

# ── Split on top-level ; && chain operators — one segment per invocation,
# in ORDER (order matters: a `cd` segment must be seen before the segments
# that follow it in the same chain, so the segments below are NOT reordered).
_segments() {
    printf '%s' "$1" | sed -E 's/[[:space:]]*(&&|;)[[:space:]]*/\n/g'
}

# ── Rule 2: force-stop the shared stack by name/filter, from anywhere ───────
if printf '%s' "$COMMAND" | grep -qE '(^|[[:space:]])docker[[:space:]]+(compose[[:space:]]+)?(stop|kill|rm)([[:space:]].*)?[[:space:]]supabase_[a-zA-Z0-9_]*_stillpoint([[:space:]]|$)'; then
    _deny "command force-stops the shared stillpoint Supabase containers directly (docker stop/kill/rm on a supabase_*_stillpoint container)"
fi

if printf '%s' "$COMMAND" | grep -qE -- '--filter[[:space:]]+name=stillpoint'; then
    _deny "command filters docker by name=stillpoint and pipes into a stop/kill — this is the exact trick that took the shared stack down on 2026-07-24"
fi

# ── Rule 1: supabase start | stop | db reset outside the stillpoint dir ─────
# chain_dir tracks "the directory this &&/; chain is currently in", updated as each `cd` segment
# is walked IN ORDER — it starts at .cwd (the directory the whole command line actually launches
# from) and is only ever advanced by an explicit `cd` segment seen earlier in the SAME chain.
chain_dir=$(_normalize_dir "$CWD")
SEGMENTS=$(_segments "$COMMAND")
while IFS= read -r raw_seg; do
    seg=$(_trim "$raw_seg")
    [[ -z "$seg" ]] && continue

    # A segment that IS a `cd` invocation advances the chain's current dir for every segment
    # that follows it, then contributes nothing else (a bare `cd` never boots a local stack).
    if [[ "$seg" =~ ^cd[[:space:]]+([^[:space:]]+) ]]; then
        chain_dir=$(_resolve_cd_target "$chain_dir" "${BASH_REMATCH[1]}")
        continue
    fi

    # Only consider segments that actually invoke the supabase CLI.
    printf '%s' "$seg" | grep -qE '(^|[[:space:]])supabase([[:space:]]|$)' || continue

    is_dangerous=0
    reason=""
    if printf '%s' "$seg" | grep -qE '(^|[[:space:]])supabase([[:space:]].*)?[[:space:]]start([[:space:]]|$)'; then
        is_dangerous=1; reason="supabase start"
    elif printf '%s' "$seg" | grep -qE '(^|[[:space:]])supabase([[:space:]].*)?[[:space:]]stop([[:space:]]|$)'; then
        is_dangerous=1; reason="supabase stop"
    elif printf '%s' "$seg" | grep -qE '(^|[[:space:]])supabase([[:space:]].*)?[[:space:]]db[[:space:]]+reset([[:space:]]|$)'; then
        is_dangerous=1; reason="supabase db reset"
    fi

    (( is_dangerous == 0 )) && continue

    workdir=$(_extract_workdir "$seg")
    if [[ -n "$workdir" ]]; then
        eff_dir=$(_normalize_dir "$workdir")
    else
        eff_dir="$chain_dir"
    fi

    if [[ "$eff_dir" != "$STILLPOINT_DIR" ]]; then
        _deny "\`$reason\` targets a local Supabase stack, but the effective directory (${eff_dir:-<unknown>}) is not the shared stillpoint dir ($STILLPOINT_DIR)"
    fi
done <<< "$SEGMENTS"

exit 0
