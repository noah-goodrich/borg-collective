#!/usr/bin/env bash
# scripts/build-plugin.sh — build the publishable plugin subset from this repo.
#
# Source of truth: /Users/noah/dev/borg-collective  (this repo)
# Plugin target:   /Users/noah/dev/claude-plugins/borg-collective/
#
# What this builds:
#   skills/       — all SKILL.md files (same as sync-plugin.sh, now subsumed)
#   hooks/        — curated self-contained hooks (NO source of ~/.claude/lib)
#   agents/       — borg-nanoprobe.md subagent definition
#   hooks.json    — regenerated hook wiring for all shipped hooks
#   plugin.json   — version bump (patch) in .claude-plugin/plugin.json
#
# Self-containment contract for hooks that reference borg state/registry:
#   1. All helpers from lib/borg-hooks.sh are INLINED — no source path references.
#   2. CLI-calling hooks (those that depend on the borg CLI being present) begin with:
#        command -v borg >/dev/null 2>&1 || exit 0
#      The lifecycle hooks (borg-link-down/up, borg-notify, borg-nanoprobe-log)
#      also carry this guard because they write to ~/.config/borg/ which only
#      exists when borg is installed.
#
# Usage:
#   ./scripts/build-plugin.sh [--dry-run]
#
# In --dry-run mode, no files are written; the script prints what would change.
# Wire into 'borg setup' to auto-run on the dev machine.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
PLUGIN_DIR="${PLUGIN_DIR_OVERRIDE:-/Users/noah/dev/claude-plugins/borg-collective}"
DRY_RUN=0

for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=1
done

# ── Helpers ───────────────────────────────────────────────────────────────────

_info()  { echo "▸ $*"; }
_dry()   { echo "[dry-run] $*"; }
_warn()  { echo "▸ WARN: $*" >&2; }

_copy_if_changed() {
    local src="$1" dst="$2"
    local label="${3:-$dst}"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        if ! diff -q "$src" "$dst" >/dev/null 2>&1; then
            _dry "would update: $label"
        fi
        return
    fi
    mkdir -p "$(dirname "$dst")"
    if ! diff -q "$src" "$dst" >/dev/null 2>&1; then
        cp "$src" "$dst"
        _info "  updated: $label"
    fi
}

_write_if_changed() {
    local content="$1" dst="$2"
    local label="${3:-$dst}"
    local tmp
    tmp=$(mktemp)
    printf '%s' "$content" > "$tmp"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        if ! diff -q "$tmp" "$dst" >/dev/null 2>&1; then
            _dry "would update: $label"
        fi
        rm -f "$tmp"
        return
    fi
    mkdir -p "$(dirname "$dst")"
    if ! diff -q "$tmp" "$dst" >/dev/null 2>&1; then
        mv "$tmp" "$dst"
        _info "  updated: $label"
    else
        rm -f "$tmp"
    fi
}

# ── Guard: plugin target must exist ──────────────────────────────────────────

if [[ ! -d "$PLUGIN_DIR" ]]; then
    _warn "Plugin dir not found: $PLUGIN_DIR"
    _warn "This script is dev-machine-only. Skipping plugin build."
    exit 0
fi

_info "Building borg-collective plugin from source..."
_info "  src:  $REPO_ROOT"
_info "  dest: $PLUGIN_DIR"
[[ "$DRY_RUN" -eq 1 ]] && _info "  (dry-run — no files written)"
echo ""

# ── Phase 1: Skills ───────────────────────────────────────────────────────────

_info "Phase 1: Skills"
SKILLS_SRC="$REPO_ROOT/skills"
SKILLS_DST="$PLUGIN_DIR/skills"

if [[ ! -d "$SKILLS_SRC" ]]; then
    _warn "skills/ not found in source repo — skipping"
else
    skills_changed=0
    for skill_dir in "$SKILLS_SRC"/*/; do
        skill_name="${skill_dir%/}"
        skill_name="${skill_name##*/}"
        src_skill="${skill_dir}SKILL.md"
        dst_skill="$SKILLS_DST/$skill_name/SKILL.md"

        [[ -f "$src_skill" ]] || continue

        if [[ ! -d "$SKILLS_DST/$skill_name" ]]; then
            if [[ "$DRY_RUN" -eq 1 ]]; then
                _dry "would create skill dir: $skill_name"
            else
                mkdir -p "$SKILLS_DST/$skill_name"
                _info "  created skill dir: $skill_name"
            fi
        fi

        if ! diff -q "$src_skill" "$dst_skill" >/dev/null 2>&1; then
            if [[ "$DRY_RUN" -eq 1 ]]; then
                _dry "would sync skill: $skill_name"
            else
                cp "$src_skill" "$dst_skill"
                _info "  synced skill: $skill_name"
            fi
            skills_changed=$((skills_changed + 1))
        fi
    done
    if [[ "$skills_changed" -eq 0 ]]; then
        _info "  all skills in sync"
    fi
fi

# ── Phase 2: Self-contained hooks ────────────────────────────────────────────

_info "Phase 2: Hooks"
HOOKS_SRC="$REPO_ROOT/hooks"
HOOKS_DST="$PLUGIN_DIR/hooks"
LIB_SRC="$REPO_ROOT/lib"

if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$HOOKS_DST"
fi

# Load the shared lib content so we can inline it into hooks that need it.
LIB_FILE="$LIB_SRC/borg-hooks.sh"
REAPER_FILE="$LIB_SRC/reaper.sh"

if [[ ! -f "$LIB_FILE" ]]; then
    _warn "lib/borg-hooks.sh not found — cannot build self-contained hooks"
    exit 1
fi

# Strip the trailing 'source reaper.sh' line (it's inlined separately) and
# extract the helpers as a self-contained block to embed in hooks that need it.
_HOOKS_LIB_CONTENT=$(sed '/^source.*reaper\.sh/d' "$LIB_FILE")
_REAPER_CONTENT=$(cat "$REAPER_FILE" 2>/dev/null || true)

# The embedded lib block: helpers from borg-hooks.sh + reaper.sh, inlined.
# Wrapped in a marker comment so the build is auditable.
_embedded_lib() {
cat <<'__LIBEOF__'
# ── Inlined helpers (borg-hooks.sh + reaper.sh) — no external source deps ────
__LIBEOF__
echo "$_HOOKS_LIB_CONTENT"
echo ""
echo "# ── Inlined: reaper.sh ──────────────────────────────────────────────────────"
echo "$_REAPER_CONTENT"
echo "# ── End inlined helpers ─────────────────────────────────────────────────────"
echo ""
}

# Build a self-contained hook by:
#   1. Preserving the shebang and leading comment block.
#   2. Inserting the borg guard + PATH setup (if the hook uses borg state).
#   3. Inlining the lib helpers where the 'source ...' line was.
#
# Usage: _build_self_contained_hook <src_hook> <dst_hook> <needs_lib: 0|1>
_build_self_contained_hook() {
    local src="$1" dst="$2" needs_lib="${3:-1}"
    local label="${dst##*/}"

    if [[ ! -f "$src" ]]; then
        _warn "hook not found: $src — skipping"
        return
    fi

    local tmp
    tmp=$(mktemp)

    # ── Shebang line (always first) ──────────────────────────────────────────
    head -1 "$src" > "$tmp"

    # ── Borg guard: hooks that write to ~/.config/borg/ need borg installed ──
    # All lifecycle hooks (link-down, link-up, notify, nanoprobe-log) depend on
    # the borg registry/state infrastructure. Guard them so they are no-ops on
    # machines without borg installed.
    {
        printf '# Built by scripts/build-plugin.sh — self-contained, no external source deps.\n'
        printf 'command -v borg >/dev/null 2>&1 || exit 0\n'
        printf '\n'
    } >> "$tmp"

    # ── Rest of the original hook (skip shebang; replace source line with lib) ──
    local in_comment_block=1
    while IFS= read -r line; do
        # Track when we leave the leading comment block (first non-blank, non-# line)
        if [[ "$in_comment_block" -eq 1 ]]; then
            if [[ "$line" != "#"* && -n "$line" ]]; then
                in_comment_block=0
            fi
        fi

        # Replace 'source .../borg-hooks.sh' with the inlined lib
        if [[ "$needs_lib" -eq 1 && "$line" =~ ^[[:space:]]*source.*borg-hooks\.sh ]]; then
            if [[ "$DRY_RUN" -eq 0 ]]; then
                _embedded_lib >> "$tmp"
            fi
            continue
        fi

        printf '%s\n' "$line" >> "$tmp"
    done < <(tail -n +2 "$src")

    if [[ "$DRY_RUN" -eq 1 ]]; then
        if ! diff -q "$tmp" "$dst" >/dev/null 2>&1; then
            _dry "would update hook: $label"
        fi
        rm -f "$tmp"
        return
    fi

    mkdir -p "$(dirname "$dst")"
    if ! diff -q "$tmp" "$dst" >/dev/null 2>&1; then
        mv "$tmp" "$dst"
        chmod +x "$dst"
        _info "  built hook: $label"
    else
        rm -f "$tmp"
        _info "  hook unchanged: $label"
    fi
}

# Hooks that are already self-contained (no lib source): copy as-is with guard.
_build_self_contained_hook "$HOOKS_SRC/bash-guard.sh"        "$HOOKS_DST/bash-guard.sh"        0
_build_self_contained_hook "$HOOKS_SRC/pre-commit-remind.sh" "$HOOKS_DST/pre-commit-remind.sh" 0
_build_self_contained_hook "$HOOKS_SRC/tool-count-nudge.sh"  "$HOOKS_DST/tool-count-nudge.sh"  0
_build_self_contained_hook "$HOOKS_SRC/notify.sh"            "$HOOKS_DST/notify.sh"            0

# Hooks that source lib/borg-hooks.sh: inline the helpers.
_build_self_contained_hook "$HOOKS_SRC/borg-link-down.sh"    "$HOOKS_DST/borg-link-down.sh"    1
_build_self_contained_hook "$HOOKS_SRC/borg-link-up.sh"      "$HOOKS_DST/borg-link-up.sh"      1
_build_self_contained_hook "$HOOKS_SRC/borg-notify.sh"       "$HOOKS_DST/borg-notify.sh"       1
_build_self_contained_hook "$HOOKS_SRC/borg-plan-promote.sh" "$HOOKS_DST/borg-plan-promote.sh" 1
# borg-nanoprobe-log.sh has no lib source — copy as-is with guard.
_build_self_contained_hook "$HOOKS_SRC/borg-nanoprobe-log.sh" "$HOOKS_DST/borg-nanoprobe-log.sh" 0

# ── Phase 3: Agent definition ─────────────────────────────────────────────────

_info "Phase 3: Agents"
AGENTS_SRC="$REPO_ROOT/agents"
AGENTS_DST="$PLUGIN_DIR/agents"

if [[ ! -f "$AGENTS_SRC/borg-nanoprobe.md" ]]; then
    _warn "agents/borg-nanoprobe.md not found — skipping agents"
else
    if [[ "$DRY_RUN" -eq 0 ]]; then
        mkdir -p "$AGENTS_DST"
    fi
    _copy_if_changed "$AGENTS_SRC/borg-nanoprobe.md" "$AGENTS_DST/borg-nanoprobe.md" "agents/borg-nanoprobe.md"
fi

# ── Phase 4: Regenerate hooks.json ───────────────────────────────────────────

_info "Phase 4: hooks.json"

# One top-level 'hooks' record per the plugin authoring spec.
# bash-guard and pre-commit-remind fire only on Bash tool calls.
# borg-plan-promote fires on Edit/Write/NotebookEdit.
# All others fire on every invocation of their event (matcher: "").
HOOKS_JSON='{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/borg-link-down.sh",
            "timeout": 15
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/borg-link-up.sh",
            "timeout": 15
          }
        ]
      },
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/notify.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/notify.sh",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/borg-notify.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/bash-guard.sh",
            "timeout": 5
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/pre-commit-remind.sh",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": "Edit|Write|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/borg-plan-promote.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/tool-count-nudge.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/borg-nanoprobe-log.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}'

_write_if_changed "$HOOKS_JSON" "$HOOKS_DST/hooks.json" "hooks/hooks.json"

# ── Phase 5: Bump plugin.json version (patch) ────────────────────────────────

_info "Phase 5: plugin.json version bump"
PLUGIN_JSON="$PLUGIN_DIR/.claude-plugin/plugin.json"

if [[ ! -f "$PLUGIN_JSON" ]]; then
    _warn "plugin.json not found at $PLUGIN_JSON — skipping version bump"
else
    current_version=$(jq -r '.version' "$PLUGIN_JSON" 2>/dev/null || echo "0.0.0")
    # Bump patch: 0.2.0 → 0.2.1
    IFS='.' read -r vmaj vmin vpatch <<< "$current_version"
    vpatch="${vpatch:-0}"
    new_version="${vmaj}.${vmin}.$((vpatch + 1))"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        _dry "would bump version: $current_version → $new_version"
    else
        tmp=$(mktemp)
        jq --arg v "$new_version" '.version = $v' "$PLUGIN_JSON" > "$tmp"
        mv "$tmp" "$PLUGIN_JSON"
        _info "  bumped version: $current_version → $new_version"
    fi
fi

echo ""
_info "Build complete."
if [[ "$DRY_RUN" -eq 0 ]]; then
    _info "  Next: cd /Users/noah/dev/claude-plugins && git add -A && git commit"
    _info "  Then: claude plugin update borg-collective"
fi
