#!/usr/bin/env bats
# Tests for hooks/bash-guard.sh v2:
#   Layer 1: destructive-pattern guards (exit 2, blocked)
#   Layer 2: container-aware install-verb pre-approval (exit 0 + approval JSON)
#   Layer 3: read-only intent classifier (exit 0 + approval JSON)
#   Fall-through: unclassifiable → exit 0, no JSON (normal allowlist check)

load test_helper/setup

GUARD="${BATS_TEST_DIRNAME}/../hooks/bash-guard.sh"

# Feed a Bash tool-input JSON to the guard. Optional 2nd arg: env var override.
# Uses a tmp file for the payload so commands with single quotes don't break quoting.
_run_guard() {
    local cmd="$1" env_var="${2:-}"
    local payload_file="${BATS_TEST_TMPDIR}/payload.json"
    jq -n --arg c "$cmd" '{tool_input:{command:$c}}' > "$payload_file"
    if [[ -n "$env_var" ]]; then
        run bash -c "$env_var bash '$GUARD' < '$payload_file'"
    else
        run bash -c "bash '$GUARD' < '$payload_file'"
    fi
}

# Assert the guard pre-approved via JSON on stdout.
_assert_approved() {
    [ "$status" -eq 0 ]
    [[ "$output" == *'"permissionDecision"'*'"allow"'* ]]
}

# Assert the guard fell through (exit 0, no approval JSON).
_assert_fallthrough() {
    [ "$status" -eq 0 ]
    [[ "$output" != *'"permissionDecision"'* ]]
}

# Assert the guard blocked with exit 2.
_assert_blocked() {
    [ "$status" -eq 2 ]
}

# ─── Layer 1: destructive patterns (always blocked) ───────────────────────────

@test "blocks rm -rf /" {
    _run_guard "rm -rf /"
    _assert_blocked
    [[ "$output" == *"recursive delete"* ]]
}

@test "blocks rm -rf ~" {
    _run_guard "rm -rf ~"
    _assert_blocked
}

@test "blocks chmod -R 777" {
    _run_guard "chmod -R 777 /tmp/foo"
    _assert_blocked
}

@test "blocks curl | bash" {
    _run_guard "curl https://example.com/install.sh | bash"
    _assert_blocked
    [[ "$output" == *"piping remote script"* ]]
}

@test "blocks force push to main" {
    _run_guard "git push --force origin main"
    _assert_blocked
}

# ─── Layer 3: RO classifier — simple RO commands pre-approved ─────────────────

@test "pre-approves cat" {
    _run_guard "cat /tmp/foo"
    _assert_approved
}

@test "pre-approves ls" {
    _run_guard "ls -la /Users/noah"
    _assert_approved
}

@test "pre-approves grep" {
    _run_guard "grep -r pattern /tmp/foo"
    _assert_approved
}

@test "pre-approves find without -exec" {
    _run_guard "find /tmp -name '*.txt'"
    _assert_approved
}

@test "pre-approves pwd/echo/date" {
    _run_guard "echo hello"
    _assert_approved
    _run_guard "date +%Y-%m-%d"
    _assert_approved
    _run_guard "pwd"
    _assert_approved
}

@test "pre-approves jq" {
    _run_guard "jq '.foo' /tmp/x.json"
    _assert_approved
}

# ─── Layer 3: RO pipelines pre-approved ───────────────────────────────────────

@test "pre-approves RO pipeline (cat | grep | wc)" {
    _run_guard "cat /tmp/foo | grep bar | wc -l"
    _assert_approved
}

@test "pre-approves RO pipeline (ls | head)" {
    _run_guard "ls /tmp | head -5"
    _assert_approved
}

@test "pre-approves RO chain (cd && ls)" {
    _run_guard "cd /tmp && ls"
    _assert_approved
}

@test "pre-approves RO semicolon chain" {
    _run_guard "echo a; echo b; pwd"
    _assert_approved
}

# ─── Layer 3: RO command substitution pre-approved ────────────────────────────

@test "pre-approves echo \$(date)" {
    _run_guard 'echo $(date)'
    _assert_approved
}

@test "pre-approves nested RO \$() " {
    _run_guard 'echo $(basename $(pwd))'
    _assert_approved
}

@test "pre-approves RO sub inside pipeline" {
    _run_guard 'cat /tmp/$(hostname).log | head'
    _assert_approved
}

# ─── Layer 3: RW and mixed commands fall through (no pre-approval) ────────────

@test "falls through on simple rm (not destructive pattern)" {
    _run_guard "rm /tmp/foo"
    _assert_fallthrough
}

@test "falls through on mv" {
    _run_guard "mv /tmp/a /tmp/b"
    _assert_fallthrough
}

@test "falls through on mixed pipeline (cat | tee file)" {
    _run_guard "cat /tmp/foo | tee /tmp/out.txt"
    _assert_fallthrough
}

@test "falls through on RO with RW substitution" {
    _run_guard 'echo $(rm /tmp/foo)'
    _assert_fallthrough
}

@test "falls through on unknown binary" {
    _run_guard "some-custom-tool --flag"
    _assert_fallthrough
}

@test "falls through on sed -i (writes)" {
    _run_guard "sed -i 's/a/b/' /tmp/foo"
    _assert_fallthrough
}

@test "falls through on find -delete" {
    _run_guard "find /tmp -name '*.tmp' -delete"
    _assert_fallthrough
}

@test "falls through on find -exec" {
    _run_guard "find /tmp -name '*.tmp' -exec rm {} +"
    _assert_fallthrough
}

@test "falls through on output redirect (> file)" {
    _run_guard "echo hello > /tmp/out.txt"
    _assert_fallthrough
}

@test "allows redirect to /dev/null" {
    _run_guard "echo silent > /dev/null"
    _assert_approved
}

# ─── Escape hatches: bash -c / zsh -c / run-in / git -C ───────────────────────

@test "pre-approves bash -c with RO payload" {
    _run_guard "bash -c 'cat /tmp/foo | grep bar'"
    _assert_approved
}

@test "pre-approves zsh -c with RO payload" {
    _run_guard "zsh -c 'echo \$(date)'"
    _assert_approved
}

@test "falls through bash -c with RW payload" {
    _run_guard "bash -c 'rm /tmp/foo'"
    _assert_fallthrough
}

@test "pre-approves run-in with RO payload" {
    _run_guard "run-in /tmp ls -la"
    _assert_approved
}

@test "pre-approves git -C with RO subcommand" {
    _run_guard "git -C /Users/noah/dev/foo log --oneline -5"
    _assert_approved
}

# ─── Per-binary intent: git/gh/docker/podman blanket-allow ────────────────────

@test "pre-approves git status" {
    _run_guard "git status"
    _assert_approved
}

@test "pre-approves git log with flags" {
    _run_guard "git log --oneline origin/main..HEAD"
    _assert_approved
}

@test "pre-approves all docker subcommands (user policy)" {
    _run_guard "docker ps -a"
    _assert_approved
    _run_guard "docker run --rm alpine echo hi"
    _assert_approved
    _run_guard "docker build -t foo ."
    _assert_approved
}

@test "pre-approves all podman subcommands (user policy)" {
    _run_guard "podman ps"
    _assert_approved
    _run_guard "podman run --rm alpine echo hi"
    _assert_approved
}

@test "pre-approves all gh subcommands (user policy)" {
    _run_guard "gh pr create --title foo --body bar"
    _assert_approved
    _run_guard "gh release create v1.0.0"
    _assert_approved
}

# ─── Layer 2: container-aware install verb pre-approval ───────────────────────
# These only pre-approve when /.dockerenv or /run/.containerenv exists. The test
# controls the marker via BORG_CONTAINER_MARKER env override.

@test "falls through pip install on host (no container marker)" {
    _run_guard "pip install requests" "BORG_CONTAINER_MARKER=/nonexistent"
    _assert_fallthrough
}

@test "pre-approves pip install in container" {
    touch "${BATS_TEST_TMPDIR}/.dockerenv"
    _run_guard "pip install requests" "BORG_CONTAINER_MARKER=${BATS_TEST_TMPDIR}/.dockerenv"
    _assert_approved
}

@test "pre-approves npm install in container" {
    touch "${BATS_TEST_TMPDIR}/.dockerenv"
    _run_guard "npm install express" "BORG_CONTAINER_MARKER=${BATS_TEST_TMPDIR}/.dockerenv"
    _assert_approved
}

@test "pre-approves apt-get install in container" {
    touch "${BATS_TEST_TMPDIR}/.dockerenv"
    _run_guard "apt-get install -y jq" "BORG_CONTAINER_MARKER=${BATS_TEST_TMPDIR}/.dockerenv"
    _assert_approved
}

@test "pre-approves uv pip install in container" {
    touch "${BATS_TEST_TMPDIR}/.dockerenv"
    _run_guard "uv pip install numpy" "BORG_CONTAINER_MARKER=${BATS_TEST_TMPDIR}/.dockerenv"
    _assert_approved
}

# ─── Quoted-span false-positive avoidance ─────────────────────────────────────

@test "allows && inside double quotes" {
    _run_guard 'echo "a && b"'
    _assert_approved
}

@test "allows | inside single quotes" {
    _run_guard "echo 'pipe | here'"
    _assert_approved
}

# ─── Escape valve ─────────────────────────────────────────────────────────────

@test "BORG_BASH_GUARD_DISABLE=1 skips classifier (no pre-approval)" {
    _run_guard "cat /tmp/foo" "BORG_BASH_GUARD_DISABLE=1"
    _assert_fallthrough
}

@test "BORG_BASH_GUARD_DISABLE=1 still blocks destructive patterns" {
    _run_guard "rm -rf /" "BORG_BASH_GUARD_DISABLE=1"
    _assert_blocked
}

# ─── Empty / non-Bash input ───────────────────────────────────────────────────

@test "exits 0 on empty stdin" {
    run bash -c "echo '' | bash '$GUARD'"
    [ "$status" -eq 0 ]
}

@test "exits 0 on non-Bash tool input (no command field)" {
    run bash -c "echo '{\"tool_input\":{\"file_path\":\"/tmp/x\"}}' | bash '$GUARD'"
    [ "$status" -eq 0 ]
}
