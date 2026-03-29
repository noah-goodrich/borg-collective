#!/usr/bin/env bash
# install.sh — The Borg Collective installer
#
# Safe to re-run. Installs borg CLI, hooks, skills, and bootstraps registry.
# Works standalone or called from a parent installer (e.g., dotfiles/install.sh).
#
# Usage:
#   ./install.sh              Full install (interactive, checks deps)
#   ./install.sh --quiet      Skip ASCII art and prompts

set -e

BORG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BORG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/borg"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_HOOKS_DIR="$CLAUDE_DIR/hooks"
CLAUDE_SKILLS_DIR="$CLAUDE_DIR/skills"
CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"
BIN_DIR="$HOME/.local/bin"
QUIET=0

[[ "${1:-}" == "--quiet" ]] && QUIET=1

GREEN='\033[0;32m'  YELLOW='\033[1;33m'  RED='\033[0;31m'  NC='\033[0m'
info() { echo -e "${GREEN}▸${NC} $*"; }
warn() { echo -e "${YELLOW}▸${NC} $*"; }
die()  { echo -e "${RED}▸ ERROR:${NC} $*" >&2; exit 1; }

if (( ! QUIET )); then
    echo ""
    echo "  ██████   ██████  ██████   ██████"
    echo "  ██   ██ ██    ██ ██   ██ ██"
    echo "  ██████  ██    ██ ██████  ██   ███"
    echo "  ██   ██ ██    ██ ██   ██ ██    ██"
    echo "  ██████   ██████  ██   ██  ██████"
    echo ""
    echo "  The Borg Collective — installer"
    echo "  Your sessions will be assimilated."
    echo ""
fi

# ── 1. Check dependencies ────────────────────────────────────────────────────

info "Checking dependencies..."

MISSING=()
command -v jq      &>/dev/null || MISSING+=(jq)
command -v fzf     &>/dev/null || MISSING+=(fzf)
command -v python3 &>/dev/null || MISSING+=(python3)
command -v node    &>/dev/null || MISSING+=(node)
command -v tmux    &>/dev/null || MISSING+=(tmux)

if (( ${#MISSING[@]} > 0 )); then
    warn "Missing: ${MISSING[*]}"
    if command -v brew &>/dev/null; then
        info "Installing via Homebrew..."
        brew install "${MISSING[@]}" 2>&1 | grep -E '(Installing|Already|Error)' || true
    else
        die "Install manually: ${MISSING[*]}"
    fi
fi

# npm packages (optional — borg works without them)
if ! command -v ccm &>/dev/null; then
    info "Installing claude-code-monitor..."
    npm install -g claude-code-monitor 2>/dev/null || warn "claude-code-monitor install failed (optional)"
fi
if ! command -v cs &>/dev/null; then
    info "Installing @tradchenko/claude-sessions..."
    npm install -g @tradchenko/claude-sessions 2>/dev/null || warn "claude-sessions install failed (optional)"
fi

info "Dependencies satisfied."

# ── 2. Create runtime directories ─────────────────────────────────────────────

info "Creating runtime directories..."
mkdir -p "$BORG_DIR/desktop"
mkdir -p "$CLAUDE_DIR"
mkdir -p "$CLAUDE_HOOKS_DIR"
mkdir -p "$CLAUDE_SKILLS_DIR"
mkdir -p "$BIN_DIR"

[[ -f "$BORG_DIR/registry.json" ]] || echo '{"projects":{}}' > "$BORG_DIR/registry.json"

# ── 3. Install borg CLI ───────────────────────────────────────────────────────

info "Installing borg CLI..."
chmod +x "$BORG_ROOT/borg.zsh"
ln -sf "$BORG_ROOT/borg.zsh" "$BIN_DIR/borg"

if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
    warn "$BIN_DIR is not in PATH. Add to ~/.zshrc:"
    warn '  export PATH="$HOME/.local/bin:$PATH"'
fi

info "Installed: $BIN_DIR/borg -> $BORG_ROOT/borg.zsh"

# ── 4. Install hooks ─────────────────────────────────────────────────────────

info "Installing hooks..."
chmod +x "$BORG_ROOT/hooks/"*.sh

for hook in "$BORG_ROOT/hooks/"*.sh; do
    name="$(basename "$hook")"
    ln -sf "$hook" "$CLAUDE_HOOKS_DIR/$name"
    info "  $name"
done

# ── 5. Register hooks in settings.json ────────────────────────────────────────

# Map hook filenames to Claude Code event types
declare -A HOOK_EVENTS=(
    [borg-start.sh]="SessionStart"
    [borg-stop.sh]="Stop"
    [borg-notify.sh]="Notification"
)

if [[ -f "$CLAUDE_SETTINGS" ]]; then
    info "Registering hooks in settings.json..."

    for hook_file in "${!HOOK_EVENTS[@]}"; do
        event="${HOOK_EVENTS[$hook_file]}"
        hook_cmd="\$HOME/.claude/hooks/$hook_file"

        # Check if already registered (avoid duplicates)
        if jq -e --arg evt "$event" --arg cmd "$hook_cmd" \
            '.hooks[$evt] // [] | map(.hooks[]? | select(.command == $cmd)) | length > 0' \
            "$CLAUDE_SETTINGS" &>/dev/null; then
            info "  $event: $hook_file (already registered)"
            continue
        fi

        # Add hook entry
        TMP="$CLAUDE_SETTINGS.tmp.$$"
        jq --arg evt "$event" --arg cmd "$hook_cmd" '
            if .hooks == null then .hooks = {} else . end |
            if .hooks[$evt] == null then .hooks[$evt] = [] else . end |
            .hooks[$evt] += [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}]
        ' "$CLAUDE_SETTINGS" > "$TMP" && mv "$TMP" "$CLAUDE_SETTINGS"
        info "  $event: $hook_file (registered)"
    done
else
    warn "No settings.json at $CLAUDE_SETTINGS"
    warn "Hooks installed but not registered. See README.md for manual registration."
fi

# ── 6. Install skills ─────────────────────────────────────────────────────────

info "Installing skills..."

for skill_dir in "$BORG_ROOT/skills/"*/; do
    [[ -d "$skill_dir" ]] || continue
    name="$(basename "$skill_dir")"
    target="$CLAUDE_SKILLS_DIR/$name"

    if [[ -L "$target" ]]; then
        rm "$target"
    elif [[ -d "$target" ]]; then
        warn "  $name: directory exists (not a symlink), skipping"
        continue
    fi

    ln -sf "$skill_dir" "$target"
    info "  $name"
done

# ── 7. Bootstrap registry ─────────────────────────────────────────────────────

info "Bootstrapping registry from session history..."
"$BIN_DIR/borg" scan 2>&1 || warn "borg scan had issues (registry may still be empty)"

# ── 8. Summary ────────────────────────────────────────────────────────────────

echo ""
info "Installation complete."
echo ""
echo "  Quick start:"
echo "    borg ls              View all tracked projects"
echo "    borg next            What should I work on?"
echo "    borg switch          Jump to a project"
echo "    borg help            All commands"
echo ""
echo "  Skills installed:"
for skill_dir in "$BORG_ROOT/skills/"*/; do
    [[ -d "$skill_dir" ]] && echo "    /$(basename "$skill_dir")"
done
echo ""
echo "  Next steps:"
echo "    1. Run: borg refresh --all        (generate summaries)"
echo "    2. In Claude Code: /plugin marketplace add alirezarezvani/claude-skills"
echo "    3. Create ~/.config/borg/config.zsh for work/life boundaries"
echo ""
echo "  Devcontainer users: add this volume mount to docker-compose.yml:"
echo "    - ~/.config/borg:/home/vscode/.config/borg:cached"
echo ""
