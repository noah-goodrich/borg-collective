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

@test "statusline: a symlinked settings.json stays a symlink and its target carries the change" {
    mkdir -p "$HOME/dotfiles"
    printf '{"model":"opus"}\n' > "$HOME/dotfiles/settings.json"
    ln -s "$HOME/dotfiles/settings.json" "$SETTINGS"
    run zsh "$BORG" setup --statusline
    [ "$status" -eq 0 ]
    [ -L "$SETTINGS" ]
    [ "$(jq -r '.statusLine.command' "$HOME/dotfiles/settings.json")" = "$SCRIPT" ]
    [ "$(jq -r '.model' "$HOME/dotfiles/settings.json")" = "opus" ]
    run zsh "$BORG" setup --statusline=off
    [ "$status" -eq 0 ]
    [ -L "$SETTINGS" ]
    [ "$(jq -r 'has("statusLine")' "$HOME/dotfiles/settings.json")" = "false" ]
}

# #503: the installed statusline also writes the context record hooks/tool-count-nudge.sh reads.
_run_installed_statusline() {
    zsh "$BORG" setup --statusline
    export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/cache"
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$BATS_TEST_TMPDIR/bin/borg"
    chmod +x "$BATS_TEST_TMPDIR/bin/borg"
    run bash -c "printf '%s' '$1' | PATH='$BATS_TEST_TMPDIR/bin:$PATH' '$SCRIPT'"
}

@test "statusline: writes {session_id, total_input_tokens, used_percentage} atomically to the per-session cache file" {
    _run_installed_statusline '{"session_id":"sess-9","model":{"display_name":"Opus"},"context_window":{"used_percentage":64.2,"total_input_tokens":128400}}'
    [ "$status" -eq 0 ]
    [ "${lines[1]}" = "[Opus] ctx 64%" ]
    local file="$XDG_CACHE_HOME/borg/context/sess-9.json"
    [ "$(jq -c '.' "$file")" = '{"session_id":"sess-9","total_input_tokens":128400,"used_percentage":64.2}' ]
    [ -z "$(ls -A "$XDG_CACHE_HOME/borg/context" | grep -v '^sess-9.json$')" ]
}

@test "statusline: no session_id writes no file, and null fields become 0" {
    _run_installed_statusline '{"model":{"display_name":"Opus"},"context_window":{}}'
    [ "$status" -eq 0 ]
    [ ! -d "$XDG_CACHE_HOME/borg/context" ]
    _run_installed_statusline '{"session_id":"early","context_window":{"used_percentage":null,"total_input_tokens":null}}'
    [ "$(jq -c '.' "$XDG_CACHE_HOME/borg/context/early.json")" = '{"session_id":"early","total_input_tokens":0,"used_percentage":0}' ]
}

@test "statusline: a session id with path characters cannot escape the context directory" {
    _run_installed_statusline '{"session_id":"../../evil","context_window":{"total_input_tokens":5}}'
    [ "$status" -eq 0 ]
    [ -f "$XDG_CACHE_HOME/borg/context/______evil.json" ]
    [ ! -e "$XDG_CACHE_HOME/evil.json" ]
}

@test "statusline: an unchanged record is not rewritten, and an unwritable cache dir stays silent" {
    _run_installed_statusline '{"session_id":"same","context_window":{"total_input_tokens":5}}'
    local file="$XDG_CACHE_HOME/borg/context/same.json"
    touch -t 200001010000 "$file"
    _run_installed_statusline '{"session_id":"same","context_window":{"total_input_tokens":5}}'
    [ "$(stat -f %Sm -t %Y "$file" 2>/dev/null || stat -c %y "$file" | cut -c1-4)" = "2000" ]
    rm -f "$file"
    printf 'x' > "$BATS_TEST_TMPDIR/blocker"
    export XDG_CACHE_HOME="$BATS_TEST_TMPDIR/blocker"
    run bash -c "printf '%s' '{\"session_id\":\"s\",\"context_window\":{}}' | PATH='$BATS_TEST_TMPDIR/bin:$PATH' '$SCRIPT'"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
}
