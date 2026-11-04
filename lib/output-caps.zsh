# lib/output-caps.zsh -- `borg setup` makes sure ~/.claude/settings.json carries two output caps under .env.
# BASH_MAX_OUTPUT_LENGTH and CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS bound what one Bash or Read result can put into
# context, which is re-read on every later call (issue 500). A key is added ONLY when absent: a value already there,
# even a different one, is a person's choice and is never overwritten. Every other setting and .env key is kept.
# Needs _borg_jq_rewrite, info and die from borg.zsh. Reads $HOME, so a test points HOME at a scratch directory.

_BORG_OUTPUT_CAPS=(BASH_MAX_OUTPUT_LENGTH 12000 CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS 8000)

# Usage: _borg_ensure_output_caps   (no arguments; one info line per key added, nothing when all are present)
_borg_ensure_output_caps() {
    source "$BORG_HOME/lib/resume-install.sh"
    command -v jq &>/dev/null || die "setup needs jq to set the output caps"
    # settings.json is often a symlink into the dotfiles repo: write through the target so the link survives.
    local settings key val
    settings="$(_ri_resolve_link "$HOME/.claude/settings.json")"
    if [[ -f "$settings" ]]; then
        jq -e 'type == "object" and ((.env // {}) | type == "object")' "$settings" &>/dev/null \
            || { warn "$settings is not a JSON object with an object .env; output caps not set"; return 0; }
    fi
    for key val in "${_BORG_OUTPUT_CAPS[@]}"; do
        if [[ -f "$settings" ]] && jq -e --arg k "$key" '(.env // {}) | has($k)' "$settings" &>/dev/null; then
            continue
        fi
        mkdir -p "${settings:h}"
        [[ -f "$settings" ]] || printf '{}\n' > "$settings"
        _borg_jq_rewrite "$settings" --arg k "$key" --arg v "$val" '.env = ((.env // {}) + {($k): $v})' || return 1
        info "set $key=$val in $settings"
    done
}
