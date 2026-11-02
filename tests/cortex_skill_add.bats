#!/usr/bin/env bats
# borg setup used to run `cortex skill add ... 2>/dev/null`, so a skill Cortex refused (a folded description, a bad
# frontmatter) vanished without a word. _borg_cortex_skill_add keeps the first useful line of what cortex said, and
# _borg_cortex_skill_summary names every failed skill once. Both call sites in cmd_setup (core skills, extension
# skills) go through them.
#
# THE HAZARD: these cases never run borg setup or the real cortex. `cortex` is a stub on PATH and HOME is the sandbox
# (setup_temp_dirs); they source borg.zsh and call the two helpers the way cmd_setup's loops do.

load test_helper/setup

BORG_ZSH="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs
    STUB_BIN="${BATS_TEST_TMPDIR}/stubbin"
    SKILLS="${BATS_TEST_TMPDIR}/skills"
    CALLS="${BATS_TEST_TMPDIR}/calls"
    mkdir -p "$STUB_BIN" "$SKILLS/alpha" "$SKILLS/bravo" "$SKILLS/charlie"
    : > "$CALLS"
    # Fails for `bravo` (and `charlie` when FAIL_ALSO=charlie) with a leading blank line, then the known message.
    cat > "$STUB_BIN/cortex" <<'EOF'
#!/bin/sh
echo "$3" >> "$CALLS"
d="${3%/}"
case "${d##*/}" in
    bravo|"$FAIL_ALSO")
        printf '\n  Error: Invalid YAML in SKILL.md frontmatter\nsecond line\n' >&2
        exit 1 ;;
esac
exit 0
EOF
    chmod +x "$STUB_BIN/cortex"
    export CALLS FAIL_ALSO=""
}

# The loop cmd_setup runs for the core skills, using the helpers it calls.
_register() {
    BORG_PATH_PREFIX="$STUB_BIN" run zsh -c "
        source '$BORG_ZSH' >/dev/null 2>&1 || true
        warn() { print -r -- \"WARN: \$*\"; }
        info() { print -r -- \"INFO: \$*\"; }
        for skill_dir in '$SKILLS'/*/(N); do
            name=\${skill_dir:t}
            _borg_cortex_skill_add \"\$skill_dir\" && info \"  \$name (cortex)\"
        done
        _borg_cortex_skill_summary
    "
}

@test "cortex skill add: the sandbox HOME is not the real home and cortex is the stub" {
    [ "$HOME" = "$BORG_TEST_HOME" ]
    [ "$(PATH="$STUB_BIN:$PATH" command -v cortex)" = "$STUB_BIN/cortex" ]
}

@test "cortex skill add: a failure prints the first useful stderr line, not the blank one before it" {
    _register
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARN:   bravo: cortex skill add failed: Error: Invalid YAML in SKILL.md frontmatter"* ]] || {
        echo "$output"; false; }
    [[ "$output" != *"second line"* ]] || false
}

@test "cortex skill add: setup continues past the failure and the summary names the failed skill" {
    _register
    [ "$(wc -l < "$CALLS" | tr -d ' ')" -eq 3 ]
    [[ "$output" == *"INFO:   alpha (cortex)"* ]] || false
    [[ "$output" == *"INFO:   charlie (cortex)"* ]] || false
    [[ "$output" != *"INFO:   bravo (cortex)"* ]] || false
    [[ "$output" == *"WARN:   cortex skill add failed for 1 skill(s): bravo"* ]] || { echo "$output"; false; }
}

@test "cortex skill add: the summary counts and names every failure" {
    FAIL_ALSO=charlie _register
    [[ "$output" == *"failed for 2 skill(s): bravo, charlie"* ]] || { echo "$output"; false; }
}

@test "cortex skill add: no failure means no warning and no summary" {
    rm -r "${SKILLS:?}/bravo"
    _register
    [[ "$output" != *"WARN"* ]] || { echo "$output"; false; }
    [[ "$output" == *"INFO:   alpha (cortex)"* ]] || false
}

@test "cortex skill add: the summary clears, so the extension loop does not repeat the core failures" {
    BORG_PATH_PREFIX="$STUB_BIN" run zsh -c "
        source '$BORG_ZSH' >/dev/null 2>&1 || true
        warn() { print -r -- \"WARN: \$*\"; }
        _borg_cortex_skill_add '$SKILLS/bravo' || true
        _borg_cortex_skill_summary
        _borg_cortex_skill_add '$SKILLS/alpha' || true
        _borg_cortex_skill_summary
    "
    [ "$(printf '%s\n' "$output" | grep -c 'failed for')" -eq 1 ]
}

@test "cortex skill add: neither call site in cmd_setup discards stderr any more" {
    ! grep -n 'cortex skill add .*2>/dev/null' "$BORG_ZSH"
}
