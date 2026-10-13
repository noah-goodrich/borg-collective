#!/usr/bin/env bats
# S12 (borg-resume): launchd watcher job, installed lib layout, loud-failure of the dark hook, D10 allowlist merge.
# Directive: docs/plans/directives/2026-10-12-borg-resume-any-interruption.md (slice S12, Decision 10).
#
# Everything runs in a sandbox: HOME, XDG dirs, and launchctl/plutil stubs on PATH. install.sh and borg setup are
# NEVER run against the real HOME; their resume plumbing lives in lib/resume-install.sh and is exercised directly,
# under bash AND under zsh (the shell install.sh and borg.zsh source it with).

load test_helper/setup

ROOT="${BATS_TEST_DIRNAME}/.."
LIB="$ROOT/lib/resume-install.sh"
PLIST="$ROOT/launchd/borg.resume-watch.plist"
LABEL_LIB="$ROOT/lib/launchd-label.zsh"
HOOK="$ROOT/hooks/borg-resume-hook.sh"
REAL_BASE="$ROOT/config/claude/settings.base.json"
SID="00000000-0000-4000-8000-000000000001"

setup() {
    setup_temp_dirs
    command -v jq >/dev/null || skip "jq not installed"
    unset LAUNCHD_LABEL_PREFIX BORG_RESUME_DISABLE BORG_RESUME_LIBDIR BORG_RESUME_DIR BORG_RESUME_WATCH
    mkdir -p "$HOME/.claude" "$BATS_TEST_TMPDIR/stubbin"
    STUB="$BATS_TEST_TMPDIR/stubbin"
    CALLS="$BATS_TEST_TMPDIR/launchctl.calls"
    : >"$CALLS"
    cat >"$STUB/launchctl" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >>"$CALLS"
[ "\$1" = "list" ] && exit "\${STUB_LIST_RC:-1}"
[ "\$1" = "bootstrap" ] && exit "\${STUB_BOOTSTRAP_RC:-0}"
exit 0
EOF
    chmod +x "$STUB/launchctl"
    SETTINGS="$HOME/.claude/settings.json"
    export BORG_RESUME_BOOTOUT_POLLS=2 BORG_RESUME_RETRY_SLEEP=0
    BASE="$BATS_TEST_TMPDIR/base.json"
    printf '%s' '{"permissions":{"allow":["Bash(ls:*)","Bash(__HOME__/.claude/bin/borg-resume:*)",
"Bash(borg-resume:*)","Read(~/.local/state/borg/resume/**)"]}}' >"$BASE"
}

_stub_plutil() {
    printf '#!/bin/sh\nexit %s\n' "$1" >"$STUB/plutil"
    chmod +x "$STUB/plutil"
}

_agent() {
    bash -c ". '$LIB' && borg_resume_install_agent '$PLIST' borg.resume-watch '$HOME/Library/LaunchAgents' \
        '$HOME/logs' '$HOME/.claude/bin/borg-resume' '/opt/x/claude' '$HOME/.local/bin:/usr/bin'"
}

# The watcher installer, run under ZSH like install.sh runs it. claude is only reachable through the fallback dirs.
_zwatcher() {
    mkdir -p "$BATS_TEST_TMPDIR/cdir"
    printf '#!/bin/sh\nexit 0\n' >"$BATS_TEST_TMPDIR/cdir/claude"
    chmod +x "$BATS_TEST_TMPDIR/cdir/claude"
    PATH="$STUB:/usr/bin:/bin" BORG_CLAUDE_SEARCH_DIRS="$BATS_TEST_TMPDIR/nodir:$BATS_TEST_TMPDIR/cdir" \
        zsh -c "set -e; source '$LIB'; borg_resume_install_watcher '$ROOT' borg.resume-watch \
        '$HOME/Library/LaunchAgents' '$HOME/logs'"
}

_merge() { XDG_STATE_HOME="${MXDG:-}" bash -c ". '$LIB' && borg_merge_settings_allow '${2:-$BASE}' '$1' /dot"; }

# The REAL borg.zsh merge function (extracted, not reimplemented), run under zsh against the real base file.
_realmerge() {
    local fn="$BATS_TEST_TMPDIR/fn.zsh"
    sed -n '/^_borg_merge_settings_permissions() {/,/^}/p' "$ROOT/borg.zsh" >"$fn"
    XDG_STATE_HOME="${MXDG:-}" zsh -c "BORG_HOME='$ROOT'; info() { print -r -- \"\$*\"; }; warn() { print -r -- \"\$*\"; }; source '$fn'; \
        _borg_merge_settings_permissions '$REAL_BASE' '$1' /dot"
}

# ─── plist and label ──────────────────────────────────────────────────────────

@test "label: resume-watch resolves through the shared resolver" {
    run zsh -c "source '$LABEL_LIB' && _borg_launchd_label resume-watch"
    [ "$status" -eq 0 ]
    [ "$output" = "borg.resume-watch" ]
    mkdir -p "$XDG_CONFIG_HOME"
    printf 'com.example\n' >"$XDG_CONFIG_HOME/launchd-prefix"
    run zsh -c "source '$LABEL_LIB' && _borg_launchd_label resume-watch"
    [ "$output" = "com.example.borg.resume-watch" ]
}

@test "plist: template is StartInterval 30, RunAtLoad false, placeholders, stdout discarded" {
    run grep -c '{{LABEL}}' "$PLIST"
    [ "$output" = "1" ]
    grep -q '<integer>30</integer>' "$PLIST"
    grep -A1 'RunAtLoad' "$PLIST" | grep -q '<false/>'
    local p
    for p in RESUME_BIN CLAUDE_BIN PATH_VALUE LOG_DIR USER HOME XDG_STATE_HOME; do
        grep -q "{{$p}}" "$PLIST"
    done
    grep -q '<string>watch</string>' "$PLIST"
    grep -q '<string>--once</string>' "$PLIST"
    grep -A1 'StandardOutPath' "$PLIST" | grep -q '/dev/null'
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

@test "plist: XDG_STATE_HOME is forwarded so the watcher and the hook share one state dir" {
    _stub_plutil 0
    PATH="$STUB:$PATH" run _agent
    grep -A1 'XDG_STATE_HOME' "$HOME/Library/LaunchAgents/borg.resume-watch.plist" | grep -q "$XDG_STATE_HOME"
}

@test "agent: renders, bootstraps, and boots out first only when already loaded" {
    _stub_plutil 0
    PATH="$STUB:$PATH" STUB_LIST_RC=1 run _agent
    [ "$status" -eq 0 ]
    grep -q '^bootstrap gui/' "$CALLS"
    ! grep -q '^bootout' "$CALLS"
    : >"$CALLS"
    printf '\n<!-- changed -->\n' >>"$HOME/Library/LaunchAgents/borg.resume-watch.plist"
    PATH="$STUB:$PATH" STUB_LIST_RC=0 run _agent
    [ "$status" -eq 0 ]
    local b s
    b="$(grep -n '^bootout' "$CALLS" | cut -d: -f1)"
    s="$(grep -n '^bootstrap' "$CALLS" | cut -d: -f1)"
    [ -n "$b" ] && [ -n "$s" ] && [ "$b" -lt "$s" ]
}

@test "agent: loaded and byte-identical plist -> no reload at all" {
    _stub_plutil 0
    PATH="$STUB:$PATH" STUB_LIST_RC=1 run _agent
    : >"$CALLS"
    PATH="$STUB:$PATH" STUB_LIST_RC=0 run _agent
    [ "$status" -eq 0 ]
    [[ "$output" == *"unchanged"* ]]
    ! grep -q '^bootout' "$CALLS"
    ! grep -q '^bootstrap' "$CALLS"
}

@test "agent: a plist that fails plutil -lint is removed and never bootstrapped" {
    _stub_plutil 1
    PATH="$STUB:$PATH" run _agent
    [ "$status" -eq 0 ]
    [[ "$output" == *"fails plutil -lint"* ]]
    [ ! -e "$HOME/Library/LaunchAgents/borg.resume-watch.plist" ]
    ! grep -q '^bootstrap' "$CALLS"
}

@test "agent: a failing bootstrap is retried once, then warns loudly without failing the install" {
    _stub_plutil 0
    PATH="$STUB:$PATH" STUB_BOOTSTRAP_RC=5 run _agent
    [ "$status" -eq 0 ]
    [[ "$output" == *"bootstrap FAILED"* ]]
    [ "$(grep -c '^bootstrap' "$CALLS")" = "2" ]
}

# ─── the watcher installer, under zsh (what install.sh actually runs) ─────────

@test "watcher (zsh): finds claude through the fallback dirs, bakes it into BORG_CLAUDE_BIN and PATH, bootstraps" {
    _stub_plutil 0
    run _zwatcher
    [ "$status" -eq 0 ]
    local out="$HOME/Library/LaunchAgents/borg.resume-watch.plist"
    [ -f "$out" ]
    grep -A1 'BORG_CLAUDE_BIN' "$out" | grep -q "$BATS_TEST_TMPDIR/cdir/claude"
    grep -A1 '<key>PATH' "$out" | grep -q "$BATS_TEST_TMPDIR/cdir:"
    grep -q '^bootstrap gui/' "$CALLS"
}

@test "claude-bin (zsh): the colon-split fallback loop works when claude is not on PATH" {
    mkdir -p "$BATS_TEST_TMPDIR/cdir"
    printf '#!/bin/sh\n' >"$BATS_TEST_TMPDIR/cdir/claude"
    chmod +x "$BATS_TEST_TMPDIR/cdir/claude"
    run env PATH="/usr/bin:/bin" BORG_CLAUDE_SEARCH_DIRS="$BATS_TEST_TMPDIR/none:$BATS_TEST_TMPDIR/cdir" \
        zsh -c "source '$ROOT/lib/borg/claude-bin.sh'; borg_resolve_claude_bin && print -r -- \$BORG_CLAUDE_BIN"
    [ "$status" -eq 0 ]
    [ "$output" = "$BATS_TEST_TMPDIR/cdir/claude" ]
}

@test "watcher: BORG_RESUME_WATCH=0 installs nothing and boots out a loaded job" {
    _stub_plutil 0
    BORG_RESUME_WATCH=0 STUB_LIST_RC=1 run _zwatcher
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/Library/LaunchAgents/borg.resume-watch.plist" ]
    ! grep -q '^bootstrap' "$CALLS"
    : >"$CALLS"
    BORG_RESUME_WATCH=0 STUB_LIST_RC=0 run _zwatcher
    [ "$status" -eq 0 ]
    grep -q '^bootout' "$CALLS"
    ! grep -q '^bootstrap' "$CALLS"
}

@test "contract: install.sh resolves resume-watch through the label resolver, uses the watcher installer only" {
    grep -q '_borg_launchd_label resume-watch)' "$ROOT/install.sh"
    grep -q 'borg_resume_install_watcher' "$ROOT/install.sh"
    ! grep -q 'settings.json' <(sed -n '/4b. borg-resume/,/5. Plugin detection/p' "$ROOT/install.sh" | grep -v '^#')
}

@test "contract: borg setup installs lib/borg beside bin, and the settings merge is the shared symlink-safe one" {
    grep -q 'borg_resume_install_lib' "$ROOT/borg.zsh"
    sed -n '/^_borg_merge_settings_permissions() {/,/^}/p' "$ROOT/borg.zsh" | grep -q 'borg_merge_settings_allow'
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

@test "lib: a missing source dir returns non-zero" {
    run bash -c ". '$LIB' && borg_resume_install_lib '$BATS_TEST_TMPDIR/nope' '$HOME/.claude/lib/borg'"
    [ "$status" -ne 0 ]
}

@test "installed layout: watch --once runs from ~/.claude and really executes a watcher pass" {
    mkdir -p "$HOME/.claude/bin"
    cp "$ROOT/bin/borg-resume" "$HOME/.claude/bin/borg-resume"
    bash -c ". '$LIB' && borg_resume_install_lib '$ROOT/lib/borg' '$HOME/.claude/lib/borg'"
    # The installed layout also needs ~/.claude/lib/borg-hooks.sh (installed by a different loop in borg setup).
    [ -f "$ROOT/lib/borg-hooks.sh" ]
    cp "$ROOT/lib/borg-hooks.sh" "$HOME/.claude/lib/borg-hooks.sh"
    local jq_dir="${BATS_TEST_TMPDIR}/jqbin"
    mkdir -p "$jq_dir"
    ln -s "$(command -v jq)" "$jq_dir/jq"
    mkdir -p "$STUB" "$BATS_TEST_TMPDIR/state/borg/resume"
    printf '#!/bin/sh\nexit 1\n' >"$STUB/tmux"
    chmod +x "$STUB/tmux"
    run env -i HOME="$HOME" USER=nobody XDG_STATE_HOME="$XDG_STATE_HOME" BORG_IN_CONTAINER=0 \
        PATH="$STUB:$jq_dir:/usr/bin:/bin" "$HOME/.claude/bin/borg-resume" watch --once
    [ "$status" -eq 0 ]
    [[ "$output" == *"borg-resume watch:"* ]]
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

# ─── D10 allowlist, carried by the existing additive settings merge ───────────

@test "base: settings.base.json carries the three D10 entries (Bash entry with an __HOME__ placeholder)" {
    run jq -r '.permissions.allow[]' "$REAL_BASE"
    [[ "$output" == *'Bash(__HOME__/.claude/bin/borg-resume:*)'* ]]
    [[ "$output" == *'Bash(borg-resume:*)'* ]]
    [[ "$output" == *'Read(~/.local/state/borg/resume/**)'* ]]
}

@test "merge: adds the entries (home rendered absolute), keeps every other key and entry, backs up first" {
    printf '%s' '{"model":"opus","env":{"A":"1"},"permissions":{"allow":["Bash(zz:*)"],"deny":["Bash(rm:*)"]}}' \
        >"$SETTINGS"
    run _merge "$SETTINGS"
    [ "$status" -eq 0 ]
    run jq -c '.permissions.allow' "$SETTINGS"
    [ "$output" = '["Bash(zz:*)","Bash(ls:*)","Bash('"$HOME"'/.claude/bin/borg-resume:*)","Bash(borg-resume:*)",'\
'"Read(~/.local/state/borg/resume/**)"]' ]
    [ "$(jq -r '.model' "$SETTINGS")" = "opus" ]
    [ "$(jq -r '.env.A' "$SETTINGS")" = "1" ]
    [ "$(jq -c '.permissions.deny' "$SETTINGS")" = '["Bash(rm:*)"]' ]
    local b
    b="$(ls "$HOME"/.claude/settings.json.borg-bak.* | head -1)"
    [ "$(jq -c '.permissions.allow' "$b")" = '["Bash(zz:*)"]' ]
}

@test "merge: idempotent -- second run changes nothing, no duplicates, no second backup" {
    printf '%s' '{"permissions":{"allow":["Bash(zz:*)"]}}' >"$SETTINGS"
    _merge "$SETTINGS"
    local h1
    h1="$(cksum <"$SETTINGS")"
    sleep 1
    run _merge "$SETTINGS"
    [ "$(cksum <"$SETTINGS")" = "$h1" ]
    [ "$(ls "$HOME"/.claude/settings.json.borg-bak.* | wc -l | tr -d ' ')" = "1" ]
    [ "$(jq '.permissions.allow | length' "$SETTINGS")" = "5" ]
}

@test "merge: existing entries keep their order; only missing ones are appended" {
    printf '%s' '{"permissions":{"allow":["Bash(zz:*)","Bash(borg-resume:*)","Bash(aa:*)"]}}' >"$SETTINGS"
    _merge "$SETTINGS"
    run jq -c '.permissions.allow[0:3]' "$SETTINGS"
    [ "$output" = '["Bash(zz:*)","Bash(borg-resume:*)","Bash(aa:*)"]' ]
    [ "$(jq '.permissions.allow | length' "$SETTINGS")" = "6" ]
}

@test "merge: no permissions key at all -> created from the base" {
    printf '%s' '{"model":"opus"}' >"$SETTINGS"
    _merge "$SETTINGS"
    [ "$(jq '.permissions.allow | length' "$SETTINGS")" = "4" ]
    [ "$(jq -r '.model' "$SETTINGS")" = "opus" ]
}

@test "merge: BORG_RESUME_WATCH=0 opts out of the borg-resume entries but still merges the rest" {
    printf '%s' '{"permissions":{"allow":["Bash(zz:*)"]}}' >"$SETTINGS"
    BORG_RESUME_WATCH=0 run _merge "$SETTINGS"
    [ "$status" -eq 0 ]
    run jq -c '.permissions.allow' "$SETTINGS"
    [ "$output" = '["Bash(zz:*)","Bash(ls:*)"]' ]
}

@test "merge: XDG_STATE_HOME that is not the default rewrites the Read entry to match" {
    printf '%s' '{}' >"$SETTINGS"
    MXDG=/var/xs _merge "$SETTINGS"
    jq -e '.permissions.allow | index("Read(//var/xs/borg/resume/**)")' "$SETTINGS"
}

@test "merge (real borg.zsh function, real base): a symlinked settings.json stays a link, content written through" {
    mkdir -p "$BATS_TEST_TMPDIR/dotfiles"
    printf '%s' '{"model":"opus","permissions":{"allow":["Bash(zz:*)"]}}' >"$BATS_TEST_TMPDIR/dotfiles/settings.json"
    ln -s "$BATS_TEST_TMPDIR/dotfiles/settings.json" "$SETTINGS"
    run _realmerge "$SETTINGS"
    [ "$status" -eq 0 ]
    [ -L "$SETTINGS" ]
    [ "$(readlink "$SETTINGS")" = "$BATS_TEST_TMPDIR/dotfiles/settings.json" ]
    local t="$BATS_TEST_TMPDIR/dotfiles/settings.json"
    jq -e '.permissions.allow | index("Bash(borg-resume:*)")' "$t"
    jq -e '.permissions.allow | index("Bash('"$HOME"'/.claude/bin/borg-resume:*)")' "$t"
    jq -e '.permissions.allow | index("Read(~/.local/state/borg/resume/**)")' "$t"
    jq -e '.permissions.allow[0] == "Bash(zz:*)"' "$t"
    [ "$(jq -r '.model' "$t")" = "opus" ]
    [ -z "$(ls "$BATS_TEST_TMPDIR/dotfiles" | grep -v '^settings.json$')" ]
    ls "$HOME"/.claude/settings.json.borg-bak.* >/dev/null
}

@test "merge: a symlinked settings.json is written through and the link stays a link" {
    mkdir -p "$BATS_TEST_TMPDIR/dotfiles"
    printf '%s' '{"permissions":{"allow":["Bash(zz:*)"]}}' >"$BATS_TEST_TMPDIR/dotfiles/settings.json"
    ln -s "$BATS_TEST_TMPDIR/dotfiles/settings.json" "$SETTINGS"
    run _merge "$SETTINGS"
    [ "$status" -eq 0 ]
    [[ "$output" == *"symlink"* ]]
    [ -L "$SETTINGS" ]
    [ "$(readlink "$SETTINGS")" = "$BATS_TEST_TMPDIR/dotfiles/settings.json" ]
    [ "$(jq '.permissions.allow | length' "$BATS_TEST_TMPDIR/dotfiles/settings.json")" = "5" ]
    [ -z "$(ls "$BATS_TEST_TMPDIR/dotfiles" | grep -v '^settings.json$')" ]
}

@test "merge: a relative symlink resolves against the link's directory" {
    mkdir -p "$HOME/.claude/sub"
    printf '%s' '{}' >"$HOME/.claude/sub/real.json"
    ln -s sub/real.json "$SETTINGS"
    _merge "$SETTINGS"
    [ -L "$SETTINGS" ]
    [ "$(jq '.permissions.allow | length' "$HOME/.claude/sub/real.json")" = "4" ]
}

@test "merge: missing file -> nothing created, exit 0" {
    run _merge "$SETTINGS"
    [ "$status" -eq 0 ]
    [ ! -e "$SETTINGS" ]
}

@test "merge: invalid JSON -> fails, file byte-identical, no backup" {
    printf '%s' '{"permissions": {' >"$SETTINGS"
    run _merge "$SETTINGS"
    [ "$status" -ne 0 ]
    [ "$(cat "$SETTINGS")" = '{"permissions": {' ]
    ! ls "$HOME"/.claude/settings.json.borg-bak.* 2>/dev/null
    [ -z "$(ls -A "$HOME/.claude" | grep 'tmp')" ]
}

@test "merge: file mode is preserved" {
    printf '%s' '{}' >"$SETTINGS"
    chmod 600 "$SETTINGS"
    _merge "$SETTINGS"
    [ "$(stat -c %a "$SETTINGS" 2>/dev/null || stat -f %Lp "$SETTINGS")" = "600" ]
}
