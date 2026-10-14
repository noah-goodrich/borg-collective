#!/usr/bin/env bats
# build-plugin.sh must prune mirror agents that no longer exist in source.
# Sandboxed: PLUGIN_DIR_OVERRIDE and BORG_ORCHESTRATOR_ROOT point into the test tmpdir.

load test_helper/setup

BUILD_PLUGIN="${BATS_TEST_DIRNAME}/../scripts/build-plugin.sh"
SRC_AGENTS="${BATS_TEST_DIRNAME}/../agents"

setup() {
    setup_temp_dirs
    export BORG_ORCHESTRATOR_ROOT="$BORG_TEST_HOME/dev"
    export PLUGIN_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/claude-plugins/borg-collective"
    mkdir -p "$PLUGIN_DIR_OVERRIDE/agents"
    echo "stale" > "$PLUGIN_DIR_OVERRIDE/agents/STALE.md"
}

@test "build prunes stale agents/*.md so mirror agents equals source agents" {
    run bash "$BUILD_PLUGIN"
    [ "$status" -eq 0 ]
    [ ! -e "$PLUGIN_DIR_OVERRIDE/agents/STALE.md" ]
    run diff <(cd "$SRC_AGENTS" && ls *.md) <(cd "$PLUGIN_DIR_OVERRIDE/agents" && ls *.md)
    [ "$status" -eq 0 ]
}

@test "dry-run reports the prune but leaves the stale file in place" {
    run bash "$BUILD_PLUGIN" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"STALE.md"* ]]
    [ -e "$PLUGIN_DIR_OVERRIDE/agents/STALE.md" ]
}

# ── Phase 1 mirrors whole skill directories ─────────────────────────────────
# These run a COPY of the build inputs so a fixture skill can carry references/.

_sandbox_repo() {
    SB="${BATS_TEST_TMPDIR}/repo"
    mkdir -p "$SB"
    local d
    for d in scripts skills hooks lib agents; do
        cp -R "${BATS_TEST_DIRNAME}/../$d" "$SB/$d"
    done
    cp "${BATS_TEST_DIRNAME}/../VERSION" "$SB/VERSION"
    mkdir -p "$SB/skills/fixture/references/deep"
    printf '%s\n' "# fixture" > "$SB/skills/fixture/SKILL.md"
    printf '%s\n' "ref one" > "$SB/skills/fixture/references/x.md"
    printf '%s\n' "ref deep" > "$SB/skills/fixture/references/deep/y.md"
}

@test "a skill's references/ files are mirrored, recursively" {
    _sandbox_repo
    run bash "$SB/scripts/build-plugin.sh"
    [ "$status" -eq 0 ]
    [ -f "$PLUGIN_DIR_OVERRIDE/skills/fixture/SKILL.md" ]
    run cat "$PLUGIN_DIR_OVERRIDE/skills/fixture/references/x.md"
    [ "$output" = "ref one" ]
    [ -f "$PLUGIN_DIR_OVERRIDE/skills/fixture/references/deep/y.md" ]
}

@test "dry-run lists skill files without writing them" {
    _sandbox_repo
    run bash "$SB/scripts/build-plugin.sh" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"would sync skill file: fixture/references/x.md"* ]]
    [ ! -e "$PLUGIN_DIR_OVERRIDE/skills/fixture/references/x.md" ]
}

@test "a reference deleted from source is removed from the mirror" {
    _sandbox_repo
    run bash "$SB/scripts/build-plugin.sh"
    [ "$status" -eq 0 ]
    rm "$SB/skills/fixture/references/x.md"
    run bash "$SB/scripts/build-plugin.sh" --dry-run
    [[ "$output" == *"would remove skill file: fixture/references/x.md"* ]]
    [ -e "$PLUGIN_DIR_OVERRIDE/skills/fixture/references/x.md" ]
    run bash "$SB/scripts/build-plugin.sh"
    [ "$status" -eq 0 ]
    [ ! -e "$PLUGIN_DIR_OVERRIDE/skills/fixture/references/x.md" ]
    [ -e "$PLUGIN_DIR_OVERRIDE/skills/fixture/references/deep/y.md" ]
}

@test "a SKILL.md-only skill syncs as before and a rerun is a no-op" {
    _sandbox_repo
    rm -r "$SB/skills/fixture/references"
    run bash "$SB/scripts/build-plugin.sh"
    [ "$status" -eq 0 ]
    run diff "$SB/skills/fixture/SKILL.md" "$PLUGIN_DIR_OVERRIDE/skills/fixture/SKILL.md"
    [ "$status" -eq 0 ]
    run bash "$SB/scripts/build-plugin.sh"
    [[ "$output" == *"all skills in sync"* ]]
}
