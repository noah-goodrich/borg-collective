#!/usr/bin/env bats
# macOS /bin/bash 3.2 treats a failed `source` as fatal under `set -e` even inside `{ ...; } || true`.
# That abort applied to borg-nanoprobe-log.sh, the only one of the three log hooks with `set -e`; the other two
# (memory-read-log, prefer-tool-log) lack -e, so the subshell there is hardening. When reaper.sh is missing the
# rotation is skipped for that call, but the row is still appended.
# The abort only reproduces on bash 3.x, so those cases skip elsewhere; the rotation-at-cap case runs everywhere.

load test_helper/setup

REPO_ROOT="${BATS_TEST_DIRNAME}/.."

setup() {
    setup_temp_dirs
    [ -x /bin/bash ] || skip "no /bin/bash"
    export BORG_DIR="${BATS_TEST_TMPDIR}/borg"
    mkdir -p "$HOME/.claude"
    # setup_temp_dirs pre-populates ~/.claude/lib; _prepare_lib resets it per case
}

_require_bash3() {
    case "$(/bin/bash -c 'echo $BASH_VERSION')" in
        3.*) ;;
        *) skip "the abort only reproduces on macOS bash 3.2; /bin/bash here is not 3.x, so green is not coverage" ;;
    esac
}

# <mode> where mode is nolib or noreaper
_prepare_lib() {
    rm -f "$BORG_TEST_HOME"/.claude/lib/*
    rmdir "$BORG_TEST_HOME/.claude/lib"
    if [ "$1" = noreaper ]; then
        mkdir -p "$HOME/.claude/lib"
        cp "$REPO_ROOT/lib/borg-hooks.sh" "$HOME/.claude/lib/borg-hooks.sh"
    fi
}

_run_nanoprobe() {
    run /bin/bash -c "printf '%s' '{\"agent_id\":\"a1\",\"agent_type\":\"borg-nanoprobe\",\"last_assistant_message\":\"done\",\"cwd\":\"$BATS_TEST_TMPDIR\"}' | /bin/bash '$REPO_ROOT/hooks/borg-nanoprobe-log.sh'"
}

_run_memory() {
    local d="$HOME/.claude/projects/-proj/memory"
    mkdir -p "$d"
    printf 'x' > "$d/m.md"
    run /bin/bash -c "printf '%s' '{\"session_id\":\"s1\",\"tool_input\":{\"file_path\":\"$d/m.md\"}}' | /bin/bash '$REPO_ROOT/hooks/borg-memory-read-log.sh'"
}

_run_prefer() {
    local d="$BORG_DIR/extensions/skill-extensions/borg-assimilate"
    mkdir -p "$d" "$BATS_TEST_TMPDIR/repo"
    git -C "$BATS_TEST_TMPDIR/repo" init --quiet
    printf -- '- Prefer-tool: `dev-workflow:create-pr`\n- Instead-of: `gh pr create`\n- Requires: command:sh\n\nDelegate.\n' > "$d/02-output.md"
    run /bin/bash -c "printf '%s' '{\"tool_input\":{\"command\":\"gh pr create --title x\"},\"cwd\":\"$BATS_TEST_TMPDIR/repo\"}' | /bin/bash '$REPO_ROOT/hooks/borg-prefer-tool-log.sh'"
}

@test "nanoprobe-log under /bin/bash: no ~/.claude/lib still appends the row" {
    _require_bash3
    _prepare_lib nolib
    _run_nanoprobe
    [ "$status" -eq 0 ]
    grep -q '"a1"' "$XDG_STATE_HOME/borg/agents.jsonl"
}

@test "nanoprobe-log under /bin/bash: reaper.sh missing still appends the row" {
    _require_bash3
    _prepare_lib noreaper
    _run_nanoprobe
    [ "$status" -eq 0 ]
    grep -q '"a1"' "$XDG_STATE_HOME/borg/agents.jsonl"
}

@test "memory-read-log under /bin/bash: no ~/.claude/lib still logs the hit" {
    _require_bash3
    _prepare_lib nolib
    _run_memory
    [ "$status" -eq 0 ]
    grep -q 's1' "$XDG_STATE_HOME/borg/memory-hits.log"
}

@test "memory-read-log under /bin/bash: reaper.sh missing still logs the hit" {
    _require_bash3
    _prepare_lib noreaper
    _run_memory
    [ "$status" -eq 0 ]
    grep -q 's1' "$XDG_STATE_HOME/borg/memory-hits.log"
}

@test "prefer-tool-log under /bin/bash: no ~/.claude/lib still logs the bypass" {
    _require_bash3
    _prepare_lib nolib
    _run_prefer
    [ "$status" -eq 0 ]
    grep -q '"event":"bypass"' "$XDG_STATE_HOME/borg/prefer-tool.jsonl"
}

@test "prefer-tool-log under /bin/bash: reaper.sh missing still logs the bypass" {
    _require_bash3
    _prepare_lib noreaper
    _run_prefer
    [ "$status" -eq 0 ]
    grep -q '"event":"bypass"' "$XDG_STATE_HOME/borg/prefer-tool.jsonl"
}

@test "nanoprobe-log under /bin/bash: full lib at the cap still rotates inside the subshell" {
    mkdir -p "$XDG_STATE_HOME/borg"
    printf "{\"id\":\"old\"}\n" > "$XDG_STATE_HOME/borg/agents.jsonl"
    export BORG_LOG_CAP_BYTES=1
    _run_nanoprobe
    [ "$status" -eq 0 ]
    [ -f "$XDG_STATE_HOME/borg/agents.jsonl.1" ]
    grep -q "old" "$XDG_STATE_HOME/borg/agents.jsonl.1"
    grep -q "a1" "$XDG_STATE_HOME/borg/agents.jsonl"
}
