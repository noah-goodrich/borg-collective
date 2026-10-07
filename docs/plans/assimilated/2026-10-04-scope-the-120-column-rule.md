# Directive: Scope the 120-column rule to where a line-oriented tool reads the text
*Filed: 2026-10-04*
*Shipped: 2026-10-04 — borg-collective PRs [#260](https://github.com/noah-goodrich/borg-collective/pull/260) and [#265](https://github.com/noah-goodrich/borg-collective/pull/265), claude-plugins#62/#63, dotfiles#20/#21/#22; live 2026-10-04. **Decided by Noah 2026-10-04 (#266)** to accept as done; W2 and W7 were not re-verified by the triage.*

**tl;dr** — "Wrap markdown at 120" is stated in about 20 instruction sites and enforced in 3 places across three
repos, and it is applied to text a renderer reflows (PR bodies, GitHub comments, chat output), where hard wraps render
as ragged lines. Noah ruled 2026-10-04: "none of the text hard wraps in the pr description or elsewhere ... applied
when needed and not universally." This directive inventories every site, states the scoped rule as exact replacement
text, and lists the enforcement that must change so nothing keeps rejecting what the new rule allows. **Nothing is
edited by filing it.** Three repos, three PRs: borg-collective, claude-plugins, dotfiles.

## Why

The rule entered `~/.claude/CLAUDE.md` as a hand-reading convenience for files opened in a terminal. It was then copied
verbatim into skills, a validator recipe, a hook, a test and a project style section, none of which asked "who reads
this text, and does that reader reflow?". The consequence Noah hit: models obey the global rule when writing PR
descriptions (`pr-description` SKILL.md even says it by name), and GitHub shows a hard-wrapped body as short broken
lines. The same wrap was already measured as a defect once, in
`assets/2026-09-28-worktree-identity-retro-evidence.md` (publishing a 120-wrapped file re-wraps the issue into `<br>`
soup).

**Principle: hard-wrap only where a line-oriented tool reads the text; never where a renderer or terminal reflows it.**
Line-oriented tools are `diff`/`git blame`, `grep`, linters and formatters, `git log`, and a human in an editor that does
not soft-wrap.

## Inventory — measured 2026-10-04

I = INSTRUCTION (prose a model reads). E = ENFORCEMENT (code, test, hook or lint that rejects, warns or rewrites).

### Repo: dotfiles (`/Users/noah/.config/dotfiles`)

| # | Location | Kind | Exact wording | Applies to |
|---|----------|------|---------------|------------|
| 1 | `claude/code/CLAUDE.md:11` | I | "Wrap all generated markdown at 120 characters. No line should exceed 120 characters unless it's a URL or code block that can't be broken." | all generated markdown |
| 2 | `claude/code/CLAUDE.md:18` | I | "Markdown/text: hard-wrap at 120 characters. No line may exceed 120 chars." | markdown AND plain text |
| 3 | `claude/code/hooks/post-tool-format.sh:21-25` | E (warn) | `length($0) > 120 ... "WARNING: $FILE has lines exceeding 120 chars (reflow needed)"` | every `*.md` after Edit/Write, fences skipped |
| 4 | `nvim/lua/custom/plugins/overrides.lua:20` | E (visual) | `vim.opt.colorcolumn = '120'  -- visual ruler at 120 chars` | every buffer |
| 5 | `nvim/lua/custom/plugins/overrides.lua:31` | cause | `vim.opt.wrap = false` | every buffer, markdown included |
| 6 | `nvim/lua/custom/plugins/markdown.lua:33` | I (comment) | "Wide research docs are hard-wrapped at 120; let long paragraphs wrap rather than run off the pane." | render-markdown `win_options` |

### Repo: `~/.claude` (deployed, not a repo)

| # | Location | Kind | Note |
|---|----------|------|------|
| 7 | `/Users/noah/.claude/CLAUDE.md:11,18` | I | Regular file (NOT a symlink): lines 1-46 are a byte copy of dotfiles `CLAUDE.md`, plus a `borg-managed` block appended by `borg setup` (merge function in `borg.zsh`, `<!-- BEGIN borg-managed -->`). The rule lives in the dotfiles half, so fix dotfiles and re-run `borg setup`; hand-editing only this copy is overwritten or drifts. |
| 8 | `/Users/noah/.claude/hooks/post-tool-format.sh` | E | Deployed copy of #3 (registered in `~/.claude/settings.json:116`, PostToolUse). Same fix, redeploy. |
| 9 | `.../memory/feedback_no_hard_wrap_rendered_prose.md` + `MEMORY.md:50` | I | Already written 2026-10-04 as an interim, and it names this directive. After the PRs land, edit it to point at the landed CLAUDE.md text instead of "until the directive lands". |

### Repo: borg-collective

| # | Location | Kind | Exact wording | Applies to |
|---|----------|------|---------------|------------|
| 10 | `CLAUDE.md:629` (Style Rules) | I | "All markdown and text files must wrap at 120 characters. No line may exceed 120 chars." | every md/txt in the repo |
| 11 | `skills/borg-link/SKILL.md:18` | I | "Hard-wrap all output at 120 characters." | the model's chat reply from `/borg-link` |
| 12 | `skills/borg-recon/SKILL.md:17` | I | "Hard-wrap all output at 120 characters." | the model's chat reply from `/borg-recon` |
| 13 | `tests/scaffold_supabase_shared.bats:112-115` | E | `@test "scaffold --supabase-shared: CLAUDE.md block wraps at 120 columns"` runs `awk 'length($0) > 120'` | the CLAUDE.md block `drone scaffold --supabase-shared` writes |
| 14 | `pyproject.toml:38,61` | E | `[tool.ruff] line-length = 120`, `[tool.pylint.format] max-line-length = 120` | Python in `borg_core/` (via `make lint`) |
| 15 | `skills/borg-link-up/SKILL.md:126` | descriptive | "a document hard-wrapped at 120 columns" | explains why the engine, not the model, writes the flip mark. Not a rule; leave. |

Descriptive mentions that are NOT rules and need no change (they document that the tree happens to be wrapped, and the
code they sit beside tolerates both styles): `borg_core/link/core.py:595`, `borg_core/link/test_core.py:594`,
`borg_core/link/test_cli.py:227`, `borg_core/planstate/core.py:61,94`, `borg_core/planstate/test_core.py:52`,
`tests/cli_contract.bats:1888`, `tests/state_census.bats:85`, `docs/plans/directives/2026-09-28-worktree-identity-*`,
`docs/plans/directives/2026-09-09-link-up-criteria-reconciliation.md:148`. Every other `120` hit in the tree is an
interval, timeout or count (`StartInterval 120`, `timeout=120`, ...), not a column limit.
**`tests/prose_contracts.bats` has NO line-length check** (it greps for leaks and wording; verified), and the Makefile
`lint` target runs only ruff, mypy and the clean-architecture linter. No markdown line-length lint, `.editorconfig` or
pre-commit config exists in either repo.

### Repo: claude-plugins

| # | Location | Kind | Exact wording | Applies to |
|---|----------|------|---------------|------------|
| 16 | `noah-content-tools/skills/pr-description/SKILL.md:173` | I | "Hard-wrap the body at 120 characters." | **the PR body: the direct cause of Noah's complaint** |
| 17 | `noah-writing-voice/skills/brevity/SKILL.md:86` | I | "13. **No line exceeds 120 characters** except a URL or an unbreakable code span." | every doc the brevity spine touches |
| 18 | `noah-writing-voice/skills/brevity/SKILL.md:97,101` | E (recipe) | `awk 'length > 120 {print FILENAME":"FNR" is "length" chars"}' "$FILE"`; "Any hit from `awk` is a wrap violation" | step 13 mechanical check |
| 19 | `noah-writing-voice/skills/brevity/references/portable-voice.md:129-132` | I | "**13. Hard-wrap generated markdown at 120 characters.** ... This is genre-independent and applies to every file this spine touches." | cites `~/.claude/CLAUDE.md` as its authority |
| 20 | `noah-strategy/skills/strategic-brief/SKILL.md:43` | I | "7. **120-character line wrap.** All generated markdown hard-wraps at 120 characters." | strategic briefs |
| 21 | `noah-strategy/skills/strategic-brief/SKILL.md:113` | I (checklist) | "- [ ] No lines exceed 120 characters" | same |
| 22 | `noah-strategy/skills/strategic-brief/references/framework.md:177` | I (checklist) | "- [ ] All lines <= 120 characters" | same |
| 23 | `borg-collective/skills/{borg-link,borg-recon}/SKILL.md` | I | Same lines as #11, #12 | **BUILD OUTPUT** of borg-collective via `build-plugin.sh`; never edit by hand, regenerate |

Checked and clean (no wrap rule): `noah-content-tools/skills/design-doc/SKILL.md` and its `scripts/validate.sh`,
`linkedin-post`, `snowflake-article`, `noah-writing-voice/skills/brevity` voice rules other than #17-19. The design-doc
validator has no line-length check, so it needs no change.

## Classification — what each surface should do

| Surface | Hard-wrap? | Reader / reason |
|---------|-----------|-----------------|
| Source: py, zsh, sh, lua, bats, yaml | Yes, tool-owned | Diffs, grep and blame are line-based. Python: the formatter and linter decide (ruff/pylint 120 in this repo). zsh/sh/lua/bats have no formatter or linter here, so 120 is a convention, not a gate. Per-language note below. |
| Comments inside source | Yes, at the file's code limit | Same readers as the code beside them. |
| Git commit messages | Yes: subject <= 72 (50 preferred), body 72 | `git log` indents 4 columns and `git format-patch` emails are plain text; this is git's own convention. Ambiguous (see below). |
| PR descriptions, PR/issue comments, review bodies, any `gh` body | **Never** | GitHub renders markdown and reflows paragraphs; a hard newline mid-paragraph becomes a visible break. This is Noah's explicit ruling. |
| Release notes, Slack/Jira/Notion/Linear posts, LinkedIn and article drafts | **Never** | Renderers reflow; hard wraps survive paste as ragged text. |
| Chat replies in the Claude Code terminal | **Never** | The TUI soft-wraps to the pane width. Noah works in tmux panes of varying width; a 120-wrapped reply in a 90-column pane wraps twice and looks ragged. Wrapping adds nothing a terminal does not already do. |
| Markdown in repos (docs, directives, plans, CLAUDE.md, SKILL.md, checkpoints) | **No for new text, once nvim soft-wraps** | GitHub renders them (reflows). The model reads them (does not care). The only line-oriented reader is vim, and the cause is `wrap = false` (#5), a config fault, fixed in dotfiles. Trade-off below. |
| Plain text / logs / `.txt` read in a terminal | No rule | No fixed width is right; leave to the producer. |
| epub / pandoc inputs | **Never** | Pandoc and epub readers reflow; hard wraps add nothing and break `--wrap=none` diffs. |
| Tables, fenced code, URLs | Never wrap | Wrapping breaks them. |

### Trade-offs where the evidence is ambiguous

- **Markdown files in repos.** For hard-wrapping: `git diff` shows one changed sentence as one changed line only if
  paragraphs are wrapped, and a one-line paragraph makes every edit a whole-paragraph diff (`git diff --word-diff`
  recovers it). Against: Noah said "none ... or elsewhere", GitHub and the model both ignore the wrap, and vim is the
  only reader that needs it, which a one-line nvim fix removes. Recommended default follows the ruling: new markdown
  prose is not hard-wrapped. When EDITING an existing wrapped paragraph, match the surrounding paragraph and do not
  reflow neighbors. That keeps diffs honest and is the migration rule below. If Noah would rather keep repo docs
  wrapped for diff quality, only the PR/comment/chat tiers change and rows 1, 2, 10, 17-22 become "wrap markdown
  *files*, never *rendered posts*". That is a smaller edit and a one-line change to the replacement text.
- **Commit messages.** Recent history in this repo is not 72-wrapped (bodies run to ~100 columns) and `git log` through
  `less` wraps visually anyway, so 72 is convention, not need. Recommended: state 72 in the rule and add NO commit-msg
  hook (fewest moving parts). Dropping the commit line from the rule entirely is also defensible.
- **120 for code.** `black` (the user CLAUDE.md names it) defaults to 88, but the hook prefers `ruff format`, which reads
  each project's `pyproject.toml`; borg-collective sets 120, other repos default to 88. So "120" is correct for
  borg-collective Python and wrong as a global number. State the rule as "the project's configured limit; 120 where none
  is configured" and let the tool own it.

## The scoped rule — exact replacement text

### R-global (dotfiles `claude/code/CLAUDE.md`, replaces lines 11 and 18; re-run `borg setup` to refresh `~/.claude/CLAUDE.md`)

Delete line 11 and line 18. Under `## Markdown / Doc Generation` put:

```
- Hard-wrap only where a line-oriented tool reads the text; never where a renderer or terminal reflows it.
  - Never hard-wrap: PR descriptions, PR/issue/review comments, any `gh` body, release notes, chat replies, posts for
    Slack/Jira/LinkedIn, and anything bound for pandoc or epub. Write one line per paragraph or bullet.
  - Markdown files: do not hard-wrap new prose. When editing an existing hard-wrapped paragraph, match its wrap and do
    not reflow neighbors. Never wrap tables, fenced code or URLs.
  - Source code and its comments: the project's configured limit (ruff/pylint/black); 120 where none is configured.
  - Git commit messages: subject <= 72 characters, body wrapped at 72.
```

and under `## Code Style` replace the "Markdown/text" line with: `- Markdown/text: no hard-wrap (see Markdown / Doc Generation).`

### R-project (borg-collective `CLAUDE.md:629`)

Replace "All markdown and text files must wrap at 120 characters. No line may exceed 120 chars." with:

```
- Code and code comments wrap at 120 (ruff/pylint enforce it for Python). Markdown and text prose is NOT hard-wrapped:
  one line per paragraph or bullet. Existing wrapped paragraphs keep their wrap when edited. Commit bodies wrap at 72.
  PR bodies and GitHub comments are never wrapped.
```

### R-skill-output (borg-collective `skills/borg-link/SKILL.md:18`, `skills/borg-recon/SKILL.md:17`)

Replace "Hard-wrap all output at 120 characters." with "Do not hard-wrap output; the terminal soft-wraps." (Chat
output only. The `borg link` Python renderer's own width budget, `PICTURE_BUDGET`, is code and is untouched.)

### R-pr (claude-plugins `pr-description/SKILL.md:173`)

Replace "Hard-wrap the body at 120 characters." with "Do not hard-wrap the body: one line per paragraph and per
bullet. GitHub reflows it; a hard newline mid-paragraph renders as a broken line." The fenced "copy whole" block is
unaffected.

### R-voice (claude-plugins `noah-writing-voice`)

- `brevity/SKILL.md:86`: replace item 13 with "**No hard-wrapped prose.** One line per paragraph or bullet; wrap only
  inside tables, code and URLs." and renumber nothing (keep it item 13 so item 14 references hold).
- `brevity/SKILL.md:97,101`: delete the `awk 'length > 120 ...'` line from the recipe and the "Any hit from `awk` is a
  wrap violation" sentence; add the opposite check for rule 13 if wanted:
  `grep -nE '^[^|`#>*-].{0,80}[a-z,]$' "$FILE"` is too noisy, so do NOT add a mechanical check (a wrong gate is worse
  than none, which is this repo's own lesson about gates that pass by measuring nothing).
- `brevity/references/portable-voice.md:129-132`: replace rule 13 with the same sentence as item 13 above; delete the
  claim that it is "from `~/.claude/CLAUDE.md`" and the "Confirmed by practice" measurements.

### R-brief (claude-plugins `noah-strategy`)

- `strategic-brief/SKILL.md:43`: replace with "7. **No hard-wrap.** Generated markdown is one line per paragraph or
  bullet."
- `strategic-brief/SKILL.md:113` and `references/framework.md:177`: delete the checklist item.

### R-nvim (dotfiles; this is what makes unwrapped markdown readable in the vim side pane)

In `nvim/lua/custom/plugins/overrides.lua` add a `FileType` autocmd for `markdown,text,gitcommit` setting
`wrap = true`, `linebreak = true`, `breakindent = true` (window-local), leaving the global `wrap = false` for code. In
`colorcolumn`, either keep `'120'` for code only (set it per code filetype) or leave it global; it is a ruler, not a
rule. Fix the comment at `markdown.lua:33` ("Wide research docs are hard-wrapped at 120") to "Long paragraphs soft-wrap
(`linebreak`); `breakindent` keeps the indent". `gitcommit` additionally gets `textwidth = 72` so commit bodies wrap
as typed.

## Enforcement changes

| Repo | File | Change |
|------|------|--------|
| dotfiles | `claude/code/hooks/post-tool-format.sh` | **Delete the `*.md` block (lines 19-28).** It only warns (exit 0, never rewrites markdown) but its warning tells the model to "reflow", which reintroduces the hard wrap by instruction. The `.py` `ruff format`/`black` block stays: it is the one real formatter and honors each project's config. Update the header comment. Redeploy to `~/.claude/hooks/`. |
| dotfiles | `nvim/lua/custom/plugins/overrides.lua`, `markdown.lua` | R-nvim above. |
| dotfiles | `claude/code/CLAUDE.md` | R-global. |
| borg-collective | `CLAUDE.md`, `skills/borg-link/SKILL.md`, `skills/borg-recon/SKILL.md` | R-project, R-skill-output. Then `build-plugin.sh` to regenerate the claude-plugins copies (reminder from memory: `--dry-run` falsely flags 5 lib-inlining hooks). |
| borg-collective | `tests/scaffold_supabase_shared.bats:112-115` | Delete the case "CLAUDE.md block wraps at 120 columns" (it enforces only the retired style). If the generated block must stay wrapped for another reason it is not one: the file is markdown the model reads. Check `templates/supabase-shared/` for a hard-wrapped block and leave its existing wrap (migration note), but stop asserting it. |
| borg-collective | `pyproject.toml`, `Makefile lint` | **No change.** They are the correct, tool-owned code limit. |
| borg-collective | `tests/prose_contracts.bats` | **No change needed.** It has no line-length assertion. Do not add one. |
| claude-plugins | `pr-description`, `noah-writing-voice/brevity` (+ `portable-voice.md`), `noah-strategy/strategic-brief` (+ `framework.md`) | R-pr, R-voice, R-brief. |
| claude-plugins | `borg-collective/skills/*` copies | Regenerated from borg-collective, never hand-edited. |
| claude-plugins | design-doc `scripts/validate.sh` | **No change** (no wrap check exists). |
| memory | `feedback_no_hard_wrap_rendered_prose.md`, `MEMORY.md:50` | After the PRs land, replace "until the directive lands" with a pointer to the landed rule. |

Order: dotfiles first (the global CLAUDE.md is what every session reads), borg-collective second, claude-plugins last
(it consumes borg-collective's build output).

## Migration note

Existing wrapped files are **not** rewritten in bulk. Only new text follows the new rule. A bulk reflow of ~200
markdown files would produce an unreviewable diff, destroy `git blame` on every paragraph, and touch machine-edited
documents (`PROJECT_PLAN.md` criteria are flipped by `borg_core.planstate`, which tolerates both shapes by design).
Editing a paragraph inside a wrapped file keeps that paragraph's wrap. If Noah later wants a reflow, do it per file with
`pandoc --wrap=none` or `prettier --prose-wrap never`, one PR per directory, and add the reflow commit to
`.git-blame-ignore-revs`. Not proposed here.

## Acceptance Criteria

- [ ] **W1 — No instruction site still says to hard-wrap prose at 120.** The inventory greps return only the scoped rule
  text, descriptive history and code limits.
  - Verify: `bash -c 'grep -rn -i -E "hard-wrap|wrap (all|at)|120 char|120-char|<= 120" /Users/noah/.config/dotfiles/claude/code /Users/noah/dev/borg-collective/CLAUDE.md /Users/noah/dev/borg-collective/skills /Users/noah/dev/claude-plugins --include=*.md --include=*.sh --exclude-dir=docs --exclude-dir=research --exclude-dir=corpus --exclude-dir=fixtures'` lists no line that instructs wrapping prose.
- [ ] **W2 — The deployed global file matches the source.** `~/.claude/CLAUDE.md` carries the scoped rule, not lines 11
  and 18.
  - Verify: `grep -c "Markdown/text: hard-wrap" /Users/noah/.claude/CLAUDE.md` prints 0 after `borg setup`.
- [ ] **W3 — The markdown-length warning is gone.** Writing a file with a 200-character markdown line produces no
  hook output; a `.py` write is still formatted.
  - Verify: pipe a PostToolUse JSON for a temp `.md` with one 200-char line into
    `/Users/noah/.claude/hooks/post-tool-format.sh` and assert empty stdout; same for a badly formatted `.py` and assert
    it is rewritten.
- [ ] **W4 — No test rejects a long markdown line.** The only wrap-asserting case is deleted and nothing replaces it.
  - Verify: `grep -rn "length(\$0) > 120\|length > 120" /Users/noah/dev/borg-collective/tests` is empty and
    `bats tests/prose_contracts.bats tests/scaffold_supabase_shared.bats tests/state_census.bats` passes.
- [ ] **W5 — Code limits are untouched.** Python lint still enforces 120 in borg-collective.
  - Verify: `make lint` is green in the devcontainer (`drone exec`), and `pyproject.toml` is unchanged in the diff.
- [ ] **W6 — A generated PR body has no mid-paragraph newline.** The `pr-description` skill, run on a real diff, emits
  one line per paragraph and bullet.
  - Verify: run the skill on a branch with a 3-paragraph change and
    `awk 'length > 0' body.md | grep -c .` equals the number of paragraphs plus bullets (no line continues onto the
    next without a blank or list marker), recorded in the PR body.
- [ ] **W7 — Markdown soft-wraps in nvim.** Opening a 400-character-line `.md` in nvim shows it wrapped at a word
  boundary with no horizontal scroll, and a `.py` file still does not wrap.
  - Verify: `nvim --headless -c "set ft=markdown" -c "lua print(vim.wo.wrap, vim.wo.linebreak)" -c q` prints
    `true true`, and the same with `ft=python` prints `false`.
- [ ] **W8 — The claude-plugins copies match their source.** Regenerated, not hand-edited.
  - Verify: `diff -r` of `borg-collective/skills/borg-link` against `claude-plugins/borg-collective/skills/borg-link`
    is empty after `build-plugin.sh`, and `claude-plugins` CI is green.
- [ ] **W9 — Existing wrapped files are unchanged.**
  - Verify: `git diff --stat main` shows no markdown file touched except those named in this directive.

## Scope Boundaries

- NOT reflowing any existing markdown (migration note).
- NOT changing `ruff`/`pylint` limits, the `borg link` renderer width budget, or any tmux/terminal config.
- NOT adding a commit-msg hook or a markdown linter. Fewest moving parts: the rule is prose plus one editor setting.
- NOT editing the interim memory file until the PRs land.
- If done early: ship, don't expand.

## Ship Definition

Three PRs, dotfiles then borg-collective then claude-plugins, each describing the rule in one paragraph (unwrapped, per
the rule), CI green on the two repos that have CI, W3 and W7 recorded in the dotfiles PR body.

## Risks

- **The model keeps wrapping from habit.** The wording lives in prose, so it is in the 70-90% compliance band. The
  PR-body case is the one Noah sees; W6 measures it once. If it recurs, escalate to a `PreToolUse` WARNING on
  `gh pr create/edit/comment` bodies containing mid-paragraph newlines (the `bash-guard.sh` surface), never a rewrite.
- **Mixed styles inside a repo.** New unwrapped paragraphs beside old wrapped ones is the accepted cost of no bulk
  reflow.
- **`~/.claude/CLAUDE.md` drift.** It is a copy, not a symlink; fixing only one of the two files reverts on the next
  `borg setup`. W2 is the guard.
- **Soft-wrap in `render-markdown` mode.** Window options there set `breakindent` and `showbreak`, not `wrap`; the
  R-nvim autocmd must run after plugin load or the plugin's `win_options` can mask it. W7 checks the effective value.
