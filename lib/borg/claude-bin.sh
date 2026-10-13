#!/usr/bin/env bash
# claude-bin.sh -- resolve an ABSOLUTE path to the claude binary, for jobs that run under launchd.
#
# launchd hands jobs a minimal PATH that omits $HOME/.local/bin (where the native installer puts
# claude), so a bare `claude` is not reliably resolvable there. Source this file and call
# borg_resolve_claude_bin; on success BORG_CLAUDE_BIN is exported as an absolute path.
#
# Order: an executable absolute BORG_CLAUDE_BIN override, then `command -v claude` on PATH, then
# the well-known install dirs (BORG_CLAUDE_SEARCH_DIRS, colon separated, overrides the default list).
# Returns 1 and leaves BORG_CLAUDE_BIN unset when nothing is found. Bash 3.2 safe; never exits.

borg_resolve_claude_bin() {
    local _cand _dir _dirs _rest
    if [ -n "${BORG_CLAUDE_BIN:-}" ] && [ "${BORG_CLAUDE_BIN#/}" != "$BORG_CLAUDE_BIN" ] \
        && [ -x "$BORG_CLAUDE_BIN" ] && [ ! -d "$BORG_CLAUDE_BIN" ]; then
        export BORG_CLAUDE_BIN
        return 0
    fi
    _cand="$(command -v claude 2>/dev/null || true)"
    if [ -n "$_cand" ] && [ "${_cand#/}" != "$_cand" ] && [ -x "$_cand" ]; then
        BORG_CLAUDE_BIN="$_cand"
        export BORG_CLAUDE_BIN
        return 0
    fi
    _dirs="${BORG_CLAUDE_SEARCH_DIRS:-${HOME:-}/.local/bin:/opt/homebrew/bin:/usr/local/bin}"
    # Split on ":" with parameter expansion, not IFS word-splitting: zsh does not split unquoted expansions.
    _rest="$_dirs:"
    while [ -n "$_rest" ]; do
        _dir="${_rest%%:*}"
        _rest="${_rest#*:}"
        if [ -n "$_dir" ] && [ -x "$_dir/claude" ] && [ ! -d "$_dir/claude" ]; then
            BORG_CLAUDE_BIN="$_dir/claude"
            export BORG_CLAUDE_BIN
            return 0
        fi
    done
    unset BORG_CLAUDE_BIN
    return 1
}
