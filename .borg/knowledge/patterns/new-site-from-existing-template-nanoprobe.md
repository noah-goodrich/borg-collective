---
id: new-site-from-existing-template-nanoprobe
project: borg-collective
domain: infrastructure
tags:
- astro
- cloudflare-pages
- scaffolding
- stillpoint-labs
- nanoprobe
preconditions: []
steps:
- Recon available template repos — compare stack (SSG framework, CSS approach, deploy
  target) and pick closest match
- Read brand assets from source-of-truth docs before writing any code (brand architecture
  md + brand guide html)
- Create new public GitHub org repo; clone template repo locally into a worktree
- Replace CSS custom properties / design tokens with new brand palette
- Self-host required fonts under /public/fonts/ with @font-face declarations
- Write/replace page content — paraphrase from brand docs, do not invent positioning
- Push to origin main; connect to CF Pages (new project, select repo, set build command)
- 'Verify first deploy: curl -sI https://<project>.pages.dev → 200'
- Capture rollback NS records before initiating custom domain wiring
- 'Wire custom domain: create CF zone → update registrar NS → bind apex + www in CF
  Pages → poll for cert'
pitfalls:
- Porkbun API access may be disabled at the account level by default — verify API
  access is enabled in Porkbun account settings before firing domain nanoprobe
- Custom domain wiring is async (NS propagation 3–10 min minimum); checkpoint and
  hand off rather than blocking the orchestrator session
- og-default.png (1200×630) is easy to forget during scaffold — log it as a follow-up
  immediately
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.387924+00:00'
updated_at: '2026-06-16 10:27:02.387924+00:00'
---

# new-site-from-existing-template-nanoprobe

## description

Standing up a net-new static marketing site on CF Pages by cloning an existing structurally-similar repo as template, adapting brand tokens, and deploying via nanoprobe in an isolated worktree
