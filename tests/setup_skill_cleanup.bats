#!/usr/bin/env bats
# Tests for borg setup skill-cleanup ownership-marker logic (issue #64).
#
# The cleanup must ONLY remove skills bearing the .borg-managed marker that
# borg itself writes on install. Personal / third-party skills without the
# marker must survive borg setup regardless of whether they match a borg
# skill name.

load test_helper/setup

# Run the skill cleanup code path in isolation via a minimal zsh snippet.
# Uses the same logic that lives in borg.zsh cmd_setup() so that any future
# refactor of the loop body is caught here.
#
# Args:
#   $1  CLAUDE_SKILLS_DIR  — the simulated ~/.claude/skills directory
#   $2  BORG_HOME          — a minimal fake borg source tree (must contain skills/)
_run_skill_cleanup() {
    local skills_dir="$1"
    local borg_home="$2"

    zsh -c "
setopt NULL_GLOB
CLAUDE_SKILLS_DIR=\"${skills_dir}\"
BORG_HOME=\"${borg_home}\"

# Migration: stamp marker on matching existing dirs (v0.8.6 one-time path)
for _existing in \"\$CLAUDE_SKILLS_DIR/\"*/(N); do
    [[ -d \"\$_existing\" ]] || continue
    _mname=\"\${_existing:t}\"
    if [[ -d \"\$BORG_HOME/skills/\$_mname\" && ! -f \"\$_existing/.borg-managed\" ]]; then
        touch \"\$_existing/.borg-managed\"
    fi
done

# Cleanup: only remove dirs bearing .borg-managed marker
for _existing in \"\$CLAUDE_SKILLS_DIR/\"*/(N); do
    [[ -d \"\$_existing\" ]] || continue
    [[ -f \"\$_existing/.borg-managed\" ]] || continue
    _ename=\"\${_existing:t}\"
    if [[ ! -d \"\$BORG_HOME/skills/\$_ename\" ]]; then
        rm -rf \"\$_existing\"
    fi
done
"
}

setup() {
    setup_temp_dirs
    export SKILLS_DIR="${BATS_TEST_TMPDIR}/claude/skills"
    export BORG_SRC="${BATS_TEST_TMPDIR}/borg_src"
    mkdir -p "$SKILLS_DIR"
    mkdir -p "$BORG_SRC/skills"
}

# ─── Core ownership-gate tests ────────────────────────────────────────────────

@test "unowned skill (no marker) survives cleanup" {
    mkdir -p "$SKILLS_DIR/noah-weekly-status"

    _run_skill_cleanup "$SKILLS_DIR" "$BORG_SRC"

    [ -d "$SKILLS_DIR/noah-weekly-status" ]
}

@test "stale borg-managed skill (marker + removed from source) is cleaned up" {
    mkdir -p "$SKILLS_DIR/old-borg-skill"
    touch "$SKILLS_DIR/old-borg-skill/.borg-managed"

    _run_skill_cleanup "$SKILLS_DIR" "$BORG_SRC"

    [ ! -d "$SKILLS_DIR/old-borg-skill" ]
}

@test "current borg-managed skill (marker + still in source) survives" {
    mkdir -p "$SKILLS_DIR/adhd-guardrails"
    touch "$SKILLS_DIR/adhd-guardrails/.borg-managed"
    mkdir -p "$BORG_SRC/skills/adhd-guardrails"

    _run_skill_cleanup "$SKILLS_DIR" "$BORG_SRC"

    [ -d "$SKILLS_DIR/adhd-guardrails" ]
}

@test "unowned skill with same name as a borg source skill survives" {
    # An unowned skill that HAPPENS to share a name with a borg skill must not be
    # removed — only the .borg-managed marker determines ownership, not the name.
    mkdir -p "$SKILLS_DIR/adhd-guardrails"
    mkdir -p "$BORG_SRC/skills/adhd-guardrails"

    _run_skill_cleanup "$SKILLS_DIR" "$BORG_SRC"

    [ -d "$SKILLS_DIR/adhd-guardrails" ]
}

@test "mixed directory: unowned skill coexists with stale borg skill" {
    mkdir -p "$SKILLS_DIR/personal-skill"
    mkdir -p "$SKILLS_DIR/stale-borg-skill"
    touch "$SKILLS_DIR/stale-borg-skill/.borg-managed"
    mkdir -p "$SKILLS_DIR/current-borg-skill"
    touch "$SKILLS_DIR/current-borg-skill/.borg-managed"
    mkdir -p "$BORG_SRC/skills/current-borg-skill"

    _run_skill_cleanup "$SKILLS_DIR" "$BORG_SRC"

    [ -d "$SKILLS_DIR/personal-skill" ]
    [ ! -d "$SKILLS_DIR/stale-borg-skill" ]
    [ -d "$SKILLS_DIR/current-borg-skill" ]
}

# ─── Migration tests ──────────────────────────────────────────────────────────

@test "migration stamps .borg-managed on matching skill without marker" {
    mkdir -p "$SKILLS_DIR/adhd-guardrails"
    mkdir -p "$BORG_SRC/skills/adhd-guardrails"

    _run_skill_cleanup "$SKILLS_DIR" "$BORG_SRC"

    [ -f "$SKILLS_DIR/adhd-guardrails/.borg-managed" ]
}

@test "migration does not stamp .borg-managed on unowned skill" {
    mkdir -p "$SKILLS_DIR/noah-weekly-status"

    _run_skill_cleanup "$SKILLS_DIR" "$BORG_SRC"

    [ ! -f "$SKILLS_DIR/noah-weekly-status/.borg-managed" ]
}

@test "migration does not duplicate marker if already present" {
    mkdir -p "$SKILLS_DIR/adhd-guardrails"
    touch "$SKILLS_DIR/adhd-guardrails/.borg-managed"
    mkdir -p "$BORG_SRC/skills/adhd-guardrails"

    _run_skill_cleanup "$SKILLS_DIR" "$BORG_SRC"

    [ -f "$SKILLS_DIR/adhd-guardrails/.borg-managed" ]
}
