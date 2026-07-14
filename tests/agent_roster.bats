#!/usr/bin/env bats
# Tests for scripts/check-agent-roster.sh — the source↔distro agent-roster drift guard.
#
# The check compares the real source agents/ dir (SCRIPT_DIR/../agents) against a distro dir
# supplied via PLUGIN_AGENTS_DIR. These tests point PLUGIN_AGENTS_DIR at controlled fake distros
# built from the real source, so they assert the guard passes when identical and fails loudly on
# each drift shape: a distro missing a source file, a distro-only orphan, and a content mismatch.

load test_helper/setup

CHECK_ROSTER="${BATS_TEST_DIRNAME}/../scripts/check-agent-roster.sh"
SRC_AGENTS="${BATS_TEST_DIRNAME}/../agents"

@test "roster: exits 0 when distro is an identical copy of source" {
    local fake_distro="${BATS_TEST_TMPDIR}/roster-pass"
    mkdir -p "$fake_distro"
    cp "$SRC_AGENTS"/*.md "$fake_distro/"

    run bash -c "PLUGIN_AGENTS_DIR='$fake_distro' bash '$CHECK_ROSTER'"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "OK: agent roster in sync"
}

@test "roster: exits 1 when a source agent is missing from the distro" {
    local fake_distro="${BATS_TEST_TMPDIR}/roster-missing"
    mkdir -p "$fake_distro"
    cp "$SRC_AGENTS"/*.md "$fake_distro/"
    rm "$fake_distro/borg-scout.md"

    run bash -c "PLUGIN_AGENTS_DIR='$fake_distro' bash '$CHECK_ROSTER'"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "borg-scout.md — in source, missing from distro"
}

@test "roster: exits 1 on a distro-only orphan agent not in source" {
    local fake_distro="${BATS_TEST_TMPDIR}/roster-orphan"
    mkdir -p "$fake_distro"
    cp "$SRC_AGENTS"/*.md "$fake_distro/"
    echo "orphan" > "$fake_distro/ghost-agent.md"

    run bash -c "PLUGIN_AGENTS_DIR='$fake_distro' bash '$CHECK_ROSTER'"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "ghost-agent.md — in distro, missing from source"
}

@test "roster: exits 1 when an agent's content differs between source and distro" {
    local fake_distro="${BATS_TEST_TMPDIR}/roster-content"
    mkdir -p "$fake_distro"
    cp "$SRC_AGENTS"/*.md "$fake_distro/"
    printf '\nDRIFTED LINE\n' >> "$fake_distro/ROUTING.md"

    run bash -c "PLUGIN_AGENTS_DIR='$fake_distro' bash '$CHECK_ROSTER'"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "ROUTING.md — content differs"
}

@test "roster: exits 1 when the distro agents dir does not exist" {
    run bash -c "PLUGIN_AGENTS_DIR='${BATS_TEST_TMPDIR}/nope' bash '$CHECK_ROSTER'"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "not found"
}
