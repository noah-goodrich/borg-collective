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

set -e

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

BORG_HOME="${0:A:h}"
# BORG_ROOT is the install path of the borg-collective source tree itself.
# Exposed so downstream tools (hooks resolving skill paths, setup re-runs)
# don't have to derive it from ${0:A:h} each time. BORG_HOME is kept as an
# internal alias for one release.
BORG_ROOT="$BORG_HOME"
export BORG_ROOT
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
chmod +x "$BORG_HOME/borg.zsh"
ln -sf "$BORG_HOME/borg.zsh" "$BIN_DIR/borg"
info "  borg -> $BORG_HOME/borg.zsh"

info "Installing drone CLI..."
chmod +x "$BORG_HOME/drone.zsh"
ln -sf "$BORG_HOME/drone.zsh" "$BIN_DIR/drone"
info "  drone -> $BORG_HOME/drone.zsh"

if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
    warn "$BIN_DIR is not in PATH. Add to ~/.zshrc:"
    warn '  export PATH="$HOME/.local/bin:$PATH"'
fi

# ── 3. Install borg-notifyd daemon + LaunchAgent ─────────────────────────────

info "Installing borg-notifyd..."
chmod +x "$BORG_HOME/bin/borg-notifyd"
ln -sf "$BORG_HOME/bin/borg-notifyd" "$BIN_DIR/borg-notifyd"
info "  borg-notifyd -> $BORG_HOME/bin/borg-notifyd"

info "Installing borg-vinculum-watch..."
chmod +x "$BORG_HOME/bin/borg-vinculum-watch"
ln -sf "$BORG_HOME/bin/borg-vinculum-watch" "$BIN_DIR/borg-vinculum-watch"
info "  borg-vinculum-watch -> $BORG_HOME/bin/borg-vinculum-watch"

if ! command -v fswatch &>/dev/null; then
    warn "fswatch not found — installing via Homebrew (required by borg-notifyd)..."
    brew install fswatch 2>&1 | grep -E '(Installing|Already|Error)' || true
fi

PLIST_NAME="com.stillpoint-labs.borg.notifyd.plist"
PLIST_SRC="$BORG_HOME/launchd/$PLIST_NAME"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME"
NOTIFYD_BIN="$BIN_DIR/borg-notifyd"
LOG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/borg"

mkdir -p "$(dirname "$PLIST_DEST")" "$LOG_DIR"

sed \
    -e "s|{{NOTIFYD_BIN}}|$NOTIFYD_BIN|g" \
    -e "s|{{LOG_DIR}}|$LOG_DIR|g" \
    "$PLIST_SRC" > "$PLIST_DEST"
info "  plist -> $PLIST_DEST"

if launchctl list "com.stillpoint-labs.borg.notifyd" &>/dev/null 2>&1; then
    info "  reloading launchd agent..."
    launchctl bootout "gui/$UID/com.stillpoint-labs.borg.notifyd" 2>/dev/null || true
fi
launchctl bootstrap "gui/$UID" "$PLIST_DEST"
info "  launchd agent bootstrapped."

# ── 3b. Install borg-cortex-watch daemon + LaunchAgent ───────────────────────

info "Installing borg-cortex-watch..."
chmod +x "$BORG_HOME/bin/borg-cortex-watch"
ln -sf "$BORG_HOME/bin/borg-cortex-watch" "$BIN_DIR/borg-cortex-watch"
info "  borg-cortex-watch -> $BORG_HOME/bin/borg-cortex-watch"

CORTEX_PLIST_NAME="com.stillpoint-labs.borg.cortex-wake.plist"
CORTEX_PLIST_SRC="$BORG_HOME/launchd/$CORTEX_PLIST_NAME"
CORTEX_PLIST_DEST="$HOME/Library/LaunchAgents/$CORTEX_PLIST_NAME"
CORTEX_WATCH_BIN="$BIN_DIR/borg-cortex-watch"

sed \
    -e "s|{{CORTEX_WATCH_BIN}}|$CORTEX_WATCH_BIN|g" \
    -e "s|{{LOG_DIR}}|$LOG_DIR|g" \
    "$CORTEX_PLIST_SRC" > "$CORTEX_PLIST_DEST"
info "  plist -> $CORTEX_PLIST_DEST"

if launchctl list "com.stillpoint-labs.borg.cortex-wake" &>/dev/null 2>&1; then
    info "  reloading launchd agent..."
    launchctl bootout "gui/$UID/com.stillpoint-labs.borg.cortex-wake" 2>/dev/null || true
fi
launchctl bootstrap "gui/$UID" "$CORTEX_PLIST_DEST"
info "  launchd agent bootstrapped."

# ── 3b2. Install borg-usage-watch daemon + LaunchAgent ───────────────────────
#
# BORG_USAGE_WATCH opt-out: default ON (installed/bootstrapped when unset or any value other
# than "0"). Set BORG_USAGE_WATCH=0 to skip installing/bootstrapping it entirely. If it is
# already bootstrapped from a previous run and the flag is now 0, bootout it so the opt-out
# actually takes effect on re-run.
USAGE_PLIST_NAME="com.stillpoint-labs.borg.usage-watch.plist"
USAGE_PLIST_DEST="$HOME/Library/LaunchAgents/$USAGE_PLIST_NAME"

if [[ "${BORG_USAGE_WATCH:-1}" == "0" ]]; then
    info "BORG_USAGE_WATCH=0 — skipping borg-usage-watch install."
    if launchctl list "com.stillpoint-labs.borg.usage-watch" &>/dev/null 2>&1; then
        info "  removing previously-bootstrapped agent..."
        launchctl bootout "gui/$UID/com.stillpoint-labs.borg.usage-watch" 2>/dev/null || true
    fi
else
    info "Installing borg-usage-watch (BORG_USAGE_WATCH=0 to opt out)..."
    chmod +x "$BORG_HOME/bin/borg-usage-watch"
    ln -sf "$BORG_HOME/bin/borg-usage-watch" "$BIN_DIR/borg-usage-watch"
    info "  borg-usage-watch -> $BORG_HOME/bin/borg-usage-watch"

    USAGE_PLIST_SRC="$BORG_HOME/launchd/$USAGE_PLIST_NAME"
    USAGE_WATCH_BIN="$BIN_DIR/borg-usage-watch"
    USAGE_PATH_VALUE="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
    USAGE_SAMPLES="${XDG_STATE_HOME:-$HOME/.local/state}/borg/usage-samples.jsonl"
    USAGE_WATCH_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/borg/usage-watch.log"

    sed \
        -e "s|{{USAGE_WATCH_BIN}}|$USAGE_WATCH_BIN|g" \
        -e "s|{{LOG_DIR}}|$LOG_DIR|g" \
        -e "s|{{USER}}|$USER|g" \
        -e "s|{{HOME}}|$HOME|g" \
        -e "s|{{PATH_VALUE}}|$USAGE_PATH_VALUE|g" \
        "$USAGE_PLIST_SRC" > "$USAGE_PLIST_DEST"
    info "  plist -> $USAGE_PLIST_DEST"

    if launchctl list "com.stillpoint-labs.borg.usage-watch" &>/dev/null 2>&1; then
        info "  reloading launchd agent..."
        launchctl bootout "gui/$UID/com.stillpoint-labs.borg.usage-watch" 2>/dev/null || true
    fi
    launchctl bootstrap "gui/$UID" "$USAGE_PLIST_DEST"
    info "  launchd agent bootstrapped."

    # Verify it actually produces output. Depends on #68 (idle polls also write a row); on
    # current main, an idle poll writes NO row, so this check is only meaningful once #68 lands.
    # An absent new row after kickstart is treated as informational, not fatal — a fresh machine
    # may have no claude panes running, but with #68 that legitimately yields an "idle" row, so
    # any new row (including an idle one) counts as pass.
    mkdir -p "$(dirname "$USAGE_SAMPLES")"
    BEFORE_COUNT=0
    [[ -f "$USAGE_SAMPLES" ]] && BEFORE_COUNT=$(wc -l < "$USAGE_SAMPLES" | tr -d ' ')

    info "  verifying usage-watch produces output (kickstart + poll up to 30s)..."
    launchctl kickstart -k "gui/$UID/com.stillpoint-labs.borg.usage-watch" 2>/dev/null || true

    VERIFIED=0
    for _i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
        sleep 2
        AFTER_COUNT=0
        [[ -f "$USAGE_SAMPLES" ]] && AFTER_COUNT=$(wc -l < "$USAGE_SAMPLES" | tr -d ' ')
        if (( AFTER_COUNT > BEFORE_COUNT )); then
            VERIFIED=1
            break
        fi
    done

    if (( VERIFIED )); then
        info "  usage-watch verified: new sample row written."
    else
        warn "usage-watch did not produce a new sample within 30s."
        warn "  Check: $USAGE_WATCH_LOG"
        warn "  Then run: borg doctor"
    fi
fi

# ── 3c. Install borg-reap daemon + LaunchAgent ───────────────────────────────

info "Installing borg-reap (hourly worktree reaper)..."

REAP_PLIST_NAME="com.stillpoint-labs.borg.reap.plist"
REAP_PLIST_SRC="$BORG_HOME/launchd/$REAP_PLIST_NAME"
REAP_PLIST_DEST="$HOME/Library/LaunchAgents/$REAP_PLIST_NAME"
BORG_BIN="$BIN_DIR/borg"

sed \
    -e "s|{{BORG_BIN}}|$BORG_BIN|g" \
    -e "s|{{LOG_DIR}}|$LOG_DIR|g" \
    "$REAP_PLIST_SRC" > "$REAP_PLIST_DEST"
info "  plist -> $REAP_PLIST_DEST"

if launchctl list "com.stillpoint-labs.borg.reap" &>/dev/null 2>&1; then
    info "  reloading launchd agent..."
    launchctl bootout "gui/$UID/com.stillpoint-labs.borg.reap" 2>/dev/null || true
fi
launchctl bootstrap "gui/$UID" "$REAP_PLIST_DEST"
info "  launchd agent bootstrapped (runs hourly; logs -> $LOG_DIR/reap.{stdout,stderr}.log)."

# ── 4. Hooks, skills, config, registry → borg setup ──────────────────────────

info "Running borg setup..."
"$BORG_HOME/borg.zsh" setup

# ── 5. Plugin detection + cairn detection ────────────────────────────────────

# Plugin check (REQUIRED): borg hooks are now owned by the borg-collective plugin.
# Without the plugin installed, no hooks fire. Detect and offer installation.
_plugin_installed=0
if command -v claude &>/dev/null; then
    if claude plugin list 2>/dev/null | grep -q "borg-collective" 2>/dev/null; then
        _plugin_installed=1
    fi
fi

if [[ "$_plugin_installed" -eq 0 ]]; then
    echo ""
    warn "borg-collective plugin NOT detected in Claude Code."
    echo ""
    echo "  The plugin owns hook registration (SessionStart, Stop, Notification, etc.)."
    echo "  Without it, borg lifecycle hooks will NOT fire."
    echo ""
    echo "  Install the plugin:"
    echo "    claude plugin install borg-collective@noah-local"
    echo ""
    if [[ "$QUIET" -eq 0 ]]; then
        printf "  Install it now? [y/N] "
        read -r "_plugin_reply"
        if [[ "${_plugin_reply:-N}" =~ ^[Yy]$ ]]; then
            if claude plugin install borg-collective@noah-local 2>&1; then
                info "Plugin installed."
            else
                warn "Plugin install failed. Run manually: claude plugin install borg-collective@noah-local"
            fi
        fi
    fi
fi

# Cairn check (OPTIONAL): cairn is the knowledge graph. Borg works without it.
_cairn_ok=0
if command -v cairn &>/dev/null; then
    if curl -fsS "http://localhost:8767/health" 2>/dev/null | grep -q '"status":"ok"' 2>/dev/null; then
        _cairn_ok=1
    fi
fi

if [[ "$_cairn_ok" -eq 0 ]]; then
    echo ""
    if command -v cairn &>/dev/null; then
        warn "cairn is installed but not responding at localhost:8767."
        echo "  To start cairn: drone up cairn"
    else
        info "cairn not found — cross-session knowledge graph is optional."
        echo "  To install: see https://github.com/noah-goodrich/cairn"
    fi
    echo "  Borg works fully without cairn; checkpoints still save locally."
    echo ""
fi

# ── 6. Summary ────────────────────────────────────────────────────────────────

echo ""
info "Installation complete."
echo ""
echo "  The Borg workflow:"
echo "    1. drone start <project> <feature> create worktree + branch, launch Claude"
echo "    2. /borg-plan                      lock objectives + acceptance criteria"
echo "    3. (implement)"
echo "    4. /simplify                       review changed code before committing"
echo "    5. /borg-link-up + git commit     flush session state, document milestone"
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
for skill_dir in "$BORG_HOME/skills/"*/(N); do
    [[ -d "$skill_dir" ]] && echo "    /$(basename "$skill_dir")"
done
echo ""
if command -v cortex &>/dev/null; then
    echo "  CoCo integration: active"
    echo "    borg ls shows [X] badge for Cortex Code projects"
    echo "    borg scan discovers CoCo sessions from session-log.md"
    echo "    Stop hook fires on CoCo sessions → registry update + checkpoint nudge"
    echo ""
fi
echo "  Community skills (run in Claude Code):"
echo "    /plugin marketplace add alirezarezvani/claude-skills"
echo "    Adds: Boris Cherny's 57-tip framework, Scope Guard, 205+ engineering skills"
echo ""
echo "  Environment variables:"
echo "    BORG_ORCHESTRATOR_ROOT=\$HOME/dev   workspace root (where orchestrator runs)"
echo "    BORG_ROOT=$BORG_HOME    install path of the borg source tree"
echo ""
echo "  Optional: ~/.config/borg/config.zsh for work/life boundaries"
echo "    BORG_WORK_HOURS=\"09:00-18:00\""
echo "    BORG_WORK_PROJECTS=\"api-service,internal-tools\""
echo "    BORG_MAX_ACTIVE=3"
echo ""
echo "  tmux session: 'borg' (rename your existing 'dev' session with: tmux rename-session borg)"
echo ""
