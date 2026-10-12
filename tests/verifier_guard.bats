#!/usr/bin/env bats
# Tests for hooks/borg-verifier-guard.sh — PreToolUse (Bash): borg-verifier may run any verification command,
# but git and gh only through a read-only allowlist, and nothing the guard cannot see through. Every other
# caller is a no-op. Bypass classes follow docs/plans/directives/2026-10-10-scout-shell-allowlist.md.

load test_helper/setup

HOOK="${BATS_TEST_DIRNAME}/../hooks/borg-verifier-guard.sh"
BASH_BIN=bash
[ -x /bin/bash ] && BASH_BIN=/bin/bash
BUILD_PLUGIN="${BATS_TEST_DIRNAME}/../scripts/build-plugin.sh"
VERIFIER_MD="${BATS_TEST_DIRNAME}/../agents/borg-verifier.md"

setup() {
    setup_temp_dirs
}

# _bash <command> [agent_type]  (agent_type defaults to the plugin-scoped verifier; pass - for none)
_bash() {
    local at="${2:-borg-collective:borg-verifier}" json
    json=$(jq -nc --arg c "$1" --arg at "$at" \
        '{tool_name:"Bash", tool_input:{command:$c}} + (if $at == "-" then {} else {agent_type:$at} end)')
    run bash -c "printf '%s' \"\$1\" | '$BASH_BIN' '$HOOK' 2>&1" _ "$json"
}

_allow() {
    _bash "$@"
    [ "$status" -eq 0 ] || { echo "expected allow, got $status: $output"; false; }
}

_deny() {
    _bash "$@"
    [ "$status" -eq 2 ] || { echo "expected deny, got $status: $output"; false; }
    [[ "$output" == *"borg verifier guard"* ]] || false
}

# --- scope: every other caller is untouched ------------------------------------------------------

@test "main session (no agent_type) may run gh pr merge" {
    _allow 'gh pr merge 12 --squash' -
}

@test "another subagent may run git push" {
    _allow 'git push origin HEAD' borg-collective:borg-nanoprobe
}

@test "a non-verifier payload that merely mentions borg-verifier is allowed" {
    _allow 'git commit -m "teach borg-verifier"' borg-collective:borg-grunt
}

@test "the bare borg-verifier type (borg setup copy in ~/.claude/agents) is enforced too" {
    _deny 'git push' borg-verifier
}

@test "a non-Bash tool from the verifier is not judged" {
    run bash -c "printf '%s' '{\"tool_name\":\"Read\",\"agent_type\":\"borg-collective:borg-verifier\",\"tool_input\":{}}' | '$BASH_BIN' '$HOOK'"
    [ "$status" -eq 0 ]
}

# --- verification commands still run ------------------------------------------------------------

@test "allow: verification commands, plain and compound" {
    _allow 'make test'
    _allow 'make lint && make test && make test-bats'
    _allow 'bats tests/verifier_guard.bats < /dev/null'
    _allow 'bats tests/*.bats'
    _allow 'drone exec ingle -- npm test'
    _allow 'run-in /Users/noah/dev/borg-collective make test'
    _allow 'pytest -q 2>&1 | tail -20'
    _allow 'make test # then report'
}

@test "allow: bash -c pipelines, the form agents are told to use" {
    _allow "bash -c 'make lint && make test 2>&1 | tail -30'"
    _allow "bash -lc 'cd /Users/noah/dev/x && git diff --stat origin/main...HEAD'"
    _allow "drone exec ingle -- bash -c 'npm run lint && npm test'"
}

@test "allow: every git read on the table" {
    _allow 'git diff --stat origin/main...HEAD'
    _allow 'git -C /Users/noah/dev/borg-collective log --oneline -5'
    _allow 'git --no-pager show --name-only HEAD'
    _allow 'git status --porcelain'
    _allow 'git rev-parse --abbrev-ref HEAD'
    _allow 'git merge-base origin/main HEAD'
    _allow 'git ls-files hooks'
    _allow 'git blame -L 1,5 borg.zsh'
    _allow 'git log --oneline --format=%h origin/main..HEAD'
}

@test "allow: gh reads and GET-only gh api" {
    _allow 'gh pr diff 307'
    _allow 'gh pr view 307 --json files --jq .files[].path'
    _allow 'gh pr checks 307 -R noah-goodrich/borg-collective'
    _allow 'gh -R noah-goodrich/borg-collective pr list --state open'
    _allow 'gh run view 123 --log-failed'
    _allow 'gh api repos/noah-goodrich/borg-collective/pulls/307/files'
    _allow 'gh api -X GET repos/o/r/pulls'
    _allow 'gh api --method=GET repos/o/r/pulls --jq .[].number'
}

# --- git and gh writes, direct ------------------------------------------------------------------

@test "deny: gh writes" {
    _deny 'gh pr merge 12 --squash'
    _deny 'gh pr close 12'
    _deny 'gh pr review 12 --approve'
    _deny 'gh pr edit 12 --title x'
    _deny 'gh pr comment 12 --body x'
    _deny 'gh -R o/r pr merge 1'
    _deny 'gh auth token'
    _deny 'gh alias set pv "pr merge"'
}

@test "deny: git writes" {
    _deny 'git push origin HEAD'
    _deny 'git commit --allow-empty -m probe'
    _deny 'git checkout main'
    _deny 'git reset --hard'
    _deny 'git branch -D x'
    _deny 'git fetch origin'
    _deny 'git -C /tmp push'
}

@test "deny: git options that write or inject configuration" {
    _deny 'git log --output=/tmp/x'
    _deny 'git diff --output /tmp/x'
    _deny 'git log --outp=/tmp/x'
    _deny "git -c alias.x='!sh -c id' x"
    _deny 'git --exec-path=/tmp log'
    _deny 'GIT_PAGER=sh git log'
    _deny 'env GIT_EXTERNAL_DIFF=/tmp/x git diff'
}

@test "deny: gh api writes, including bundled and attached short options" {
    _deny 'gh api -X POST repos/o/r/issues'
    _deny 'gh api --method PATCH repos/o/r/pulls/1'
    _deny 'gh api --method=DELETE repos/o/r/git/refs/heads/x'
    _deny 'gh api -f title=x repos/o/r/issues'
    _deny 'gh api -iXPOST repos/o/r/issues'
    _deny 'gh api repos/o/r/issues --input body.json'
    _deny "gh api graphql -f query='mutation{x}'"
    _deny 'gh api -H X-HTTP-Method-Override:PUT repos/o/r/pulls/1/merge'
}

# --- the same writes, hidden ---------------------------------------------------------------------

@test "deny: path-qualified, quoted and escaped command names" {
    _deny '/usr/bin/git push'
    _deny '"git" push'
    _deny 'g\it push'
    _deny "'gh' pr merge 1"
}

@test "deny: writes inside compound commands and pipelines" {
    _deny 'make test && git push'
    _deny 'make test; gh pr merge 1'
    _deny 'true | git push'
    _deny 'make test || git commit -am x'
    _deny $'git status\ngit push'
    _deny 'echo a#b; git push'
    _deny '{ git push; }'
    _deny 'if true; then gh pr merge 1; fi'
}

@test "deny: writes inside shell -c, at any depth" {
    _deny "bash -c 'git push'"
    _deny "bash -lc \"gh pr merge 1\""
    _deny "sh -c 'make && git commit -am x'"
    _deny "bash -c \"sh -c 'git push'\""
    _deny "drone exec ingle -- bash -c 'git push'"
    _deny "zsh -c 'gh pr merge 1'"
}

@test "deny: wrappers that run git or gh" {
    _deny 'drone exec ingle -- git push'
    _deny 'run-in /tmp gh pr merge 1'
    _deny 'env git push'
    _deny 'timeout 5 git push'
    _deny 'nohup git push'
    _deny 'command git push'
    _deny 'find . -name x -exec git push \;'
}

@test "deny: constructs the guard cannot see through" {
    _deny 'G=git; $G push'
    _deny '${G} push'
    _deny "\$'\\x67it' push"
    _deny 'git push $X'
    _deny '$(echo git) push'
    _deny '`echo git` push'
    _deny 'cat <(git push)'
    _deny '{git,x} push'
    _deny '/usr/bin/gi? push'
    _deny 'eval "git push"'
    _deny 'echo git push | xargs git'
    _deny 'echo "git push" | bash'
    _deny 'echo "gh pr merge 1" | sh -s'
    _deny "python3 -c 'import os'"
    _deny "perl -ne 'print'"
    _deny "node -e 'x'"
    _deny 'source /dev/stdin'
    _deny "alias g=git"
    _deny "trap 'git push' EXIT"
    _deny 'tmux send-keys -t x "gh pr merge 1" Enter'
    _deny "env -S 'git push'"
    _deny 'drone down ingle'
}

@test "deny: zsh, interpreter-stdin, awk and precommand forms" {
    _deny '=git push'
    _deny 'read GIT_PAGER'
    _deny 'echo "import os" | python3'
    _deny $'python3 - <<\'EOF\'\nimport os\nEOF'
    _deny 'node'
    _deny "awk 'BEGIN{system(\"gh pr merge 1\")}'"
    _deny "awk '{print | \"sh\"}' file"
    _deny 'noglob eval x'
    _deny 'coproc eval x'
    _deny 'function f { eval x; }'
}

@test "allow: exit-status reporting, module runs, plain awk and test" {
    _allow 'make test; echo "exit=$?"'
    _allow 'python3 -m pytest -q'
    _allow 'python3 --version'
    _allow "awk '{print \$1}' results.txt"
    _allow '[ "a" = b ] && make test'
}

@test "deny: blind-review round 1 bypasses" {
    _deny $'cat <<EOF\nit\'s\nEOF\ngit push\necho it\\\'s'
    _deny $'cat <<EOF\n$(git push)\nEOF'
    _deny $'bash <<\'EOF\'\ngit push\nEOF'
    _deny "python3 -W ignore -c 'import os'"
    _deny "node -r x -e 'y'"
    _deny "perl -I lib -e 'x'"
    _deny "csh -c 'git push'"
    _deny "tcsh -c 'gh pr merge 1'"
    _deny "pwsh -c 'git push'"
    _deny "lua -e 'os.execute(1)'"
    _deny "Rscript -e 'system(1)'"
    _deny '/Library/Developer/CommandLineTools/usr/libexec/git-core/git-push origin HEAD'
    _deny 'gh-merge 1'
    _deny 'hub merge 1'
    _deny 'jj git push'
    _deny 'npm version patch'
    _deny 'select x in a; do eval x; done'
    _deny 'echo "git push" | xargs -I{} sh -c {}'
}

@test "deny: write forms of the list-only git subcommands" {
    _deny 'git branch new-branch'
    _deny 'git branch -m old new'
    _deny 'git remote add x y'
    _deny 'git reflog expire --all'
    _deny 'git worktree add /tmp/x'
    _deny 'git stash'
    _deny 'git stash pop'
    _deny 'git grep -Ovim foo'
    _deny 'git grep --open-files-in-pager=vim foo'
}

@test "allow: blind-review round 1 false denies" {
    _allow 'bats tests/*'
    _allow 'shellcheck hooks/*'
    _allow 'ls -d */'
    _allow 'source .venv/bin/activate && pytest'
    _allow ". .venv/bin/activate && pytest"
    _allow "git ls-files '*.sh' | xargs shellcheck"
    _allow 'git branch --show-current'
    _allow 'git branch -a --contains HEAD'
    _allow 'git branch --list "feat/*"'
    _allow 'git remote -v'
    _allow 'git reflog -5'
    _allow 'git for-each-ref refs/heads'
    _allow 'git grep -n TODO'
    _allow 'git --version'
    _allow 'git worktree list'
    _allow 'git stash list'
    _allow 'gh auth status'
    _allow 'gh run watch 123'
    _allow 'ENV=test make test'
    _allow 'python3 -m pytest -c pytest.ini'
    _allow $'cat <<\'EOF\' > /tmp/notes.txt\ngit push is mentioned here\nEOF'
}

@test "deny: unparseable input fails closed for the verifier" {
    _deny "echo 'unterminated"
    _deny 'echo "unterminated'
}

# --- fail closed / fail open ---------------------------------------------------------------------

@test "a malformed payload that mentions borg-verifier is denied" {
    run bash -c "printf '%s' 'not json borg-verifier' | '$BASH_BIN' '$HOOK'"
    [ "$status" -eq 2 ]
}

@test "a malformed payload that does not mention the verifier is allowed" {
    run bash -c "printf '%s' 'not json' | '$BASH_BIN' '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "missing python3 denies the verifier and allows everyone else" {
    local bin="${BATS_TEST_TMPDIR}/nopy"
    mkdir -p "$bin"
    ln -s "$(command -v jq)" "$bin/jq"
    local v='{"tool_name":"Bash","agent_type":"borg-collective:borg-verifier","tool_input":{"command":"make test"}}'
    local o='{"tool_name":"Bash","agent_type":"borg-collective:borg-grunt","tool_input":{"command":"git push"}}'
    run env PATH="$bin" "$BASH_BIN" -c "printf '%s' '$v' | '$BASH_BIN' '$HOOK'"
    [ "$status" -eq 2 ]
    run env PATH="$bin" "$BASH_BIN" -c "printf '%s' '$o' | '$BASH_BIN' '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "BORG_VERIFIER_GUARD=0 disables the guard" {
    export BORG_VERIFIER_GUARD=0
    _allow 'gh pr merge 1'
}

# --- wiring --------------------------------------------------------------------------------------

@test "wiring: build-plugin.sh copies the hook and registers it on a Bash PreToolUse matcher" {
    grep -qE '_build_self_contained_hook .*borg-verifier-guard\.sh' "$BUILD_PLUGIN"
    run grep -B7 -A2 'borg-verifier-guard.sh"' "$BUILD_PLUGIN"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"matcher": "Bash"'* ]] || false
}

@test "roster: the verifier never ships Bash without the guard" {
    if grep -qE '^tools:.*\bBash\b' "$VERIFIER_MD"; then
        grep -q 'borg-verifier-guard.sh' "$BUILD_PLUGIN"
    fi
}
