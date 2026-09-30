# Why borg is a zsh CLI wrapping a Python core — the recovered record

*2026-09-29. Answering a claim from another session that "pure python would be faster than bash scripts." Produced by a
13-agent sweep over seven documentary surfaces plus independent measurement, with three adversarial reviewers.*

**tl;dr:** The decision record exists, is ratified, and is one document. The reason is **testability — specifically a
permanent zsh tooling gap — plus maintainer fluency.** Speed was never an argument *for* Python in the record;
it is the argument for keeping **hooks** in shell. And that last piece is where the other session is **right**: the
"hooks stay shell" arithmetic was computed on *empty* interpreters, and the shipped `bash-guard.sh` measures 194 ms
against Python's 35 ms floor.

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
measured a hook that does real work. Measured independently today, twice, on the shipped artifact:

| | ms/call |
|---|---|
| `hooks/bash-guard.sh` (42 pattern checks, real payload) | **194.1** |
| `python3 -c pass` (full interpreter startup, no work) | **35.2** |
| a same-shape Python guard (stdin JSON + 12 regexes), written by a reviewer | **33.0-33.9** |

So the shipped bash hook costs **~5.5x Python's entire startup budget**, and a Python equivalent measured *faster than
`python3 -c pass`* on this machine — i.e. the regex work is free relative to startup, while in bash it dominates.

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
