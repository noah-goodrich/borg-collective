#!/usr/bin/env bats
# AC4 part C: log retention. One helper (lib/borg-hooks.sh::_borg_rotate_log) caps an append-only log
# at BORG_LOG_CAP_BYTES (default 1 MiB), keeping ONE previous generation as <file>.1. Readers that
# need history read .1 then the live file. The sandbox redirects HOME and every XDG dir
# (tests/test_helper/setup.bash), so nothing here can touch the real machine.

load test_helper/setup

LIB="${BATS_TEST_DIRNAME}/../lib/borg-hooks.sh"
HOOKS="${BATS_TEST_DIRNAME}/../hooks"
BIN="${BATS_TEST_DIRNAME}/../bin"

setup() {
    setup_temp_dirs
    NEW="$XDG_STATE_HOME/borg"
    mkdir -p "$NEW" "$HOME/.claude/lib"
    cp "$LIB" "$HOME/.claude/lib/borg-hooks.sh"
    cp "${BATS_TEST_DIRNAME}/../lib/reaper.sh" "$HOME/.claude/lib/reaper.sh"
}

_fill() { head -c "$2" /dev/zero | tr '\0' 'a' > "$1"; }

_rot() { bash -c "source '$LIB'; _borg_rotate_log \"\$@\"" _ "$@"; }

@test "rotate: under the cap leaves the file alone" {
    _fill "$NEW/x.log" 99
    run _rot "$NEW/x.log" 100
    [ "$status" -eq 0 ] && [ -z "$output" ]
    [ "$(wc -c < "$NEW/x.log" | tr -d ' ')" -eq 99 ]
    [ ! -e "$NEW/x.log.1" ]
}

@test "rotate: exactly at the cap rotates" {
    _fill "$NEW/x.log" 100
    run _rot "$NEW/x.log" 100
    [ "$status" -eq 0 ]
    [ ! -e "$NEW/x.log" ]
    [ "$(wc -c < "$NEW/x.log.1" | tr -d ' ')" -eq 100 ]
}

@test "rotate: over the cap rotates and replaces the previous generation, keeping only one" {
    _fill "$NEW/x.log" 150
    echo old > "$NEW/x.log.1"
    run _rot "$NEW/x.log" 100
    [ "$status" -eq 0 ]
    [ "$(wc -c < "$NEW/x.log.1" | tr -d ' ')" -eq 150 ]
    [ ! -e "$NEW/x.log.2" ]
}

@test "rotate: the default cap is 1 MiB (BORG_LOG_CAP_BYTES unset)" {
    unset BORG_LOG_CAP_BYTES
    _fill "$NEW/a.log" 1048575
    _fill "$NEW/b.log" 1048576
    _rot "$NEW/a.log"
    _rot "$NEW/b.log"
    [ -e "$NEW/a.log" ] && [ ! -e "$NEW/a.log.1" ]
    [ ! -e "$NEW/b.log" ] && [ -e "$NEW/b.log.1" ]
}

@test "rotate: BORG_LOG_CAP_BYTES overrides, and a garbage cap falls back to the default" {
    _fill "$NEW/x.log" 60
    BORG_LOG_CAP_BYTES=50 _rot "$NEW/x.log"
    [ -e "$NEW/x.log.1" ]
    _fill "$NEW/y.log" 60
    BORG_LOG_CAP_BYTES=banana _rot "$NEW/y.log"
    [ -e "$NEW/y.log" ] && [ ! -e "$NEW/y.log.1" ]
}

@test "rotate: fail-open -- absent file, empty arg, unwritable dir are silent and return 0" {
    run _rot "$NEW/missing.log" 1
    [ "$status" -eq 0 ] && [ -z "$output" ]
    run _rot "" 1
    [ "$status" -eq 0 ] && [ -z "$output" ]
    _fill "$NEW/x.log" 50
    chmod 555 "$NEW"
    run _rot "$NEW/x.log" 10
    chmod 755 "$NEW"
    [ "$status" -eq 0 ] && [ -z "$output" ]
    [ -e "$NEW/x.log" ]
}

@test "rotate: a symlinked log is never renamed" {
    _fill "$NEW/real.log" 50
    ln -s "$NEW/real.log" "$NEW/link.log"
    _rot "$NEW/link.log" 10
    [ -L "$NEW/link.log" ] && [ -e "$NEW/real.log" ] && [ ! -e "$NEW/link.log.1" ]
}

# ─── a real writer rotates ────────────────────────────────────────────────────

_memory_payload() {
    local mem="$HOME/.claude/projects/-Users-noah-dev-x/memory"
    mkdir -p "$mem" && printf c > "$mem/MEMORY.md"
    jq -n --arg f "$mem/MEMORY.md" '{session_id:"s9", tool_input:{file_path:$f}}' > "${BATS_TEST_TMPDIR}/p.json"
}

@test "memory-read-log: at the cap the old log becomes .1 and the live file holds only the new row" {
    _memory_payload
    printf 'old1\told\n' > "$NEW/memory-hits.log"
    run env BORG_LOG_CAP_BYTES=5 bash "$HOOKS/borg-memory-read-log.sh" < "${BATS_TEST_TMPDIR}/p.json"
    [ "$status" -eq 0 ] && [ -z "$output" ]
    [ "$(cat "$NEW/memory-hits.log.1")" = "$(printf 'old1\told')" ]
    [ "$(wc -l < "$NEW/memory-hits.log" | tr -d ' ')" -eq 1 ]
    grep -q 's9' "$NEW/memory-hits.log"
}

@test "memory-read-log: under the cap appends in place, no .1" {
    _memory_payload
    printf 'old1\told\n' > "$NEW/memory-hits.log"
    run bash "$HOOKS/borg-memory-read-log.sh" < "${BATS_TEST_TMPDIR}/p.json"
    [ "$(wc -l < "$NEW/memory-hits.log" | tr -d ' ')" -eq 2 ]
    [ ! -e "$NEW/memory-hits.log.1" ]
}

@test "memory-read-log: with the lib absent the write still lands (rotation is fail-open)" {
    _memory_payload
    rm -f "$HOME/.claude/lib/borg-hooks.sh"
    printf 'old1\told\n' > "$NEW/memory-hits.log"
    run env BORG_LOG_CAP_BYTES=5 bash "$HOOKS/borg-memory-read-log.sh" < "${BATS_TEST_TMPDIR}/p.json"
    [ "$status" -eq 0 ] && [ -z "$output" ]
    [ "$(wc -l < "$NEW/memory-hits.log" | tr -d ' ')" -eq 2 ]
    [ ! -e "$NEW/memory-hits.log.1" ]
}

@test "nanoprobe-log: rotates agents.jsonl at the cap and the new record is in the live file" {
    printf '{"id":"oldrun","agent_type":"x","finished_at":"2026-01-01T00:00:00Z"}\n' > "$NEW/agents.jsonl"
    run env BORG_LOG_CAP_BYTES=5 bash "$HOOKS/borg-nanoprobe-log.sh" \
        <<< '{"agent_id":"newrun","agent_type":"borg-nanoprobe","last_assistant_message":"hi","cwd":"/tmp"}'
    [ "$status" -eq 0 ]
    grep -q oldrun "$NEW/agents.jsonl.1"
    [ "$(wc -l < "$NEW/agents.jsonl" | tr -d ' ')" -eq 1 ]
    grep -q newrun "$NEW/agents.jsonl"
}

# ─── readers span .1 then the live file ───────────────────────────────────────

@test "memory-hits-report counts reads across .1 and the live file" {
    mkdir -p "$HOME/.claude/projects/-Users-noah-dev-cairn"
    printf '{}' > "$HOME/.claude/projects/-Users-noah-dev-cairn/s.jsonl"
    local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '%s\ta\tp1\tM.md\t1\n%s\tb\tp1\tM.md\t1\n' "$ts" "$ts" > "$NEW/memory-hits.log.1"
    printf '%s\tc\tp2\tM.md\t1\n' "$ts" > "$NEW/memory-hits.log"
    run bash "$BIN/memory-hits-report"
    [ "$status" -eq 0 ]
    [[ "$output" == *"reads:    3"* ]]
    [[ "$output" == *"p1"*"2"* ]]
}

@test "borg nanoprobes lists the live file first, then the rotated generation; nanoprobe-log finds a rotated id" {
    printf '{"id":"aaaaaaaa-old","agent_type":"t","summary":"rotated run","finished_at":"2026-01-01"}\n' \
        > "$NEW/agents.jsonl.1"
    printf '{"id":"bbbbbbbb-new","agent_type":"t","summary":"live run","finished_at":"2026-02-01"}\n' \
        > "$NEW/agents.jsonl"
    run zsh "${BATS_TEST_DIRNAME}/../borg.zsh" nanoprobes
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == *"bbbbbbbb"* ]]
    [[ "${lines[1]}" == *"aaaaaaaa"* ]]
    run zsh "${BATS_TEST_DIRNAME}/../borg.zsh" nanoprobe-log aaaaaaaa
    [ "$status" -eq 0 ]
    [[ "$output" == *"rotated run"* ]]
}

@test "usage-watch: a full samples file rotates and the new row lands in a fresh live file" {
    local mock="${BATS_TEST_TMPDIR}/claude-mock"
    printf '#!/usr/bin/env bash\necho "Current session: 10%% used · resets 5pm (America/Denver)"\necho "Current week (all models): 40%% used · resets Jul 30 at 7am (America/Denver)"\n' > "$mock"
    chmod +x "$mock"
    export BORG_USAGE_CLAUDE_BIN="$mock" BORG_USAGE_PANE_CMD="echo claude" BORG_USAGE_NOW_EPOCH=1700000000
    export BORG_USAGE_SAMPLES="$NEW/usage-samples.jsonl" BORG_USAGE_LOG="$NEW/usage-watch.log"
    export BORG_USAGE_GUARDIAN_STATE="$NEW/usage-guardian.json"
    printf '{"ts":"2020-01-01T00:00:00Z","status":"ok"}\n' > "$BORG_USAGE_SAMPLES"
    run env BORG_LOG_CAP_BYTES=10 "$BIN/borg-usage-watch" --once
    [ "$status" -eq 0 ]
    grep -q '2020-01-01' "$BORG_USAGE_SAMPLES.1"
    [ "$(wc -l < "$BORG_USAGE_SAMPLES" | tr -d ' ')" -eq 1 ]
    ! grep -q '2020-01-01' "$BORG_USAGE_SAMPLES"
}

@test "plan-promote: its debug log rotates at the cap instead of growing without bound" {
    local repo="${BATS_TEST_TMPDIR}/repo"
    mkdir -p "$repo"
    git -C "$repo" init --quiet
    jq -n --arg c "$repo" --arg f "$repo/x.txt" \
        '{tool_name:"Write", session_id:"s1", cwd:$c, tool_input:{file_path:$f}}' > "${BATS_TEST_TMPDIR}/p.json"
    printf 'stale debug line\n' > "$NEW/plan-promote-debug.log"
    run bash -c "cd '$repo' && BORG_LOG_CAP_BYTES=5 bash '$HOOKS/borg-plan-promote.sh' < '${BATS_TEST_TMPDIR}/p.json'"
    [ "$status" -eq 0 ]
    grep -q 'stale debug line' "$NEW/plan-promote-debug.log.1"
    ! grep -q 'stale debug line' "$NEW/plan-promote-debug.log"
    grep -q 'borg-plan-promote' "$NEW/plan-promote-debug.log"
}
