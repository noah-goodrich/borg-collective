# PR chains — one grid, time flows down

Generated 2026-08-20 10:09 · 9 open PRs
Navigate:  `*` on a node id toggles picture <-> details.  `gp` on a full ref opens the PR.
States:  v done   * ready/open   ~ draft   READY = every parent merged

## At a glance   (one cell per PR; > marks next)

viz-program        viz        X X >O                   noah-goodrich/borg-collective#158
ingle-t1-cutover   cutover    X X X X X >o X X         stillpoint-labs/stillpoint#48
ingle-t1-cutover   contract   X X X X X O              


## Program: viz-program

Give borg a truthful, cross-repo picture of PR state so mornings start from derived fact instead of memory.

Repos: noah-goodrich/borg-collective

### viz lane

    v n1   noah-goodrich/borg-collective#144
    |
    v n2   noah-goodrich/borg-collective#149
    |
    * n3   noah-goodrich/borg-collective#158   <-- NEXT

## Program: ingle-t1-cutover

Move ingle onto the shared stillpoint database: freeze writes, load prod data, flip the schema, and guard every app with a schema contract.

Repos: stillpoint-labs/ingle  ·  stillpoint-labs/reveal  ·  stillpoint-labs/stillpoint  ·  stillpoint-labs/troth

### cutover lane

    v n4   stillpoint-labs/stillpoint#37
    |
    v n5   stillpoint-labs/stillpoint#33
    |
    v n6   stillpoint-labs/stillpoint#39
    |
    v n7   stillpoint-labs/stillpoint#40
    |
    v n8   stillpoint-labs/stillpoint#50
    |
    ~ n9   stillpoint-labs/stillpoint#48   <-- NEXT
    |
    v n10  stillpoint-labs/stillpoint#58
    |
    v n11  stillpoint-labs/ingle#330

### contract lane

    v n12  stillpoint-labs/stillpoint#54
    |
    v n13  stillpoint-labs/stillpoint#55
    |
    v n14  stillpoint-labs/ingle#341
    |
    v n15  stillpoint-labs/reveal#59
    |
    v n16  stillpoint-labs/troth#83
    |
    * n17  stillpoint-labs/stillpoint#57


## Node details

### n1 · noah-goodrich/borg-collective#144 — DONE
    feat(viz-2): give story.json a generator (S1/S2/S3/S5, S6 partial)
    waits on: nothing — head of its lane
    unlocks: noah-goodrich/borg-collective#149

### n2 · noah-goodrich/borg-collective#149 — DONE
    fix(recon): credential leak in item refs + bridge recon to the raw gather (viz-2
    waits on: nothing — parent merged
    unlocks: noah-goodrich/borg-collective#158

### n3 · noah-goodrich/borg-collective#158 — READY
    feat(programs): borg-native declared edges + backfill from historical data.json
    waits on: nothing — parent merged
    GATE (decision): held for the PM6/PM7 coordinator and a review against personal projects
    unparked by: review of noah-goodrich/borg-collective#158 against real projects

### n4 · stillpoint-labs/stillpoint#37 — DONE
    T0.6: ingle cutover contract migration (drop 12 columns + dead table)
    waits on: nothing — head of its lane
    unlocks: stillpoint-labs/stillpoint#33

### n5 · stillpoint-labs/stillpoint#33 — DONE
    feat(migrations): T0.7 ingle cutover — additive member_meals + household_store_a
    waits on: nothing — parent merged
    unlocks: stillpoint-labs/stillpoint#39

### n6 · stillpoint-labs/stillpoint#39 — DONE
    feat(ingle-cutover): T1 prereqs — port ingle 0121 resolver fn + 0125 grant
    waits on: nothing — parent merged
    unlocks: stillpoint-labs/stillpoint#40

### n7 · stillpoint-labs/stillpoint#40 — DONE
    feat(ingle-cutover): T1 data-load script (build only — not yet run)
    waits on: nothing — parent merged
    unlocks: stillpoint-labs/stillpoint#50

### n8 · stillpoint-labs/stillpoint#50 — DONE
    feat(ingle-cutover): write-freeze companion scripts (freeze/unfreeze source)
    waits on: nothing — parent merged
    unlocks: stillpoint-labs/stillpoint#48

### n9 · stillpoint-labs/stillpoint#48 — DRAFT
    draft(cutover): write-freeze design for the ingle T1 load
    waits on: nothing — parent merged
    unlocks: stillpoint-labs/stillpoint#58
    GATE (decision): stillpoint drone must sign off; design-only, no DB touched
    unparked by: stillpoint drone review + approval on stillpoint-labs/stillpoint#48

### n10 · stillpoint-labs/stillpoint#58 — DONE
    chore(cutover): land the 3 already-applied ingle migrations + T1 cutover-run fix
    waits on: stillpoint-labs/stillpoint#48
    unlocks: stillpoint-labs/ingle#330

### n11 · stillpoint-labs/ingle#330 — DONE
    feat(cutover): T4 schema-flip — query ingle schema (code only, no env)
    waits on: nothing — parent merged

### n12 · stillpoint-labs/stillpoint#54 — DONE
    feat(schema-contract): relocate ingle drift guard here, generalized across tenan
    waits on: nothing — head of its lane
    unlocks: stillpoint-labs/stillpoint#55

### n13 · stillpoint-labs/stillpoint#55 — DONE
    feat(schema-contract): add reveal + troth contracts to the generalized guard
    waits on: nothing — parent merged
    unlocks: stillpoint-labs/ingle#341

### n14 · stillpoint-labs/ingle#341 — DONE
    feat(ci): guard the ingle <-> stillpoint schema-contract dual-source drift
    waits on: nothing — parent merged
    unlocks: stillpoint-labs/reveal#59

### n15 · stillpoint-labs/reveal#59 — DONE
    docs(directives): file schema-contract guard handoff
    waits on: nothing — parent merged
    unlocks: stillpoint-labs/troth#83

### n16 · stillpoint-labs/troth#83 — DONE
    docs(directives): file schema-contract guard handoff
    waits on: nothing — parent merged
    unlocks: stillpoint-labs/stillpoint#57

### n17 · stillpoint-labs/stillpoint#57 — READY
    feat(schema-contract): local runner + live-prod confirmation of auth trigger dri
    waits on: nothing — parent merged
    GATE (verification): needs a live-prod confirmation run against all four contracts
    unparked by: local runner executed against prod

## Open PRs in no chain (merge in any order)

    * noah-goodrich/dotfiles#15
         feat(zsh): Snowflake PAT env aliases + devcontainer venv auto-activate

    * stillpoint-labs/ingle#353
         docs(directive): pantry expiry — defer the surface, ship the confirm sweep

    * stillpoint-labs/ingle#354
         fix(pantry): remove the expiring_soon flag that has never once been true

    * stillpoint-labs/ingle#355
         docs(directive): session findings register — 2026-08-15/16

    * stillpoint-labs/reveal#58
         docs(directive): CI self-hosted optimization plan (target ~2-3m)

    ~ stillpoint-labs/troth#64
         refactor(plaid): edge-safe syncPlaidItem + recurring-sync plan (G4)
