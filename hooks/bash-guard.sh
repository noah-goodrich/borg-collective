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

# ── Normalization pre-pass (audit cross-cutting fix) ──────────────────────────
# Layer 1's literal-substring matching was brittle against ordinary shell
# equivalence: quoting, flag reordering, path-qualified binaries, extra
# whitespace. Normalize ONCE — drop quote characters (content kept), fold
# newlines/tabs to spaces, collapse runs, trim — then match the hard-block
# categories on the normalized form. NORM is for MATCHING only; the user's
# original COMMAND still runs if allowed.
_bg_norm() {
    printf '%s' "$1" | tr -d '\047"' | tr '\n\t' '  ' | sed -E 's/  +/ /g; s/^ //; s/ $//'
}

# Split a normalized command into segments on top-level ; && || | & operators,
# plus subshell/group delimiters ( ) { } — a bare & (backgrounding, NOT the
# already-handled &&) starts a new segment, and ( ) { } are stripped at
# segment boundaries so `(rm -rf /)` yields a bare `rm -rf /` segment instead
# of hiding it behind a leading `(`.
# Emits one segment per line (leading/trailing space trimmed by the caller).
_bg_segments() {
    printf '%s' "$1" \
        | sed -E 's/ *(&&|\|\||[;|]) */\n/g' \
        | sed -E 's/([^&])&([^&]|$)/\1\n\2/g' \
        | sed -E 's/[(){}]+/\n/g'
}

# Basename of ONE token — strip a single leading backslash (\rm) and any path
# prefix (/bin/rm, /usr/bin/rm) — no wrapper/assignment awareness. Used to test
# individual tokens inside a segment, not just the leading one.
_bg_tok_bin() {
    local tok="$1"
    tok="${tok#\\}"
    printf '%s' "${tok##*/}"
}

# Find a $2-named token ANYWHERE in segment $1 (basename-aware) and print the
# text that follows it (padded with a leading+trailing space), one match per
# call — checks matches left-to-right and returns on the first whose args the
# caller's danger-check ($3, a function name) reports dangerous.
#
# This replaces trying to resolve "the" real leading binary through wrapper
# prefixes (sudo, env, nice -n 5, timeout 5, ...) — an unbounded and easily
# incomplete list. A wrapper doesn't hide rm/chmod from a token scan: whatever
# precedes the rm/chmod token (sudo, env FOO=1, nice -n 5, timeout 5, sudo -u
# root, sudo nice -n 5, ...) is irrelevant — only the args AFTER the token
# matter, and those are unchanged by whatever wrapper ran it.
_bg_scan_danger() {
    local segment="$1" target="$2" checker="$3"
    local -a toks
    read -ra toks <<< "$segment"
    local i n=${#toks[@]}
    for (( i = 0; i < n; i++ )); do
        [[ "$(_bg_tok_bin "${toks[i]}")" == "$target" ]] || continue
        local rest=" ${toks[*]:i+1} "
        "$checker" "$rest" && return 0
    done
    return 1
}

# True (0) if rm args $1 (" -flags target ", already padded) are recursive
# and target root, home, or .claude. Invoked indirectly by _bg_scan_danger via
# its $checker name argument — shellcheck can't see that call.
# shellcheck disable=SC2329,SC2317
_bg_rm_args_danger() {
    printf '%s' "$1" | grep -qE ' -[A-Za-z]*[rR][A-Za-z]* | --recursive ' || return 1
    printf '%s' "$1" | grep -qE ' /( |\*|$)| ~( |/|$)| \$\{?HOME\}?( |/|$)| [^ ]*\.claude( |/|$)'
}

# True (0) if chmod args $1 (" -flags mode ", already padded) are recursive
# and grant write to "other". Invoked indirectly by _bg_scan_danger; see above.
# shellcheck disable=SC2329,SC2317
_bg_chmod_args_danger() {
    printf '%s' "$1" | grep -qE ' -[A-Za-z]*[rR][A-Za-z]* | --recursive ' || return 1
    printf '%s' "$1" | grep -qE ' [0-7]{2,3}[2367]( |$)| [ugo]*[ao][ugo]*\+[A-Za-z]*w| \+[A-Za-z]*w'
}

# True (0) if a recursive rm in $1 (normalized) targets root, home, or .claude.
# Recursive = any flag cluster containing r/R, or --recursive. Targets:
#   /  or /*  (root)      ~  ~/… or $HOME/${HOME} (home)      …*.claude… (settings)
# Scans for an `rm` token ANYWHERE in each segment — not just the leading
# token — so a wrapper prefix (sudo, env, nice -n 5, timeout 5, ...) of any
# shape cannot hide the real invocation from this check.
_bg_rm_danger() {
    local seg segs
    # Here-string (not process substitution): a here-string appends a trailing
    # newline, so `read` does not drop a single unterminated segment.
    segs=$(_bg_segments "$1")
    while IFS= read -r seg; do
        _bg_scan_danger "$seg" "rm" _bg_rm_args_danger && return 0
    done <<< "$segs"
    return 1
}

# True (0) if a recursive chmod in $1 (normalized) grants write to "other".
# Others-writable = an octal mode whose last digit has the write bit (2,3,6,7),
# or a symbolic mode granting w to a/o/all (a+w, o+w, ugo+rwx, bare +w). Owner-
# or group-only grants (u+w, g+w) and non-others octals (755) are left alone.
# Same wrapper-proof token scan as _bg_rm_danger.
_bg_chmod_danger() {
    local seg segs
    segs=$(_bg_segments "$1")
    while IFS= read -r seg; do
        _bg_scan_danger "$seg" "chmod" _bg_chmod_args_danger && return 0
    done <<< "$segs"
    return 1
}

# True (0) if $1 (normalized) is a `git push` force-pushing to main/master.
# Requires --force or -f — NOT --force-with-lease, the recommended safe form.
# Matches the ref as a token: main, :main (HEAD:main), or /main (refs/heads/main).
_bg_gitforce_danger() {
    printf '%s' "$1" | grep -qE '(^| )git push( |$)' || return 1
    printf '%s' "$1" | grep -qE ' --force( |$)| -f( |$)' || return 1
    printf '%s' "$1" | grep -qE '(^| |:|/)(main|master)( |$)' && return 0
    return 1
}

# True (0) if $1 (normalized) redirects (> or >>) into a .claude/settings.json
# path, in any home notation (~, $HOME, absolute). Reads are untouched.
_bg_settings_write_danger() {
    printf '%s' "$1" | grep -qE '>>? *[^ ]*\.claude/settings\.json' && return 0
    return 1
}

NORM=$(_bg_norm "$COMMAND")

if _bg_rm_danger "$NORM"; then
    echo "Blocked: recursive delete of root, home, or Claude settings directory" >&2; exit 2
fi

if _bg_chmod_danger "$NORM"; then
    echo "Blocked: recursive world-writable chmod" >&2; exit 2
fi

if _bg_gitforce_danger "$NORM"; then
    echo "Blocked: force push to main/master — use --force-with-lease or push to a branch" >&2; exit 2
fi

if _bg_settings_write_danger "$NORM"; then
    echo "Blocked: writing Claude settings file" >&2; exit 2
fi

# ── Layer 1: destructive patterns (always hard-blocked) ───────────────────────

case "$COMMAND" in
    *"> /dev/sda"*|*"dd if="*"of=/dev/"*)
        echo "Blocked: raw disk write" >&2; exit 2 ;;
    *"curl"*"| bash"*|*"wget"*"| bash"*|*"curl"*"| sh"*|*"wget"*"| sh"*)
        echo "Blocked: piping remote script to shell" >&2; exit 2 ;;
esac

# Escape valve: skip the classifier but keep Layer 1 (already ran).
if [[ -n "${BORG_BASH_GUARD_DISABLE:-}" ]]; then
    exit 0
fi

# Defined before Layer 1.5 (below) so the case branches can call it. Layers 2 and
# 3 use it too.
_preapprove() {
    jq -cn --arg r "$1" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"allow",permissionDecisionReason:$r}}'
    exit 0
}

# ── Layer 1.5: known-safe borg skill patterns ─────────────────────────────────
# These commands use shell constructs (while loops, variable assignments) that
# the RO classifier can't parse, but are known read-only by inspection.
#
# Pre-approval is the strongest decision this hook can make: it emits
# permissionDecision=allow and exits, skipping the classifier AND the normal
# allowlist. So it must match a SPECIFIC command, never a substring.
#
# This branch previously matched *".borg-project"* — any command containing that
# substring anywhere, including in a trailing comment. `touch /etc/x # .borg-project`
# was waved past every remaining check. Anchor on the exact canonical command instead.

# Collapse newlines/tabs/space-runs to single spaces and trim, so the multi-line
# heredoc shape in skills/borg-link/SKILL.md compares equal to a one-line paste.
# Also normalizes an optional `;` before the closing `done`.
_canon_ws() {
    printf '%s' "$1" | tr '\n\t' '  ' | sed -E 's/  +/ /g; s/^ //; s/ $//; s/; done$/ done/'
}

# The one command skills/borg-link/SKILL.md tells Claude to run. Keep byte-for-byte
# in sync with that file (and with tests/bash_guard.bats `_marker_walk`). Single-quoted:
# every $ here is literal — this is a pattern to compare against, never to evaluate.
# shellcheck disable=SC2016
_BORG_MARKER_WALK='dir="$PWD"; while [[ "$dir" != "/" ]]; do [[ -f "$dir/.borg-project" ]] && { echo "WORKSPACE=$dir"; echo "PROJECT=$(cat "$dir/.borg-project")"; break; } dir=$(dirname "$dir") done'

# A walk that does not match exactly is not pre-approved — it falls through to the
# classifier and, at worst, prompts. Fail closed: a prompt is cheap, a bypass is not.
if [[ "$(_canon_ws "$COMMAND")" == "$_BORG_MARKER_WALK" ]]; then
    _preapprove "borg marker walk — read-only directory scan"
fi

# NOTE: a `for f in *.borg/checkpoints/* | */docs/plans/*` prologue used to be
# pre-approved here. Pre-approval covered the whole LOOP, so the body could be any
# command — the prologue was the entire ticket (audit finding A2). No skill emits
# such a Bash loop, so the branch is gone: these fall through to the classifier,
# which reads the loop body on its own merits.

# ── Helpers ───────────────────────────────────────────────────────────────────

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
        sort|uniq|cut|paste|tr|rev|column|expand|unexpand|fold|fmt) return 0 ;;
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

    # A3: backtick command substitution. The $() resolver below only sees $(...),
    # and _strip_quotes deletes a backtick span sitting inside double quotes before
    # it is ever examined — so scan the RAW command here. Same rule as $(): a non-RO
    # inner command makes the whole command non-RO. Mirrors the $() loop below.
    local bt_scan bt_inner bt_cmd bt_count=0
    bt_scan="$cmd"
    # shellcheck disable=SC2016  # grep regex literal — single quotes intentional
    while echo "$bt_scan" | grep -q '`'; do
        bt_inner=$(echo "$bt_scan" | grep -oE '`[^`]*`' | head -1)
        [[ -z "$bt_inner" ]] && break   # unbalanced backtick — no span to classify
        bt_cmd="${bt_inner#\`}"; bt_cmd="${bt_cmd%\`}"
        is_command_ro "$bt_cmd" || return 1
        bt_scan="${bt_scan//$bt_inner/__RO_SUB__}"
        bt_count=$((bt_count + 1))
        (( bt_count > 20 )) && return 1  # safety
    done

    # A4: quoted find destructive flag. _strip_quotes removes whole quoted spans, so
    # a quoted flag (find . "-exec" ... / find . '-delete') is gone before the find
    # check in is_segment_ro runs. Detect it here on a copy with only the quote
    # CHARACTERS removed, and only when `find` is a segment's leading token — so a
    # benign `echo "find . -delete"` is not affected.
    local uq_seg uq_split
    # Here-string (not `< <(...)`) so the final segment is not dropped: a here-string
    # appends a trailing newline, process substitution does not, and BSD sed keeps the
    # input's missing terminator — `while read` then skips the last, unterminated line.
    uq_split=$(printf '%s' "$cmd" | tr -d '\047"' | sed -E 's/[[:space:]]*(&&|\|\||[;|])[[:space:]]*/\n/g')
    while IFS= read -r uq_seg; do
        uq_seg=$(_trim "$uq_seg")
        [[ "${uq_seg%% *}" == "find" ]] || continue
        echo " $uq_seg " | grep -qE '[[:space:]](-exec|-delete|-ok|-execdir|-okdir|-fprint|-fprintf)([[:space:]]|$)' && return 1
    done <<< "$uq_split"

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
    # shellcheck disable=SC2016  # grep regex literal — single quotes intentional
    while echo "$stripped" | grep -q '\$('; do
        # Extract the first innermost $(...) — one that contains no further $( within.
        local inner
        # shellcheck disable=SC2016  # grep regex literal — single quotes intentional
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
