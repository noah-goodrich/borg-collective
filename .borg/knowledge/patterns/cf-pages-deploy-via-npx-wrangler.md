---
id: cf-pages-deploy-via-npx-wrangler
project: borg-collective
domain: infrastructure
tags:
- cloudflare
- pages
- github-actions
- wrangler
- ci-cd
preconditions: []
steps:
- Store CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID as GitHub Actions secrets
- In the deploy job, run `npm ci` and `npm run build` inside the workflow
- 'Deploy with: `npx wrangler pages deploy ./dist --project-name <cf-project>` as
  a run: step'
- 'Surface secrets via env: block on the step (CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID)'
pitfalls:
- 'wrangler-action@v3 with apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }} is unreliable
  — token may not be passed correctly, causing auth failures'
- Ensure the CF Pages project name matches exactly what exists in Cloudflare dashboard
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.384971+00:00'
updated_at: '2026-06-11 22:41:19.384971+00:00'
---

# cf-pages-deploy-via-npx-wrangler

## description

Deploy to Cloudflare Pages from GitHub Actions using npx wrangler directly rather than the wrangler-action
