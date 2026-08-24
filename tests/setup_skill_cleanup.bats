#!/usr/bin/env bats
# Tests for borg setup's legacy-copy migration sweep (80/20 split, Gap 3 of the
# 2026-08-23 install audit).
#
# Skills and agents ship via the borg-collective plugin (docs/plans/assimilated/
# 2026-06-08-mechanism-layer-extraction-plugin-80-20-split.md). borg setup no longer
# copies them into ~/.claude — instead it removes the orphaned legacy copies so they
# stop double-loading. The sweep must ONLY remove:
#   - skill dirs bearing the .borg-managed marker that the legacy loop stamped
#   - agent files whose name matches a source-repo agent
# Hand-authored neighbours (no marker / no source match, e.g. ducky/) must survive.

load test_helper/setup

# Run the migration sweep in isolation via a minimal zsh snippet mirroring the
# cmd_setup() logic, same convention as the previous version of this file.
#
# Args:
#   $1  CLAUDE_SKILLS_DIR — the simulated ~/.claude/skills directory
#   $2  CLAUDE_AGENTS_DIR — the simulated ~/.claude/agents directory
#   $3  BORG_HOME         — a minimal fake borg source tree (skills/ + agents/)
_run_migration_sweep() {
    local skills_dir="$1"
    local agents_dir="$2"
    local borg_home="$3"

    zsh -c "
setopt NULL_GLOB
CLAUDE_SKILLS_DIR=\"${skills_dir}\"
CLAUDE_AGENTS_DIR=\"${agents_dir}\"
BORG_HOME=\"${borg_home}\"

# Skills: remove ONLY .borg-managed legacy copies.
for _existing in \"\$CLAUDE_SKILLS_DIR/\"*/(N); do
    [[ -d \"\$_existing\" && -f \"\$_existing/.borg-managed\" ]] || continue
    rm -rf \"\$_existing\"
done

# Agents: remove ONLY files matching a source-repo agent name.
if [[ -d \"\$CLAUDE_AGENTS_DIR\" && -d \"\$BORG_HOME/agents\" ]]; then
    for _agent_file in \"\$BORG_HOME/agents/\"*.md(N); do
        [[ -f \"\$_agent_file\" ]] || continue
        _aname=\"\${_agent_file:t}\"
        [[ -f \"\$CLAUDE_AGENTS_DIR/\$_aname\" ]] && rm -f \"\$CLAUDE_AGENTS_DIR/\$_aname\"
    done
fi
"
}

setup() {
    setup_temp_dirs
    export SKILLS_DIR="${BATS_TEST_TMPDIR}/claude/skills"
    export AGENTS_DIR="${BATS_TEST_TMPDIR}/claude/agents"
    export BORG_SRC="${BATS_TEST_TMPDIR}/borg_src"
    mkdir -p "$SKILLS_DIR" "$AGENTS_DIR" "$BORG_SRC/skills" "$BORG_SRC/agents"
}

# ─── Skill sweep: ownership gate ──────────────────────────────────────────────

@test "legacy borg-managed skill copy is removed even though it still exists in source" {
    mkdir -p "$BORG_SRC/skills/borg-plan"
    mkdir -p "$SKILLS_DIR/borg-plan"
    touch "$SKILLS_DIR/borg-plan/.borg-managed"
    _run_migration_sweep "$SKILLS_DIR" "$AGENTS_DIR" "$BORG_SRC"
    [ ! -d "$SKILLS_DIR/borg-plan" ]
}

@test "hand-authored skill without marker survives (the ducky case)" {
    mkdir -p "$SKILLS_DIR/ducky"
    echo "personal" > "$SKILLS_DIR/ducky/SKILL.md"
    _run_migration_sweep "$SKILLS_DIR" "$AGENTS_DIR" "$BORG_SRC"
    [ -d "$SKILLS_DIR/ducky" ]
    [ -f "$SKILLS_DIR/ducky/SKILL.md" ]
}

@test "unmarked skill sharing a borg source name survives — the sweep never adopts" {
    mkdir -p "$BORG_SRC/skills/simplify"
    mkdir -p "$SKILLS_DIR/simplify"
    echo "user fork" > "$SKILLS_DIR/simplify/SKILL.md"
    _run_migration_sweep "$SKILLS_DIR" "$AGENTS_DIR" "$BORG_SRC"
    [ -d "$SKILLS_DIR/simplify" ]
}

@test "mixed directory: marked copies go, unmarked neighbours stay" {
    mkdir -p "$SKILLS_DIR/borg-link" "$SKILLS_DIR/ducky" "$SKILLS_DIR/borg-review"
    touch "$SKILLS_DIR/borg-link/.borg-managed"
    touch "$SKILLS_DIR/borg-review/.borg-managed"
    _run_migration_sweep "$SKILLS_DIR" "$AGENTS_DIR" "$BORG_SRC"
    [ ! -d "$SKILLS_DIR/borg-link" ]
    [ ! -d "$SKILLS_DIR/borg-review" ]
    [ -d "$SKILLS_DIR/ducky" ]
}

# ─── Agent sweep: name-match gate ─────────────────────────────────────────────

@test "agent copy matching a source agent is removed" {
    echo "src" > "$BORG_SRC/agents/borg-nanoprobe.md"
    echo "copy" > "$AGENTS_DIR/borg-nanoprobe.md"
    _run_migration_sweep "$SKILLS_DIR" "$AGENTS_DIR" "$BORG_SRC"
    [ ! -f "$AGENTS_DIR/borg-nanoprobe.md" ]
}

@test "agent file with no source counterpart survives" {
    echo "mine" > "$AGENTS_DIR/my-personal-agent.md"
    _run_migration_sweep "$SKILLS_DIR" "$AGENTS_DIR" "$BORG_SRC"
    [ -f "$AGENTS_DIR/my-personal-agent.md" ]
}

# ─── Idempotence ──────────────────────────────────────────────────────────────

@test "sweep on already-clean directories is a no-op" {
    mkdir -p "$SKILLS_DIR/ducky"
    _run_migration_sweep "$SKILLS_DIR" "$AGENTS_DIR" "$BORG_SRC"
    _run_migration_sweep "$SKILLS_DIR" "$AGENTS_DIR" "$BORG_SRC"
    [ -d "$SKILLS_DIR/ducky" ]
}
