# claude-marche: language policy, and four findings from asking the question

*2026-09-29. Prompted by ai-devx review comments on Ontra-ai/claude-marche#523. Produced by an 8-agent sweep with three
adversarial reviewers; every load-bearing claim below was re-verified by hand afterwards.*

**tl;dr:** The review asked about *readability*, not speed. mjewell is right about the tests and wrong about
permissions. But the language question is not the risk — the sweep turned up a **live approval bypass in #523**, a CI
glob that runs 4 test files and skips the Python ones, and **zero runtime guards** on hooks that invoke `python3`
directly. Fix those; adopt a one-line language rule; do not run a migration. (The fail-open finding was independently fixed
on 2026-09-30 by `a84e7e4b`; see Finding 4.)

## Finding 1 — a live bypass in #523, verified by hand

`block-pr-approval.sh` blocks the plain forms and **allows a quoted flag**:

```
gh pr review 912 --approve            -> rc=2  blocked
gh pr review 912 -a                   -> rc=2  blocked
FOO=1 gh pr review 912 --approve      -> rc=2  blocked
cd /tmp; gh pr review 912 --approve   -> rc=2  blocked
gh pr review 912 "--approve"          -> rc=0  ALLOWED
gh pr review 912 '--approve'          -> rc=0  ALLOWED
gh pr review 912 --comment -b hi      -> rc=0  allowed (correct)
```

Tested against `origin/fix/de-pr-review-plan-states`, the PR's own branch, with `jq` present.

**Cause.** The pattern anchors on whitespace *before* the flag: `[[:space:]](--approve…|-a…)`. With a quote character
immediately before `--approve`, that leading anchor never matches, so the terminator is never reached. It is the
**leading anchor** that needs widening, not the terminator — and widening it interacts with the two false positives the
hook already guards against, so it is not a one-character change.

All 34 existing tests still pass with the bypass present, which is exactly why it went unnoticed. **Two cases to add
before merge**, and they are the cheapest possible proof the suite discriminates.

## Finding 2 — permissions cannot replace the hook (mjewell's suggestion, tested)

Measured against a neutral stub binary with a glob deny rule, Claude Code 2.1.276:

| spelling | deny rule |
|---|---|
| plain flag | BLOCKED |
| `cd /tmp; …`, `VAR=x …`, `command …`, `echo hi \| …` | BLOCKED |
| flag reordered before the arg | **RAN** |
| short flag `-a` | **RAN** |
| `--flag=true` | **RAN** |
| quoted token | **RAN** |
| `bash -c '…'` | **RAN** |
| heredoc into `--input -` | **RAN** |

Three structural blockers, each independently fatal:

1. **A plugin cannot ship permission rules.** There is no permissions field in the plugin manifest. A deny rule has to
   land by hand in each engineer's `~/.claude/settings.json` — and `claude-marche/.claude/settings.json` does not
   govern sessions run in `dbt` or `snowflake-permissions`, which is where `pr-review` actually runs.
2. **MCP rules can't match arguments from a settings file.** Denying `mcp__github__pull_request_review_write` by bare
   name also blocks the sanctioned `--comment` and `REQUEST_CHANGES` paths, which the hook deliberately allows.
3. **The docs say so directly**: a Bash rule *"isn't a security boundary around the program… To inspect the full
   command text with your own logic before it runs, use a PreToolUse hook."*

**Keep the hook. Add a deny rule alongside it** for the forms a glob does catch — but note that after Finding 1's fix
the quoted-token form is missed by *both* layers, so "defense in depth" is not a reason to skip the regex fix.

**One correction the PR owes him.** Its body cites the never-approve guarantee "holding ~88% of the time." That figure
measured a *grader*, not a near-approval — the body itself says "it was never an approval bug; across ~40 runs the
skill declined every time." His base-rate instinct is right and that line should come out.

## Finding 3 — CI runs 4 test files and skips the Python ones

`.github/workflows/validate-plugins.yml:41` loops exactly `plugins/*/hooks/*.test.sh`. Five `test_*.py` files exist
under `plugins/` and **no workflow executes them**.

So the review's advice — rewrite bash tests into Python — would, applied today, move tests **out** of CI. The ordering
is: **make the unrun tests run, then improve readability.** Not the reverse.

## Finding 4 — the hooks fail open, and no plugin can declare a runtime

> **FIXED 2026-09-30, independently.** claude-marche `a84e7e4b` ("fix(outbound-gate): resolve the interpreter, and
> fail closed when there is none") landed at 10:37, hours after this was measured. `hooks/hooks.json` now invokes
> `run-gate.sh deny-on-missing gate_outbound.py` and `run-gate.sh warn-on-missing gate_chat_length.py`, a 66-line
> wrapper that resolves an interpreter and exits 2 when there is none — exactly the mechanism named as missing below.
> Two sessions reached the same fix from opposite directions, which is the strongest evidence in this document that
> the finding was real. **The paragraphs below are preserved as measured, not corrected in place**, because the
> structural half is still true: a plugin STILL cannot declare a runtime dependency, and a `type: "command"` hook that
> cannot start is STILL a non-blocking error. The wrapper is a workaround for a packaging gap, not a closure of it.

- `grep -rn 'command -v python3' plugins/` → **0 hits.**
- `plugins/outbound-gate/hooks/hooks.json` invokes bare `python3 ${CLAUDE_PLUGIN_ROOT}/hooks/gate_outbound.py` and
  `gate_chat_length.py`, with no guard and no fallback.
- The plugin manifest has no `dependencies`/`engines`/`runtime` field, so a plugin cannot state that it needs `python3`
  and Claude Code cannot refuse to install it where one is absent.

A `type: "command"` hook that cannot start is a non-blocking error and the tool call proceeds. So `gate_outbound.py`'s
own docstring — *"Fail closed. Any error here denies. A gate that opens when its own logic breaks is not a gate"* — is
true inside the process and false outside it. **No `python3` → no process → the send goes through unguarded.**

borg solves this with an explicit guard (`command -v python3 >/dev/null 2>&1 || exit 0`) in the two hooks that need it.
marche has the opposite exposure and none of the guards. For a *gate*, exiting 0 is the wrong degrade — it should be a
loud failure, which means the guard belongs in a bash shim that exits non-zero when the interpreter is missing.

## The policy — one rule

Startup, this machine, macOS arm64, 20 invocations each:

| | ms |
|---|---|
| `bash -c ':'` | 9.3 |
| `jq -n 1` | 11.6 |
| `python3` (Homebrew), json+re | 36.2 |
| `/usr/bin/python3` 3.9.6 (the fallback) | 51.9 |
| `node -e 1` | 66.7 |
| `ruby -e 1` | 94.8 |

End-to-end on the real hook: **bash 45.6 ms/call, a 20-line Python port 37.5 ms/call.** Python wins not because Python
is fast but because it is *one* process instead of `bash + jq + tr + tr`.

> **A hook body may be bash if it spawns at most one helper process. Two or more, it is Python 3.**
>
> 1. **≤1 subprocess** (env vars, paths, exit codes, one `jq` read) → **bash**.
> 2. **≥2 subprocesses** (JSON parse *plus* string work — every real policy hook) → **Python 3, stdlib only, must
>    parse under 3.9**.
> 3. **Never node or ruby in a hook body** — 67 ms and 95 ms of startup before doing anything.
> 4. **Anything that is not a hook body** — tests, `scripts/`, evals, `bin/` — **any language the team reads.** RSpec
>    already tests bash successfully elsewhere in the org.
> 5. **Every hook, any language, is stdin-JSON in / exit-code out**, and states its measured per-call cost in the PR.

The rule is *process count*, not taste — which is why it survives the readability argument in both directions.

## Sequencing

**Now, on #523:** add the two quoted-token cases, fix the leading anchor, drop the "~88%" line.
**Next, one PR:** widen the CI glob to run the Python tests; add a `python3` guard shim to outbound-gate that fails
loud rather than open.
**Ongoing:** apply the rule to *new* hooks. `block-pr-approval.sh` is 3 subprocesses and would be Python under it —
port it when it next needs a substantive change, not before.
**Never:** rewrite the 34-test bash file for readability alone. It is the only plugin test suite CI actually runs.
