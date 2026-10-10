#!/usr/bin/env bash
# borg-scout-guard.sh — PreToolUse (Bash) hook: confine the borg-scout subagent to read-only git/gh.
#
# borg-scout carries the Bash tool so it can answer "what is the state of PR X / what changed in
# commit Y". Bash is all-or-nothing in agent frontmatter, so the confinement is THIS hook: Claude
# Code puts agent_id/agent_type in every hook payload, and when agent_type names borg-scout (bare or
# namespaced, e.g. borg-collective:borg-scout) the command must match an allowlist or it is denied
# (exit 2, reason on stderr). Every other caller (main session, other agents) exits 0 untouched.
#
# Allowlist (everything else is denied):
#   git  log show diff status blame grep ls-files rev-parse, branch (list forms only),
#        remote [-v], worktree list; `git -C <path>` allowed, `git -c` is not
#   gh   pr view|list|diff|checks, issue view|list, run view|list, repo view, api (GET only)
#   optional pipe into head / wc / grep (single-level, simple args). No other pipe, chain, redirect,
#   command/process substitution, env prefix or path-qualified binary.
#
# FAIL-CLOSED for a scout caller (an unparseable command is denied), FAIL-OPEN when the caller is not
# provably a scout (no python3, bad JSON, no agent_type): this hook must never wedge other sessions.
# Python (not bash) because the allowlist needs a quote-aware tokenizer; one process, stdlib only.

set -uo pipefail

command -v python3 >/dev/null 2>&1 || exit 0

python3 -I -c '
import json, re, shlex, sys

try:
    data = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
if not isinstance(data, dict):
    sys.exit(0)
at = data.get("agent_type") or ""
if not (isinstance(at, str) and (at == "borg-scout" or at.endswith(":borg-scout"))):
    sys.exit(0)
if data.get("tool_name") not in (None, "Bash"):
    sys.exit(0)

cmd = (data.get("tool_input") or {}).get("command")

def deny(why):
    sys.stderr.write(
        "borg-scout guard: denied (%s).\n"
        "borg-scout may only run read-only git/gh: git log|show|diff|status|blame|grep|ls-files|rev-parse,\n"
        "git branch (list), git remote -v, git worktree list; gh pr view|list|diff|checks, gh issue view|list,\n"
        "gh run view|list, gh repo view, gh api (GET only). Optional single pipe into head, wc or grep.\n"
        "No chains, redirects or substitutions. Report what you need to the caller instead.\n" % why)
    sys.exit(2)

if not isinstance(cmd, str) or not cmd.strip():
    deny("empty command")
if re.search(r"[`\n\r]|\$\(|\$\{|<\(|>\(", cmd):
    deny("command or process substitution, or multi-line")

lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
lex.whitespace_split = True
try:
    toks = list(lex)
except ValueError:
    deny("unparseable quoting")

PUNCT = set("();<>|&")
segs = [[]]
for t in toks:
    if t and set(t) <= PUNCT:
        if t == "|":
            segs.append([])
            continue
        deny("operator %r" % t)
    segs[-1].append(t)
if len(segs) > 2 or any(not s for s in segs):
    deny("pipeline shape")

if len(segs) == 2:
    pipe = segs[1]
    if pipe[0] not in ("head", "wc", "grep"):
        deny("pipe target %r not head/wc/grep" % pipe[0])
    for a in pipe[1:]:
        if a.startswith(("-f", "--file", "--exclude-from")) and pipe[0] == "grep":
            deny("grep file-pattern flag")

a = segs[0]
bad_common = ("--output", "--ext-diff", "--open-files-in-pager", "--textconv", "--web", "--watch", "--no-index")

def is_bad_long(r):
    # git and gh accept any unambiguous ABBREVIATION of a long option, so deny a token when it is a
    # prefix of a denylisted name (--outpu=x, --ext-di) as well as when it extends one (--output-file).
    if r.startswith(bad_common):
        return True
    if r.startswith("--"):
        name = r.split("=", 1)[0]
        return len(name) > 2 and any(b.startswith(name) for b in bad_common)
    return False

def check_git(args):
    i = 0
    if args[:1] == ["-C"]:
        if len(args) < 3: deny("git -C needs a path and subcommand")
        i = 2
    if i >= len(args): deny("git with no subcommand")
    sub, rest = args[i], args[i + 1:]
    if sub.startswith("-"): deny("git global option %s" % sub)
    for r in rest:
        if is_bad_long(r) or re.match(r"^-O", r) and sub == "grep":
            deny("flag %s" % r)
    if sub in ("log", "show", "diff", "status", "blame", "grep", "ls-files", "rev-parse"):
        return
    if sub == "remote":
        if rest not in ([], ["-v"], ["--verbose"]): deny("git remote form")
        return
    if sub == "worktree":
        if not rest or rest[0] != "list" or any(x not in ("--porcelain", "-v", "--verbose", "-z") for x in rest[1:]):
            deny("git worktree form")
        return
    if sub == "branch":
        ok_flags = {"-a", "--all", "-r", "--remotes", "-v", "-vv", "--verbose", "--list", "-l", "--show-current",
                    "--merged", "--no-merged", "--contains", "--no-contains", "--points-at", "--sort", "--format",
                    "--color", "--no-color", "--column", "--no-column"}
        value_flags = {"--merged", "--no-merged", "--contains", "--no-contains", "--points-at", "--sort", "--format"}
        listing = any(x in ("--list", "-l") for x in rest)
        expect_val = False
        for x in rest:
            if expect_val:
                expect_val = False
                continue
            if x.startswith("-"):
                name = x.split("=", 1)[0]
                if name not in ok_flags: deny("git branch flag %s" % x)
                if name in value_flags and "=" not in x: expect_val = True
            elif not listing:
                deny("git branch with a name creates a branch")
        return
    deny("git subcommand %r" % sub)

def check_gh(args):
    if len(args) < 2: deny("gh form")
    g, sub = args[0], args[1]
    rest = args[2:]
    for r in rest:
        if is_bad_long(r) or r in ("-w",):
            deny("flag %s" % r)
    allowed = {"pr": ("view", "list", "diff", "checks"), "issue": ("view", "list"),
               "run": ("view", "list"), "repo": ("view",)}
    if g in allowed:
        if sub not in allowed[g]: deny("gh %s %s" % (g, sub))
        return
    if g == "api":
        endpoint_args = args[1:]
        i = 0
        while i < len(endpoint_args):
            x = endpoint_args[i]
            if x in ("-X", "--method"):
                if i + 1 >= len(endpoint_args) or endpoint_args[i + 1].upper() != "GET": deny("gh api non-GET method")
                i += 2; continue
            if re.match(r"^-X.", x) or x.startswith("--method="):
                if x.split("=", 1)[-1].lstrip("-X").upper() != "GET": deny("gh api non-GET method")
            if x in ("-f", "-F", "--field", "--raw-field", "--input") or re.match(r"^-[fF].", x) \
                    or x.startswith(("--field=", "--raw-field=", "--input=")):
                deny("gh api request body flag")
            if "graphql" in x.lower(): deny("gh api graphql")
            i += 1
        return
    deny("gh command %r" % g)

if a[0] == "git":
    check_git(a[1:])
elif a[0] == "gh":
    check_gh(a[1:])
else:
    deny("binary %r is not git or gh" % a[0])
sys.exit(0)
' <<<"$(cat)"
exit $?
