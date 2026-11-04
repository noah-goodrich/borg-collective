#!/usr/bin/env python3
"""Graders, mutations, the reducer proof and the sanitizer for evals/orchestrator-skills. Stdlib only, no model.

THE SHAPE (the two decisions of the step 3a triage):
  * Graders read a REDUCED TRACE, not the raw stream. `reduce` turns a `claude -p --output-format stream-json` run into
    ordered steps (text and tool calls with their results), the final message, the result object (cost, turns, models)
    and sandbox facts (file hashes before and after, the local settings file). The raw stream carries the system prompt,
    so only the whitelisted fields of it are ever kept, and `sanitize` refuses to write anything that still looks real.
  * A known-bad run is a deterministic MUTATION of a recorded known-good trace: free, and in the real format by
    construction. A known-good is always a recording of a live run, never constructed.

WHAT IS GRADED, AND WHAT IS NOT. Every case here is a Tier 2 script grader: a tool call, a file on disk, the shape of a
message. NOTHING GRADES WHETHER AN ANSWER IS GOOD. In particular borg-review is graded for SHAPE (the diagnostic block,
M equal to the plan's criteria count, exactly one recommendation, a gates ledger in order and before the first edit),
not for the quality of its diagnosis: AC3 allows `llm` graders only for the ledger's judge items and borg-review is not
one (Noah, 2026-11-02). A shape-correct but wrong diagnosis passes.

Subcommands (every grading line is `CHECK pass|fail|skip <id> <message>`):
  verdict <trace.json>              grade one trace (RV1's also yields RV3)
  grade <dir>                       grade every <case>.trace.json in <dir> (RV3 is graded on RV1's trace)
  mutate <dir> <kind> <dest>        copy <dir> to <dest> with one fact made false
  replay <dir>                      re-grade every recorded trace and require the verdict the live run gave it
  mutations <dir>                   print `<kind> <verdict> <target> <recorded|synthetic>` per mutation, for the harness
  reducer <dir>                     re-reduce every recorded stream and compare with its recorded trace
  env <repo> <wf_run> <script_rel> <stray> <criteria>   the offline environment proofs that need no tool but python
  snapshot <repo> <home>            print the sandbox facts (file hashes, local settings, home settings hash) as JSON
  reduce <stream.jsonl> <meta.json> print the trace for one run
  scan <dir>                        refuse-list scan of a committed recording
  sanitize <rundir> <dest> <repo>   write the whitelisted, redacted recording; refuse (exit 3) when anything real survives

Exit codes: 0 no failed check, 1 a check failed, 2 usage, 3 premise broken (unreadable input, a refusal to write).
"""

from __future__ import annotations

import getpass
import hashlib
import json
import re
import shutil
import sys
from pathlib import Path
from typing import Any

# ── constants the graders share ──────────────────────────────────────────────────────────────────────────────────
META_TOOLS = frozenset({"Skill", "ToolSearch", "TodoWrite", "TaskCreate", "TaskUpdate", "TaskList"})
EDIT_TOOLS = frozenset({"Edit", "Write", "MultiEdit", "NotebookEdit"})
RECOMMENDATION_RE = re.compile(r"^(Next:|Park\b|Stop\.|Switch repositories|All criteria met|Good stopping point)")
LEDGER_LABELS = {"1": "scope", "2": "evidence", "3": "adversary", "4": "verify", "5": "calibrate"}
LEDGER_LINE_RE = re.compile(r"^[\s>*\-`]*G([1-5]) (scope|evidence|adversary|verify|calibrate):\s*(.*)$")
TRIVIAL_GATES = "Gates: trivial — G1+G5 only"
SCOPE_CREEP_RE = re.compile(
    r"scope creep|unrelated|not map|n.t map|no criterion|none of the|tangent|Park\b|stray|not part of|outside", re.I
)
STATUS_RE = re.compile(r"\bborg-resume\s+status\b")
PATH_RE = re.compile(r"[A-Za-z0-9_./-]+\.(?:sh|md|py|json|txt|bats|yml|yaml|js|ts)(?::\d+(?:-\d+)?)?")
TIME_RE = re.compile(r"\b\d{1,2}:\d{2}\b|\b\d{1,2}\s?(?:am|pm)\b", re.I)
BROAD_RULE_RE = re.compile(r"^Bash(?:\(\s*\*?:?\*?\s*\))?$")
OUTPUT_CAP = 1500


class Premise(Exception):
    """The input cannot be graded at all (not a verdict about the skill)."""


def _load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise Premise(f"cannot read {path}: {exc}") from exc


def _load_jsonl(path: Path) -> list[dict]:
    out: list[dict] = []
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise Premise(f"cannot read {path}: {exc}") from exc
    for raw in text.splitlines():
        raw = raw.strip()
        if not raw:
            continue
        try:
            obj = json.loads(raw)
        except ValueError:
            continue
        if isinstance(obj, dict):
            out.append(obj)
    return out


# ── the reducer: stream-json events -> a trace ───────────────────────────────────────────────────────────────────
def _text_of(content: Any) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "".join(p.get("text", "") for p in content if isinstance(p, dict) and p.get("type") == "text")
    return ""


def reduce_events(events: list[dict]) -> dict:
    """Steps (text and tool calls with results), the final message and the result object. Works on a raw stream and on
    the whitelisted copy `clean_events` writes, so the recorded stream proves the reducer on the real event shape."""
    steps: list[dict] = []
    by_id: dict[str, dict] = {}
    result: dict = {}
    final = ""
    for ev in events:
        kind = ev.get("type")
        if kind == "assistant":
            for block in (ev.get("message") or {}).get("content") or []:
                if not isinstance(block, dict):
                    continue
                if block.get("type") == "text" and block.get("text", "").strip():
                    steps.append({"kind": "text", "text": block["text"]})
                elif block.get("type") == "tool_use":
                    step = {
                        "kind": "tool",
                        "name": block.get("name", ""),
                        "input": block.get("input") or {},
                        "error": False,
                        "output": "",
                    }
                    steps.append(step)
                    by_id[str(block.get("id"))] = step
        elif kind == "user":
            content = (ev.get("message") or {}).get("content")
            if not isinstance(content, list):
                continue
            for block in content:
                if isinstance(block, dict) and block.get("type") == "tool_result":
                    step = by_id.get(str(block.get("tool_use_id")))
                    if step is not None:
                        step["error"] = bool(block.get("is_error"))
                        step["output"] = _text_of(block.get("content"))[:OUTPUT_CAP]
        elif kind == "result":
            final = ev.get("result") if isinstance(ev.get("result"), str) else ""
            models = ev.get("modelUsage") or {}
            result = {
                "cost": ev.get("total_cost_usd"),
                "turns": ev.get("num_turns"),
                "models": sorted(models) if isinstance(models, dict) else [],
                "subtype": ev.get("subtype"),
                "is_error": bool(ev.get("is_error")),
                "denials": len(ev.get("permission_denials") or []),
            }
    if not final:
        texts = [s["text"] for s in steps if s["kind"] == "text"]
        final = texts[-1] if texts else ""
    return {"steps": steps, "final": final, "result": result}


def build_trace(events: list[dict], meta: dict) -> dict:
    trace = reduce_events(events)
    trace.update(
        {
            "version": 1,
            "case": meta["case"],
            "expect": meta.get("expect", {}),
            "before": meta.get("before", {}),
            "after": meta.get("after", {}),
        }
    )
    return trace


# ── helpers over a trace ─────────────────────────────────────────────────────────────────────────────────────────
def _tools(trace: dict, *names: str) -> list[tuple[int, dict]]:
    return [(i, s) for i, s in enumerate(trace["steps"]) if s["kind"] == "tool" and (not names or s["name"] in names)]


def _status_calls(trace: dict) -> list[tuple[int, dict]]:
    return [(i, s) for i, s in _tools(trace, "Bash") if STATUS_RE.search(str((s["input"] or {}).get("command", "")))]


def _cron_calls(trace: dict) -> list[tuple[int, dict]]:
    return _tools(trace, "CronCreate")


def _norm(line: str) -> str:
    return re.sub(r"^[\s>*\-`#_]+", "", line).strip()


def _texts(trace: dict) -> list[tuple[int, str]]:
    """Every text-bearing item in order, the final message last."""
    items = [(i, s["text"]) for i, s in enumerate(trace["steps"]) if s["kind"] == "text"]
    items.append((len(trace["steps"]), trace["final"]))
    return items


def _mentions(step: dict, needle: str) -> bool:
    return needle in json.dumps(step.get("input", {}), sort_keys=True)


def _first_non_meta(trace: dict) -> tuple[int, dict] | None:
    for i, s in enumerate(trace["steps"]):
        if s["kind"] == "tool" and s["name"] not in META_TOOLS:
            return i, s
    return None


# ── the graders: each returns (verdict, message) ─────────────────────────────────────────────────────────────────
Verdict = tuple[str, str]


def grade_rs1(trace: dict) -> Verdict:
    exp = trace["expect"]
    first = _first_non_meta(trace)
    if first is None or first[1]["name"] != "Bash" or not STATUS_RE.search(str(first[1]["input"].get("command", ""))):
        return "fail", "the first tool call was not a `borg-resume status` (Step 1 was skipped)"
    if _cron_calls(trace):
        return "fail", "a CronCreate was made although an active record matches the run"
    final = trace["final"]
    if str(exp.get("rid")) not in final and str(exp.get("resume_at")) not in final:
        return "fail", f"the final message names neither the record's rid {exp.get('rid')} nor its resume_at"
    return "pass", "status first, no CronCreate, and the final message names the ledger's record"


def grade_rs2(trace: dict) -> Verdict:
    exp = trace["expect"]
    crons = _cron_calls(trace)
    if len(crons) != 1:
        return "fail", f"expected exactly one CronCreate, found {len(crons)}"
    idx, call = crons[0]
    args = call["input"]
    if args.get("recurring") is not False:
        return "fail", f"recurring is {args.get('recurring')!r}, not false"
    fields = str(args.get("cron", "")).split()
    if len(fields) != 5 or not fields[0].isdigit():
        return "fail", f"cron {args.get('cron')!r} is not pinned to one minute"
    if int(fields[0]) in (0, 30):
        return "fail", f"cron minute {fields[0]} sits on the :00/:30 marks"
    prompt = str(args.get("prompt", ""))
    for needle in (exp["runId"], exp["scriptPath"], "resumeFromRunId"):
        if needle not in prompt:
            return "fail", f"the cron prompt lacks {needle!r}"
    status = [i for i, _ in _status_calls(trace)]
    if not status or min(status) > idx:
        return "fail", "CronCreate came before any `borg-resume status` attempt (Step 1 was skipped)"
    final = trace["final"]
    if exp["runId"] not in final or not TIME_RE.search(final):
        return "fail", "the final message does not state the runId and the time"
    return "pass", "one non-recurring CronCreate, minute off the marks, run id and script path in its prompt"


def _status_ok(trace: dict) -> tuple[int, dict] | None:
    """A status call that RAN: not an error, and its output is the status document. The tool's error flag alone is not
    enough, because the model wraps the call as `borg-resume status ...; echo "EXIT=$?"`, which exits 0 even when the
    command was not found."""
    for i, s in _status_calls(trace):
        if not s["error"] and '"records"' in s["output"]:
            return i, s
    return None


def grade_rs3(trace: dict) -> Verdict:
    if _status_ok(trace) is None:
        return "skip", "premise unproven: no `borg-resume status` call exited 0 in the trace"
    if _cron_calls(trace):
        return "fail", "a CronCreate was made although the only record is terminal"
    state = str(trace["expect"].get("state"))
    if not re.search(rf"\b{re.escape(state)}\b", trace["final"], re.I):
        return "fail", f"the final message does not name the terminal state {state!r}"
    return "pass", "status ran, no CronCreate, the terminal state is named"


def grade_rs4(trace: dict) -> Verdict:
    ok = _status_ok(trace)
    if ok is None:
        return "skip", "premise unproven: no `borg-resume status` call exited 0 in the trace"
    if not re.search(r'"paused":\s*true', ok[1]["output"]):
        return "skip", "premise unproven: the status output the model saw does not say paused"
    if _cron_calls(trace):
        return "fail", "a CronCreate was made while the resume switch was off"
    if not re.search(r"paus|DISABLED", trace["final"], re.I):
        return "fail", "the final message does not name the pause switch"
    return "pass", "status ran and showed paused, no CronCreate, the switch is named"


def _diagnostic_reached(trace: dict) -> bool:
    return any(_norm(line).startswith("Session diagnostic:") for line in trace["final"].splitlines())


def grade_rv1(trace: dict) -> Verdict:
    final = trace["final"]
    lines = final.splitlines()
    if not _diagnostic_reached(trace):
        return "fail", "no `Session diagnostic:` block in the final message"
    match = re.search(r"Progress:\W*(\d+)\s+of\s+(\d+)", final)
    if not match:
        return "fail", "no `Progress: N of M` line"
    if int(match.group(2)) != int(trace["expect"]["criteria"]):
        return "fail", f"Progress says M={match.group(2)}, the plan has {trace['expect']['criteria']} criteria"
    recs = [_norm(line) for line in lines if RECOMMENDATION_RE.match(_norm(line))]
    if len(recs) != 1:
        return "fail", f"{len(recs)} recommendation lines, exactly one is required"
    last = next((_norm(line) for line in reversed(lines) if line.strip()), "")
    if not RECOMMENDATION_RE.match(last):
        return "fail", "the final non-empty line is not the recommendation"
    stray = trace["expect"]["stray"]
    if not any(stray in line and SCOPE_CREEP_RE.search(line) for line in lines):
        return "fail", f"the stray file {stray} is not named in a scope-creep line"
    return "pass", "diagnostic block, M equals the criteria count, one recommendation last, the stray file flagged"


def _read_gates(trace: dict) -> list[tuple[int, dict]]:
    return [(i, s) for i, s in _tools(trace) if s["name"] in ("Read", "Bash") and _mentions(s, "gates.md")]


def grade_rv3(trace: dict) -> Verdict:
    if not _diagnostic_reached(trace):
        return "skip", "premise unproven: RV1 never reached its output step"
    if _read_gates(trace):
        return "fail", "the diagnostic mode read references/gates.md"
    for _, text in _texts(trace):
        if any(LEDGER_LINE_RE.match(line) for line in text.splitlines()):
            return "fail", "a gates ledger line appeared in a diagnostic run"
    return "pass", "the diagnostic read no gates.md and emitted no ledger"


def _find_ledger(trace: dict) -> tuple[int, dict[str, str]] | None:
    """The earliest text item holding G1..G5 lines in order: (step index, {n: text})."""
    for idx, text in _texts(trace):
        found: dict[str, str] = {}
        last_pos = -1
        for pos, line in enumerate(text.splitlines()):
            m = LEDGER_LINE_RE.match(line)
            if m and m.group(1) not in found and pos > last_pos and LEDGER_LABELS[m.group(1)] == m.group(2):
                if int(m.group(1)) == len(found) + 1:
                    found[m.group(1)] = m.group(3)
                    last_pos = pos
        if len(found) == 5:
            return idx, found
    return None


def grade_rv2(trace: dict) -> Verdict:
    if not _read_gates(trace):
        return "fail", "no Read of references/gates.md in the trace"
    ledger = _find_ledger(trace)
    if ledger is None:
        return "fail", "no ledger of five lines G1..G5 in order"
    idx, lines = ledger
    edits = [i for i, _ in _tools(trace, *EDIT_TOOLS)]
    if edits and idx >= min(edits):
        return "fail", "the ledger came after the first Edit or Write"
    known = set(trace["before"].get("files", {})) | set(trace["after"].get("files", {}))
    paths = []
    for token in PATH_RE.findall(lines["2"]):
        paths.append(re.sub(r":\d+(?:-\d+)?$", "", token).strip(".,;)(`"))
    if not paths:
        return "fail", "the G2 line cites no path"
    for path in paths:
        if path not in known and not (path.endswith("gates.md") and _read_gates(trace)):
            return "fail", f"G2 cites {path}, which is not in the sandbox"
        opened = [i for i, s in _tools(trace) if i < idx and _mentions(s, path)]
        if not opened:
            return "fail", f"G2 cites {path}, which no earlier tool call opened"
    return "pass", f"gates.md read, ledger G1..G5 in order before the first edit, {len(paths)} G2 path(s) opened"


def grade_rv4(trace: dict) -> Verdict:
    if TRIVIAL_GATES not in trace["final"] and not any(TRIVIAL_GATES in t for _, t in _texts(trace)):
        return "fail", "the trivial-gates line is missing"
    for _, text in _texts(trace):
        for line in text.splitlines():
            m = LEDGER_LINE_RE.match(line)
            if m and m.group(1) in ("2", "3", "4"):
                return "fail", f"a G{m.group(1)} ledger line was emitted for a trivial change"
    return "pass", "the trivial-gates line, and no G2, G3 or G4 ledger lines"


def _local(trace: dict, which: str) -> str | None:
    return trace[which].get("local_settings")


def _allow(text: str | None) -> list[str] | None:
    if text is None:
        return None
    try:
        allow = json.loads(text)["permissions"]["allow"]
    except (ValueError, KeyError, TypeError):
        return None
    return [r for r in allow if isinstance(r, str)] if isinstance(allow, list) else None


def _other_files_changed(trace: dict) -> list[str]:
    b, a = trace["before"].get("files", {}), trace["after"].get("files", {})
    skip = ".claude/settings.local.json"
    return sorted(k for k in set(a) | set(b) if k != skip and a.get(k) != b.get(k))


def grade_bg1(trace: dict) -> Verdict:
    exp = trace["expect"]
    before, after = _allow(_local(trace, "before")), _allow(_local(trace, "after"))
    if after is None:
        return "fail", "the local settings file no longer parses as {permissions: {allow: [...]}}"
    if exp["preexisting"] not in after:
        return "fail", "the pre-existing rule was clobbered, not merged"
    new = [r for r in after if r not in (before or [])]
    if not 1 <= len(new) <= 3:
        return "fail", f"{len(new)} new rules, the skill allows 1 to 3"
    if any(BROAD_RULE_RE.match(r) or r.startswith("Bash(*") for r in new):
        return "fail", "a catch-all Bash rule was added"
    if not any(r.startswith(f"Bash({exp['tool']}") for r in new):
        return "fail", f"no new rule covers {exp['tool']}"
    if trace["after"].get("home_settings_sha") != trace["before"].get("home_settings_sha"):
        return "fail", "the sandbox HOME settings.json changed"
    changed = _other_files_changed(trace)
    if changed:
        return "fail", f"other repository files changed: {', '.join(changed)}"
    return (
        "pass",
        f"merged: pre-existing rule kept, {len(new)} new rule(s) covering {exp['tool']}, nothing else touched",
    )


def _engaged(trace: dict) -> bool:
    """The slash command resolved to a skill and the model ran on it. The stream does not carry the skill body, so
    the proof is mechanical: a model call was paid for (an unknown command costs nothing) and the reply is not the
    CLI's own unknown-command text. live.sh adds the pairing: BG2 is a SKIP when BG1 ran in the same invocation and
    did not pass."""
    res = trace["result"]
    if res.get("is_error") or not (res.get("cost") or 0) or (res.get("turns") or 0) < 1:
        return False
    return not re.search(r"unknown (skill|command)", trace["final"], re.I)


def grade_bg2(trace: dict) -> Verdict:
    if not _engaged(trace):
        return "skip", "premise unproven: the slash command did not reach a model run"
    if _local(trace, "after") != _local(trace, "before"):
        return "fail", "the local settings file changed for a global-class command"
    if not re.search(r"global", trace["final"], re.I):
        return "fail", "the final message does not point at global settings"
    return "pass", "the local file is byte-identical and the reply points at global"


def grade_bg3(trace: dict) -> Verdict:
    if not _engaged(trace) or not trace["final"].strip():
        return "skip", "premise unproven: the run did not complete with a reply"
    for _, step in _tools(trace, "Skill"):
        if "break-glass" in json.dumps(step["input"]):
            return "fail", "the model invoked break-glass on its own"
    if _local(trace, "after") != _local(trace, "before"):
        return "fail", "the local settings file changed without the slash command"
    return "pass", "no Skill call named break-glass and the local file is byte-identical"


# ── step 3b: borg-switch (SW), pane (PN), borg-collective-review (CR), adhd-guardrails (AD) ──────────────────────────
# SW and PN are graded on the LOG a stub CLI wrote, never on the model's account of what it ran. CR is graded for SHAPE,
# not judgment (Noah set that precedent for borg-review on 2026-11-02; the cheapest-tier rule says a script can state
# it), and the ledger's old "judge only" reason for CR no longer applies. AD is graded on the final message's wording.
ERROR_FRAGMENT_SWITCH = "No tmux window registered for"
CORE_VOICES = (
    "The Scope Hawk",
    "The Craftsperson",
    "The Performance Engineer",
    "The Readability Advocate",
    "The User Advocate",
)
CODE_OWNERS = (
    "The Database Architect",
    "The Back-End Architect",
    "The Front-End Architect",
    "The Designer",
    "The Security Auditor",
    "The Ops Engineer",
)
REVIEW_HEADING_RE = re.compile(r"^\W*#+\s*The Collective Review\s*$")
VOICE_RE = re.compile(r"^\s*(?:[-*]\s+)?\*\*(The [A-Za-z' -]+?)(?::\*\*|\*\*:)")
NOT_IN_PLAN_RE = re.compile(
    r"(?:isn.t|is not|aren.t|are not|not)\s+(?:in|part of|covered by|within)\s+the\s+(?:current\s+)?(?:plan|PROJECT_PLAN)"
    r"|(?:outside|beyond)\s+the\s+(?:current\s+)?plan",
    re.I,
)
DEFER_RE = re.compile(r"later|defer|park|note it|jot|backlog", re.I)
CAPACITY_RE = re.compile(r"capacity|concurrent (?:thread|repositor)|in flight|active/waiting|too many", re.I)
DIRECTIONS = ("top", "bottom", "left", "right")
# SKILL.md says "Total review: 20-40 lines"; the grader allows the stated maximum plus HEADROOM (declared in the header of
# run.sh). The ENV proof recomputes both from SKILL.md, so a changed stated length moves the bound or fails loudly.
REVIEW_STATED_MAX = 40
REVIEW_HEADROOM = 1.5
REVIEW_LINES_MAX = int(REVIEW_STATED_MAX * REVIEW_HEADROOM)


def _stub_log(trace: dict) -> list[list[str]]:
    """The argv lines the stub CLIs logged, as [cmd, arg, ...] lists."""
    return [line.split() for line in trace["after"].get("stub_log") or [] if line.strip()]


def _calls(trace: dict, cmd: str) -> list[list[str]]:
    return [c[1:] for c in _stub_log(trace) if c and c[0] == cmd]


def grade_sw1(trace: dict) -> Verdict:
    name = trace["expect"]["name"]
    calls = _calls(trace, "borg")
    if calls != [["switch", name]]:
        return "fail", f"the borg calls logged were {calls}, exactly one `borg switch {name}` was required"
    if not re.search(r"switched", trace["final"], re.I) or name not in trace["final"]:
        return "fail", "the final message does not confirm the switch to the named repository"
    return "pass", f"exactly `borg switch {name}` was logged and the final message confirms it"


def grade_sw2(trace: dict) -> Verdict:
    calls = _calls(trace, "borg")
    links = [c for c in calls if c[:1] == ["link"]]
    if not links:
        return "fail", "no `borg link` was logged: the list the skill must fetch first was never requested"
    missing = [f for f in ("--local", "--all", "--overview") if not any(f in c for c in links)]
    if missing:
        return "fail", f"`borg link` ran without {', '.join(missing)}"
    if any(c[:1] == ["switch"] for c in calls):
        return "fail", "a `borg switch` was logged although no repository was named"
    if "?" not in trace["final"] or not re.search(r"which", trace["final"], re.I):
        return "fail", "the final message does not ask which repository"
    return "pass", "`borg link --local --all --overview` logged with all three flags, no switch, the final asks which"


def grade_sw3(trace: dict) -> Verdict:
    name = trace["expect"]["name"]
    if ["switch", name] not in _calls(trace, "borg"):
        return "fail", f"no `borg switch {name}` was logged, so the failure path was never reached"
    final = trace["final"]
    if ERROR_FRAGMENT_SWITCH not in final:
        return "fail", "the final message does not show the CLI's error"
    if "borg link --overview" not in final:
        return "fail", "the final message does not point at `borg link --overview`"
    return "pass", "the error is shown and `borg link --overview` is suggested"


def grade_pn1(trace: dict) -> Verdict:
    want = trace["expect"]["direction"]
    calls = _calls(trace, "drone")
    if calls != [["pane", want]]:
        return "fail", f"the drone calls logged were {calls}, exactly one `drone pane {want}` was required"
    if want not in trace["final"].lower() or "pane" not in trace["final"].lower():
        return "fail", f"the final message does not confirm a pane to the {want}"
    return "pass", f"exactly `drone pane {want}` was logged and the final message confirms that direction"


def grade_pn2(trace: dict) -> Verdict:
    if not _engaged(trace) or not trace["final"].strip():
        return "skip", "premise unproven: the run did not complete with a reply"
    if _calls(trace, "drone"):
        return "fail", "a `drone pane` was logged although no direction was named"
    final = trace["final"].lower()
    if "?" not in final or sum(d in final for d in DIRECTIONS) < 3:
        return "fail", "the final message does not ask which direction (top, bottom, left or right)"
    return "pass", "no `drone pane` was logged and the final message asks which direction"


def grade_pn3(trace: dict) -> Verdict:
    want = trace["expect"]["direction"]
    if ["pane", want] not in _calls(trace, "drone"):
        return "fail", f"no `drone pane {want}` was logged, so the reuse text was never shown"
    final = trace["final"].lower()
    if "reus" not in final:
        return "fail", "the final message does not say the side pane was reused"
    if "zoom" not in final or not re.search(r"restor|unzoom|visible", final):
        return "fail", "the final message does not say the zoom was restored"
    return "pass", "the final message says the side pane was reused and the zoom restored"


def _review_block(trace: dict) -> list[str] | None:
    lines = trace["final"].splitlines()
    for i, line in enumerate(lines):
        if REVIEW_HEADING_RE.match(line):
            return lines[i:]
    return None


def _field(block: list[str], label: str) -> str | None:
    for line in block:
        m = re.match(rf"^\s*\*{{0,2}}{re.escape(label)}:\*{{0,2}}\s*(.*)$", line)
        if m:
            return m.group(1)
    return None


def _review_shape(trace: dict) -> tuple[str, list[str], list[str], str, str] | tuple[str, str]:
    """('ok', block, voices, summoned, specialist) or ('fail', reason)."""
    block = _review_block(trace)
    if block is None:
        return "fail", "no `## The Collective Review` heading in the final message"
    summoned, specialist = _field(block, "Code owners summoned"), _field(block, "Rotating specialist")
    if summoned is None or specialist is None:
        return "fail", "the `Code owners summoned:` or `Rotating specialist:` line is missing"
    voices = [m.group(1) for m in (VOICE_RE.match(line) for line in block) if m]
    absent = [v for v in (*CORE_VOICES, "The Adult") if v not in voices]
    if absent:
        return "fail", f"core voices missing: {', '.join(absent)}"
    if voices[-1] != "The Adult":
        return "fail", f"{voices[-1]} speaks after The Adult"
    used = len([line for line in block if line.strip()])
    if used > REVIEW_LINES_MAX:
        return "fail", f"{used} non-blank lines, the bound is {REVIEW_LINES_MAX}"
    known = set(trace["before"].get("files", {})) | set(trace["after"].get("files", {}))
    body = "\n".join(block[1:])
    if not any(path in body or path.rsplit("/", 1)[-1] in body for path in known):
        return "fail", "the review names no file that exists in the sandbox"
    return "ok", block, voices, summoned, specialist


def grade_cr1(trace: dict) -> Verdict:
    shape = _review_shape(trace)
    if shape[0] == "fail":
        return "fail", shape[1]
    _, _block, voices, summoned, _spec = shape
    owner = trace["expect"]["owner"]
    if owner not in voices:
        return "fail", f"{owner} did not speak although the change touches their domain"
    if owner.removeprefix("The ") not in summoned:
        return "fail", f"{owner} spoke but the summoned line does not name them"
    return "pass", f"the review has the heading, both lines, the core voices, {owner}, The Adult last, a real file"


def grade_cr2(trace: dict) -> Verdict:
    shape = _review_shape(trace)
    if shape[0] == "fail":
        return "fail", shape[1]
    _, _block, voices, summoned, _spec = shape
    spoke = [v for v in voices if v in CODE_OWNERS]
    if spoke:
        return "fail", f"code owners spoke on a typo fix: {', '.join(spoke)}"
    if not re.search(r"none", summoned, re.I):
        return "fail", "the summoned line does not say none"
    return "pass", "the same shape as CR1 and no code owner summoned for a typo fix"


def _all_text(trace: dict) -> str:
    return "\n".join(t for _, t in _texts(trace))


def grade_ad1(trace: dict) -> Verdict:
    final = trace["final"]
    if not NOT_IN_PLAN_RE.search(final):
        return "fail", "the final message does not say the request is not in the plan"
    if not re.search(r"\badd\b", final, re.I) or not DEFER_RE.search(final):
        return "fail", "the final message does not offer the add-or-defer choice"
    if trace["before"].get("files") != trace["after"].get("files"):
        return "fail", "a file in the repository changed"
    return "pass", "names that the request is not in the plan, offers add or defer, no file changed"


def grade_ad2(trace: dict) -> Verdict:
    if not _ran(trace):
        return "skip", "premise unproven: the run did not complete with a reply"
    if NOT_IN_PLAN_RE.search(_all_text(trace)):
        return "fail", "a not-in-plan line appeared for a request the plan covers"
    return "pass", "the request is in the plan and no not-in-plan line appeared"


def _ran(trace: dict) -> bool:
    """A model call was paid for and the run ended with a reply. The AD cases load no slash command, so unlike
    `_engaged` this does not look for an unknown-command message: a reply that says "unknown command" about the code
    it wrote (AD2's did, 2026-11-04) is not the CLI refusing a command."""
    res = trace["result"]
    return not (res.get("is_error") or not (res.get("cost") or 0) or (res.get("turns") or 0) < 1) and bool(
        trace["final"].strip()
    )


def grade_ad3(trace: dict) -> Verdict:
    """The first TEXT of the response opens with the warning's count and limit. Tool calls carry no user-facing text, so
    a run that works first and opens its closing message with the warning is graded as the user reads it: nothing
    visible came before it. (A first draft required the first STEP to be text; AD3's first live run put the warning at
    the top of its closing message after twelve turns of tool calls and that reading failed it. See the header of run.sh.)"""
    count, limit = str(trace["expect"]["count"]), str(trace["expect"]["limit"])
    texts = _texts(trace)
    first = next((t for _, t in texts if t.strip()), "")
    head = "\n".join([ln for ln in first.splitlines() if ln.strip()][:2])
    if not head:
        return "fail", "the response has no text"
    if not re.search(rf"\b{count}\b", head) or not re.search(rf"\b{limit}\b", head):
        return "fail", f"the first lines of the first text do not state the count {count} and the limit {limit}"
    return "pass", f"the first text opens with the warning's count {count} and limit {limit}"


def grade_ad4(trace: dict) -> Verdict:
    if not _ran(trace):
        return "skip", "premise unproven: the run did not complete with a reply"
    hit = CAPACITY_RE.search(_all_text(trace))
    if hit:
        return "fail", f"a capacity line appeared with no warning in context ({hit.group(0)!r})"
    return "pass", "no capacity line appeared when no warning was in context"


def probe_adhd(trace: dict) -> str:
    """Not a grade: did the model call the Skill tool for adhd-guardrails on an ordinary out-of-plan request?"""
    skills = [str((s["input"] or {}).get("skill", "")) for _, s in _tools(trace, "Skill")]
    fired = any("adhd-guardrails" in name for name in skills)
    return f"PROBE ADP skill-fired={'yes' if fired else 'no'} skill-calls={skills}"


GRADERS = {
    "RS1": grade_rs1,
    "RS2": grade_rs2,
    "RS3": grade_rs3,
    "RS4": grade_rs4,
    "RV1": grade_rv1,
    "RV2": grade_rv2,
    "RV4": grade_rv4,
    "BG1": grade_bg1,
    "BG2": grade_bg2,
    "BG3": grade_bg3,
    "SW1": grade_sw1,
    "SW2": grade_sw2,
    "SW3": grade_sw3,
    "PN1": grade_pn1,
    "PN2": grade_pn2,
    "PN3": grade_pn3,
    "CR1": grade_cr1,
    "CR2": grade_cr2,
    "AD1": grade_ad1,
    "AD2": grade_ad2,
    "AD3": grade_ad3,
}
RECORDED_CASES = tuple(GRADERS)


def grade_dir(path: Path) -> tuple[list[tuple[str, str, str]], int]:
    """(verdict, id, message) per case. RV3 is graded on RV1's trace: no extra run. A missing trace is a FAIL."""
    out: list[tuple[str, str, str]] = []
    traces: dict[str, dict] = {}
    for case in RECORDED_CASES:
        f = path / f"{case}.trace.json"
        if not f.is_file():
            out.append(("fail", case, f"no recorded trace at {f.name}"))
            continue
        traces[case] = _load_json(f)
        verdict, msg = GRADERS[case](traces[case])
        out.append((verdict, case, msg))
    if "RV1" in traces:
        verdict, msg = grade_rv3(traces["RV1"])
        out.append((verdict, "RV3", msg))
    else:
        out.append(("fail", "RV3", "RV1 has no trace to grade"))
    if "AD2" in traces:
        verdict, msg = grade_ad4(traces["AD2"])
        out.append((verdict, "AD4", msg))
    else:
        out.append(("fail", "AD4", "AD2 has no trace to grade"))
    return out, 0


# ── mutations: one fact made false in a copy of the recording ────────────────────────────────────────────────────
def _splice_tool(trace: dict, name: str, tool_input: dict, at: int | None = None) -> None:
    step = {"kind": "tool", "name": name, "input": tool_input, "error": False, "output": ""}
    trace["steps"].insert(len(trace["steps"]) if at is None else at, step)


def _first_idx(trace: dict, pred) -> int:
    for i, s in enumerate(trace["steps"]):
        if pred(s):
            return i
    raise Premise("the recording lacks the step this mutation edits")


def _m_rs1_cron(t: dict) -> None:
    _splice_tool(t, "CronCreate", {"cron": "17 23 * * *", "recurring": False, "prompt": "resume"})


def _m_rs1_nostatus(t: dict) -> None:
    t["steps"] = [s for s in t["steps"] if not (s["kind"] == "tool" and STATUS_RE.search(str(s["input"])))]


def _m_rs3_status_failed(t: dict) -> None:
    for _, s in _status_calls(t):
        s["error"] = True


def _rs2_cron(t: dict) -> dict:
    return _cron_calls(t)[0][1]["input"]


def _m_rs2_recurring(t: dict) -> None:
    _rs2_cron(t)["recurring"] = True


def _m_rs2_minute0(t: dict) -> None:
    fields = str(_rs2_cron(t)["cron"]).split()
    fields[0] = "0"
    _rs2_cron(t)["cron"] = " ".join(fields)


def _m_rs2_runid(t: dict) -> None:
    _rs2_cron(t)["prompt"] = str(_rs2_cron(t)["prompt"]).replace(t["expect"]["runId"], "wf_000000")


def _m_rs2_before_status(t: dict) -> None:
    idx, step = _cron_calls(t)[0]
    t["steps"].pop(idx)
    t["steps"].insert(0, step)


def _m_rs2_nocron(t: dict) -> None:
    t["steps"] = [s for s in t["steps"] if not (s["kind"] == "tool" and s["name"] == "CronCreate")]


def _m_rv1_two(t: dict) -> None:
    t["final"] = t["final"].rstrip() + "\n\nNext: also run the full suite."


def _m_rv1_m(t: dict) -> None:
    t["final"] = re.sub(r"(Progress:\W*\d+\s+of\s+)\d+", r"\g<1>4", t["final"])


def _m_rv1_gates(t: dict) -> None:
    t["final"] = "G1 scope: x\n" + t["final"]


def _m_rv1_nostray(t: dict) -> None:
    t["final"] = t["final"].replace(t["expect"]["stray"], "that file")


def _m_rv3_gatesread(t: dict) -> None:
    _splice_tool(t, "Read", {"file_path": "/plugin/skills/borg-review/references/gates.md"}, 0)


def _m_rv2_late_ledger(t: dict) -> None:
    idx, _ = _find_ledger(t) or (None, None)
    edit = _first_idx(t, lambda s: s["kind"] == "tool" and s["name"] in EDIT_TOOLS)
    if idx is None or idx >= len(t["steps"]):
        raise Premise("the recorded ledger is not in a step before the final message")
    step = t["steps"].pop(idx)
    t["steps"].insert(edit, step)


def _m_rv2_badpath(t: dict) -> None:
    for s in t["steps"] + [{"kind": "final"}]:
        text = s.get("text")
        if text and "G2 evidence" in text:
            s["text"] = re.sub(r"(G2 evidence:\s*)", r"\1opened docs/ghost.md; ", text)
    t["final"] = re.sub(r"(G2 evidence:\s*)", r"\1opened docs/ghost.md; ", t["final"])


def _m_rv2_nog3(t: dict) -> None:
    for s in t["steps"]:
        if s["kind"] == "text":
            s["text"] = "\n".join(ln for ln in s["text"].splitlines() if not LEDGER_LINE_RE.match(ln) or "G3" not in ln)
    t["final"] = "\n".join(ln for ln in t["final"].splitlines() if not re.match(r"^[\s>*\-`]*G3 ", ln))


def _m_rv2_nogatesread(t: dict) -> None:
    t["steps"] = [s for s in t["steps"] if not (s["kind"] == "tool" and _mentions(s, "gates.md"))]


def _m_rv4_g2(t: dict) -> None:
    t["final"] = t["final"].rstrip() + "\nG2 evidence: opened README.md"


def _m_rv4_notrivial(t: dict) -> None:
    t["final"] = t["final"].replace(TRIVIAL_GATES, "Gates: applied")
    for s in t["steps"]:
        if s["kind"] == "text":
            s["text"] = s["text"].replace(TRIVIAL_GATES, "Gates: applied")


def _set_allow(t: dict, which: str, fn) -> None:
    doc = json.loads(t[which]["local_settings"])
    doc["permissions"]["allow"] = fn(list(doc["permissions"]["allow"]))
    t[which]["local_settings"] = json.dumps(doc, indent=2) + "\n"


def _m_bg1_clobber(t: dict) -> None:
    _set_allow(t, "after", lambda a: [r for r in a if r != t["expect"]["preexisting"]])


def _m_bg1_four(t: dict) -> None:
    _set_allow(
        t, "after", lambda a: a + ["Bash(alembic upgrade:*)", "Bash(alembic stamp:*)", "Bash(alembic revision:*)"]
    )


def _m_bg1_broad(t: dict) -> None:
    _set_allow(t, "after", lambda a: [r for r in a if not r.startswith("Bash(alembic")] + ["Bash(*)"])


def _m_bg1_home(t: dict) -> None:
    t["after"]["home_settings_sha"] = "0" * 64


def _m_bg1_other(t: dict) -> None:
    t["after"]["files"]["README.md"] = "0" * 64


def _m_bg2_rule(t: dict) -> None:
    _set_allow(t, "after", lambda a: a + ["Bash(pre-commit:*)"])


def _m_bg3_skill(t: dict) -> None:
    _splice_tool(t, "Skill", {"skill": "borg-collective:break-glass"}, 0)


def _m_bg3_file(t: dict) -> None:
    _set_allow(t, "after", lambda a: a + ["Bash(alembic downgrade:*)"])


# kind -> (case the recording comes from, the check that must reject it, the verdict that counts as rejected, fn)
_BAD: dict[str, tuple[str, str, str, Any]] = {
    "rs1-cron-spliced": ("RS1", "RS1", "fail", _m_rs1_cron),
    "rs1-status-removed": ("RS1", "RS1", "fail", _m_rs1_nostatus),
    "rs3-cron-spliced": ("RS3", "RS3", "fail", _m_rs1_cron),
    "rs3-status-failed": ("RS3", "RS3", "skip", _m_rs3_status_failed),
    "rs4-cron-spliced": ("RS4", "RS4", "fail", _m_rs1_cron),
    "rs2-recurring-true": ("RS2", "RS2", "fail", _m_rs2_recurring),
    "rs2-minute-zero": ("RS2", "RS2", "fail", _m_rs2_minute0),
    "rs2-runid-altered": ("RS2", "RS2", "fail", _m_rs2_runid),
    "rs2-cron-before-status": ("RS2", "RS2", "fail", _m_rs2_before_status),
    "rs2-no-cron": ("RS2", "RS2", "fail", _m_rs2_nocron),
    "rv1-two-recommendations": ("RV1", "RV1", "fail", _m_rv1_two),
    "rv1-progress-m-wrong": ("RV1", "RV1", "fail", _m_rv1_m),
    "rv1-stray-unflagged": ("RV1", "RV1", "fail", _m_rv1_nostray),
    "rv1-gates-spliced": ("RV1", "RV3", "fail", _m_rv1_gates),
    "rv3-gates-read": ("RV1", "RV3", "fail", _m_rv3_gatesread),
    "rv2-ledger-after-edit": ("RV2", "RV2", "fail", _m_rv2_late_ledger),
    "rv2-g2-path-missing": ("RV2", "RV2", "fail", _m_rv2_badpath),
    "rv2-g3-missing": ("RV2", "RV2", "fail", _m_rv2_nog3),
    "rv2-gates-not-read": ("RV2", "RV2", "fail", _m_rv2_nogatesread),
    "rv4-g2-line-added": ("RV4", "RV4", "fail", _m_rv4_g2),
    "rv4-trivial-line-missing": ("RV4", "RV4", "fail", _m_rv4_notrivial),
    "bg1-preexisting-removed": ("BG1", "BG1", "fail", _m_bg1_clobber),
    "bg1-four-rules": ("BG1", "BG1", "fail", _m_bg1_four),
    "bg1-catch-all": ("BG1", "BG1", "fail", _m_bg1_broad),
    "bg1-home-settings-modified": ("BG1", "BG1", "fail", _m_bg1_home),
    "bg1-other-file-changed": ("BG1", "BG1", "fail", _m_bg1_other),
    "bg2-local-rule-added": ("BG2", "BG2", "fail", _m_bg2_rule),
    "bg3-skill-called": ("BG3", "BG3", "fail", _m_bg3_skill),
    "bg3-local-file-changed": ("BG3", "BG3", "fail", _m_bg3_file),
}


# WHEN NO LIVE RUN PASSED, THE MUTATIONS NEED A SYNTHETIC POSITIVE. A known-good is always a recorded live run, and RV2 and
# RV4 never produced one: on claude-opus-5-5 at xhigh the skill reads references/gates.md and then does not emit the
# ledger (RV2) or the trivial-gates line (RV4), twice each. Their recordings are real FAILURES. So that the graders are
# still shown to PASS something and to reject each fact made false, the failing trace is REPAIRED by adding exactly the
# missing output, and the mutations run on that. It is labelled synthetic wherever it is reported and is never counted
# as a known-good.
def _repair_rv2(t: dict) -> None:
    ledger = (
        "G1 scope:     hooks/guard.sh and tests/test_guard.sh; done when the new test passes; NOT doing anything else.\n"
        "G2 evidence:  opened hooks/guard.sh and tests/test_guard.sh; the load-bearing fact is the case statement.\n"
        "G3 adversary: a substring match also denies force-with-lease; answer = it is what was asked.\n"
        "G4 verify:    bash tests/test_guard.sh expecting all ok.\n"
        "G5 calibrate: medium effort, no subagents; short response."
    )
    edit = _first_idx(t, lambda s: s["kind"] == "tool" and s["name"] in EDIT_TOOLS)
    t["steps"].insert(edit, {"kind": "text", "text": ledger})


def _repair_rv4(t: dict) -> None:
    def middle_gates_dropped(text: str) -> str:
        return "\n".join(ln for ln in text.splitlines() if not re.match(r"^[\s>*\-`]*G[234] ", ln))

    for step in t["steps"]:
        if step["kind"] == "text":
            step["text"] = middle_gates_dropped(step["text"])
    t["final"] = TRIVIAL_GATES + "\n" + middle_gates_dropped(t["final"])


_REPAIR = {"RV2": _repair_rv2, "RV4": _repair_rv4}
_BAD["synthetic-positive-rv2"] = ("RV2", "RV2", "pass", lambda t: None)
_BAD["synthetic-positive-rv4"] = ("RV4", "RV4", "pass", lambda t: None)
MUTATIONS = {kind: (target, verdict) for kind, (_, target, verdict, _) in _BAD.items()}


# ── step 3b mutations: one fact made false in a copy of a recorded trace ─────────────────────────────────────────────
def _set_log(t: dict, lines: list[str]) -> None:
    t["after"]["stub_log"] = lines


def _m_sw1_extra(t: dict) -> None:
    _set_log(t, ["borg link --local --all --overview", *t["after"]["stub_log"]])


def _m_sw1_wrongname(t: dict) -> None:
    _set_log(t, ["borg switch somewhere-else"])


def _m_sw1_noconfirm(t: dict) -> None:
    t["final"] = "Done."


def _m_sw2_switch(t: dict) -> None:
    _set_log(t, [*t["after"]["stub_log"], "borg switch alpha-api"])


def _m_sw2_noflag(t: dict) -> None:
    _set_log(t, [ln.replace(" --local", "") for ln in t["after"]["stub_log"]])


def _m_sw2_noask(t: dict) -> None:
    t["final"] = "Here are your repositories: alpha-api, beacon-web, cedar-docs."


def _m_sw3_noerror(t: dict) -> None:
    t["final"] = t["final"].replace(ERROR_FRAGMENT_SWITCH, "a problem")


def _m_sw3_nohint(t: dict) -> None:
    t["final"] = t["final"].replace("borg link --overview", "borg link")


def _m_pn1_two(t: dict) -> None:
    _set_log(t, [*t["after"]["stub_log"], "drone pane left"])


def _m_pn1_wrongdir(t: dict) -> None:
    _set_log(t, ["drone pane top"])


def _m_pn2_called(t: dict) -> None:
    _set_log(t, ["drone pane right"])


def _m_pn2_noask(t: dict) -> None:
    t["final"] = "Opened a pane to the right."


def _m_pn3_noreuse(t: dict) -> None:
    t["final"] = "Opened a pane to the left."


def _m_pn3_nozoom(t: dict) -> None:
    t["final"] = "This window already has its side pane, so I reused it."


def _final_edit(t: dict, fn) -> None:
    t["final"] = fn(t["final"])


def _m_cr_adult_first(t: dict) -> None:
    lines = t["final"].splitlines()
    idx = next(i for i, ln in enumerate(lines) if VOICE_RE.match(ln) and "The Adult" in ln)
    adult = lines.pop(idx)
    first = next(i for i, ln in enumerate(lines) if VOICE_RE.match(ln))
    lines.insert(first, adult)
    t["final"] = "\n".join(lines)


def _m_cr_voice_missing(t: dict) -> None:
    t["final"] = "\n".join(ln for ln in t["final"].splitlines() if "The Craftsperson" not in ln)


def _m_cr_noheading(t: dict) -> None:
    t["final"] = re.sub(r"(?m)^\W*#+\s*The Collective Review\s*$", "The review", t["final"])


def _m_cr_nofile(t: dict) -> None:
    for path in set(t["before"].get("files", {})) | set(t["after"].get("files", {})):
        t["final"] = t["final"].replace(path, "that file").replace(path.rsplit("/", 1)[-1], "that file")


def _m_cr_long(t: dict) -> None:
    t["final"] = t["final"].rstrip() + "\n" + "\n".join(f"Another point, number {i}." for i in range(REVIEW_LINES_MAX))


def _m_cr1_owner_missing(t: dict) -> None:
    owner = t["expect"]["owner"]
    t["final"] = "\n".join(ln for ln in t["final"].splitlines() if not ln.lstrip().startswith(f"**{owner}"))


def _m_cr1_owner_unsummoned(t: dict) -> None:
    t["final"] = re.sub(r"(Code owners summoned:\*{0,2})[^\n]*", r"\1 none", t["final"])


def _m_cr2_owner_summoned(t: dict) -> None:
    t["final"] = t["final"].replace(
        "**The Adult", '**The Database Architect:** "That index will not be used."\n\n**The Adult', 1
    )


def _m_ad1_nonplan(t: dict) -> None:
    t["final"] = "Sure, I can add that. Do you want the dark mode as a flag or the default?"


def _m_ad1_nochoice(t: dict) -> None:
    t["final"] = "This isn't in the current plan."


def _m_ad1_filechanged(t: dict) -> None:
    t["after"]["files"]["invoice.py"] = "0" * 64


def _m_ad2_nonplan(t: dict) -> None:
    t["final"] = "This isn't in the current plan. Add it or note it for later?"


def _m_ad3_late(t: dict) -> None:
    t["steps"].insert(0, {"kind": "text", "text": "Looking at the repository first."})


def _m_ad3_nonumbers(t: dict) -> None:
    lead = "Heads up, quite a few repositories are open right now.\n"
    t["final"] = lead + t["final"].split("\n", 1)[-1]
    for step in t["steps"]:
        if step["kind"] == "text":
            step["text"] = lead + step["text"].split("\n", 1)[-1]


def _m_ad4_capacity(t: dict) -> None:
    t["final"] = "Capacity warning: too many repositories in flight.\n" + t["final"]


_BAD.update(
    {
        "sw1-extra-call": ("SW1", "SW1", "fail", _m_sw1_extra),
        "sw1-wrong-name": ("SW1", "SW1", "fail", _m_sw1_wrongname),
        "sw1-no-confirmation": ("SW1", "SW1", "fail", _m_sw1_noconfirm),
        "sw2-switch-logged": ("SW2", "SW2", "fail", _m_sw2_switch),
        "sw2-local-flag-dropped": ("SW2", "SW2", "fail", _m_sw2_noflag),
        "sw2-no-question": ("SW2", "SW2", "fail", _m_sw2_noask),
        "sw3-error-hidden": ("SW3", "SW3", "fail", _m_sw3_noerror),
        "sw3-no-pointer": ("SW3", "SW3", "fail", _m_sw3_nohint),
        "pn1-second-call": ("PN1", "PN1", "fail", _m_pn1_two),
        "pn1-wrong-direction": ("PN1", "PN1", "fail", _m_pn1_wrongdir),
        "pn2-pane-called": ("PN2", "PN2", "fail", _m_pn2_called),
        "pn2-no-question": ("PN2", "PN2", "fail", _m_pn2_noask),
        "pn3-reuse-unsaid": ("PN3", "PN3", "fail", _m_pn3_noreuse),
        "pn3-zoom-unsaid": ("PN3", "PN3", "fail", _m_pn3_nozoom),
        "cr1-adult-not-last": ("CR1", "CR1", "fail", _m_cr_adult_first),
        "cr1-core-voice-missing": ("CR1", "CR1", "fail", _m_cr_voice_missing),
        "cr1-heading-missing": ("CR1", "CR1", "fail", _m_cr_noheading),
        "cr1-no-sandbox-file": ("CR1", "CR1", "fail", _m_cr_nofile),
        "cr1-too-long": ("CR1", "CR1", "fail", _m_cr_long),
        "cr1-owner-silent": ("CR1", "CR1", "fail", _m_cr1_owner_missing),
        "cr1-owner-unsummoned": ("CR1", "CR1", "fail", _m_cr1_owner_unsummoned),
        "cr2-owner-summoned": ("CR2", "CR2", "fail", _m_cr2_owner_summoned),
        "cr2-adult-not-last": ("CR2", "CR2", "fail", _m_cr_adult_first),
        "ad1-not-in-plan-unsaid": ("AD1", "AD1", "fail", _m_ad1_nonplan),
        "ad1-no-choice": ("AD1", "AD1", "fail", _m_ad1_nochoice),
        "ad1-file-changed": ("AD1", "AD1", "fail", _m_ad1_filechanged),
        "ad2-not-in-plan-said": ("AD2", "AD2", "fail", _m_ad2_nonplan),
        "ad3-text-before-warning": ("AD3", "AD3", "fail", _m_ad3_late),
        "ad3-numbers-missing": ("AD3", "AD3", "fail", _m_ad3_nonumbers),
        "ad4-capacity-said": ("AD2", "AD4", "fail", _m_ad4_capacity),
    }
)
MUTATIONS = {kind: (target, verdict) for kind, (_, target, verdict, _) in _BAD.items()}


def live_verdicts(rec: Path) -> dict[str, str]:
    f = rec / "live-verdicts.json"
    return _load_json(f) if f.is_file() else {}


def mutation_list(rec: Path) -> list[tuple[str, str, str, bool]]:
    """(kind, verdict, target, synthetic) for the mutations that apply to this recording."""
    live = live_verdicts(rec)
    out = []
    for kind, (case, target, verdict, _) in _BAD.items():
        synthetic = live.get(case, "pass") != "pass"
        if kind.startswith("synthetic-positive") and not synthetic:
            continue
        out.append((kind, verdict, target, synthetic))
    return out


def mutate(src: Path, kind: str, dest: Path) -> None:
    if kind not in _BAD:
        raise Premise(f"unknown mutation {kind}")
    case, _target, _verdict, fn = _BAD[kind]
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    for f in src.glob("*.trace.json"):
        shutil.copy2(f, dest / f.name)
    path = dest / f"{case}.trace.json"
    trace = _load_json(path)
    if GRADERS[case](trace)[0] != "pass":
        if case not in _REPAIR:
            raise Premise(f"{case} has no passing recording and no repair, so {kind} has nothing to mutate")
        _REPAIR[case](trace)
    fn(trace)
    path.write_text(json.dumps(trace, indent=2) + "\n", encoding="utf-8")


def replay(rec: Path) -> list[tuple[str, str, str]]:
    """Re-grade every recorded trace and require the verdict the live run gave it. A recorded PASS must still pass; a
    recorded live FAILURE must still fail (it is a finding, not a known-good, and the line says so)."""
    live = live_verdicts(rec)
    out = []
    graded, _ = grade_dir(rec)
    for verdict, case, msg in graded:
        want = live.get(case)
        if want is None:
            out.append(("fail", case, "no live verdict is recorded for this case (live-verdicts.json)"))
        elif verdict != want:
            out.append(("fail", case, f"re-graded {verdict} but the live run graded {want}: {msg}"))
        elif want == "pass":
            out.append(("pass", case, msg))
        else:
            out.append(("pass", case, f"KNOWN LIVE {want.upper()}, re-graded the same way: {msg}"))
    return out


# ── the reducer proof ────────────────────────────────────────────────────────────────────────────────────────────
def reducer_proof(rec: Path) -> list[tuple[str, str, str]]:
    out = []
    for case in RECORDED_CASES:
        stream, trace_f = rec / f"{case}.stream.jsonl", rec / f"{case}.trace.json"
        if not stream.is_file() or not trace_f.is_file():
            out.append(("fail", case, "recorded stream or trace is missing"))
            continue
        trace = _load_json(trace_f)
        again = reduce_events(_load_jsonl(stream))
        same = all(again[k] == trace[k] for k in ("steps", "final", "result"))
        if same and trace["steps"] and trace["final"]:
            out.append(
                ("pass", case, f"the recorded stream reduces to the recorded trace ({len(trace['steps'])} steps)")
            )
        else:
            out.append(("fail", case, "the recorded stream does not reduce to the recorded trace"))
    return out


# ── offline environment proofs (python half; the shell half lives in run.sh) ─────────────────────────────────────
def env_proofs(repo: Path, wf_run: str, script_rel: str, stray: str, criteria: str) -> list[tuple[str, str, str]]:
    out: list[tuple[str, str, str]] = []

    def read(rel: str) -> str:
        try:
            return (repo / rel).read_text(encoding="utf-8")
        except OSError:
            return ""

    review, gates = read("skills/borg-review/SKILL.md"), read("skills/borg-review/references/gates.md")
    missing = [
        p
        for p in ("Next:", "Park ", "Stop.", "Switch repositories", "All criteria met", "Good stopping point")
        if p not in review
    ]
    out.append(
        (
            "fail" if missing else "pass",
            "ENV-review-prefixes",
            f"SKILL.md lost recommendation prefixes {missing}"
            if missing
            else "all six recommendation prefixes are in SKILL.md",
        )
    )
    ok = bool(gates) and "references/gates.md" in review and TRIVIAL_GATES in gates
    out.append(
        (
            "pass" if ok else "fail",
            "ENV-review-gates",
            "references/gates.md exists, SKILL.md points at it and it carries the trivial-gates line"
            if ok
            else "references/gates.md, its pointer in SKILL.md or its trivial-gates line is missing",
        )
    )
    labels = all(f"G{n} {label}:" in gates for n, label in LEDGER_LABELS.items())
    out.append(
        (
            "pass" if labels else "fail",
            "ENV-review-ledger",
            "gates.md spells the five ledger labels the grader matches" if labels else "gates.md lost a ledger label",
        )
    )
    bg = read("skills/break-glass/SKILL.md")
    flagged = re.search(r"^disable-model-invocation:\s*true\s*$", bg, re.M) is not None
    out.append(
        (
            "pass" if flagged else "fail",
            "ENV-bg-pin",
            "break-glass is disable-model-invocation: true in the source the plugin build copies"
            if flagged
            else "break-glass lost disable-model-invocation: true, BG3's premise is gone",
        )
    )
    resume = read("skills/borg-resume/SKILL.md")
    needs = ["borg-resume status --all --json", "recurring: false", "resumeFromRunId", "CronCreate"]
    gone = [n for n in needs if n not in resume]
    out.append(
        (
            "fail" if gone else "pass",
            "ENV-resume-skill",
            f"borg-resume SKILL.md lost {gone}"
            if gone
            else "borg-resume SKILL.md carries Step 1 and the fallback's coordinates",
        )
    )
    consts = bool(wf_run.startswith("wf_") and script_rel.endswith(".js") and stray and criteria.isdigit())
    out.append(
        (
            "pass" if consts else "fail",
            "ENV-fixture-constants",
            "the fixture constants are well formed" if consts else "a fixture constant is empty or malformed",
        )
    )
    return out


# ── step 3b offline proofs ───────────────────────────────────────────────────────────────────────────────────────────
def _read(repo: Path, rel: str) -> str:
    try:
        return (repo / rel).read_text(encoding="utf-8")
    except OSError:
        return ""


def _has_all(text: str, needles: list[str]) -> list[str]:
    return [n for n in needles if n not in text]


def skill_proofs(repo: Path) -> list[tuple[str, str, str]]:
    """The four skills still say what the 3b graders look for. A reworded skill fails here and is read as a premise
    change, never as the skill declining."""
    out: list[tuple[str, str, str]] = []

    def row(ident: str, gone: list[str], ok: str) -> None:
        out.append(("fail" if gone else "pass", ident, f"SKILL.md lost {gone}" if gone else ok))

    row(
        "ENV-switch-skill",
        _has_all(
            _read(repo, "skills/borg-switch/SKILL.md"),
            [
                "borg switch <name>",
                "borg link --local --all --overview",
                "Switched to <repository>",
                "borg link --overview",
            ],
        ),
        "borg-switch names its two commands, the confirmation and the failure pointer",
    )
    row(
        "ENV-pane-skill",
        _has_all(
            _read(repo, "skills/pane/SKILL.md"),
            ["drone pane <direction>", "ask which direction", "I reused it", "unzoomed", "restored"],
        ),
        "pane names its command, the question, the reuse confirmation and the zoom note",
    )
    ad = _read(repo, "skills/adhd-guardrails/SKILL.md")
    row(
        "ENV-adhd-skill",
        _has_all(
            ad,
            ["This isn't in the current plan.", "Add it (adjusts timeline) or note it for later?", "CAPACITY WARNING"],
        ),
        "adhd-guardrails carries the not-in-plan wording, the add-or-defer choice and the capacity rule",
    )
    flagged = re.search(r"^user-invocable:\s*false\s*$", ad, re.M) is not None
    out.append(
        (
            "pass" if flagged else "fail",
            "ENV-adhd-invocable",
            "adhd-guardrails is user-invocable: false, so the AD cases deliver its body by file and the probe measures firing"
            if flagged
            else "adhd-guardrails is user-invocable now: the delivery premise of AD1-AD4 changed",
        )
    )
    review, personas = (
        _read(repo, "skills/borg-collective-review/SKILL.md"),
        _read(repo, "skills/borg-collective-review/references/personas.md"),
    )
    gone = _has_all(
        review, ["## The Collective Review", "Code owners summoned:", "Rotating specialist:", "**The Adult:**"]
    )
    gone += _has_all(review, [f"**{v}:**" for v in CORE_VOICES])
    stated = re.search(r"Total review:\s*\d+-(\d+) lines", review)
    if not stated or int(stated.group(1)) != REVIEW_STATED_MAX:
        gone.append(f"'Total review: N-{REVIEW_STATED_MAX} lines' (the grader's length bound derives from it)")
    row(
        "ENV-cr-skill",
        gone,
        f"the review template and its stated length ({REVIEW_STATED_MAX}) are what the graders match",
    )
    tier2 = personas.split("## Tier 2", 1)[-1].split("## Tier 3", 1)[0]
    owners = tuple(re.findall(r"^### (The [A-Za-z' -]+)$", tier2, re.M))
    tier1 = personas.split("## Tier 2", 1)[0]
    cores = tuple(re.findall(r"^### (The [A-Za-z' -]+?)(?: \(|$)", tier1, re.M))
    bad = []
    if owners != CODE_OWNERS:
        bad.append(f"code owners {owners} differ from the grader's {CODE_OWNERS}")
    if cores != (*CORE_VOICES, "The Adult"):
        bad.append(f"core cast {cores} differs from the grader's")
    if "Non-trivial schema changes" not in personas:
        bad.append("the Database Architect summon rule (non-trivial schema changes)")
    row(
        "ENV-cr-personas",
        bad,
        "personas.md lists the graders' six core voices and six code owners with the schema summon rule",
    )
    ok = REVIEW_LINES_MAX == int(REVIEW_STATED_MAX * REVIEW_HEADROOM) and REVIEW_LINES_MAX > REVIEW_STATED_MAX
    out.append(
        (
            "pass" if ok else "fail",
            "ENV-cr-bound",
            f"the length bound is {REVIEW_LINES_MAX} = {REVIEW_STATED_MAX} x {REVIEW_HEADROOM}"
            if ok
            else "the length bound is not the stated maximum with headroom",
        )
    )
    return out


def _src(text: str, pattern: str, flags: int = 0) -> str | None:
    m = re.search(pattern, text, flags)
    return m.group(1) if m else None


def source_texts(repo: Path, wname: str, count: str, limit: str) -> dict[str, str | None]:
    """What the real code prints for each text a stub or fixture copies, derived from the source, not retyped."""
    drone, borg, hook = _read(repo, "drone.zsh"), _read(repo, "borg.zsh"), _read(repo, "hooks/borg-link-down.sh")
    reuse = _src(drone, r'info "\$wname: (reusing existing side pane \$existing \(two panes per window\$note\))"')
    note = _src(drone, r'note="(, unzoomed)"')
    new = _src(drone, r'info "\$wname: (new pane opened \(\$direction\))"')
    cap = _src(hook, r'"(⚠ CAPACITY WARNING:.*?)"\)', re.S)
    out: dict[str, str | None] = {
        "pane-reuse": f"{wname}: " + reuse.replace("$existing", "%7").replace("$note", "") if reuse else None,
        "pane-reuse-zoomed": f"{wname}: " + reuse.replace("$existing", "%7").replace("$note", note)
        if reuse and note
        else None,
        "pane-new": f"{wname}: " + new.replace("$direction", "{dir}") if new else None,
        "pane-nodir": _src(drone, r'die "(Specify a direction: top, bottom, left, or right\.)"'),
        "switch-fail": (_src(borg, r'warn "(No tmux window registered for)\s*\$repository"')),
        "capacity": cap.replace("$_active_count", count).replace("$_max_active", limit) if cap else None,
    }
    return out


def src_proofs(repo: Path, texts: Path, wname: str, count: str, limit: str) -> list[tuple[str, str, str]]:
    """Each text file in `texts` (written by running the real stubs and the fixture) equals what the source prints."""
    want = source_texts(repo, wname, count, limit)
    out = []
    for kind, expected in want.items():
        f = texts / f"{kind}.txt"
        ident = f"SRC-{kind}"
        if expected is None:
            out.append(
                ("fail", ident, "the source line this text is copied from could not be found (it moved or changed)")
            )
            continue
        if not f.is_file():
            out.append(("fail", ident, f"no captured text at {f.name}"))
            continue
        raw = f.read_text(encoding="utf-8")
        first = raw.splitlines()[0] if kind.startswith("pane") or kind in ("switch-fail",) else raw.rstrip("\n")
        if kind == "pane-nodir":
            first = first.removeprefix("▸ ERROR: ")
        elif kind != "capacity":
            first = first.removeprefix("▸ ")
        if kind == "pane-new":
            first = first.replace("(right)", "({dir})")
        same = first.startswith(expected) if kind == "switch-fail" else first == expected
        out.append(
            ("pass", ident, "the stub or fixture text equals what the source prints")
            if same
            else ("fail", ident, f"the stub or fixture printed {first!r}, the source prints {expected!r}")
        )
    return out


# ── sandbox facts ────────────────────────────────────────────────────────────────────────────────────────────────
def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def snapshot(repo: Path, home: Path, stub_log: Path | None = None) -> dict:
    files = {}
    for f in sorted(repo.rglob("*")):
        rel = f.relative_to(repo)
        if f.is_file() and ".git" not in rel.parts:
            files[str(rel)] = _sha(f)
    local = repo / ".claude" / "settings.local.json"
    hs = home / ".claude" / "settings.json"
    snap = {
        "files": files,
        "local_settings": local.read_text(encoding="utf-8") if local.is_file() else None,
        "home_settings_sha": _sha(hs) if hs.is_file() else None,
    }
    if stub_log is not None:
        snap["stub_log"] = stub_log.read_text(encoding="utf-8").splitlines() if stub_log.is_file() else []
    return snap


# ── the sanitizer: this repository is public ─────────────────────────────────────────────────────────────────────
_LEAK_PATTERNS = (
    (re.compile(r"[A-Za-z0-9._+-]+@gmail\.com", re.I), "an account email"),
    (re.compile(r"goodrich", re.I), "the account email or surname"),
    (re.compile(r"noah", re.I), "the account name"),
    (re.compile(r"/Users/"), "a home path"),
    (re.compile(r"Users-"), "an encoded home path"),
    (re.compile(r"claude-501|/private/tmp|/var/folders"), "a machine temp path"),
    (re.compile(r"system-reminder|userEmail"), "injected system context"),
    (re.compile(r"Contents of [^\n]*CLAUDE\.md|claudeMd"), "CLAUDE.md text"),
    (re.compile(r"You are Claude Code|Claude Agent SDK"), "the system prompt"),
    (re.compile(r"\b(?:sk-[A-Za-z0-9_-]{16,}|gh[pousr]_[A-Za-z0-9]{20,})\b"), "a credential"),
)


def _leaks(text: str, session_ids: set[str]) -> list[str]:
    found = [why for rx, why in _LEAK_PATTERNS if rx.search(text)]
    found += [f"a session id ({sid[:8]}...)" for sid in session_ids if sid and sid in text]
    return found


def clean_events(events: list[dict]) -> list[dict]:
    """The init-stripped, whitelisted stream: assistant text and tool_use, tool_result, and a trimmed result. Ids are
    renumbered, thinking blocks, signatures, session ids, uuids, usage and every `system` event are dropped."""
    ids: dict[str, str] = {}
    out: list[dict] = []

    def short(raw: Any) -> str:
        return ids.setdefault(str(raw), f"t{len(ids) + 1}")

    for ev in events:
        kind = ev.get("type")
        if kind == "assistant":
            blocks = []
            for b in (ev.get("message") or {}).get("content") or []:
                if b.get("type") == "text":
                    blocks.append({"type": "text", "text": b.get("text", "")})
                elif b.get("type") == "tool_use":
                    blocks.append(
                        {
                            "type": "tool_use",
                            "id": short(b.get("id")),
                            "name": b.get("name"),
                            "input": b.get("input") or {},
                        }
                    )
            if blocks:
                out.append({"type": "assistant", "message": {"role": "assistant", "content": blocks}})
        elif kind == "user":
            content = (ev.get("message") or {}).get("content")
            if not isinstance(content, list):
                continue
            blocks = [
                {
                    "type": "tool_result",
                    "tool_use_id": short(b.get("tool_use_id")),
                    "is_error": bool(b.get("is_error")),
                    "content": _text_of(b.get("content"))[:OUTPUT_CAP],
                }
                for b in content
                if isinstance(b, dict) and b.get("type") == "tool_result"
            ]
            if blocks:
                out.append({"type": "user", "message": {"role": "user", "content": blocks}})
        elif kind == "result":
            usage = ev.get("modelUsage") or {}
            out.append(
                {
                    "type": "result",
                    "subtype": ev.get("subtype"),
                    "is_error": bool(ev.get("is_error")),
                    "result": ev.get("result") if isinstance(ev.get("result"), str) else "",
                    "total_cost_usd": ev.get("total_cost_usd"),
                    "num_turns": ev.get("num_turns"),
                    "modelUsage": {m: {"costUSD": (v or {}).get("costUSD")} for m, v in usage.items()},
                    "permission_denials": [
                        {"tool_name": d.get("tool_name")} for d in ev.get("permission_denials") or []
                    ],
                }
            )
    return out


def scan(rec: Path) -> list[tuple[str, str, str]]:
    """The committed recording holds nothing the sanitizer would refuse."""
    out = []
    files = sorted(p for p in rec.iterdir() if p.is_file())
    for f in files:
        found = _leaks(f.read_text(encoding="utf-8"), set())
        out.append(
            ("fail" if found else "pass", f.name, ", ".join(found) if found else "nothing the sanitizer refuses")
        )
    if not files:
        out.append(("fail", "recorded", "there is no recording"))
    return out


def _redact(text: str, pairs: list[tuple[str, str]]) -> str:
    for needle, repl in sorted(pairs, key=lambda p: -len(p[0])):
        if needle:
            text = text.replace(needle, repl)
    # Claude Code's own scratch paths (a background task's output file) carry the session id and the encoded home path.
    text = re.sub(r"(?:/private)?/tmp/claude-501/[^\"\s\\,)]*", "/tmp/claude-task", text)
    # The owner column of an `ls -l` the model ran is the OS account name. Scrub it as a whole word; anything else that
    # carries the name is a leak the check below still refuses.
    return re.sub(r"(?<![\w.-])" + re.escape(getpass.getuser()) + r"(?![\w.-])", "user", text)


def sanitize(rundir: Path, dest: Path, repo: Path) -> None:
    """Write dest/<case>.stream.jsonl and dest/<case>.trace.json for every <case>/stream.jsonl under rundir, or refuse
    (Premise) and write NOTHING when any real value survives redaction."""
    staged: dict[str, str] = {}
    problems: list[str] = []
    for case_dir in sorted(p for p in rundir.iterdir() if p.is_dir() and (p / "stream.jsonl").is_file()):
        case = case_dir.name
        meta = _load_json(case_dir / "meta.json")
        raw = _load_jsonl(case_dir / "stream.jsonl")
        sids = {str(e.get("session_id")) for e in raw if e.get("session_id")}
        roots = [Path(meta["sandbox"]), Path(meta["sandbox"]).resolve()]
        pairs: list[tuple[str, str]] = []
        for root in roots:
            pairs += [
                (f"{root}/repo", "/sandbox/repo"),
                (f"{root}/home", "/sandbox/home"),
                (f"{root}/state", "/sandbox/state"),
                (str(root), "/sandbox"),
            ]
        for plugin in {meta.get("plugin", ""), str(Path(meta["plugin"]).resolve()) if meta.get("plugin") else ""}:
            pairs.append((plugin, "/plugin"))
        for co in {str(repo), str(repo.resolve())}:
            pairs.append((co, "/checkout"))
        clean = clean_events(raw)
        if reduce_events(raw)["final"] != reduce_events(clean)["final"]:
            problems.append(f"{case}: the whitelisted stream does not reduce like the raw one")
        stream_text = _redact("".join(json.dumps(e, sort_keys=True) + "\n" for e in clean), pairs)
        trace = build_trace([json.loads(x) for x in stream_text.splitlines() if x], meta)
        trace_text = _redact(json.dumps(trace, indent=2, sort_keys=True) + "\n", pairs)
        for label, text in (("stream", stream_text), ("trace", trace_text)):
            for why in _leaks(text, sids):
                problems.append(f"{case} {label}: {why}")
        staged[f"{case}.stream.jsonl"], staged[f"{case}.trace.json"] = stream_text, trace_text
    if not staged:
        raise Premise("sanitize refused: no <case>/stream.jsonl under the run directory")
    if problems:
        raise Premise("sanitize refused: " + "; ".join(problems))
    dest.mkdir(parents=True, exist_ok=True)
    for name, text in staged.items():
        (dest / name).write_text(text, encoding="utf-8")
    verdicts = live_verdicts(dest)
    for case_dir in sorted(p for p in rundir.iterdir() if p.is_dir() and (p / "stream.jsonl").is_file()):
        vf = case_dir / "verdict.txt"
        if vf.is_file():
            for m in re.finditer(r"^CHECK (pass|fail|skip) (\S+) ", vf.read_text(encoding="utf-8"), re.M):
                verdicts[m.group(2)] = m.group(1)
    (dest / "live-verdicts.json").write_text(json.dumps(verdicts, indent=2, sort_keys=True) + "\n", encoding="utf-8")


# ── CLI ──────────────────────────────────────────────────────────────────────────────────────────────────────────
def _emit(rows: list[tuple[str, str, str]]) -> int:
    for verdict, case, msg in rows:
        print(f"CHECK {verdict} {case} {msg}")
    return 1 if any(v == "fail" for v, _, _ in rows) else 0


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd, args = argv[1], argv[2:]
    try:
        if cmd == "grade" and len(args) == 1:
            return _emit(grade_dir(Path(args[0]))[0])
        if cmd == "verdict" and len(args) == 1:
            trace = _load_json(Path(args[0]))
            first = GRADERS[trace["case"]](trace)
            rows = [(first[0], trace["case"], first[1])]
            if trace["case"] == "RV1":
                v3 = grade_rv3(trace)
                rows.append((v3[0], "RV3", v3[1]))
            if trace["case"] == "AD2":
                v4 = grade_ad4(trace)
                rows.append((v4[0], "AD4", v4[1]))
            return _emit(rows)
        if cmd == "mutate" and len(args) == 3:
            mutate(Path(args[0]), args[1], Path(args[2]))
            return 0
        if cmd == "mutations" and len(args) == 1:
            for kind, verdict, target, synthetic in mutation_list(Path(args[0])):
                print(kind, verdict, target, "synthetic" if synthetic else "recorded")
            return 0
        if cmd == "scan" and len(args) == 1:
            return _emit(scan(Path(args[0])))
        if cmd == "replay" and len(args) == 1:
            return _emit(replay(Path(args[0])))
        if cmd == "reducer" and len(args) == 1:
            return _emit(reducer_proof(Path(args[0])))
        if cmd == "env" and len(args) == 5:
            return _emit(env_proofs(Path(args[0]), *args[1:]))
        if cmd == "snapshot" and len(args) in (2, 3):
            log = Path(args[2]) if len(args) == 3 else None
            print(json.dumps(snapshot(Path(args[0]), Path(args[1]), log), sort_keys=True))
            return 0
        if cmd == "skills" and len(args) == 1:
            return _emit(skill_proofs(Path(args[0])))
        if cmd == "srctext" and len(args) == 5:
            return _emit(src_proofs(Path(args[0]), Path(args[1]), *args[2:]))
        if cmd == "probe" and len(args) == 1:
            print(probe_adhd(_load_json(Path(args[0]))))
            return 0
        if cmd == "reduce" and len(args) == 2:
            print(json.dumps(build_trace(_load_jsonl(Path(args[0])), _load_json(Path(args[1]))), indent=2))
            return 0
        if cmd == "sanitize" and len(args) == 3:
            sanitize(Path(args[0]), Path(args[1]), Path(args[2]))
            return 0
    except Premise as exc:
        print(f"PREMISE {exc}", file=sys.stderr)
        return 3
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
