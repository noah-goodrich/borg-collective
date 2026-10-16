#!/usr/bin/env bash
# resume-doctor.sh -- the borg-resume rows of `borg doctor` (slice S13). Sourced by borg.zsh (zsh) and by tests.
# READ-ONLY: it inspects and reports, it never repairs, never writes under the real state dir and never calls a
# mutating launchctl verb. Needs jq. Bash 3.2 and zsh safe.
#
#   borg_resume_doctor_rows <resume_label>
#       prints one TAB-separated record per check:  STATUS <TAB> NAME <TAB> DETAIL <TAB> HINT
#       STATUS is OK | WARN | FAIL | INFO | OFF  (OFF = disabled on purpose by BORG_RESUME_WATCH=0)
#
# Nothing installed (no bin, no hook, no watcher plist, no lib dir) is a single INFO row, not a failure: a machine
# that never ran `borg setup` for borg-resume is not broken, it is just not using it.

BORG_RESUME_DOCTOR_LOG_MAX_AGE="${BORG_RESUME_DOCTOR_LOG_MAX_AGE:-120}"
BORG_RESUME_DOCTOR_GUARDIAN_MAX_AGE="${BORG_RESUME_DOCTOR_GUARDIAN_MAX_AGE:-86400}"

_rd_row() { printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "${4:-}"; }

_rd_now() {
    case "${BORG_RESUME_NOW_EPOCH:-}" in
        "" | *[!0-9]*) date +%s ;;
        *) printf '%s\n' "$BORG_RESUME_NOW_EPOCH" ;;
    esac
}

_rd_mtime() {
    stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null
}

_rd_iso_epoch() {
    date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s 2>/dev/null || date -u -d "$1" +%s 2>/dev/null
}

_rd_dir() {
    if [ -n "${BORG_RESUME_DIR:-}" ]; then
        printf '%s\n' "$BORG_RESUME_DIR"
    else
        printf '%s/borg/resume\n' "${XDG_STATE_HOME:-$HOME/.local/state}"
    fi
}

# Is the borg-resume hook registered? Settings (resolved through any symlink), the hooks dir, or a plugin hooks.json.
_rd_hook_registered() {
    local _s="$HOME/.claude/settings.json"
    [ -e "$HOME/.claude/hooks/borg-resume-hook.sh" ] && return 0
    [ -r "$_s" ] && grep -q 'borg-resume-hook' "$_s" 2>/dev/null && return 0
    if [ -d "$HOME/.claude/plugins" ]; then
        grep -rlqs --include=hooks.json 'borg-resume-hook' "$HOME/.claude/plugins" 2>/dev/null && return 0
    fi
    return 1
}

# The lib/borg files bin/borg-resume needs, derived from the repo (never a hardcoded list): every name the bin
# references, then the names those libs reference in turn (a few rounds), kept only if the repo ships them.
_rd_required_libs() {
    local _repo="${BORG_HOME:-}" _bin _libsrc _set _new _n _f _round
    _bin="$_repo/bin/borg-resume"
    _libsrc="$_repo/lib/borg"
    if [ ! -f "$_bin" ] || [ ! -d "$_libsrc" ]; then
        _bin="$HOME/.claude/bin/borg-resume"
        _libsrc="$HOME/.claude/lib/borg"
    fi
    [ -f "$_bin" ] || return 1
    _set="$(grep -o '[a-z][a-z0-9-]*\.sh' "$_bin" | sort -u)"
    for _round in 1 2 3; do
        _new="$_set"
        while IFS= read -r _n; do
            [ -f "$_libsrc/$_n" ] || continue
            _new="$_new
$(grep -o '[a-z][a-z0-9-]*\.sh' "$_libsrc/$_n")"
        done <<EOF2
$_set
EOF2
        _new="$(printf '%s\n' "$_new" | sort -u)"
        [ "$_new" = "$_set" ] && break
        _set="$_new"
    done
    while IFS= read -r _f; do
        [ -f "$_libsrc/$_f" ] && printf '%s\n' "$_f"
    done <<EOF2
$_set
EOF2
    return 0
}

_rd_watcher() {
    local _label="$1" _optout="$2" _out _rc=0 _state _exit
    _out="$(launchctl print "gui/$(id -u)/$_label" 2>&1)" || _rc=$?
    if [ "$_rc" -ne 0 ]; then
        if [ "$_optout" = 1 ]; then
            _rd_row OFF resume-watch "opted out (BORG_RESUME_WATCH=0 at install)" "unset it and run: borg setup"
        else
            _rd_row FAIL resume-watch "watcher job not loaded ($_label)" \
                "nothing will resume sessions: run ./install.sh to install the watcher"
        fi
        return 0
    fi
    _state="$(printf '%s\n' "$_out" | sed -n 's/^[[:space:]]*state = //p' | head -1)"
    _exit="$(printf '%s\n' "$_out" | sed -n 's/^[[:space:]]*last exit code = //p' | head -1)"
    case "$_state" in
        running) _rd_row OK resume-watch "running ($_label)" ;;
        *)
            case "$_exit" in
                "" | 0 | "(never exited)") _rd_row OK resume-watch "loaded, idle between passes ($_label)" ;;
                *) _rd_row FAIL resume-watch "loaded but not running, last exit $_exit ($_label)" \
                    "see the resume-watch.stderr.log under the borg data dir, then re-run ./install.sh" ;;
            esac
            ;;
    esac
}

_rd_watchlog() {
    local _optout="$1" _f _t _now _age _max="$BORG_RESUME_DOCTOR_LOG_MAX_AGE"
    if [ "$_optout" = 1 ]; then
        _rd_row OFF resume-log "opted out (BORG_RESUME_WATCH=0 at install)"
        return 0
    fi
    # watch.log only gets a line on activity; liveness is the heartbeat the watcher touches every pass.
    _f="$(_rd_dir)/watch.heartbeat"
    if [ ! -e "$_f" ]; then
        _rd_row WARN resume-log "no watcher pass recorded yet" "expected within a minute of install; re-run doctor"
        return 0
    fi
    _t="$(_rd_mtime "$_f")"
    _now="$(_rd_now)"
    case "$_t" in "" | *[!0-9]*) _rd_row WARN resume-log "cannot read the last pass time"; return 0 ;; esac
    _age=$((_now - _t))
    if [ "$_age" -gt "$_max" ]; then
        _rd_row FAIL resume-log "last pass ${_age}s ago (limit ${_max}s)" "the watcher is not completing passes"
    else
        _rd_row OK resume-log "last pass ${_age}s ago"
    fi
}

# First <string> after <key>NAME</key> in a plist (EnvironmentVariables values).
_rd_plist_string() {
    awk -v k="<key>$2</key>" 'index($0, k) { f = 1; next }
        f && /<string>/ { gsub(/.*<string>|<\/string>.*/, ""); print; exit }' "$1"
}

# The probe runs the INSTALLED borg-resume under a launchd-like environment (env -i + the plist's PATH and
# BORG_CLAUDE_BIN), with the cache bypassed (TTL 0) and a scratch state dir so doctor writes nothing real.
_rd_probe() {
    local _optout="$1" _label="$2" _bin="$HOME/.claude/bin/borg-resume" _plist _path _cbin _scratch _out _rc=0
    if [ "$_optout" = 1 ]; then
        _rd_row OFF resume-probe "opted out (BORG_RESUME_WATCH=0 at install)"
        return 0
    fi
    if [ ! -x "$_bin" ] || [ ! -f "$HOME/.claude/lib/borg/resume-probe.sh" ]; then
        _rd_row WARN resume-probe "skipped: borg-resume or its lib is not installed" "see resume-lib"
        return 0
    fi
    _plist="$HOME/Library/LaunchAgents/$_label.plist"
    _path="/usr/bin:/bin:$HOME/.claude/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin"
    _cbin=""
    if [ -f "$_plist" ]; then
        _path="$(_rd_plist_string "$_plist" PATH)"
        _cbin="$(_rd_plist_string "$_plist" BORG_CLAUDE_BIN)"
        [ -n "$_path" ] || _path="/usr/bin:/bin:$HOME/.claude/bin:$HOME/.local/bin:/opt/homebrew/bin"
    fi
    _scratch="$(mktemp -d "${TMPDIR:-/tmp}/borg-doctor-probe.XXXXXX")" || {
        _rd_row WARN resume-probe "skipped: no scratch directory"
        return 0
    }
    _out="$(env -i HOME="$HOME" USER="${USER:-$(id -un)}" PATH="$_path" XDG_STATE_HOME="${XDG_STATE_HOME:-}" \
        BORG_CLAUDE_BIN="$_cbin" BORG_RESUME_DIR="$_scratch" BORG_RESUME_PROBE_TTL=0 BORG_RESUME_PROBE_TIMEOUT=20 \
        BORG_RESUME_USAGE_CMD="$([ "${BORG_RESUME_DOCTOR_TEST:-}" = 1 ] && printf '%s' "${BORG_RESUME_USAGE_CMD:-}")" "$_bin" probe 2>&1)" || _rc=$?
    rm -r "$_scratch" 2>/dev/null
    if [ "$_rc" -eq 0 ] && [ "$_out" = unmetered ]; then
        _rd_row INFO resume-probe "usage-billed account: /usage reports cost, no session limit" \
            "limit-class resumes and the guardian's limit thresholds do not apply on this account"
    elif [ "$_rc" -eq 0 ]; then
        _rd_row OK resume-probe "usage probe works under the launchd environment (${_out}% used)"
    else
        _rd_row FAIL resume-probe "usage probe failed under the launchd environment: ${_out:-exit $_rc}" \
            "limit-class resumes fail closed until this works; check BORG_CLAUDE_BIN in the watcher plist"
    fi
}

_rd_guardian() {
    local _f="${BORG_USAGE_GUARDIAN_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/borg/usage-guardian.json}"
    local _ts _t _now _age _max="$BORG_RESUME_DOCTOR_GUARDIAN_MAX_AGE" _a _b
    if [ ! -f "$_f" ]; then
        _rd_row WARN resume-guardian "no usage-guardian.json" "resume runs its own probe, so this is informational"
        return 0
    fi
    _a="$(jq -r '.last_swept_at // empty' "$_f" 2>/dev/null)"
    _b="$(jq -r '.last_unknown_at // empty' "$_f" 2>/dev/null)"
    _t=""
    for _ts in "$_a" "$_b"; do
        [ -n "$_ts" ] || continue
        _ts="$(_rd_iso_epoch "$_ts")"
        case "$_ts" in "" | *[!0-9]*) continue ;; esac
        if [ -z "$_t" ] || [ "$_ts" -gt "$_t" ]; then _t="$_ts"; fi
    done
    [ -n "$_t" ] || _t="$(_rd_mtime "$_f")"
    _now="$(_rd_now)"
    _age=$((_now - _t))
    if [ "$_age" -gt "$_max" ]; then
        _rd_row WARN resume-guardian "usage guardian last active $((_age / 3600))h ago" \
            "the guardian looks dead; resume runs its own probe, so this is a warning only"
    else
        _rd_row OK resume-guardian "usage guardian active $((_age / 60))m ago"
    fi
}

_rd_allowlist() {
    local _optout="$1" _s="$HOME/.claude/settings.json" _allow _miss="" _e
    if [ ! -r "$_s" ]; then
        if [ "$_optout" = 1 ]; then
            _rd_row OFF resume-allow "opted out (BORG_RESUME_WATCH=0 at install)"
        else
            _rd_row FAIL resume-allow "global settings.json not readable ($_s)" "run: borg setup"
        fi
        return 0
    fi
    _allow="$(jq -r '.permissions.allow[]?' "$_s" 2>/dev/null)" || _allow=""
    # Each entry is accepted spelled with ~ or with the absolute HOME (the installer renders the latter).
    printf '%s\n' "$_allow" | grep -Eq '^Bash\((~|'"$HOME"')/\.claude/bin/borg-resume:\*\)$' ||
        _miss="$_miss Bash(~/.claude/bin/borg-resume:*)"
    printf '%s\n' "$_allow" | grep -Fxq 'Bash(borg-resume:*)' || _miss="$_miss Bash(borg-resume:*)"
    printf '%s\n' "$_allow" | grep -Eq '^Read\((~|/)[^)]*borg/resume/\*\*\)$' ||
        _miss="$_miss Read(~/.local/state/borg/resume/**)"
    _e="${_miss# }"
    if [ -z "$_e" ]; then
        _rd_row OK resume-allow "the three borg-resume allowlist entries are present"
    elif [ "$_optout" = 1 ]; then
        _rd_row OFF resume-allow "opted out (BORG_RESUME_WATCH=0 at install)"
    else
        _rd_row FAIL resume-allow "missing from settings.json allow: $_e" \
            "without them resume prompts for permission and stalls: run: borg setup"
    fi
}

_rd_lib() {
    local _libdir="$HOME/.claude/lib/borg" _req _f _missing="" _n=0 _m=0 _bin_present="$1" _hook="$2"
    _req="$(_rd_required_libs)" || _req=""
    if [ -z "$_req" ]; then
        _rd_row WARN resume-lib "cannot derive the required lib list from bin/borg-resume"
        return 0
    fi
    while IFS= read -r _f; do
        _n=$((_n + 1))
        if [ ! -f "$_libdir/$_f" ]; then
            _m=$((_m + 1))
            _missing="$_missing $_f"
        fi
    done <<EOF2
$_req
EOF2
    if [ "$_m" -eq 0 ]; then
        _rd_row OK resume-lib "all $_n lib files present in $_libdir"
    else
        if [ ! -d "$_libdir" ]; then
            _rd_row FAIL resume-lib "$_libdir is missing" "run: borg setup"
        else
            _rd_row FAIL resume-lib "$_m of $_n lib files missing:${_missing}" "run: borg setup"
        fi
        if [ "$_bin_present" = 1 ] && [ "$_hook" = 1 ]; then
            _rd_row FAIL resume-hook \
                "the borg-resume hook is installed but its lib is missing, so every event is dropped" "run: borg setup"
        fi
    fi
}

_rd_switch() {
    local _s
    _s="$(_rd_dir)/DISABLED"
    if [ "${BORG_RESUME_DISABLE:-}" = "1" ]; then
        _rd_row INFO resume-switch "BORG_RESUME_DISABLE=1 in this shell: recording and injection are stopped"
    elif [ -e "$_s" ]; then
        _rd_row INFO resume-switch "paused (DISABLED sentinel present): recording continues, nothing is injected" \
            "resume with: borg resume unpause"
    else
        _rd_row INFO resume-switch "off (injection allowed)"
    fi
}

borg_resume_doctor_rows() {
    local _label="$1" _optout=0 _bin=0 _hook=0 _plist=0 _lib=0
    [ "${BORG_RESUME_WATCH:-1}" = "0" ] && _optout=1
    [ -e "$(_rd_dir)/WATCH_OPTOUT" ] && _optout=1
    [ -x "$HOME/.claude/bin/borg-resume" ] && _bin=1
    _rd_hook_registered && _hook=1
    [ -e "$HOME/Library/LaunchAgents/$_label.plist" ] && _plist=1
    [ -d "$HOME/.claude/lib/borg" ] && _lib=1
    if [ $((_bin + _hook + _plist + _lib)) -eq 0 ]; then
        _rd_row INFO borg-resume "not installed (run: borg setup to enable automatic resume)"
        return 0
    fi
    _rd_watcher "$_label" "$_optout"
    _rd_watchlog "$_optout"
    _rd_probe "$_optout" "$_label"
    _rd_guardian
    _rd_allowlist "$_optout"
    _rd_lib "$_bin" "$_hook"
    _rd_switch
    return 0
}
