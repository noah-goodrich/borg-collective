#!/usr/bin/env bash
# borg-gates-ledger.sh -- PreToolUse hook (matcher: Edit|Write|MultiEdit): in a session where /borg-review ran in
# GATES mode, deny the first edit until the assistant has printed its G1..G5 ledger, or the trivial line.
#
# Why a hook (#510): skills/borg-review/references/gates.md says "emit this before you start editing" and the model
# does the gates' reasoning in thinking and skips the visible ledger. Two SKILL.md rewrites failed (live evals RV2 and
# RV4, evals/orchestrator-skills). Instruction text cannot make a model print something; a denied edit can. Reads
# are never denied, so the model reads first and the ledger's G2 line cites files it has really opened.
#
# What it checks is that a ledger EXISTS, not what it says: G1..G5 lines (`G<n> <label>:`, the same shape the eval
# grader matches) or `Gates: trivial -- G1+G5 only`, in an assistant TEXT block (thinking does not count) after the
# most recent gates invocation. Once one exists every edit passes.
#
# Gates mode, read from the transcript (Claude JSONL), is: a /borg-review (or the old /fable-reviewer) slash command,
# or a Skill tool call to either, whose args -- or, for a Skill call with empty args, the last real user message --
# carry a trigger phrase ("apply the gates", "fable mode", ...). Plain /borg-review is diagnostic mode and is not
# touched. Subagents (payload agent_id / agent_type) are not touched: the ledger is the main session's.
#
# Contract: denies with exit 2 and the reason on stderr. FAILS OPEN on everything else: no python3, no transcript,
# an unreadable payload, a Cortex `.json` transcript. After BORG_GATES_LEDGER_MAX_DENIALS (default 3) denials in one
# session since the last invocation it lets the edit through, so a ledger the hook cannot see never wedges a session.
# Kill switch: BORG_GATES_LEDGER=0. Tests: tests/gates_ledger.bats.

set -uo pipefail

[[ "${BORG_GATES_LEDGER:-1}" == "0" ]] && exit 0

INPUT=""
IFS= read -r -d "" INPUT || true
[[ "$INPUT" == *transcript_path* ]] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

# Read with `read -d ""` outside any command substitution (bash 3.2 heredoc-in-$( ) parse bug, see
# tests/hook_bash32_parse.bats).
read -r -d "" GUARD <<'PY' || true
import json, os, re, sys

EDIT_TOOLS = ("Edit", "Write", "MultiEdit")
SKILL_RE = re.compile(r"(?:^|:)(?:borg-review|fable-reviewer)$")
COMMAND_RE = re.compile(r"<command-name>\s*/?(?:[\w-]+:)?(?:borg-review|fable-reviewer)\s*</command-name>")
ARGS_RE = re.compile(r"<command-args>(.*?)</command-args>", re.S)
TRIGGER_RE = re.compile(r"apply the gates|fable mode|gates mode|5-gate|five gates|start-of-change gates|fable-reviewer",
                        re.I)
LEDGER_LINE_RE = re.compile(r"^[\s>*\-`]*G([1-5]) (?:scope|evidence|adversary|verify|calibrate):")
TRIVIAL_RE = re.compile(r"Gates:\s*trivial")

DENY = """borg-review is in gates mode and no G1-G5 ledger has been printed yet, so this edit is denied.
Print the ledger now as visible text (not in thinking), then repeat the same edit. Exactly this shape:

G1 scope:     <one sentence: what is in scope and the observable done-criterion; what is NOT>
G2 evidence:  <the real files you opened, as paths, and the load-bearing fact@path:line>
G3 adversary: <the strongest way this plan is wrong, and your answer>
G4 verify:    <the exact test command you will run and expect to pass>
G5 calibrate: <effort tier, model routing, response size>

For a trivial one-line change print only this line instead: Gates: trivial — G1+G5 only
Read any file you still need first: reads are never blocked. Once the ledger is printed, edits pass.
(Kill switch for this check: BORG_GATES_LEDGER=0.)"""


def texts(content):
    if isinstance(content, str):
        return [content]
    if isinstance(content, list):
        return [b.get("text") for b in content
                if isinstance(b, dict) and b.get("type") == "text" and isinstance(b.get("text"), str)]
    return []


def scan(path):
    """(gates_marker, ledger_seen): gates_marker is the index of the last gates invocation, or None."""
    marker = None
    ledger_labels = set()
    trivial = False
    last_user = ""
    try:
        fh = open(path, "r", encoding="utf-8", errors="replace")
    except Exception:
        return None, False
    with fh:
        for idx, line in enumerate(fh):
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            if not isinstance(rec, dict):
                continue
            msg = rec.get("message")
            content = msg.get("content") if isinstance(msg, dict) else None
            kind = rec.get("type")
            if kind == "user":
                if rec.get("isMeta") or isinstance(content, list) and any(
                        isinstance(b, dict) and b.get("type") == "tool_result" for b in content):
                    continue
                for t in texts(content):
                    m = COMMAND_RE.search(t)
                    if m:
                        a = ARGS_RE.search(t)
                        if TRIGGER_RE.search(a.group(1) if a else ""):
                            marker, ledger_labels, trivial = idx, set(), False
                    else:
                        last_user = t
            elif kind == "assistant":
                if not isinstance(content, list):
                    continue
                for b in content:
                    if not isinstance(b, dict):
                        continue
                    if b.get("type") == "tool_use" and b.get("name") == "Skill":
                        inp = b.get("input") if isinstance(b.get("input"), dict) else {}
                        skill = inp.get("skill")
                        if isinstance(skill, str) and SKILL_RE.search(skill):
                            args = inp.get("args") if isinstance(inp.get("args"), str) else ""
                            if TRIGGER_RE.search(args) or (not args.strip() and TRIGGER_RE.search(last_user)):
                                marker, ledger_labels, trivial = idx, set(), False
                    elif b.get("type") == "text" and marker is not None and isinstance(b.get("text"), str):
                        for ln in b["text"].splitlines():
                            m = LEDGER_LINE_RE.match(ln)
                            if m:
                                ledger_labels.add(m.group(1))
                        if TRIVIAL_RE.search(b["text"]):
                            trivial = True
    return marker, trivial or len(ledger_labels) == 5


def counter_path(session):
    base = os.environ.get("XDG_STATE_HOME") or os.path.join(os.path.expanduser("~"), ".local", "state")
    safe = re.sub(r"[^A-Za-z0-9_.-]", "_", session)[:80] or "unknown"
    return os.path.join(base, "borg", "gates-ledger", safe)


def main():
    try:
        payload = json.loads(sys.stdin.read())
    except ValueError:
        return 0
    if not isinstance(payload, dict) or payload.get("tool_name") not in EDIT_TOOLS:
        return 0
    if payload.get("agent_id") or payload.get("agent_type"):
        return 0
    path = payload.get("transcript_path")
    if not isinstance(path, str) or not path.endswith(".jsonl"):
        return 0
    marker, ledger = scan(path)
    if marker is None or ledger:
        return 0
    try:
        cap = int(os.environ.get("BORG_GATES_LEDGER_MAX_DENIALS", "3"))
    except ValueError:
        cap = 3
    session = str(payload.get("session_id") or "")
    cp = counter_path(session + "-" + str(marker))
    try:
        n = int(open(cp).read().strip() or "0")
    except Exception:
        n = 0
    if n >= cap:
        return 0
    try:
        os.makedirs(os.path.dirname(cp), exist_ok=True)
        with open(cp, "w") as fh:
            fh.write(str(n + 1))
    except Exception:
        pass
    sys.stderr.write(DENY + "\n")
    return 2


try:
    sys.exit(main())
except SystemExit:
    raise
except Exception:
    sys.exit(0)
PY

printf '%s' "$INPUT" | python3 -I -c "$GUARD"
exit $?
