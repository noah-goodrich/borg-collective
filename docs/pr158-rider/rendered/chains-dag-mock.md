# MOCK — a forked program, picture first

Navigation:  `*` on any two-character node id toggles picture ↔ details.  `gp` on any full ref opens the PR.

## Program: auth-hardening (mock)

Rotate every service onto scoped keypair auth, then flip enforcement on in one release.

Repos: acme/platform  ·  acme/warehouse  ·  acme/infra

States:  ✔ done   ● ready now   ○ waiting   ◌ draft


## The shape

    ✔ n1  platform#400
    │
    ├────────────────────┬────────────────────┐
    │                    │                    │
    ● n2  platform#420   ● n3  warehouse#87   ◌ n4  infra#12
    │                    │                    │
    ○ n5  platform#431   ○ n6  warehouse#93   │
    │                    │                    │
    └────────────────────┼────────────────────┘
                         │
                         ○ n7  infra#77       ◀ the join


**Work the three READY nodes today — nothing orders them.** Each merge on the left two columns unlocks the node
below it. The join needs all three columns finished.


## Node details

### n1 · acme/platform#400 — DONE
    base migration
    unlocked when it merged: platform#420, warehouse#87, infra#12

### n2 · acme/platform#420 — READY
    add auth scopes to the token service
    waits on: nothing — the base migration merged
    unlocks: acme/platform#431

### n3 · acme/warehouse#87 — READY
    rotate the warehouse keypair
    waits on: nothing — the base migration merged
    unlocks: acme/warehouse#93

### n4 · acme/infra#12 — READY (draft)
    inventory services still on password auth
    waits on: nothing — the base migration merged
    unlocks: acme/infra#77 (directly)

### n5 · acme/platform#431 — WAITING
    enforce scopes on internal calls
    waits on: acme/platform#420
    unlocks: acme/infra#77

### n6 · acme/warehouse#93 — WAITING
    cut consumers over to the new key
    waits on: acme/warehouse#87
    unlocks: acme/infra#77

### n7 · acme/infra#77 — WAITING (join)
    flip enforcement flag, all services
    waits on: acme/platform#431 + acme/warehouse#93 + acme/infra#12
    GATE (verification): staged rollout run must pass
    unparked by: canary deploy green for 24h


## What the renderer computes (spec, not prose)

- Rows = topological levels, columns = branches. Vertical always; time flows down.
- READY = state open AND every parent merged. All READY nodes are announced together — "next" is a set.
- Node ids appear exactly twice — picture and details — so vim `*` is the jump key, no plugin.
- Details carry the full ref so `gp` opens the PR from there.
