# Source Record: LangSmith pricing and pytest integration docs

- **Full citation:** LangChain, "Pricing" page; LangSmith docs "pytest" how-to, read 2026-10-30.
- **URL:** https://www.langchain.com/pricing ; https://docs.langchain.com/langsmith/pytest.md
- **Date accessed:** 2026-10-30
- **Evidence level:** vendor documentation
- **Track:** t2 tooling landscape

## Verified Quote(s)

pricing:
1. Developer plan: "Up to 5k base traces / mo, then pay-as-you-go"
2. "Maximum of 1 seat (free)"
3. FAQ: "Base traces have a shorter retention period of 14 days."
4. Enterprise: "Self-hosted and hybrid deployment options"

pytest docs:
5. "This functionality requires Python SDK version `langsmith>=0.3.4`."
6. "Every decorated test case will be synced to a dataset example."
7. "The tests will run as normal, but the experiment logs will not be sent to LangSmith."

## Key finding

LangSmith's pytest plugin lets ordinary pytest tests (which could shell out to `claude -p` or `cortex`) become datasets and experiments, but history and comparison live in the hosted service with 14-day base-trace retention on the free plan and self-hosting only on Enterprise. With tracking off it is just pytest, so it adds nothing over the existing harness without the SaaS.

Access status: live
