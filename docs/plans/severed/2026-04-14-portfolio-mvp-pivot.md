# Directive: Portfolio MVP Pivot — Waypoint + Wallpaper-Kit on Supabase
*Filed: 2026-04-14*
*Status: Active — drives parallel work across two external project repos*

## What Changed

Both Waypoint and wallpaper-kit are pivoting to a unified **Supabase + Fly.io** stack for MVP
validation, based on the Cortex Code evaluation in `~/dev/cortex-handoffs/`:

- **Waypoint** — reverses the v0.2.0 Snowflake Postgres BURST_XS + MCP-first plan. New primary
  surface is a mobile-first Next.js PWA; MCP server is demoted to an optional power-user
  integration. Active plan: `/Users/noah/dev/wayfinderai-waypoint/PROJECT_PLAN.md`. The
  cancelled v0.2.0 plan is preserved at
  `/Users/noah/dev/wayfinderai-waypoint/docs/plans/severed/2026-04-14_v0.2.0-snowflake-mcp-first.md`.
- **Wallpaper-kit** — executes the platform consolidation already decided in
  `/Users/noah/dev/wallpaper-kit/docs/platform_consolidation.md`: Supabase for auth + Postgres +
  storage + static hosting, Fly.io for the heavy enhance worker. Repo will be renamed
  (user-owned branding exercise). **The current `PROJECT_PLAN.md` (experiment framework) is
  still in progress and is NOT being replaced yet.** The new MVP plan lives as a directive
  alongside it at
  `/Users/noah/dev/wallpaper-kit/docs/plans/directives/2026-04-14-supabase-flyio-mvp-pivot.md`
  and will be promoted to `PROJECT_PLAN.md` once the experiment framework ships or is
  explicitly parked.

## Why

Cortex's evaluation confirmed:

1. **Snowflake Postgres at Stage 1 is a $10/mo loyalty tax with no user benefit.** Neon or Supabase
   free tier carries 0-500 households at $0. The zero-migration scale-up convenience is real but
   worth ~2 hours of future `pg_dump`/`pg_restore`, not worth dragging a second vendor through the
   MVP.
2. **SPCS is the wrong shape for consumer SaaS.** Inverted mental model, ~$50/mo warm-pool floor,
   and 10-30s cold-start UX on bursty consumer traffic.
3. **Supabase + Fly.io is the bootstrapper sweet spot** for both apps. One platform for state +
   auth, one platform for heavy compute, zero cloud-ops overhead.

Founder constraint: validate MVPs fast, cheap, without burning cycles on infrastructure so cycles
go to pricing, positioning, and GTM.

## Cross-Project Rules (both apps)

- **Two separate Supabase projects**, not one shared. Clean separation of concerns. Either app
  can be killed or sold without untangling a shared backend.
- **Zero Snowflake / Cortex / Clerk** in MVP source paths. Revisit Snowflake as an analytics layer
  only at ≥1K paying users across the portfolio.
- **Mobile-first PWA** for both front-ends. Native mobile comes after paying users validate the
  concept.
- **No Stripe / checkout / pricing tiers in the MVP.** Free closed beta. Pricing validates by
  conversation with beta users.
- **Total combined infra cost ≤ $25/mo** pre-launch.
- **Supabase Auth for both apps**, not Clerk. Free to 50K MAU, Google + Microsoft providers built
  in.

## Timeline

~4 weeks elapsed, ~50 hours focused work across two independent streams:

- **Stream A — Waypoint** (4 sessions, ~6-8h each)
- **Stream B — wallpaper-kit** (5 sessions including rename, ~6-8h each)

If neither MVP is live at 6 weeks, something is being over-engineered — escalate via `/borg-review`.

## Related Artifacts

- `~/dev/cortex-handoffs/cortex-snowflake-eval-pt1-response.md` — the evaluation that drives this
  directive (Cortex Code CLI, 2026-04-14)
- `~/dev/cortex-handoffs/cortex-snowflake-eval-pt1-platform-and-setup.md` — original question doc
- `~/dev/wallpaper-kit/docs/platform_consolidation.md` — original platform decision for
  wallpaper-kit (still authoritative)
- `~/dev/wayfinderai-waypoint/PROJECT_PLAN.md` — Waypoint Stream A plan (active)
- `~/dev/wayfinderai-waypoint/docs/plans/severed/2026-04-14_v0.2.0-snowflake-mcp-first.md` —
  Waypoint's cancelled Snowflake/MCP-first plan, kept for history
- `~/dev/wallpaper-kit/PROJECT_PLAN.md` — wallpaper-kit's **in-progress** experiment framework
  plan (still active, not displaced by this directive)
- `~/dev/wallpaper-kit/docs/plans/directives/2026-04-14-supabase-flyio-mvp-pivot.md` —
  wallpaper-kit Stream B plan (queued; promoted to `PROJECT_PLAN.md` after experiment framework
  work finishes or is parked)

## Open Items Not Owned By This Directive

- **Wallpaper-kit rename.** Noah is running the branding exercise separately. The new name is
  blocking Session 0 of Stream B, but is not infrastructure work — don't try to solve it here.
- **Pricing tiers and GTM copy.** Deliberately out of scope. They are the *output* of the MVPs,
  not inputs.
- **Post-revenue analytics layer.** When either app clears ~1K paying users, revisit a Supabase
  → Snowflake pipeline (Fivetran CDC → BRONZE/SILVER/GOLD → dbt). Track as a future directive;
  not active work.
