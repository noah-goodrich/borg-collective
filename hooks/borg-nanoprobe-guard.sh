#!/usr/bin/env bash
# borg-nanoprobe-guard.sh — PreToolUse hook (matcher: Skill|Write|Edit|MultiEdit|NotebookEdit|Bash): make the
# borg-nanoprobe fence a gate instead of prose.
#
# Two rules, both scoped to the nanoprobe by the payload's `agent_type` exactly the way
# borg-verifier-guard.sh scopes itself to the verifier (plugin agent reports `borg-collective:borg-nanoprobe`,
# the borg-setup copy reports the bare `borg-nanoprobe`; every other caller is a no-op that allows):
#
#   1. Skill: a nanoprobe may call a skill only when the MACHINE-layer brief extension
#      (${XDG_CONFIG_HOME:-$HOME/.config}/borg/extensions/agent-extensions/borg-nanoprobe/brief.md) carries a
#      `- Prefer-tool:` line naming exactly that skill, a `- Instead-of:` line equal to `gh pr create`, and a
#      `- Requires:` line. The hook reads that file itself; nothing the agent or its brief says can widen it.
#      Every other Skill call is denied.
#   2. Write|Edit|MultiEdit|NotebookEdit: denied for any path under ${XDG_CONFIG_HOME:-$HOME/.config}/borg/
#      extensions/, so a nanoprobe cannot author its own permission.
#   3. Bash: denied for any command whose text references the extensions directory in any spelling (resolved
#      path, $XDG_CONFIG_HOME form, ~/.config form, bare .config/borg/extensions, agent-extensions), so a shell
#      redirect cannot bypass rule 2. Reads need no Bash (the agent uses the Read tool), so any reference is denied.
#
# Contract: a deny exits 2 with the reason on stderr (same as borg-verifier-guard.sh). Errors in the hook fail
# OPEN (exit 0). The fast path is pure bash builtins: a payload that never mentions borg-nanoprobe exits 0
# without forking. Kill switch: BORG_NANOPROBE_GUARD=0.

set -uo pipefail

[[ "${BORG_NANOPROBE_GUARD:-1}" == "0" ]] && exit 0

INPUT=""
IFS= read -r -d "" INPUT || true
[[ "$INPUT" == *borg-nanoprobe* ]] || exit 0

command -v python3 >/dev/null 2>&1 || exit 0

# Read with `read -d ""` outside any command substitution (bash 3.2 heredoc-in-$( ) parse bug, see
# tests/hook_bash32_parse.bats).
read -r -d "" GUARD <<'PY' || true
import json, os, sys

NANOPROBE_TYPES = ("borg-collective:borg-nanoprobe", "borg-nanoprobe")
WRITE_TOOLS = ("Write", "Edit", "MultiEdit", "NotebookEdit")
INSTEAD_OF = "gh pr create"


def field(text, name):
    """Values of every `- Name: value` line, backticks and spaces stripped."""
    out = []
    prefix = "- " + name.lower() + ":"
    for line in text.splitlines():
        s = line.strip()
        if s.lower().startswith(prefix):
            out.append(s[len(prefix):].strip().strip("`").strip())
    return out


def config_home():
    return os.environ.get("XDG_CONFIG_HOME") or os.path.join(os.environ.get("HOME", ""), ".config")


def skill_allowed(skill):
    path = os.path.join(config_home(), "borg", "extensions", "agent-extensions", "borg-nanoprobe", "brief.md")
    try:
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
    except OSError:
        return False, "no machine-layer brief at %s, so no skill is granted" % path
    if skill not in field(text, "Prefer-tool"):
        return False, "the machine-layer brief does not name %r in a '- Prefer-tool:' line" % skill
    if INSTEAD_OF not in field(text, "Instead-of"):
        return False, "the machine-layer brief has no '- Instead-of: %s' line" % INSTEAD_OF
    if not any(field(text, "Requires")):
        return False, "the machine-layer brief has no '- Requires:' line"
    return True, ""


def under_extensions(p, cwd):
    root = os.path.join(config_home(), "borg", "extensions")
    if not os.path.isabs(p):
        p = os.path.join(cwd or os.getcwd(), p)
    roots = {os.path.normpath(root), os.path.realpath(root)}
    cands = {os.path.normpath(p), os.path.realpath(p)}
    return any(c == r or c.startswith(r + os.sep) for c in cands for r in roots)


def mentions_extensions(cmd):
    root = os.path.join(config_home(), "borg", "extensions")
    needles = (root, os.path.realpath(root), "borg/extensions", ".config/borg/extensions",
               "agent-extensions")
    return any(n in cmd for n in needles)


def deny(reason):
    sys.stderr.write("borg nanoprobe guard: denied for borg-nanoprobe.\n  - %s\nKill switch: "
                     "BORG_NANOPROBE_GUARD=0.\n" % reason)
    return 2


def main():
    try:
        data = json.loads(sys.stdin.read())
    except ValueError:
        return 0
    if not isinstance(data, dict) or data.get("agent_type") not in NANOPROBE_TYPES:
        return 0
    tool = data.get("tool_name")
    ti = data.get("tool_input")
    if not isinstance(ti, dict):
        return 0
    if tool == "Skill":
        skill = ti.get("skill")
        if not isinstance(skill, str) or not skill:
            return deny("Skill call without a skill name")
        ok, why = skill_allowed(skill.strip())
        if ok:
            return 0
        return deny("Skill %r is not granted to a nanoprobe: %s" % (skill, why))
    if tool in WRITE_TOOLS:
        p = ti.get("file_path") or ti.get("notebook_path") or ti.get("path")
        if isinstance(p, str) and p and under_extensions(p, data.get("cwd")):
            return deny("%s under borg/extensions/ is not allowed; extensions are user-authored" % tool)
    if tool == "Bash":
        cmd = ti.get("command")
        if isinstance(cmd, str) and mentions_extensions(cmd):
            return deny("Bash command referencing borg/extensions/ is not allowed; extensions are user-authored")
    return 0


try:
    rc = main()
except Exception:
    rc = 0
sys.exit(rc)
PY

printf '%s' "$INPUT" | python3 -I -c "$GUARD"
rc=$?
[[ $rc -eq 2 ]] && exit 2
exit 0
