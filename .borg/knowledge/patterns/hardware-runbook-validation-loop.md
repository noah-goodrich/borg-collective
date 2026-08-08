---
id: hardware-runbook-validation-loop
project: borg-collective
domain: infrastructure
tags:
- runbook
- hardware
- documentation
- validation
preconditions: []
steps:
- Draft runbook steps in docs/ (e.g. work-machine-setup.md)
- Execute every step on real target hardware, not a VM
- Log each error or deviation as an erratum inline in the doc
- Fix all errata (expect ~5-6 for a new hardware config) before committing
- Commit validated runbook to main, not a branch, so it is immediately authoritative
pitfalls:
- Runbooks validated only on VMs routinely fail on real hardware due to firmware,
  driver, or partition differences
- Committing before hardware validation creates false confidence and causes wasted
  time for the next person
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-12 03:25:39.254212+00:00'
updated_at: '2026-06-12 03:25:39.254213+00:00'
---

# hardware-runbook-validation-loop

## description

Pattern for writing and validating a hardware setup runbook against real machines
