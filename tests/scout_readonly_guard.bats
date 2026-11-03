#!/usr/bin/env bats
# Tier 1 table for hooks/scout-readonly-guard.sh — PreToolUse (Bash): borg-scout gets read-only Bash through an
# allowlist; every other agent_type passes through untouched. Rows are "command" lines in the three tables below.

load test_helper/setup

HOOK="${BATS_TEST_DIRNAME}/../hooks/scout-readonly-guard.sh"
BUILD_PLUGIN="${BATS_TEST_DIRNAME}/../scripts/build-plugin.sh"
SCOUT_MD="${BATS_TEST_DIRNAME}/../agents/borg-scout.md"
BASH_BIN="${BASH_BIN:-/bin/bash}"

setup() {
    setup_temp_dirs
    [ -x "$BASH_BIN" ] || BASH_BIN="$(command -v bash)"
}

# _run_cmd <agent_type> <command>   (sets $status/$output; stderr merged)
_run_cmd() {
    local json
    json=$(jq -nc --arg at "$1" --arg c "$2" '{tool_name:"Bash", agent_type:$at, tool_input:{command:$c}}')
    run bash -c "printf '%s' \"\$1\" | '$BASH_BIN' '$HOOK' 2>&1" _ "$json"
}

_allow() {
    _run_cmd "${2:-borg-collective:borg-scout}" "$1"
    [ "$status" -eq 0 ] || { echo "expected ALLOW: $1 -> $status $output"; false; }
}

_deny() {
    _run_cmd "${2:-borg-collective:borg-scout}" "$1"
    [ "$status" -eq 2 ] || { echo "expected DENY: $1 -> $status $output"; false; }
    [[ "$output" == *"borg scout guard"* ]] || false
}

@test "table: allowed commands" {
    local rows=(
        'git log --oneline -5'
        'git show HEAD~1 --stat'
        'git diff a..b | head'
        'git diff main...HEAD --stat | wc -l'
        'git status --short'
        'git rev-parse --show-toplevel'
        'git ls-files docs'
        'git ls-remote --heads origin'
        'git grep -n foo -- hooks'
        'git blame -L 1,5 README.md'
        'git branch --list'
        'git branch --list "feat/*"'
        'git -C /Users/me/repo log --oneline -3'
        'git --no-pager log -1 --format=%H'
        'gh pr view 5 --json title'
        'gh pr view 5 --json title --jq .title'
        'gh pr list --state merged --limit 5'
        'gh pr checks 5'
        'gh pr diff 5 | head -50'
        'gh issue view 502'
        'gh issue list --label bug'
        'gh search prs "scout" --repo a/b'
        'gh api repos/a/b/pulls/5'
        'gh api repos/a/b/pulls/5 --method GET --jq .title'
        'gh api -X GET repos/a/b/issues'
        'gh api repos/a/b/pulls --paginate --jq ".[].number"'
        'jq .a file.json'
        'jq -r ".[] | .b" f.json'
        "jq -r '.[] | select(.a == \"x;y && z\")' f.json"
        "rg -n 'foo;bar|baz' src"
        "grep -rn 'a && b' docs | head -20"
        'grep -o foo file | sort | uniq -c | sort -rn | head'
        'head -n 5 f'
        'tail -n 20 f'
        'wc -l f'
        'ls -la /tmp'
        'cat README.md'
        'sort -u f'
        'uniq f'
        'cut -d, -f1 f'
        'find . -name "*.md" -type f'
        'find hooks -maxdepth 1 -name "*.sh" | sort'
    )
    local r bad=""
    for r in "${rows[@]}"; do
        _run_cmd borg-collective:borg-scout "$r"
        [ "$status" -eq 0 ] || bad="$bad"$'\n'"  $r -> $status $output"
    done
    [ -z "$bad" ] || { echo "wrongly denied:$bad"; false; }
}

@test "table: denied commands" {
    local rows=(
        'git push'
        'git push origin main'
        'git commit -m x'
        'git checkout main'
        'git branch newbranch'
        'git branch -D x'
        'git log > f'
        'git log >> f'
        'git log; rm x'
        'git log && rm x'
        'git log || rm x'
        'git log & rm x'
        'echo $(id)'
        'git log $(id)'
        'git log `id`'
        'git log "$(id)"'
        'git log "`id`"'
        'git log $HOME'
        'git log "$HOME"'
        'rm x'
        'gh pr merge 5'
        'gh pr create'
        'gh pr close 5'
        'gh pr comment 5 --body x'
        'gh issue create'
        'gh pr view 5 --web'
        'gh api -X POST repos/x/y/issues'
        'gh api --method DELETE repos/x/y'
        'gh api --method=DELETE repos/x/y'
        'gh api -XDELETE repos/x/y'
        'gh api --method PATCH repos/x/y'
        'gh api repos/x/y -f title=x'
        'gh api repos/x/y -F title=x'
        'gh api repos/x/y --field title=x'
        'gh api repos/x/y --raw-field title=x'
        'gh api repos/x/y --input f.json'
        'gh api repos/x/y -H "X-HTTP-Method-Override: DELETE"'
        'gh api https://evil.example/x'
        'gh api repos/x/y --hostname evil.example'
        'git -c core.pager=sh log'
        'git -c core.pager="sh -c id" log'
        'git --git-dir=/x log'
        'git --exec-path=/x log'
        'git log --output=f'
        'git log --outp=f'
        'git diff --output f'
        'git show -o f'
        'git diff --no-index a b'
        'git diff --ext-diff'
        'git grep -O foo'
        'git grep --open-files-in-pager=sh foo'
        'git ls-remote --upload-pack=id origin'
        'git ls-remote ext::sh'
        'env X=y git log'
        'X=y git log'
        'xargs rm'
        'git log | xargs rm'
        'git log | tee f'
        'tee f'
        'sed -i s/a/b/ f'
        'sed -n 1p f'
        'awk 1 f'
        'git log
rm x'
        'git log | head
rm x'
        'bash -c id'
        'sh -c id'
        'eval ls'
        'sort -o f g'
        'sort --output=f g'
        'sort -ro f g'
        'sort --compress-program=sh g'
        'uniq a b'
        'tail -f f'
        'rg --pre sh foo'
        'rg --hostname-bin sh foo'
        'find . -delete'
        'find . -exec rm {} +'
        'find . -execdir rm {} +'
        'find . -ok rm {} ;'
        'find . -okdir rm {} ;'
        'find . -fprint f'
        'find . -fprintf f %p'
        'find . -fls f'
        'cat f > g'
        'cat < f'
        'cat <(ls)'
        'git log |& cat'
        'ls ; ls'
        '/bin/ls'
        '/usr/bin/git log'
        'git log "unterminated'
        "git log 'unterminated"
        'ls {a,b}'
        'ls ~/x'
        'ls *'
        '*'
        '(ls)'
        'ls #x'
        'ugrep foo'
        'bfs . -name x'
        'curl https://x'
        'python3 -c 1'
        ''
        '|'
        'ls |'
        'ls \; id'
    )
    local r bad=""
    for r in "${rows[@]}"; do
        _run_cmd borg-collective:borg-scout "$r"
        [ "$status" -eq 2 ] || bad="$bad"$'\n'"  [$r] -> $status $output"
    done
    [ -z "$bad" ] || { echo "wrongly allowed:$bad"; false; }
}

@test "the bare borg-scout agent_type is gated too" {
    _deny 'git push' borg-scout
    _allow 'git log -1' borg-scout
}

@test "pass-through: every other agent_type is untouched" {
    local t
    for t in borg-collective:borg-grunt borg-grunt borg-collective:borg-verifier borg-collective:borg-nanoprobe \
        general-purpose scoutish; do
        _allow 'git push' "$t"
        _allow 'rm -rf x; echo $(id) > f' "$t"
    done
}

@test "pass-through: a payload with no agent_type (the main session) is untouched" {
    run bash -c "printf '%s' '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git push\"}}' | '$BASH_BIN' '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "a tool other than Bash is not this hook's business" {
    run bash -c "printf '%s' '{\"tool_name\":\"Read\",\"agent_type\":\"borg-scout\",\"tool_input\":{\"file_path\":\"x\"}}' | '$BASH_BIN' '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "a scout payload with a missing command denies" {
    run bash -c "printf '%s' '{\"tool_name\":\"Bash\",\"agent_type\":\"borg-scout\",\"tool_input\":{}}' | '$BASH_BIN' '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
}

@test "an unparseable payload that names the scout denies; one that does not is allowed" {
    run bash -c "printf '%s' 'borg-scout not json' | '$BASH_BIN' '$HOOK' 2>&1"
    [ "$status" -eq 2 ]
    run bash -c "printf '%s' 'not json' | '$BASH_BIN' '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "missing python3 denies the scout and allows everyone else" {
    local bin="${BATS_TEST_TMPDIR}/nopy"
    mkdir -p "$bin"
    local v='{"tool_name":"Bash","agent_type":"borg-collective:borg-scout","tool_input":{"command":"git log"}}'
    local o='{"tool_name":"Bash","agent_type":"borg-collective:borg-grunt","tool_input":{"command":"git push"}}'
    run env PATH="$bin" "$BASH_BIN" -c "printf '%s' '$v' | '$BASH_BIN' '$HOOK'"
    [ "$status" -eq 2 ]
    run env PATH="$bin" "$BASH_BIN" -c "printf '%s' '$o' | '$BASH_BIN' '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "BORG_SCOUT_GUARD=0 disables the guard" {
    export BORG_SCOUT_GUARD=0
    _allow 'git push'
}

# --- wiring --------------------------------------------------------------------------------------

@test "wiring: build-plugin.sh copies the hook and registers it on a Bash PreToolUse matcher" {
    grep -qE '_build_self_contained_hook .*scout-readonly-guard\.sh' "$BUILD_PLUGIN"
    run grep -B5 -A2 'hooks/scout-readonly-guard.sh"' "$BUILD_PLUGIN"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"matcher": "Bash"'* ]] || false
}

@test "roster: the scout never ships Bash without the guard" {
    if grep -qE '^tools:.*\bBash\b' "$SCOUT_MD"; then
        grep -q 'hooks/scout-readonly-guard.sh"' "$BUILD_PLUGIN"
    fi
}

@test "roster: the guard is never registered for a scout that has no Bash" {
    if grep -q 'hooks/scout-readonly-guard.sh"' "$BUILD_PLUGIN"; then
        grep -qE '^tools:.*\bBash\b' "$SCOUT_MD"
    fi
}

@test "the scout description stays one double-quoted line" {
    run grep -c '^description: ".*"$' "$SCOUT_MD"
    [ "$output" = "1" ]
}
