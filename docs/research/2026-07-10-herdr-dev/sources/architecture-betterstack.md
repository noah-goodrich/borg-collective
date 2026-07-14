# Source Card — Better Stack Community guide

- **Full citation:** Better Stack Community, "Herdr: Terminal Multiplexer with Built-in AI Agent State
  Awareness," Better Stack guides.
- **URL:** https://betterstack.com/community/guides/ai/herdr-ai-agent/
- **Date accessed:** 2026-07-10
- **Evidence level:** L6 — independent practitioner technical write-up
- **Research topic area:** architecture, positioning vs tmux/Warp
- **Credibility (compressed, rapid tier):** Independent of the vendor; technically specific on the
  client-server model; explicitly does NOT detail or verify the state-detection heuristics. Band: **keep**
  (best independent architecture read available).
- **Bias Guard Check:** I want an independent source to validate the tool → scored its praise HARDER;
  weighted its *caveats* (experimental orchestration) rather than its endorsements.
- **Key findings:** (1) Client-server over a local Unix socket; thin client renders. (2) `--remote`
  forwards over an SSH tunnel. (3) tmux "sees a text stream with no understanding of the process state."
  (4) Herdr runs inside your existing terminal vs Warp/cmux replacing it. (5) Agent-driven orchestration
  is "the more experimental feature."
- **## Verified Quote(s):** "Herdr uses a client-server architecture. The server process manages
  sessions, workspaces, and panes. The client is a thin process in the terminal window … they
  communicate over a Unix socket." Location: architecture section.
- **Access status:** live
- **Inclusion Decision:** include (independent technical corroboration)
- **Perspective category:** Practitioner
