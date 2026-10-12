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
