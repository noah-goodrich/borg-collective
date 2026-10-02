# Why borg is a zsh CLI wrapping a Python core — the recovered record

*2026-09-29. Answering a claim from another session that "pure python would be faster than bash scripts." Produced by a
13-agent sweep over seven documentary surfaces plus independent measurement, with three adversarial reviewers.*

**tl;dr:** The decision record exists, is ratified, and is one document. The reason is **testability — specifically a
permanent zsh tooling gap — plus maintainer fluency.** Speed was never an argument *for* Python in the record;
it is the argument for keeping **hooks** in shell. And that last piece is where the other session is **right**: the
"hooks stay shell" arithmetic was computed on *empty* interpreters, and the shipped `bash-guard.sh` costs more
than Python's entire interpreter startup on every machine measured (at least 2.6x on every run; method below).

## The record

`docs/plans/assimilated/2026-08-11-python-core-toolchain-and-enforced-clean-architecture.md` — 385 lines, filed
`667af84`, resolved in #118 (`9d2b325`), shipped 2026-08-12 as #120. Two sections carry the whole answer: `## The
decision: Python + shell` (:23) and `## The measured boundary: hooks stay shell` (:71).

Supporting: `docs/plans/assimilated/2026-08-12-recon-migration-ledger.md` (per-command ledger),
`docs/research/2026-08-11-python-single-binary-startup-latency.md` (the benchmark study),
`docs/research/2026-08-12-clean-architecture-for-ai-agents/recommendation.md`.

**Neither file a reader checks first has the reasoning.** `docs/architecture.md:82` states the fact with zero rationale.
`CLAUDE.md:484` states the rule as a bare imperative. `CLAUDE.md:263` ("CLI structure mirrors dev.sh") is about
zsh-internal convention, not language choice. All three citations verified verbatim by an adversarial reviewer.

## Why Python for the core — testability, not speed

The directive's own ranking, all quotes verified:

1. **The zsh tooling gap is permanent** (:49-55). *"No coverage tool exists for zsh"* — kcov/bashcov instrument bash's
   xtrace, so **4,242 LOC, 54% of the codebase, is unmeasurable**. *"shellcheck refuses zsh, since 2016"*, and forcing
   `-s bash` is documented (SC1071) as giving *"false safety on exactly the word-splitting class"* that caused the
   trigger bugs. *"No mature shell mutation testing exists."* macOS ships bash 3.2.57 (2007), whose `set -e` silently
   ignores non-final `[[ ]]` — that hid 161 assertions.
2. **The trigger was three shell-idiom bugs in one day** (:38-45): #113a (`BASH_SOURCE` empty under zsh), #113b (zsh
   does not word-split unquoted expansions), #114 (GNU `stat -f` prints to stdout before failing). Commit `667af84`:
   *"each a shell-idiom failure no test could catch in the language it was written in."*
3. **The deliverable was the RULE, not the port** (:18-19, T6 at :150-158). The normative wording *"must name no
   language, so it ports unchanged"* to other repos. `667af84`: *"worth doing even if the migration never happens."*
   That rule is what lives at `CLAUDE.md:484`.
4. **Go and Rust lost to maintainer fluency — and the repo records they won on the merits** (:25-34). *"The reason
   is about the maintainer rather than the code… A tool the maintainer edits reluctantly is worse than one they edit
   fluently."* Then: *"A blind review argued — correctly, on this directive's own stated criteria — that a compiled
   single binary dominates… That argument is recorded rather than buried. It lost to maintainer fluency."*
5. **Strangler, not rewrite** (:210-214). *"Big-bang rewriting a 2,700-line file whose safety net is the thing being
   fixed is how this goes wrong. Command by command."* The parity net, `tests/cli_contract.bats`, is
   *"language-agnostic by design"* and was grown **before** any migration.
6. **Two languages is the declared end state** (:342-343), not a waypoint.

Non-latency reasons shell keeps the edge: zsh owns argv for *"muscle memory, tmux integration, and hook contracts"*
(:215-216); `drone.zsh` stays shell for code shape — *"least logic, most shell affinity"* (:309); drone containers
bind-mount `~/.config/borg`, so *"a missing venv breaks it in a way a zsh script never would"* (:339-341). And one
surface stays zsh for **contract** reasons, documented only in a code comment — `borg.zsh:1073-1077`: moving the
`claude -p` call into Python *"would silently delete two shipped contracts"*, because `borg_core/proc.py` DEVNULLs
stderr and returns `None` rather than rc 124 on timeout.

## The speed question, answered properly

**Speed appears in the record exactly once, and it argues for SHELL, not Python.** The measurement table (:73-86,
Python 3.14.5):

| program | ms |
|---|---|
| `zsh -c true` | 27.3 |
| `bash -c true` | 27.9 |
| `python3 -S -c pass` | 41.1 |
| `python3 -c pass` | 47.6 |
| `python3 -c 'import typer'` | 59.6 |

*"Python's practical floor is ~41 ms before any borg code runs, against zsh's ~27 ms. The two PostToolUse hooks fire on
every agent tool call; at ~250 calls a session that is seconds of pure added latency for zero benefit. **Hooks stay
shell — permanently, and this is arithmetic rather than preference.**"*

"Just compile it" was researched and closed *"so it is never re-litigated"* (:88-103): every packager still boots full
CPython — Nuitka measured 257 ms vs 152 ms plain, PyInstaller `--onefile` re-unpacks per run, PyOxidizer dormant since
2024-11-03, `py2many` cannot transpile typer/click. The research's load-bearing line: *"compiling/packaging Python does
not fix CPython startup."* `-S` recovers only 6.5 ms on 3.14 — *"do not plan around the old ratio."*

The one door back in is named and deferred (:108-110): a **persistent daemon plus thin socket client** (~0.1 ms per
round trip), *"a real, stateful architecture change, not a packaging swap. Out of scope — recorded so the option is
remembered rather than rediscovered."*

Measured live 2026-09-29 for comparison: `import borg_core.link.cli` ~69 ms; `borg link --local` 178 ms; `borg link`
(network) 1151 ms, so the sweep is ~975 ms and the zsh wrapper is 2-3% of it; wrapper tax on a Python-dispatching
command ~32 ms.

## Where the other session is RIGHT, and the record is incomplete

The "hooks stay shell" arithmetic compared **empty interpreters**: `zsh -c true` against `python3 -c pass`. It never
measured a hook that does real work. Measured on the shipped artifact, on two machines (both 2026-10-02):

Two machines, one method, one shipped artifact. The direction (the bash hook costs MORE than Python's whole startup)
holds on both; the absolute figure does not transfer between them, which is why CLAUDE.md pins the direction and not a
number.

**Method.** `hooks/bash-guard.sh` at the head of this PR (shebang `#!/usr/bin/env bash`), invoked as
`printf '%s' "$P" | bash hooks/bash-guard.sh`. 20 sequential runs inside bash's `time` keyword, total wall clock
divided by 20. Output discarded. Included: the process spawn, every helper fork (`jq`, `sed`, `tr`, `grep`), and the
stdout JSON pre-approval; the hook's exit-2 block path is not exercised by either payload. Excluded: any wrapper
shell. Typical payload `P` is `{"tool_name":"Bash","tool_input":{"command":"ls -la /tmp"}}`. The early-exit-defeating
payload is `{"tool_name":"Bash","tool_input":{"command":"echo hello world && cat /etc/hosts | sort | uniq -c"}}`,
chosen so the read-only classifier walks a multi-segment pipeline instead of approving at the first segment.

| ms/call, 20 runs each | reviewer: Apple M3 Pro | author: Apple M4 Pro, pass 1 / pass 2 |
|---|---|---|
| `bash-guard.sh`, typical payload | 63.5 | 147.3 / 147.4 |
| `bash-guard.sh`, early-exit-defeating payload | 80.1 | 164.8 / 168.0 |
| `python3 -c pass` | 24.1 | 33.1 / 33.2 |
| `bash -c true` | not measured | 11.2 / 11.1 |
| `jq -n 1` | not measured | 9.0 / 9.7 |
| bash-guard typical / `python3 -c pass` | 2.6x | 4.4x |
| bash-guard early-exit-defeating / `python3 -c pass` | 3.3x | 5.0x |

Run-to-run spread on the author's machine, five passes in total (these two plus three later passes at machine load of
about 2.4 to 2.5): typical payload 115 to 179 ms (3.7x to 5.6x of `python3 -c pass`), early-exit-defeating payload 147
to 198 ms (4.8x to 6.2x), `python3 -c pass` 31 to 33 ms. The floor across all runs on both machines is 2.6x (the
reviewer's single pass); the contract is that floor, not any band above it.

Interpreters on the author's machine: macOS 26.6.2, bash 5.3.20 and python3 3.14.5 and jq all under
`/opt/homebrew/bin`. The reviewer's interpreter paths and versions were not recorded in the review; add them to
this table if they differ. A same-shape Python guard (stdin JSON plus 12 regexes, written by a reviewer on the
author's machine) measured 33.0 to 33.9, i.e. no slower than `python3 -c pass` there.

**Process count, which is the real driver.** `bash -x` traced with `PS4='+TRACE '` and filtered to command words
that resolve to external binaries (builtins such as `printf` and `[[` excluded) gives, per call: typical payload 23
external processes (12 `sed`, 5 `grep`, 4 `tr`, 2 `jq`); early-exit-defeating payload 24 (13 `sed`, 5 `grep`,
4 `tr`, 2 `jq`). The hook is one bash plus roughly two dozen short-lived helpers, not one process. This is a trace
count, not a `dtrace` exec count, so treat it as accurate to a few processes.

**Why the figure moves with the machine (a hypothesis, consistent with the data and not proven).** Per-exec cost is
higher on the author's machine: `bash -c true` is 11 ms and `python3 -c pass` 33 ms there, against a 24 ms
`python3 -c pass` on the reviewer's. A hook that pays that overhead 23 times moves with it (147 versus 63.5, 2.3x),
while Python's single startup pays it once (33 versus 24, 1.4x). That is also why the ratio is larger here (4.4x
versus 2.6x). The cause of the higher per-exec cost (chip, OS release, or security tooling) was not isolated.

**The earlier 194.1 ms figure is withdrawn as a headline.** It was an uncontrolled observation with no recorded
method; a later checkpoint on the same machine recorded 166 ms per Bash call. It sits inside this machine's own
run-to-run spread above (115 to 198 ms) and does not transfer to another machine. Every run on this machine exceeds
`python3 -c pass` by more than 3.7x, so the direction was never in doubt; the figure was. The earlier "42 pattern
checks" parenthetical is also dropped: it was not derivable from the artifact. `hooks/bash-guard.sh` contains no `=~`
at all, and no counting method over its glob tests and `case` patterns was recorded that reaches 42. The
process count above is the verifiable description of what was timed.

**That does not overturn the core decision** — the core is Python already, and the reason was never speed. But it does
falsify the premise of the hook boundary as written. The honest statement is: *trivial* hooks stay shell because 27 ms
beats 41 ms; hooks doing string or regex work at volume are the opposite case, and `bash-guard.sh` is the proof.

## What the archaeology could NOT find

- Zero hits for `python is faster|shell is faster|faster than (bash|zsh|shell)` across `docs/` + `CLAUDE.md`. The
  framing "which is faster" is not in the record at all.
- Zero hits for `bash vs python|interpreter startup|startup cost|python core` across all 1106 files in
  `.borg/knowledge/` — cairn's export has nothing on this.
- `docs/research/2026-08-11-testing-posture*` is cited but **never existed in git history**; only the assimilated plan
  `2026-08-11-testing-posture-b-and-d.md` was committed.
- The directive grades its own justification (:346-348): *"The base rate is thin. Three bugs in one deliberately
  portability-focused day is not a measured defect rate. This directive's honest justification is Part 1's rule plus
  maintainer ergonomics — stated so the judgment is visible rather than smuggled in as a finding."*

## Two stale artifacts found on the way

- `2026-08-12-recon-migration-ledger.md:11` says `hooks/*.sh (all 9)`. There are **13** hooks, and **two** already
  invoke `python3` (`borg-plan-promote.sh`, `borg-prefer-tool-log.sh`, both guarded with
  `command -v python3 || exit 0`). The ledger row is stale on count and on purity.
- A reviewer reported `checkpoint-name` "is not a command" and `borg help` listing 25. Both are **artifacts of reading
  `feat/short-window-names`**, the branch the default worktree is parked on, which is behind `main` (3 hits on main, 0
  there; 26 commands vs 25). Fourth instance in one session of a stale default worktree producing a false finding —
  the subject of the worktree-identity retro, one more time. A research prompt against an unmerged or recently-merged
  tree must name the branch, not the repository.
