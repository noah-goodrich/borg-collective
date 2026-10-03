Generated: 2026-09-10

# Talking Between Machines

How to let Claude Code sessions on different machines pass messages to each other, as close to real-time as the
tooling actually allows.

**Design review: PASSED** — two blind adversarial reviews ran. The first overturned the original pick; the second
returned REVISE and its three fixes are folded in below.

AI-scoring: 100/100 (scanning mode: categories 3, 4, 6, 8-words)

## Glossary

Every term you need, defined once.

- **Session** — one running Claude Code conversation. On Noah's Mac these live in tmux windows.
- **Drone** — a project's session running inside a devcontainer (a Docker container holding one project's tools).
- **drone-host** — the always-on self-hosted machine. It never sleeps, which turns out to matter enormously.
- **Turn** — one round of the agent doing work: you type, it thinks and acts, it stops. A **turn boundary** is the
  moment it stops.
- **Hook** — a script Claude Code runs automatically at a lifecycle moment (session start, turn end). A **Stop hook**
  fires at a turn boundary and can hand the model extra text via `additionalContext`.
- **Headless** — `claude -p "do this"`, a one-shot run with no interactive terminal. It starts, works, exits.
- **send-keys** — `tmux send-keys`, which types text into another terminal pane from outside.
- **Tailscale** — a private network overlay. Machines get stable addresses and talk directly, encrypted, without
  opening ports to the internet.
- **Durable** — a message survives the receiver being offline. **At-most-once** is the opposite: if nobody is
  listening, the message is gone.
- **Cursor** — a per-subscriber marker recording how far down the message log that subscriber has read.
- **Ack** — acknowledgement. The receiver confirming it actually got the message.
- **MCP** — Model Context Protocol, the standard way to give a model extra tools. Agent-to-tool, not agent-to-agent.

## 1. Recommendation

Build **Option G**: a durable message log on `drone-host`, reached over Tailscale, with delivery chosen by whether
the target session is alive, and the read cursor advancing only on acknowledgement.

The single most important finding, and the one that reshapes everything:

> **You cannot wake a running Claude Code session from outside.** The agent loop is turn-based. Hooks fire only at
> turn boundaries, and a session parked waiting for input has already fired its last one.

So "real-time" cannot mean event-to-pane. It means **event-to-next-turn-boundary**, and any design promising more
than that is lying. Sub-second detection is easy; reliable *injection* is the unsolved part, industry-wide.

### What to build, in order

1. **The log.** Append-only JSON Lines file on `drone-host`, one file per channel, one writer per file. Per-subscriber
   cursor files, exactly like `vinculum` — that shape is already proven. Reached over Tailscale.
2. **Ack-gated cursors.** The cursor advances **only** when the receiver confirms delivery, never on send. Dedup on
   the envelope's existing `id`. This is what prevents the silent-partial-delivery failure that's documented
   elsewhere in the wild.
3. **Bounded retry.** Un-acked messages retry with exponential backoff and a hard ceiling, then go to a dead-letter
   file and raise. Unbounded retry plus per-message process spawn is how you wake up to a surprise bill.
4. **Delivery by liveness, with the strict guard on both risky paths:**
   - Target session **live and idle** → inject via `send-keys`, then verify submission before acking.
   - Target session **live and busy** → queue; the Stop hook ingests at the next turn boundary.
   - Target session **live but at a permission prompt** → do not deliver. Text sent here can be swallowed as the
     yes/no answer.
   - **No live session** → fresh headless `claude -p` worker. **Never `--resume` a session that is live and
     attached** — a second process appending to a transcript a human is actively using is the most destructive path
     available, and it gets the *same* liveness gate as `send-keys`, not a weaker one.
5. **Only then**, tune latency.

### Minimum viable version

*One channel, `drone-host` as the only always-on node, ack-gated delivery to a fresh headless worker. No
`send-keys`, no `--resume`, no live-session injection at all.* That version is correct, cheap to reason about, and
proves the ack protocol before anything racy is layered on.

### What this honestly does not give you

A fresh headless worker is **not the addressed session continuing a conversation**. It's a new worker with no
context. Full session-to-session dialogue across machines — where the receiving session answers *as itself* — is
only reachable through the live-injection paths, which are exactly the paths the evidence says are unreliable.
Anthropic has the same gap open at [claude-code#28300](https://github.com/anthropics/claude-code/issues/28300).
Build the durable spine; treat true cross-machine dialogue as a later bet, not an MVP promise.

## 2. Options Considered

Generated from zero, with the existing `vinculum` catalogued and quarantined first so it couldn't anchor the set.

### Option A: Built-in path only

- **What it is:** Use Claude Code's own `SendMessage` / `ListAgents` over Remote Control. Build nothing.
- **Pros:** Zero work. Officially supported. Two-way where it works.
- **Cons:** Routes through Anthropic servers. Requires the *sending* session connected to Remote Control via
  claude.ai OAuth — unavailable on API key, Bedrock, or Vertex. If the sender isn't connected, the message is
  one-way with no reply address.
- **Killed because:** container sessions and host sessions on the same box cannot see each other. Every drone is a
  devcontainer, so the built-in path is structurally blind to exactly the sessions worth reaching.
- **Feasibility:** High to try, zero to fix.

### Option B: Shared MCP inbox

- **What it is:** An MCP server on `drone-host`; each session calls a tool to check its inbox.
- **Cons:** MCP tools fire only when the model decides to call one. That's polling on the model's own cadence, and
  polling burns tokens on every empty check — the exact pattern Anthropic built the monitor tool to replace.
- **Feasibility:** Medium. **Tradeoff conceded:** you pay tokens forever for latency you never quite get.

### Option C: Durable log + Stop-hook ingestion

- **What it is:** Log on `drone-host`; a Stop hook injects `additionalContext` at turn boundaries.
- **Fatal gap:** an idle session has already fired its last Stop. Nothing schedules another. Messages to a parked
  drone — the modal state — sit undelivered forever.

### Option D: Headless receivers

- **What it is:** An arriving message triggers `claude -p` on the target machine. No live session involved.
- **Pros:** Immune to every turn-boundary and TUI race, because there's no existing loop to interrupt.
- **Cons:** A cold spawn per message. Not the addressed session; a new context-less worker.
- **Feasibility:** High.

### Option E: Vinculum over the wire

- **What it is:** Replicate the existing file log across machines, keep `fswatch` → `send-keys`.
- **Pros:** Smallest diff to something already working.
- **Cons:** Inherits the `send-keys` race wholesale and adds multi-writer file sync, whose conflict story is a
  rename, not a merge.

### Option F: Two-speed delivery

- **Separation move:** by condition — idle sessions get `send-keys`, busy ones get Stop-hook ingestion.
- **Why it fell:** it labelled `send-keys` a "fast-path optimization" when it is the *only* mechanism that reaches
  the modal receiver state. That inverts what the evidence supports.

### Option G: Liveness-routed durable log — **chosen**

- **Separation move:** by condition, applied to *liveness* rather than busyness, with correctness resting on the
  path that doesn't depend on an agent loop existing at all.
- **Feasibility:** High. **Estimate:** 2–3 sessions for the MVP; live injection is a separate, later bet.

## 3. Council and Dissent

- **Technical Realist** killed **A** — not on effort, on structure. Devcontainers are invisible to the built-in path.
- **Pragmatist** dissented against the whole build, and it stands as a named risk: **E is two days' work on something
  already running.** The counter is that E inherits the one defect — unverified delivery — that makes cross-machine
  messaging untrustworthy rather than merely slow.
- **User Advocate** flagged the honest ceiling: Noah wants sessions *talking*, and the MVP delivers messages without
  delivering dialogue. That limitation is stated in §1 rather than buried.
- **Recommender** took G on the grounds that a durable, acked spine is the part you cannot retrofit, while latency
  optimizations can be layered on any time.

**Blind review round 1 — OVERTURN.** Objection: *"The MVP builds the one delivery mechanism (Stop-hook ingestion)
that the findings themselves prove cannot deliver to an idle session, and defers to 'later' the only mechanism
(send-keys) capable of waking one."* Sustained; the pick was rebuilt.

**Blind review round 2 — REVISE.** Objection: *"the idle/liveness gate is specified for send-keys but never
specified for `--resume`, meaning the more destructive path (a second process appending to the SAME session
transcript) ships with the WEAKER guard, not the stronger one."* Sustained. All three fixes — matching guard on
`--resume`, fresh worker as the non-resumed default, bounded retry with backoff — are in §1.

## 4. Track Findings

**Claude Code primitives.** Cross-session messaging exists (v2.1.224+) and does reach other machines, but only
through Anthropic's servers, only with the sender on Remote Control, and never between a container and its host.

**The last mile.** No external wake exists. `send-keys` races because Ink distinguishes a physical Enter from a
programmatic `\r` — text appears and never submits. It also drops under high tmux output volume and races with shell
init. Cross-tool comparison found this unsolved in Codex, Gemini CLI, Copilot and others alike.

**Transport.** macOS sleep is the real adversary, not latency: multiple open Tailscale issues through late 2025
report the daemon degraded after lid-close, needing seconds to minutes to rejoin, which is why durability has to be
anchored on the box that never sleeps. That same requirement disqualifies most of the obvious brokers, because Redis
pub/sub and NATS Core are at-most-once and simply drop what an offline subscriber missed. The durable tiers are
better but not as advertised: Jepsen (Dec 2025) found JetStream can lose *acknowledged* writes because it flushes
every two minutes rather than before acking, whereas MQTT earns durability by default through QoS and persistent
sessions. The same split shows up one layer down, where SSE recovers gaps in the protocol itself via
`Last-Event-ID` and WebSocket leaves that replay to your code.

**Precedent.** Nothing production-grade exists. The closest community build is roughly 190 lines with no auth and no
persistence, self-described as a proof of concept. The recurring failures elsewhere: silent overwrites that still
look correct, central coordinators becoming the bottleneck, re-delegation loops quietly burning tokens, and one
report of a transport delivering a single line of a multi-line message with no error at all.

## 5. Prior Work (catalogued, then quarantined)

- **`borg vinculum`** — `bin/borg-vinculum-watch`. Append-only `log.jsonl` per channel under
  `~/.local/share/borg/vinculum/`, per-subscriber cursor files, `fswatch` → `tmux send-keys`, envelope
  `{from, body, id, ts}`. **Right:** durable log plus per-subscriber cursors is the correct spine, and G keeps it.
  **Wrong:** delivery is fire-and-forget — the cursor advances whether or not the message ever landed.
  **Single-machine assumptions:** exactly three — tmux access, `$HOME`, `fswatch` on PATH.
- **`borg-linkup-all`** — tmux-broadcast to all drones. Same unverified-delivery weakness.
- **Hooks** — `borg-link-down.sh` (SessionStart) and `borg-link-up.sh` (Stop) already move state between sessions
  through files. Proof the hook path works; also proof it only fires at turn boundaries.
- **cairn** — decommissioned 2026-08-08, archived docs only. Not revived here.
- **MCP servers** — none exist in the tree today.

*Prior work catalogued and quarantined; the options above were generated from zero.*
