# Inspect AI: Metrics (epochs, reducers, standard errors)

- Citation: UK AI Security Institute, Inspect AI documentation, "Metrics" page (undated; read 2026-10-30).
- URL: https://inspect.aisi.org.uk/metrics.html
- Date accessed: 2026-10-30
- Evidence level: vendor documentation (government open-source framework)
- Access status: live

## Verified Quote(s)

> Metrics normally operate on a reduced score view, where epoch scores for each sample are combined into a single score.

Reducers list:

> Reduce to the average of all scores.

> Reduce to the most common score.

> Reduce to the maximum of all scores.

Standard error:

> supports computing clustered standard errors via the

Bootstrap:

> Standard deviation of a bootstrapped estimate of the mean.

## Key finding

Inspect runs each sample for multiple epochs and reduces per-sample scores with a chosen reducer (mean, median, mode, max, pass_at_k, at_least_k) before computing metrics, and supports clustered and bootstrapped standard errors. The choice of reducer is how a harness encodes pass@k (any success) versus a consistency requirement (at_least_k, or k of k as pass^k).

## Notes

- The pass_at_k and at_least_k descriptions were returned only as partial fragments, so they are not quoted here.
- An older "Reducing Epochs" section on scorers.html no longer exists; content moved to metrics.html.
