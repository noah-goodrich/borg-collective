#!/usr/bin/env bash
# bash-guard.sh v2 — PreToolUse hook for Bash calls.
#
# Three-layer design. Output contract with Claude Code:
#   exit 2           → deny (stderr message shown to Claude)
#   stdout JSON      → pre-approve (bypasses permissions.allow prompt)
#     { "hookSpecificOutput":
#         { "hookEventName":"PreToolUse",
#           "permissionDecision":"allow",
#           "permissionDecisionReason":"..." } }
#   exit 0, no JSON  → fall through to the normal allowlist check
#
# Layer 1: hard-block destructive patterns (recursive root delete, curl|bash,
#          force push to main, settings truncation). Always on; never softened.
# Layer 2: container-aware pre-approval for common install verbs (pip, npm,
#          apt-get, etc.) when /.dockerenv or /run/.containerenv exists.
# Layer 3: read-only intent classifier. Parses pipelines, substitutions, and
#          chains; pre-approves when EVERY segment is a known-RO invocation.
#          Unknown binaries fall through (safe default).
#
# Escape valves:
#   BORG_BASH_GUARD_DISABLE=1 — skip Layers 2 + 3 (Layer 1 still enforced).
#   BORG_CONTAINER_MARKER=<path> — override container-detection path (for tests).

set -u

COMMAND=$(jq -r '.tool_input.command' < /dev/stdin 2>/dev/null) || exit 0
[[ -z "$COMMAND" || "$COMMAND" == "null" ]] && exit 0

# ── Layer 1: destructive patterns (always hard-blocked) ───────────────────────

case "$COMMAND" in
    *"rm -rf /"*|*"rm -rf ~"*|*"rm -rf \$HOME"*)
        echo "Blocked: recursive delete of home or root directory" >&2; exit 2 ;;
    *"chmod -R 777"*)
        echo "Blocked: world-writable recursive chmod" >&2; exit 2 ;;
    *"> /dev/sda"*|*"dd if="*"of=/dev/"*)
        echo "Blocked: raw disk write" >&2; exit 2 ;;
    *"curl"*"| bash"*|*"wget"*"| bash"*|*"curl"*"| sh"*|*"wget"*"| sh"*)
        echo "Blocked: piping remote script to shell" >&2; exit 2 ;;
    *"rm -rf"*".claude"*)
        echo "Blocked: recursive delete of Claude settings directory" >&2; exit 2 ;;
    *"git push --force"*" main"*|*"git push --force"*" master"*|*"git push -f "*" main"*|*"git push -f "*" master"*)
        echo "Blocked: force push to main/master — use --force-with-lease or push to a branch" >&2; exit 2 ;;
    *"> ~/.claude/settings.json"*|*">\$HOME/.claude/settings.json"*|*"> /Users/"*"/.claude/settings.json"*)
        echo "Blocked: truncating Claude settings file" >&2; exit 2 ;;
esac

# Escape valve: skip the classifier but keep Layer 1 (already ran).
if [[ -n "${BORG_BASH_GUARD_DISABLE:-}" ]]; then
    exit 0
fi

# ── Helpers ───────────────────────────────────────────────────────────────────

_preapprove() {
    jq -cn --arg r "$1" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",permissionDecisionReason:$r}}'
    exit 0
}

# Strip single- and double-quoted spans for pattern matching. Heuristic; fine
# for the Bash shapes Claude actually emits.
_strip_quotes() {
    echo "$1" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g"
}

_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    echo "$s"
}

# Classify a single "segment" (one invocation, no top-level pipes/chains).
# Returns 0 if RO, 1 otherwise.
is_segment_ro() {
    local seg rest bin
    seg=$(_trim "$1")
    [[ -z "$seg" ]] && return 0

    bin="${seg%% *}"
    rest=""
    [[ "$seg" == *" "* ]] && rest="${seg#* }"

    # Shell built-ins / navigation (don't modify anything)
    case "$bin" in
        cd|pushd|popd|dirs|:|true|false|test|\[|\[\[) return 0 ;;
    esac

    # bash -c / zsh -c: classify the inner payload
    if [[ "$bin" == "bash" || "$bin" == "zsh" ]]; then
        if [[ "$rest" == "-c "* ]]; then
            local payload="${rest#-c }"
            payload=$(_trim "$payload")
            # Strip a single layer of surrounding quotes
            if [[ "$payload" == \'*\' ]]; then
                payload="${payload#\'}"; payload="${payload%\'}"
            elif [[ "$payload" == \"*\" ]]; then
                payload="${payload#\"}"; payload="${payload%\"}"
            fi
            is_command_ro "$payload" && return 0 || return 1
        fi
        return 1
    fi

    # run-in <path> <cmd> — classify the cmd portion
    if [[ "$bin" == "run-in" ]]; then
        # rest = "/path cmd args..."
        local remainder="${rest#* }"
        is_command_ro "$remainder" && return 0 || return 1
    fi

    # Simple RO binaries
    case "$bin" in
        cat|head|tail|less|more|nl|od|xxd|hexdump|strings|tac) return 0 ;;
        ls|tree|dir|pwd|readlink|realpath|basename|dirname) return 0 ;;
        grep|egrep|fgrep|rg|ag|ack) return 0 ;;
        wc|stat|file|du|df|size) return 0 ;;
        shasum|sha256sum|sha1sum|md5|md5sum|cksum) return 0 ;;
        which|command|type|whence|whereis|locate) return 0 ;;
        echo|printf) return 0 ;;
        sort|uniq|cut|paste|tr|rev|column|expand|unexpand|fold|fmt|head|tail) return 0 ;;
        date|cal) return 0 ;;
        uname|hostname|whoami|id|tty|env|printenv|locale|arch) return 0 ;;
        ps|uptime|w|last|free|sysctl|vm_stat) return 0 ;;
        jq|yq|tomlq|xq) return 0 ;;
        awk|xargs) return 0 ;;
    esac

    # sed without -i is RO
    if [[ "$bin" == "sed" ]]; then
        echo " $rest " | grep -qE '[[:space:]]-i([[:space:]]|$|\.)' && return 1
        return 0
    fi

    # find without destructive flags is RO
    if [[ "$bin" == "find" ]]; then
        echo " $rest " | grep -qE '[[:space:]](-exec|-delete|-ok|-execdir|-okdir|-fprint|-fprintf)' && return 1
        return 0
    fi

    # git: parse subcommand after skipping -C /path prefix flags
    if [[ "$bin" == "git" ]]; then
        local git_sub
        git_sub=$(echo "$rest" | awk '{
            i=1
            while (i <= NF) {
                if ($i == "-C") { i += 2; continue }
                if ($i ~ /^-/)  { i++; continue }
                print $i; exit
            }
        }')
        case "$git_sub" in
            status|log|show|diff|branch|remote|config|ls-files|ls-tree|ls-remote) return 0 ;;
            rev-parse|rev-list|blame|tag|describe|reflog|shortlog|grep|cat-file) return 0 ;;
            fsck|count-objects|var|whatchanged|bisect|worktree|check-ignore|check-attr) return 0 ;;
            stash)
                local stash_sub
                stash_sub=$(echo "$rest" | awk '{for(i=1;i<=NF;i++) if($i=="stash") { print $(i+1); exit }}')
                case "$stash_sub" in list|show|""|-*) return 0 ;; esac
                return 1 ;;
        esac
        # User policy: all git commands allowed. Blanket approve any git we didn't
        # already classify RO — Layer 1 handles the force-push-to-main exception.
        return 0
    fi

    # User policy: all docker/podman and all gh commands allowed.
    if [[ "$bin" == "docker" || "$bin" == "podman" || "$bin" == "docker-compose" ]]; then
        return 0
    fi
    if [[ "$bin" == "gh" ]]; then
        return 0
    fi

    # npm/pnpm/yarn RO subcommands
    if [[ "$bin" == "npm" || "$bin" == "pnpm" || "$bin" == "yarn" ]]; then
        local sub="${rest%% *}"
        case "$sub" in
            list|ls|view|outdated|search|config|root|prefix|bin|audit|fund|explore|explain|why|ping|profile|token|whoami|doctor) return 0 ;;
            run|run-script|exec|test|start) return 0 ;;
        esac
        return 1
    fi

    # pip RO subcommands
    if [[ "$bin" == "pip" || "$bin" == "pip3" ]]; then
        local sub="${rest%% *}"
        case "$sub" in list|show|freeze|check|hash|config|debug|index|search) return 0 ;; esac
        return 1
    fi

    # uv: mostly RO; uv pip has its own subcommands
    if [[ "$bin" == "uv" ]]; then
        local sub="${rest%% *}"
        case "$sub" in tree|cache|help|version|self) return 0 ;; esac
        if [[ "$sub" == "pip" ]]; then
            local pip_sub
            pip_sub=$(echo "$rest" | awk '{print $2}')
            case "$pip_sub" in list|show|check|tree|freeze) return 0 ;; esac
            return 1
        fi
        return 1
    fi

    # brew RO
    if [[ "$bin" == "brew" ]]; then
        local sub="${rest%% *}"
        case "$sub" in list|info|search|outdated|desc|deps|uses|doctor|config|home|ls|readall) return 0 ;; esac
        return 1
    fi

    # cargo RO
    if [[ "$bin" == "cargo" ]]; then
        local sub="${rest%% *}"
        case "$sub" in search|tree|metadata|locate-project|pkgid|version|help) return 0 ;; esac
        return 1
    fi

    # go RO
    if [[ "$bin" == "go" ]]; then
        local sub="${rest%% *}"
        case "$sub" in list|version|env|doc|help|vet) return 0 ;; esac
        return 1
    fi

    # kubectl RO
    if [[ "$bin" == "kubectl" ]]; then
        local sub="${rest%% *}"
        case "$sub" in get|describe|logs|top|version|explain|api-resources|api-versions|cluster-info|diff) return 0 ;; esac
        return 1
    fi

    # Unknown → fall-through (not pre-approved)
    return 1
}

# Classify a full command (may contain $(), pipes, chains, redirects).
# Returns 0 if entire command is RO, 1 otherwise.
is_command_ro() {
    local cmd stripped trimmed
    cmd="$1"
    trimmed=$(_trim "$cmd")

    # Escape-hatch shortcuts: handle these BEFORE quote-stripping so the inner
    # payload's quotes stay intact for recursive classification.
    case "$trimmed" in
        "bash -c "*|"zsh -c "*)
            local payload="${trimmed#* -c }"
            if [[ "$payload" == \'*\' ]]; then
                payload="${payload#\'}"; payload="${payload%\'}"
            elif [[ "$payload" == \"*\" ]]; then
                payload="${payload#\"}"; payload="${payload%\"}"
            fi
            is_command_ro "$payload" && return 0 || return 1
            ;;
        "run-in "*)
            local after="${trimmed#run-in }"
            local remainder="${after#* }"
            is_command_ro "$remainder" && return 0 || return 1
            ;;
    esac

    stripped=$(_strip_quotes "$cmd")

    # Output redirection > or >> to anywhere except /dev/null → RW.
    # Heuristic: look for > followed by a path that isn't /dev/null.
    if echo "$stripped" | grep -qE '>>?[[:space:]]*[^&[:space:]]'; then
        if ! echo "$stripped" | grep -qE '>>?[[:space:]]*/dev/null($|[[:space:]])'; then
            return 1
        fi
    fi

    # Iteratively resolve innermost $(...) substitutions. If any inner is
    # non-RO, the whole command is non-RO. Replace resolved spans with a
    # placeholder so they don't interfere with later parsing.
    local sub_count=0
    while echo "$stripped" | grep -q '\$('; do
        # Extract the first innermost $(...) — one that contains no further $( within.
        local inner
        inner=$(echo "$stripped" | grep -oE '\$\([^$()]*\)' | head -1)
        [[ -z "$inner" ]] && break
        local inner_cmd="${inner#\$\(}"
        inner_cmd="${inner_cmd%\)}"
        if ! is_command_ro "$inner_cmd"; then
            return 1
        fi
        # Remove this span from the outer so parsing continues.
        stripped="${stripped//$inner/__RO_SUB__}"
        sub_count=$((sub_count + 1))
        (( sub_count > 20 )) && return 1  # safety
    done

    # Split on top-level chain operators (&&, ||, ;).
    local chain_normalized
    chain_normalized=$(echo "$stripped" | sed -E 's/[[:space:]]+(&&|\|\|)[[:space:]]+/\n/g; s/[[:space:]]*;[[:space:]]*/\n/g')
    while IFS= read -r chain_seg; do
        [[ -z "$(_trim "$chain_seg")" ]] && continue
        # Split chain segment on top-level pipe.
        local pipe_normalized
        pipe_normalized=$(echo "$chain_seg" | sed -E 's/[[:space:]]+\|[[:space:]]+/\n/g')
        while IFS= read -r pipe_seg; do
            [[ -z "$(_trim "$pipe_seg")" ]] && continue
            # Restore __RO_SUB__ placeholder as a benign token for classification.
            pipe_seg="${pipe_seg//__RO_SUB__/placeholder}"
            is_segment_ro "$pipe_seg" || return 1
        done <<< "$pipe_normalized"
    done <<< "$chain_normalized"

    return 0
}

# ── Layer 2: container-aware install-verb pre-approval ────────────────────────

_marker="${BORG_CONTAINER_MARKER:-}"
_in_container=0
if [[ -n "$_marker" ]]; then
    [[ -e "$_marker" ]] && _in_container=1
else
    [[ -f /.dockerenv || -f /run/.containerenv ]] && _in_container=1
fi

if (( _in_container )); then
    case "$COMMAND" in
        "pip install"*|"pip3 install"*|"uv pip install"*|"pipx install"*)
            _preapprove "inside-container install verb (pip)" ;;
        "npm install"*|"npm i "*|"npm ci"*|"pnpm install"*|"pnpm add"*|"yarn install"*|"yarn add"*)
            _preapprove "inside-container install verb (npm/pnpm/yarn)" ;;
        "apt-get install"*|"apt install"*|"apt-get update"*|"apt update"*)
            _preapprove "inside-container install verb (apt)" ;;
        "gem install"*|"cargo install"*|"go install"*)
            _preapprove "inside-container install verb (gem/cargo/go)" ;;
    esac
fi

# ── Layer 3: RO intent classifier ─────────────────────────────────────────────

if is_command_ro "$COMMAND"; then
    _preapprove "read-only by intent classifier"
fi

# Fall-through: let the normal permissions.allow check decide.
exit 0
