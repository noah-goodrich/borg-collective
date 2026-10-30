#!/usr/bin/env bats
# Frontmatter rules that let Cortex Code CLI load borg's agents. borg setup copies agents/*.md to
# ~/.snowflake/cortex/agents/ (_borg_install_cortex_agents in borg.zsh), and Cortex 1.2.18, checked live on
# 2026-10-30, is stricter than Claude Code in three ways:
#   - it registers an agent under its `name:`, so the name must match the file the plugin and docs refer to;
#   - it silently skips a file whose description is a folded `description: >` block (`cortex plugin validate`
#     reports "Invalid YAML"), which is how borg-grunt and borg-scout went missing;
#   - it honors `model:` only as a full id: `claude-haiku-5-5` and `claude-sonnet-5-5` run as pinned, while the bare
#     `sonnet` alias falls back to the session's model (Opus).
# Claude Code accepts every form these cases reject, so the Cortex rule is the one pinned here.

AGENTS="${BATS_TEST_DIRNAME}/../agents"

fm() { awk '/^---$/{n++; next} n==1' "$1"; }

@test "agents: the roster is not empty" {
    local -a files=("$AGENTS"/*.md)
    [ -f "${files[0]}" ]
}

@test "agents: every agent's name matches its file name" {
    local f n
    for f in "$AGENTS"/*.md; do
        n=${f##*/}
        n=${n%.md}
        fm "$f" | grep -qx "name: $n" || { echo "$f: name is not $n"; return 1; }
    done
}

@test "agents: every description is one line, never a folded or literal block" {
    local f
    for f in "$AGENTS"/*.md; do
        fm "$f" | grep -Eq '^description: *[^[:space:]>|]' || { echo "$f: description is empty or a block scalar"; return 1; }
    done
}

@test "agents: every model is a full claude- id, never a bare alias" {
    local f
    for f in "$AGENTS"/*.md; do
        fm "$f" | grep -Eqx 'model: claude-[a-z]+-[0-9]+(-[0-9]+)*' || { echo "$f: model is not a full id"; return 1; }
    done
}
