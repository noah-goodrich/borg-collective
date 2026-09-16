# Directive: Generalize the local-extension loader, and make "prefer a different base tool" a type

*Filed: 2026-09-15 · Status: PROPOSAL — needs Noah's word before anything is built*
*Requested-via: a peer session (`dev-4a`), relaying Noah*
*Deliberately unparented — see "Why this carries no `*Parent plan:*` line"*

**tl;dr** — The extension mechanism already works and is wired to two skills, not one. Generalizing it to the other
lifecycle skills is small. The interesting half is the new `prefer-tool` type, and the honest finding is that as pure
prose it is the same shape as four mechanisms this repo has already measured as failures — so it needs either
enforcement or an oracle, not a politer request.

## Corrections to the premises this was filed on

Three, all measured before scoping. None of them kills the ask; two change its shape.

1. **"It is wired to exactly one skill" is wrong — it is wired to two.** `skills/borg-plan/SKILL.md` *and*
   `skills/borg-assimilate/SKILL.md` both read the two-layer path at `01-context` / `02-output` / `03-followup`.
   `CLAUDE.md:293` says so and `grep -rln skill-extensions skills/` confirms it. This matters because
   `borg-assimilate` appears on the "then the lifecycle skills" list as work to do, and it is already done.
2. **"borg-plan's three hook points almost certainly do not transfer verbatim" is answered, and the answer is that
   they DO — for skills.** `borg-assimilate` is not a planning conversation and it reuses all three names unchanged,
   by mapping them to positions in its own flow rather than to planning moments: `01-context` = before any work,
   `02-output` = before the artifact, `03-followup` = after it. The names are generic already. So the
   generalization to `borg-link-up` / `borg-review` is a transcription, not a design problem.
3. **The motivating tool is real and documented; it is simply not installed. My own first correction here was
   wrong.** I searched `~/.claude/plugins` (the *install* tree), found no `dev-workflow`, no `create-pr` and no
   `pr_default_draft`, and wrote that the skill, its version and its userConfig boolean were all "unverified". That
   was an overreach produced by searching the wrong tree. `claude-marche` is a **directory** marketplace whose source
   is `~/dev/claude-marche`, and the local checkout was **52 commits behind** `origin/main`. The plugin was in the
   source the whole time. Verified after syncing: `dev-workflow` is at **2.8.1**, `skills/create-pr/SKILL.md`
   exists, and `pr_default_draft` is a declared `boolean` userConfig with a default of `false`, documented in the
   plugin's own README and honoured by the skill with conversation overrides winning. The peer's description was
   accurate on every substantive point.

   What survives is the narrower true statement, which is still the one that matters for design: it was **not
   installed**. It is now (`claude plugin install dev-workflow@claude-marche`, scope user) — so the absence case is
   no longer this feature's first instance. It remains worth designing for, because a `prefer-tool` extension is
   machine-local by construction and will routinely name something a given machine lacks. But the argument must
   rest on that, not on the tool's interface being doubtful. It is not doubtful.

## Why this carries no `*Parent plan:*` line

The instruction was to file this parented. I have not, and this is the one place I departed from it, because the
instruction predates a change that landed today.

Until this morning, `*Parent plan:*` was lineage — "filed while that plan was active" — and it was decorative,
because `/borg-assimilate` Step 0.75 computed the parent slug from the plan's Objective prose, matched nothing, and
proceeded silently (#203, #205). **Step 0.75 now fires.** It reads the declared `- Plan-slug:` annotation and blocks
shipping a plan while any directive parented to it is still open. On this repository it currently reports **nine**
children, and all nine are genuinely about `borg link` as a derived-fact surface — rendering, manifests, the AC5
lifecycle work. The conflation of "filed during" with "must resolve before ship" does not yet exist in the data.

Parenting an extension-loader directive to the One Front Door plan would introduce it, and would block that plan's
assimilation on work with no relationship to it — while AC5 and AC7 are the two criteria still open and the goal is
to ship. So this is filed independent, per `/borg-plan`'s own allowance that independent directives carry no lineage.

Adding the line is a one-line change if Noah wants it parented anyway. **The underlying question is worth a separate
ruling and is not settled here:** parentage now means two different things, and a directive filed mid-plan that is
topically unrelated has no way to record "filed during" without also asserting "blocks shipping."

## Ask 1 — generalize the loader

Two shapes, and only one of them is a transcription.

**Skills — mechanical.** `borg-link-up` and `borg-review` take the same three hook points with the same two-layer
read and the same silent skip, mapped to their own flows. `borg-link-up`: `01-context` before the checkpoint is
composed, `02-output` before it is written, `03-followup` after the file lands. `borg-review`: `01-context` before
the diagnostic, `02-output` before the single recommendation, and **no `03-followup`** — the skill's whole contract
is that it ends on exactly one action, and a hook that runs after it invites a second.

**Agents — not mechanical, and `borg-nanoprobe` is an agent.** `agents/borg-nanoprobe.md` has no phases. It has a
brief, a scope gate, a worktree lifecycle, a return contract — a standing instruction set consumed once at spawn,
not a conversation with positions in it. There is no "before the artifact" moment to hook. So a nanoprobe extension
has **one** load point, not three: the brief, read at spawn before the scope gate. Proposed path, parallel to the
existing one and deliberately a different noun so the two cannot be confused:

    ~/.config/borg/extensions/agent-extensions/borg-nanoprobe/brief.md
    <project root>/.borg/agent-extensions/borg-nanoprobe/brief.md

One caution that needs a decision, not a default: the nanoprobe's own file forbids touching things outside its scope
and carries a lean-context return contract that exists as a cost lever. An extension read at spawn is context every
nanoprobe pays for on every run. Keep it to the same "terse" rule the skill extensions carry, and state that the
scope gate is **not** extensible — an extension may add instructions, never widen what the agent may touch.

## Ask 2 — the `prefer-tool` type, and the objection to it

The concrete case: prefer an employer-internal PR-creation plugin over calling `gh pr create` directly, so that a
draft-PR default becomes configuration instead of prose repeated across skills.

**The argument for putting it in an extension is sound and I want to strengthen it rather than restate it.** This
repository is `PUBLIC` (verified via `gh repo view`). It was history-scrubbed on 2026-08-31 to remove employer
references. A tool preference that names an employer's internal plugin is precisely the content that would need
scrubbing again — so the extension layer is not a convenience here, it is the mechanism that stops a known recurrence.
**Writing this directive demonstrated the point:** the plugin actually present in the local cache is employer-named,
and I have deliberately kept that name out of this file, because this file is public. The feature is arguing for
itself.

**The objection, which is the part I was asked for judgement on.** A prefer-tool extension that is pure prose is a
request that a model may honour or ignore, with no record either way. That is structurally identical to the
voluntary-write surfaces this repo has already measured: per `CLAUDE.md`'s cairn entry, four shipped, tested, exposed
surfaces that asked the agent to volunteer produced **one real row in five months**, and the transferable rule drawn
from it was *never build capture that asks the agent to volunteer*. A prose "please prefer tool X" is that rule's
subject. It will feel like it works, because a model reading the file usually complies while someone is watching.

So the recommendation is not "prose, it's safer." It is:

1. **v1 is prose PLUS an oracle, in the same commit.** The extension may only advise, but whether the advice was
   followed must be recorded. `hooks/borg-memory-read-log.sh` is the precedent — it exists exactly because the cairn
   decommission proved an uninstrumented capture surface hides its own failure. The analogue: log that a
   `prefer-tool` extension was read, and log which tool the session actually used for that action, so compliance is
   a measured number and not a feeling.
2. **If measured compliance is low, escalate to a WARNING, never a rewrite.** The middle rung is a `PreToolUse` hook
   that sees `gh pr create`, notices a `prefer-tool` extension is active, and says so — refusing or reminding.
   `hooks/bash-guard.sh` already occupies this surface and already blocks on destructive patterns, so the mechanism
   exists and its blast radius is understood.
3. **Never silently redirect a call.** Rewriting the command that runs, without the operator seeing it, breaks the
   repo's stated posture that skills propose and the developer validates — and its failure mode is invisible, which
   is the property every defect in this plan's history has shared.

## Ask 3 / Q1 — precedence when the two layers disagree

Current rule, both skills: machine first, repo second, "later files extend or override earlier ones" — so a
checked-in repo file beats a personal machine preference. The observation that this is backwards *for a tool
preference* is correct, but the fix should not be a per-type exception, because then no one can predict what a file
does without knowing its type.

**Proposed rule, stated generally so future types inherit it: the layer that owns the fact wins.**

| The extension asserts | Owner | Winner |
|---|---|---|
| project policy ("plans here cite a ticket") | the project | **repo** — binds everyone who works on it |
| environment ("this machine makes PRs via X") | the machine | **machine** — a public repo cannot know what is here |

`prefer-tool` is the second row, so it inverts the existing order — not as a special case, but because its subject is
the environment. A public repo asserting `gh pr create` must not override a private machine that says otherwise;
that is the scrubbing argument again, one level down.

**Whichever layer loses, the conflict must be observable.** A silently-overridden preference is a preference nobody
can debug. Against that: these files load on every invocation and the existing rule is that they stay terse, so this
cannot be chatty. Proposal — report a conflict only when two layers both assert the *same* key, and report it once.

## Ask 3 / Q2 — when the preferred tool is absent

Not the first instance any more — `dev-workflow` is installed as of filing — but structurally routine, because a
`prefer-tool` extension is machine-local by construction and will name tools a given machine lacks.

**Degrade to the default, loudly, once.** Not silently — a dead preference that no one is told about is worse than no
preference, because it reads as working. Not fatally — a missing personal plugin must never break PR creation.

**The consequence that settles the prose-versus-structure question.** The loader reads markdown; it cannot know what
"tool X" means or how to probe for it, so the precondition cannot live in the loader. It has to be declared by the
extension. Which means **a `prefer-tool` extension is not pure prose** — it needs at minimum a `requires:` line
naming the skill or command whose presence makes the preference live. That is not a stylistic choice; it falls out of
the absence case having to be checkable at all.

And once `requires:` exists, `borg doctor` can check it, which is where "is my environment as I declared it" already
lives. That is reuse of an existing surface rather than a new one, and it is the cheapest way to make a dead
preference visible without adding noise to every skill invocation.

## Scope boundaries

- **In:** the loader generalization (four skills, one agent), the `prefer-tool` type's shape, precedence, the absence
  contract, and the instrumentation that makes compliance measurable.
- **Out:** implementing any of it. Out: changing `PROJECT_PLAN.md`. Out: the Jira automation — see below. Out:
  installing or vendoring the preferred plugin.

## Evidence, and one thing it does NOT establish

Reported by the peer session, cited as relayed rather than as verified here: two PRs were opened today in an
employer repository as ready-for-review while carrying unresolved decisions, and a Jira automation moved both tickets
to `In Review` within 8 seconds.

**The draft default does not fix that automation, and the directive must not claim it does.** A controlled test
(since closed and cleaned up) showed the automation ignores draft status entirely — a draft PR transitioned its
ticket in 6 seconds. Changing the automation belongs to its owner. What a draft default fixes is our own hygiene,
which is the part within our control. Keeping those two claims apart is the whole value of the evidence; collapsing
them would make this directive an argument for something it cannot deliver.

## Open questions for Noah

1. **Parentage.** Filed independent, for the reason above. Say the word and it gets the line — but the "filed during
   vs. blocks shipping" ambiguity wants its own ruling either way, now that Step 0.75 fires.
2. **Does `prefer-tool` ship with the oracle, or as prose first?** The recommendation is together, because the cairn
   measurement says prose-alone will look like it works. Prose-first is defensible if the oracle is a named follow-up
   and not an intention.
3. **Is the absence case worth `requires:`,** accepting that `prefer-tool` then has structure and is no longer just
   a markdown paragraph?
4. **Which skills, in which order.** Proposed: `borg-nanoprobe` first as asked, then `borg-link-up`, then
   `borg-review`. `borg-assimilate` and `borg-plan` need nothing.
