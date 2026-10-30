# Automating eval design and hillclimbing with Claude

- Citation: Lance Martin, "Automating eval design and hillclimbing with Claude", Claude blog (Anthropic), 2026-09-28.
- URL: https://claude.dev/blog/automating-eval-design-and-hillclimbing/
- Date accessed: 2026-10-30
- Evidence level: vendor documentation (practitioner engineering post from the model vendor)
- Access status: live

## Verified Quote(s)

Section "Validating the grader":

> After the inputs, Claude proposes the cheapest grader that fits your application’s output:

> If the output possibilities are constrained, it uses a code based check (exact match, a label from a fixed set, JSON that matches a schema, tests that pass).

> a second model reads the input, the output and a rubric written as checkable claims (not a 1-to-5 scale), and returns a score with its reasoning.

> You pick the judge model, and it should not be the model you are testing.

> When you’ve validated the grader, the skill tells you the size of the evaluation set (cases × repeats × model, and roughly how long it will take), runs the baseline, and prints the score with a confidence interval.

Section "Diagnostic checks":

> Claude runs the grader twice on the same output, and reports whether the verdict changed.

> Claude checks for timeouts, API errors, and cut-off answers to ensure infrastructure noise doesn't pass as model variance.

> if the baseline already scores about 95% or higher, the skill warns the user and alerts that the hillclimb should aim to explore cost or latency rather than quality.

Section "Eval design" (saturation and noise):

> The most capable model at the highest effort should be well below 100% on the evaluation, otherwise you can't reliably judge how changes impact performance.

> Before the first round, Claude checks that the eval's noise (how far the score can move by chance alone) is smaller than the smallest improvement you'd act on; if it isn't, it says so and suggests more repetitions or cases.

Section "Overfitting":

> Use a train set that the hillclimber may read and a test set that is never seen. If the train set scores improve while the test set scores stay flat, then that is a common overfitting warning sign.

> If the hillclimber reads the failing transcripts, it should never paste the failure content into the prompt.

Section "Hillclimbing" (attributable surfaces):

> The evaluation metric (the trigger rate for the skill) is directly coupled to the skill description that is being modified.

Section "Hillclimbing for cost reduction":

> The benchmark included 44 tickets, with 30 used for the search and 14 held out.

> One generally strong objective across various efforts is cost: even if an evaluation is saturated, you can ask Claude to find ways to reduce cost while keeping performance at parity.

Figure 2 alt text (section "Adversarial sampling"):

> with a few should-not-fire cases.

## Key finding

Anthropic's own hillclimb tooling defaults to the cheapest deterministic grader, uses a checkable-claim rubric (not 1-5) when a judge is unavoidable, forbids self-judging, and gates the loop on a noise-versus-minimum-effect check, a grader re-run consistency check, and a held-out split that is never read. A baseline at or above roughly 95% is treated as saturated for quality, redirecting the climb to cost or latency; skill-trigger rate is named (preceding sentence, which contains a hyperlink) as a successful hillclimb target.

## Notes

- The post does not discuss pass@k or pass^k.
- The worked example's held-out set is only 14 cases; no interval width is reported for it.
