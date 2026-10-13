#!/usr/bin/env bash
# resume-install.sh -- install-time helpers for borg-resume (slice S12). Sourced by install.sh and borg.zsh
# (zsh) and by tests (bash 3.2). Nothing runs on source. Every function is fail-soft: a problem is reported
# on stdout and returned, never fatal, so an install under `set -e` never dies halfway on resume plumbing.
#
#   borg_resume_install_lib <src_dir> <dest_dir>      copy lib/borg/*.sh into <dest_dir> (atomic per file)
#   borg_resume_merge_allowlist <settings.json>       idempotently add the three D10 allow entries
#   borg_resume_install_agent <plist_src> <label> <la_dir> <log_dir> <bin> <claude_bin> <path_value>
#                                                     render, lint, bootout-if-loaded, bootstrap the watcher job

BORG_RESUME_ALLOW_BASH_ABS='Bash(~/.claude/bin/borg-resume:*)'
BORG_RESUME_ALLOW_BASH_BARE='Bash(borg-resume:*)'
BORG_RESUME_ALLOW_READ='Read(~/.local/state/borg/resume/**)'

_ri_say() {
    if type info >/dev/null 2>&1; then info "$@"; else printf '%s\n' "$*"; fi
}

_ri_warn() {
    if type warn >/dev/null 2>&1; then warn "$@"; else printf 'warning: %s\n' "$*"; fi
}

borg_resume_install_lib() {
    local _src="$1" _dest="$2" _f _n=0 _tmp
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
            _ri_warn "could not install ${_f##*/} into $_dest"
        fi
    done <<EOF
$(find "$_src" -maxdepth 1 -type f -name '*.sh' | sort)
EOF
    _ri_say "  $_n borg lib file(s) -> $_dest"
    return 0
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

borg_resume_merge_allowlist() {
    local _link="$1" _target _dir _ts _bak _tmp _before _after
    if [ -z "$_link" ] || { [ ! -e "$_link" ] && [ ! -L "$_link" ]; }; then
        _ri_warn "settings.json not found at ${_link:-<unset>} -- resume allowlist NOT merged (nothing changed)"
        return 0
    fi
    _target="$(_ri_resolve_link "$_link")"
    if [ ! -f "$_target" ]; then
        _ri_warn "settings.json at $_link does not resolve to a file -- resume allowlist NOT merged"
        return 0
    fi
    if ! command -v jq >/dev/null 2>&1; then
        _ri_warn "jq not found -- resume allowlist NOT merged"
        return 0
    fi
    if ! jq -e 'type == "object"' "$_target" >/dev/null 2>&1; then
        _ri_warn "settings.json is not valid JSON (or not an object) -- resume allowlist NOT merged (nothing changed)"
        return 0
    fi
    if ! jq -e '(.permissions // {}) | type == "object" and ((.allow // []) | type == "array")' "$_target" \
        >/dev/null 2>&1; then
        _ri_warn "settings.json permissions.allow has an unexpected shape -- resume allowlist NOT merged"
        return 0
    fi
    _before="$(jq -c '.permissions.allow // []' "$_target")"
    _tmp="$_target.borg-resume.tmp.$$"
    # cp -p keeps mode and owner; the redirect below then rewrites only the content.
    if ! cp -p "$_target" "$_tmp" 2>/dev/null; then
        _ri_warn "cannot write beside $_target -- resume allowlist NOT merged"
        return 0
    fi
    if ! jq --arg a "$BORG_RESUME_ALLOW_BASH_ABS" --arg b "$BORG_RESUME_ALLOW_BASH_BARE" \
        --arg c "$BORG_RESUME_ALLOW_READ" '
        .permissions.allow = ((.permissions.allow // []) as $cur
            | $cur + ([$a, $b, $c] | map(select(. as $e | $cur | index($e) | not))))
    ' "$_target" >"$_tmp" 2>/dev/null; then
        rm -f "$_tmp"
        _ri_warn "jq merge failed -- resume allowlist NOT merged (nothing changed)"
        return 0
    fi
    _after="$(jq -c '.permissions.allow' "$_tmp")"
    if [ "$_before" = "$_after" ]; then
        rm -f "$_tmp"
        _ri_say "  resume allowlist already present in $_link"
        return 0
    fi
    # The backup sits beside the path the user knows (the link), not inside a dotfiles repo it points into.
    _ts="$(date +%Y%m%d-%H%M%S)"
    _bak="${_link}.borg-resume-bak.$_ts"
    if ! cp -p "$_target" "$_bak" 2>/dev/null; then
        rm -f "$_tmp"
        _ri_warn "could not back up $_link -- resume allowlist NOT merged"
        return 0
    fi
    if mv -f "$_tmp" "$_target"; then
        if [ -L "$_link" ]; then
            _ri_say "  settings.json is a symlink: wrote through to $_target (link left intact)"
        fi
        _ri_say "  resume allowlist merged into $_link (backup: $_bak)"
    else
        rm -f "$_tmp"
        _ri_warn "could not replace $_target -- resume allowlist NOT merged"
    fi
    return 0
}

borg_resume_install_agent() {
    local _src="$1" _label="$2" _la="$3" _logs="$4" _bin="$5" _claude="$6" _path="$7" _dest
    _dest="$_la/$_label.plist"
    if [ ! -f "$_src" ]; then
        _ri_warn "resume-watch plist template missing: $_src -- skipped"
        return 0
    fi
    mkdir -p "$_la" "$_logs" || return 0
    sed \
        -e "s|{{LABEL}}|$_label|g" \
        -e "s|{{RESUME_BIN}}|$_bin|g" \
        -e "s|{{CLAUDE_BIN}}|$_claude|g" \
        -e "s|{{LOG_DIR}}|$_logs|g" \
        -e "s|{{USER}}|${USER:-}|g" \
        -e "s|{{HOME}}|$HOME|g" \
        -e "s|{{PATH_VALUE}}|$_path|g" \
        "$_src" >"$_dest"
    if command -v plutil >/dev/null 2>&1 && ! plutil -lint "$_dest" >/dev/null 2>&1; then
        _ri_warn "  resume-watch: rendered plist fails plutil -lint -- skipped, NOT bootstrapped ($_dest)"
        rm -f "$_dest"
        return 0
    fi
    _ri_say "  plist -> $_dest"
    if launchctl list "$_label" >/dev/null 2>&1; then
        _ri_say "  reloading launchd agent..."
        launchctl bootout "gui/$(id -u)/$_label" 2>/dev/null || true
    fi
    if launchctl bootstrap "gui/$(id -u)" "$_dest" 2>/dev/null; then
        _ri_say "  launchd agent bootstrapped: $_label (every 30s)"
    else
        _ri_warn "  launchctl bootstrap failed for $_label; plist left at $_dest"
    fi
    return 0
}
