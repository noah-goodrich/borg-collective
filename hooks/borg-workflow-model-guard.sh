#!/usr/bin/env bash
# borg-workflow-model-guard.sh — PreToolUse hook (matcher: Workflow): enforce the routing policy on every
# agent() call in a Workflow script.
#
# Policy (docs/agent-routing.md): orchestrator and drone sessions run Opus at xhigh; every subagent must be
# BELOW that tier. Inside a Workflow script an agent() call with no pin inherits the session model AND
# effort (CLAUDE_CODE_SUBAGENT_MODEL does not reach it), so a fan-out silently runs every stage on Opus
# xhigh. Each agent() call must therefore carry either
#   - agentType on the allowlist (research-tools:* only when the session transcript shows a research-tools
#     skill/command was invoked; research-tools types are exempt from the caps), or
#   - with no agentType: model sonnet/haiku AND effort low/medium/high.
# A model/effort given alongside an allowlisted agentType must meet the same caps.
#
# Input: tool_input.script (inline), else the file at tool_input.scriptPath, else the saved workflow
# tool_input.name (resolved in <cwd and parents>/.claude/workflows and ~/.claude/workflows).
#
# CONTRACT — fail CLOSED. The script is tokenized (strings, comments, regex literals and nested template
# literals are understood, so prose containing "agent(" is not a call). Denied with exit 2 and the fix on
# stderr: any non-compliant call; options that are not an object literal (variable, spread, expression);
# agentType/model/effort that are not string literals (a const holding a literal is resolved); agent
# referenced without being called (alias, callback); a script that cannot be parsed; a scriptPath or saved
# name that cannot be resolved. Fails OPEN only when the call is not ours to judge (missing python3, empty
# or malformed stdin, another tool). There is no inline escape hatch. Kill switch:
# BORG_WORKFLOW_MODEL_GUARD=0. The policy block below is byte-identical in hooks/borg-agent-model-guard.sh
# (a bats test diffs them).

set -uo pipefail

[[ "${BORG_WORKFLOW_MODEL_GUARD:-1}" == "0" ]] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0

# Read with `read -d ""` outside any command substitution: bash 3.2 mis-parses a heredoc nested in $( )
# when it holds a backtick or an unbalanced quote (see tests/hook_bash32_parse.bats).
read -r -d "" GUARD <<'PY' || true
import json, os, re, sys

# POLICY-BEGIN
ALLOWED_TYPES = (
    "borg-collective:borg-scout",
    "borg-collective:borg-grunt",
    "borg-collective:borg-nanoprobe",
    "borg-collective:borg-researcher",
    "borg-collective:borg-reviewer",
    "borg-collective:borg-verifier",
    "claude-code-guide",
)
# Built-in types whose definition pins no effort: they inherit the session's xhigh, so a call must
# carry an effort. (No model is required: the built-in already runs Haiku.)
EFFORT_REQUIRED_TYPES = ("claude-code-guide",)
RESEARCH_PREFIX = "research-tools:"
EFFORT_OK = ("low", "medium", "high")
MODEL_RE = re.compile(r"^(sonnet|haiku|claude-sonnet-[a-z0-9._-]+|claude-haiku-[a-z0-9._-]+)$")
RESEARCH_CMD_RE = re.compile(
    r"<command-name>\s*/(?:research-tools:)?(?:research|deep-research|brainstorm)\s*</command-name>")
USE_INSTEAD = (
    "borg-collective:borg-scout (read-only search/locate), borg-collective:borg-grunt (fully-specified "
    "edit/run), borg-collective:borg-nanoprobe (one task, judgment), borg-collective:borg-researcher "
    "(web research, one track), borg-collective:borg-reviewer (blind review), "
    "borg-collective:borg-verifier (verification), claude-code-guide (Claude Code questions)")
TYPE_HINTS = {
    "general-purpose": "general-purpose inherits the session's Opus xhigh. Use subagent_type "
                       "borg-collective:borg-nanoprobe (one task, judgment), borg-collective:borg-grunt "
                       "(fully-specified edit/run) or borg-collective:borg-scout (read-only search)",
    "explore": "use subagent_type borg-collective:borg-scout for read-only search",
    "plan": "Plan inherits the session's Opus xhigh. Use subagent_type borg-collective:borg-nanoprobe to "
            "draft a plan from a written brief, or plan in the main session",
    "fork": "a fork inherits the session's Opus xhigh and full effort. Hand the work to "
            "borg-collective:borg-nanoprobe with a written brief instead",
    "claude": "the claude catch-all type inherits the session's Opus xhigh. Pick a specialist from the "
              "allowlist",
    "borg-collective:routing": "ROUTING is a guide (docs/agent-routing.md), not an agent type. Pick a "
                               "specialist from the allowlist",
}


class Dyn(object):
    """A value that could not be read as a string literal (variable, expression, spread, ...)."""
    def __init__(self, why):
        self.why = why


def research_invoked(path):
    """True when the transcript shows a research-tools Skill tool_use or research slash command."""
    if not path or not isinstance(path, str):
        return False
    try:
        fh = open(path, "r", encoding="utf-8", errors="replace")
    except Exception:
        return False
    with fh:
        for line in fh:
            if "research" not in line and "brainstorm" not in line:
                continue
            if '"Skill"' not in line and "<command-name>" not in line:
                continue
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            msg = rec.get("message") if isinstance(rec, dict) else None
            content = msg.get("content") if isinstance(msg, dict) else None
            kind = rec.get("type") if isinstance(rec, dict) else None
            if kind == "assistant" and isinstance(content, list):
                for b in content:
                    if isinstance(b, dict) and b.get("type") == "tool_use" and b.get("name") == "Skill":
                        inp = b.get("input")
                        s = inp.get("skill") if isinstance(inp, dict) else None
                        if isinstance(s, str) and s.startswith(RESEARCH_PREFIX):
                            return True
            elif kind == "user":
                texts = []
                if isinstance(content, str):
                    texts = [content]
                elif isinstance(content, list):
                    texts = [b.get("text") for b in content
                             if isinstance(b, dict) and b.get("type") == "text"]
                for t in texts:
                    if isinstance(t, str) and RESEARCH_CMD_RE.search(t):
                        return True
    return False


def is_research_type(t):
    return isinstance(t, str) and t.strip().startswith(RESEARCH_PREFIX)


def type_problem(t, research_ok):
    """None if subagent type t may be spawned, else a message that names the fix."""
    if isinstance(t, Dyn):
        return "subagent type must be a string literal (%s). Allowed: %s" % (t.why, USE_INSTEAD)
    if not isinstance(t, str) or not t.strip():
        return ("no subagent_type: an untyped spawn is a fork that inherits the session's Opus xhigh. "
                "Pass subagent_type: " + USE_INSTEAD)
    t = t.strip()
    if t in ALLOWED_TYPES:
        return None
    if t.startswith(RESEARCH_PREFIX):
        if research_ok:
            return None
        return ("'%s' is allowed only in a session that invoked a research-tools skill or command. "
                "Invoke /research-tools:research, /deep-research or /brainstorm first, or use "
                "borg-collective:borg-researcher (Sonnet) for web research" % t)
    hint = TYPE_HINTS.get(t.lower())
    if hint:
        return "'%s' is not allowed: %s" % (t, hint)
    if ("borg-collective:" + t) in ALLOWED_TYPES:
        return "use the namespaced form subagent_type borg-collective:%s, not '%s'" % (t, t)
    return "subagent type '%s' is not on the allowlist. Use one of: %s" % (t, USE_INSTEAD)


def cap_problems(model, effort, need_pin, agent_type=None):
    """model/effort are None when absent, else the value as given. need_pin: absent is itself a fault."""
    out = []
    if model is None:
        if need_pin:
            out.append("no model: an unpinned call inherits Opus. Pass model: 'sonnet' or 'haiku'")
    elif isinstance(model, Dyn):
        out.append("model must be a string literal (%s); use 'sonnet' or 'haiku'" % model.why)
    elif not (isinstance(model, str) and MODEL_RE.match(model.strip().lower())):
        out.append("model %r is above the cap. Only sonnet or haiku (claude-sonnet-*/claude-haiku-* ids "
                   "work too); never opus, fable or inherit" % (model,))
    if effort is None:
        if need_pin:
            out.append("no effort: an unpinned call inherits the session's xhigh. Pass effort: 'low', "
                       "'medium' or 'high'")
        elif agent_type in EFFORT_REQUIRED_TYPES:
            out.append("%s pins no effort, so it inherits the session's xhigh. Pass effort: 'low' "
                       "(or 'medium'/'high')" % agent_type)
    elif isinstance(effort, Dyn):
        out.append("effort must be a string literal (%s); use 'low', 'medium' or 'high'" % effort.why)
    elif not (isinstance(effort, str) and effort.strip().lower() in EFFORT_OK):
        out.append("effort %r is above the cap. Use 'low', 'medium' or 'high'; never xhigh or max"
                   % (effort,))
    return out
# POLICY-END


class ParseError(Exception):
    pass


class Tok(object):
    __slots__ = ("kind", "val", "pos", "exprs")

    def __init__(self, kind, val, pos, exprs=None):
        self.kind = kind      # id | num | str | tpl | re | p
        self.val = val        # str/tpl: decoded text (tpl: None when it has ${}); id/p: the text
        self.pos = pos
        self.exprs = exprs or []   # tpl only: token lists of each ${ } expression


OPEN = "([{"
CLOSE = ")]}"
REGEX_AFTER_WORDS = set(["return", "typeof", "case", "in", "of", "delete", "void", "throw", "new",
                         "else", "do", "yield", "await", "instanceof"])
REGEX_AFTER_PUNCT = set(["(", ",", "=", ":", "[", "!", "&", "|", "?", "{", ";", "+", "-", "*", "%", "<",
                         ">", "~", "^", "=>", "..."])


def line_of(src, pos):
    return src.count("\n", 0, pos) + 1


def tokenize(src, i, in_expr):
    """Return (tokens, end). In a template ${ } expression, end is the index of the closing brace."""
    toks = []
    n = len(src)
    depth = 0
    while i < n:
        c = src[i]
        if c.isspace():
            i += 1
            continue
        if c == "/" and src.startswith("//", i):
            j = src.find("\n", i)
            i = n if j < 0 else j
            continue
        if c == "/" and src.startswith("/*", i):
            j = src.find("*/", i + 2)
            if j < 0:
                raise ParseError("unterminated block comment at line %d" % line_of(src, i))
            i = j + 2
            continue
        if c == "'" or c == '"':
            j = i + 1
            buf = []
            while True:
                if j >= n or src[j] == "\n":
                    raise ParseError("unterminated string literal at line %d" % line_of(src, i))
                d = src[j]
                if d == "\\":
                    buf.append(src[j + 1:j + 2])
                    j += 2
                    continue
                if d == c:
                    break
                buf.append(d)
                j += 1
            toks.append(Tok("str", "".join(buf), i))
            i = j + 1
            continue
        if c == "`":
            j = i + 1
            buf = []
            exprs = []
            while True:
                if j >= n:
                    raise ParseError("unterminated template literal at line %d" % line_of(src, i))
                d = src[j]
                if d == "\\":
                    buf.append(src[j + 1:j + 2])
                    j += 2
                    continue
                if d == "`":
                    break
                if d == "$" and src.startswith("${", j):
                    sub, end = tokenize(src, j + 2, True)
                    exprs.append(sub)
                    j = end + 1
                    continue
                buf.append(d)
                j += 1
            toks.append(Tok("tpl", None if exprs else "".join(buf), i, exprs))
            i = j + 1
            continue
        if c.isalpha() or c == "_" or c == "$":
            j = i + 1
            while j < n and (src[j].isalnum() or src[j] in "_$"):
                j += 1
            toks.append(Tok("id", src[i:j], i))
            i = j
            continue
        if c.isdigit() or (c == "." and i + 1 < n and src[i + 1].isdigit()):
            j = i + 1
            while j < n and (src[j].isalnum() or src[j] in "._"):
                j += 1
            toks.append(Tok("num", src[i:j], i))
            i = j
            continue
        if c == "/":
            prev = toks[-1] if toks else None
            is_re = (prev is None
                     or (prev.kind == "p" and prev.val in REGEX_AFTER_PUNCT)
                     or (prev.kind == "id" and prev.val in REGEX_AFTER_WORDS))
            if is_re:
                j = i + 1
                in_class = False
                while True:
                    if j >= n or src[j] == "\n":
                        raise ParseError("unterminated regular expression at line %d" % line_of(src, i))
                    d = src[j]
                    if d == "\\":
                        j += 2
                        continue
                    if d == "[":
                        in_class = True
                    elif d == "]":
                        in_class = False
                    elif d == "/" and not in_class:
                        break
                    j += 1
                j += 1
                while j < n and src[j].isalnum():
                    j += 1
                toks.append(Tok("re", None, i))
                i = j
                continue
        if src.startswith("...", i):
            toks.append(Tok("p", "...", i))
            i += 3
            continue
        if src.startswith("=>", i):
            toks.append(Tok("p", "=>", i))
            i += 2
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            if in_expr and depth == 0:
                return toks, i
            depth -= 1
        toks.append(Tok("p", c, i))
        i += 1
    if in_expr:
        raise ParseError("unterminated ${ in a template literal")
    return toks, n


def token_lists(toks):
    yield toks
    for t in toks:
        if t.kind == "tpl":
            for sub in t.exprs:
                for lst in token_lists(sub):
                    yield lst


def check_balanced(lst, src):
    stack = []
    for t in lst:
        if t.kind != "p":
            continue
        if t.val in OPEN:
            stack.append(t)
        elif t.val in CLOSE:
            if not stack or OPEN.index(stack[-1].val) != CLOSE.index(t.val):
                raise ParseError("unbalanced %r at line %d" % (t.val, line_of(src, t.pos)))
            stack.pop()
    if stack:
        raise ParseError("unclosed %r opened at line %d" % (stack[-1].val, line_of(src, stack[-1].pos)))


def match(lst, k):
    """lst[k] is an opener; return the index of its closer (balance was already checked)."""
    depth = 0
    for m in range(k, len(lst)):
        t = lst[m]
        if t.kind != "p":
            continue
        if t.val in OPEN:
            depth += 1
        elif t.val in CLOSE:
            depth -= 1
            if depth == 0:
                return m
    raise ParseError("unbalanced bracket")


def split_commas(lst):
    parts = []
    cur = []
    depth = 0
    for t in lst:
        if t.kind == "p":
            if t.val in OPEN:
                depth += 1
            elif t.val in CLOSE:
                depth -= 1
            elif t.val == "," and depth == 0:
                parts.append(cur)
                cur = []
                continue
        cur.append(t)
    if cur:
        parts.append(cur)
    return parts


def is_p(t, v):
    return t is not None and t.kind == "p" and t.val == v


def collect_consts(lists, src):
    """name -> string for names declared exactly once with a string literal and never reassigned."""
    decl = {}
    counts = {}
    tainted = set()
    for lst in lists:
        for k, t in enumerate(lst):
            if t.kind != "id" or not is_p(lst[k + 1] if k + 1 < len(lst) else None, "="):
                continue
            nn = lst[k + 2] if k + 2 < len(lst) else None
            if is_p(nn, "="):
                continue
            prev = lst[k - 1] if k else None
            if prev is not None and prev.kind == "id" and prev.val in ("const", "let", "var"):
                counts[t.val] = counts.get(t.val, 0) + 1
                after = lst[k + 3] if k + 3 < len(lst) else None
                simple_end = (after is None or (after.kind == "p" and after.val in (";", ",", ")", "}"))
                              or (nn is not None and line_of(src, after.pos) != line_of(src, nn.pos)))
                if nn is not None and nn.kind in ("str", "tpl") and nn.val is not None and simple_end:
                    decl[t.val] = nn.val
                else:
                    tainted.add(t.val)
            else:
                tainted.add(t.val)
    return dict((k, v) for k, v in decl.items() if counts.get(k) == 1 and k not in tainted)


def literal(vtoks, consts):
    if len(vtoks) == 1:
        t = vtoks[0]
        if t.kind in ("str", "tpl") and t.val is not None:
            return t.val
        if t.kind == "id" and t.val in consts:
            return consts[t.val]
        if t.kind == "id":
            return Dyn("variable '%s'" % t.val)
        if t.kind == "tpl":
            return Dyn("template literal with ${} interpolation")
    return Dyn("an expression")


def analyze_call(lst, k, consts, src, research_state):
    """lst[k] is the 'agent' identifier of a call. Returns a list of problem strings (may be empty)."""
    close = match(lst, k + 1)
    args = split_commas(lst[k + 2:close])
    opts = args[1] if len(args) >= 2 else None
    problems = []
    label = None
    props = {}
    if opts is None:
        problems.append("no options: the call inherits the session's Opus xhigh. Pass { agentType: "
                        "'borg-collective:borg-scout' } (or -grunt/-nanoprobe/-researcher/-reviewer/"
                        "-verifier) or { model: 'sonnet', effort: 'medium' }")
    elif len(opts) >= 2 and is_p(opts[0], "{") and match(opts, 0) == len(opts) - 1:
        for part in split_commas(opts[1:-1]):
            if not part:
                continue
            h = part[0]
            if is_p(h, "..."):
                problems.append("options contain a spread (...), so the pin cannot be checked. Write "
                                "agentType, or model + effort, inline as literals")
                continue
            if is_p(h, "["):
                problems.append("options contain a computed key, so the pin cannot be checked")
                continue
            if h.kind not in ("id", "str", "num"):
                continue
            if len(part) == 1:
                key, vt = h.val, [h]
            elif is_p(part[1], ":"):
                key, vt = h.val, part[2:]
            elif is_p(part[1], "("):
                key, vt = h.val, part
            else:
                continue
            props[key] = vt
        lab = literal(props["label"], consts) if "label" in props else None
        label = lab if isinstance(lab, str) else None
        agent_type = literal(props["agentType"], consts) if "agentType" in props else None
        model = literal(props["model"], consts) if "model" in props else None
        effort = literal(props["effort"], consts) if "effort" in props else None
        if agent_type is not None:
            research = is_research_type(agent_type)
            if research and research_state[0] is None:
                research_state[0] = research_invoked(research_state[1])
            tp = type_problem(agent_type, bool(research_state[0]) if research else False)
            if tp:
                problems.append(tp.replace("subagent_type", "agentType"))
            elif not research:
                problems.extend(cap_problems(model, effort, False, agent_type))
        else:
            problems.extend(cap_problems(model, effort, True))
            if problems:
                problems.append("or pass agentType: 'borg-collective:borg-scout' (read-only search) / "
                                "-grunt / -nanoprobe / -researcher / -reviewer / -verifier")
    else:
        problems.append("options are not an object literal (a variable, spread, call or expression), so "
                        "the pin cannot be checked. Write the options inline: { agentType: ... } or "
                        "{ model: 'sonnet', effort: 'medium' }")
    if not problems:
        return []
    where = "line %d" % line_of(src, lst[k].pos)
    if label:
        where += " (label '%s')" % label
    return ["%s: %s" % (where, "; ".join(problems))]


def check_script(src, research_state):
    toks, _ = tokenize(src, 0, False)
    lists = list(token_lists(toks))
    for lst in lists:
        check_balanced(lst, src)
    consts = collect_consts(lists, src)
    out = []
    for lst in lists:
        for k, t in enumerate(lst):
            if t.kind != "id" or t.val != "agent":
                continue
            prev = lst[k - 1] if k else None
            nxt = lst[k + 1] if k + 1 < len(lst) else None
            if prev is not None and prev.kind == "id" and prev.val == "function":
                continue
            if is_p(nxt, "("):
                out.extend(analyze_call(lst, k, consts, src, research_state))
            elif is_p(prev, "."):
                continue
            elif is_p(nxt, ":") and (is_p(prev, "{") or is_p(prev, ",")):
                continue
            else:
                out.append("line %d: agent is referenced without being called (alias, callback, "
                           ".call/.bind, destructuring), so its options cannot be checked. Call "
                           "agent(prompt, { ... }) directly" % line_of(src, t.pos))
    return out


def find_saved(name, cwd):
    if not re.match(r"^[A-Za-z0-9][A-Za-z0-9._-]*$", name) or ".." in name:
        return None
    dirs = []
    d = os.path.abspath(cwd)
    while True:
        dirs.append(os.path.join(d, ".claude", "workflows"))
        parent = os.path.dirname(d)
        if parent == d:
            break
        d = parent
    dirs.append(os.path.join(os.path.expanduser("~"), ".claude", "workflows"))
    for base in dirs:
        for ext in ("", ".js", ".mjs", ".cjs", ".ts"):
            cand = os.path.join(base, name + ext)
            if os.path.isfile(cand):
                return cand
    return None


def read_file(path):
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        return fh.read()


def deny(origin, problems):
    sys.stderr.write("borg workflow model guard: Workflow denied (%s).\n" % origin)
    for q in problems:
        sys.stderr.write("  - %s\n" % q)
    sys.stderr.write("Policy: orchestrator/drone sessions run Opus xhigh; every agent() must be below that: "
                     "an allowlisted agentType (borg-collective:borg-scout/-grunt/-nanoprobe/-researcher/"
                     "-reviewer/-verifier, claude-code-guide), or with no agentType model 'sonnet'/'haiku' "
                     "AND effort 'low'/'medium'/'high'. research-tools:* is exempt, only after a "
                     "research-tools skill/command ran. No escape hatch. Guide: docs/agent-routing.md. "
                     "Kill switch: BORG_WORKFLOW_MODEL_GUARD=0.\n")
    return 2


def main():
    try:
        data = json.loads(sys.stdin.read())
    except Exception:
        return 0
    if not isinstance(data, dict) or data.get("tool_name") != "Workflow":
        return 0
    ti = data.get("tool_input")
    if not isinstance(ti, dict):
        ti = {}
    script, spath, name = ti.get("script"), ti.get("scriptPath"), ti.get("name")
    if isinstance(script, str) and script.strip():
        src, origin = script, "inline script"
    elif isinstance(spath, str) and spath.strip():
        origin = "scriptPath %s" % spath
        try:
            src = read_file(os.path.expanduser(spath))
        except Exception as exc:
            return deny(origin, ["scriptPath cannot be read (%s), so the script cannot be checked. Pass "
                                 "the script inline or fix the path" % exc])
    elif isinstance(name, str) and name.strip():
        origin = "saved workflow '%s'" % name
        cwd = data.get("cwd") if isinstance(data.get("cwd"), str) and data.get("cwd") else os.getcwd()
        found = find_saved(name.strip(), cwd)
        if not found:
            return deny(origin, ["saved workflow '%s' not found in .claude/workflows (project) or "
                                 "~/.claude/workflows, so it cannot be checked. Pass the script inline or "
                                 "scriptPath" % name])
        try:
            src = read_file(found)
        except Exception as exc:
            return deny(origin, ["saved workflow file %s cannot be read (%s)" % (found, exc)])
    else:
        return deny("no script", ["the Workflow call has no script, scriptPath or name, so there is "
                                  "nothing to check"])
    research_state = [None, data.get("transcript_path")]
    try:
        problems = check_script(src, research_state)
    except ParseError as exc:
        return deny(origin, ["the script cannot be parsed (%s), and this guard fails closed. Fix the "
                             "syntax" % exc])
    if not problems:
        return 0
    return deny(origin, problems)


try:
    rc = main()
except Exception as exc:
    sys.stderr.write("borg workflow model guard: internal error (%s: %s); denying\n"
                     % (type(exc).__name__, exc))
    rc = 2
sys.exit(rc)
PY

python3 -I -c "$GUARD"
rc=$?
[[ $rc -eq 0 ]] && exit 0
exit 2
