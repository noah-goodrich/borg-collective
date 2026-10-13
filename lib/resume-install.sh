#!/usr/bin/env bash
# resume-install.sh -- install-time helpers for borg-resume (slice S12). Sourced by install.sh and borg.zsh
# (zsh) and by tests (bash 3.2). Nothing runs on source. Every function is fail-soft: a problem is reported
# on stdout and returned, never fatal, so an install under `set -e` never dies halfway on resume plumbing.
#
#   borg_resume_install_lib <src_dir> <dest_dir>      copy lib/borg/*.sh into <dest_dir> (atomic per file);
#                                                     returns 1 if any file could not be installed
#   borg_merge_settings_allow <base> <target> <dotfiles_dir>
#                                                     additive union of base permissions.allow into <target>;
#                                                     symlink-safe, backed up when it changes (used by borg setup)
#   borg_resume_install_agent <plist_src> <label> <la_dir> <log_dir> <bin> <claude_bin> <path_value>
#                                                     render, lint, reload, bootstrap the watcher job
#   borg_resume_install_watcher <borg_home> <label> <la_dir> <log_dir>
#                                                     resolve claude + PATH, then install the agent
#                                                     (BORG_RESUME_WATCH=0 boots the job out instead)

_ri_say() {
    if typeset -f info >/dev/null 2>&1; then info "$@"; else printf '%s\n' "$*"; fi
}

_ri_warn() {
    if typeset -f warn >/dev/null 2>&1; then warn "$@"; else printf 'warning: %s\n' "$*"; fi
}

borg_resume_install_lib() {
    local _src="$1" _dest="$2" _f _n=0 _bad=0 _tmp
    if [ ! -d "$_src" ]; then
        _ri_warn "borg-resume lib source not found: $_src"
        return 1
    fi
    mkdir -p "$_dest" || return 1
    while IFS= read -r _f; do
        [ -n "$_f" ] || continue
        _tmp="$_dest/.${_f##*/}.tmp.$$"
        if cp "$_f" "$_tmp" 2>/dev/null && chmod 644 "$_tmp" && mv -f "$_tmp" "$_dest/${_f##*/}"; then
            _n=$((_n + 1))
        else
            rm -f "$_tmp"
            _bad=$((_bad + 1))
            _ri_warn "could not install ${_f##*/} into $_dest"
        fi
    done <<EOF
$(find "$_src" -maxdepth 1 -type f -name '*.sh' | sort)
EOF
    _ri_say "  $_n borg lib file(s) -> $_dest"
    [ "$_bad" -eq 0 ]
}

# Follow a chain of symlinks to the real file path. Prints the final path; absolute-izes relative links.
_ri_resolve_link() {
    local _p="$1" _l _i=0
    while [ -L "$_p" ] && [ "$_i" -lt 16 ]; do
        _l="$(readlink "$_p")" || break
        case "$_l" in
            /*) _p="$_l" ;;
            *) _p="${_p%/*}/$_l" ;;
        esac
        _i=$((_i + 1))
    done
    printf '%s\n' "$_p"
}

# Render the base settings: __DOTFILES_DIR__ and __HOME__ placeholders, and the borg-resume state-dir Read entry
# follows XDG_STATE_HOME when that is set to something other than the default (a //abs path in permission syntax).
_ri_render_base() {
    local _base="$1" _dot="$2" _xdg="${XDG_STATE_HOME:-}" _out
    _out="$(sed -e "s|__DOTFILES_DIR__|$_dot|g" -e "s|__HOME__|${HOME:-}|g" "$_base")" || return 1
    if [ -n "$_xdg" ] && [ "$_xdg" != "${HOME:-}/.local/state" ]; then
        _out="$(printf '%s\n' "$_out" | sed -e "s|Read(~/.local/state/borg/resume/|Read(/$_xdg/borg/resume/|")"
    fi
    printf '%s\n' "$_out"
}

borg_merge_settings_allow() {
    local _base="$1" _link="$2" _dot="${3:-}" _target _base_json _before _after _tmp _bak _ts _drop=0
    [ -f "$_base" ] && [ -f "$_link" ] || return 0
    _target="$(_ri_resolve_link "$_link")"
    [ -f "$_target" ] || return 0
    _base_json="$(_ri_render_base "$_base" "$_dot")" || return 1
    # BORG_RESUME_WATCH=0 is the install-time opt-out: the borg-resume allowlist entries are not merged.
    [ "${BORG_RESUME_WATCH:-1}" = "0" ] && _drop=1
    _tmp="$_target.borg-merge.tmp.$$"
    _before="$(jq -c '.permissions.allow // []' "$_target" 2>/dev/null)" || return 1
    # cp -p keeps mode and owner; the redirect below rewrites only the content.
    cp -p "$_target" "$_tmp" 2>/dev/null || return 1
    # Additive and order-preserving: live entries keep their position, missing base entries are appended.
    if ! jq --argjson base "$_base_json" --argjson drop "$_drop" '
        (.permissions.allow // []) as $live
        | ($base.permissions.allow // []
            | map(select($drop == 0 or (test("borg-resume|borg/resume") | not)))) as $new
        | .permissions.allow = ($live + ($new - $live))
    ' "$_target" >"$_tmp" 2>/dev/null; then
        rm -f "$_tmp"
        return 1
    fi
    _after="$(jq -c '.permissions.allow' "$_tmp")"
    if [ "$_before" = "$_after" ]; then
        rm -f "$_tmp"
        return 0
    fi
    # The backup sits beside the path the user knows (the link), not inside a dotfiles repo it points into.
    _ts="$(date +%Y%m%d-%H%M%S)"
    _bak="${_link}.borg-bak.$_ts"
    if ! cp -p "$_target" "$_bak" 2>/dev/null; then
        rm -f "$_tmp"
        _ri_warn "could not back up $_link -- permissions NOT merged"
        return 1
    fi
    # mv onto the RESOLVED target: a settings.json symlink is written through, never replaced by a plain file.
    if ! mv -f "$_tmp" "$_target"; then
        rm -f "$_tmp"
        return 1
    fi
    [ -L "$_link" ] && _ri_say "  settings.json is a symlink: wrote through to $_target (link left intact)"
    _ri_say "  settings.json permissions merged (backup: $_bak)"
    return 0
}

_ri_is_loaded() { launchctl list "$1" >/dev/null 2>&1; }

# Boot a job out and wait for launchd to drop it (bootout is async; an immediate bootstrap can fail with EIO).
_ri_bootout_wait() {
    local _label="$1" _i=0 _max="${BORG_RESUME_BOOTOUT_POLLS:-25}"
    launchctl bootout "gui/$(id -u)/$_label" 2>/dev/null || true
    while _ri_is_loaded "$_label" && [ "$_i" -lt "$_max" ]; do
        sleep 0.2
        _i=$((_i + 1))
    done
    if _ri_is_loaded "$_label"; then
        _ri_warn "  $_label still loaded after bootout; continuing"
        return 1
    fi
    return 0
}

borg_resume_install_agent() {
    local _src="$1" _label="$2" _la="$3" _logs="$4" _bin="$5" _claude="$6" _path="$7" _dest _new _state
    _dest="$_la/$_label.plist"
    if [ ! -f "$_src" ]; then
        _ri_warn "resume-watch plist template missing: $_src -- skipped"
        return 0
    fi
    mkdir -p "$_la" "$_logs" || return 0
    _state="${XDG_STATE_HOME:-${HOME:-}/.local/state}"
    _new="$_dest.new.$$"
    sed \
        -e "s|{{LABEL}}|$_label|g" \
        -e "s|{{RESUME_BIN}}|$_bin|g" \
        -e "s|{{CLAUDE_BIN}}|$_claude|g" \
        -e "s|{{LOG_DIR}}|$_logs|g" \
        -e "s|{{USER}}|${USER:-}|g" \
        -e "s|{{HOME}}|$HOME|g" \
        -e "s|{{XDG_STATE_HOME}}|$_state|g" \
        -e "s|{{PATH_VALUE}}|$_path|g" \
        "$_src" >"$_new"
    if command -v plutil >/dev/null 2>&1 && ! plutil -lint "$_new" >/dev/null 2>&1; then
        _ri_warn "  resume-watch: rendered plist fails plutil -lint -- skipped, NOT bootstrapped ($_dest)"
        rm -f "$_new" "$_dest"
        return 0
    fi
    if _ri_is_loaded "$_label" && [ -f "$_dest" ] && cmp -s "$_new" "$_dest"; then
        rm -f "$_new"
        _ri_say "  launchd agent already loaded and unchanged: $_label"
        return 0
    fi
    mv -f "$_new" "$_dest"
    _ri_say "  plist -> $_dest"
    if _ri_is_loaded "$_label"; then
        _ri_say "  reloading launchd agent..."
        _ri_bootout_wait "$_label" || true
    fi
    if launchctl bootstrap "gui/$(id -u)" "$_dest" 2>/dev/null; then
        _ri_say "  launchd agent bootstrapped: $_label (every 30s)"
        return 0
    fi
    # One retry: launchd can still be tearing the old job down.
    sleep "${BORG_RESUME_RETRY_SLEEP:-1}"
    if launchctl bootstrap "gui/$(id -u)" "$_dest" 2>/dev/null; then
        _ri_say "  launchd agent bootstrapped on retry: $_label (every 30s)"
    else
        _ri_warn "  launchctl bootstrap FAILED for $_label; the watcher is NOT running (plist left at $_dest)"
    fi
    return 0
}

# Resolve claude and the job PATH under whichever shell sourced us (bash or zsh), then install the agent.
# BORG_RESUME_WATCH=0: boot the job out if loaded and install nothing (the allowlist merge honours it too).
borg_resume_install_watcher() {
    local _home="$1" _label="$2" _la="$3" _logs="$4" _claude="" _pv _dir
    if [ "${BORG_RESUME_WATCH:-1}" = "0" ]; then
        _ri_say "  BORG_RESUME_WATCH=0: borg-resume watcher not installed"
        # Persist the opt-out so `borg doctor` in a fresh shell knows it was deliberate.
        mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/borg/resume" 2>/dev/null &&
            : >"${XDG_STATE_HOME:-$HOME/.local/state}/borg/resume/WATCH_OPTOUT" 2>/dev/null
        if _ri_is_loaded "$_label"; then
            _ri_say "  booting out the already-loaded watcher: $_label"
            _ri_bootout_wait "$_label" || true
        fi
        return 0
    fi
    rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/borg/resume/WATCH_OPTOUT" 2>/dev/null
    if [ -f "$_home/lib/borg/claude-bin.sh" ]; then
        # shellcheck source=/dev/null
        . "$_home/lib/borg/claude-bin.sh" 2>/dev/null
        borg_resolve_claude_bin 2>/dev/null && _claude="$BORG_CLAUDE_BIN"
    fi
    [ -n "$_claude" ] || _ri_warn "  claude not found: the watcher will run without BORG_CLAUDE_BIN"
    _pv="$HOME/.claude/bin:$HOME/.local/bin"
    if [ -n "$_claude" ]; then
        _dir="${_claude%/*}"
        _pv="$_pv:$_dir"
    fi
    _pv="$_pv:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
    borg_resume_install_agent "$_home/launchd/borg.resume-watch.plist" "$_label" "$_la" "$_logs" \
        "$HOME/.claude/bin/borg-resume" "$_claude" "$_pv"
}
