# Automating eval design and hillclimbing with Claude

- Citation: Lance Martin, "Automating eval design and hillclimbing with Claude", Claude blog (Anthropic), published Sep 28, 2026.
- URL: https://claude.dev/blog/automating-eval-design-and-hillclimbing/
- Date accessed: 2026-10-30
- Evidence level: vendor documentation (Anthropic engineering blog; worked examples, no independent replication)
- Access status: live

## Verified Quote(s)

Section "/claude-api hillclimb" (loop setup):

> Before it starts, Claude asks what you want to optimize (e.g., performance, or cost while performance holds) and then splits the evaluation set at random into test and train.

> Before the first round, Claude checks that the eval's noise (how far the score can move by chance alone) is smaller than the smallest improvement you'd act on; if it isn't, it says so and suggests more repetitions or cases.

Section "/claude-api hillclimb" (per-round loop and accept/revert rule):

> Each round, Claude reads the previous round's train transcripts and proposes one change as a patch.

> At this point, Claude applies a check: if the `train` set improves but the `test` set is flat, Claude suspects overfitting and reverts the patch. If there is a regression, Claude reverts. If train and test sets improve, it keeps the patch (Figure 6).

Section "/claude-api hillclimb" (stop rule):

> When the score stalls for two or three rounds, Claude reads each remaining train failure and sorts it by cause.

> When hillclimbing completes, Claude leaves your code at the version that did best on the test set for your goal. It reports the test result against the baseline with confidence intervals (Figure 7). If the gain is within noise, it says so and recommends against merging.

Section "Hillclimbing", subsection "Overfitting" (guards):

> **Split the cases**. Use a train set that the hillclimber may read and a test set that is never seen. If the train set scores improve while the test set scores stay flat, then that is a common overfitting warning sign.

> If the hillclimber reads the failing transcripts, it should never paste the failure content into the prompt.

> Models can sometimes “reward hack” by directly finding answers to evaluations.

Section "Hillclimbing", "Attributable" bullet (skill triggering):

> The evaluation metric (the trigger rate for the skill) is directly coupled to the skill description that is being modified.

Section "/claude-api build-eval", "Diagnostic checks":

> **Headroom**: if the baseline already scores about 95% or higher, the skill warns the user and alerts that the hillclimb should aim to explore cost or latency rather than quality.

Section "/claude-api build-eval", "Designing examples":

> Five to ten cases you write by hand.

Section "Examples", "Hillclimbing for cost reduction":

> The benchmark included 44 tickets, with 30 used for the search and 14 held out.

> On the 14 held-out tickets that the search never saw, the final configuration scored 90.5% against the original setup's 78.6%, at about one fifth of the cost.

## Key finding

Anthropic's hillclimb loop automates both eval construction (interview, human-gated build-eval) and optimization (one root-cause patch per round, kept only if train and test both improve, reverted on test-flat or regression), with a pre-flight noise check, a stall-for-2-3-rounds stop, and a "within noise means do not merge" exit. Its cost example used 30 search plus 14 held-out cases, and it recommends optimizing cost at parity once the baseline is about 95% or higher, but it gives no minimum case count. Note that the test set is used to choose the final version, so it acts as a validation set, not a sealed one.
