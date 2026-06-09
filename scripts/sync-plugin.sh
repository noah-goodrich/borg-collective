#!/usr/bin/env bash
# scripts/sync-plugin.sh — sync skills from the source repo to the plugin distribution.
#
# Run after updating skills in skills/ to keep the plugin current before publishing.
# Usage: ./scripts/sync-plugin.sh [--dry-run]
#
# Source of truth: /Users/noah/dev/borg-collective/skills/
# Plugin target:   /Users/noah/dev/claude-plugins/borg-collective/skills/
#
# Note: hooks and lib/ in the plugin are intentionally NOT synced here — the plugin
# hooks are a curated stateless subset (bash-guard, notify, nudges) and the plugin
# carries no lib/ (self-contained, no machine-local sources). Sync skills only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${SCRIPT_DIR}/../skills"
DST_DEFAULT="/Users/noah/dev/claude-plugins/borg-collective/skills"
DRY_RUN=0

for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=1
done

if [[ ! -d "$SRC" ]]; then
    echo "ERROR: source not found: $SRC" >&2
    exit 1
fi

DST="${PLUGIN_SKILLS_DIR:-$DST_DEFAULT}"

if [[ ! -d "$DST" ]]; then
    echo "ERROR: plugin skills dir not found: $DST" >&2
    echo "Set PLUGIN_SKILLS_DIR to override the default path." >&2
    exit 1
fi

changed=0
for skill_dir in "$SRC"/*/; do
    skill_name="${skill_dir%/}"
    skill_name="${skill_name##*/}"
    src_skill="${skill_dir}SKILL.md"
    dst_skill="$DST/$skill_name/SKILL.md"

    [[ -f "$src_skill" ]] || continue
    [[ -d "$DST/$skill_name" ]] || continue  # only sync skills that already exist in the plugin

    if ! diff -q "$src_skill" "$dst_skill" >/dev/null 2>&1; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
            echo "would sync: $skill_name"
        else
            cp "$src_skill" "$dst_skill"
            echo "synced: $skill_name"
        fi
        changed=$((changed + 1))
    fi
done

if [[ "$changed" -eq 0 ]]; then
    echo "all skills in sync"
fi
