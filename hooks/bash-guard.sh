#!/usr/bin/env bash
# PreToolUse hook (Bash matcher) — block dangerous + style-violating commands.
#
# Two layers:
#   1. Destructive-pattern guards (rm -rf /, curl|bash, force push to main, etc.)
#   2. CLAUDE.md syntax rules: no bare |, &&, ||, ;, $(), ~ paths, or inline #
#      comments unless wrapped in an allowed escape hatch (bash -c, zsh -c,
#      run-in, git -C). Quoted spans are stripped before pattern matching so
#      strings like `echo "a && b"` aren't false-positives.
#
# Exit 2 = block + tell Claude. Exit 0 = allow. Set BORG_BASH_GUARD_SOFT=1 to
# downgrade syntax-rule blocks to stderr warnings (escape valve for false
# positives mid-session — destructive guards are never softened).

COMMAND=$(jq -r '.tool_input.command' < /dev/stdin 2>/dev/null) || exit 0
[[ -z "$COMMAND" || "$COMMAND" == "null" ]] && exit 0

# ── Layer 1: destructive patterns (always hard-blocked) ───────────────────────

case "$COMMAND" in
    *"rm -rf /"*|*"rm -rf ~"*|*"rm -rf \$HOME"*)
        echo "Blocked: recursive delete of home or root directory" >&2
        exit 2 ;;
    *"chmod -R 777"*)
        echo "Blocked: world-writable recursive chmod" >&2
        exit 2 ;;
    *"> /dev/sda"*|*"dd if="*"of=/dev/"*)
        echo "Blocked: raw disk write" >&2
        exit 2 ;;
    *"curl"*"| bash"*|*"wget"*"| bash"*|*"curl"*"| sh"*|*"wget"*"| sh"*)
        echo "Blocked: piping remote script to shell" >&2
        exit 2 ;;
    *"curl"*"-X POST"*|*"curl"*"-X PUT"*|*"curl"*"-X DELETE"*|*"curl"*"-X PATCH"*|*"curl"*"-d "*|*"curl"*"--data"*|*"curl"*"--upload"*|*"curl"*"-F "*|*"curl"*"--form"*)
        echo "Blocked: curl with write method — GET only" >&2
        exit 2 ;;
    *"rm -rf"*".claude"*)
        echo "Blocked: recursive delete of Claude settings directory" >&2
        exit 2 ;;
    *"git push --force"*" main"*|*"git push --force"*" master"*|*"git push -f "*" main"*|*"git push -f "*" master"*)
        echo "Blocked: force push to main/master — use --force-with-lease or push to a branch" >&2
        exit 2 ;;
    *"> ~/.claude/settings.json"*|*">\$HOME/.claude/settings.json"*|*"> /Users/"*"/.claude/settings.json"*)
        echo "Blocked: truncating Claude settings file" >&2
        exit 2 ;;
esac

# ── Layer 2: CLAUDE.md syntax rules ───────────────────────────────────────────

# Already wrapped in an escape hatch? Skip syntax checks.
case "$COMMAND" in
    "bash -c "*|"zsh -c "*|"run-in "*|"git -C "*) exit 0 ;;
esac

# Strip single- and double-quoted spans before pattern matching, so quoted
# operators like `echo "a && b"` don't trigger. Heuristic — handles the
# common Bash forms Claude actually emits, not adversarial nesting.
STRIPPED=$(echo "$COMMAND" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")

_block_or_warn() {
    local rule="$1" hint="$2"
    if [[ -n "$BORG_BASH_GUARD_SOFT" ]]; then
        echo "WARN ($rule): $hint  [BORG_BASH_GUARD_SOFT=1, allowing]" >&2
        return 0
    fi
    echo "Blocked ($rule): $hint" >&2
    echo "  Command: $COMMAND" >&2
    exit 2
}

case "$STRIPPED" in
    *' && '*) _block_or_warn "bare &&" "wrap chains in bash -c '...', or use git -C /path / run-in /path" ;;
esac
case "$STRIPPED" in
    *' || '*) _block_or_warn "bare ||" "wrap chains in bash -c '...'" ;;
esac
case "$STRIPPED" in
    *';'*) _block_or_warn "bare ;" "wrap multi-statement lines in bash -c '...'" ;;
esac

# Bare pipe — distinguish from || (already handled above).
echo "$STRIPPED" | grep -Eq '(^|[^|])\|([^|]|$)' \
    && _block_or_warn "bare pipe" "wrap pipelines in bash -c '...'"

# $() command substitution. ${...} parameter expansion is fine.
case "$STRIPPED" in
    *'$('*) _block_or_warn '$()' "use parameter expansion (\${var}) or pipe results, or wrap in bash -c '...'" ;;
esac

# ~ tilde paths. Want absolute /Users/... or $HOME or relative ./...
echo "$STRIPPED" | grep -Eq '(^|[[:space:]])~(/|[[:space:]]|$)' \
    && _block_or_warn "tilde path" "use absolute paths (e.g. /Users/noah/...) — permission matching is literal"

# Inline # comment after a non-quoted space.
echo "$STRIPPED" | grep -Eq '[[:space:]]#([[:space:]]|$)' \
    && _block_or_warn "inline # comment" "remove inline comments from one-liners — they confuse the shell parser"

exit 0
