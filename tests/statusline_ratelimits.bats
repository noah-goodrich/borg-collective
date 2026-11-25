#!/usr/bin/env bats
# #465: bin/borg-statusline caches rate_limits.five_hour from the statusline JSON for the usage guardian.

load test_helper/setup

setup() {
    setup_temp_dirs
    export XDG_STATE_HOME="${BATS_TEST_TMPDIR}/state" XDG_CACHE_HOME="${BATS_TEST_TMPDIR}/cache" HOME="${BATS_TEST_TMPDIR}"
}

@test "statusline writes rate-limits.json from the 2.1.300 capture" {
    run bash -c "bash '${BATS_TEST_DIRNAME}/../bin/borg-statusline' < '${BATS_TEST_DIRNAME}/fixtures/statusline-input-2.1.300.json'"
    [ "$status" -eq 0 ]
    f="$XDG_STATE_HOME/borg/rate-limits.json"
    [ "$(jq -r '.five_hour_pct' "$f")" = "10" ]
    [ "$(jq -r '.seven_day_pct' "$f")" = "4" ]
    [ -n "$(jq -r '.at' "$f")" ]
}

@test "statusline without rate_limits writes no cache and still exits 0" {
    run bash -c "echo '{\"session_id\":\"s\"}' | bash '${BATS_TEST_DIRNAME}/../bin/borg-statusline'"
    [ "$status" -eq 0 ]
    [ ! -e "$XDG_STATE_HOME/borg/rate-limits.json" ]
}

@test "usage_parse shapes: one fixture per shape" {
    . "${BATS_TEST_DIRNAME}/../lib/borg/usage-parse.sh"
    F="${BATS_TEST_DIRNAME}/fixtures"
    [[ "$(borg_usage_parse "$(cat $F/usage-output.txt)")" == session-line\|21\|39\|* ]]
    [[ "$(borg_usage_parse "$(cat $F/usage-output-idle.txt)")" == session-line\|0\|0\|* ]]
    [[ "$(borg_usage_parse "$(cat $F/usage-output-2.1.300.txt)")" == session-line\|5\|4\|* ]]
    [[ "$(borg_usage_parse "$(cat $F/usage-output-unmetered.txt)")" == unmetered\|* ]]
    [[ "$(borg_usage_parse "$(cat $F/usage-output-limits-breakdown.txt)")" == "limits-breakdown|||" ]]
    [[ "$(borg_usage_parse "garbage")" == "unrecognized|||" ]]
}
