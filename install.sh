#!/usr/bin/env zsh
# install.sh — The Borg Collective installer
#
# Handles: dependency checks, binary symlinks, PATH warning.
# Delegates: hooks, skills, config, registry → `borg setup`
#
# Safe to re-run. Works standalone or called from a parent installer (e.g., dotfiles/install.sh).
#
# Usage:
#   ./install.sh              Full install (interactive, checks deps)
#   ./install.sh --quiet      Skip ASCII art and prompts
#
# NOTE: For non-dev install, use Homebrew:
#   brew tap noah-goodrich/borg-collective https://github.com/noah-goodrich/borg-collective.git
#   brew install borg-collective
#   borg setup
#
# Use install.sh only for dev (editing source directly from this clone).

set -e

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

BORG_ROOT="${0:A:h}"
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

# ── 1b. Check optional dependencies ──────────────────────────────────────────

DOTFILES_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
POSTGRES_COMPOSE="$DOTFILES_DIR/devcontainer/docker-compose.postgres.yml"

if [[ ! -d "$DOTFILES_DIR" ]]; then
    warn "Dotfiles not found at $DOTFILES_DIR"
    warn "drone up requires dotfiles for shared postgres compose and base image."
    warn "Install dotfiles first, or drone will only work without containers."
fi

if [[ -d "$DOTFILES_DIR" && ! -f "$POSTGRES_COMPOSE" ]]; then
    warn "Missing: $POSTGRES_COMPOSE"
    warn "drone up needs this for shared postgres. Run dotfiles install.sh to set it up."
fi

# ── 2. Install borg and drone CLIs ───────────────────────────────────────────

mkdir -p "$BIN_DIR"

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

# ── 3. Hooks, skills, config, registry → borg setup ──────────────────────────

info "Running borg setup..."
"$BORG_ROOT/borg.zsh" setup

# ── 4. Summary ────────────────────────────────────────────────────────────────

echo ""
info "Installation complete."
echo ""
echo "  The Borg workflow:"
echo "    1. drone start <project> <feature> create worktree + branch, launch Claude"
echo "    2. /borg-plan                      lock objectives + acceptance criteria"
echo "    3. (implement)"
echo "    4. /simplify                       review changed code before committing"
echo "    5. /checkpoint + git commit        document session milestone"
echo "    6. borg next / Ctrl+Space >        what needs attention? jump there."
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
    echo "  CoCo integration: active"
    echo "    borg ls shows [X] badge for Cortex Code projects"
    echo "    borg scan discovers CoCo sessions from session-log.md"
    echo "    Stop hook fires on CoCo sessions → debrief + cairn record"
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
