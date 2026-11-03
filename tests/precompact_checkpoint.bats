#!/usr/bin/env bats
# #503 Tier 1: hooks/borg-precompact-checkpoint.sh (PreCompact) writes a minimal checkpoint, and an EXISTING
# checkpoint's `Waits on you:` rows still reach `borg next` afterwards. The newest checkpoint is read whole, so the
# automatic file carries the previous Blockers and Next Session forward; the last case is the regression guard.

load test_helper/setup

HOOK="${BATS_TEST_DIRNAME}/../hooks/borg-precompact-checkpoint.sh"
BORG="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs
    export BORG_CHECKPOINT_PREPARE_NOW="2026-11-02T10:00:00"
    REPO="${BATS_TEST_TMPDIR}/fixture"
    git init -q -b feat/x "$REPO"
    printf 'dirty\n' > "$REPO/dirty.txt"
    STORE="$REPO/.borg/checkpoints"
    TRANSCRIPT="${BATS_TEST_TMPDIR}/t.jsonl"
    {
        printf '%s\n' '{"type":"user","message":{"role":"user","content":"first ask"}}'
        printf '%s\n' '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"ok"}]}}'
        printf '%s\n' '{"type":"user","message":{"role":"user","content":"please finish the parser"}}'
        printf '%s\n' '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"x"}]}}'
    } > "$TRANSCRIPT"
}

_payload() {
    jq -nc --arg cwd "$1" --arg t "$TRANSCRIPT" \
        '{hook_event_name:"PreCompact",session_id:"3b0f70ca-1111",cwd:$cwd,transcript_path:$t,trigger:"auto"}'
}

_fire() {
    run bash -c "printf '%s' '$(_payload "$1")' | '$HOOK'"
}

_link_up_checkpoint() {
    mkdir -p "$STORE"
    cat > "$STORE/2026-10-30-120000-abcdef.md" <<'MD'
**tl;dr** — Shipped the chooser. Next: wire the rows.

## 1. Goal
Ship the chooser.

## 2. Accomplished
- Did things.

## 3. Ready to Commit
Nothing.

## 4. Blockers
No blockers.

Waits on you:
- Approve the invented budget in the tracker.

## 5. Next Session
1. Wire the chooser rows into the board.

## Manifest Row
**No row.**
MD
}

@test "precompact: writes a checkpoint with branch, git status and the last user message" {
    mkdir -p "$STORE"
    _fire "$REPO"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    local file="$STORE/2026-11-02-100000-3b0f70.md"
    [ -f "$file" ]
    run cat "$file"
    for heading in "## 1. Goal" "## 2. Accomplished" "## 3. Ready to Commit" "## 4. Blockers" "## 5. Next Session"; do
        [[ "$output" == *"$heading"* ]]
    done
    [[ "$output" == *"Branch: feat/x"* ]]
    [[ "$output" == *"?? dirty.txt"* ]]
    [[ "$output" == *"> please finish the parser"* ]]
    [[ "$output" == *"borg:auto-checkpoint"* ]]
}

@test "precompact: the filename follows the link-up convention (second resolution plus session tag)" {
    mkdir -p "$STORE"
    _fire "$REPO"
    run ls "$STORE"
    [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}-3b0f70\.md$ ]]
}

@test "precompact: out of scope (no .borg, no marker, not the Queen) writes nothing" {
    _fire "$REPO"
    [ "$status" -eq 0 ]
    [ ! -e "$REPO/.borg" ]
}

@test "precompact: fails open and silent on garbage, a missing cwd and no stdin" {
    run bash -c "printf 'not json' | '$HOOK'"
    [ "$status" -eq 0 ] && [ -z "$output" ]
    run bash -c "printf '{\"cwd\":\"/no/such/dir\"}' | '$HOOK'"
    [ "$status" -eq 0 ] && [ -z "$output" ]
    run bash -c "'$HOOK' < /dev/null"
    [ "$status" -eq 0 ] && [ -z "$output" ]
}

@test "precompact: BORG_NO_SESSION_HOOKS=1 writes nothing" {
    mkdir -p "$STORE"
    BORG_NO_SESSION_HOOKS=1 run bash -c "printf '%s' '$(_payload "$REPO")' | '$HOOK'"
    [ "$status" -eq 0 ]
    [ -z "$(ls -A "$STORE")" ]
}

@test "precompact: the Queen session checkpoints into the orchestrator root's store" {
    export BORG_ORCHESTRATOR_ROOT="${BATS_TEST_TMPDIR}/queen"
    mkdir -p "$BORG_ORCHESTRATOR_ROOT"
    _fire "$BORG_ORCHESTRATOR_ROOT"
    [ -f "$BORG_ORCHESTRATOR_ROOT/.borg/checkpoints/2026-11-02-100000-3b0f70.md" ]
}

@test "precompact: the previous checkpoint's Blockers, Waits on you and Next Session are carried forward verbatim" {
    _link_up_checkpoint
    _fire "$REPO"
    run cat "$STORE/2026-11-02-100000-3b0f70.md"
    [[ "$output" == *"**tl;dr** — Shipped the chooser. Next: wire the rows."* ]]
    [[ "$output" == *"Waits on you:"* ]]
    [[ "$output" == *"- Approve the invented budget in the tracker."* ]]
    [[ "$output" == *"1. Wire the chooser rows into the board."* ]]
    [[ "$output" == *"carried-from=2026-10-30-120000-abcdef.md"* ]]
}

@test "precompact: the newest checkpoint is now the auto one, and its waits-on-you rows still reach borg next" {
    _link_up_checkpoint
    mkdir -p "$BORG_DIR"
    jq -n --arg p "$REPO" '{repositories: {fixture: {path: $p, status: "idle", last_activity: "2026-10-30T12:00:00Z"}}}' \
        > "$BORG_REGISTRY"
    run bash -c "zsh '$BORG' next --rows --json --local --all 2>/dev/null"
    printf '%s' "$output" | jq -e '[.rows[] | select(.project == "fixture" and .owner == "YOU")] | map(.next_step)
        == ["Approve the invented budget in the tracker."]'
    _fire "$REPO"
    [ -f "$STORE/2026-11-02-100000-3b0f70.md" ]
    run bash -c "zsh '$BORG' next --rows --json --local --all 2>/dev/null"
    [ "$status" -eq 0 ]
    printf '%s' "$output" | jq -e '[.rows[] | select(.project == "fixture") | {owner, next_step}] | sort_by(.owner)
        == [{owner: "AGENT", next_step: "Wire the chooser rows into the board."},
            {owner: "YOU", next_step: "Approve the invented budget in the tracker."}]'
}

@test "precompact: borg link --json still reports the link-up summary after an auto checkpoint" {
    _link_up_checkpoint
    mkdir -p "$BORG_DIR"
    jq -n --arg p "$REPO" '{repositories: {fixture: {path: $p, status: "idle", last_activity: "2026-10-30T12:00:00Z"}}}' \
        > "$BORG_REGISTRY"
    _fire "$REPO"
    run bash -c "zsh '$BORG' link fixture --json 2>/dev/null"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Shipped the chooser"* ]]
}

@test "build-plugin.sh registers the PreCompact hook and ships it executable beside hooks.json" {
    local plugin="${BATS_TEST_TMPDIR}/plugin/borg-collective"
    mkdir -p "$plugin"
    PLUGIN_DIR_OVERRIDE="$plugin" run bash "${BATS_TEST_DIRNAME}/../scripts/build-plugin.sh"
    [ "$status" -eq 0 ]
    test -x "$plugin/hooks/borg-precompact-checkpoint.sh"
    jq -e '[.hooks.PreCompact[].hooks[].command | select(test("borg-precompact-checkpoint"))] | length == 1' \
        "$plugin/hooks/hooks.json"
}
