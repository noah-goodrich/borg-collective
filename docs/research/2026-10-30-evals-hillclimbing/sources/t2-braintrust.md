# Source Record: Braintrust pricing and CLI experiments reference

- **Full citation:** Braintrust, "Pricing" page and "bt experiments" CLI reference, read 2026-10-30.
- **URL:** https://www.braintrust.dev/pricing ; https://docs.braintrust.dev/reference/cli/experiments.md (redirected from https://www.braintrust.dev/docs/reference/cli/experiments.md)
- **Date accessed:** 2026-10-30
- **Evidence level:** vendor documentation
- **Track:** t2 tooling landscape

## Verified Quote(s)

pricing:
1. Starter plan: "$0 / month"
2. Starter limits: "1 GB processed data"; "10k scores"; "14-day retention"
3. Pro plan: "$249 / month"
4. Enterprise: "premium support with on-prem or hosted deployment for high volume or privacy-sensitive data."

CLI experiments reference:
5. "Compare summary metrics for up to eight experiments side by side: one base experiment and up to seven comparisons."
6. "The `list`, `view`, and `compare` subcommands also support `--json` output."

## Key finding

Braintrust gives good experiment history and base-vs-challenger comparison, but it is a hosted SaaS: the free tier keeps data 14 days and self-hosting is Enterprise-only, which collides with the no-hosted-service constraint. Its `Eval()` task can be any function, so a CLI agent could be wrapped, but the history value lives in the hosted backend.

Access status: live
