#!/usr/bin/env bats
# Classifier, reset parser and transcript helpers for borg-resume (slice S2).
# Table-driven from tests/fixtures/resume/. Clock is pinned with BORG_RESUME_NOW_EPOCH.

setup() {
    FX="${BATS_TEST_DIRNAME}/fixtures/resume"
    LIB="${BATS_TEST_DIRNAME}/../lib/borg/resume-classify.sh"
    command -v jq >/dev/null || skip "jq not installed"
    # shellcheck disable=SC1090
    . "$LIB"
    # 2026-10-12 12:00:00 UTC
    export BORG_RESUME_NOW_EPOCH=1791806400
    unset BORG_RESUME_NATIVE_GRACE_SEC
}

_need_tz() {
    [ -f /usr/share/zoneinfo/America/Denver ] || [ -f /var/db/timezone/zoneinfo/America/Denver ] ||
        skip "tzdata not installed"
}

# epoch of a wall-clock time in a zone, via the same portable helper the library uses
_zone_epoch() { _rc_epoch_in_zone "$1" "$2" "$3"; }

@test "library parses under /bin/bash -n" {
    [ -x /bin/bash ] || skip "/bin/bash not present"
    run /bin/bash -n "$LIB"
    [ "$status" -eq 0 ]
}

@test "library defines functions only (sourcing prints nothing)" {
    run bash -c ". '$LIB'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ---- error -> class/action ----------------------------------------------------------------

@test "every StopFailure error maps to its matrix class and action" {
    local row err expect
    for row in \
        "rate_limit|You've hit your session limit|usage_limit resume" \
        "overloaded||transient backoff" \
        "server_error||transient backoff" \
        "unknown||transient backoff" \
        "timeout||transient backoff" \
        "connection_lost||transient backoff" \
        "stream_stalled||transient backoff" \
        "max_output_tokens||max_output_tokens resume" \
        "invalid_request|Prompt is too long|prompt_too_long compact_resume" \
        "invalid_request|bad param|notify_only notify" \
        "authentication_failed||notify_only notify" \
        "oauth_org_not_allowed||notify_only notify" \
        "account_on_hold||notify_only notify" \
        "verification_required||notify_only notify" \
        "billing_error||notify_only notify" \
        "cloud_credential_error||notify_only notify" \
        "model_not_found||notify_only notify" \
        "brand_new_error||transient backoff"; do
        err="${row%%|*}"
        local rest="${row#*|}"
        local text="${rest%%|*}"
        expect="${rest#*|}"
        run resume_classify_error "$err" "$text"
        [ "$status" -eq 0 ]
        [ "$output" = "$expect" ] || {
            echo "FAIL $err -> $output (want $expect)"
            return 1
        }
    done
}

@test "spend-limit and team-budget text map to notify_only even on rate_limit" {
    run resume_classify_error rate_limit "You've reached your monthly spend limit"
    [ "$output" = "notify_only notify" ]
    run resume_classify_error rate_limit "Your team budget has been exhausted"
    [ "$output" = "notify_only notify" ]
    run resume_classify_error unknown "spend limit reached"
    [ "$output" = "notify_only notify" ]
}

@test "captured fixtures classify end to end through the synthetic-error record" {
    local row f expect rec fields err text
    for row in \
        "main_rate_limit|usage_limit resume" \
        "main_rate_limit_session|usage_limit resume" \
        "main_authentication_failed|notify_only notify" \
        "main_invalid_request|prompt_too_long compact_resume" \
        "main_max_output_tokens|max_output_tokens resume" \
        "main_server_error_tail|transient backoff"; do
        f="${row%%|*}"
        expect="${row#*|}"
        rec="$(resume_last_meaningful_record "$FX/$f.jsonl")"
        fields="$(resume_synthetic_error "$rec")"
        err="${fields%%$'\t'*}"
        text="${fields#*$'\t'}"
        text="${text%$'\t'*}"
        run resume_classify_error "$err" "$text"
        [ "$output" = "$expect" ] || {
            echo "FAIL $f -> $output (want $expect)"
            return 1
        }
    done
}

# ---- reset parser -------------------------------------------------------------------------

@test "session phrasing: time later today in the named zone" {
    _need_tz
    # now = 06:00 MDT on 2026-10-12, so 7:10am is today
    export BORG_RESUME_NOW_EPOCH
    BORG_RESUME_NOW_EPOCH="$(_zone_epoch America/Denver 2026-10-12 06:00)"
    run resume_parse_reset "You've hit your session limit · resets 7:10am (America/Denver)"
    [ "$status" -eq 0 ]
    [ "$output" = "$(_zone_epoch America/Denver 2026-10-12 07:10)" ]
}

@test "hour-only phrasing and pm parse" {
    _need_tz
    BORG_RESUME_NOW_EPOCH="$(_zone_epoch America/Denver 2026-10-12 06:00)"
    run resume_parse_reset "resets 7am (America/Denver)"
    [ "$output" = "$(_zone_epoch America/Denver 2026-10-12 07:00)" ]
    run resume_parse_reset "resets 12am (America/Denver)"
    [ "$output" = "$(_zone_epoch America/Denver 2026-10-13 00:00)" ]
    run resume_parse_reset "resets 12:30pm (America/Denver)"
    [ "$output" = "$(_zone_epoch America/Denver 2026-10-12 12:30)" ]
    run resume_parse_reset "resets 5pm (America/Denver)"
    [ "$output" = "$(_zone_epoch America/Denver 2026-10-12 17:00)" ]
}

@test "a time earlier than now rolls to tomorrow" {
    _need_tz
    BORG_RESUME_NOW_EPOCH="$(_zone_epoch America/Denver 2026-10-12 08:00)"
    run resume_parse_reset "resets 7:10am (America/Denver)"
    [ "$status" -eq 0 ]
    [ "$output" = "$(_zone_epoch America/Denver 2026-10-13 07:10)" ]
}

@test "weekly phrasing with a date parses in the named zone" {
    _need_tz
    BORG_RESUME_NOW_EPOCH="$(_zone_epoch America/Denver 2026-10-12 08:00)"
    run resume_parse_reset "You've hit your weekly limit · resets Oct 17 at 7am (America/Denver)"
    [ "$status" -eq 0 ]
    [ "$output" = "$(_zone_epoch America/Denver 2026-10-17 07:00)" ]
}

@test "a dated reset already in the past rolls to next year" {
    _need_tz
    BORG_RESUME_NOW_EPOCH="$(_zone_epoch America/Denver 2026-10-12 08:00)"
    run resume_parse_reset "resets Jul 7 at 7am (America/Denver)"
    [ "$status" -eq 0 ]
    [ "$output" = "$(_zone_epoch America/Denver 2027-07-07 07:00)" ]
}

@test "relative phrasing: hours, minutes, days and combinations" {
    run resume_parse_reset "resets in 3 hours"
    [ "$output" = "$((BORG_RESUME_NOW_EPOCH + 10800))" ]
    run resume_parse_reset "resets in 45 minutes"
    [ "$output" = "$((BORG_RESUME_NOW_EPOCH + 2700))" ]
    run resume_parse_reset "resets in 1 hour 30 minutes"
    [ "$output" = "$((BORG_RESUME_NOW_EPOCH + 5400))" ]
    run resume_parse_reset "resets in 2 days"
    [ "$output" = "$((BORG_RESUME_NOW_EPOCH + 172800))" ]
}

@test "short zone labels resolve (MT is America/Denver)" {
    _need_tz
    BORG_RESUME_NOW_EPOCH="$(_zone_epoch America/Denver 2026-10-12 06:00)"
    run resume_parse_reset "resets 7:10am (MT)"
    [ "$status" -eq 0 ]
    [ "$output" = "$(_zone_epoch America/Denver 2026-10-12 07:10)" ]
}

@test "same wall time in different zones gives different epochs" {
    _need_tz
    [ -f /usr/share/zoneinfo/Asia/Tokyo ] || skip "tzdata incomplete"
    BORG_RESUME_NOW_EPOCH="$(_zone_epoch UTC 2026-10-12 00:00)"
    run resume_parse_reset "resets 9am (Asia/Tokyo)"
    [ "$output" = "$(_zone_epoch UTC 2026-10-12 00:00)" ] || [ "$output" = "$(_zone_epoch UTC 2026-10-13 00:00)" ]
}

@test "unparseable text and bad zones fail with rc 1" {
    run resume_parse_reset "You've hit your limit"
    [ "$status" -eq 1 ]
    run resume_parse_reset ""
    [ "$status" -eq 1 ]
    run resume_parse_reset "resets 7:10am (Not/AZone)"
    [ "$status" -eq 1 ]
    run resume_parse_reset "resets 13pm (UTC)"
    [ "$status" -eq 1 ]
}

# ---- plan ---------------------------------------------------------------------------------

@test "usage limit resumes at reset plus the native grace" {
    run resume_plan rate_limit "resets in 3 hours"
    [ "$output" = "usage_limit resume $((BORG_RESUME_NOW_EPOCH + 10800 + 120))" ]
    BORG_RESUME_NATIVE_GRACE_SEC=30
    run resume_plan rate_limit "resets in 3 hours"
    [ "$output" = "usage_limit resume $((BORG_RESUME_NOW_EPOCH + 10800 + 30))" ]
}

@test "usage limit with unparseable reset falls back to backoff" {
    run resume_plan rate_limit "You've hit your limit" 0
    [ "$output" = "usage_limit backoff $((BORG_RESUME_NOW_EPOCH + 45))" ]
    run resume_plan rate_limit "You've hit your limit" 4
    [ "$output" = "usage_limit notify -" ]
}

@test "transient backoff is 45s, 2m, 5m, 15m, then notify" {
    local a want=(45 120 300 900)
    for a in 0 1 2 3; do
        run resume_plan server_error "" "$a"
        [ "$output" = "transient backoff $((BORG_RESUME_NOW_EPOCH + ${want[$a]}))" ]
    done
    run resume_plan server_error "" 4
    [ "$output" = "transient notify -" ]
}

@test "sleep-truncated errors get only the first backoff" {
    run resume_plan server_error "" 3 true
    [ "$output" = "transient backoff $((BORG_RESUME_NOW_EPOCH + 45))" ]
}

@test "max_output_tokens is +15s, prompt_too_long is immediate, notify classes have no time" {
    run resume_plan max_output_tokens ""
    [ "$output" = "max_output_tokens resume $((BORG_RESUME_NOW_EPOCH + 15))" ]
    run resume_plan invalid_request "Prompt is too long"
    [ "$output" = "prompt_too_long compact_resume $BORG_RESUME_NOW_EPOCH" ]
    run resume_plan authentication_failed "Login expired"
    [ "$output" = "notify_only notify -" ]
}

@test "plan over captured weekly and session limit fixtures" {
    _need_tz
    BORG_RESUME_NOW_EPOCH="$(_zone_epoch America/Denver 2026-10-12 06:00)"
    local rec fields text
    rec="$(resume_last_meaningful_record "$FX/main_rate_limit_session.jsonl")"
    fields="$(resume_synthetic_error "$rec")"
    text="${fields#*$'\t'}"
    text="${text%$'\t'*}"
    run resume_plan rate_limit "$text"
    [ "$output" = "usage_limit resume $(($(_zone_epoch America/Denver 2026-10-12 07:10) + 120))" ]
}

# ---- interrupt markers --------------------------------------------------------------------

@test "interrupt marker text matcher" {
    resume_is_interrupt_marker "[Request interrupted by user]"
    resume_is_interrupt_marker "[Request interrupted by user for tool use]"
    ! resume_is_interrupt_marker "please continue"
    ! resume_is_interrupt_marker "[Request interrupted by user] and more"
}

@test "interrupt fixtures: plain and for tool use are trailing markers" {
    run resume_tail_interrupted "$FX/interrupt_user.jsonl"
    [ "$status" -eq 0 ]
    run resume_tail_interrupted "$FX/interrupt_tool_use.jsonl"
    [ "$status" -eq 0 ]
    rec="$(resume_last_meaningful_record "$FX/interrupt_tool_use.jsonl")"
    resume_record_is_interrupt "$rec"
}

@test "a later user message cancels the interrupt marker" {
    local t="$BATS_TEST_TMPDIR/cancel.jsonl"
    cp "$FX/interrupt_user.jsonl" "$t"
    printf '%s\n' '{"type":"user","uuid":"u-0299","message":{"role":"user","content":"carry on"}}' >>"$t"
    run resume_tail_interrupted "$t"
    [ "$status" -ne 0 ]
    printf '%s\n' '{"type":"permission-mode","permissionMode":"default"}' >>"$t"
    run resume_tail_interrupted "$t"
    [ "$status" -ne 0 ]
}

@test "a trailing marker followed only by bookkeeping is still an interrupt" {
    local t="$BATS_TEST_TMPDIR/bk.jsonl"
    cp "$FX/interrupt_tool_use.jsonl" "$t"
    printf '%s\n' '{"type":"last-prompt"}' '{"type":"cost-state"}' >>"$t"
    run resume_tail_interrupted "$t"
    [ "$status" -eq 0 ]
}

@test "a marker given as a plain string content is detected" {
    resume_record_is_interrupt '{"type":"user","message":{"role":"user","content":"[Request interrupted by user]"}}'
    ! resume_record_is_interrupt '{"type":"assistant","message":{"role":"assistant","content":"[Request interrupted by user]"}}'
}

# ---- bookkeeping allowlist and last meaningful record -------------------------------------

@test "bookkeeping allowlist" {
    local t
    for t in last-prompt permission-mode pr-link cost-state file-history-snapshot attachment; do
        resume_record_is_bookkeeping "{\"type\":\"$t\"}" || {
            echo "not bookkeeping: $t"
            return 1
        }
    done
    resume_record_is_bookkeeping '{"type":"system","subtype":"stop_hook_summary"}'
    resume_record_is_bookkeeping '{"type":"system","subtype":"turn_duration"}'
    ! resume_record_is_bookkeeping '{"type":"system","subtype":"other"}'
    ! resume_record_is_bookkeeping '{"type":"assistant"}'
    ! resume_record_is_bookkeeping '{"type":"user"}'
}

@test "synthetic server_error is the last meaningful record despite five trailing bookkeeping records" {
    run resume_last_meaningful_line "$FX/main_server_error_tail.jsonl"
    [ "$output" = "2" ]
    rec="$(resume_last_meaningful_record "$FX/main_server_error_tail.jsonl")"
    fields="$(resume_synthetic_error "$rec")"
    [ "${fields%%$'\t'*}" = "server_error" ]
    resume_record_is_clean_close '{"type":"system","subtype":"turn_duration"}'
    ! resume_record_is_clean_close "$rec"
}

@test "sleep-interrupted tail: error followed by bookkeeping only" {
    local t="$BATS_TEST_TMPDIR/sleep.jsonl"
    grep -v turn_duration "$FX/main_server_error_tail.jsonl" >"$t"
    run resume_last_meaningful_line "$t"
    [ "$output" = "2" ]
    rec="$(resume_last_meaningful_record "$t")"
    fields="$(resume_synthetic_error "$rec")"
    [ "${fields%%$'\t'*}" = "server_error" ]
    [ "${fields##*$'\t'}" = "true" ]
}

@test "five trailing bookkeeping records after the synthetic error are skipped" {
    local t="$BATS_TEST_TMPDIR/five.jsonl"
    head -n 2 "$FX/main_server_error_tail.jsonl" >"$t"
    printf '%s\n' '{"type":"permission-mode"}' '{"type":"pr-link"}' \
        '{"type":"system","subtype":"stop_hook_summary"}' '{"type":"last-prompt"}' \
        '{"type":"cost-state"}' >>"$t"
    run resume_last_meaningful_line "$t"
    [ "$output" = "2" ]
    rec="$(resume_last_meaningful_record "$t")"
    resume_synthetic_error "$rec" >/dev/null
}

@test "last_meaningful_record honours the tail window and absolute line numbers" {
    local t="$BATS_TEST_TMPDIR/long.jsonl" i
    : >"$t"
    for i in $(seq 1 100); do printf '%s\n' '{"type":"user","message":{"content":"x"}}' >>"$t"; done
    printf '%s\n' '{"type":"assistant","uuid":"last"}' '{"type":"cost-state"}' >>"$t"
    run resume_last_meaningful_line "$t" 60
    [ "$output" = "101" ]
    # only bookkeeping inside the window: nothing meaningful
    run resume_last_meaningful_record "$t" 1
    [ -z "$output" ]
}

@test "malformed lines and a missing file are tolerated" {
    local t="$BATS_TEST_TMPDIR/bad.jsonl"
    printf '%s\n' '{"type":"assistant","uuid":"a"}' 'not json at all' >"$t"
    run resume_last_meaningful_line "$t"
    [ "$output" = "1" ]
    run resume_last_meaningful_record "$BATS_TEST_TMPDIR/missing.jsonl"
    [ "$status" -ne 0 ]
}

@test "resume_synthetic_error ignores ordinary records" {
    run resume_synthetic_error '{"type":"assistant","message":{"content":[{"type":"text","text":"hi"}]}}'
    [ "$status" -ne 0 ]
}
