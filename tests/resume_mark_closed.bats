#!/usr/bin/env bats
# S3b (borg-resume): `borg-resume mark-closed <project|sid>` and its callers (drone down, borg down).
# docker and tmux are stubs that log to $TRACE; project names are invented.

load test_helper/setup

BIN="${BATS_TEST_DIRNAME}/../bin/borg-resume"
DRONE="${BATS_TEST_DIRNAME}/../drone.zsh"
SID1="0b1e2c3d-4f5a-6b7c-8d9e-0a1b2c3d4e51"
SID2="0b1e2c3d-4f5a-6b7c-8d9e-0a1b2c3d4e52"
SID3="0b1e2c3d-4f5a-6b7c-8d9e-0a1b2c3d4e53"

setup() {
    setup_temp_dirs
    setup_mock_bin
    command -v jq >/dev/null || skip "jq not installed"
    export TRACE="${BATS_TEST_TMPDIR}/trace.log"
    : > "$TRACE"
    export BORG_RESUME_DIR="${BATS_TEST_TMPDIR}/resume"
    export BORG_RESUME_NOW_EPOCH=1791806400
    unset BORG_RESUME_DISABLE BORG_NO_SESSION_HOOKS BORG_RESUME_BIN
    mkdir -p "$BORG_RESUME_DIR/sessions" "$BORG_RESUME_DIR/events"
    reg "$SID1" amber-fox-labs
    reg "$SID2" amber-fox-labs
    reg "$SID3" other-proj
}

reg() { printf '{"session_id":"%s","project":"%s"}\n' "$1" "$2" > "$BORG_RESUME_DIR/sessions/$1.json"; }
evs() { printf '%s/events/%s.jsonl' "$BORG_RESUME_DIR" "$1"; }

@test "mark-closed <sid> appends a session_end prompt_input_exit event" {
    run "$BIN" mark-closed "$SID1"
    [ "$status" -eq 0 ]
    [ "$(jq -r .ev "$(evs "$SID1")")" = "session_end" ]
    [ "$(jq -r .reason "$(evs "$SID1")")" = "prompt_input_exit" ]
    [ "$(jq -r .via "$(evs "$SID1")")" = "mark_closed" ]
    [ "$(jq -r .sid "$(evs "$SID1")")" = "$SID1" ]
    [ "$(jq -r .scope "$(evs "$SID1")")" = "main" ]
    [ "$(jq -r .t "$(evs "$SID1")")" = "1791806400" ]
    [ ! -e "$(evs "$SID3")" ]
}

@test "mark-closed <project> marks every registered session of that project only" {
    run "$BIN" mark-closed amber-fox-labs
    [ "$status" -eq 0 ]
    [ -s "$(evs "$SID1")" ]
    [ -s "$(evs "$SID2")" ]
    [ ! -e "$(evs "$SID3")" ]
}

@test "mark-closed of an unknown target exits 0 and writes nothing" {
    run "$BIN" mark-closed nothing-here
    [ "$status" -eq 0 ]
    [ -z "$(ls "$BORG_RESUME_DIR/events")" ]
}

@test "mark-closed with no target is a usage error" {
    run "$BIN" mark-closed
    [ "$status" -eq 2 ]
}

@test "mark-closed respects the env kill switch" {
    BORG_RESUME_DISABLE=1 run "$BIN" mark-closed "$SID1"
    [ "$status" -eq 0 ]
    [ ! -e "$(evs "$SID1")" ]
}

@test "mark-closed still records when only the DISABLED sentinel is set" {
    : > "$BORG_RESUME_DIR/DISABLED"
    run "$BIN" mark-closed "$SID1"
    [ "$status" -eq 0 ]
    [ -s "$(evs "$SID1")" ]
}

@test "mark-closed rejects a hostile target without writing" {
    run "$BIN" mark-closed "../x;id"
    [ "$status" -eq 0 ]
    [ -z "$(ls "$BORG_RESUME_DIR/events")" ]
}

# ---- callers --------------------------------------------------------------------------------

_stub_infra() {
    cat > "$MOCK_BIN/tmux" <<'MOCK'
#!/usr/bin/env bash
echo "tmux $*" >> "$TRACE"
exit 1
MOCK
    cat > "$MOCK_BIN/docker" <<'MOCK'
#!/usr/bin/env bash
echo "docker $*" >> "$TRACE"
exit 0
MOCK
    chmod +x "$MOCK_BIN/tmux" "$MOCK_BIN/docker"
    PROJ="$BATS_TEST_TMPDIR/dev/amber-fox-labs"
    mkdir -p "$PROJ"
    echo "{\"projects\":{\"amber-fox-labs\":{\"path\":\"$PROJ\"}}}" > "$BORG_REGISTRY"
}

@test "drone down marks the project closed" {
    _stub_infra
    run "$DRONE" down amber-fox-labs
    [ "$status" -eq 0 ]
    [ -s "$(evs "$SID1")" ]
    [ -s "$(evs "$SID2")" ]
    [ ! -e "$(evs "$SID3")" ]
}

@test "drone down skips marking when the kill switch is set" {
    _stub_infra
    BORG_RESUME_DISABLE=1 run "$DRONE" down amber-fox-labs
    [ "$status" -eq 0 ]
    [ ! -e "$(evs "$SID1")" ]
}

@test "drone down still succeeds when borg-resume is broken" {
    _stub_infra
    printf '#!/usr/bin/env bash\nexit 7\n' > "$BATS_TEST_TMPDIR/bad-resume"
    chmod +x "$BATS_TEST_TMPDIR/bad-resume"
    BORG_RESUME_BIN="$BATS_TEST_TMPDIR/bad-resume" run "$DRONE" down amber-fox-labs
    [ "$status" -eq 0 ]
}

@test "borg down calls the shared mark-closed helper" {
    grep -q "_borg_mark_closed" "${BATS_TEST_DIRNAME}/../borg.zsh"
}
