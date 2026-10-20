#!/usr/bin/env bats
# The arrival brief (docs/plans/directives/2026-10-18-arrival-brief-on-sessionstart.md, AC1-AC6 and the plugin half
# of AC3/AC7). hooks/borg-arrival-brief.sh is a SessionStart hook whose stdout is a top-level `systemMessage`.
#
# `borg` is a MOCK that records its argv and serves a synthetic document; `git` is a mock that records itself and
# exits 99. Every repository name here is a placeholder: nothing is read from a real registry.

load test_helper/setup

HOOK="${BATS_TEST_DIRNAME}/../hooks/borg-arrival-brief.sh"
BUILD="${BATS_TEST_DIRNAME}/../scripts/build-plugin.sh"

setup() {
    setup_temp_dirs
    setup_mock_bin
    mkdir -p "$BORG_DIR" "$HOME/dev/fixture-repo"
    export MOCK_LOG="${BATS_TEST_TMPDIR}/borg-argv.log"
    export GIT_LOG="${BATS_TEST_TMPDIR}/git-argv.log"
    export MOCK_DOC="${BATS_TEST_TMPDIR}/doc.json"
    : > "$MOCK_LOG"
    cat > "$MOCK_BIN/borg" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_LOG"
[ -n "${MOCK_FAIL:-}" ] && exit 1
case "$1 $2" in
    "next --line") printf '%s\n' "▶ merge #440 · fixture-repo · 4 waiting" ;;
    "link "*) cat "$MOCK_DOC" ;;
esac
MOCK
    cat > "$MOCK_BIN/git" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GIT_LOG"
exit 99
MOCK
    chmod +x "$MOCK_BIN/borg" "$MOCK_BIN/git"
    local stamp now
    stamp=$(date +%Y-%m-%d-%H%M)
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    jq -n --arg cp "$stamp.md" --arg now "$now" '{
        version: 2, generated_at: $now, scope: {kind: "repository", repository: "fixture-repo", local: false},
        capacity: {active: 0, limit: 3, over_limit: false},
        waiting: {rows: [], hidden_lines: [], degraded: null},
        focus: {name: "fixture-repo", entry: {path: "/ws/fixture-repo", status: "idle", relative_activity: "2h ago"},
                checkpoints: [$cp], checkpoint_head: "tl;dr: Built the widget and merged #12.\n\n## 1. Goal\n- x",
                since: {head_moves: 3}, assimilated: [], directives: [], plan: null,
                identity: {kind: "checkout", branch: "main", worktree_of: ""}}
    }' > "$MOCK_DOC"
}

# _input <source> [session_title] [cwd]: a real SessionStart input.
_input() {
    jq -nc --arg src "$1" --arg title "${2:-}" --arg cwd "${3:-$HOME/dev/fixture-repo}" \
        '{session_id: "s1", cwd: $cwd, hook_event_name: "SessionStart", source: $src}
         + (if $title == "" then {} else {session_title: $title} end)'
}

_run_hook() { run bash -c '"$0" <<< "$1"' "$HOOK" "$1"; }

@test "AC1: a startup input yields a top-level systemMessage with the four lines" {
    _run_hook "$(_input startup)"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.systemMessage | test("last time") and test("next") and test("watch out") and test("since then")'
    echo "$output" | jq -e '.systemMessage | test("HEAD moved 3 times")'
}

@test "AC1: the same case fails against an empty hook body" {
    printf '#!/usr/bin/env bash\nexit 0\n' > "${BATS_TEST_TMPDIR}/empty.sh"
    chmod +x "${BATS_TEST_TMPDIR}/empty.sh"
    run bash -c '"$0" <<< "$1"' "${BATS_TEST_TMPDIR}/empty.sh" "$(_input startup)"
    ! echo "$output" | jq -e '.systemMessage | test("last time")'
}

@test "AC1: every brief line fits 98 columns" {
    _run_hook "$(_input resume)"
    echo "$output" | jq -r '.systemMessage' | while IFS= read -r line; do
        [ "${#line}" -le 98 ]
    done
}

@test "AC2: a resume with a title already set emits no sessionTitle" {
    _run_hook "$(_input resume kept)"
    [ "$status" -eq 0 ]
    run bash -c 'printf "%s" "$0" | jq -e ".hookSpecificOutput.sessionTitle // empty"' "$output"
    [ "$status" -eq 4 ]
    [ -z "$output" ]
}

@test "AC2: an empty title emits the directory name as sessionTitle" {
    _run_hook "$(_input startup)"
    [ "$(echo "$output" | jq -r '.hookSpecificOutput.sessionTitle')" = "fixture-repo" ]
    [ "$(echo "$output" | jq -r '.hookSpecificOutput.hookEventName')" = "SessionStart" ]
}

@test "AC3: clear, compact and fork print nothing and exit 0" {
    for source in clear compact fork; do
        _run_hook "$(_input "$source")"
        [ "$status" -eq 0 ]
        [ -z "$output" ]
    done
    [ ! -s "$MOCK_LOG" ]
}

@test "AC4: exactly one borg call, link <repo> --json, and no git process" {
    _run_hook "$(_input startup)"
    [ "$status" -eq 0 ]
    [ "$(wc -l < "$MOCK_LOG" | tr -d ' ')" = "1" ]
    [ "$(cat "$MOCK_LOG")" = "link fixture-repo --json" ]
    [ ! -e "$GIT_LOG" ]
    echo "$output" | jq -e '.systemMessage | test("last time")'
}

@test "AC4: a .borg-project marker names the repository passed to borg link" {
    printf 'registered-name\n' > "$HOME/dev/fixture-repo/.borg-project"
    _run_hook "$(_input startup)"
    [ "$(cat "$MOCK_LOG")" = "link registered-name --json" ]
}

@test "AC5: the Queen session gets the one verdict line, no title, and the registry is untouched" {
    printf '{"repositories":{"a":{"path":"/x"}}}\n' > "$BORG_REGISTRY"
    local before after
    before=$(shasum "$BORG_REGISTRY")
    _run_hook "$(_input startup "" "$HOME/dev")"
    after=$(shasum "$BORG_REGISTRY")
    [ "$before" = "$after" ]
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.systemMessage')" = "▶ merge #440 · fixture-repo · 4 waiting" ]
    echo "$output" | jq -e '.systemMessage | contains("\n") | not'
    echo "$output" | jq -e 'has("hookSpecificOutput") | not'
    [ "$(cat "$MOCK_LOG")" = "next --line" ]
    [ ! -e "$GIT_LOG" ]
}

@test "AC5: a custom BORG_ORCHESTRATOR_ROOT classifies the Queen, with or without a trailing slash" {
    export BORG_ORCHESTRATOR_ROOT="${BATS_TEST_TMPDIR}/ws"
    mkdir -p "$BORG_ORCHESTRATOR_ROOT"
    _run_hook "$(_input startup "" "$BORG_ORCHESTRATOR_ROOT/")"
    [ "$(cat "$MOCK_LOG")" = "next --line" ]
}

@test "AC6: a failing borg is a one-line unavailable message and exit 0" {
    MOCK_FAIL=1 _run_hook "$(_input startup)"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.systemMessage | length > 0 and contains("unavailable") and (contains("\n") | not)'
    MOCK_FAIL=1 _run_hook "$(_input startup "" "$HOME/dev")"
    echo "$output" | jq -e '.systemMessage | contains("unavailable")'
}

@test "AC6: a document that is not JSON is unavailable, not a crash" {
    printf 'not json' > "$MOCK_DOC"
    _run_hook "$(_input resume)"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.systemMessage | contains("unavailable")'
}

@test "AC6: an unusable borg_core is loud, not silent" {
    run env -i HOME="$HOME" PATH="/usr/bin:/bin" BORG_ROOT="${BATS_TEST_TMPDIR}/nowhere" \
        bash -c 'mkdir -p "$0/hooks" && cp "$1" "$0/hooks/" && "$0/hooks/borg-arrival-brief.sh" <<< "$2"' \
        "${BATS_TEST_TMPDIR}/lonely" "$HOOK" "$(_input startup)"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.systemMessage | contains("unavailable")'
}

@test "BORG_NO_SESSION_HOOKS=1 opts out silently" {
    BORG_NO_SESSION_HOOKS=1 _run_hook "$(_input startup)"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "latency: the hook's own overhead, with a mocked borg, is under 500 ms at p95 over 20 runs" {
    run python3 - "$HOOK" "$(_input startup)" <<'PY'
import subprocess, sys, time
hook, payload = sys.argv[1], sys.argv[2]
samples = []
for _ in range(20):
    start = time.monotonic()
    subprocess.run([hook], input=payload, text=True, capture_output=True, check=True)
    samples.append(time.monotonic() - start)
samples.sort()
print(int(samples[18] * 1000))
PY
    [ "$status" -eq 0 ]
    [ "$output" -lt 500 ]
}

@test "parity: session mode and repository name agree with the shell functions in lib/borg-hooks.sh" {
    local root="${BATS_TEST_TMPDIR}/ws" cwd
    mkdir -p "$root/proj/sub"
    printf 'marked\n' > "$root/proj/.borg-project"
    for cwd in "$root" "$root/" "$root/proj" "$root/proj/sub" "${root}x" "/"; do
        local shell_mode py_mode shell_repo py_repo
        shell_mode=$(BORG_ORCHESTRATOR_ROOT="$root" bash -c 'source "$1"; _borg_session_mode "$2"' _ "${BATS_TEST_DIRNAME}/../lib/borg-hooks.sh" "$cwd")
        py_mode=$(BORG_ORCHESTRATOR_ROOT="$root" PYTHONPATH="${BATS_TEST_DIRNAME}/.." python3 -c 'import sys; from borg_core.link import arrival; print(arrival.session_mode(sys.argv[1], sys.argv[2]))' "$cwd" "$root")
        [ "$shell_mode" = "$py_mode" ]
        [ "$cwd" = "/" ] && continue
        shell_repo=$(bash -c 'source "$1"; _borg_find_repository "$2"' _ "${BATS_TEST_DIRNAME}/../lib/borg-hooks.sh" "${cwd%/}")
        py_repo=$(PYTHONPATH="${BATS_TEST_DIRNAME}/.." python3 -c 'import sys; from borg_core.link import arrival_hook; print(arrival_hook.find_repository(sys.argv[1]))' "${cwd%/}")
        [ "$shell_repo" = "$py_repo" ]
    done
}

@test "AC3/AC7: build-plugin.sh registers the hook for startup|resume only" {
    run bash -c 'sed -n "/^HOOKS_JSON=/,/^}.$/p" "$0" | sed -e "1s/^HOOKS_JSON=.//" -e "\$s/.\$//" | jq -e "[.hooks.SessionStart[] | select(.hooks[].command | test(\"borg-arrival-brief\"))] | length == 1 and .[0].matcher == \"startup|resume\""' "$BUILD"
    [ "$status" -eq 0 ]
}

@test "AC7: the build ships the hook executable beside hooks.json" {
    local plugin="${BATS_TEST_TMPDIR}/plugin/borg-collective"
    mkdir -p "$plugin"
    PLUGIN_DIR_OVERRIDE="$plugin" run bash "$BUILD"
    [ "$status" -eq 0 ]
    test -x "$plugin/hooks/borg-arrival-brief.sh"
    jq -e '[.hooks.SessionStart[] | select(.hooks[].command | test("borg-arrival-brief"))] | length == 1 and .[0].matcher == "startup|resume"' "$plugin/hooks/hooks.json"
}
