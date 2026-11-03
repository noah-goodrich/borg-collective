#!/usr/bin/env bash
# borg-precompact-checkpoint.sh -- Claude Code PreCompact hook (#503).
# Writes a minimal checkpoint to <repository>/.borg/checkpoints/ just before compaction, so the next SessionStart
# restores state even when nobody ran /borg-link-up. A THIN WRAPPER, per hooks/CLAUDE.md's language rule: JSON plus
# git plus string work is more than one helper process, so the body is Python 3 stdlib
# (borg_core/checkpoint/precompact_hook.py; the document is assembled by borg_core/checkpoint/precompact.py).
#
# SILENT AND FAIL-OPEN: a PreCompact hook must never disturb compaction, and a plugin hook fires in every session on
# the machine, so with no python3, no borg_core, or a directory borg does not live in, this prints nothing and exits 0.
# No `set -e`: every path ends in exit 0. Copied by build-plugin.sh WITHOUT the "borg on PATH" guard: it finds
# borg_core the way borg-arrival-brief.sh does.

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
    python3 -m borg_core.checkpoint.precompact_hook >/dev/null 2>&1
exit 0
