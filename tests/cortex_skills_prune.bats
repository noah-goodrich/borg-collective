#!/usr/bin/env bats
# `cortex skill add <dir>` records the directory in ~/.snowflake/cortex/skills.json and nothing else, so a skill borg
# removes or renames leaves a registration pointing at nothing. _borg_cortex_prune_skills (borg.zsh), called from
# cmd_setup's Cortex section, drops borg's own dead entries on every `borg setup`.
#
# THE HAZARD: these cases never run borg setup or cortex. HOME is the sandbox (setup_temp_dirs), the skills.json is a
# fixture, and the function is sourced from borg.zsh and called directly. The real ~/.snowflake is never read.

load test_helper/setup

BORG_ZSH="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs
    CORTEX="${BATS_TEST_TMPDIR}/cortex"
    BSKILLS="${BATS_TEST_TMPDIR}/borg/skills"
    OTHER="${BATS_TEST_TMPDIR}/plugins/noah-voice"
    mkdir -p "$CORTEX" "$BSKILLS/borg-plan" "$BSKILLS/borg-link" "$BSKILLS/borg-recon" "$OTHER"
    cat > "$CORTEX/skills.json" <<EOF
{
  "paths": [
    "$BSKILLS/borg-plan",
    "$BSKILLS/borg-search",
    "$BSKILLS/borg-link",
    "$BSKILLS/no-unnecessary-read-perms",
    "$BSKILLS/borg-recon",
    "$OTHER",
    "${BATS_TEST_TMPDIR}/plugins/gone-nonborg-skill"
  ],
  "other": {"keep": true}
}
EOF
}

_prune() {
    run zsh -c "
        source '$BORG_ZSH' >/dev/null 2>&1 || true
        warn() { print -r -- \"WARN: \$*\"; }
        info() { print -r -- \"INFO: \$*\"; }
        _borg_cortex_prune_skills '$CORTEX' '$BSKILLS'
    "
}

_paths() { jq -r '.paths[]' "$CORTEX/skills.json"; }

@test "cortex prune: a dead borg entry is dropped" {
    _prune
    [ "$status" -eq 0 ]
    [[ "$(_paths)" != *"borg-search"* ]] || { _paths; false; }
    [[ "$output" == *"INFO:   dropped 3 dead skill registration(s) from Cortex: borg-search, no-unnecessary-read-perms, borg-recon"* ]] || {
        echo "$output"; false; }
}

@test "cortex prune: a retired name under borg's skills dir goes even though its directory still exists" {
    [ -d "$BSKILLS/borg-recon" ]
    _prune
    [[ "$(_paths)" != *"borg-recon"* ]] || { _paths; false; }
}

@test "cortex prune: live borg entries and non-borg entries (even a dead one) are kept, other keys survive" {
    _prune
    run _paths
    [[ "$output" == *"$BSKILLS/borg-plan"* ]] || false
    [[ "$output" == *"$BSKILLS/borg-link"* ]] || false
    [[ "$output" == *"$OTHER"* ]] || false
    [[ "$output" == *"gone-nonborg-skill"* ]] || false
    [ "$(jq -r '.other.keep' "$CORTEX/skills.json")" = "true" ]
    [ "$(jq '.paths | length' "$CORTEX/skills.json")" -eq 4 ]
}

@test "cortex prune: a second run changes nothing and says nothing" {
    _prune
    cp "$CORTEX/skills.json" "${BATS_TEST_TMPDIR}/after-first.json"
    _prune
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    cmp "$CORTEX/skills.json" "${BATS_TEST_TMPDIR}/after-first.json"
}

@test "cortex prune: nothing dead means the file is not rewritten" {
    printf '{"paths":["%s/borg-plan"]}' "$BSKILLS" > "$CORTEX/skills.json"
    touch -t 200001010000 "$CORTEX/skills.json"
    _prune
    [ -z "$output" ]
    [ "$(stat -f %m "$CORTEX/skills.json" 2>/dev/null || stat -c %Y "$CORTEX/skills.json")" -lt 1000000000 ]
}

@test "cortex prune: a missing or malformed skills.json is left alone" {
    rm "$CORTEX/skills.json"
    _prune
    [ "$status" -eq 0 ]
    [ ! -e "$CORTEX/skills.json" ]
    printf 'not json' > "$CORTEX/skills.json"
    _prune
    [ "$status" -eq 0 ]
    [ "$(cat "$CORTEX/skills.json")" = "not json" ]
}

@test "cortex prune: cmd_setup calls it after registering skills, and never shells out to cortex remove" {
    run grep -c '_borg_cortex_prune_skills "\$COCO_DIR" "\$BORG_HOME/skills"' "$BORG_ZSH"
    [ "$output" = "1" ]
    run grep -c 'cortex skill remove' "$BORG_ZSH"
    [ "$output" = "0" ]
}
