#!/usr/bin/env bats
# S12 (borg-resume): launchd watcher job, installed lib layout, loud-failure of the dark hook, D10 allowlist merge.
# Directive: docs/plans/directives/2026-10-12-borg-resume-any-interruption.md (slice S12, Decision 10).
#
# Everything runs in a sandbox: HOME, XDG dirs, and launchctl/plutil stubs on PATH. install.sh and borg setup are
# NEVER run; their resume plumbing lives in lib/resume-install.sh and is exercised directly.

load test_helper/setup

ROOT="${BATS_TEST_DIRNAME}/.."
LIB="$ROOT/lib/resume-install.sh"
PLIST="$ROOT/launchd/borg.resume-watch.plist"
LABEL_LIB="$ROOT/lib/launchd-label.zsh"
HOOK="$ROOT/hooks/borg-resume-hook.sh"
SID="00000000-0000-4000-8000-000000000001"

setup() {
    setup_temp_dirs
    command -v jq >/dev/null || skip "jq not installed"
    unset LAUNCHD_LABEL_PREFIX BORG_RESUME_DISABLE BORG_RESUME_LIBDIR BORG_RESUME_DIR
    mkdir -p "$HOME/.claude" "$BATS_TEST_TMPDIR/stubbin"
    STUB="$BATS_TEST_TMPDIR/stubbin"
    CALLS="$BATS_TEST_TMPDIR/launchctl.calls"
    : >"$CALLS"
    cat >"$STUB/launchctl" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$CALLS"
[ "\$1" = "list" ] && exit "\${STUB_LIST_RC:-1}"
exit "\${STUB_BOOTSTRAP_RC:-0}"
EOF
    chmod +x "$STUB/launchctl"
    SETTINGS="$HOME/.claude/settings.json"
}

_stub_plutil() {
    printf '#!/bin/sh\nexit %s\n' "$1" >"$STUB/plutil"
    chmod +x "$STUB/plutil"
}

_agent() {
    bash -c ". '$LIB' && borg_resume_install_agent '$PLIST' borg.resume-watch '$HOME/Library/LaunchAgents' \
        '$HOME/logs' '$HOME/.claude/bin/borg-resume' '/opt/x/claude' '$HOME/.local/bin:/usr/bin'"
}

_merge() { bash -c ". '$LIB' && borg_resume_merge_allowlist '$1'"; }

# ─── plist and label ──────────────────────────────────────────────────────────

@test "label: resume-watch resolves through the shared resolver" {
    run zsh -c "source '$LABEL_LIB' && _borg_launchd_label resume-watch"
    [ "$status" -eq 0 ]
    [ "$output" = "borg.resume-watch" ]
    printf 'com.example\n' >"$XDG_CONFIG_HOME/launchd-prefix"
    mkdir -p "$XDG_CONFIG_HOME"
    run zsh -c "source '$LABEL_LIB' && _borg_launchd_label resume-watch"
    [ "$output" = "com.example.borg.resume-watch" ]
}

@test "plist: template is StartInterval 30, RunAtLoad false, placeholders for label, bin, claude, path, logs" {
    run grep -c '{{LABEL}}' "$PLIST"
    [ "$output" = "1" ]
    grep -q '<integer>30</integer>' "$PLIST"
    grep -A1 'RunAtLoad' "$PLIST" | grep -q '<false/>'
    local p
    for p in RESUME_BIN CLAUDE_BIN PATH_VALUE LOG_DIR USER HOME; do
        grep -q "{{$p}}" "$PLIST"
    done
    grep -q '<string>watch</string>' "$PLIST"
    grep -q '<string>--once</string>' "$PLIST"
}

@test "plist: rendered file lints with plutil when plutil exists" {
    command -v plutil >/dev/null || skip "plutil not available (non-macOS lane)"
    rm -f "$STUB/plutil"
    PATH="$STUB:$PATH" run _agent
    [ "$status" -eq 0 ]
    local out="$HOME/Library/LaunchAgents/borg.resume-watch.plist"
    [ -f "$out" ]
    ! grep -q '{{' "$out"
    plutil -lint "$out"
    grep -q '/opt/x/claude' "$out"
    grep -q "$HOME/.claude/bin/borg-resume" "$out"
}

@test "agent: renders, bootstraps, and boots out first only when already loaded" {
    _stub_plutil 0
    PATH="$STUB:$PATH" STUB_LIST_RC=1 run _agent
    [ "$status" -eq 0 ]
    grep -q '^bootstrap gui/' "$CALLS"
    ! grep -q '^bootout' "$CALLS"
    : >"$CALLS"
    PATH="$STUB:$PATH" STUB_LIST_RC=0 run _agent
    [ "$status" -eq 0 ]
    local b s
    b="$(grep -n '^bootout' "$CALLS" | cut -d: -f1)"
    s="$(grep -n '^bootstrap' "$CALLS" | cut -d: -f1)"
    [ -n "$b" ] && [ -n "$s" ] && [ "$b" -lt "$s" ]
}

@test "agent: a plist that fails plutil -lint is removed and never bootstrapped" {
    _stub_plutil 1
    PATH="$STUB:$PATH" run _agent
    [ "$status" -eq 0 ]
    [[ "$output" == *"fails plutil -lint"* ]]
    [ ! -e "$HOME/Library/LaunchAgents/borg.resume-watch.plist" ]
    ! grep -q '^bootstrap' "$CALLS"
}

@test "agent: a failing bootstrap warns but does not fail the install" {
    _stub_plutil 0
    PATH="$STUB:$PATH" STUB_BOOTSTRAP_RC=5 run _agent
    [ "$status" -eq 0 ]
    [[ "$output" == *"bootstrap failed"* ]]
}

@test "contract: install.sh resolves resume-watch through the label resolver and calls the installer" {
    grep -q '_borg_launchd_label resume-watch)' "$ROOT/install.sh"
    grep -q 'borg_resume_install_agent' "$ROOT/install.sh"
    grep -q 'borg_resume_merge_allowlist' "$ROOT/install.sh"
}

@test "contract: borg setup installs lib/borg beside bin" {
    grep -q 'borg_resume_install_lib' "$ROOT/borg.zsh"
}

# ─── installed layout ─────────────────────────────────────────────────────────

@test "lib: install copies every lib/borg/*.sh, is idempotent, and leaves no temp files" {
    bash -c ". '$LIB' && borg_resume_install_lib '$ROOT/lib/borg' '$HOME/.claude/lib/borg'"
    bash -c ". '$LIB' && borg_resume_install_lib '$ROOT/lib/borg' '$HOME/.claude/lib/borg'"
    local f
    for f in "$ROOT"/lib/borg/*.sh; do
        cmp -s "$f" "$HOME/.claude/lib/borg/${f##*/}"
    done
    [ -z "$(ls -A "$HOME/.claude/lib/borg" | grep '\.tmp\.')" ]
}

@test "installed layout: borg-resume watch --once runs from ~/.claude under a launchd-like environment" {
    mkdir -p "$HOME/.claude/bin"
    cp "$ROOT/bin/borg-resume" "$HOME/.claude/bin/borg-resume"
    bash -c ". '$LIB' && borg_resume_install_lib '$ROOT/lib/borg' '$HOME/.claude/lib/borg'"
    local jq_dir="${BATS_TEST_TMPDIR}/jqbin"
    mkdir -p "$jq_dir"
    ln -s "$(command -v jq)" "$jq_dir/jq"
    mkdir -p "$STUB" "$BATS_TEST_TMPDIR/state/borg/resume"
    printf '#!/bin/sh\nexit 1\n' >"$STUB/tmux"
    chmod +x "$STUB/tmux"
    run env -i HOME="$HOME" USER=nobody XDG_STATE_HOME="$XDG_STATE_HOME" BORG_IN_CONTAINER=0 \
        PATH="$STUB:$jq_dir:/usr/bin:/bin" "$HOME/.claude/bin/borg-resume" watch --once
    [ "$status" -eq 0 ]
}

# ─── the dark hook becomes loud ───────────────────────────────────────────────

@test "borg-resume record: exits 3 with a one-line stderr reason when it cannot load its lib" {
    local nolib="$BATS_TEST_TMPDIR/nolib"
    run bash -c "echo '{}' | BORG_RESUME_LIBDIR='$nolib' '$ROOT/bin/borg-resume' record session_start 2>&1 >/dev/null"
    [ "$output" != "" ]
    [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" = "1" ]
    [[ "$output" == *"resume-paths.sh"* ]]
    run bash -c "echo '{}' | BORG_RESUME_LIBDIR='$nolib' '$ROOT/bin/borg-resume' record session_start >/dev/null 2>&1"
    [ "$status" -eq 3 ]
}

@test "hook: with the lib missing, exits 0 and the failure lands in hook.log (log dir created)" {
    mkdir -p "$HOME/.claude/bin"
    ln -s "$ROOT/bin/borg-resume" "$HOME/.claude/bin/borg-resume"
    export BORG_RESUME_LIBDIR="$BATS_TEST_TMPDIR/nolib"
    export BORG_RESUME_DIR="$BATS_TEST_TMPDIR/fresh/resume"
    [ ! -e "$BATS_TEST_TMPDIR/fresh" ]
    run bash -c "printf '{\"session_id\":\"$SID\"}' | '$HOOK' SessionStart"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ -f "$BORG_RESUME_DIR/hook.log" ]
    grep -q 'session_start rc=3' "$BORG_RESUME_DIR/hook.log"
    grep -q 'resume-paths.sh' "$BORG_RESUME_DIR/hook.log"
}

# ─── D10 allowlist merge ──────────────────────────────────────────────────────

@test "merge: adds exactly the three entries, keeps every other key and entry, backs up first" {
    printf '%s' '{"model":"opus","env":{"A":"1"},"permissions":{"allow":["Bash(ls:*)"],"deny":["Bash(rm:*)"]}}' \
        >"$SETTINGS"
    run _merge "$SETTINGS"
    [ "$status" -eq 0 ]
    run jq -c '.permissions.allow' "$SETTINGS"
    [ "$output" = '["Bash(ls:*)","Bash(~/.claude/bin/borg-resume:*)","Bash(borg-resume:*)",'\
'"Read(~/.local/state/borg/resume/**)"]' ]
    [ "$(jq -r '.model' "$SETTINGS")" = "opus" ]
    [ "$(jq -r '.env.A' "$SETTINGS")" = "1" ]
    [ "$(jq -c '.permissions.deny' "$SETTINGS")" = '["Bash(rm:*)"]' ]
    local b
    b="$(ls "$HOME"/.claude/settings.json.borg-resume-bak.* | head -1)"
    [ "$(jq -c '.permissions.allow' "$b")" = '["Bash(ls:*)"]' ]
}

@test "merge: idempotent -- second run changes nothing, no duplicates, no second backup" {
    printf '%s' '{"permissions":{"allow":["Bash(ls:*)"]}}' >"$SETTINGS"
    _merge "$SETTINGS"
    local h1
    h1="$(cksum <"$SETTINGS")"
    sleep 1
    run _merge "$SETTINGS"
    [ "$(cksum <"$SETTINGS")" = "$h1" ]
    [ "$(ls "$HOME"/.claude/settings.json.borg-resume-bak.* | wc -l | tr -d ' ')" = "1" ]
    [ "$(jq '.permissions.allow | length' "$SETTINGS")" = "4" ]
}

@test "merge: only missing entries are added and an existing one is not duplicated or reordered" {
    printf '%s' '{"permissions":{"allow":["Bash(borg-resume:*)","Bash(ls:*)"]}}' >"$SETTINGS"
    _merge "$SETTINGS"
    run jq -c '.permissions.allow' "$SETTINGS"
    [ "$output" = '["Bash(borg-resume:*)","Bash(ls:*)","Bash(~/.claude/bin/borg-resume:*)",'\
'"Read(~/.local/state/borg/resume/**)"]' ]
}

@test "merge: no permissions key at all -> created with the three entries" {
    printf '%s' '{"model":"opus"}' >"$SETTINGS"
    _merge "$SETTINGS"
    [ "$(jq '.permissions.allow | length' "$SETTINGS")" = "3" ]
    [ "$(jq -r '.model' "$SETTINGS")" = "opus" ]
}

@test "merge: a symlinked settings.json is written through and the link stays a link" {
    mkdir -p "$BATS_TEST_TMPDIR/dotfiles"
    printf '%s' '{"permissions":{"allow":["Bash(ls:*)"]}}' >"$BATS_TEST_TMPDIR/dotfiles/settings.json"
    ln -s "$BATS_TEST_TMPDIR/dotfiles/settings.json" "$SETTINGS"
    run _merge "$SETTINGS"
    [ "$status" -eq 0 ]
    [[ "$output" == *"symlink"* ]]
    [ -L "$SETTINGS" ]
    [ "$(readlink "$SETTINGS")" = "$BATS_TEST_TMPDIR/dotfiles/settings.json" ]
    [ "$(jq '.permissions.allow | length' "$BATS_TEST_TMPDIR/dotfiles/settings.json")" = "4" ]
    [ -z "$(ls "$BATS_TEST_TMPDIR/dotfiles" | grep -v '^settings.json$')" ]
}

@test "merge: a relative symlink resolves against the link's directory" {
    mkdir -p "$HOME/.claude/sub"
    printf '%s' '{}' >"$HOME/.claude/sub/real.json"
    ln -s sub/real.json "$SETTINGS"
    _merge "$SETTINGS"
    [ -L "$SETTINGS" ]
    [ "$(jq '.permissions.allow | length' "$HOME/.claude/sub/real.json")" = "3" ]
}

@test "merge: missing file -> warns, creates nothing, exit 0" {
    run _merge "$SETTINGS"
    [ "$status" -eq 0 ]
    [[ "$output" == *"NOT merged"* ]]
    [ ! -e "$SETTINGS" ]
}

@test "merge: invalid JSON -> warns, file byte-identical, no backup, exit 0" {
    printf '%s' '{"permissions": {' >"$SETTINGS"
    run _merge "$SETTINGS"
    [ "$status" -eq 0 ]
    [[ "$output" == *"NOT merged"* ]]
    [ "$(cat "$SETTINGS")" = '{"permissions": {' ]
    ! ls "$HOME"/.claude/settings.json.borg-resume-bak.* 2>/dev/null
}

@test "merge: permissions.allow of the wrong type -> warns and changes nothing" {
    printf '%s' '{"permissions":{"allow":"nope"}}' >"$SETTINGS"
    run _merge "$SETTINGS"
    [[ "$output" == *"NOT merged"* ]]
    [ "$(cat "$SETTINGS")" = '{"permissions":{"allow":"nope"}}' ]
}

@test "merge: file mode is preserved" {
    printf '%s' '{}' >"$SETTINGS"
    chmod 600 "$SETTINGS"
    _merge "$SETTINGS"
    [ "$(stat -f %Lp "$SETTINGS" 2>/dev/null || stat -c %a "$SETTINGS")" = "600" ]
}

@test "merge: never writes a project-level settings file" {
    mkdir -p "$BATS_TEST_TMPDIR/proj/.claude"
    printf '%s' '{}' >"$SETTINGS"
    ( cd "$BATS_TEST_TMPDIR/proj" && _merge "$SETTINGS" )
    [ -z "$(ls -A "$BATS_TEST_TMPDIR/proj/.claude")" ]
}
