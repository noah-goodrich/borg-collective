# Detecting tests that pass for the wrong reason (weak assertions)

**Date:** 2026-08-11
**Question:** How do projects detect tests that PASS FOR THE WRONG REASON — assertions too weak
to distinguish success from failure?

## Executive summary

- Mature, actively maintained mutation testing for shell/bash **does not exist**. The closest
  practical substitute is manual/CI-enforced "verify the test fails without the fix" discipline,
  ShellCheck static analysis, and disciplined use of `bats-assert` instead of raw `[[ ]]`.
- "Verify your test fails without the fix" is **pure discipline** in the shell world — no tool
  automates it for bash/bats specifically. In compiled/typed ecosystems this is exactly what
  mutation testing (Stryker, PIT, mutmut) automates; nothing equivalent ships for shell.
- The bats `[[ ]]`/`(( ))` + `set -e` gotcha is real, documented, and specifically worse on
  bash 3.2 (macOS's shipped bash): `set -e` handling of `[[ ]]`/`(( ))` changed in bash 4.1, so
  on 3.2 an intermediate failing `[[ ]]` does **not** abort the test unless it's the last
  statement — confirming example (c) in the brief is a known, named bats gotcha, not a one-off bug.
  [bats-core gotchas doc](https://bats-core.readthedocs.io/en/stable/gotchas.html) (2024-2026).
- `bats-assert`/`bats-support` fix this by making each assertion its own function call that
  explicitly `return 1`s and prints a diagnostic — it does not rely on `set -e` propagating through
  `[[ ]]` at all, which is the real reason it's safer than raw brackets in bats bodies.
- Shell has no universal sentinel-exit-code convention distinguishing "false" from "errored";
  `sysexits.h` (64-78) is the closest formal standard but it's a C convention rarely honored by
  shell scripts, and most shell tools conflate "logical false" and "operational error" into a
  single nonzero exit — exactly the bug in example (a).

## Findings

### 1. Mutation testing for shell/bash

No mature mutation-testing tool for bash/shell surfaced in current search results. Tools found in
this space are unit-test *frameworks*, not mutation testers:

- **bats-core** — the de facto bash test framework, actively maintained.
  [github.com/bats-core/bats-core](https://github.com/bats-core/bats-core) [2024-2026]
- **shtk**, **bunit**, **Bach**, **Bash Test Tools** — smaller/alternative bash unit-test
  harnesses, general-purpose, not mutation-oriented.
  [jmmv.dev/2023/10/unit-testing-with-shtk.html](https://jmmv.dev/2023/10/unit-testing-with-shtk.html) [2023]
- **ShellCheck** — static analysis, not mutation testing, but it does catch some of the specific
  failure classes here: it has rule **SC2314/SC2315** flagging that `!` before a command does not
  cause a bats test to fail (a related-but-distinct gotcha to the `[[ ]]`/`(( ))` one).
  [shellcheck.net/wiki/SC2314](https://www.shellcheck.net/wiki/SC2314),
  [SC2315](https://www.shellcheck.net/wiki/SC2315) [2024-2026]
- A general web search for "mutmut/mutate for shell" and "mutation testing bash" returned nothing
  that is a real, shipping mutation engine for shell scripts. Mutation testing (mutmut for Python,
  Stryker for JS/.NET, PIT for Java) requires either an AST/bytecode the tool can systematically
  perturb, or a language runtime hook — shell's syntactic looseness (globbing, word-splitting,
  quoting semantics) makes automated "flip a comparison operator" mutation much harder to do
  soundly, which is the likely reason no one has shipped it.

**Verdict: mature shell mutation testing does not exist.** Closest practical substitute, in order
of leverage:
1. ShellCheck in CI (catches known gotcha classes, e.g. SC2314/SC2315).
2. Manual "break the fix, rerun the test, confirm red" as a PR-review step (see below — no tool
   enforces this for shell, but it's cheap and catches exactly the (a)/(b) failure modes).
3. `bats-assert`/`bats-support` in place of raw `[[ ]]`/`test` so assertion failures are structural
   function calls, not relying on errexit propagation.

### 2. "Verify your test fails without the fix" — tooling vs. discipline

- In statically-typed/compiled ecosystems this is *literally what mutation testing automates* —
  Stryker, PIT, mutmut all work by mutating the implementation and checking the test suite goes
  red; a test that stays green against a mutant is flagged as weak.
  [testmon.org](https://www.testmon.org/) discusses the adjacent "which tests exercise this
  change" problem via coverage, not mutation, and is explicit that it has no CI-specific behavior
  beyond re-running previously-failed tests [2024-2026].
- For shell specifically: no CI pattern or tool was found that automatically runs a new test
  against the pre-fix commit and asserts it fails. The `tdd-bdd-commit`
  ([github.com/matatk/tdd-bdd-commit](https://github.com/matatk/tdd-bdd-commit)) project encodes
  red/green *commit-message discipline* (tag commits `[RED]`/`[GREEN]`) but that's a convention
  enforced by a linter on commit messages, not a run of the test against the old code — it trusts
  the developer's self-report.
- Conclusion: **this remains purely a discipline/process practice** — "write the test, run it
  against the buggy code, confirm it fails red, then apply the fix and confirm green" — with no
  tool-enforced gate found for shell/bash. The nearest thing to enforcement is a PR-review
  checklist item or a commit-message convention, both of which rely on developer honesty rather
  than automated verification.

### 3. bats assertion hygiene — what actually controls intermediate-failure behavior

- The mechanism is confirmed directly from the bats-core docs: **"The `set -e` handling of `[[ ]]`
  and `(( ))` changed in Bash 4.1. Older versions, like 3.2 on macOS, don't abort the test unless
  [the failing expression is] the last command before the (test) function returns."**
  [bats-core gotchas](https://bats-core.readthedocs.io/en/stable/gotchas.html) [2024-2026]. This is
  exactly example (c) in the brief — it is a named, documented bash-version gotcha, not a
  bats-specific bug, and not fixable by bats itself (it's inherent to bash 3.2's errexit
  implementation).
- Documented workaround from the same source: use `[ ]` instead of `[[ ]]` where possible (POSIX
  test doesn't have this gotcha), or append `|| false` to any `[[ ]]`/`(( ))` expression to force
  a real nonzero exit that errexit will always catch, regardless of bash version.
  [bats-core gotchas](https://bats-core.readthedocs.io/en/stable/gotchas.html)
- Related, separate gotcha, also from ShellCheck: negating a command with `!` inside a bats test
  body never triggers errexit due to a bash design decision — fold the negation into the
  conditional instead (`[ ! -f x ]` rather than `! [ -f x ]` as a bare statement).
  [SC2314](https://www.shellcheck.net/wiki/SC2314) / [SC2315](https://www.shellcheck.net/wiki/SC2315)
  [2024-2026]
- **bats-assert / bats-support** ([github.com/bats-core/bats-assert](https://github.com/bats-core/bats-assert),
  a bats-core-adopted fork of the original `ztombol/bats-assert`) sidestep the whole problem
  structurally: each `assert_*` call is a real function that itself calls `return 1` (and prints a
  formatted diagnostic to stderr) on failure — it does not depend on errexit propagating through a
  bare `[[ ]]` at all. That's the actual reason "use bats-assert instead of raw `[[ ]]`" is the
  standard advice, not merely style. The repo shows continued activity (open PRs/issues, GitHub
  Actions CI present) as of this check, though exact last-release timestamps weren't confirmed by
  the fetch — treat as "actively used, cross-check release cadence before hard-pinning a version."
  [github.com/bats-core/bats-assert](https://github.com/bats-core/bats-assert) [tier uncertain,
  likely 2024-2026 given bats-core org ownership]
- `bats_require_minimum_version` is a real bats-core builtin (declared in a test file to assert a
  minimum bats-core version and opt into stricter/newer semantics) — it did **not** appear in the
  bats-assert README fetched, so it's a bats-core core feature, not an assertion-library feature.
  Could not fully verify its exact semantics from primary docs in this pass — flag as needing a
  direct read of bats-core's own README/CHANGELOG if this matters for the codebase
  (`docs.bats-core.readthedocs.io` didn't surface it in the fetched page).
- **bats-mock**: real, but the canonical `jasonkarns/bats-mock` is described as dormant; the
  actively maintained fork is `buildkite-plugins/bats-mock`.
  [github.com/buildkite-plugins/bats-mock](https://github.com/buildkite-plugins/bats-mock) [2024-2026]
  vs. dormant original [github.com/jasonkarns/bats-mock](https://github.com/jasonkarns/bats-mock).
  Socket.dev's package-health check flagged the npm-distributed `bats-mock` as having an unhealthy
  release cadence (last release "a year ago", one maintainer) — use with awareness it's a
  single-maintainer project, not evidence it's abandoned outright.
  [socket.dev/npm/package/bats-mock](https://socket.dev/npm/package/bats-mock) [2024-2026]

### 4. Distinguishing "returned false" from "errored" in shell

- No universal shell-native convention exists. The closest formal standard is **sysexits.h**
  (BSD/C convention): exit 0 = success, exit codes 64-78 (`EX_USAGE`, `EX_DATAERR`,
  `EX_NOINPUT`, etc.) reserved for specific *error* categories, distinct from a plain `1`
  used by `false`/general failure.
  [Apple sysexits(3) man page](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/sysexits.3.html),
  [brandur.org/exit-status](https://brandur.org/exit-status) [2024-2026, standard itself is
  foundational/pre-2020 but still current practice].
- In practice, most shell scripts (including the bug in example (a)) collapse "logically false"
  and "operation failed" into the same nonzero exit code, which is precisely why a caller checking
  only `$?` can't distinguish "stat says file is stale" from "stat itself failed." The
  general Unix convention documented across multiple sources (TLDP Exit Codes appendix, exit-status
  writeups) is: 0 = success, 1 = general failure, 2 = misuse of shell builtins, 126/127 =
  command-not-found/not-executable, 128+n = killed by signal n — none of these ranges are reserved
  by convention for "the check itself could not run" vs. "the check ran and said no."
  [TLDP Appendix E — Exit Codes With Special Meanings](https://tldp.org/LDP/abs/html/exitcodes.html)
  [pre-2020, but this appendix is still the most commonly cited reference and hasn't been
  superseded by anything newer].
- **Practical technique (not a named tool, but the standard fix pattern)**: separate the "did the
  check run" channel from the "what did the check conclude" channel. Concretely:
  - Use three-way exit codes: e.g. `0` = fresh, `1` = stale, `2+` (or a distinct reserved code) =
    "could not determine" (stat/syscall failed) — and have the test assert on the *specific* code,
    not just `[ "$status" -ne 0 ]`.
  - Or: have the function write its raw error (stderr / a captured `$?` from the inner `stat` call)
    to a side channel the test can inspect (`assert_output --partial "No such file"` from
    bats-assert) in addition to checking the exit code, so a hard failure produces observably
    different test output than a genuine "stale" result.
  - This is the general "don't let `$?` alone carry two bits of information" principle; it maps
    directly onto example (a) — the fix is to make the stat failure path exit with a distinct code
    (or emit to stderr) rather than being caught by the same `if ! stat ...; then echo false; fi`
    branch that also handles "genuinely stale."
  - No tooling enforces this pattern automatically; it's a code-review/design discipline, reinforced
    by `set -o pipefail` and checking `$?` immediately after the specific command rather than after
    a compound conditional (which is also what mitigates the bats `[[ ]]` gotcha in finding #3).

## Evidence gaps and uncertainties

- Could not find any *counter-example* — i.e., no vendor or OSS project claims to ship a working
  bash mutation tester. Absence of evidence is treated as evidence of absence here given multiple
  differently-worded searches all returned unit-test frameworks and static analyzers, never a
  mutation engine.
- `bats_require_minimum_version`'s exact semantics were not directly confirmed from bats-core's own
  README/CHANGELOG in this pass (only that it did not appear in the bats-assert page fetched). If
  this directive is load-bearing for your bats suite, do a direct read of
  `bats-core/bats-core`'s README before relying on this document's characterization.
- Exact current release/commit dates for `bats-core/bats-assert` were not extracted (WebFetch
  summarized qualitative activity signals — stars, open PRs/issues — not timestamps). Treat the
  "actively maintained" claim as directionally right but unverified to the day/month.
- The CI-pattern search for "assert a new test fails against the prior commit" surfaced only
  general TDD red/green commit-tagging conventions (`tdd-bdd-commit`), not an actual automated gate
  that checks out the previous commit and reruns the new test. If such tooling exists it's likely
  language-specific (e.g., some mutation-testing frameworks have a "test the tests" mode) rather
  than shell-specific; this document should not be read as ruling out non-shell equivalents.

## Paywalled must-reads

None identified — all load-bearing sources (bats-core docs, ShellCheck wiki, GitHub READMEs) are
open access.

## Sources index

| # | Title | URL | Date | Tier |
|---|-------|-----|------|------|
| 1 | bats-core Gotchas doc (`[[ ]]`/`(( ))` + set -e + bash 3.2) | https://bats-core.readthedocs.io/en/stable/gotchas.html | 2024-2026 | [2024-2026] |
| 2 | ShellCheck SC2314 (`!` doesn't fail bats tests) | https://www.shellcheck.net/wiki/SC2314 | 2024-2026 | [2024-2026] |
| 3 | ShellCheck SC2315 | https://www.shellcheck.net/wiki/SC2315 | 2024-2026 | [2024-2026] |
| 4 | bats-core/bats-assert repo | https://github.com/bats-core/bats-assert | unconfirmed | [2024-2026, unverified] |
| 5 | bats-core/bats-core (main framework) | https://github.com/bats-core/bats-core | 2024-2026 | [2024-2026] |
| 6 | bats-core sstephenson/bats issue #165 (errexit clarification) | https://github.com/sstephenson/bats/issues/165 | pre-2020 origin, still cited | [pre-2020] |
| 7 | buildkite-plugins/bats-mock (maintained fork) | https://github.com/buildkite-plugins/bats-mock | 2024-2026 | [2024-2026] |
| 8 | jasonkarns/bats-mock (dormant original) | https://github.com/jasonkarns/bats-mock | dormant | [2020-2023] |
| 9 | Socket.dev health check on npm bats-mock | https://socket.dev/npm/package/bats-mock | 2024-2026 | [2024-2026] |
| 10 | jmmv.dev — shtk unit testing bash | https://jmmv.dev/2023/10/unit-testing-with-shtk.html | 2023 | [2020-2023] |
| 11 | testmon.org — pytest-testmon (mutation-adjacent, Python only) | https://www.testmon.org/ | 2024-2026 | [2024-2026] |
| 12 | matatk/tdd-bdd-commit (red/green commit discipline tool) | https://github.com/matatk/tdd-bdd-commit | unconfirmed | [uncertain] |
| 13 | Apple sysexits(3) man page | https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/sysexits.3.html | foundational | [pre-2020] |
| 14 | brandur.org — Command Exit Status | https://brandur.org/exit-status | unconfirmed | [uncertain] |
| 15 | TLDP Appendix E — Exit Codes With Special Meanings | https://tldp.org/LDP/abs/html/exitcodes.html | foundational | [pre-2020] |
