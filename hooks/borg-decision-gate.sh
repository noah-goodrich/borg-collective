#!/usr/bin/env bash
# borg-decision-gate.sh -- Claude Code / Cortex Code Stop hook.
# Blocks a turn whose final message asks Noah to decide as a plain list ("Needs Noah: #97, close or restate scope")
# when the turn made no AskUserQuestion call, and tells the model to re-ask each decision through AskUserQuestion with
# real context. It happened 2026-10-04, 2026-10-15 and 2026-11-25; memory rules failed twice, so this is the hard wire.
# A THIN WRAPPER, per hooks/CLAUDE.md's language rule: JSON plus string work is more than one helper process, so the
# body is Python 3 stdlib (borg_core/decisiongate/hook.py, pure detection in borg_core/decisiongate/core.py).
#
# FAIL-OPEN AND QUIET: with no python3, no borg_core, or any error, this prints nothing and exits 0 (the turn ends). A
# plugin hook fires in every session on the machine, Queen and repository, which is the intent. It blocks at most
# once in a row: the payload's stop_hook_active makes the Python body pass. No `set -e`: every path ends in exit 0.
# Copied by build-plugin.sh WITHOUT the "borg on PATH" guard: it finds borg_core the way borg-arrival-brief.sh does.

PATH="${PATH:+$PATH:}${HOME}/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin"
export PATH

[ "${BORG_NO_SESSION_HOOKS:-}" = "1" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0

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
[ -n "$_core_root" ] || exit 0

PYTHONSAFEPATH=1 PYTHONPATH="$_core_root${PYTHONPATH:+:$PYTHONPATH}" \
    python3 -m borg_core.decisiongate.hook 2>/dev/null
exit 0
