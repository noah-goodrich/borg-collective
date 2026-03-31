# How to Ship Like Boris (and Not Lose Your Mind)

*An ELI5 guide to parallel AI-assisted development, adapted for developers with ADHD.*

---

## Part 1: The Boris Way

Boris Cherny created Claude Code. He ships twenty to thirty pull requests per day. Not typo fixes — real
features, refactors, and bug fixes across production codebases. Here is how he does it.

### The setup

Boris opens his terminal. He has one repository but five copies of it, each on a different git branch.
These are called *worktrees* — they share the same git history but each has its own working directory,
so changes in one don't affect the others.

He starts Claude Code in each worktree. Five terminals. Five independent AI sessions. Five parallel
streams of work.

### The workflow

Boris doesn't type code. He describes what he wants and Claude writes it. But he doesn't just say "build
me a thing" — he's specific about what he wants, how to verify it works, and when to stop.

**Step 1: Plan before you build.** For anything non-trivial, Boris enters Plan Mode (Shift+Tab in Claude
Code). Claude produces a detailed plan. Boris reads it, asks questions, adjusts scope. Only when the plan
is solid does he tell Claude to execute. This prevents Claude from running off in the wrong direction and
burning tokens on work you'll throw away.

**Step 2: Give Claude a way to check its own work.** This is the single highest-impact habit. Tell Claude
"run the tests after you make changes" or "here's what the output should look like." When Claude can
verify its own work, quality improves two to three times. Without verification, Claude produces code that
*looks* right but has subtle bugs.

**Step 3: Review everything.** Boris treats Claude like a junior developer. The code it writes is a first
draft, not a final product. He reads diffs, questions decisions, and pushes back when something feels
wrong. Claude is fast but not always right.

**Step 4: Ship small.** Each worktree produces one focused PR. Not a mega-PR that touches forty files —
a small, reviewable change that does one thing. This is why five parallel worktrees produce thirty PRs:
each one is small enough to ship in an hour.

**Step 5: Automate the repetitive parts.** Boris's core insight: "If you do something more than once a
day, make it a skill." Skills are reusable instruction files that tell Claude how to handle specific
tasks. Instead of re-explaining your testing conventions or code style every session, you encode it once
and it applies automatically.

### The tools Boris uses

These are all built into Claude Code — no external tools required:

| Tool | What it does | When to use it |
|------|-------------|---------------|
| Plan Mode (Shift+Tab) | Claude plans without executing | Complex tasks, unfamiliar code |
| `/simplify` | Three parallel agents review your code | After implementation, before PR |
| `/checkpoint` | Saves a summary of current progress | Before breaks, before context gets long |
| Skills (SKILL.md) | Reusable instructions for Claude | Patterns you repeat daily |
| Hooks | Scripts that run on session events | Automatic logging, notifications |
| Git worktrees | Parallel isolated branches | Running 3-5 sessions simultaneously |

### Why this works

The bottleneck in software development is no longer typing code. It's making decisions, reviewing output,
and maintaining context across parallel streams. Boris's workflow is optimized for decision throughput:
Claude handles the mechanical work, Boris handles the judgment calls.

At any given moment, two or three of his five sessions are working independently (running tests, writing
code, waiting for builds). He context-switches to whichever one needs a decision right now. The
parallelism means he's never blocked.

---

## Part 2: The Cognitive Load Problem

You read Part 1 and thought: "That sounds amazing." Now imagine maintaining a mental model of five
parallel sessions — what each one was doing, where it left off, what it needs from you, whether the
approach is still right — while also doing the actual engineering work of reviewing code, making design
decisions, and shipping features.

That mental model is your cognitive baseline. It's the overhead you carry before you do anything
productive. And it grows with every session you add.

### The universal tax

Research on context-switching (Gloria Mark, UC Irvine) shows it costs developers twenty-three minutes to
fully re-engage after an interruption. That number was measured on the general population, not a clinical
sample. Every developer managing parallel AI sessions pays this tax on every switch. Five sessions means
five potential twenty-three-minute penalties per day, even if you're organized about it.

Working memory — the number of things you can hold in your head simultaneously — is limited to roughly
seven items for most people (Miller's Law). If four of those slots are consumed by "where was I in cairn,
what's the borg PR status, did I respond to the wallpaper-kit question, is the snowflake migration
safe" — you have three slots left for the actual problem you're trying to solve. That's not an ADHD
problem. That's a math problem.

### The specific risks

**Decision fatigue.** Five sessions are waiting for input. Which one do you attend to first? Research on
decision fatigue (Baumeister) shows that decision quality degrades after sustained cognitive effort —
for everyone, not just neurodivergent individuals. Each pending decision consumes a finite resource.
By afternoon, you're making worse choices about code architecture because you spent the morning making
triage decisions about which session to attend to.

**No exit criteria.** You start refactoring one module. An hour later, you're deep in a rewrite. Claude
never tells you to stop. It never says "this is good enough, ship it." It will keep refactoring forever
because it has no concept of diminishing returns. Without explicit acceptance criteria, work expands to
fill the available time and attention — Parkinson's Law applied to AI-assisted development.

**No natural stopping points.** Terminal sessions don't have "closing time." There's no bell at 6 PM.
Without explicit boundaries, work bleeds into evenings. This feels productive in the moment because
you're shipping code, but sustained overwork without recovery leads to the burnout pattern documented
in the Maslach Burnout Inventory: emotional exhaustion, then cynicism, then reduced effectiveness.
The insidious part is that this happens gradually — you don't crash one day, you slowly get worse over
weeks.

**The slow bleed.** This is the version of the problem that's hardest to detect. Developers with ADHD
experience these issues acutely and obviously — the hyperfocus crash, the decision paralysis, the
addiction pattern. Neurotypical developers experience the same underlying problems but as a slow erosion:
slightly worse decisions each week, slightly less enjoyment, slightly more dread about the backlog of
sessions waiting for attention. By the time it's noticeable, it's been going on for months.

Clinical researchers have developed the AI Addiction Scale (AIAS-21), measuring compulsive use, craving,
tolerance, and withdrawal from generative AI tools. While the most acute patterns correlate with
impulsivity traits, the "I use AI longer than I intend" and "I feel anxious about unfinished AI sessions"
items apply broadly to anyone managing persistent parallel sessions.

### What this means for tooling

The fix is not "be more disciplined." Discipline is a depleting resource — you spend it down throughout
the day. The fix is external scaffolding: systems that reduce the cognitive baseline so your actual
working memory is available for actual work.

Specifically:
- **Fewer active sessions means fewer decisions.** A capacity limit isn't a constraint — it's a
  cognitive relief valve.
- **Persistent context means less re-derivation.** If the tool remembers where you were, you don't
  have to. That frees working memory slots.
- **Explicit acceptance criteria mean clear stopping points.** "Done" is defined before you start, not
  negotiated while you're deep in implementation.
- **Automatic debriefs mean zero-cost session handoff.** When you come back tomorrow, context is
  waiting for you. No twenty-three-minute ramp-up.
- **One recommendation means no decision required.** "What should I work on?" gets one answer, not
  a list of five options ranked by six criteria.

These aren't accommodations for a specific condition. They're cognitive infrastructure for sustainable
AI-assisted development. Developers with ADHD or other neurodivergent conditions will feel the benefit
immediately. Everyone else will feel it after a few weeks of carrying the baseline without scaffolding.

---

## Part 3: A Day with Borg

This is the workflow that Borg is designed to enable. It takes Boris's parallel session approach and adds
the external scaffolding that makes it sustainable: boundaries, recommendations, shipping discipline,
and persistent context that survives across sessions.

### Morning

You open Ghostty. You type `borg init`.

Borg starts an orchestrator — a Claude session that knows about all your projects. It reads the debriefs
from your last sessions (stored automatically when each session ended) and presents a morning briefing:

```
Good morning. Here's where things stand:

  api-service (last active: yesterday, 4:30 PM)
    Objective: Add rate limiting to public endpoints
    Status: Tests passing. PR ready for review.
    Next step: Open PR and merge.

  web-dashboard (last active: yesterday, 6:15 PM)
    Objective: Migrate charts from D3 to Recharts
    Status: 3 of 5 chart components migrated.
    Next step: Migrate the remaining two components.

  data-pipeline (last active: 3 days ago)
    Objective: Add retry logic for failed Snowflake queries
    Status: Blocked — need to decide on backoff strategy.
    Next step: Resume and pick a strategy.

  3 projects active. Capacity limit: 3. You're at capacity.

  I'd recommend starting with api-service — the PR is ready to merge.
  That frees up a slot for new work.
```

You say: "Spin up api-service and web-dashboard."

Borg runs `drone up api-service` and `drone up web-dashboard`. Containers start. tmux windows appear.
You're ready to work.

### Working on a project

You switch to the api-service window. You type `drone claude api-service` to start a Claude session
inside the project's container.

Claude starts with context from your last session — the debrief that was automatically generated when
you stopped yesterday. It knows you were adding rate limiting. It knows the tests pass. It knows the
next step is to open a PR.

You say: "Open the PR for rate limiting." Claude does it. You review. You merge. Done.

One project shipped. Capacity freed.

### Switching context

You press `Ctrl+Space >`. Borg's hotkey. It checks what needs attention next and switches your tmux
window to that project. No decision required — borg already figured out the priority.

You land in the web-dashboard window. A brief status appears in the tmux status bar:
"web-dashboard | Migrate charts — 3 of 5 done."

You start your Claude session. Context from yesterday loads automatically. You pick up where you
left off.

### Establishing goals (the shipping discipline)

For a project that doesn't have defined goals yet, you run `/borg-plan` inside the Claude session.
It doesn't ask you to think through everything from scratch — it reads the codebase, proposes goals
and criteria, and asks you to confirm or adjust:

```
I've looked at the project. Here's what I think we're building:

  Objective: Migrate all chart components from D3 to Recharts

  Does that sound right, or would you frame it differently?
  → "That's right."

  Here's what I'd suggest for acceptance criteria:
    1. All 5 chart components render identically with Recharts
    2. No D3 imports remain in the codebase
    3. Existing tests pass without modification
    4. Bundle size doesn't increase by more than 10%

  Anything to add or change?
  → "Add: tooltips and hover states work the same as before."

  ✓ Added. For shipping, I'd suggest:
    • PR opened against main
    • Visual review of all 5 charts in staging
    • Tests green in CI

  Does that capture 'shipped' for this?
  → "Yes."

  Timeline: you have 2 components left, ~30 min each based on the first 3.
  Reasonable to finish this session?
  → "Yes."

  Locked. I'll hold you to these criteria and flag if we drift.
```

Claude did the thinking. You validated. The project has a contract now — Claude knows when to stop,
and you know when to stop.

### Checking shipping progress

Later, you run `/borg-ship`:

```
Checking acceptance criteria for web-dashboard...

  ✓ 5 of 5 chart components migrated to Recharts
  ✓ No D3 imports found in codebase (grep confirmed)
  ✓ All existing tests pass
  ✗ Bundle size check: not measured yet
      → Run: npm run build && du -sh dist/
  ◐ Tooltips and hover states: 4 of 5 verified, PipelineChart not checked
      → Open PipelineChart in staging and verify hover behavior

  3 of 5 criteria fully met. 2 need quick verification.
  These are checks, not implementation work — should take <10 minutes.
```

No scope creep. No "while we're here, let's also..." The criteria are locked.

### Session end

When you're done working on a project, the session ends (you type `/exit` or close the terminal). Borg's
stop hook fires automatically. It runs a deep analysis of your session transcript using Claude Sonnet and
produces a structured debrief:

```
Session debrief: web-dashboard (2026-03-30, 2:15 PM)

Objective: Migrate chart components from D3 to Recharts
Outcome: All 5 components migrated. 3 of 5 acceptance criteria verified.

Decisions made:
  - Used Recharts ResponsiveContainer instead of D3 resize observer
    Reasoning: Simpler API, handles window resize natively, fewer lines of code
  - Kept D3 color scales as a standalone utility (no Recharts equivalent)
    Reasoning: D3-scale is 4KB and already depended on by non-chart code

Next steps:
  - Verify bundle size (run npm run build && du -sh dist/)
  - Check PipelineChart tooltips in staging
  - Open PR once checks pass

Blockers: None
```

This debrief is stored automatically. Tomorrow's orchestrator will read it. The next Claude session in
this project will have it as context. You don't have to remember anything.

### End of day

You press `Ctrl+Space >` one more time. Borg says: "All clear. Take a break."

If it's after your configured work hours and you try to switch to a work project, borg asks: "It's
10:30 PM. api-service is a work project. Switch anyway? [y/N]". One keystroke of friction. Not a wall —
a speed bump.

---

## Part 4: The Tool Map

Every step in the workflow above maps to a specific tool. Some are built into Claude Code. Some come
from the community. Some are built into Borg. The goal is that you never have to build or remember
the plumbing — borg handles it.

### Boris's native techniques (built into Claude Code)

| Technique | How to use it | Why it matters |
|-----------|--------------|---------------|
| Plan Mode | Press Shift+Tab before complex tasks | Prevents Claude from running off in wrong direction |
| Verification | Say "run tests after changes" | 2-3x quality improvement |
| `/simplify` | Run after implementation | Three parallel agents review efficiency, correctness, maintainability |
| `/checkpoint` | Run before breaks | Saves progress summary for context recovery |
| `/compact` | Run when context gets long | Compresses conversation without losing key details |
| Skills | Create SKILL.md files | Encode patterns you repeat daily |
| Hooks | Scripts in ~/.claude/hooks/ | Automatic actions on session start, stop, notification |

### Community tools (install once)

| Tool | Install | Purpose |
|------|---------|---------|
| Boris's 57 tips | `/plugin marketplace add alirezarezvani/claude-skills` | Complete workflow framework as a skill |
| Scope Guard | Same marketplace plugin | Prevents scope creep by cross-referencing against project scope |
| Engineering bundle | Same marketplace plugin | 26+ skills for architecture, QA, DevOps |

### Borg tools (this project)

| Command | What it does | What problem it solves |
|---------|-------------|----------------------|
| `borg init` | Launches orchestrator with morning briefing | "What should I work on?" |
| `borg claude` | Opens/resumes orchestrator session | Re-enter orchestrator after stepping away |
| `borg next` / `Ctrl+Space >` | Switches to most pressing project | Decision paralysis elimination |
| `borg ls` | Dashboard of all projects | "What's the state of everything?" |
| `/borg-plan` | Skill — Claude proposes, you validate | Establishes locked acceptance criteria |
| `/borg-ship` | Skill — evaluates criteria with evidence | "Am I done? Can I ship?" |
| `borg search` | Queries cairn knowledge graph | "Have I solved this before?" |
| `drone up/down` | Start/stop project containers | Container lifecycle |
| `drone claude` | Launch Claude in project container | "Start working on this project" |
| `/adhd-guardrails` | Always-on skill | Scope discipline, break reminders, shame-free language |
| `/checkpoint-enhanced` | Manual skill | Structured session summary with next-session entry point |
| `/borg-debrief` | Automatic (stop hook) | Deep session analysis persisted for future sessions |

### How they compose

```
┌─────────────────────────────────────────────────────────────────┐
│  You (developer)                                                │
│                                                                 │
│  "What should I work on?"  →  borg init / borg next             │
│  "Start this project"      →  drone up + drone claude           │
│  "What am I building?"     →  /borg-plan (sets criteria)        │
│  "Am I done?"              →  /borg-ship (checks criteria)      │
│  "Have I done this before?" → borg search (queries cairn)       │
│  "I'm done for now"        →  /exit (debrief runs automatically)│
│  "What's next?"            →  Ctrl+Space > (switches window)    │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  Borg (orchestrator)        Drone (project lifecycle)           │
│  - Morning briefing         - Container up/down                 │
│  - Priority scoring         - tmux window management            │
│  - Work/life boundaries     - Claude session launching          │
│  - Knowledge persistence    - Pane layout (3-pane dev setup)    │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  Claude Code (the AI)       Cairn (knowledge graph)             │
│  - Plan Mode                - Decisions + reasoning             │
│  - Code generation          - Patterns + gotchas                │
│  - Verification loops       - Session debriefs                  │
│  - Skills + hooks           - Vector search across history      │
│  - /simplify review         - Cross-project knowledge           │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  tmux (multiplexer)         Docker (isolation)                  │
│  - Session: borg            - One container per project         │
│  - Windows per project      - Shared postgres for cairn         │
│  - 3-pane layout            - bind-mounted ~/.claude/ for hooks │
│  - Ctrl+Space prefix        - devnet shared network             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Getting Started

If you're reading this and want to try the workflow:

**Minimum viable setup (no borg required):**
1. Install Claude Code: `npm install -g @anthropic-ai/claude-code`
2. Install Boris's tips: `/plugin marketplace add alirezarezvani/claude-skills` (in a Claude session)
3. Use Plan Mode (Shift+Tab) for complex tasks
4. Give Claude verification: "run tests after changes"
5. Run `/simplify` before shipping

That's it. You're already using the Boris workflow. Everything else — borg, drone, cairn, the hooks —
is scaffolding that makes the workflow sustainable for people who need external structure.

**Full setup (with borg):**
```
git clone https://github.com/your-username/borg-collective ~/dev/borg-collective
cd ~/dev/borg-collective && ./install.sh
borg init
```

See the [quickstart guide](quickstart.md) for detailed setup instructions.
