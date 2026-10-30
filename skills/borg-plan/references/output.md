## Output

### Local Extensions: 02-output

Before writing `PROJECT_PLAN.md`, check for local extension files. Read each file below that exists
and treat its contents as additional instructions for shaping the plan being written. Read in
order; later files extend or override earlier ones.

1. `~/.config/borg/extensions/skill-extensions/borg-plan/02-output.md`
2. `<repository root>/.borg/skill-extensions/borg-plan/02-output.md`

**Precedence has one exception, and it inverts the order:** a file declaring `- Prefer-tool:`
asserts something about THIS MACHINE, so when both layers declare it the MACHINE layer wins.
Everything else is repository policy and the repository layer wins. Full rules: `docs/extensions.md`.

If neither exists, skip silently.

After the conversation, write `PROJECT_PLAN.md` in the repository root.

**`- Plan-slug:` is the plan's own name for its archived copy, and it is chosen HERE — once, by a
person, at plan time.** It is `<established-date>-<short-slug>`, where the short slug is a 3-6 word
human condensation of the objective, not a slugification of it. Confirm it with the developer
alongside the acceptance criteria. Every later consumer READS this line: `/borg-plan`'s own
follow-up-directive section below, `/borg-assimilate` Step 0.75's child-directive gate, Step 5's
archival path, and `borg_core.manifest.cli resolve`, which uses it to pick a manifest when a
repository declares more than one. Omit it and Step 0.75 stops the assimilation rather than
guessing.

Why it is stored and not computed: an archived filename is a condensation, and there is no function
from prose to condensation. Measured 2026-09-15 on this repository, the instruction to derive
`<established-date>-<slugified-objective>` produced
`make-borg-link-the-single-front-door-that-answers-from-a-clean-read-of-derived-fact-...` against a
real slug of `2026-08-24-one-front-door-link-derived-fact-surface`. Three separate places carried
that derivation, so the gate that searched and the step that wrote agreed with each other and
disagreed with every file on disk.

```markdown
# Project Plan: [Project Name]
*Established: [date]*

- Plan-slug: `[date]-[short-slug]`

## Objective
[confirmed 1-2 sentences]

## Acceptance Criteria
- [ ] Criterion 1
  - Verify: [command or check]
- [ ] Criterion 2
  - Verify: [command or check]

## Scope Boundaries
- NOT building: [thing 1]
- NOT building: [thing 2]
- If done early: Ship, don't expand.

## Ship Definition
[specific steps]

## Timeline
Target: [date or "this session"]
Estimated effort: [sessions/hours]

## Risks
- [Risk 1]
- [Risk 2]
```

### Scaffold the project manifest

Immediately after writing `PROJECT_PLAN.md`, scaffold the manifest. Unconditional — not an offer,
not a question, and not something the developer opts into:

```
command -v borg | xargs readlink -f | xargs dirname
PYTHONPATH=<that dir> python3 -m borg_core.manifest.cli scaffold \
    --repository <repository root> --name <the Plan-slug> --desc "<the confirmed Objective, one line>"
```

- **`--name` is the `- Plan-slug:` you just declared**, byte for byte. Same string, same session.
- **Never pass `--apex`.** A plan has no PR yet. Rows arrive at link-up, which is the ratified split.
- **Scaffold picks the folder, and you tell the developer which and why.** A new manifest always goes in
  `.stacks/`, the one manifest root (`.borg/chains/` and `.borg/programs/` are no longer read, and scaffold
  refuses to create inside a `.stacks/` that git ignores). When it creates one, the output
  ends with `root: <folder> (<reason>)`; relay it in one sentence. An `exists:` line means nothing was created;
  say so instead. Do not choose the folder yourself.
- **`--root stacks` is the only override**, and it is the default anyway. `--root borg` is refused by name.
- **It never clobbers.** `scaffold` is idempotent: an existing manifest is reported at exit 0 and
  left untouched. Re-running `/borg-plan` on a repository that already has one is the ordinary case.
- **A non-zero exit is reported, never worked around.** Say what failed and carry on writing the
  plan. Do not hand-write a manifest, and do not retry with a different `--name`.

## Local Extensions: 03-followup

After `PROJECT_PLAN.md` is written, check for local extension files. Read each file below that
exists and treat its contents as additional instructions for follow-up actions (e.g. linking the
plan to an external ticket). Read in order; later files extend or override earlier ones.

1. `~/.config/borg/extensions/skill-extensions/borg-plan/03-followup.md`
2. `<repository root>/.borg/skill-extensions/borg-plan/03-followup.md`

**Precedence has one exception, and it inverts the order:** a file declaring `- Prefer-tool:`
asserts something about THIS MACHINE, so when both layers declare it the MACHINE layer wins.
Everything else is repository policy and the repository layer wins. Full rules: `docs/extensions.md`.

If neither exists, skip silently.
