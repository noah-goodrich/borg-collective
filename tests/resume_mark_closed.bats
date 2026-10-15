#!/usr/bin/env bats
# S3b (borg-resume): `borg-resume mark-closed <repository|sid>` and its callers (drone down, borg down).
# docker and tmux are stubs that log to $TRACE; repository names are invented.

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

@test "mark-closed <repository> marks every registered session of that repository only" {
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
    echo "{\"repositories\":{\"amber-fox-labs\":{\"path\":\"$PROJ\"}}}" > "$BORG_REGISTRY"
}

@test "drone down marks the repository closed" {
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


# ---- review fixes: repository-name charset, dir matching, ordering, borg down behavior -----------

regfull() {
    printf '{"session_id":"%s","project":"%s","cwd":"%s","tmux":{"project_dir":"%s"}}\n' \
        "$1" "$2" "$3" "$4" > "$BORG_RESUME_DIR/sessions/$1.json"
}

@test "mark-closed matches a repository name containing dots" {
    local sid="0b1e2c3d-4f5a-6b7c-8d9e-0a1b2c3d4e61"
    reg "$sid" "my.app v2"
    run "$BIN" mark-closed "my.app v2"
    [ "$status" -eq 0 ]
    [ -s "$(evs "$sid")" ]
    [ ! -e "$(evs "$SID3")" ]
}

@test "mark-closed matches a subdir cwd through the repository dir" {
    local sid="0b1e2c3d-4f5a-6b7c-8d9e-0a1b2c3d4e62"
    regfull "$sid" src "/dev/pr/src" ""
    run "$BIN" mark-closed pr /dev/pr
    [ "$status" -eq 0 ]
    [ -s "$(evs "$sid")" ]
    [ ! -e "$(evs "$SID3")" ]
}

@test "mark-closed matches the /workspace container case through tmux.project_dir" {
    local sid="0b1e2c3d-4f5a-6b7c-8d9e-0a1b2c3d4e63"
    regfull "$sid" workspace /workspace /dev/pr
    run "$BIN" mark-closed pr /dev/pr
    [ "$status" -eq 0 ]
    [ -s "$(evs "$sid")" ]
}

@test "mark-closed does not match a sibling dir sharing a prefix" {
    local sid="0b1e2c3d-4f5a-6b7c-8d9e-0a1b2c3d4e64"
    regfull "$sid" other /dev/pr-two/src /dev/pr-two
    run "$BIN" mark-closed pr /dev/pr
    [ ! -e "$(evs "$sid")" ]
}

@test "mark-closed with zero matches says so on stderr and exits 0" {
    run "$BIN" mark-closed nothing-here
    [ "$status" -eq 0 ]
    [[ "$output" == *"no session matched"* ]]
}

@test "mark-closed is skipped when the last event is already a mark, re-marked after a later session_end" {
    "$BIN" mark-closed "$SID1"
    "$BIN" mark-closed "$SID1"
    [ "$(wc -l < "$(evs "$SID1")" | tr -d ' ')" = 1 ]
    printf '{"t":1791806500,"ev":"session_end","sid":"%s","scope":"main","reason":"other"}\n' "$SID1" >> "$(evs "$SID1")"
    "$BIN" mark-closed "$SID1"
    [ "$(wc -l < "$(evs "$SID1")" | tr -d ' ')" = 3 ]
    [ "$(tail -n 1 "$(evs "$SID1")" | jq -r .via)" = "mark_closed" ]
}

@test "drone down marks again after teardown when the dying claude wrote session_end other" {
    _stub_infra
    cat > "$MOCK_BIN/docker" <<'MOCK'
#!/usr/bin/env bash
echo "docker $*" >> "$TRACE"
case "$*" in *" -p "*) printf '{"t":1791806500,"ev":"session_end","sid":"%s","scope":"main","reason":"other"}\n' "$SID1" >> "$BORG_RESUME_DIR/events/$SID1.jsonl" ;; esac
exit 0
MOCK
    chmod +x "$MOCK_BIN/docker"
    mkdir -p "$PROJ/.devcontainer" && : > "$PROJ/.devcontainer/docker-compose.yml"
    export SID1
    run "$DRONE" down amber-fox-labs
    [ "$status" -eq 0 ]
    [ "$(tail -n 1 "$(evs "$SID1")" | jq -r .via)" = "mark_closed" ]
}

@test "borg down marks only on the drone-down fallback, with name and dir" {
    local stub="$BATS_TEST_TMPDIR/resume-stub" log="$BATS_TEST_TMPDIR/stub.log"
    printf '#!/usr/bin/env bash\necho "$*" >> "%s"\n' "$log" > "$stub"
    chmod +x "$stub"
    run zsh -c '
        eval "$(sed -n "/^_borg_mark_closed()/,/^}/p;/^cmd_down()/,/^}/p" "$1")"
        BORG_TMUX_SESSION=s BORG_RESUME_BIN="$2"
        info() { :; }
        borg_tmux_alive() { return 0; }
        _borg_has_recent_checkpoint() { return 0; }
        _borg_offer_checkpoint() { :; }
        _borg_stop_shared_supabase() { :; }
        docker() { :; }
        drone() { [[ "$2" == good ]]; }
        tmux() {
            case "$1" in
                list-windows) printf "orchestrator\ngood\nbad\nnodir\n" ;;
                show-option) case "$3" in
                    s:good) echo /dev/good.app ;; s:bad) echo /dev/bad ;; *) return 1 ;; esac ;;
            esac
            return 0
        }
        cmd_down
    ' _ "${BATS_TEST_DIRNAME}/../borg.zsh" "$stub"
    [ "$status" -eq 0 ]
    [ "$(cat "$log")" = "mark-closed bad /dev/bad" ]
}
