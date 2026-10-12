#!/usr/bin/env bats
# THE ORACLE FOR evals/session-load/ (directive 2026-09-02-session-load-eval-skill-registration-and-hooks,
# SL3). The harness needs a model to start a real session, so it cannot gate CI; its FLOORS can, because
# they run on a canned stream-json that stands in for what a session reported. Each of the four surfaces
# the 31 unit cases cannot see is checked FIRING (a planted duplicate turns it red, both counts named) and
# HOLDING (the clean shape stays green), because a floor asserted in one direction passes just as well for
# a checker that always fails or always passes:
#
#   1 two versioned plugin dirs        2 plugin skill + extension symlink of the same name
#   3 one logical event firing twice    4 a literal-path hook entry beside the plugin's
#
# Hermetic: no claude, no network, HOME and XDG_CONFIG_HOME both redirected by setup_temp_dirs. The
# end-to-end cases hand run.sh a stub claude via BORG_EVAL_CLAUDE and an evidence tree via BORG_EVAL_REPO.
# Every `[[ ]]` ends in `|| false` (bash 3.2 does not honour errexit on a bare one).

load test_helper/setup

setup() {
    setup_temp_dirs
    CHECK="$BORG_HOME/evals/session-load/check.py"
    CH="$BATS_TEST_TMPDIR/claude-home"
    mkdir -p "$CH/skills"
}

# _events <plugin-count> <extra-bare-skill|-> <session-starts> <stops> > file
_events() {
    local plugins="$1" bare="$2" starts="$3" stops="$4" s i
    printf '{"type":"system","subtype":"init","skills":['
    for s in "$BORG_HOME"/skills/*/SKILL.md; do
        if sed -n '2,/^---$/p' "$s" | grep -q 'user-invocable: false'; then continue; fi
        s="${s%/SKILL.md}"; s="${s##*/}"
        printf '"borg-collective:%s",' "$s"
    done
    if [ "$bare" != "-" ]; then printf '"%s",' "$bare"; fi
    printf '"other:x"],"plugins":['
    for ((i = 1; i <= plugins; i++)); do
        if [ "$i" -gt 1 ]; then printf ','; fi
        printf '{"name":"borg-collective","path":"%s/none%s"}' "$BATS_TEST_TMPDIR" "$i"
    done
    printf ']}\n'
    for ((i = 0; i < starts; i++)); do printf '{"type":"system","subtype":"hook_started","hook_event":"SessionStart"}\n'; done
    for ((i = 0; i < stops; i++)); do printf '{"type":"system","subtype":"hook_started","hook_event":"Stop"}\n'; done
}

_check() {
    run python3 -I "$CHECK" --events "$1" --repo "$BORG_HOME" --claude-home "$CH"
}

@test "surface 1 fires: a second versioned plugin dir is red with both counts" {
    _events 2 - 2 2 > "$BATS_TEST_TMPDIR/e.jsonl"
    _check "$BATS_TEST_TMPDIR/e.jsonl"
    [ "$status" -eq 1 ]
    [[ "$output" == *"plugin borg-collective: observed 2 of 1 authored"* ]] || false
}

@test "surface 1 holds: one plugin dir is green, 'skills: observed N of N authored'" {
    _events 1 - 2 2 > "$BATS_TEST_TMPDIR/e.jsonl"
    _check "$BATS_TEST_TMPDIR/e.jsonl"
    [ "$status" -eq 0 ]
    [[ "$output" == *"CHECK pass skills plugin borg-collective: loaded once"* ]] || false
    [[ "$output" == *"CHECK pass skills skills: observed "* ]] || false
}

@test "surface 2 fires: an extension symlink colliding with a plugin skill is registered twice" {
    ln -s "$BORG_HOME/skills/borg-plan" "$CH/skills/borg-plan"
    _events 1 borg-plan 2 2 > "$BATS_TEST_TMPDIR/e.jsonl"
    _check "$BATS_TEST_TMPDIR/e.jsonl"
    [ "$status" -eq 1 ]
    [[ "$output" == *"skill borg-plan: surplus, observed 2 of 1 authored"* ]] || false
}

@test "surface 2 holds: the bundled bare simplify with no symlink is not a collision" {
    _events 1 simplify 2 2 > "$BATS_TEST_TMPDIR/e.jsonl"
    _check "$BATS_TEST_TMPDIR/e.jsonl"
    [ "$status" -eq 0 ]
}

@test "surface 3 fires: one logical event executing twice is red with both counts" {
    _events 1 - 3 2 > "$BATS_TEST_TMPDIR/e.jsonl"
    _check "$BATS_TEST_TMPDIR/e.jsonl"
    [ "$status" -eq 1 ]
    [[ "$output" == *"hooks SessionStart: surplus, fired 3 of 2 authored"* ]] || false
}

@test "surface 3 holds: exactly the authored count per event is green; a missing hook is a named shortfall" {
    _events 1 - 2 2 > "$BATS_TEST_TMPDIR/e.jsonl"
    _check "$BATS_TEST_TMPDIR/e.jsonl"
    [ "$status" -eq 0 ]
    _events 1 - 2 1 > "$BATS_TEST_TMPDIR/s.jsonl"
    _check "$BATS_TEST_TMPDIR/s.jsonl"
    [ "$status" -eq 1 ]
    [[ "$output" == *"hooks Stop: shortfall, fired 1 of 2 authored"* ]] || false
}

@test "surface 4 fires: a literal-path hook entry in settings.json beside the plugin's is named" {
    printf '%s\n' '{"hooks":{"SessionStart":[{"matcher":"","hooks":[{"type":"command","command":"/h/.claude/hooks/borg-link-down.sh"}]}]}}' \
        > "$CH/settings.json"
    _events 1 - 3 2 > "$BATS_TEST_TMPDIR/e.jsonl"
    _check "$BATS_TEST_TMPDIR/e.jsonl"
    [ "$status" -eq 1 ]
    [[ "$output" == *"fired 3 of 2 authored"* ]] || false
    [[ "$output" == *"borg-link-down.sh"* ]] || false
}

@test "surface 4 holds: a non-borg settings.json hook is baseline, not a surplus" {
    printf '%s\n' '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"/h/session-log.sh"}]}]}}' > "$CH/settings.json"
    _events 1 - 2 3 > "$BATS_TEST_TMPDIR/e.jsonl"
    _check "$BATS_TEST_TMPDIR/e.jsonl"
    [ "$status" -eq 0 ]
}

@test "AUTHORED_HOOKS matches the commands build-plugin.sh writes for SessionStart and Stop" {
    run python3 -I -c '
import re, sys
sys.path.insert(0, sys.argv[1] + "/evals/session-load")
import check
src = open(sys.argv[1] + "/scripts/build-plugin.sh").read()
for event, n in check.AUTHORED_HOOKS.items():
    m = re.search(r"\"%s\": \[(.*?)\n    \]" % event, src, re.S)
    assert m, event
    got = len(re.findall(r"\"command\":", m.group(1)))
    assert got == n, (event, got, n)
print("ok")' "$BORG_HOME"
    [ "$status" -eq 0 ]
}

_stub_claude() {
    local file="$1"
    printf '#!/bin/sh\ncat "%s"\n' "$file" > "$BATS_TEST_TMPDIR/claude"
    chmod +x "$BATS_TEST_TMPDIR/claude"
}

_sandbox_repo() {
    local sb="$BATS_TEST_TMPDIR/repo" e
    mkdir -p "$sb"
    for e in "$BORG_HOME"/*; do
        if [ "${e##*/}" != evals ]; then ln -sfn "$e" "$sb/${e##*/}"; fi
    done
    printf '%s\n' "$sb"
}

_live() {
    run env BORG_EVAL_REPO="$(_sandbox_repo)" BORG_EVAL_CLAUDE="$1" BORG_EVAL_CLAUDE_HOME="$CH" \
        bash "$BORG_HOME/evals/session-load/run.sh" "${@:2}"
}

@test "run.sh live: a clean canned session exits 0; a planted duplicate exits 1 with both counts" {
    _events 1 - 2 2 > "$BATS_TEST_TMPDIR/clean.jsonl"
    _stub_claude "$BATS_TEST_TMPDIR/clean.jsonl"
    _live "$BATS_TEST_TMPDIR/claude"
    [ "$status" -eq 0 ]
    _events 2 - 2 2 > "$BATS_TEST_TMPDIR/dup.jsonl"
    _stub_claude "$BATS_TEST_TMPDIR/dup.jsonl"
    _live "$BATS_TEST_TMPDIR/claude"
    [ "$status" -eq 1 ]
    [[ "$output" == *"observed 2 of 1 authored"* ]] || false
}

@test "run.sh live: an absent resolved CLI SKIPs naming it, and the mode floor fails the run" {
    _live "$BATS_TEST_TMPDIR/no-such-claude"
    [ "$status" -eq 1 ]
    [[ "$output" == *"SKIP  LIVE: resolved claude CLI '$BATS_TEST_TMPDIR/no-such-claude' not found"* ]] || false
    [[ "$output" == *"CHECKER"* ]] || false
}

@test "run.sh live: --skills-only grades no hooks and --hooks-only grades no skills" {
    _events 1 - 2 2 > "$BATS_TEST_TMPDIR/clean.jsonl"
    _stub_claude "$BATS_TEST_TMPDIR/clean.jsonl"
    _live "$BATS_TEST_TMPDIR/claude" --skills-only
    [ "$status" -eq 0 ]
    [[ "$output" != *"hooks SessionStart"* ]] || false
    _live "$BATS_TEST_TMPDIR/claude" --hooks-only
    [ "$status" -eq 0 ]
    [[ "$output" != *"plugin borg-collective"* ]] || false
}

@test "run.sh live: a session that reports nothing gradeable is premise broken, not green" {
    printf '{"type":"result"}\n' > "$BATS_TEST_TMPDIR/empty.jsonl"
    _stub_claude "$BATS_TEST_TMPDIR/empty.jsonl"
    _live "$BATS_TEST_TMPDIR/claude"
    [ "$status" -eq 1 ]
    [[ "$output" == *"premise broken"* ]] || false
}

@test "run.sh pins its model tier explicitly at the claude -p site" {
    run grep -E -- '-p .*--model' "$BORG_HOME/evals/session-load/run.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"--effort"* ]] || false
}
