#!/usr/bin/env bash
# borg-agent-model-guard.sh — PreToolUse hook (matcher: Agent|Task): enforce the subagent routing policy.
#
# Policy (docs/agent-routing.md): orchestrator and drone sessions run Opus at xhigh; every subagent they
# spawn must be BELOW that tier. Deny-by-default allowlist of subagent_type; for allowed types a per-call
# model must be absent or sonnet/haiku and a per-call effort absent or low/medium/high. The only exception
# is research-tools:* (any model/effort), and only in a session whose transcript shows a research-tools
# skill or command was invoked. A spawn with no subagent_type is a fork that inherits Opus xhigh: denied.
#
# Contract: denies with exit 2 and the fix on stderr. Fails OPEN only when the call is not ours to judge
# (missing python3, empty or malformed stdin, another tool). Kill switch: BORG_AGENT_MODEL_GUARD=0.
# The policy block below is byte-identical in hooks/borg-workflow-model-guard.sh (a bats test diffs them).
#
# Cortex Code: also registered in Cortex's hooks.json (borg.zsh _BORG_CORTEX_HOOKS), where its task tool arrives as
# tool_name "Task" and the borg agents are installed under the same borg-collective: names. Two Cortex-only rules sit
# after POLICY-END: a per-call model must be a full claude-sonnet-*/claude-haiku-* id (Cortex ignores aliases), and
# Cortex's own Snowflake agents (CORTEX_SPECIALISTS) are allowed only with such a pin.

set -uo pipefail

[[ "${BORG_AGENT_MODEL_GUARD:-1}" == "0" ]] && exit 0
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
        elif isinstance(agent_type, str) and agent_type.strip() in EFFORT_REQUIRED_TYPES:
            out.append("%s pins no effort, so it inherits the session's xhigh. Pass effort: 'low' "
                       "(or 'medium'/'high')" % agent_type.strip())
    elif isinstance(effort, Dyn):
        out.append("effort must be a string literal (%s); use 'low', 'medium' or 'high'" % effort.why)
    elif not (isinstance(effort, str) and effort.strip().lower() in EFFORT_OK):
        out.append("effort %r is above the cap. Use 'low', 'medium' or 'high'; never xhigh or max"
                   % (effort,))
    return out
# POLICY-END

# Cortex Code only (outside the shared POLICY block; borg-workflow-model-guard.sh has no Cortex twin, since Cortex has
# no Workflow tool). Cortex runs every command hook with CORTEX_PROJECT_DIR set and Claude Code never sets it, so that
# is the signal. Measured live on Cortex 1.2.24 (evals/cortex-agents, 2026-10-30): a per-call `model` on the task tool
# is honored as a full id (Explore with model "claude-haiku-5-5" ran Haiku) and silently ignored as an alias (a
# model "haiku" session billed only the session's model), so a Cortex call must name the full id. Cortex's own
# Snowflake agents have no borg equivalent and pin no model, so they run the session's model unless the call pins a
# full Sonnet/Haiku id.
CORTEX_SPECIALISTS = ("snowflake-object-discovery", "semantic-view-transform", "dbt-verify", "sql-verify",
                      "feedback")
CORTEX_MODEL_RE = re.compile(r"^(claude-sonnet-[a-z0-9._-]+|claude-haiku-[a-z0-9._-]+)$")


def is_cortex():
    return bool(os.environ.get("CORTEX_PROJECT_DIR"))


def cortex_model_problem(t, model):
    """Cortex: None if this call's model is allowed, else the fix. A specialist must pin one; others may omit it."""
    if model is None:
        if t in CORTEX_SPECIALISTS:
            return ("'%s' pins no model, so in Cortex it runs the session's model (Opus in a Queen or drone "
                    "session). Pass model: 'claude-sonnet-5-5' (or a claude-haiku-* id)" % t)
        return None
    if isinstance(model, str) and CORTEX_MODEL_RE.match(model.strip().lower()):
        return None
    if isinstance(model, str) and MODEL_RE.match(model.strip().lower()):
        return ("model %r is an alias, which Cortex ignores (the call runs the session's model). Pass the full id, "
                "for example 'claude-sonnet-5-5' or 'claude-haiku-5-5'" % (model,))
    return None


def main():
    try:
        data = json.loads(sys.stdin.read())
    except Exception:
        return 0
    if not isinstance(data, dict) or data.get("tool_name") not in ("Agent", "Task"):
        return 0
    ti = data.get("tool_input")
    if not isinstance(ti, dict):
        ti = {}
    st = ti.get("subagent_type")
    research = is_research_type(st)
    model = ti.get("model")
    model = None if model in (None, "") else model
    effort = ti.get("effort")
    effort = None if effort in (None, "") else effort
    problems = []
    if is_cortex() and isinstance(st, str) and st.strip() in CORTEX_SPECIALISTS:
        # Not on the allowlist, which is shared with Claude Code; allowed here on the same caps plus a model pin.
        problems.extend(cap_problems(model, effort, False, st))
        if not problems:
            p = cortex_model_problem(st.strip(), model)
            if p:
                problems.append(p)
    else:
        p = type_problem(st, research_invoked(data.get("transcript_path")) if research else False)
        if p:
            problems.append(p)
        elif not research:
            problems.extend(cap_problems(model, effort, False, st))
            if not problems and is_cortex():
                p = cortex_model_problem(st.strip(), model)
                if p:
                    problems.append(p)
    if not problems:
        return 0
    sys.stderr.write("borg agent model guard: Agent call denied.\n")
    for q in problems:
        sys.stderr.write("  - %s\n" % q)
    sys.stderr.write("Policy: Queen/drone sessions run Opus xhigh; subagents must be below that "
                     "(Sonnet/Haiku, effort low/medium/high); claude-code-guide also needs effort low/medium/high. "
                     "Only research-tools:* is exempt, and only "
                     "after a research-tools skill/command ran. Guide: docs/agent-routing.md. "
                     "Kill switch: BORG_AGENT_MODEL_GUARD=0.\n")
    return 2


try:
    rc = main()
except Exception as exc:
    sys.stderr.write("borg agent model guard: internal error (%s); denying\n" % exc)
    rc = 2
sys.exit(rc)
PY

python3 -I -c "$GUARD"
rc=$?
[[ $rc -eq 0 ]] && exit 0
exit 2
