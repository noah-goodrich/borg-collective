#!/usr/bin/env bash
# resume_real.sh -- real-claude smoke lane for borg-resume (slice S16). LOCAL ONLY: not run in CI, not a bats file.
#
# What it proves: the REAL claude binary still emits the hook payload and the synthetic transcript record that the
# checked-in captured fixtures (tests/fixtures/resume/) were built from, so a Claude Code upgrade that changes either
# shape is caught here instead of silently turning borg-resume dark. Two legs, both against a throwaway listener on
# 127.0.0.1 (tests/smoke/resume_stub_api.py) that can only answer with errors:
#   (i)  HTTP 429 rate_limit_error     -> StopFailure error "rate_limit", synthetic record apiErrorStatus 429
#   (ii) an invalid model name         -> StopFailure for a model that does not exist (the stub answers 404)
# For each leg it asserts that
#   - a StopFailure hook payload arrived, and its key set matches tests/fixtures/resume/stop_failure_payload.json;
#   - the session transcript holds an isApiErrorMessage record, and its key set matches the isApiErrorMessage record
#     in tests/fixtures/resume/main_rate_limit.jsonl.
# "Matches" means: every named fixture key is present, and the real payload has keys beyond them exactly when the
# fixture has the "<key>" wildcard (the fixtures are allowlist skeletons: unknown keys were renamed "<key>").
#
# Run (needs claude, jq, python3; takes under a minute):
#     tests/smoke/resume_real.sh                 run both legs, exit 0 only if every check passed
#     tests/smoke/resume_real.sh check-keys '<json array of keys>' <fixture.json>
#                                                the shape matcher alone (used by tests/resume_smoke.bats)
# Environment:
#     BORG_CLAUDE_BIN        absolute path of the claude binary (default: the one on PATH)
#     SMOKE_LEG_TIMEOUT_SEC  hard limit per claude run (default 90)
#     SMOKE_KEEP=1           keep the temp dir (printed at the end) for inspection
# Exit: 0 all checks passed, 1 a check failed, 2 prerequisite missing (nothing was run), 3 skipped under CI.
#
# Isolation (all enforced here, not by convention):
#   - claude runs under `env -i` with ONLY a fake API key, HOME and CLAUDE_CONFIG_DIR inside a fresh temp dir, and
#     ANTHROPIC_BASE_URL set to the local listener. The script refuses to start a run unless that URL is 127.0.0.1,
#     so the real API is never contacted, with any model name.
#   - telemetry, error reporting, the auto-updater and non-essential traffic are switched off.
#   - nothing under the real HOME is read or written: no ~/.claude, no settings.json, no borg state dir, no launchd,
#     no tmux. The listener and the temp dir are removed on exit (also on Ctrl-C), unless SMOKE_KEEP=1.
#   - the hook is a tiny recorder that stores only the event name, the sorted KEY NAMES and the `error` enum value.
#
# Bash 3.2 compatible.

_sm_self="${BASH_SOURCE[0]:-$0}"
SM_HERE="$(cd "${_sm_self%/*}" && pwd)"
SM_ROOT="$(cd "$SM_HERE/../.." && pwd)"
SM_FXR="$SM_ROOT/tests/fixtures/resume"
SM_MODEL_BAD="borg-smoke-no-such-model"
SM_TMP=""
SM_STUB_PID=""
SM_FAILS=0

say() { printf '%s\n' "$*"; }
pass() { say "  PASS  $*"; }
fail() { say "  FAIL  $*"; SM_FAILS=$((SM_FAILS + 1)); }

# session_id is a tolerated alias: the fixture names it, claude 2.1.296 emits only sessionId. It is neither required
# nor counted as a surprise key.
# shape_match <actual keys as a JSON array> <fixture json file>. Exit 0 on a match.
shape_match() {
    jq -n -e --argjson a "$1" --slurpfile f "$2" '
        ($f[0] | keys) as $fk
        | ($fk - ["<key>", "session_id"]) as $named
        | ((($named - $a) | length) == 0)
          and (((($a - $named - ["session_id"]) | length) > 0) == (($fk | index("<key>")) != null))' >/dev/null 2>&1
}

# The first isApiErrorMessage record of a jsonl file, as one JSON line.
api_error_record() { jq -c 'select(type == "object" and .isApiErrorMessage == true)' "$1" 2>/dev/null | head -n 1; }

# shellcheck disable=SC2329  # invoked through trap
sm_cleanup() {
    [ -z "$SM_STUB_PID" ] || kill "$SM_STUB_PID" 2>/dev/null
    [ -z "$SM_STUB_PID" ] || wait "$SM_STUB_PID" 2>/dev/null
    SM_STUB_PID=""
    if [ -n "$SM_TMP" ]; then
        if [ "${SMOKE_KEEP:-0}" = 1 ]; then
            say "kept: $SM_TMP"
        else
            case "$SM_TMP" in
                */borg-resume-smoke.*) rm -rf "$SM_TMP" ;;
            esac
        fi
    fi
}

sm_prereq() {
    local _m
    for _m in jq python3; do
        command -v "$_m" >/dev/null 2>&1 || { say "missing prerequisite: $_m"; return 2; }
    done
    [ -f "$SM_FXR/stop_failure_payload.json" ] && [ -f "$SM_FXR/main_rate_limit.jsonl" ] || {
        say "missing fixtures under $SM_FXR"
        return 2
    }
    # shellcheck source=/dev/null
    . "$SM_ROOT/lib/borg/claude-bin.sh" 2>/dev/null
    if ! { declare -F borg_resolve_claude_bin >/dev/null 2>&1 && borg_resolve_claude_bin; }; then
        say "missing prerequisite: claude (set BORG_CLAUDE_BIN to an absolute path)"
        return 2
    fi
    return 0
}

sm_start_stub() {
    local _i=0
    python3 -I "$SM_HERE/resume_stub_api.py" "$SM_TMP/port" "$SM_TMP/stub.log" "$SM_TMP/mode" &
    SM_STUB_PID=$!
    while [ ! -s "$SM_TMP/port" ] && [ "$_i" -lt 50 ]; do
        sleep 0.1
        _i=$((_i + 1))
    done
    [ -s "$SM_TMP/port" ] || { say "listener did not start"; return 1; }
    SM_URL="http://127.0.0.1:$(cat "$SM_TMP/port")"
    return 0
}

# The recorder hook: event name, sorted key names, error enum. Nothing else is stored.
sm_write_hook() { # <dir>
    cat >"$1/hook.sh" <<'HOOK'
#!/bin/bash
jq -c '{ev: (.hook_event_name // "unknown"), error: (.error // null), keys: keys}' >>"$SMOKE_EVENTS" 2>/dev/null
exit 0
HOOK
    chmod +x "$1/hook.sh"
    jq -n --arg cmd "$1/hook.sh" '
        [ "StopFailure", "SessionStart", "Stop" ]
        | map({(.): [{hooks: [{type: "command", command: $cmd, timeout: 5}]}]}) | add | {hooks: .}' >"$1/settings.json"
}

# One leg: run claude once, then check the captured payload and transcript.
sm_leg() { # <label> <stub mode> <model> <expected error | "">
    local _l="$1" _mode="$2" _model="$3" _want="$4" _d _rc _pid _wd _i _sf _err _keys _rec _recfile _t
    _d="$SM_TMP/$_l"
    mkdir -p "$_d/home" "$_d/config" "$_d/work"
    : >"$_d/events.jsonl"
    printf '%s' "$_mode" >"$SM_TMP/mode"
    sm_write_hook "$_d"
    case "$SM_URL" in
        http://127.0.0.1:[0-9]*) ;;
        *) say "refusing to run: base URL is not the local listener ($SM_URL)"; return 2 ;;
    esac
    say "leg $_l (stub mode $_mode, model $_model)"
    (
        cd "$_d/work" || exit 1
        exec env -i PATH="$PATH" HOME="$_d/home" TERM=dumb TMPDIR="$SM_TMP" CLAUDE_CONFIG_DIR="$_d/config" \
            ANTHROPIC_BASE_URL="$SM_URL" ANTHROPIC_API_KEY="sk-ant-api03-smoke-local-stub-only" \
            CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 DISABLE_AUTOUPDATER=1 DISABLE_TELEMETRY=1 \
            DISABLE_ERROR_REPORTING=1 CLAUDE_CODE_MAX_RETRIES=0 SMOKE_EVENTS="$_d/events.jsonl" \
            "$BORG_CLAUDE_BIN" -p "reply with the single word ok" --model "$_model" --settings "$_d/settings.json" \
            >"$_d/stdout" 2>"$_d/stderr" </dev/null
    ) &
    _pid=$!
    ( sleep "${SMOKE_LEG_TIMEOUT_SEC:-90}"; kill "$_pid" 2>/dev/null; sleep 2; kill -9 "$_pid" 2>/dev/null ) &
    _wd=$!
    wait "$_pid"
    _rc=$?
    pkill -P "$_wd" 2>/dev/null
    kill "$_wd" 2>/dev/null
    wait "$_wd" 2>/dev/null
    # StopFailure is fire and forget: give the recorder a moment after the process exits.
    _i=0
    while [ "$_i" -lt 50 ]; do
        grep -q '"ev":"StopFailure"' "$_d/events.jsonl" 2>/dev/null && break
        sleep 0.1
        _i=$((_i + 1))
    done
    say "  claude exit code $_rc; stub saw $(wc -l <"$SM_TMP/stub.log" 2>/dev/null | tr -d ' ') request(s)"

    _sf="$(jq -c 'select(.ev == "StopFailure")' "$_d/events.jsonl" 2>/dev/null | head -n 1)"
    if [ -z "$_sf" ]; then
        fail "$_l: no StopFailure hook payload captured (events seen: $(jq -r .ev "$_d/events.jsonl" | tr '\n' ' '))"
        say "        stderr: $(head -c 300 "$_d/stderr" 2>/dev/null | tr '\n' ' ')"
    else
        _keys="$(printf '%s' "$_sf" | jq -c .keys)"
        _err="$(printf '%s' "$_sf" | jq -r '.error // empty')"
        if shape_match "$_keys" "$SM_FXR/stop_failure_payload.json"; then
            pass "$_l: StopFailure payload keys match stop_failure_payload.json"
        else
            fail "$_l: StopFailure payload keys differ from stop_failure_payload.json: $_keys"
        fi
        if [ -n "$_want" ]; then
            [ "$_err" = "$_want" ] && pass "$_l: error is $_err" || fail "$_l: error is '$_err', expected $_want"
        else
            if [ -z "$_err" ]; then
                fail "$_l: StopFailure carries no error value"
            elif [ "$_err" = model_not_found ]; then
                pass "$_l: error is model_not_found"
            else
                pass "$_l: error is '$_err' (the directive expects model_not_found; recorded as observed)"
            fi
        fi
    fi

    _t="$(find "$_d/config/projects" -name '*.jsonl' 2>/dev/null | head -n 20)"
    _rec=""
    while IFS= read -r _recfile; do
        [ -n "$_recfile" ] || continue
        _rec="$(api_error_record "$_recfile")"
        [ -z "$_rec" ] || break
    done <<EOF
$_t
EOF
    if [ -z "$_rec" ]; then
        fail "$_l: no isApiErrorMessage record in the session transcript"
    else
        api_error_record "$SM_FXR/main_rate_limit.jsonl" >"$_d/fixture_record.json"
        if shape_match "$(printf '%s' "$_rec" | jq -c 'keys')" "$_d/fixture_record.json"; then
            pass "$_l: synthetic record keys match the main_rate_limit.jsonl record"
        else
            fail "$_l: synthetic record keys differ: $(printf '%s' "$_rec" | jq -c 'keys')"
        fi
        if [ "$_mode" = 429 ]; then
            [ "$(printf '%s' "$_rec" | jq -r '.apiErrorStatus // empty')" = 429 ] &&
                pass "$_l: synthetic record apiErrorStatus is 429" || fail "$_l: apiErrorStatus is not 429"
        fi
    fi
    return 0
}

sm_main() {
    local _rc
    if [ -n "${CI:-}" ] && [ "${CI:-}" != 0 ] && [ "${CI:-}" != false ]; then
        say "skipped: the real-claude smoke lane is local only (CI is set)"
        return 3
    fi
    sm_prereq || return $?
    SM_TMP="$(mktemp -d "${TMPDIR:-/tmp}/borg-resume-smoke.XXXXXX")" || return 2
    trap sm_cleanup EXIT
    trap 'exit 130' INT TERM
    sm_start_stub || return 2
    say "borg-resume real-claude smoke: $("$BORG_CLAUDE_BIN" --version 2>/dev/null | head -n 1), stub $SM_URL"
    sm_leg rate_limit 429 "haiku" rate_limit
    sm_leg invalid_model 404model "$SM_MODEL_BAD" ""
    _rc=0
    [ "$SM_FAILS" -eq 0 ] || _rc=1
    say "$([ "$_rc" -eq 0 ] && echo 'ALL CHECKS PASSED' || echo "$SM_FAILS CHECK(S) FAILED")"
    return "$_rc"
}

case "${1:-run}" in
    check-keys)
        [ "$#" -eq 3 ] || { say "usage: $0 check-keys '<json array>' <fixture.json>"; exit 2; }
        shape_match "$2" "$3"
        exit $?
        ;;
    run)
        sm_main
        exit $?
        ;;
    *)
        say "usage: $0 [run | check-keys '<json array>' <fixture.json>]"
        exit 2
        ;;
esac
