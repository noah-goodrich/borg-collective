#!/usr/bin/env bats
# `borg setup` adds BASH_MAX_OUTPUT_LENGTH and CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS under .env in
# ~/.claude/settings.json, only when absent (issue 500). The real lib/output-caps.zsh function and the real
# _borg_jq_rewrite (cut out of borg.zsh) run against a SCRATCH HOME; the real ~/.claude is never touched, and
# $HOME is asserted to be the scratch directory before anything runs.

load test_helper/setup

setup() {
    setup_temp_dirs
    [[ "$HOME" == "${BATS_TEST_TMPDIR}"* ]]
    mkdir -p "$HOME/.claude"
    SETTINGS="$HOME/.claude/settings.json"
}

_caps() {
    BORG_HOME="$BORG_HOME" run zsh -c '
        info() { echo "INFO: $*"; }; warn() { echo "WARN: $*"; }; die() { echo "DIE: $*"; exit 1; }
        eval "$(sed -n "/^_borg_jq_rewrite()/,/^}/p" "$BORG_HOME/borg.zsh")"
        source "$BORG_HOME/lib/output-caps.zsh"
        _borg_ensure_output_caps'
}

@test "output caps: absent keys are added as strings, one info line each" {
    printf '{"model":"opus"}\n' > "$SETTINGS"
    _caps
    [ "$status" -eq 0 ]
    [ "$(jq -r '.env.BASH_MAX_OUTPUT_LENGTH | type' "$SETTINGS")" = "string" ]
    [ "$(jq -r '.env.BASH_MAX_OUTPUT_LENGTH' "$SETTINGS")" = "12000" ]
    [ "$(jq -r '.env.CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS' "$SETTINGS")" = "8000" ]
    [ "${#lines[@]}" -eq 2 ]
}

@test "output caps: an existing different value is preserved" {
    printf '{"env":{"BASH_MAX_OUTPUT_LENGTH":"50000"}}\n' > "$SETTINGS"
    _caps
    [ "$status" -eq 0 ]
    [ "$(jq -r '.env.BASH_MAX_OUTPUT_LENGTH' "$SETTINGS")" = "50000" ]
    [ "$(jq -r '.env.CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS' "$SETTINGS")" = "8000" ]
}

@test "output caps: other settings and other env keys are preserved" {
    printf '{"model":"opus","permissions":{"allow":["Bash(ls:*)"]},"env":{"FOO":"bar"}}\n' > "$SETTINGS"
    _caps
    [ "$status" -eq 0 ]
    [ "$(jq -r '.model' "$SETTINGS")" = "opus" ]
    [ "$(jq -c '.permissions' "$SETTINGS")" = '{"allow":["Bash(ls:*)"]}' ]
    [ "$(jq -r '.env.FOO' "$SETTINGS")" = "bar" ]
}

@test "output caps: a second run changes nothing and prints nothing" {
    printf '{"model":"opus"}\n' > "$SETTINGS"
    _caps
    cp "$SETTINGS" "$BATS_TEST_TMPDIR/settings.1"
    _caps
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    cmp "$SETTINGS" "$BATS_TEST_TMPDIR/settings.1"
}

@test "output caps: creates settings.json when there is none, like the statusline writer" {
    [ ! -e "$SETTINGS" ]
    _caps
    [ "$status" -eq 0 ]
    [ "$(jq -c '.env' "$SETTINGS")" = '{"BASH_MAX_OUTPUT_LENGTH":"12000","CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS":"8000"}' ]
    [ -z "$(ls "$HOME/.claude" | grep tmp)" ]
}

@test "output caps: a symlinked settings.json keeps its link and the target is written" {
    mkdir -p "$HOME/dot"
    printf '{"model":"opus"}\n' > "$HOME/dot/settings.json"
    ln -s "$HOME/dot/settings.json" "$SETTINGS"
    _caps
    [ "$status" -eq 0 ]
    [ -L "$SETTINGS" ]
    [ "$(jq -r '.env.BASH_MAX_OUTPUT_LENGTH' "$HOME/dot/settings.json")" = "12000" ]
}

@test "output caps: a settings file that is not an object is left byte for byte" {
    printf '[1,2]\n' > "$SETTINGS"
    cp "$SETTINGS" "$BATS_TEST_TMPDIR/before"
    _caps
    [ "$status" -eq 0 ]
    cmp "$SETTINGS" "$BATS_TEST_TMPDIR/before"
}

@test "output caps: cmd_setup calls the function on plain setup, not behind a flag" {
    run grep -n "^    _borg_ensure_output_caps$" "$BORG_HOME/borg.zsh"
    [ "$status" -eq 0 ]
}
