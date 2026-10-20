#!/usr/bin/env bash
# borg-arrival-brief.sh -- Claude Code SessionStart hook (matcher: startup|resume).
# Shows the human the arrival brief as a top-level `systemMessage`: four lines in a repository session, ONE verdict
# line in the Queen session. Directive: docs/plans/directives/2026-10-18-arrival-brief-on-sessionstart.md.
#
# A THIN WRAPPER, per hooks/CLAUDE.md's language rule: reading JSON plus string work is more than one helper
# process, so the body is Python 3 stdlib (borg_core/link/arrival_hook.py, render logic in borg_core/link/arrival.py).
# This file only finds the package and execs it. NEVER SILENT: a machine with no python3 or no borg_core still
# prints one `unavailable` line (printf, no parser needed) and exits 0, because silence reads as "nothing to say".
# No `set -e`: every path ends in exit 0.

# APPENDED, not prepended like borg-link-down.sh: this hook shadows nothing, and a caller's own PATH (a test's mock
# borg, a project-local one) must win over the defaults.
PATH="${PATH:+$PATH:}${HOME}/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin"
export PATH

[ "${BORG_NO_SESSION_HOOKS:-}" = "1" ] && exit 0

_payload=$(cat 2>/dev/null) || _payload=""

_loud() {
    # Only for the two sources that get a brief; any other source (clear, compact, fork) stays silent.
    case "$_payload" in
        *'"source":"startup"'* | *'"source": "startup"'* | *'"source":"resume"'* | *'"source": "resume"'*)
            printf '{"systemMessage":"borg: arrival brief unavailable (%s)"}\n' "$1" ;;
    esac
    exit 0
}

command -v python3 >/dev/null 2>&1 || _loud "python3 not found"

# borg_core: script-relative (checkout, symlinked install), then $BORG_ROOT, then the source tree `borg` runs from.
_hook_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P) || _hook_dir=""
_core_root=""
if [ -n "$_hook_dir" ] && [ -d "$_hook_dir/../borg_core" ]; then
    _core_root="$_hook_dir/.."
elif [ -n "${BORG_ROOT:-}" ] && [ -d "$BORG_ROOT/borg_core" ]; then
    _core_root="$BORG_ROOT"
else
    _borg_bin=$(command -v borg 2>/dev/null) || _borg_bin=""
    if [ -n "$_borg_bin" ]; then
        _borg_dir=$(python3 -I -c 'import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "$_borg_bin" 2>/dev/null)
        [ -d "$_borg_dir/borg_core" ] && _core_root="$_borg_dir"
    fi
fi
[ -n "$_core_root" ] || _loud "borg_core not found"

printf '%s' "$_payload" | PYTHONSAFEPATH=1 PYTHONPATH="$_core_root${PYTHONPATH:+:$PYTHONPATH}" \
    python3 -m borg_core.link.arrival_hook 2>/dev/null || _loud "hook crashed"
exit 0
