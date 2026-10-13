#!/usr/bin/env bats
# Offline checks for the real-claude smoke lane (slice S16): tests/smoke/resume_real.sh and its stub listener.
# This file NEVER runs claude and never runs the smoke script's `run` verb (that is local-only, by hand). It covers the
# pieces that can be proven offline: the shape matcher, the local stub's error-only behaviour, the CI skip, and that
# the smoke directory is outside bats discovery (tests/*.bats).

setup() {
    SMOKE="${BATS_TEST_DIRNAME}/smoke/resume_real.sh"
    STUB="${BATS_TEST_DIRNAME}/smoke/resume_stub_api.py"
    FXR="${BATS_TEST_DIRNAME}/fixtures/resume"
    command -v jq >/dev/null || skip "jq not installed"
}

teardown() {
    if [ -n "${STUB_PID:-}" ]; then
        kill "$STUB_PID" 2>/dev/null || true
        wait "$STUB_PID" 2>/dev/null || true
    fi
}

start_stub() { # <mode>
    command -v python3 >/dev/null || skip "python3 not installed"
    command -v curl >/dev/null || skip "curl not installed"
    printf '%s' "$1" >"$BATS_TEST_TMPDIR/mode"
    python3 -I "$STUB" "$BATS_TEST_TMPDIR/port" "$BATS_TEST_TMPDIR/stub.log" "$BATS_TEST_TMPDIR/mode" &
    STUB_PID=$!
    local i=0
    while [ ! -s "$BATS_TEST_TMPDIR/port" ] && [ "$i" -lt 50 ]; do
        sleep 0.1
        i=$((i + 1))
    done
    [ -s "$BATS_TEST_TMPDIR/port" ]
    URL="http://127.0.0.1:$(cat "$BATS_TEST_TMPDIR/port")"
}

@test "smoke: the script and its stub are syntactically valid and outside bats discovery" {
    bash -n "$SMOKE"
    python3 -I -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$STUB"
    [ -x "$SMOKE" ]
    [ -z "$(find "${BATS_TEST_DIRNAME}/smoke" -name '*.bats')" ]
}

@test "smoke: check-keys accepts the fixture's own keys, with extra keys where the fixture has the wildcard" {
    run "$SMOKE" check-keys "$(jq -c 'keys' "$FXR/stop_failure_payload.json")" "$FXR/stop_failure_payload.json"
    [ "$status" -eq 0 ]
    run "$SMOKE" check-keys "$(jq -c '(keys - ["<key>"]) + ["some_new_field"]' "$FXR/stop_failure_payload.json")" \
        "$FXR/stop_failure_payload.json"
    [ "$status" -eq 0 ]
}

@test "smoke: check-keys rejects a missing named key, and a surprise key when the fixture has no wildcard" {
    run "$SMOKE" check-keys "$(jq -c '(keys - ["<key>", "error"])' "$FXR/stop_failure_payload.json")" \
        "$FXR/stop_failure_payload.json"
    [ "$status" -ne 0 ]
    jq -c 'del(."<key>")' "$FXR/stop_failure_payload.json" >"$BATS_TEST_TMPDIR/nowild.json"
    run "$SMOKE" check-keys "$(jq -c '(keys - ["<key>"]) + ["some_new_field"]' "$FXR/stop_failure_payload.json")" \
        "$BATS_TEST_TMPDIR/nowild.json"
    [ "$status" -ne 0 ]
    run "$SMOKE" check-keys "$(jq -c '(keys - ["<key>"])' "$FXR/stop_failure_payload.json")" \
        "$BATS_TEST_TMPDIR/nowild.json"
    [ "$status" -eq 0 ]
}

@test "smoke: the synthetic-record fixture matches itself and not a StopFailure payload" {
    jq -c 'select(.isApiErrorMessage == true)' "$FXR/main_rate_limit.jsonl" | head -n 1 >"$BATS_TEST_TMPDIR/rec.json"
    [ -s "$BATS_TEST_TMPDIR/rec.json" ]
    run "$SMOKE" check-keys "$(jq -c 'keys' "$BATS_TEST_TMPDIR/rec.json")" "$BATS_TEST_TMPDIR/rec.json"
    [ "$status" -eq 0 ]
    run "$SMOKE" check-keys "$(jq -c 'keys' "$FXR/stop_failure_payload.json")" "$BATS_TEST_TMPDIR/rec.json"
    [ "$status" -ne 0 ]
}

@test "smoke: the stub answers 429 / 404 / 400 with x-should-retry false and never succeeds" {
    start_stub 429
    run curl -s -i -X POST -H 'x-api-key: secret-key-value' -d '{}' "$URL/v1/messages"
    [[ "$output" == *"429"* ]]
    [[ "$output" == *"rate_limit_error"* ]]
    [[ "$output" == *"x-should-retry: false"* ]]
    printf '404model' >"$BATS_TEST_TMPDIR/mode"
    run curl -s -o /dev/null -w '%{http_code}' -X POST -d '{}' "$URL/v1/messages"
    [ "$output" = 404 ]
    printf 'anything' >"$BATS_TEST_TMPDIR/mode"
    run curl -s -o /dev/null -w '%{http_code}' -X POST -d '{}' "$URL/v1/messages"
    [ "$output" = 400 ]
    rm -f "$BATS_TEST_TMPDIR/mode"
    run curl -s -o /dev/null -w '%{http_code}' -X POST -d '{}' "$URL/v1/messages"
    [ "$output" = 400 ]
    run curl -s -o /dev/null -w '%{http_code}' "$URL/anything"
    [ "$output" = 404 ]
    [ "$(wc -l <"$BATS_TEST_TMPDIR/stub.log" | tr -d ' ')" = 5 ]
    ! grep -q 'secret-key-value' "$BATS_TEST_TMPDIR/stub.log"
}

@test "smoke: the stub binds loopback only" {
    start_stub 429
    run lsof -nP -a -p "$STUB_PID" -iTCP -sTCP:LISTEN
    if [ "$status" -eq 0 ]; then
        [[ "$output" == *"127.0.0.1:"* ]]
        [[ "$output" != *"*:"* ]]
    fi
}

@test "smoke: under CI the run verb skips with exit 3 before touching anything" {
    CI=1 run "$SMOKE"
    [ "$status" -eq 3 ]
    [[ "$output" == *"local only"* ]]
}
