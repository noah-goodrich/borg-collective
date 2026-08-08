---
id: compose-env-file-secret-bootstrap
project: cairn
domain: infrastructure
tags:
- docker-compose
- secrets
- devcontainer
- onboarding
preconditions: []
steps:
- Add `.env` to `.gitignore` at the repo root.
- Add `.devcontainer/.env` to `.gitignore`.
- Create `.env.example` (committed) with placeholder values so developers know what
  variables are required.
- Each developer copies `.env.example` → `.env` and fills in real values.
- Docker compose auto-loads `.env` from the working directory — no explicit `--env-file`
  flag needed.
- The devcontainer loads `.devcontainer/.env` for any variables scoped to that context.
- Verify by stopping/removing the relevant container, unsetting the env var from the
  shell, and confirming compose resolves it from the file.
pitfalls:
- If `.env` doesn't exist at all, compose silently substitutes an empty string — the
  service starts but behaves incorrectly. Always confirm the file exists after cloning.
- CI runners (e.g., Drone) source their own secrets files — ensure those files export
  the same variable names used in compose.yml, or add a `.env` generation step to
  the pipeline.
- docker compose only auto-loads `.env` from the directory where the compose.yml lives.
  If compose.yml is in a subdirectory, the `.env` must be there too.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.016617+00:00'
updated_at: '2026-06-11 20:31:18.016617+00:00'
---

# compose-env-file-secret-bootstrap

## description

Bootstrap local compose secrets without shell-sourcing dependencies by placing a gitignored .env file where compose expects it.
