# D1 — Prior-Work Catalog (quarantined)

Cataloged before any option generation. Walled off from D3 — options in this research are generated from
zero, not by picking among these.

## 1. `pylint-clean-architecture` (Noah's own plugin, v1.5.2, PyPI)

What it is: a custom pylint plugin enforcing layered architecture — directory/suffix-based layer
resolution (Domain/UseCase/Infrastructure/Interface), a Silent Core rule (no print/logging in
Domain/UseCase), a DI-enforcement rule (Gateway/Repository/Client-suffixed classes must be injected, not
instantiated, inside UseCase code), a "God File" rule (one Heavy component per file), and an anti-bypass
guard that blocks blanket `# pylint: disable` comments without a stated justification.

Where it lives: `~/dev/pylint-clean-architecture` (source), installed as a dependency in this repo's
`pyproject.toml` and in `pytest-coverage-impact`.

What it gets right: mechanically enforced (not documented-and-hoped-for), which matches this repo's own
learned lesson that only enforced rules survive AI-agent sessions. The layer resolution is
**configurable** via `[tool.clean-arch.layer_map]` per project — it does NOT hard-require the textbook
`domain/use_case/infrastructure/interface` directory names; those are just its *defaults*.

What it gets wrong (or leaves open): built assuming a human maintainer's cognitive-load problem (can't
hold too many files in your head, need hard walls against spaghetti) — never evaluated against
agent-specific failure modes (tool-call cost to traverse layers, whether Silent-Core/DI rules trip false
positives on legitimate agent-authored code). No prior data exists in this repo on whether its rule set
helps or hurts agent-driven maintenance specifically.

## 2. `pytest-coverage-impact` — the one real example already using this exact plugin

Where it lives: `~/dev/pytest-coverage-impact/pytest_coverage_impact/`.

**Actual directory layout in production** (not the textbook default):
`core/`, `di/`, `domain/`, `feedback/`, `gateways/`, `interface/`, `logic/`, `ml/` — 8 top-level
directories for a project with 1 package. It uses a **custom `layer_map`**, not the plugin's default
`domain/use_case/infrastructure/interface` convention. `gateways/` (not `infrastructure/`) holds the I/O
adapters; `logic/` (not `use_case/`) holds orchestration; `ml/` is a whole additional non-canonical
directory for machine-learning code that doesn't map cleanly onto any of the four standard layers at
all.

What this gets right: proves the plugin is flexible enough to fit a real, non-toy project without
forcing the textbook shape.

What it gets wrong: even the ONE prior example in this exact ecosystem didn't converge on the "canonical"
4-layer layout — meaning "adopt Clean Architecture" was never actually a single settled convention here,
even before this question was raised. There is no existing evidence (this repo has never measured it)
on whether Claude Code sessions maintaining `pytest-coverage-impact` have had an easier or harder time
than they would with a flatter structure.

## 3. borg-collective's own current (pre-migration) shell conventions

`borg.zsh` (~2,700+ lines, one file, case-dispatched `cmd_*` functions), `lib/*.zsh` (shared helpers,
one file per concern — `registry.zsh`, `tmux.zsh`, `reaper.sh`+`registry.zsh` split mirrored by
`recon.sh`+`recon.zsh`), `hooks/*.sh` (one file per hook, portable sh). This is a genuinely flat,
low-indirection structure — no layering at all beyond "one file per named concern" — and it's the thing
Part 1-2 of this same directive already found riddled with untestable, unmeasured logic (the whole
reason Python + a testable core was proposed in the first place).

What it gets right: minimal indirection, easy to grep, one hop from command name to implementation.

What it gets wrong: zero enforced separation between I/O and logic — exactly the defect this migration
exists to fix. cmd_recon mixed arg-parsing, orchestration, and shell-out-to-subprocess in one function.

## 4. This repo's own already-stated Architecture Rule (Part 1, already shipped)

`CLAUDE.md` "Architecture Rules" section, added in Part 1 of this same directive: *"Logic goes in a
testable core. Shell is a wrapper. New modules ship with tests in the same commit."* Deliberately
language-agnostic (the directive's own text: "must name no language, so it ports unchanged to dbt/
Snowflake/TS repos"). This is intentionally MINIMAL — it does not mandate 4-layer Clean Architecture,
Protocol-based DI, or any specific directory shape. It only mandates: separate logic from shell, and
test coverage lands with the code. Worth noting this already-shipped rule is looser than what the
`borg_core/` draft design (this session, now under question) was about to build on top of it.

## 5. This session's own first-draft `borg_core/` design (quarantined as prior art, not a starting point)

Earlier this session, before this bigger question was raised, a full domain/use_case/infrastructure/
interface layout was drafted for the `recon` migration and sent through one round of adversarial review.
That draft and its critiques are preserved (not discarded) as raw material — findings from that review
(e.g., real linter-compliance landmines, over-splitting single-responsibility infrastructure classes,
readability risk for a future session) will be checked against whatever this research concludes, but the
draft itself is NOT an anchor for D3's option generation below.
