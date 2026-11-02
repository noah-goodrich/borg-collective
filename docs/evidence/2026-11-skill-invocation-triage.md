# Skill invocation triage (step 0 of the evals plan)

Part of #480, step 0 of `PROJECT_PLAN.md` (AC4). Each of the 16 skills under `skills/` gets a recorded invocation mode. `slash-only` skills carry `disable-model-invocation: true`, which removes them from the model's skill listing in Claude Code (Cortex ignores the field). `self-firing` skills stay listed and get trigger suites later.

## Method

- User-typed: occurrences of `<command-name>/borg-collective:<skill></command-name>` or the bare `/<skill>` form in `/Users/noah/.claude/projects/*/*.jsonl`. Model: assistant `Skill` tool calls whose `input.skill` names the skill. Counts are raw occurrences on this machine, so resumed sessions that replay history can count one event twice. Treat them as order of magnitude, not exact. No transcript text is copied here.
- Dependency evidence: every place that tells the model to invoke the skill (other skills, `agents/`, `hooks/`, `bin/`, `docs/agents/`, the user's global `CLAUDE.md` and `borg-managed.md`, the user's memory index).
- Rule: any instruction to the model to invoke a skill makes it `self-firing`, whatever the counts say. Mixed or thin evidence also resolves to `self-firing`, because a wrongly hidden skill breaks a workflow and a wrongly listed one costs a few tokens. Hiding never removes the slash command: the user can still type it.

## Table

| Skill | Mode | Typed | Model |
|-------|------|------:|------:|
| adhd-guardrails | self-firing | 0 | 0 |
| borg-assimilate | self-firing | 26 | 6 |
| borg-collective-review | self-firing | 0 | 30 |
| borg-link | self-firing | 66 | 2 |
| borg-link-up | self-firing | 103 | 15 |
| borg-next | self-firing | 4 | 2 |
| borg-plan | self-firing | 24 | 11 |
| borg-recon | folded into borg-link (2026-11-02) | 0 | 0 |
| borg-resume | self-firing | 0 | 0 |
| borg-review | self-firing | 0 | 0 |
| borg-switch | self-firing | 0 | 0 |
| borg-verify | self-firing | 1 | 12 |
| break-glass | slash-only | 0 | 0 |
| fable-reviewer | self-firing | 0 | 0 |
| no-unnecessary-read-perms | retired (2026-11-02) | 0 | 0 |
| pane | self-firing | 0 | 4 |

Retired and folded rows keep their evidence; the skill directories are gone. See "Decisions (Noah, 2026-11-02)".

Typed for borg-link and borg-link-up adds the plugin-prefixed and bare forms (`/borg-collective:borg-link` 35 plus `/borg-link` 31; link-up 90 plus 12 plus 1). Model for `pane` adds the bare and prefixed forms (2 plus 2).

## Per-skill evidence

- **adhd-guardrails**: `skills/adhd-guardrails/SKILL.md` description says "Always active". It is `user-invocable: false`, so the model is the only caller. Zero calls on record because it is always-on guidance, not a typed action. Self-firing.
- **borg-assimilate**: `skills/borg-assimilate/SKILL.md`, heading "Step 0: Run /simplify First" and the review step call `borg-collective-review`. `hooks/pre-commit-remind.sh` tells the model to run `/borg-assimilate` before a commit. Typed 26, model 6. Self-firing.
- **borg-collective-review**: `skills/borg-plan/SKILL.md` heading "Run The Collective Review" and `skills/borg-assimilate/SKILL.md` ("Follow the process defined in the `borg-collective-review` skill") both tell the model to invoke it. Model 30, typed 0. Self-firing, the clearest case.
- **borg-link**: description "Use when the user asks for status, overview, briefing". `skills/borg-switch/SKILL.md` drives `borg link` directly. Typed 66, model 2 (Noah's daily workflow starts at `/borg-link` in the Queen session). Self-firing: the description is aimed at natural-language requests.
- **borg-link-up**: `hooks/borg-link-up.sh` and `hooks/tool-count-nudge.sh` tell the model to run `/borg-link-up`; `bin/borg-usage-watch` sends it by default; `borg.zsh` `_borg_offer_checkpoint` types it into a pane. Typed 103, model 15. A 2026-06 decision already removed `disable-model-invocation` from it (`.borg/knowledge/decisions/20260506-borg-link-agent-invocable.md`). Self-firing.
- **borg-next**: description "Use when the user asks \"what should I work on?\"". No hook instruction. Typed 4, model 2. Thin, so self-firing.
- **borg-plan**: `hooks/borg-link-down.sh` ("Run /borg-plan to establish objectives") instructs the model; the user's memory entry "Auto-run borg-plan in plan mode" says plan mode auto-invokes it. Typed 24, model 11. Self-firing.
- **borg-recon**: description is natural-language triggers ("morning link-up", "catch me up", "recon"). No instruction to the model, no usage on this machine. Thin, so self-firing. Candidate for retirement or merge, see group (a).
- **borg-resume**: `hooks/borg-dispatch-guard.sh` message tells the model "use /borg-resume after the reset", and the description is written for a model-visible failure ("session limit" errors). No usage on record, but the hook is an instruction to the model. Self-firing.
- **borg-review**: `hooks/tool-count-nudge.sh` injects "Run /borg-review to check progress" into the model's context at 75 tool calls. Self-firing despite zero counts.
- **borg-switch**: description is natural-language ("switch to X", "jump to X"), and `docs/agents/commands.md` records its `borg link --local --all --overview` call as the one automated caller of that path. No usage. Thin, so self-firing.
- **borg-verify**: `agents/borg-verifier.md` is "spawned by /borg-verify as a merge gate", and the orchestrator runs it after a nanoprobe finishes (description: "Call after a nanoprobe completes"). Model 12, typed 1. Self-firing.
- **break-glass**: slash-only, and the one judgment call. Typed 0, model 0, and nothing in `skills/`, `agents/`, `hooks/`, `bin/`, `docs/agents/`, `CLAUDE.md` or the user's global files tells the model to invoke it. The body (heading "If You Still Need a Local Exception") is a human-gated flow: explain to the user, then write to `.claude/settings.local.json`, and the user's global rule in `borg-managed.md` ("Never accept project-level permission prompts ... Do not add permissions to project-level settings") says the model should not do that by itself. The counts are thin, which by the rule would mean self-firing. It is slash-only anyway because the downside is asymmetric: a model auto-loading a permission-exception writer is the unwanted failure, while a user who wants it types `/break-glass`. Noah can reverse this by deleting one line.
- **fable-reviewer**: description says "Use when starting a non-trivial change, when a task risks scope creep, or when the user says /fable-reviewer". The model-triggered wording is explicit, no usage on record. Thin, so self-firing.
- **no-unnecessary-read-perms**: already carries `disable-model-invocation: true` on main, so today it is hidden from the listing. Its description says "Always active" and `.borg/knowledge/decisions/20260611-always-on-skill-for-read-perms.md` says it exists because global `CLAUDE.md` entries can be missed, which only works if the model loads it. That is a contradiction (an always-on skill the model cannot load). Left unchanged in this PR; Noah decides whether to drop the flag or retire the skill. Mode recorded as self-firing by intent.
- **pane**: description "Use when the user says \"split the pane\""; the model called it 4 times. Self-firing.

## Listing size, before and after

No existing measure covers the skill listing: `tests/context_budget.bats` caps `skills/borg-link/SKILL.md` and `CLAUDE.md` bytes, and `tests/skill_frontmatter.bats` caps each description at 320 characters, so no pin changes. The model's listing is one line per model-invocable skill: `- borg-collective:<name>: <description>`. Measured from the folded descriptions in the frontmatter, with the same awk the 320-character test uses:

- Before: 15 listed skills, 4,253 characters (about 1,060 tokens at 4 characters per token). `no-unnecessary-read-perms` is already hidden, and this session's own skill listing confirms it is absent.
- After: 14 listed skills, 3,942 characters (about 985 tokens).
- Saving: 311 characters, about 78 tokens on every session that loads the plugin.

No headless `claude -p` run was made: the `system/init` event lists names, not listing text, so a live run cannot measure this number, and `user-invocable` skills are still registered there by design.

## Overlapping scopes: proposed restructures

Proposals only. No description or body is changed in this PR.

### (a) borg-link, borg-recon, borg-next

- Overlap: link says "Use when the user asks for status, overview, briefing, \"what's going on\"". Recon says "Use when the user says \"morning link-up\", \"what changed\", \"catch me up\", \"recon\", or starts a session wanting the lay of the land". Next says "Use when the user asks \"what should I work on?\", \"what's next?\", or wants to know priorities". A request like "what's going on" or "catch me up" matches both link and recon; "what's next" fits link's overview and next's chooser.
- Usage: link typed 66, model 2; next typed 4, model 2; recon 0 and 0. Link is the front door in practice, next is occasional, recon is unused on this machine.
- Proposed restructure: make `borg-link` the single entry point and fold recon into it as a reference file the link skill routes to when the request is "since a mark" or "catch me up" (`skills/borg-link/references/questions.md` already points at `/borg-recon` for the idle-checkpoint case). Keep `borg-next` as a separate chooser because its job (pick one and open it) is a different action. Then delete the "what changed / catch me up / recon" triggers from the recon description or retire the skill. Noah decides; if recon stays, narrowing it to the explicit phrases "morning link-up" and "recon" removes the overlap with link.

### (b) borg-review, borg-collective-review, fable-reviewer, borg-verify

- Overlap: review says "Mid-session diagnostic. Checks progress against the plan, detects scope creep and bad loops ... Use when stuck, scattered, or unsure if you're still building the right thing". Fable-reviewer says "Use when starting a non-trivial change, when a task risks scope creep". Collective-review says "debate a plan or shipping decision ... Can also be invoked directly for ad-hoc design reviews". Verify says "Independent pre-merge evaluator ... re-run tests, map acceptance criteria to diff evidence". Scope creep appears in both review and fable-reviewer; "review" of a plan or change appears in collective-review, fable-reviewer and verify; fable-reviewer's own body escalates to `borg-reviewer` for blind review, which is verify's job.
- Usage: collective-review model 30, typed 0 (called by plan and assimilate); verify model 12, typed 1; review 0 and 0 but a hook nudges it; fable-reviewer 0 and 0.
- Proposed restructure: separate by moment, not by wording. Keep `borg-collective-review` (called by plan and assimilate) and `borg-verify` (merge gate) as they are, since the evidence shows they fire in their own lifecycle slots. Merge `fable-reviewer` into `borg-review`: review owns "during the work" (progress, scope creep, loops, and the five gates as its checklist), and fable-reviewer's start-of-change gates become the first section of review. That removes the shared "scope creep" trigger and one listed description.

## Decisions (Noah, 2026-11-02)

1. **Hide `break-glass`.** Shipped in #481 (slash-only, `disable-model-invocation: true`).
2. **Retire `no-unnecessary-read-perms`.** It was hidden from the model while its description claimed "Always active", so its rule never loaded. The skill directory, its ledger waiver and its docs entries are removed. The permission rule itself lives in the user's global `CLAUDE.md` and `borg-managed.md`.
3. **Fold `borg-recon` into `borg-link`.** `borg-link` is the single entry point: its description gains the recon triggers and its body routes "what changed since a mark" requests to `skills/borg-link/references/recon.md` (the former skill body). The page-painting path is untouched. The `borg recon` CLI and `borg_core/recon/` are unchanged. The only recorded reason against folding, `docs/plans/severed/2026-10-12-borg-recon-reads-the-link-document.md`, is a dropped directive about which sweep recon reads, not a reason to keep a separate skill, and the marker caveat it records still holds on the routed path. `borg-next` stays the chooser.
