#!/usr/bin/env bash
# borg-workflow-model-guard.sh — PreToolUse hook (matcher: Workflow): deny unpinned agent() calls.
#
# Inside a Workflow script an agent() call with neither `agentType:` nor `model:` inherits the session
# model AND session effort (CLAUDE_CODE_SUBAGENT_MODEL does not reach it), so a fan-out silently runs
# every stage on Opus. Rule + rationale: docs/agent-routing.md.
#
# Input: tool_input.script (inline), or the file at tool_input.scriptPath. tool_input.name (a saved
# workflow) is allowed without inspection.
#
# CONTRACT — fail OPEN. The parse is heuristic. Anything not confidently understood exits 0: missing
# jq/python3, empty or malformed stdin, unreadable scriptPath, unbalanced parens, options passed as a
# variable or with a spread. A guard that wrongly blocks is worse than none. It denies (exit 2, reason
# on stderr) only when it finds an agent() call it fully parsed that carries no agentType/model.
#
# Escape hatch: a `/* inherit-ok */` comment inside the call means inheriting the session model is
# intentional. Kill switch: BORG_WORKFLOW_MODEL_GUARD=0.

set -uo pipefail

[[ "${BORG_WORKFLOW_MODEL_GUARD:-1}" == "0" ]] && exit 0
command -v jq >/dev/null 2>&1 || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

INPUT=$(cat /dev/stdin 2>/dev/null || true)
[[ -z "$INPUT" ]] && exit 0

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null) || exit 0
[[ "$TOOL_NAME" == "Workflow" ]] || exit 0

# Saved workflows are not inspected.
NAME=$(printf '%s' "$INPUT" | jq -r '.tool_input.name // ""' 2>/dev/null) || exit 0
[[ -n "$NAME" ]] && exit 0

SCRIPT=$(printf '%s' "$INPUT" | jq -r '.tool_input.script // ""' 2>/dev/null) || exit 0
if [[ -z "$SCRIPT" ]]; then
    SPATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.scriptPath // ""' 2>/dev/null) || exit 0
    [[ -n "$SPATH" && -r "$SPATH" ]] || exit 0
    SCRIPT=$(cat "$SPATH" 2>/dev/null) || exit 0
fi
[[ -z "$SCRIPT" ]] && exit 0

read -r -d "" PARSER <<'PY' || true
import re, sys

src = sys.stdin.read()
n = len(src)
QUOTES = "\"'`"

def skip_string(i):
    q = src[i]; j = i + 1
    while j < n:
        if src[j] == "\\":
            j += 2; continue
        if src[j] == q:
            return j + 1
        j += 1
    return None

def scan_call(start):
    """start = index of '('. Returns (end_index, [(raw, blanked), ...]) or None if unparseable."""
    depth = 0; i = start; args = []; raw = []; bl = []
    while i < n:
        c = src[i]; nx = src[i + 1] if i + 1 < n else ""
        if c in QUOTES:
            j = skip_string(i)
            if j is None: return None
            raw.append(src[i:j]); bl.append(c + c); i = j; continue
        if c == "/" and nx == "/":
            j = src.find("\n", i); j = n if j < 0 else j
            raw.append(src[i:j]); i = j; continue
        if c == "/" and nx == "*":
            j = src.find("*/", i + 2)
            if j < 0: return None
            raw.append(src[i:j + 2]); i = j + 2; continue
        if c in "([{":
            depth += 1
            if depth > 1:
                raw.append(c); bl.append(c)
        elif c in ")]}":
            depth -= 1
            if depth < 0: return None
            if depth == 0:
                if c != ")": return None
                if "".join(bl).strip() or args:
                    args.append(("".join(raw), "".join(bl)))
                return i, args
            raw.append(c); bl.append(c)
        elif c == "," and depth == 1:
            args.append(("".join(raw), "".join(bl))); raw = []; bl = []
        else:
            raw.append(c); bl.append(c)
        i += 1
    return None

# Find agent( call sites outside strings and comments.
sites = []; i = 0
site_re = re.compile(r"agent\s*\(")
while i < n:
    c = src[i]; nx = src[i + 1] if i + 1 < n else ""
    if c in QUOTES:
        j = skip_string(i)
        if j is None: sys.exit(0)
        i = j; continue
    if c == "/" and nx == "/":
        j = src.find("\n", i); i = n if j < 0 else j; continue
    if c == "/" and nx == "*":
        j = src.find("*/", i + 2)
        if j < 0: sys.exit(0)
        i = j + 2; continue
    m = site_re.match(src, i)
    if m and (i == 0 or not re.match(r"[\w.$]", src[i - 1])):
        if not re.search(r"function\s*$", src[max(0, i - 12):i]):
            sites.append(i + m.group(0).index("("))
        i = m.end(); continue
    i += 1

missing = []
for p in sites:
    r = scan_call(p)
    if r is None: sys.exit(0)            # cannot parse: fail open
    end, args = r
    if re.search(r"/\*\s*inherit-ok\s*\*/", src[p:end + 1]): continue
    if not args: continue
    objs = [a for a in args if a[1].strip().startswith("{")]
    if not objs:
        if len(args) >= 2: continue      # options passed as a variable: fail open
        opts_raw = opts_bl = ""
    else:
        opts_raw, opts_bl = objs[0]
        if "..." in opts_bl: continue    # spread: fail open
    if re.search(r"\b(agentType|model)\s*[:,}]", opts_bl): continue
    lm = re.search(r"label\s*:\s*['\"`]([^'\"`]*)", opts_raw)
    line = src.count("\n", 0, p) + 1
    missing.append("line %d%s" % (line, " (label '%s')" % lm.group(1) if lm else ""))

if missing:
    print("; ".join(missing))
PY

REASON=$(printf '%s' "$SCRIPT" | python3 -I -c "$PARSER" 2>/dev/null) || exit 0
[[ -z "$REASON" ]] && exit 0

{
    printf 'borg workflow model guard: agent() call(s) with no agentType or model pin: %s.\n' "$REASON"
    printf 'Unpinned calls inherit the session model AND effort (Opus); CLAUDE_CODE_SUBAGENT_MODEL does not reach them.\n'
    printf "Fix, per call: add agentType: 'borg-collective:borg-scout' (or -grunt/-nanoprobe/-researcher/-reviewer; must be namespaced) OR model: 'sonnet', effort: 'medium'.\n"
    printf 'Intentional inherit: put /* inherit-ok */ inside the call. Guide: docs/agent-routing.md\n'
} >&2
exit 2
