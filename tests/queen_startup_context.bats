#!/usr/bin/env bats
# What a Queen session loads at startup (issue 429). Two producers feed it: `_borg_orchestrator_context` (the system
# prompt `borg init` builds) and the SessionStart hook (`hooks/borg-link-down.sh`, orchestrator mode). The roster
# belongs to the hook alone, because only the hook carries each repository's next action; the system prompt carries
# checkpoint excerpts, and those must come from the repositories touched most recently, not from registry order.
#
# Every repository name here is a placeholder. The fixtures never state which repositories should win: each one
# carries a last_activity, and the code under test has to derive the order.

load test_helper/setup

BORG="${BATS_TEST_DIRNAME}/../borg.zsh"
BORG_START="${BATS_TEST_DIRNAME}/../hooks/borg-link-down.sh"

setup() {
    setup_temp_dirs
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    unset BORG_QUEEN_IDLE_DAYS
    mkdir -p "$BORG_DIR" "$HOME/dev"
}

# An ISO timestamp N days in the past; BSD date first, GNU date second.
_iso_days_ago() {
    date -u -v-"$1"d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "$1 days ago" +%Y-%m-%dT%H:%M:%SZ
}

# A repository directory carrying one checkpoint whose body names the repository.
_repo_with_checkpoint() {
    local dir="${BATS_TEST_TMPDIR}/ws/$1"
    mkdir -p "$dir/.borg/checkpoints"
    printf '**tl;dr** -- MARK_%s\n\n## Next session\n\nNext step for %s.\n' "$1" "$1" \
        > "$dir/.borg/checkpoints/2026-01-01-0900.md"
    printf '%s' "$dir"
}

# _registry_entry <name> <status> <days-ago|never>: one entry for the registry JSON, with a checkpoint on disk.
_registry_entry() {
    local dir
    dir=$(_repo_with_checkpoint "$1")
    if [ "$3" = "never" ]; then
        printf '"%s":{"path":"%s","status":"%s","source":"cli"}' "$1" "$dir" "$2"
    else
        printf '"%s":{"path":"%s","status":"%s","source":"cli","last_activity":"%s"}' \
            "$1" "$dir" "$2" "$(_iso_days_ago "$3")"
    fi
}

# _write_registry <name:status:days>...  (registry order is the argument order)
_write_registry() {
    local spec out="" sep=""
    for spec in "$@"; do
        IFS=: read -r n s d <<< "$spec"
        out+="${sep}$(_registry_entry "$n" "$s" "$d")"
        sep=","
    done
    printf '{"repositories":{%s}}' "$out" > "$BORG_REGISTRY"
}

_orchestrator_context() {
    run bash -c "zsh -c \"set -- help; source '$BORG' >/dev/null 2>&1; _borg_orchestrator_context\" 2>/dev/null"
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; false; }
}

# Hook state for one repository: the status and last_activity live in its per-repository state file.
_seed_state() {
    local dir="${BATS_TEST_TMPDIR}/ws/$1" sf
    sf=$(state_path_of "$dir" "")
    mkdir -p "${sf%/*}"
    printf '{"status":"%s","last_activity":"%s"}' "$2" "$(_iso_days_ago "$3")" > "$sf"
}

_hook_context() {
    run bash "$BORG_START" <<< "$(printf '{"session_id":"s","cwd":"%s"}' "$HOME/dev")"
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; false; }
    HOOK_CTX=$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')
}

# ── Checkpoint excerpts follow recency ──────────────────────────────────────────────────────────────────────────

@test "excerpts: when every repository is idle the three most recently active supply them" {
    _write_registry oldest:idle:170 older:idle:90 mid:idle:20 newer:idle:3 newest:idle:1
    _orchestrator_context
    [[ "$output" == *"=== newest "* ]] || false
    [[ "$output" == *"=== newer "* ]] || false
    [[ "$output" == *"=== mid "* ]] || false
    [[ "$output" != *"MARK_oldest"* ]] || false
    [[ "$output" != *"MARK_older"* ]] || false
    [[ "$output" != *"ppath="* && "$output" != *"cp="* ]] || { echo "loop locals leaked into the prompt"; false; }
}

@test "excerpts: a repository that was never active sorts after every dated one" {
    _write_registry untouched:idle:never a:idle:100 b:idle:50 c:idle:10
    _orchestrator_context
    [[ "$output" != *"MARK_untouched"* ]] || false
    [[ "$output" == *"MARK_a"* ]] || false
}

@test "excerpts: status still outranks recency (a waiting repository comes first)" {
    _write_registry stale-waiting:waiting:120 x:idle:1 y:idle:2 z:idle:3
    export BORG_NO_REAP=1  # the reaper would downgrade a 120-day-old waiting row to idle
    _orchestrator_context
    [[ "$output" == *"MARK_stale-waiting"* ]] || false
    [[ "$output" == *"MARK_x"* ]] || false
    [[ "$output" == *"MARK_y"* ]] || false
    [[ "$output" != *"MARK_z"* ]] || false
}

# ── The roster prints once, from the hook ───────────────────────────────────────────────────────────────────────

@test "roster: the system prompt no longer carries a Repository registry list" {
    _write_registry alpha:idle:1 beta:waiting:2
    _orchestrator_context
    [[ "$output" != *"Repository registry:"* ]] || false
    [[ "$output" != *"  alpha ["* ]] || false
    [[ "$output" != *"  beta ["* ]] || false
    [[ "$output" == *"Current time:"* ]] || false
    [[ "$output" == *"Latest checkpoints:"* ]] || false
}

@test "roster: the hook names each repository exactly once, with its next action" {
    _write_registry alpha:idle:1 beta:idle:2
    _seed_state alpha idle 1
    _seed_state beta idle 2
    _hook_context
    [ "$(printf '%s\n' "$HOOK_CTX" | grep -c '• alpha ')" = "1" ]
    [ "$(printf '%s\n' "$HOOK_CTX" | grep -c '• beta ')" = "1" ]
    [[ "$HOOK_CTX" == *"next: Next step for alpha."* ]] || false
}

# ── Long-idle repositories are counted, not listed ──────────────────────────────────────────────────────────────

_cutoff_registry() {
    _write_registry fresh:idle:5 old:idle:45 ancient-waiting:waiting:90 ancient-active:active:200 never-seen:idle:never
    _seed_state fresh idle 5
    _seed_state old idle 45
    _seed_state ancient-waiting waiting 90
    _seed_state ancient-active active 200
}

@test "idle cutoff: repositories idle past 30 days are hidden and counted on one line" {
    _cutoff_registry
    _hook_context
    [[ "$HOOK_CTX" == *"• fresh "* ]] || false
    [[ "$HOOK_CTX" != *"• old "* ]] || false
    [[ "$HOOK_CTX" != *"• never-seen "* ]] || false
    [[ "$HOOK_CTX" == *"+ 2 idle 30+ days (borg link for all)"* ]] || false
    [[ "$HOOK_CTX" == *"You are the QUEEN (5 repositories)"* ]] || false
}

@test "idle cutoff: waiting and active repositories always show, however old" {
    _cutoff_registry
    _hook_context
    [[ "$HOOK_CTX" == *"• ancient-waiting [waiting]"* ]] || false
    [[ "$HOOK_CTX" == *"• ancient-active [active]"* ]] || false
}

@test "idle cutoff: BORG_QUEEN_IDLE_DAYS overrides the 30-day default" {
    _cutoff_registry
    export BORG_QUEEN_IDLE_DAYS=60
    _hook_context
    [[ "$HOOK_CTX" == *"• old "* ]] || false
    [[ "$HOOK_CTX" == *"+ 1 idle 60+ days (borg link for all)"* ]] || false
}

@test "idle cutoff: a non-numeric BORG_QUEEN_IDLE_DAYS falls back to the default" {
    _cutoff_registry
    export BORG_QUEEN_IDLE_DAYS=soon
    _hook_context
    [[ "$HOOK_CTX" == *"+ 2 idle 30+ days (borg link for all)"* ]] || false
}

@test "idle cutoff: no count line when every repository is inside the window" {
    _write_registry alpha:idle:1 beta:idle:2
    _seed_state alpha idle 1
    _seed_state beta idle 2
    _hook_context
    [[ "$HOOK_CTX" != *"borg link for all"* ]] || false
}
