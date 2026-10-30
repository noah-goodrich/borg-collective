# Source Record: Hamel Husain, Evals FAQ (build custom tools; tooling gaps)

- **Full citation:** Hamel Husain, "Q: Should I build a custom annotation tool or use something off-the-shelf?" (May 29, 2025, modified June 1, 2025) and "Q: What gaps in eval tooling should I be prepared to fill myself?" (June 1, 2025, modified May 5, 2026), hamel.dev Evals FAQ.
- **URL:** https://hamel.dev/blog/posts/evals-faq/should-i-build-a-custom-annotation-tool-or-use-something-off-the-shelf.html ; https://hamel.dev/blog/posts/evals-faq/what-gaps-in-eval-tooling-should-i-be-prepared-to-fill-myself.html
- **Date accessed:** 2026-10-30
- **Evidence level:** practitioner
- **Track:** t2 tooling landscape (argument against adopting a framework)
- **Age flag:** first written mid-2025; the gaps page was modified 2026-05-05.

## Verified Quote(s)

custom annotation tool page:
1. "I often find that teams with custom annotation tools iterate ~10x faster."
2. "Off-the-shelf tools may be justified when you need to coordinate dozens of distributed annotators with enterprise access controls."

tooling gaps page:
3. "Be prepared to build most of your evaluators from scratch."
4. "In our experience, successful teams spend most of their effort on application-specific metrics."
5. "Generic metrics like “hallucination score” or “helpfulness rating” rarely capture what actually matters"

## Key finding

The leading evals practitioner argues that off-the-shelf eval platforms earn their keep mainly for large, distributed annotation teams, and that most evaluators and review views end up custom-built anyway. For a solo developer with a small case set this supports keeping the shell harness and adding a thin results layer rather than adopting a platform.

Access status: live (both pages)
