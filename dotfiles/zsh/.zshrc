# =============================================================================
# POWERLEVEL10K INSTANT PROMPT
# Must stay at the very top of .zshrc
# =============================================================================
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi


# =============================================================================
# ZSH CORE
# =============================================================================
# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY

# Navigation
setopt AUTO_CD              # cd by typing directory name
setopt AUTO_PUSHD           # push dirs onto stack automatically
setopt PUSHD_IGNORE_DUPS

# Completion
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'  # case-insensitive

# Keybindings — vi mode
bindkey -v
export KEYTIMEOUT=1

# Keep Ctrl+R for history search in vi mode
bindkey '^R' history-incremental-search-backward


# =============================================================================
# PLUGINS
# =============================================================================
ZSH_PLUGIN_DIR="$HOME/.config/zsh"

# Powerlevel10k prompt
source "$ZSH_PLUGIN_DIR/powerlevel10k/powerlevel10k.zsh-theme"

# Autosuggestions (fish-style inline suggestions)
source "$ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh"
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=60'
bindkey '^ ' autosuggest-accept   # Ctrl+Space accepts suggestion

# Syntax highlighting (must be last plugin)
source "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"


# =============================================================================
# ENVIRONMENT
# =============================================================================
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="less"

# XDG
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"

# SSH agent — use macOS native keychain agent (prevents Docker from hijacking it)
if [[ "$OSTYPE" == darwin* ]]; then
    local _ssh_sock
    _ssh_sock=$(launchctl getenv SSH_AUTH_SOCK)
    [[ -n "$_ssh_sock" ]] && export SSH_AUTH_SOCK="$_ssh_sock"
fi

# PATH additions
export PATH="/opt/homebrew/bin:$PATH"      # Homebrew (macOS)
export PATH="$HOME/.local/bin:$HOME/.claude/bin:$PATH"


# =============================================================================
# ALIASES
# =============================================================================
# Editor
alias v="nvim"
alias vi="nvim"
alias vim="nvim"

# Navigation
alias ..="cd .."
alias ...="cd ../.."
alias l="ls -Glah"                         # macOS color ls
alias ll="ls -lah"
alias la="ls -A"
alias c="clear"

# Git
alias gs="git status"
alias gst="git status"
alias ga="git add"
alias gc="git commit"
alias gco="git checkout"
alias gp="git push"
alias gpl="git pull"
alias gl="git log --oneline --graph --decorate"
alias gd="git diff"

# Docker
alias dc="docker-compose"

# tmux
alias t="tmux"
alias ta="tmux attach -t"
alias tl="tmux ls"
alias tn="tmux new -s"


# =============================================================================
# POWERLEVEL10K CONFIG
# =============================================================================
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# =============================================================================
# MACHINE-LOCAL OVERRIDES (gitignored)
# =============================================================================
# Put machine-specific aliases, exports, and completions in local.zsh.
# Examples: custom PATH entries, API key loading, work-only aliases.
[[ -f "${0:A:h}/local.zsh" ]] && source "${0:A:h}/local.zsh"
