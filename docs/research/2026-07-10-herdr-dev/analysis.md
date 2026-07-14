Generated: 2026-07-10

# Herdr (herdr.dev) — Rapid Research Brief

> **UNVERIFIED — self-check only.** This is a rapid-tier brief. **NOT INDEPENDENTLY VERIFIED** — no
> separate fact-checking agent re-ran the citations. Every claim is sourced and quoted below, but a
> second reader should spot-check anything load-bearing before you act on it.
>
> **AI-scoring: 86/100** (self-assessed against the noah-voice rules).

## Glossary

- **Agent (coding agent):** a CLI program that writes code for you by talking to a model — Claude Code,
  Codex, Copilot CLI, Cursor Agent, and so on.
- **Multiplexer:** one program that runs many terminal sessions at once and keeps them alive when you
  disconnect. `tmux` is the classic example.
- **PTY (pseudo-terminal):** the pipe the operating system puts between a program and your terminal
  window. Persisting the PTY is what lets a session survive after you close the laptop.
- **Unix socket:** a local, file-like channel two programs on the same machine use to talk. No network.
- **AGPL-3.0:** a strong copyleft open-source license. If you run modified AGPL code as a network
  service, you must publish your changes. Stricter than MIT or GPL.
- **Bus factor:** how many people would have to get hit by a bus before a project stalls. A one-person
  project has a bus factor of 1 — a real risk.
- **Pre-1.0:** a version number below 1.0 (herdr is at 0.7.3). By convention the author is still
  reserving the right to break things between releases.

---

## 1. Recommendations

- **Evaluate herdr as prior art for your borg tmux layer — it is the closest off-the-shelf thing to
  what you built.** It does agent-state detection, persistent SSH sessions, and a socket
  orchestration API: the same three jobs borg's tmux glue does. Spend an hour running it before
  investing more in home-grown equivalents. (See §4, §5 Adoption.)
- **Do NOT treat its state detection as solved-and-robust — it uses the same fragile trick borg does.**
  Herdr detects agent state with process-name matching plus terminal-output heuristics. That is
  exactly the class of bug your checkpoint already logged (the version-named-pane / pgrep gate). If
  you adopt or borrow from it, carry your `suspect`-row self-audit idea over. (See §5 Architecture.)
- **If you ever embed or redistribute herdr, read the license first.** Core is AGPL-3.0-or-later.
  Fine for personal use; a landmine if you fold it into anything proprietary without buying the
  commercial license. (See §5 License & Pricing.)
- **Wait for 1.0 before depending on it in an unattended pipeline.** It is ~5 weeks old at v0.7.3 with
  70 releases in a month — fast, but still pre-1.0 and single-maintainer. Great for hands-on trials,
  risky as load-bearing infra today. (See §5 Maturity.)

## 2. Summary

**What it is.** Herdr is a terminal-native "agent multiplexer" — think `tmux`, but it understands that
the thing running in a pane is an AI coding agent, not just a text stream. It is a single Rust binary
that runs *inside* the terminal you already use. Its own tagline: *"Agent multiplexer · a binary, not
an app."* You point it at agents like Claude Code, Codex, Copilot CLI, or Cursor Agent and it runs them
in split panes and tabs, keeps them alive over SSH when you disconnect, and shows you at a glance which
ones are `idle`, `working`, `blocked`, or `done`.

**Who makes it.** A single developer, `ogulcancelik` on GitHub, backed by a sponsorship program with
"gold-tier" supporters. It is not a company product.

**The problem it solves.** When you run several coding agents at once, a plain multiplexer is blind:
*"tmux treats all processes the same … it sees a text stream with no understanding of the process
state"* (Better Stack). You cannot tell which agent is stuck waiting for you versus grinding away.
Herdr adds that missing awareness, plus a local socket API so agents can even open their own panes and
spawn helpers.

**Maturity.** Very new, moving very fast, already popular. It shipped **June 5, 2026**, and by **July 7,
2026** was at **v0.7.3** — its **70th release**. The repo has **~15.1k stars and ~1k forks**. That is a
genuinely viral launch for a five-week-old dev tool. The flip side: it is pre-1.0, and the bus factor
is 1.

**Money.** The core is free and open-source under **AGPL-3.0-or-later**, with **commercial licenses
available** for uses AGPL does not allow. One third-party review calls the model "freemium" but notes
actual paid-tier pricing is *not publicly disclosed*. Since the tool itself advertises "no account, no
telemetry," the paid side is almost certainly commercial licensing and sponsorship, not a hosted SaaS.

**Why it matters to you specifically.** Herdr is, in effect, a polished public version of the
orchestration layer you built into borg — agent-state detection, persistent sessions, a control socket.
It is the natural build-vs-borrow comparison. It also shares borg's central weakness: state detection
by process name and output shape, which is brittle exactly where you have already been bitten.

**Testability note (from Phase 2 classification):** *cheaply testable.* The strongest way to close the
open questions — how reliable is the state detection, how good is the socket API — is to install the
binary and drive it for an hour. This brief did not do that (desk research only); it is the obvious
next step and is flagged as such in Recommendations.

## 5. Research

### What it is / who makes it (official + repo)

Herdr describes itself as *"Agent multiplexer · a binary, not an app"* that lets you run *"all your
coding agents from one terminal, on any box, even over ssh"* (herdr.dev). The GitHub repo tagline is
*"agent multiplexer that lives in your terminal"* and the primary language is **Rust (85.2%)**. The
maintainer is `ogulcancelik`. Score band: **keep** (official primary source for identity/features;
vendor bias noted — claims about robustness are self-reported).

### Problem & positioning (Better Stack, compare page)

The core problem, stated independently by Better Stack: *"tmux treats all processes the same. If a
Claude Code or Codex instance is running in a pane, tmux sees a text stream with no understanding of
the process state."* Herdr's own comparison page frames every rival the same way — as either
agent-blind or terminal-replacing:

- **vs tmux:** *"tmux persists terminals; Herdr persists agent workspaces and understands agent state."*
- **vs Zellij:** *"Zellij is a modern terminal workspace; Herdr is an agent multiplexer with state,
  waits, and orchestration."*
- **vs Warp / cmux (AI-native terminals):** Better Stack's neutral framing — *"Newer AI-native
  terminals like Warp and Cmux replace the terminal entirely … Herdr runs inside the terminal you
  already use, preserving existing fonts, color schemes, shell configuration, and muscle memory."*
- **vs Conductor / Emdash / Superset:** *"They orchestrate isolated worktrees and review diffs; Herdr
  orchestrates live terminals and agent state."*

Third-party reviews add more names to the competitive set: **Shire, CLI Agent Orchestrator (CAO),
Terax, Aider, and Google's Agents CLI/ADK** (Stork.AI). Score band: **keep** for Better Stack
(independent, technical); **keep** for the compare page but read as marketing.

### Architecture (Better Stack + official)

Independent description of the design: *"Herdr uses a client-server architecture. The server process
manages sessions, workspaces, and panes. The client is a thin process in the terminal window that
captures input and renders output. Locally, they communicate over a Unix socket."* Remote work is the
same server, reached over SSH: *"The --remote flag starts the server on a remote machine and the client
locally, forwarding communication through the SSH tunnel."*

The state detection — the whole point of the tool — is where the public detail thins out. The official
site and search snippets describe *"process-name matching plus terminal-output heuristics"* to label
agents `idle` / `working` / `blocked` / `done`. Better Stack confirms the labels but gives no mechanism:
*"processes running in Herdr panes are identified as agents"* and shown as `working`, `idle`, `blocked`.
It also flags the self-orchestration feature as unfinished: *"The agent-driven orchestration through the
Herdr CLI is the more experimental feature."* Score band: **keep** (Better Stack is the best independent
technical read available; note it explicitly does not verify the detection heuristics).

### Features & install (official)

Persistent PTY sessions across panes and tabs; agent-state tracking; remote SSH attach; a CLI plus a
JSON socket API for orchestration; clickable/mouse-driven panes alongside tmux-style prefix keys; a
mobile-responsive layout for narrow phone terminals. *"Any terminal agent works out of the box."*
Install via `curl -fsSL https://herdr.dev/install.sh | sh`, Homebrew, or a Nix flake; a Windows preview
ships as a PowerShell script. Privacy stance: *"no Electron, no account, no telemetry."* Score band:
**keep** (vendor feature list; uncontested but self-reported).

### License, pricing, maturity, adoption (repo + Stork.AI)

- **License:** *"Dual-licensed: GNU Affero General Public License v3.0 or later (AGPL-3.0-or-later) …
  commercial licenses available"* (GitHub).
- **Pricing:** *"Herdr operates on a freemium business model. While a free tier is available, specific
  details regarding paid tiers … are not publicly disclosed as of early July 2026"* (Stork.AI). Listed
  con: *"Specific pricing details … are not publicly available, making cost planning difficult."*
- **Maturity / cadence:** launched *"Jun 5, 2026"* (Stork.AI); at **v0.7.3 on July 7, 2026**, the
  **70th release**, on **1,077 commits** (GitHub). Roughly two releases a day since launch.
- **Adoption:** **~15.1k stars, ~1k forks** (GitHub) — strong for a five-week-old project. Supporting
  signals: a docs site, a plugin marketplace, and a sponsorship program.

Score bands: GitHub repo **keep** (primary, quantitative). Stork.AI **borderline** — useful for pricing
and the alternatives list, but it is an SEO tool-directory page, so treat its framing as secondary.

### Strengths and risks (synthesis across sources)

**Strengths.** Runs inside your existing terminal, so no lost muscle memory or config (Better Stack).
Local, private, no account, no telemetry (official). Zero-config agent-state awareness is the real
differentiator (official + Better Stack). SSH-native persistence suits a "close the laptop, reattach
from a phone" workflow (official). The socket API enables agent self-orchestration (official).
Exceptional early traction (repo).

**Risks.** Pre-1.0 and ~5 weeks old — expect breaking changes (repo). Single maintainer, bus factor 1
(repo). AGPL copyleft is a redistribution hazard for any proprietary use without the commercial license
(repo). Commercial pricing is opaque (Stork.AI). State detection leans on process names and output
heuristics — a known-brittle approach (official; Better Stack declines to verify it). Self-orchestration
is explicitly *"experimental"* (Better Stack). Terminal-only, no GUI (Stork.AI con).

## 6. Methodology (short note — rapid tier)

**Tier:** rapid. **Stamp:** UNVERIFIED — self-check only; NOT INDEPENDENTLY VERIFIED. No Phase 3.5
verification subagent ran; the executable citation gate is expected to (correctly) fail this as "not
fact-checked." That is the honest rapid-tier outcome, not an error.

**Search log:**

| # | Query | Purpose |
|---|-------|---------|
| 1 | `herdr.dev developer tool` | existence + identity |
| 2 | `"herdr" dev tool what is it` | features + agent list |
| 3 | direct fetch: herdr.dev/ | official identity, features, install, privacy |
| 4 | direct fetch: github.com/ogulcancelik/herdr | license, language, stars, releases, cadence |
| 5 | direct fetch: herdr.dev/compare/ | self-described competitors |
| 6 | direct fetch: stork.ai/en/herdr | pricing, launch date, third-party alternatives, cons |
| 7 | direct fetch: betterstack.com/…/herdr-ai-agent | independent architecture + positioning read |

**Triage (kept / cut):** 5 sources kept and carded (official site, compare page, GitHub repo, Stork.AI,
Better Stack). Cut without carding: CoddyKit, Terminal Trove, OpenTechHub, Nahornyi, Knightli, CAO —
redundant tool-directory / blog restatements of the official copy, adding no independent claim (the
lowest-value survivor that *cleared* the bar was Stork.AI, kept only for pricing + alternatives).

**Perspective balance:** Practitioner/vendor (official ×2), Institutional-ish primary (GitHub metrics),
Practitioner-independent (Better Stack), Contrarian/secondary review (Stork.AI). No Academic source —
appropriate for a 5-week-old commercial tool. Boots-on-the-ground (forum/user reports) not yet found;
a real gap, noted below.

**Bias-guard summary:** agree 2 · disagree 1 · neutral 2. Not skewed past 3:1; no falsification query
required. The one deliberately skeptical read (single-maintainer + unverified heuristics) is carried
into Risks.

**Limitations.** Desk research only — the tool was not installed or driven, so all robustness claims are
the vendor's own or an independent reviewer's, not observed here. No user-community/forum evidence was
located, so real-world reliability at scale is unknown. Commercial pricing could not be determined. For
a defensible, publishable evidence base, re-run at full tier with the verification subagent and a
hands-on trial.
