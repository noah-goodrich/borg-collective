#!/usr/bin/env zsh
# drone-hooks — host-side lifecycle hooks for drone's compose up/down.
#
# Projects can ship executable shell scripts at .devcontainer/borg-hooks/
# that run on the HOST around drone's docker compose calls:
#
#   pre-up.sh   runs before `docker compose up -d` (strict: non-zero exit aborts)
#   post-down.sh runs after  `docker compose down` (lenient: non-zero exit warns)
#
# The hook's working directory is the project root. BORG_PROJECT_NAME is
# exported. Hooks run via plain bash so their own `set -euo pipefail` stays
# scoped to the hook.

# Run a project's borg-hook by name.
# Usage: run_borg_hook <project_dir> <project_name> <hook_name> <strict|lenient>
# Returns: 0 on success or when hook is absent; non-zero only when mode=strict
#          and the hook returned non-zero. In lenient mode always returns 0.
run_borg_hook() {
    local project_dir="$1" project_name="$2" hook_name="$3" mode="${4:-strict}"
    local hook="$project_dir/.devcontainer/borg-hooks/$hook_name"

    [[ -f "$hook" ]] || return 0
    [[ -x "$hook" ]] || {
        echo "▸ WARN: borg-hook $hook_name is not executable — skipping" >&2
        return 0
    }

    echo "▸ Running borg-hook: $hook_name" >&2
    local rc=0
    (cd "$project_dir" && BORG_PROJECT_NAME="$project_name" bash "$hook") || rc=$?
    [[ "$rc" -eq 0 ]] && return 0

    if [[ "$mode" == "strict" ]]; then
        echo "▸ ERROR: borg-hook $hook_name failed (exit $rc) — aborting" >&2
        return "$rc"
    else
        echo "▸ WARN: borg-hook $hook_name failed (exit $rc) — continuing" >&2
        return 0
    fi
}
