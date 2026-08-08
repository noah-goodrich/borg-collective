---
id: obs-20260611-dockerignore-env-leak
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- docker
- security
- dotenv
- build-context
- .dockerignore
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.036623+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-dockerignore-env-leak

## content

Without a .dockerignore file, the entire project directory (including .env containing secrets like POSTGRES_PASSWORD and API keys) is sent as Docker build context and can be inadvertently copied into the image if any Dockerfile layer uses COPY . .

## resolution

Add a .dockerignore file that explicitly excludes .env, .env.*, and other secret-containing files before any docker build or publish workflow runs.
