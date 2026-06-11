#!/usr/bin/env bash
# scripts/check-plugin-version.sh — assert plugin.json version == borg-collective VERSION.
#
# Exits 0 when versions match; exits 1 with a clear message when they diverge.
# Intended as a lightweight drift-guard: run manually, from CI, or from bats tests.
#
# Usage:
#   ./scripts/check-plugin-version.sh
#
# To fix a mismatch, run:
#   ./scripts/build-plugin.sh
# or manually set plugin.json "version" to the value in VERSION.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
VERSION_FILE="$REPO_ROOT/VERSION"
PLUGIN_JSON="${PLUGIN_DIR_OVERRIDE:-/Users/noah/dev/claude-plugins}/borg-collective/.claude-plugin/plugin.json"

if [[ ! -f "$VERSION_FILE" ]]; then
    echo "ERROR: VERSION file not found: $VERSION_FILE" >&2
    exit 1
fi

if [[ ! -f "$PLUGIN_JSON" ]]; then
    echo "ERROR: plugin.json not found: $PLUGIN_JSON" >&2
    echo "  Set PLUGIN_DIR_OVERRIDE to override the default path." >&2
    exit 1
fi

cli_version=$(tr -d '[:space:]' < "$VERSION_FILE")
plugin_version=$(jq -r '.version' "$PLUGIN_JSON" 2>/dev/null || echo "")

if [[ "$cli_version" == "$plugin_version" ]]; then
    echo "OK: plugin version in sync with CLI — $cli_version"
    exit 0
else
    echo "ERROR: version mismatch detected" >&2
    echo "  CLI (VERSION file):   $cli_version" >&2
    echo "  Plugin (plugin.json): $plugin_version" >&2
    echo "" >&2
    echo "  Fix: run ./scripts/build-plugin.sh (or set plugin.json version to $cli_version)" >&2
    exit 1
fi
