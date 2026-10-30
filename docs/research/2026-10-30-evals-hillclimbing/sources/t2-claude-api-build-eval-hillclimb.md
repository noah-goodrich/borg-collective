# Source Record: claude.dev blog, "Automating eval design and hillclimbing with Claude"

- **Full citation:** Lance Martin, "Automating eval design and hillclimbing with Claude," claude.dev Blog (Anthropic), Sep 28, 2026.
- **URL:** https://claude.dev/blog/automating-eval-design-and-hillclimbing/
- **Date accessed:** 2026-10-30
- **Evidence level:** vendor documentation (first-party engineering post)
- **Track:** t2 tooling landscape

## Verified Quote(s)

1. "Claude interviews you, builds the eval inside your codebase, and pauses for approval at specific points."
2. "When you run `/claude-api hillclimb` in Claude Code, Claude iterates to improve against a given evaluation."
3. "Use a train set that the hillclimber may read and a test set that is never seen."
4. "It reports the test result against the baseline with confidence intervals (Figure 7)."
5. "Claude runs the grader twice on the same output, and reports whether the verdict changed."
6. "The claude-api skill ships inside Claude Code, so updating gets you the latest version of these commands."
7. Editable surfaces list items: "Skills or instruction files"; "Tool descriptions"; "Your harness code"
8. "By default, these extra pages are static files that open locally and load nothing from the network."

## Key finding

Since Sep 28, 2026 Claude Code ships `/claude-api build-eval` and `/claude-api hillclimb`: an agent-authored in-repo eval with baseline plus confidence intervals and judge-stability checks, and a one-change-per-round hillclimber with a never-seen test split that can edit skills, instruction files and tool descriptions. The post does not say how round history is persisted and does not address Claude Code plugins or Cortex as the system under test (its examples are API apps and the claude-api skill itself).

Access status: live
