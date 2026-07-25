#!/usr/bin/env bats
# Tests for hooks/borg-supabase-guard.sh — the shared-Supabase-stack hard-stop (PreToolUse Bash).
#
# Contract: there is ONE shared local Supabase stack, owned by the stillpoint repo. This hook
# DENIES (exit 2, reason on stderr) any `supabase start|stop|db reset` whose effective target
# directory is not the shared stillpoint dir, and any docker stop/kill/rm or --filter name=
# invocation that force-stops the shared `supabase_*_stillpoint` containers. Everything else —
# the same commands run FROM the stillpoint dir, Cloud-targeted supabase subcommands (db push,
# migration, link), and unrelated commands — is ALLOWED (exit 0).

load test_helper/setup

HOOK="${BATS_TEST_DIRNAME}/../hooks/borg-supabase-guard.sh"

setup() {
    setup_temp_dirs
    export BORG_STILLPOINT_SUPABASE_DIR="/Users/noah/dev/stillpoint"
}

# Feed a Bash tool-input JSON (command + cwd) to the guard.
_run_guard() {
    local cmd="$1" cwd="${2:-/Users/noah/dev/ingle}"
    local payload_file="${BATS_TEST_TMPDIR}/payload.json"
    jq -n --arg c "$cmd" --arg d "$cwd" '{tool_input:{command:$c}, cwd:$d}' > "$payload_file"
    run bash -c "bash '$HOOK' < '$payload_file'"
}

_assert_blocked() {
    [ "$status" -eq 2 ]
    [[ "$output" == *"stillpoint Supabase stack"* ]]
}

_assert_allowed() {
    [ "$status" -eq 0 ]
}

# ─── BLOCK: supabase start/stop/db reset outside the shared dir ─────────────

@test "blocks: supabase start with cwd=non-stillpoint project" {
    _run_guard "supabase start" "/Users/noah/dev/ingle"
    _assert_blocked
}

@test "blocks: supabase --workdir <non-stillpoint> start" {
    _run_guard "supabase --workdir /Users/noah/dev/ingle start" "/Users/noah/dev/ingle"
    _assert_blocked
}

@test "blocks: supabase --workdir=<non-stillpoint> start (equals form)" {
    _run_guard "supabase --workdir=/Users/noah/dev/ingle start" "/Users/noah/dev/ingle"
    _assert_blocked
}

@test "blocks: supabase db reset from a non-stillpoint dir" {
    _run_guard "supabase db reset" "/Users/noah/dev/troth"
    _assert_blocked
}

@test "blocks: supabase stop from a non-stillpoint dir" {
    _run_guard "supabase stop" "/Users/noah/dev/troth"
    _assert_blocked
}

@test "blocks: leading cd into a non-stillpoint dir then supabase start" {
    _run_guard "cd /Users/noah/dev/ingle && supabase start" "/Users/noah/dev"
    _assert_blocked
}

@test "blocks: chained command with supabase start as a later segment" {
    _run_guard "npm install; supabase start" "/Users/noah/dev/ingle"
    _assert_blocked
}

# ─── BLOCK: force-stopping the shared stack by name/filter ──────────────────

@test "blocks: docker ps --filter name=stillpoint piped into xargs docker stop" {
    _run_guard "docker ps --filter name=stillpoint -q | xargs -r docker stop"
    _assert_blocked
}

@test "blocks: docker stop targeting a supabase_*_stillpoint container directly" {
    _run_guard "docker stop supabase_db_stillpoint"
    _assert_blocked
}

@test "blocks: docker kill targeting a supabase_*_stillpoint container directly" {
    _run_guard "docker kill supabase_studio_stillpoint"
    _assert_blocked
}

# ─── ALLOW: same commands run from the stillpoint dir ────────────────────────

@test "allows: supabase start with cwd=stillpoint (the owning repo)" {
    _run_guard "supabase start" "/Users/noah/dev/stillpoint"
    _assert_allowed
}

@test "allows: supabase db reset with cwd=stillpoint" {
    _run_guard "supabase db reset" "/Users/noah/dev/stillpoint"
    _assert_allowed
}

@test "allows: supabase --workdir <stillpoint> start" {
    _run_guard "supabase --workdir /Users/noah/dev/stillpoint start" "/Users/noah/dev/ingle"
    _assert_allowed
}

@test "allows: supabase start when cwd matches a custom BORG_STILLPOINT_SUPABASE_DIR" {
    export BORG_STILLPOINT_SUPABASE_DIR="/Users/noah/custom/stillpoint-fork"
    _run_guard "supabase start" "/Users/noah/custom/stillpoint-fork"
    _assert_allowed
}

# ─── ALLOW: Cloud-targeted / non-local-boot supabase subcommands ─────────────

@test "allows: supabase db push from a non-stillpoint dir" {
    _run_guard "supabase db push" "/Users/noah/dev/ingle"
    _assert_allowed
}

@test "allows: supabase migration list from a non-stillpoint dir" {
    _run_guard "supabase migration list" "/Users/noah/dev/ingle"
    _assert_allowed
}

@test "allows: supabase migration up from a non-stillpoint dir" {
    _run_guard "supabase migration up" "/Users/noah/dev/ingle"
    _assert_allowed
}

@test "allows: supabase link from a non-stillpoint dir" {
    _run_guard "supabase link --project-ref abc123" "/Users/noah/dev/ingle"
    _assert_allowed
}

# ─── ALLOW: unrelated commands ────────────────────────────────────────────────

@test "allows: unrelated command (npm test)" {
    _run_guard "npm test" "/Users/noah/dev/ingle"
    _assert_allowed
}

@test "allows: docker stop of an unrelated container" {
    _run_guard "docker stop some_other_container" "/Users/noah/dev/ingle"
    _assert_allowed
}

@test "allows: empty stdin (fail open)" {
    run bash -c "printf '' | bash '$HOOK'"
    [ "$status" -eq 0 ]
}
