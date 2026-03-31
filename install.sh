#!/usr/bin/env zsh
# install.sh — The Borg Collective installer
#
# Safe to re-run. Installs borg CLI, hooks, skills, and bootstraps registry.
# Works standalone or called from a parent installer (e.g., dotfiles/install.sh).
#
# Usage:
#   ./install.sh              Full install (interactive, checks deps)
#   ./install.sh --quiet      Skip ASCII art and prompts

set -e

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

BORG_ROOT="${0:A:h}"
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

info "Dependencies satisfied."

# ── 2. Create runtime directories ─────────────────────────────────────────────

info "Creating runtime directories..."
mkdir -p "$BORG_DIR/desktop"
mkdir -p "$CLAUDE_DIR"
mkdir -p "$CLAUDE_HOOKS_DIR"
mkdir -p "$CLAUDE_SKILLS_DIR"
mkdir -p "$BIN_DIR"

[[ -f "$BORG_DIR/registry.json" ]] || echo '{"projects":{}}' > "$BORG_DIR/registry.json"

# ── 3. Install borg and drone CLIs ───────────────────────────────────────────

info "Installing borg CLI..."
chmod +x "$BORG_ROOT/borg.zsh"
ln -sf "$BORG_ROOT/borg.zsh" "$BIN_DIR/borg"
info "  borg -> $BORG_ROOT/borg.zsh"

info "Installing drone CLI..."
chmod +x "$BORG_ROOT/drone.zsh"
ln -sf "$BORG_ROOT/drone.zsh" "$BIN_DIR/drone"
info "  drone -> $BORG_ROOT/drone.zsh"

if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
    warn "$BIN_DIR is not in PATH. Add to ~/.zshrc:"
    warn '  export PATH="$HOME/.local/bin:$PATH"'
fi

# ── 4. Install hooks ─────────────────────────────────────────────────────────

info "Installing hooks..."
chmod +x "$BORG_ROOT/hooks/"*.sh

for hook in "$BORG_ROOT/hooks/"*.sh; do
    name="$(basename "$hook")"
    ln -sf "$hook" "$CLAUDE_HOOKS_DIR/$name"
    info "  $name"
done

# ── 5. Register hooks in settings.json ────────────────────────────────────────

# Register a hook in a settings.json file
# Usage: register_hook <settings_file> <hook_cmd> <event> <label>
register_hook() {
    local settings="$1" hook_cmd="$2" event="$3" label="$4"
    local timeout_val=10

    # Check if already registered (avoid duplicates)
    if jq -e --arg evt "$event" --arg cmd "$hook_cmd" \
        '.hooks[$evt] // [] | map(.hooks[]? | select(.command == $cmd)) | length > 0' \
        "$settings" &>/dev/null; then
        info "  $event: $label (already registered)"
        return
    fi

    # Add hook entry with timeout
    local tmp="$settings.tmp.$$"
    jq --arg evt "$event" --arg cmd "$hook_cmd" --argjson timeout "$timeout_val" '
        if .hooks == null then .hooks = {} else . end |
        if .hooks[$evt] == null then .hooks[$evt] = [] else . end |
        .hooks[$evt] += [{"matcher": "", "hooks": [{"type": "command", "command": $cmd, "timeout": $timeout}]}]
    ' "$settings" > "$tmp" && mv "$tmp" "$settings"
    info "  $event: $label (registered)"
}

# 5a. Claude Code hooks
if [[ -f "$CLAUDE_SETTINGS" ]]; then
    info "Registering hooks in Claude Code settings.json..."
    register_hook "$CLAUDE_SETTINGS" "\$HOME/.claude/hooks/borg-start.sh"  "SessionStart" "borg-start.sh"
    register_hook "$CLAUDE_SETTINGS" "\$HOME/.claude/hooks/borg-stop.sh"   "Stop"         "borg-stop.sh"
    register_hook "$CLAUDE_SETTINGS" "\$HOME/.claude/hooks/borg-notify.sh" "Notification"  "borg-notify.sh"
else
    warn "No settings.json at $CLAUDE_SETTINGS"
    warn "Claude Code hooks installed but not registered. See README.md for manual registration."
fi

# 5b. Cortex Code CLI (CoCo) hooks
COCO_DIR="$HOME/.snowflake/cortex"
COCO_SETTINGS="$COCO_DIR/settings.json"

if command -v cortex &>/dev/null; then
    info "Cortex Code CLI detected — configuring CoCo integration..."
    mkdir -p "$COCO_DIR"

    # Create settings.json if it doesn't exist
    [[ -f "$COCO_SETTINGS" ]] || echo '{}' > "$COCO_SETTINGS"

    # Symlink hooks into CoCo hooks dir (same scripts, different location)
    mkdir -p "$COCO_DIR/hooks"
    for hook in "$BORG_ROOT/hooks/"*.sh; do
        name="$(basename "$hook")"
        ln -sf "$hook" "$COCO_DIR/hooks/$name"
    done

    info "Registering hooks in CoCo settings.json..."
    register_hook "$COCO_SETTINGS" "\$HOME/.snowflake/cortex/hooks/borg-start.sh"  "SessionStart" "borg-start.sh"
    register_hook "$COCO_SETTINGS" "\$HOME/.snowflake/cortex/hooks/borg-stop.sh"   "Stop"         "borg-stop.sh"
    register_hook "$COCO_SETTINGS" "\$HOME/.snowflake/cortex/hooks/borg-notify.sh" "Notification"  "borg-notify.sh"

    # Register skills with CoCo
    info "Registering skills with CoCo..."
    for skill_dir in "$BORG_ROOT/skills/"*/; do
        [[ -d "$skill_dir" ]] || continue
        name="$(basename "$skill_dir")"
        cortex skill add "$skill_dir" 2>/dev/null && info "  $name (cortex)" || warn "  $name: cortex skill add failed"
    done
else
    info "Cortex Code CLI not found — skipping CoCo integration"
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

# ── 7. Install tmux keybinding ────────────────────────────────────────────────

TMUX_CONF="$HOME/.config/tmux/tmux.conf"
if [[ -f "$TMUX_CONF" ]]; then
    if ! grep -q "borg next" "$TMUX_CONF" 2>/dev/null; then
        info "Adding tmux keybinding: Ctrl+Space > (borg next --switch)"
        echo "" >> "$TMUX_CONF"
        echo '# Borg: jump to most pressing project (borg next --switch)' >> "$TMUX_CONF"
        echo 'bind > run-shell "$HOME/.local/bin/borg next --switch 2>/dev/null || tmux display-message '"'"'All clear — take a break'"'"'"' >> "$TMUX_CONF"
    else
        info "tmux keybinding already configured"
    fi
    # Reload tmux config if tmux is running
    tmux source-file "$TMUX_CONF" 2>/dev/null && info "tmux config reloaded" || true
else
    warn "tmux.conf not found at $TMUX_CONF — add keybinding manually:"
    warn '  bind > run-shell "$HOME/.local/bin/borg next --switch"'
fi

# ── 8. Bootstrap registry ─────────────────────────────────────────────────────

info "Bootstrapping registry from session history..."
"$BORG_ROOT/borg.zsh" scan 2>&1 || warn "borg scan had issues (registry may still be empty)"

# ── 9. Summary ────────────────────────────────────────────────────────────────

echo ""
info "Installation complete."
echo ""
echo "  The Borg workflow:"
echo "    1. drone up <project>              spin up a project (container + tmux window)"
echo "    2. drone claude <project>          launch Claude in that window"
echo "    3. borg next                       what needs your attention?"
echo "    4. Ctrl+Space >                    jump there instantly"
echo "    5. /borg-plan                      lock acceptance criteria"
echo "    6. /borg-ship                      evaluate shipping readiness"
echo ""
echo "  borg commands:"
echo "    borg next [--switch]   Single recommendation + jump there"
echo "    borg ls                Full project dashboard"
echo "    borg switch <project>  fzf picker → tmux window"
echo "    borg scan              Auto-discover projects from session history"
echo "    borg help              All borg commands"
echo ""
echo "  drone commands:"
echo "    drone up [project]     Start container + tmux window"
echo "    drone down [project]   Stop container + remove window"
echo "    drone claude [project] Launch Claude Code in project window"
echo "    drone restart [all]    Restart containers"
echo "    drone status           Show all active drones"
echo "    drone help             All drone commands"
echo ""
echo "  Skills installed:"
for skill_dir in "$BORG_ROOT/skills/"*/; do
    [[ -d "$skill_dir" ]] && echo "    /$(basename "$skill_dir")"
done
echo ""
if command -v cortex &>/dev/null; then
    echo "  CoCo integration:"
    echo "    Hooks registered in ~/.snowflake/cortex/settings.json"
    echo "    Skills registered via cortex skill add"
    echo ""
fi
echo "  Community skills (run in Claude Code):"
echo "    /plugin marketplace add alirezarezvani/claude-skills"
echo "    Adds: Boris Cherny's 57-tip framework, Scope Guard, 205+ engineering skills"
echo ""
echo "  Optional: ~/.config/borg/config.zsh for work/life boundaries"
echo "    BORG_WORK_HOURS=\"09:00-18:00\""
echo "    BORG_WORK_PROJECTS=\"api-service,internal-tools\""
echo "    BORG_MAX_ACTIVE=3"
echo ""
echo "  tmux session: 'borg' (rename your existing 'dev' session with: tmux rename-session borg)"
echo ""
