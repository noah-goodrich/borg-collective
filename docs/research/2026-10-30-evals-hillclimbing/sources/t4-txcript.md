# Source: txcript crate documentation (docs.rs)

**Full citation:** txcript. Crate README on docs.rs, version 0.13.0, released 2026-09-04.
**URL:** https://docs.rs/crate/txcript/0.13.0
**Date accessed:** 2026-10-30
**Evidence level:** practitioner (open-source tool documentation)
**Track:** T4 portability, normalizing transcripts to a common schema

## Verified Quote(s)

**Location:** crate description.

> Convert coding-agent session transcripts between harness formats.

**Location:** architecture section.

> The canonical model is `Transcript<Common>`: `Meta` + `Vec<Message>`

> Native load/save is byte-lossless

**Location:** limitations section.

> Claude's data-export ZIP and `conversations.json` are not supported.

## Key finding

txcript shows the hub-and-spoke normalization pattern at scale: each harness converts to and from one canonical transcript (metadata plus messages with reasoning, tool calls, results and usage), and native round-trips are byte-lossless while cross-harness conversion keeps only what the source provides. Cortex Code is not among its harnesses, and some sources are read-only, which means borg would write its own Cortex spoke.

**Access status:** live
