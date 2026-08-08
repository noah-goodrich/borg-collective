---
id: obs-20260612-anthropic-key-container-mismatch
session_date: '2026-06-12'
project: cairn
tool: cursor
tags:
- cairn
- anthropic
- api-key
- environment-variable
- container
- docker
category: error_encountered
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-12 03:25:39.255699+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260612-anthropic-key-container-mismatch

## content

cairn container silently failed to authenticate with Anthropic because the host uses ANTHROPIC_SDK_KEY but the SDK inside the container expects ANTHROPIC_API_KEY. The mismatch is invisible at startup — it only surfaces when an API call is made.

## resolution

Added explicit env var mapping in cairn's container config (ANTHROPIC_SDK_KEY → ANTHROPIC_API_KEY). Merged in 16509f9. Any future cairn deployment must include this mapping or Anthropic calls will silently fail.
