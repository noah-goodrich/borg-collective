#!/usr/bin/env bats
# Parity between the hooks the Claude plugin registers and the hooks borg registers for Cortex Code CLI.
#
# The plugin list is read from its source of truth, the HOOKS_JSON section of scripts/build-plugin.sh, never copied here.
# The Cortex side is three arrays in borg.zsh: _BORG_CORTEX_HOOKS (registered), _BORG_CORTEX_CLAUDE_ONLY (stays out on
# purpose) and _BORG_CORTEX_PENDING (not yet, with the #516 slice that adapts it). A plugin hook in none of them fails
# here, so the two lists cannot drift silently. Directive: docs/plans/directives/2026-10-15-borg-in-cortex.md AC7.
#
# BUILD_SCRIPT, BORG_ZSH and HOOKS_DIR can be pointed elsewhere to run the test against a copy.

BUILD_SCRIPT="${BORG_PARITY_BUILD_SCRIPT:-${BATS_TEST_DIRNAME}/../scripts/build-plugin.sh}"
BORG_ZSH="${BORG_PARITY_BORG_ZSH:-${BATS_TEST_DIRNAME}/../borg.zsh}"
HOOKS_DIR="${BATS_TEST_DIRNAME}/../hooks"
FIX="Register it for Cortex (add it to _BORG_CORTEX_HOOKS in borg.zsh), or list it in _BORG_CORTEX_CLAUDE_ONLY or _BORG_CORTEX_PENDING with a reason."

setup() {
    REGISTERED="${BATS_TEST_TMPDIR}/registered.txt"
    CLAUDE_ONLY="${BATS_TEST_TMPDIR}/claude-only.txt"
    PENDING="${BATS_TEST_TMPDIR}/pending.txt"
    PLUGIN="${BATS_TEST_TMPDIR}/plugin.txt"

    # one "script|reason" (or bare script) per line, from the arrays in borg.zsh
    run zsh -c "
        source '$BORG_ZSH' >/dev/null 2>&1 || true
        for e in \"\${_BORG_CORTEX_HOOKS[@]}\"; do print -r -- \"\${\${e#*|}%%|*}\"; done > '$REGISTERED'
        print -rl -- \"\${_BORG_CORTEX_CLAUDE_ONLY[@]}\" > '$CLAUDE_ONLY'
        print -rl -- \"\${_BORG_CORTEX_PENDING[@]}\" > '$PENDING'
    "
    [ "$status" -eq 0 ]

    # every hooks/<name>.sh named in a command of the plugin's HOOKS_JSON
    awk "/^HOOKS_JSON='/{on=1; sub(/^HOOKS_JSON='/, \"\")} on{print} /^}'\$/{on=0}" "$BUILD_SCRIPT" \
        | grep -o 'hooks/[A-Za-z0-9_.-]*\.sh' | sed 's|^hooks/||' | sort -u > "$PLUGIN"
}

# the script column of an "script|reason" list file
_names() { cut -d'|' -f1 "$1" | sort -u; }

# a list file holds at least one non-blank line (print -rl of an empty array writes one blank line, which -s accepts)
_has_entry() { grep -q '[^[:space:]]' "$1"; }

@test "parity: the plugin hook list and the Cortex arrays were all read" {
    _has_entry "$PLUGIN" || { echo "no hooks parsed from HOOKS_JSON in $BUILD_SCRIPT"; return 1; }
    _has_entry "$REGISTERED" || { echo "_BORG_CORTEX_HOOKS is empty or unreadable"; return 1; }
    _has_entry "$CLAUDE_ONLY" || { echo "_BORG_CORTEX_CLAUDE_ONLY is empty or unreadable"; return 1; }
    # _BORG_CORTEX_PENDING may be empty once every hook is adapted, so only its file must exist
    [ -f "$PENDING" ] || { echo "_BORG_CORTEX_PENDING was not read"; return 1; }
}

@test "parity: every hook the Claude plugin registers is registered, Claude-only or pending for Cortex" {
    local script bad=""
    while IFS= read -r script; do
        grep -qx -- "$script" "$REGISTERED" && continue
        _names "$CLAUDE_ONLY" | grep -qx -- "$script" && continue
        _names "$PENDING" | grep -qx -- "$script" && continue
        bad="$bad
$script: the Claude plugin registers it but Cortex does not. $FIX"
    done < "$PLUGIN"
    [ -z "$bad" ] || { echo "$bad"; return 1; }
}

@test "parity: every Claude-only and pending entry carries a non-empty reason" {
    local file line bad=""
    for file in "$CLAUDE_ONLY" "$PENDING"; do
        while IFS= read -r line; do
            [[ -n "$line" ]] || continue
            if [[ "$line" != *"|"* ]] || [[ -z "${line#*|}" ]]; then
                bad="$bad
${line%%|*}: listed without a reason. Give it a one-line reason after the pipe, or register it for Cortex."
            fi
        done < "$file"
    done
    [ -z "$bad" ] || { echo "$bad"; return 1; }
}

@test "parity: no script appears in more than one of the three arrays" {
    local dups
    dups=$( { sort -u "$REGISTERED"; _names "$CLAUDE_ONLY"; _names "$PENDING"; } | sort | uniq -d)
    [ -z "$dups" ] || { printf '%s\n' "$dups" | sed 's/$/: listed in more than one of _BORG_CORTEX_HOOKS, _BORG_CORTEX_CLAUDE_ONLY, _BORG_CORTEX_PENDING. Keep exactly one./'; return 1; }
}

@test "parity: every script named in any array exists under hooks/" {
    local script bad=""
    while IFS= read -r script; do
        [[ -n "$script" ]] || continue
        [ -f "$HOOKS_DIR/$script" ] || bad="$bad
$script: named in a Cortex hook array but hooks/$script does not exist. Fix the name or remove the entry."
    done < <({ sort -u "$REGISTERED"; _names "$CLAUDE_ONLY"; _names "$PENDING"; } | sort -u)
    [ -z "$bad" ] || { echo "$bad"; return 1; }
}

@test "parity: no Claude-only or pending entry names a script the plugin no longer registers" {
    local script bad=""
    while IFS= read -r script; do
        [[ -n "$script" ]] || continue
        grep -qx -- "$script" "$PLUGIN" || bad="$bad
$script: listed in _BORG_CORTEX_CLAUDE_ONLY or _BORG_CORTEX_PENDING but HOOKS_JSON no longer registers it. Remove the stale entry."
    done < <({ _names "$CLAUDE_ONLY"; _names "$PENDING"; } | sort -u)
    [ -z "$bad" ] || { echo "$bad"; return 1; }
}
