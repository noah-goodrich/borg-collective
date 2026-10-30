# Source: Hamara, "Deterministic AI Testing with Session Recording in cagent" (Docker blog)

**Full citation:** Stan Hamara. "Deterministic AI Testing with Session Recording in cagent." Docker Blog, posted Jan 6, 2026.
**URL:** https://www.docker.com/blog/deterministic-ai-testing-with-session-recording-in-cagent/
**Date accessed:** 2026-10-30
**Evidence level:** practitioner (vendor engineering blog about its own agent tool)
**Track:** T4 portability, record and replay for Tier 1

## Verified Quote(s)

**Location:** "how it works" section.

> During recording, cagent proxies requests to the AI provider, captures the full request/response cycle, and saves it to a YAML "cassette" file.

> During replay, incoming requests are matched against the recording and served from cache—no network calls required.

**Location:** heading "Getting started" (the sentence reads "One implementation detail worth noting: tool call IDs are normalized before matching.").

> tool call IDs are normalized before matching.

**Location:** security note.

> Cassettes automatically strip sensitive headers (`Authorization`, `X-Api-Key`) before saving, making them safe to commit to version control.

**Location:** maintenance guidance.

> When agent instructions change significantly, delete the cassette and re-record to capture the new behaviour.

## Key finding

The mainstream record/replay pattern intercepts the model API with a proxy, stores request/response cassettes, normalizes volatile IDs before matching, strips auth headers, and re-records when instructions change. That pattern needs control of the provider base URL; Cortex Code routes model calls through Snowflake rather than a configurable provider endpoint, so for Cortex the replay seam has to be the CLI's own stream-json/NDJSON output and hook payloads, not the model API.

**Access status:** live
