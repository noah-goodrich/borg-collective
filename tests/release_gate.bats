#!/usr/bin/env bats
# scripts/release-gate.sh (#536): plugin content may not change under an already-released VERSION unless the PR
# carries the `unreleased` label. Each case builds a throwaway git repo with a copy of build-plugin.sh.

GATE="${BATS_TEST_DIRNAME}/../scripts/release-gate.sh"
BUILD="${BATS_TEST_DIRNAME}/../scripts/build-plugin.sh"

setup() {
    R="${BATS_TEST_TMPDIR}/repo"
    mkdir -p "$R/scripts" "$R/hooks" "$R/skills/x" "$R/docs"
    cp "$BUILD" "$R/scripts/build-plugin.sh"
    echo 0.9.14 > "$R/VERSION"
    echo a > "$R/hooks/bash-guard.sh"
    echo a > "$R/hooks/borg-cortex-restore.sh"
    echo a > "$R/skills/x/SKILL.md"
    echo a > "$R/docs/note.md"
    export RELEASE_GATE_ROOT="$R"
    git -C "$R" init -q -b main
    git -C "$R" config user.email t@t
    git -C "$R" config user.name t
    git -C "$R" add -A
    git -C "$R" commit -q -m base
    git -C "$R" tag v0.9.14
    git -C "$R" checkout -q -b pr
}

commit_file() { # <path> <content>
    mkdir -p "$(dirname "$R/$1")"
    echo "$2" > "$R/$1"
    git -C "$R" add -A
    git -C "$R" commit -q -m change
}

@test "paths: every hook and lib file build-plugin.sh names is listed, and the trees" {
    run "$GATE" paths
    [ "$status" -eq 0 ]
    [[ "$output" == *"hooks/borg-nanoprobe-guard.sh"* ]]
    [[ "$output" == *"lib/borg-hooks.sh"* ]]
    [[ "$output" == *"lib/reaper.sh"* ]]
    [[ "$output" == *"skills/"* ]]
    [[ "$output" == *"agents/"* ]]
}

@test "paths: pinned against the real hooks directory (drift fails here)" {
    export RELEASE_GATE_ROOT="${BATS_TEST_DIRNAME}/.."
    for f in $("$GATE" paths | grep -E '^(hooks|lib)/'); do
        [ -f "${BATS_TEST_DIRNAME}/../$f" ]
    done
    run "$GATE" paths
    [[ "$output" != *"borg-cortex-restore.sh"* ]]
}

@test "plugin hook change at the released version fails with the two remedies" {
    commit_file hooks/bash-guard.sh b
    run "$GATE" check main pr ""
    [ "$status" -eq 1 ]
    [[ "$output" == *"hooks/bash-guard.sh"* ]]
    [[ "$output" == *"Bump VERSION"* ]]
    [[ "$output" == *"'unreleased'"* ]]
    [[ "$output" == *"Main after 0.9.14 (unreleased)"* ]]
}

@test "skills change at the released version fails" {
    commit_file skills/x/SKILL.md b
    run "$GATE" check main pr ""
    [ "$status" -eq 1 ]
}

@test "the unreleased label lets it through" {
    commit_file hooks/bash-guard.sh b
    run "$GATE" check main pr "bug,unreleased"
    [ "$status" -eq 0 ]
}

@test "a label that merely contains the word does not count" {
    commit_file hooks/bash-guard.sh b
    run "$GATE" check main pr "not-unreleased"
    [ "$status" -eq 1 ]
}

@test "a VERSION bump past the tag passes" {
    commit_file hooks/bash-guard.sh b
    commit_file VERSION 0.9.15
    run "$GATE" check main pr ""
    [ "$status" -eq 0 ]
}

@test "a hook that build-plugin.sh does not package does not trip the gate" {
    commit_file hooks/borg-cortex-restore.sh b
    run "$GATE" check main pr ""
    [ "$status" -eq 0 ]
}

@test "docs-only change passes" {
    commit_file docs/note.md b
    run "$GATE" check main pr ""
    [ "$status" -eq 0 ]
}

@test "newest tag is chosen by version order, not text order" {
    git -C "$R" tag v0.9.9
    commit_file hooks/bash-guard.sh b
    run "$GATE" check main pr ""
    [ "$status" -eq 1 ]
    [[ "$output" == *"v0.9.14"* ]]
}

@test "no tags at all fails loudly" {
    git -C "$R" tag -d v0.9.14
    run "$GATE" check main pr ""
    [ "$status" -eq 1 ]
    [[ "$output" == *"no vX.Y.Z tag"* ]]
}
