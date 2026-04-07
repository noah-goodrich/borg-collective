#!/usr/bin/env bash
# =============================================================================
# Dotfiles Install Script (Borg Collective starter)
# Safe to re-run — backs up existing files before symlinking
# =============================================================================

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
USERNAME="$(whoami)"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${GREEN}[dotfiles]${NC} $1"; }
warn()    { echo -e "${YELLOW}[dotfiles]${NC} $1"; }
error()   { echo -e "${RED}[dotfiles]${NC} $1"; }

# -----------------------------------------------------------------------------
# Templatize — resolve __PLACEHOLDER__ markers in a file
# Usage: templatize <source> <destination>
# Replaces: __HOME__, __USERNAME__, __DOTFILES_DIR__, __GIT_NAME__, __GIT_EMAIL__
# -----------------------------------------------------------------------------
templatize() {
    local src="$1"
    local dst="$2"
    local git_name="${GIT_NAME:-$(git config --global user.name 2>/dev/null || echo '__GIT_NAME__')}"
    local git_email="${GIT_EMAIL:-$(git config --global user.email 2>/dev/null || echo '__GIT_EMAIL__')}"

    sed -e "s|__HOME__|$HOME|g" \
        -e "s|__USERNAME__|$USERNAME|g" \
        -e "s|__DOTFILES_DIR__|$DOTFILES_DIR|g" \
        -e "s|__GIT_NAME__|$git_name|g" \
        -e "s|__GIT_EMAIL__|$git_email|g" \
        "$src" > "$dst"
    info "Templatized $dst"
}

# -----------------------------------------------------------------------------
# Symlink helper — backs up existing file/dir before linking
# Usage: link <source> <target>
# -----------------------------------------------------------------------------
link() {
    local src="$1"
    local dst="$2"

    # Create parent directory if needed
    mkdir -p "$(dirname "$dst")"

    # If target already exists and is not already our symlink
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        mkdir -p "$BACKUP_DIR"
        warn "Backing up existing $dst → $BACKUP_DIR/"
        mv "$dst" "$BACKUP_DIR/"
    fi

    # Remove stale symlink
    [ -L "$dst" ] && rm "$dst"

    # Use a path relative to the symlink's directory so the link resolves
    # correctly even when the home directory differs (e.g. inside containers).
    local rel_src
    rel_src=$(python3 -c "import os,sys; print(os.path.relpath(sys.argv[1], os.path.dirname(sys.argv[2])))" "$src" "$dst" 2>/dev/null) || rel_src="$src"
    ln -sf "$rel_src" "$dst"
    info "Linked $dst → $rel_src"
}

# -----------------------------------------------------------------------------
# Install dependencies
# -----------------------------------------------------------------------------
install_deps() {
    info "Checking dependencies..."

    # tmux
    if ! command -v tmux &>/dev/null; then
        warn "tmux not found — installing..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install tmux
        else
            sudo apt-get install -y tmux
        fi
    fi

    # Zsh
    if ! command -v zsh &>/dev/null; then
        warn "zsh not found — installing..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install zsh
        else
            sudo apt-get install -y zsh
        fi
    fi

    # Powerlevel10k
    if [ ! -d "$HOME/.config/zsh/powerlevel10k" ]; then
        info "Installing Powerlevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
            "$HOME/.config/zsh/powerlevel10k"
    fi

    # zsh-autosuggestions
    if [ ! -d "$HOME/.config/zsh/zsh-autosuggestions" ]; then
        info "Installing zsh-autosuggestions..."
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
            "$HOME/.config/zsh/zsh-autosuggestions"
    fi

    # zsh-syntax-highlighting
    if [ ! -d "$HOME/.config/zsh/zsh-syntax-highlighting" ]; then
        info "Installing zsh-syntax-highlighting..."
        git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
            "$HOME/.config/zsh/zsh-syntax-highlighting"
    fi
}

# -----------------------------------------------------------------------------
# Merge Claude Code settings.json (non-destructive)
# Merges dotfiles base config into existing ~/.claude/settings.json.
# Preserves hooks, plugins, and permissions added by other tools (e.g. borg).
# -----------------------------------------------------------------------------
merge_claude_settings() {
    local template="$DOTFILES_DIR/claude/code/settings.json"
    local target="$HOME/.claude/settings.json"

    if ! command -v jq &>/dev/null; then
        warn "jq not found — cannot merge settings.json"
        if [ ! -f "$target" ]; then
            warn "Copying template as fallback (install jq and re-run to merge properly)"
            cp "$template" "$target"
        fi
        return
    fi

    if [ ! -f "$target" ]; then
        info "Creating ~/.claude/settings.json from template..."
        cp "$template" "$target"
        return
    fi

    # Existing file: merge dotfiles settings without clobbering
    info "Merging dotfiles settings into existing settings.json..."
    local tmp="$target.tmp.$$"

    jq -s '
        .[0] as $existing | .[1] as $template |
        $existing |
        .permissions = $template.permissions |
        .model = $template.model |
        .hooks = (
            ($existing.hooks // {}) as $eh |
            ($template.hooks // {}) as $th |
            ($eh | keys) + ($th | keys) | unique | map(
                . as $evt |
                ($eh[$evt] // []) as $existing_entries |
                ($th[$evt] // []) as $template_entries |
                ($existing_entries | [.[].hooks[]?.command]) as $existing_cmds |
                ($template_entries | map(
                    select(.hooks | map(.command) | all(. as $c | $existing_cmds | index($c) | not))
                )) as $new_entries |
                {key: $evt, value: ($existing_entries + $new_entries)}
            ) | from_entries
        )
    ' "$target" "$template" > "$tmp" && mv "$tmp" "$target"
    info "  settings.json merged (existing hooks preserved)"
}

# -----------------------------------------------------------------------------
# Link all dotfiles
# -----------------------------------------------------------------------------
link_dotfiles() {
    info "Linking dotfiles..."

    # tmux
    link "$DOTFILES_DIR/tmux/tmux.conf"   "$HOME/.config/tmux/tmux.conf"

    # zsh
    link "$DOTFILES_DIR/zsh/.zshrc"       "$HOME/.zshrc"

    # git — templatize to resolve __GIT_NAME__ and __GIT_EMAIL__
    if [ ! -f "$HOME/.gitconfig" ] || grep -q '__GIT_' "$HOME/.gitconfig" 2>/dev/null; then
        templatize "$DOTFILES_DIR/git/config" "$HOME/.gitconfig"
    else
        info "Skipping git config — already configured (no placeholders)"
    fi
    link "$DOTFILES_DIR/git/ignore"       "$HOME/.config/git/ignore"

    # neovim
    link "$DOTFILES_DIR/nvim"             "$HOME/.config/nvim"

    # ghostty
    link "$DOTFILES_DIR/ghostty"          "$HOME/.config/ghostty"

    # Claude Code
    mkdir -p "$HOME/.claude/hooks"
    link "$DOTFILES_DIR/claude/code/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    merge_claude_settings
}

# -----------------------------------------------------------------------------
# Build base devcontainer image (if Docker is available)
# -----------------------------------------------------------------------------
build_base_devcontainer() {
    if ! command -v docker &>/dev/null; then
        warn "Docker not found — skipping base devcontainer image build"
        return
    fi

    # Ensure shared Docker network exists (used by all devcontainers)
    info "Ensuring devnet Docker network exists..."
    docker network inspect devnet >/dev/null 2>&1 || docker network create devnet

    local dockerfile="$DOTFILES_DIR/devcontainer/Dockerfile.base"
    if [ -f "$dockerfile" ]; then
        info "Building devcontainer-base:local image..."
        docker build -f "$dockerfile" -t devcontainer-base:local "$DOTFILES_DIR/devcontainer/" \
            && info "  → devcontainer-base:local built successfully" \
            || warn "  → devcontainer-base:local build failed (Docker may not be running)"
    else
        warn "devcontainer/Dockerfile.base not found, skipping base image build"
    fi
}

# -----------------------------------------------------------------------------
# Reload zshrc in all open tmux panes
# -----------------------------------------------------------------------------
reload_all_panes() {
    if ! command -v tmux &>/dev/null || ! tmux list-sessions &>/dev/null 2>&1; then
        info "No tmux session running — start a new shell to pick up changes"
        return
    fi

    local pane_ids
    pane_ids=$(tmux list-panes -a -F '#{pane_id}')
    local count=0
    while IFS= read -r pid; do
        [ -z "$pid" ] && continue
        tmux send-keys -t "$pid" " source ~/.zshrc" Enter
        count=$((count + 1))
    done <<< "$pane_ids"
    info "Reloaded ~/.zshrc in $count tmux pane(s)"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    info "Starting dotfiles installation from $DOTFILES_DIR"

    install_deps
    link_dotfiles
    build_base_devcontainer
    reload_all_panes

    info "Done!"
    echo ""
    info "Next steps:"
    info "  1. Run 'p10k configure' to set up your prompt"
    info "  2. Edit ~/.gitconfig to set your name and email (if not already set)"
    info "  3. Edit ~/.claude/CLAUDE.md to personalize your Claude Code preferences"
    echo ""

    if [ -d "$BACKUP_DIR" ]; then
        warn "Backups saved to: $BACKUP_DIR"
    fi
}

main "$@"
