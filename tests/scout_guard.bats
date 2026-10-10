#!/usr/bin/env bats
# Tests for hooks/borg-scout-guard.sh — confines the borg-scout subagent's Bash to read-only git/gh.
# Enforcement keys on agent_type in the PreToolUse payload; any other caller is untouched.

load test_helper/setup

HOOK="${BATS_TEST_DIRNAME}/../hooks/borg-scout-guard.sh"
BUILD_PLUGIN="${BATS_TEST_DIRNAME}/../scripts/build-plugin.sh"

setup() { setup_temp_dirs; }

# _caller <agent_type> <command>; _scout <command>
_caller() {
    local json
    json=$(jq -nc --arg t "$1" --arg c "$2" '{tool_name:"Bash", agent_id:"a1", agent_type:$t, tool_input:{command:$c}}')
    run bash -c "printf '%s' \"\$1\" | '$HOOK' 2>&1" _ "$json"
}
_scout() { _caller "borg-collective:borg-scout" "$1"; }

@test "allowed: read-only git commands" {
    for c in "git log --oneline -n 5" "git show abc123" "git diff main...HEAD --stat" "git status --short" \
             "git blame -L1,5 file.sh" "git grep -n foo" "git ls-files" "git rev-parse HEAD" "git branch" \
             "git branch -a" "git branch --list 'feat/*'" "git branch --contains abc123" "git remote -v" \
             "git worktree list" "git -C /tmp/repo log -1"; do
        _scout "$c"
        [ "$status" -eq 0 ] || { echo "denied: $c -> $output"; false; }
    done
}

@test "allowed: read-only gh commands" {
    for c in "gh pr view 12 --json state,title" "gh pr list --state open" "gh pr diff 12" "gh pr checks 12" \
             "gh issue view 3" "gh issue list" "gh run view 99" "gh run list --limit 5" "gh repo view" \
             "gh api repos/o/r/pulls/1" "gh api -X GET repos/o/r/pulls" "gh api --method GET repos/o/r" \
             "gh pr view 12 -R o/r"; do
        _scout "$c"
        [ "$status" -eq 0 ] || { echo "denied: $c -> $output"; false; }
    done
}

@test "allowed: bare agent_type and a single pipe into head/wc/grep" {
    _caller "borg-scout" "git log --oneline | head -5"
    [ "$status" -eq 0 ]
    _scout "gh pr list | wc -l"
    [ "$status" -eq 0 ]
    _scout "git ls-files | grep '\.sh$'"
    [ "$status" -eq 0 ]
}

@test "denied: git write commands" {
    for c in "git commit -m x" "git push origin main" "git checkout main" "git reset --hard" "git add ." \
             "git branch newbranch" "git branch -D old" "git branch -m a b" "git remote add x url" \
             "git worktree add ../x" "git -c core.pager=sh log" "git diff --output=/tmp/out" "git config user.name x" \
             "git stash" "git fetch"; do
        _scout "$c"
        [ "$status" -eq 2 ] || { echo "allowed: $c"; false; }
    done
}

@test "denied: gh write commands" {
    for c in "gh pr create" "gh pr merge 1" "gh pr comment 1 -b x" "gh issue create" "gh issue close 1" \
             "gh repo delete x" "gh run rerun 1" "gh auth login" "gh pr view 1 --web" "gh workflow run x"; do
        _scout "$c"
        [ "$status" -eq 2 ] || { echo "allowed: $c"; false; }
    done
}

@test "denied: gh api with a non-GET method, body flags, or graphql" {
    for c in "gh api -X POST repos/o/r/issues" "gh api --method POST repos/o/r/issues" "gh api -XPATCH repos/o/r" \
             "gh api --method=DELETE repos/o/r" "gh api repos/o/r/issues -f title=x" "gh api repos/o/r -F a=b" \
             "gh api repos/o/r --input body.json" "gh api graphql -f query=x" "gh api graphql"; do
        _scout "$c"
        [ "$status" -eq 2 ] || { echo "allowed: $c"; false; }
    done
}

@test "denied: chained, redirected, substituted, or env-prefixed commands" {
    for c in "git log; ls" "git log && git push" "git log || true" "git log & git push" \
             'git log $(whoami)' 'git log `id`' "git log > out.txt" "git log | tee out" "git log | head | wc" \
             "git log | sh" "FOO=1 git log" "/usr/bin/git log" "ls" "cat file" $'git log\ngit push'; do
        _scout "$c"
        [ "$status" -eq 2 ] || { echo "allowed: $c"; false; }
    done
}

@test "denial explains the allowlist" {
    _scout "git push"
    [ "$status" -eq 2 ]
    [[ "$output" == *"read-only git/gh"* ]] || false
}

@test "non-scout callers are unaffected" {
    _caller "borg-collective:borg-nanoprobe" "git push origin main"
    [ "$status" -eq 0 ]
    _caller "general-purpose" "git reset --hard"
    [ "$status" -eq 0 ]
    _caller "borg-collective:borg-scouting-party" "git push"
    [ "$status" -eq 0 ]
}

@test "main session (no agent_type) is unaffected" {
    run bash -c "printf '%s' '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git push\"}}' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "malformed JSON and empty stdin fail open (caller not provably scout)" {
    run bash -c "printf '%s' '{oops' | '$HOOK'"
    [ "$status" -eq 0 ]
    run bash -c "printf '' | '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "scout with a missing command is denied (fail closed for a scout)" {
    run bash -c "printf '%s' '{\"tool_name\":\"Bash\",\"agent_type\":\"borg-scout\",\"tool_input\":{}}' | '$HOOK'"
    [ "$status" -eq 2 ]
}

@test "scout keeps Haiku/low and gains Bash; wiring registered" {
    grep -q '^tools: Read, Grep, Glob, Bash$' "${BATS_TEST_DIRNAME}/../agents/borg-scout.md"
    grep -q '^model: haiku$' "${BATS_TEST_DIRNAME}/../agents/borg-scout.md"
    grep -q '^effort: low$' "${BATS_TEST_DIRNAME}/../agents/borg-scout.md"
    grep -qE '_build_self_contained_hook .*borg-scout-guard\.sh' "$BUILD_PLUGIN"
    run grep -B4 'borg-scout-guard.sh' "$BUILD_PLUGIN"
    [[ "$output" == *'"matcher": "Bash"'* ]] || false
}

@test "denied: abbreviated long options and --no-index (git/gh accept unambiguous prefixes)" {
    for c in "git diff --outpu=/tmp/zz" "git diff --out=/tmp/zz" "git log --output /tmp/zz" "git log --ext-di" \
             "git diff --ext-d" "git grep --open-files-in-p foo" "git grep --open-f foo" "git show --textc" \
             "git diff --no-index /etc/passwd /dev/null" "git diff --no-ind a b" "git diff --no-i a b" \
             "gh pr view 1 --we" "gh pr checks 1 --wat" "gh pr view 1 --out=x"; do
        _scout "$c"
        [ "$status" -eq 2 ] || { echo "allowed: $c"; false; }
    done
}

@test "allowed: ordinary long options and the -- separator still pass" {
    for c in "git log --oneline --no-color -n 3" "git diff --stat -- hooks" "git log --format=%H"; do
        _scout "$c"
        [ "$status" -eq 0 ] || { echo "denied: $c -> $output"; false; }
    done
}

@test "denied: bundled and attached short flags (cluster decomposition, not token-start match)" {
    for c in "git grep -nOtouch foo" "git grep -iOsh foo" "git grep -On foo" "git grep -nO foo" "git grep -O foo" \
             "git grep -inO sh foo" "git diff -Ofile" "git diff -pO x" "git log -nOx" "git show -O" \
             "git diff -o/tmp/x" "git log -po/tmp/x" "git blame -Lo x" \
             "gh pr view 1 -cw" "gh pr checks 1 -w" "gh run view 1 -vw" "gh repo view -w" \
             "gh api -iXPOST repos/o/r" "gh api -ifx=1 repos/o/r" "gh api -iF a=b repos/o/r" "gh api -iX POST repos/o/r" \
             "gh api -iXGET -fa=b repos/o/r"; do
        _scout "$c"
        [ "$status" -eq 2 ] || { echo "allowed: $c"; false; }
    done
}

@test "denied: clustered file-pattern flag on the grep pipe target" {
    for c in "git log | grep -rf /tmp/x" "git log | grep -f /tmp/x" "git log | grep -ff /tmp/x" "git log | grep -if/tmp/x" \
             "git log | grep --file=/tmp/x" "git log | grep --exclude-from=/tmp/x"; do
        _scout "$c"
        [ "$status" -eq 2 ] || { echo "allowed: $c"; false; }
    done
}

@test "allowed: ordinary short flags and clusters still pass" {
    for c in "git log --oneline | head -5" "git grep -n foo" "git grep -inw foo" "git grep -e foo -n" "git log -n5 -p" \
             "git diff -U3 -w" "git log -S foo" "git ls-files -o" "git log | grep -rn foo" "git log | grep -efoo" \
             "git log | grep -in foo" "gh api repos/a/b/pulls" "gh api -i repos/a/b" "gh api -iXGET repos/a/b" \
             "gh pr view 1 -R o/r" "gh pr list -L 5 -s all" "gh run list -L5"; do
        _scout "$c"
        [ "$status" -eq 0 ] || { echo "denied: $c -> $output"; false; }
    done
}

@test "deploy topology: scout agent and guard share one vehicle (the plugin); setup never installs a bare agent" {
    # borg setup removes legacy ~/.claude/agents copies and copies no agent file anywhere, and CoCo has no agent
    # install path, so a Bash-enabled borg-scout can only arrive via the plugin build that also registers the guard.
    run grep -nE 'cp .*(agent_file|/agents/)' "${BATS_TEST_DIRNAME}/../borg.zsh"
    [ "$status" -ne 0 ]
    run grep -nE 'cp .*agents' "${BATS_TEST_DIRNAME}/../install.sh"
    [ "$status" -ne 0 ]
    grep -q 'borg-scout-guard.sh' "$BUILD_PLUGIN"
    grep -q 'agents' "$BUILD_PLUGIN"
}
