# Source: Claude Code docs, Cross-session messaging

**Full citation:** Anthropic. "Message your other Claude Code sessions." Claude Code documentation. https://code.claude.com/docs/en/cross-session-messaging. Live page, requires v2.1.224 or later, accessed 2026-10-13.
**URL:** https://code.claude.com/docs/en/cross-session-messaging
**Date accessed:** 2026-10-13
**Evidence level:** 4 (vendor primary documentation)
**Research topic area:** Native inter-session messaging vs borg vinculum bus

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 10/10 | Feature owner |
| 2 | Evidence Quality | 8/10 | Complete behavior spec |
| 3 | Currency | 10/10 | Live, v2.1.224+ |
| 4 | Intent | 7/10 | Product docs |
| 5 | Bias & Objectivity | 8/10 | Security limits stated |
| 6 | Logic & Coherence | 9/10 | Delivery, controls, limits |
| 7 | Corroboration | 8/10 | Teams, agent-view pages agree |
| 8 | Intellectual Honesty | 9/10 | Lists refusals and caps |
| 9 | Specificity | 10/10 | Sockets, settings, caps |
| 10 | Relevance | 9/10 | Overlaps borg messaging |

- Authority and Currency: first-party and live.
- Evidence Quality: states every refusal case and numeric cap.
- Bias: the security controls (`crossSessionInbound`, `isolatePeerMachines`) are shown plainly.
- Logic: split into delivery, inbound controls, non-interactive sessions, restriction, availability, limitations.
- Corroboration: the agent-teams page refers to the same `SendMessage` tool and rules.
- Honesty: includes message loop throttling and message size caps.
- Specificity: per-session Unix socket, `CLAUDE_CODE_MESSAGING_SOCKET`, 100-message hold, 12-hour notice expiry.
- Relevance: a native low-level bus that could replace the transport of a file-based cross-session bus, though not its durability.

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Claude can list and message your other sessions on this machine, on other machines, and in the cloud, using `ListAgents` and `SendMessage`; no setup is needed once the version requirement is met.
- Messages are plain text only, never conversation history or files, and arrive between tool calls or start a new turn when the receiver is idle.
- Delivery is not durable: held messages are capped at 100 and expire (default 5 minutes for dialogs), and a rapid burst is refused at the sender.
- A message from another session cannot approve anything or change configuration, a safety property a home-grown bus has to replicate by convention.
- `notify_when_idle` gives a native "tell me when that session finishes" signal for sessions on the same machine, with a 12-hour expiry.

## Verified Quote(s)

**Location reference:** Page opening paragraph below the title and version note; section "How a session treats an incoming message" first bullet.

> Cross-session messaging lets Claude deliver a message from one of your Claude Code sessions to another.

> A message is a piece of text one Claude writes to another, never the sender's conversation history or files.

> never counts as your consent, so it can't answer a pending permission prompt on your behalf.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Native transport that overlaps cross-session coordination in borg; its non-durable design is the key difference.

**Redundancy check:** Not covered by agent view or teams cards, which describe different scopes.

**Perspective category:** Institutional
