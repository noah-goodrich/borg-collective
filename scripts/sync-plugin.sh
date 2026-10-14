#!/usr/bin/env bash
# scripts/sync-plugin.sh — sync skills and agents from the source repo to the plugin distribution.
#
# Run after updating skills in skills/ or agents in agents/ to keep the plugin current before
# publishing.
# Usage: ./scripts/sync-plugin.sh [--dry-run]
#
# Source of truth: /Users/noah/dev/borg-collective/{skills,agents}/
# Plugin target:   /Users/noah/dev/claude-plugins/borg-collective/{skills,agents}/
#
# Note: hooks and lib/ in the plugin are intentionally NOT synced here — the plugin
# hooks are a curated stateless subset (bash-guard, notify, nudges) and the plugin
# carries no lib/ (self-contained, no machine-local sources). Sync skills + agents only.
#
# The agents loop is additive and existing-targets-only; the skills loop covers whole skill
# directories of skills already in the distro (it may create files inside them, e.g.
# references/; it never deletes; dot-prefixed files are skipped). There is no --delete —
# this is a one-way source→distro refresh, not a true mirror.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${SCRIPT_DIR}/../skills"
AGENTS_SRC="${SCRIPT_DIR}/../agents"
DST_DEFAULT="/Users/noah/dev/claude-plugins/borg-collective/skills"
AGENTS_DST_DEFAULT="/Users/noah/dev/claude-plugins/borg-collective/agents"
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

AGENTS_DST="${PLUGIN_AGENTS_DIR:-$AGENTS_DST_DEFAULT}"

changed=0
for skill_dir in "$SRC"/*/; do
    skill_name="${skill_dir%/}"
    skill_name="${skill_name##*/}"

    [[ -f "${skill_dir}SKILL.md" ]] || continue
    [[ -d "$DST/$skill_name" ]] || continue  # only sync skills that already exist in the plugin

    # Whole skill directory (SKILL.md plus references/), additive: never deletes.
    while IFS= read -r rel; do
        rel="${rel#./}"
        src_file="${skill_dir}${rel}"
        dst_file="$DST/$skill_name/$rel"
        if ! diff -q "$src_file" "$dst_file" >/dev/null 2>&1; then
            if [[ "$DRY_RUN" -eq 1 ]]; then
                echo "would sync: $skill_name/$rel"
            else
                mkdir -p "$(dirname "$dst_file")"
                cp "$src_file" "$dst_file"
                echo "synced: $skill_name/$rel"
            fi
            changed=$((changed + 1))
        fi
    done < <(cd "$skill_dir" && find . -type f -not -path '*/.*' | LC_ALL=C sort)
done

# Agents: same additive, existing-targets-only contract as skills above. Only overwrite agent
# files already present in the distro; never create or delete. Skipped silently if the source
# or distro agents/ dir is absent.
if [[ -d "$AGENTS_SRC" && -d "$AGENTS_DST" ]]; then
    for src_agent in "$AGENTS_SRC"/*.md; do
        [[ -f "$src_agent" ]] || continue
        agent_name="${src_agent##*/}"
        dst_agent="$AGENTS_DST/$agent_name"

        [[ -f "$dst_agent" ]] || continue  # only sync agents that already exist in the plugin

        if ! diff -q "$src_agent" "$dst_agent" >/dev/null 2>&1; then
            if [[ "$DRY_RUN" -eq 1 ]]; then
                echo "would sync: agents/$agent_name"
            else
                cp "$src_agent" "$dst_agent"
                echo "synced: agents/$agent_name"
            fi
            changed=$((changed + 1))
        fi
    done
fi

if [[ "$changed" -eq 0 ]]; then
    echo "all skills and agents in sync"
fi
