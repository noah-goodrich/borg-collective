#!/usr/bin/env bats
# `borg setup --statusline[=off] [--force]` (doorways S4, AC4). OPT-IN: plain `borg setup` never writes `statusLine`.
# EVERY CASE RUNS AGAINST A SCRATCH HOME (setup_temp_dirs redirects HOME). The real ~/.claude is never touched, and
# `$HOME` is asserted to be the scratch directory before anything runs, so a broken sandbox fails loudly first.

load test_helper/setup

BORG="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs
    [[ "$HOME" == "${BATS_TEST_TMPDIR}"* ]]
    mkdir -p "$HOME/.claude"
    SETTINGS="$HOME/.claude/settings.json"
    SCRIPT="$HOME/.claude/borg-statusline.sh"
}

@test "statusline: installs the script and the statusLine key, keeping every other key" {
    printf '{"model":"opus","permissions":{"allow":["Bash(ls:*)"]},"hooks":{"Stop":[]}}\n' > "$SETTINGS"
    run zsh "$BORG" setup --statusline
    [ "$status" -eq 0 ]
    [ -x "$SCRIPT" ]
    [ "$(jq -r '.statusLine.type' "$SETTINGS")" = "command" ]
    [ "$(jq -r '.statusLine.command' "$SETTINGS")" = "$SCRIPT" ]
    [ "$(jq -c '.permissions' "$SETTINGS")" = '{"allow":["Bash(ls:*)"]}' ]
    [ "$(jq -r '.model' "$SETTINGS")" = "opus" ]
    [ "$(jq -c '.hooks' "$SETTINGS")" = '{"Stop":[]}' ]
}

@test "statusline: creates settings.json when there is none" {
    [ ! -e "$SETTINGS" ]
    run zsh "$BORG" setup --statusline
    [ "$status" -eq 0 ]
    [ "$(jq -r '.statusLine.command' "$SETTINGS")" = "$SCRIPT" ]
}

@test "statusline: a second run changes nothing" {
    printf '{"model":"opus"}\n' > "$SETTINGS"
    run zsh "$BORG" setup --statusline
    [ "$status" -eq 0 ]
    cp "$SETTINGS" "$BATS_TEST_TMPDIR/settings.1"
    cp "$SCRIPT" "$BATS_TEST_TMPDIR/script.1"
    run zsh "$BORG" setup --statusline
    [ "$status" -eq 0 ]
    [[ "$output" == *"already installed"* ]]
    cmp "$SETTINGS" "$BATS_TEST_TMPDIR/settings.1"
    cmp "$SCRIPT" "$BATS_TEST_TMPDIR/script.1"
}

@test "statusline: a statusLine that is not borg's is refused without --force, and left byte for byte" {
    printf '{"statusLine":{"type":"command","command":"~/mine.sh"},"model":"opus"}\n' > "$SETTINGS"
    cp "$SETTINGS" "$BATS_TEST_TMPDIR/before"
    run zsh "$BORG" setup --statusline
    [ "$status" -eq 1 ]
    [[ "$output" == *"--force"* ]]
    cmp "$SETTINGS" "$BATS_TEST_TMPDIR/before"
    [ ! -e "$SCRIPT" ]
}

@test "statusline: --force replaces a statusLine that is not borg's" {
    printf '{"statusLine":{"type":"command","command":"~/mine.sh"},"model":"opus"}\n' > "$SETTINGS"
    run zsh "$BORG" setup --statusline --force
    [ "$status" -eq 0 ]
    [ "$(jq -r '.statusLine.command' "$SETTINGS")" = "$SCRIPT" ]
    [ "$(jq -r '.model' "$SETTINGS")" = "opus" ]
}

@test "statusline: a settings file that is not JSON is left untouched" {
    printf 'not json\n' > "$SETTINGS"
    run zsh "$BORG" setup --statusline
    [ "$status" -ne 0 ]
    [ "$(cat "$SETTINGS")" = "not json" ]
}

@test "statusline=off: removes borg's key and script, keeps the rest" {
    printf '{"model":"opus"}\n' > "$SETTINGS"
    zsh "$BORG" setup --statusline
    run zsh "$BORG" setup --statusline=off
    [ "$status" -eq 0 ]
    [ ! -e "$SCRIPT" ]
    [ "$(jq -c 'has("statusLine")' "$SETTINGS")" = "false" ]
    [ "$(jq -r '.model' "$SETTINGS")" = "opus" ]
}

@test "statusline=off: never removes a statusLine that is not borg's, even with --force" {
    printf '{"statusLine":{"type":"command","command":"~/mine.sh"}}\n' > "$SETTINGS"
    cp "$SETTINGS" "$BATS_TEST_TMPDIR/before"
    run zsh "$BORG" setup --statusline=off --force
    [ "$status" -eq 0 ]
    cmp "$SETTINGS" "$BATS_TEST_TMPDIR/before"
}

@test "statusline=off: with nothing installed it is a no-op" {
    run zsh "$BORG" setup --statusline=off
    [ "$status" -eq 0 ]
    [ ! -e "$SETTINGS" ]
}

@test "statusline: the installed script prints the borg line, then the model and context from stdin" {
    zsh "$BORG" setup --statusline
    mkdir -p "$XDG_STATE_HOME/borg"
    printf '%s\t%s\n' "$(date +%s)" "▶ merge #440 · borg-collective · 4 waiting" > "$XDG_STATE_HOME/borg/next-glance"
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/usr/bin/env bash\nexec zsh "%s" "$@"\n' "$BORG" > "$BATS_TEST_TMPDIR/bin/borg"
    chmod +x "$BATS_TEST_TMPDIR/bin/borg"
    run bash -c "printf '%s' '{\"model\":{\"display_name\":\"Opus\"},\"context_window\":{\"used_percentage\":37.6}}' | PATH='$BATS_TEST_TMPDIR/bin:$PATH' '$SCRIPT'"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "▶ merge #440 · borg-collective · 4 waiting" ]
    [ "${lines[1]}" = "[Opus] ctx 37%" ]
}

@test "statusline: plain borg setup (the wizard body) never names statusLine" {
    run bash -c "sed -n '/^cmd_setup() {/,/^}/p' '$BORG' | grep -c 'statusLine'"
    [ "$output" = "0" ]
}

@test "statusline: --force without --statusline is refused" {
    run zsh "$BORG" setup --force
    [ "$status" -ne 0 ]
}
