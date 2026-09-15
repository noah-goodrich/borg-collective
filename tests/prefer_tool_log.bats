#!/usr/bin/env bats
# Oracles for hooks/borg-prefer-tool-log.sh -- the prefer-tool bypass log.

load test_helper/setup

HOOK="${BATS_TEST_DIRNAME}/../hooks/borg-prefer-tool-log.sh"

setup() {
    setup_temp_dirs
    export BORG_DIR="${BATS_TEST_TMPDIR}/borg"
    REPO="${BATS_TEST_TMPDIR}/repo"
    mkdir -p "$REPO"
    git -C "$REPO" init --quiet
    LOG="$BORG_DIR/prefer-tool.jsonl"
    cd "${BATS_TEST_DIRNAME}/.." || return 1
}

_write_pref() {   # <requires-value>
    local d="$BORG_DIR/extensions/skill-extensions/borg-assimilate"
    mkdir -p "$d"
    printf -- '- Prefer-tool: `dev-workflow:create-pr`\n- Instead-of: `gh pr create`\n- Requires: command:%s\n\nDelegate.\n' "$1" > "$d/02-output.md"
}

@test "prefer-tool: a live preference bypassed by a matching command is logged" {
    _write_pref sh
    run bash -c "printf '{\"tool_input\":{\"command\":\"gh pr create --title x\"},\"cwd\":\"$REPO\"}' | '$HOOK'"
    [ "$status" -eq 0 ]
    [ -f "$LOG" ]
    grep -q '"event":"bypass"' "$LOG"
    grep -q 'dev-workflow:create-pr' "$LOG"
}

@test "prefer-tool: a DEAD preference logs nothing (it is not in force)" {
    # Discriminates against the live case above: same command, same file, only the requirement
    # differs. A dead preference cannot be bypassed because it is not asking for anything.
    _write_pref definitely-not-a-real-binary-xyz
    run bash -c "printf '{\"tool_input\":{\"command\":\"gh pr create --title x\"},\"cwd\":\"$REPO\"}' | '$HOOK'"
    [ "$status" -eq 0 ]
    [ ! -f "$LOG" ]
}

@test "prefer-tool: an unrelated command logs nothing" {
    _write_pref sh
    run bash -c "printf '{\"tool_input\":{\"command\":\"ls -la\"},\"cwd\":\"$REPO\"}' | '$HOOK'"
    [ "$status" -eq 0 ]
    [ ! -f "$LOG" ]
}

@test "prefer-tool: no preference at all logs nothing and still exits 0" {
    run bash -c "printf '{\"tool_input\":{\"command\":\"gh pr create\"},\"cwd\":\"$REPO\"}' | '$HOOK'"
    [ "$status" -eq 0 ]
    [ ! -f "$LOG" ]
}

@test "prefer-tool: the hook never blocks, on any malformed input" {
    for p in '' 'not json' '{}' '{"tool_input":{}}'; do
        run bash -c "printf '%s' '$p' | '$HOOK'"
        [ "$status" -eq 0 ] || { echo "blocked on: [$p]"; false; }
    done
}

@test "prefer-tool: a missing BORG_DIR does not leak a redirect error into stderr" {
    # The `cmd >> file 2>/dev/null` hazard from CLAUDE.md: bash opens redirect targets before the
    # command runs, so a missing directory prints to the REAL stderr no matter where 2>/dev/null
    # sits. A consumer merging stderr into stdout splices that line ahead of the JSON.
    export BORG_DIR="${BATS_TEST_TMPDIR}/absent-tree/borg"
    _write_pref sh
    run bash -c "printf '{\"tool_input\":{\"command\":\"gh pr create\"},\"cwd\":\"$REPO\"}' | '$HOOK' 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" != *"No such file or directory"* ]] || { echo "leaked: $output"; false; }
}
