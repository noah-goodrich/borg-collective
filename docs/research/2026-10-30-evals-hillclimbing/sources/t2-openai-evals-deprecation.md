# Source Record: OpenAI API deprecations page (Evals platform) and openai/evals repo

- **Full citation:** OpenAI, "Deprecations," OpenAI API docs, entry "2026-06-03: Evals platform"; and openai/evals GitHub repository README, read 2026-10-30.
- **URL:** https://developers.openai.com/api/docs/deprecations (redirected from https://platform.openai.com/docs/deprecations) ; https://github.com/openai/evals
- **Date accessed:** 2026-10-30
- **Evidence level:** vendor documentation
- **Track:** t2 tooling landscape

## Verified Quote(s)

Deprecations page, entry "2026-06-03: Evals platform":
1. "On June 3, 2026, we notified developers using the Evals platform that the product is being deprecated."
2. "Existing evals become read-only."  (row dated Oct 31, 2026)
3. "The Evals dashboard and API are scheduled to shut down."  (row dated Nov 30, 2026)
4. Migration guide title: "Moving from OpenAI Evals to Promptfoo"

openai/evals README:
5. "Please note that we are currently not accepting evals with custom code!"

Repository facts (not quotes): not archived; MIT license; 691 commits on main; about 19.7k stars; last commit date not visible in the fetched page.

## Key finding

OpenAI is shutting down its hosted Evals platform (read-only 2026-10-31, shutdown 2026-11-30) and points users to promptfoo; the open-source `openai/evals` repo is unarchived but refuses custom-code evals and targets model endpoints, not CLI agents. It is a skip for borg.

Access status: live (both pages)
