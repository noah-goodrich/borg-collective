# Autonomous Systems Evaluation Standard

- Citation: UK AI Safety Institute, "Autonomous Systems Evaluation Standard", page dated 2024-10-31.
- URL: https://ukgovernmentbeis.github.io/as-evaluation-standard
- Date accessed: 2026-10-30
- Evidence level: vendor documentation (government evaluation standard). Older than 2025; flagged.
- Access status: live

## Verified Quote(s)

> restrict your use of model graded scoring to content matching

> these approaches have known accuracy and bias issues

> required to detect if the repository has been included in training corpora

> manually check the logs to ensure there are no model API errors, tool issues or other failures

> Ideally, we want evaluations to behave the same every time we run them, and for the scores not to change over time given the same model.

## Key finding

UK AISI's standard restricts model-graded scoring to content matching because broader judging has known accuracy and bias issues, requires a canary string so training-corpus contamination can be detected, and requires manual log review for API and tool failures. It gives no guidance on runs per sample or confidence intervals.
