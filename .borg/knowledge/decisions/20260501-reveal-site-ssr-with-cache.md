---
id: 20260501-reveal-site-ssr-with-cache
date: '2026-06-16'
project: borg-collective
domain: infrastructure
tags:
- reveal-site
- astro
- cloudflare-pages
- ssr
- supabase
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.265598+00:00'
updated_at: '2026-06-16 10:27:02.265599+00:00'
---

# 20260501-reveal-site-ssr-with-cache

## decision

Deploy reveal-site gallery pages as SSR (prerender = false) with Cache-Control s-maxage=86400 rather than static generation

## context

Gallery pages (index.astro, seen/) need to reflect newly imported photographs without a full redeploy. Photographs enter prod Supabase asynchronously via the import pipeline.

## reasoning

SSR allows Cloudflare's CDN edge to serve fresh Supabase data on a 24-hour cache window without triggering a new build. Static generation would require a webhook-triggered rebuild every time photos are imported.
