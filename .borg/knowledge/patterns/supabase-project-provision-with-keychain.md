---
id: supabase-project-provision-with-keychain
project: borg-collective
domain: infrastructure
tags:
- supabase
- keychain
- secrets
- provisioning
- devcontainer
preconditions: []
steps:
- Run `supabase projects create <name> --org-id <org> --region <region> --db-password
  <generated>` and capture the auto-generated password immediately.
- Store the DB password in macOS Keychain via the store-secret skill/flow at creation
  time — Supabase will not show it again.
- Add registry rows for SUPABASE_ACCESS_TOKEN, <PROJECT>_SUPABASE_DB_PASSWORD, and
  any project refs in ~/.config/dotfiles/zsh/secrets.zsh with corresponding _keychain_export
  calls.
- Forward the env vars through the project's docker-compose.yml with empty-string
  fallbacks (e.g., INGLE_SUPABASE_DB_PASSWORD=${INGLE_SUPABASE_DB_PASSWORD:-}).
- Bake the Supabase CLI into the base Docker image (Dockerfile.base) so it's available
  in all devcontainers without per-project duplication.
- Rebuild the base image and all dependent project images (`drone rebuild`).
- From inside the container, run `supabase link --project-ref <ref>` and update supabase/config.toml
  major_version to match the cloud Postgres version.
pitfalls:
- Supabase does not re-expose the auto-generated DB password after project creation.
  If it wasn't captured then, the project must be deleted and re-created.
- Docker Desktop containers lack IPv6 by default; Supabase free-tier direct-DB endpoints
  are IPv6-only. Raw psql to cloud DB from inside a container requires the Supavisor
  pooler (IPv4) or explicit Docker IPv6 config.
- supabase/config.toml major_version must match the cloud project's Postgres version
  or `supabase link` / migrations will fail.
- The store-secret skill uses bash-style `read -s -p` which parses differently in
  zsh — if invoked from a zsh session, the prompt flag may be treated as literal input.
  Verify the shell context before use.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.189199+00:00'
updated_at: '2026-06-16 10:27:02.189200+00:00'
---

# supabase-project-provision-with-keychain

## description

Provision a new Supabase Cloud project and wire its credentials end-to-end into a devcontainer secret pipeline, capturing the DB password at generation time.
