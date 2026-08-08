---
id: new-site-devcontainer-scaffold
project: borg-collective
domain: infrastructure
tags:
- devcontainer
- astro
- npm
- docker
- borg
- onboarding
preconditions: []
steps:
- Create .devcontainer/ with Dockerfile, docker-compose.yml, and devcontainer.json
  mirroring an existing working site (e.g., reveal-site)
- Assign a unique host port (increment from last used, e.g., 4322, 4323) in docker-compose.yml
  and devcontainer.json
- Set postCreateCommand in devcontainer.json to run `npm install` so dependencies
  are installed inside the container on first open
- Register the new site with borg and start with `drone up <site-name>`
- Run all subsequent npm/build commands via `drone exec` — never on the host
- Verify build inside container before pushing
- Create GitHub repo, set CF Pages secrets (CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID),
  and wire deploy workflow using npx wrangler pattern
pitfalls:
- 'If you accidentally run `npm install` on the host before the devcontainer is set
  up, node_modules will exist on the host. bash-guard may block `rm -rf` on home subdirectories
  — use the `!` escape prefix: `! rm -rf /path/to/node_modules`'
- Do not use @astrojs/tailwind with Astro 6 — use @tailwindcss/vite instead
- 'wrangler-action@v3 apiToken param is unreliable; use npx wrangler with env: block
  for CF Pages deploys'
- Each devcontainer needs a unique host port or concurrent multi-site dev will fail
  with port conflicts
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.384614+00:00'
updated_at: '2026-06-11 22:41:19.384615+00:00'
---

# new-site-devcontainer-scaffold

## description

Scaffold a new Astro site with devcontainer isolation so all npm/build work runs inside the container, not on the host
