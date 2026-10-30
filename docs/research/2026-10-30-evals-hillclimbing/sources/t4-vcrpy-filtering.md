# Source: VCR.py documentation, "Advanced Features" (filtering)

**Full citation:** VCR.py project. "Advanced Features." vcrpy.readthedocs.io, latest. No date shown.
**URL:** https://vcrpy.readthedocs.io/en/latest/advanced.html
**Date accessed:** 2026-10-30
**Evidence level:** practitioner (open-source library documentation)
**Track:** T4 portability, sanitization hazards in recorded sessions

## Verified Quote(s)

**Location:** heading "Filter sensitive data from the request".

> The cassette file only ever contains `<API_KEY>`.

> needs its own entry with that encoded form.

> very short values could replace unrelated text

**Location:** heading "Custom Response Filtering".

> every time an existing cassette is loaded for replay.

> keep the callback idempotent.

## Key finding

The reference record/replay library documents concrete sanitization traps: a secret that appears URL-encoded or escaped needs a separate filter, secrets inside compressed bodies are missed unless decoding is enabled, short replacement values corrupt unrelated text, and response filters re-run on every replay. For agent transcripts the same traps apply to tokens, account identifiers, hostnames and file paths echoed inside tool output, so header stripping alone is insufficient.

**Access status:** live
