#!/usr/bin/env bats
# AC4 A2b-1: every operational WRITER under the old config dir now writes the machine-local state
# root (${XDG_STATE_HOME:-$HOME/.local/state}/borg). Two shapes are pinned here:
#   * pure writers (logs): the file lands in the state root and NOT in the config dir.
#   * read+write files: an old-location file is READ, then the state root is WRITTEN, old untouched.
# The sandbox redirects HOME, XDG_CONFIG_HOME and XDG_STATE_HOME (tests/test_helper/setup.bash), so a
# write that still targets the config dir is visible as a file under $OLD, never on the real machine.
# Cases for usage-watch, memory-gate, pr-watch and cortex-resume live beside their suites.

load test_helper/setup

HOOKS="${BATS_TEST_DIRNAME}/../hooks"
BIN="${BATS_TEST_DIRNAME}/../bin"

setup() {
    setup_temp_dirs
    OLD="$BORG_DIR"
    NEW="$XDG_STATE_HOME/borg"
    mkdir -p "$OLD"
}

@test "plan-promote: the debug log lands in the state root, not the config dir" {
    local repo="${BATS_TEST_TMPDIR}/repo"
    mkdir -p "$repo"
    git -C "$repo" init --quiet
    jq -n --arg c "$repo" --arg f "$repo/x.txt" \
        '{tool_name:"Write", session_id:"s1", cwd:$c, tool_input:{file_path:$f}}' > "${BATS_TEST_TMPDIR}/p.json"
    run bash -c "cd '$repo' && bash '$HOOKS/borg-plan-promote.sh' < '${BATS_TEST_TMPDIR}/p.json'"
    [ "$status" -eq 0 ]
    [ -f "$NEW/plan-promote-debug.log" ]
    grep -q 'JSONL not found' "$NEW/plan-promote-debug.log"
    [ ! -e "$OLD/plan-promote-debug.log" ]
}

@test "memory-read-log: the first write carries a pre-move history across, then appends in the state root" {
    printf 't1\ts0\tp\tA.md\t1\nt2\ts0\tp\tB.md\t1\n' > "$OLD/memory-hits.log"
    local mem="$HOME/.claude/projects/-Users-noah-dev-x/memory"
    mkdir -p "$mem" && printf c > "$mem/MEMORY.md"
    jq -n --arg f "$mem/MEMORY.md" '{session_id:"s9", tool_input:{file_path:$f}}' > "${BATS_TEST_TMPDIR}/p.json"
    run bash -c "bash '$HOOKS/borg-memory-read-log.sh' < '${BATS_TEST_TMPDIR}/p.json'"
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$NEW/memory-hits.log" | tr -d ' ')" = "3" ]
    [ "$(head -1 "$NEW/memory-hits.log" | cut -f1)" = "t1" ]
    [ "$(wc -l < "$OLD/memory-hits.log" | tr -d ' ')" = "2" ]
}

@test "nanoprobe-log: the first write carries a pre-move history across, then appends in the state root" {
    printf '{"id":"old-run"}\n' > "$OLD/agents.jsonl"
    run bash -c "printf '%s' '{\"agent_id\":\"new-run\",\"agent_type\":\"x\",\"last_assistant_message\":\"m\",\"cwd\":\"/tmp\"}' | bash '$HOOKS/borg-nanoprobe-log.sh'"
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$NEW/agents.jsonl" | tr -d ' ')" = "2" ]
    [ "$(head -1 "$NEW/agents.jsonl")" = '{"id":"old-run"}' ]
    [ "$(wc -l < "$OLD/agents.jsonl" | tr -d ' ')" = "1" ]
}

@test "prefer-tool-log: the bypass log lands in the state root, not the config dir" {
    local d="$OLD/extensions/skill-extensions/borg-assimilate"
    mkdir -p "$d"
    printf -- '- Prefer-tool: `dev-workflow:create-pr`\n- Instead-of: `gh pr create`\n- Requires: command:sh\n' > "$d/02-output.md"
    run bash -c "printf '{\"tool_input\":{\"command\":\"gh pr create\"},\"cwd\":\"$BATS_TEST_TMPDIR\"}' | '$HOOKS/borg-prefer-tool-log.sh'"
    [ "$status" -eq 0 ]
    [ -f "$NEW/prefer-tool.jsonl" ]
    [ ! -e "$OLD/prefer-tool.jsonl" ]
}

# ── bin/borg-cortex-watch: read AND written ─────────────────────────────────────────────────────

_cortex_mocks() {
    # setup_temp_dirs does NOT redirect XDG_DATA_HOME, and the agent logs to ${XDG_DATA_HOME:-...}/borg:
    # unredirected, this suite appends to the developer's REAL cortex-wake.log. Sandbox it.
    export XDG_DATA_HOME="${BATS_TEST_TMPDIR}/data"
    local mb="${BATS_TEST_TMPDIR}/mockbin"
    mkdir -p "$mb"
    printf '#!/bin/sh\ncase "$1" in list-sessions) exit 0 ;; list-panes) [ "$2" = "-a" ] && exit 0; exit 1 ;; esac\nexit 0\n' > "$mb/tmux"
    printf '#!/bin/sh\nexit 0\n' > "$mb/osascript"
    chmod +x "$mb/tmux" "$mb/osascript"
    export PATH="$mb:$PATH"
    # The agent re-exports PATH with the real system dirs FIRST (launchd self-heal), which would put a
    # REAL tmux ahead of the mock -- on a dev machine that is the live server, with live panes. Run a
    # copy minus that one line so the mocks win; every other line is the script under test.
    CORTEX_WATCH="${BATS_TEST_TMPDIR}/borg-cortex-watch"
    sed '/^export PATH=/d' "$BIN/borg-cortex-watch" > "$CORTEX_WATCH"
}

@test "cortex-watch: reads an old-location wakes file, then writes the pruned copy to the state root" {
    _cortex_mocks
    printf '%s' '{"wakes":[{"pane_id":"%9","session":"s","window":"w","pane_index":"0","project":"gone","reset_at":"2999-01-01T00:00:00Z"}]}' \
        > "$OLD/cortex-wakes.json"
    run bash "$CORTEX_WATCH" --once
    [ "$status" -eq 0 ] || { echo "$output" >&2; false; }
    [ -f "$NEW/cortex-wakes.json" ]
    [ "$(jq '.wakes | length' "$NEW/cortex-wakes.json")" = "0" ]
    [ "$(jq '.wakes | length' "$OLD/cortex-wakes.json")" = "1" ]
    # The orphan can only have been dropped if the OLD file's entry was actually read.
    grep -q "orphan: pane=%9" "${XDG_DATA_HOME:-$HOME/.local/share}/borg/cortex-wake.log"
}

@test "cortex-watch: a fresh machine initialises the state root, not the config dir" {
    _cortex_mocks
    run bash "$CORTEX_WATCH" --once
    [ "$status" -eq 0 ] || { echo "$output" >&2; false; }
    [ -f "$NEW/cortex-wakes.json" ]
    [ ! -e "$OLD/cortex-wakes.json" ]
}

# ── pure-Python writers ──────────────────────────────────────────────────────────────────────────

@test "pr-watch snapshot: save_snapshot writes the state root, load_snapshot reads the old copy first" {
    printf '{"prs":[{"number":7}]}' > "$OLD/pr-watch-snapshot.json"
    run env PYTHONPATH="${BATS_TEST_DIRNAME}/.." python3 -c '
from borg_core.watch import shell
assert shell.load_snapshot() == {"prs": [{"number": 7}]}
shell.save_snapshot({"prs": []})
assert shell.load_snapshot() == {"prs": []}
'
    [ "$status" -eq 0 ]
    [ "$(cat "$NEW/pr-watch-snapshot.json" | jq -c .)" = '{"prs":[]}' ]
    [ "$(jq -c . "$OLD/pr-watch-snapshot.json")" = '{"prs":[{"number":7}]}' ]
}

@test "recon: the last-run mark is written to the state root, and an old-location mark is still read" {
    mkdir -p "$OLD/recon" && printf '2020-01-01T00:00:00Z\n' > "$OLD/recon/last-run"
    run env PYTHONPATH="${BATS_TEST_DIRNAME}/.." python3 -c '
from borg_core.recon import shell
assert shell.read_last_run_marker() == "2020-01-01T00:00:00Z"
shell.write_last_run_marker("2030-01-01T00:00:00Z")
assert shell.read_last_run_marker() == "2030-01-01T00:00:00Z"
'
    [ "$status" -eq 0 ]
    [ "$(cat "$NEW/recon/last-run")" = "2030-01-01T00:00:00Z" ]
    [ "$(cat "$OLD/recon/last-run")" = "2020-01-01T00:00:00Z" ]
}
