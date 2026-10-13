#!/usr/bin/env bats
# PINNED WORDING, not concepts. These assertions match exact strings/headings in
# skills/borg-link/SKILL.md. An editor changing SKILL.md's prose must update this file in
# lockstep — do not expect this suite to catch a meaning-preserving rewording; it only catches the
# specific mutations recorded in each test's non-vacuity note (see Phase 4, A6, phase4-spec.md /
# phase4-corrections.md). bats string-matching a markdown file cannot verify that a model actually
# follows the prose — the step-9 live smoke (run once, by hand, by the owner after redeploy) is
# the only real behavioral evidence this artifact has. Its result belongs in the placeholder below.
#
# STEP-9 SMOKE BASELINE (owner fills in after `borg setup` redeploy):
#   Fallback row forced: <TBD>
#   First tool call observed: <TBD>
#   Staleness downgraded?: <TBD>

load test_helper/setup

SKILL="${BORG_HOME}/skills/borg-link/SKILL.md"

@test "A6 primary path: SKILL.md runs the engine and no longer forbids shelling out" {
    run cat "$SKILL"
    [ "$status" -eq 0 ]
    [[ "$output" == *"borg link --json"* ]] || false
    [[ "$output" != *"Do **not** shell out to"* ]] || false
    [[ "$output" == *"--brief"* ]] || false
    [[ "$output" == *"--refresh"* ]] || false
}

@test "A6 fallback contract: the section exists, states its trigger, and forbids the staleness downgrade in exact words" {
    run cat "$SKILL"
    [ "$status" -eq 0 ]
    [[ "$output" == *"## Fallback"* ]] || false
    [[ "$output" == *"not in registry"* ]] || false
    [[ "$output" == *"repository '<name>' not in registry"* ]] || false
    [[ "$output" == *"RepositoryNotFound"* ]] || false
    [[ "$output" != *"ProjectNotFound"* ]] || false
    [[ "$output" == *"rc="* ]] || false
    [[ "$output" == *"has_live_window"* ]] || false
    [[ "$output" == *"null"* ]] || false
    [[ "$output" == *"apply NO staleness downgrade"* ]] || false
}

@test "A6 retired couplings stay retired" {
    run cat "$SKILL"
    [ "$status" -eq 0 ]
    [[ "$output" != *"lib/reaper.sh"* ]] || false
    [[ "$output" != *"docs/plans/severed"* ]] || false
    [[ "$output" != *"Cancelled ("* ]] || false
    [[ "$output" != *"grep -qx"* ]] || false
    [[ "$output" != *"~/.config/borg/registry.json"* ]] || false
}

@test "A6 the file exists and is non-empty" {
    [ -f "$SKILL" ]
    [ -s "$SKILL" ]
}

# --- Scope decides the page (Noah, 2026-10-13) ---------------------------------------------------
# The skill used to choose its mode with a `.borg-project` marker walk, and linked worktrees never
# get that marker, so /borg-link inside borg-probes rendered the registry-wide overview. The engine's
# `scope.kind` decides now. These cases pin that, plus the one behaviour that is cheap to RUN rather
# than string-match: the Step 1 jq pipe is extracted from the skill and executed against a stub
# `borg`, so the repository arm's whitelist is exercised, not just quoted.

_section() {
    awk -v from="$1" -v to="$2" '
        index($0, from) == 1 { want=1 }
        want && to != "" && index($0, to) == 1 && index($0, from) != 1 { exit }
        want { print }
    ' "$SKILL"
}

_step1_command() {
    awk '
        /^## Step 1/ { s=1; next }
        s && /^```bash/ { f=1; next }
        s && f && /^```/ { exit }
        s && f { print }
    ' "$SKILL"
}

_stub_borg() {
    mkdir -p "${BATS_TEST_TMPDIR}/stub"
    printf '#!/bin/sh\ncat "%s"\n' "$1" > "${BATS_TEST_TMPDIR}/stub/borg"
    chmod +x "${BATS_TEST_TMPDIR}/stub/borg"
}

@test "scope: the mode is chosen from scope.kind, not from the .borg-project marker" {
    run cat "$SKILL"
    [ "$status" -eq 0 ]
    [[ "$output" == *'## Step 1 — Run the engine, then branch on `scope.kind`'* ]] || false
    [[ "$output" == *'`.scope.kind == "orchestrator"` → the **Queen view**'* ]] || false
    [[ "$output" == *'`.scope.kind == "repository"` → the **repository page**'* ]] || false
    [[ "$output" == *'The `.borg-project` marker is NOT the mode decision.'* ]] || false
    [[ "$output" != *'**Mode selection.**'* ]] || false
    [[ "$output" != *'Marker found + no argument'* ]] || false
}

@test "scope: the marker walk survives only inside the Fallback section" {
    local fb_line walk_line
    fb_line="$(grep -n '^## Fallback' "$SKILL" | head -1 | cut -d: -f1)"
    walk_line="$(grep -n 'MARKER-WALK-BEGIN' "$SKILL" | head -1 | cut -d: -f1)"
    [ -n "$fb_line" ] && [ -n "$walk_line" ]
    [ "$walk_line" -gt "$fb_line" ]
    [ "$(grep -c 'MARKER-WALK-BEGIN' "$SKILL")" -eq 1 ]
}

@test "scope: user-facing text says Queen, contract names are unchanged" {
    run cat "$SKILL"
    [ "$status" -eq 0 ]
    [[ "$output" == *'## Queen view'* ]] || false
    [[ "$output" == *'Queen session'* ]] || false
    [[ "$output" == *'BORG_ORCHESTRATOR_ROOT'* ]] || false
    [[ "$output" == *'`scope.kind == "orchestrator"`'* ]] || false
}

@test "scope: the repository section never instructs rendering the board or repo-level sections" {
    run _section '## Repository scope' '## Fallback'
    [ "$status" -eq 0 ]
    [[ "$output" == *'Never render, even though `--json` carries it:'* ]] || false
    [[ "$output" == *'the registry-wide board'* ]] || false
    [[ "$output" == *'any other worktree or repository'* ]] || false
    [[ "$output" == *'QUEUED/SHIPPED'* ]] || false
    [[ "$output" != *'## The collective'* ]] || false
    [[ "$output" != *'Recently shipped'* ]] || false
    [[ "$output" != *'Queued:'* ]] || false
    [[ "$output" != *'Plan: <'* ]] || false
}

@test "scope: the Queen view does not leak into the repository page and vice versa" {
    run _section '## Queen view' '## Repository scope'
    [ "$status" -eq 0 ]
    [[ "$output" == *'## The collective'* ]] || false
    [[ "$output" == *'never use it to render a repository or a worktree'* ]] || false
    [[ "$output" != *'Never render, even though'* ]] || false
}

@test "scope: the repository page reads the checkpoint from its own directory, never the union" {
    run _section '## Repository scope' '## Fallback'
    [ "$status" -eq 0 ]
    [[ "$output" == *'<entry.path>/.borg/checkpoints'* ]] || false
    [[ "$output" == *'from nowhere else'* ]] || false
    [[ "$output" == *'sort -r | head -3'* ]] || false
    [[ "$output" == *'Never fall back to a checkpoint from another directory.'* ]] || false
    [[ "$output" == *'`focus.checkpoint_head`'* ]] || false
    [[ "$output" == *'`entry.summary`'* ]] || false
    [[ "$output" == *'you must not reconstruct them'* ]] || false
}

# DECISION 5 (2026-10-13): the skill renders the repository page in the SAME ORDER as the engine -- identity,
# session and checkpoints, then the Queen pointer, then the waiting row, and the page ENDS on the next-action
# line (link-unification L3). It used to end on the pointer, which made the skill's page differ from `borg link`'s.
@test "scope: the repository page puts the Queen pointer before WAITING and ends on the next action" {
    local line='For the overview of every repository, run /borg-link in the Queen session.'
    [ "$(grep -cxF "$line" "$SKILL")" -eq 1 ]
    run _section '## Repository scope' '## Fallback'
    [[ "$output" == *'the page ENDS on the `Next:` line'* ]] || false
    [[ "$output" != *'That last line is ALWAYS the final line'* ]] || false

    # The skeleton is the fenced block that holds the pointer. Order inside it is the contract.
    local block
    block="$(awk -v want="$line" '
        /^```/ { if (inblock) { if (hit) { printf "%s", buf; exit } buf=""; inblock=0 } else { inblock=1; buf="" } next }
        inblock { buf = buf $0 "\n"; if ($0 == want) hit=1 }
    ' "$SKILL")"
    [ -n "$block" ]
    local pointer_at waiting_at next_at last
    pointer_at="$(grep -nxF "$line" <<<"$block" | head -1 | cut -d: -f1)"
    waiting_at="$(grep -n '^Waiting:' <<<"$block" | head -1 | cut -d: -f1)"
    next_at="$(grep -n '^Next:' <<<"$block" | head -1 | cut -d: -f1)"
    [ -n "$pointer_at" ] && [ -n "$waiting_at" ] && [ -n "$next_at" ]
    [ "$pointer_at" -lt "$waiting_at" ]
    [ "$waiting_at" -lt "$next_at" ]
    last="$(grep -v '^[[:space:]]*$' <<<"$block" | tail -1)"
    [[ "$last" == "Next:"* ]] || false
}

@test "scope: a detached HEAD is reported as detached at the short sha, not as a branch called HEAD" {
    run _section '## Repository scope' '## Fallback'
    [[ "$output" == *'rev-parse --short HEAD'* ]] || false
    [[ "$output" == *'detached at <short sha>'* ]] || false
}

@test "scope: an unregistered directory gets the hint page, never the Queen view" {
    run cat "$SKILL"
    [[ "$output" == *'`.scope.unregistered == true` → the **hint page**'* ]] || false
    [[ "$output" == *'`borg add`'* ]] || false
    [[ "$output" == *'do not present the overview in its place'* ]] || false
    cat > "${BATS_TEST_TMPDIR}/unreg.json" <<'JSON'
{"version": 2, "generated_at": "t", "order": ["secret-a", "secret-b"], "projects": {"secret-a": {}, "secret-b": {}},
 "directives": [{"project": "secret-a", "title": "x"}], "grid": {"warnings": []}, "focus": null,
 "scope": {"kind": "orchestrator", "repository": null, "local": false, "unregistered": true}}
JSON
    _stub_borg "${BATS_TEST_TMPDIR}/unreg.json"
    local cmd
    cmd="$(_step1_command)"
    cmd="${cmd/ \[<project>\]/}"
    PATH="${BATS_TEST_TMPDIR}/stub:$PATH" run eval "$cmd"
    [ "$status" -eq 0 ]
    run jq -c 'keys' <<<"$output"
    [ "$output" = '["generated_at","scope","version"]' ]
}

@test "scope: Step 1 pipe, repository arm, passes a whitelist and drops every registry-wide key" {
    cat > "${BATS_TEST_TMPDIR}/repo.json" <<'JSON'
{"version": 2, "generated_at": "t", "capacity": {"over_limit": true}, "total_projects": 3,
 "order": ["p", "q"], "projects": {"p": {}, "q": {}},
 "directives": [{"project": "q", "title": "other"}], "assimilated": [{"title": "x"}],
 "grid": {"warnings": ["w"]}, "scope": {"kind": "repository", "repository": "p", "local": false},
 "focus": {"name": "p", "entry": {"path": "/w/p", "status": "waiting", "summary": "blended",
    "repo": "/w/.git"}, "plan": {"objective": "o"}, "checkpoints": ["a.md"],
    "checkpoint_head": "union", "directives": [1], "assimilated": [2]},
 "waiting": {"rows": [{"project": "p", "item": "session", "ref": null},
    {"project": "p", "item": "a repo PR", "ref": "o/r#9", "next_step": "merge #9"},
    {"project": "q", "item": "session", "ref": null}],
    "hidden_lines": ["+3 more"], "degraded": null}}
JSON
    _stub_borg "${BATS_TEST_TMPDIR}/repo.json"
    local cmd
    cmd="$(_step1_command)"
    cmd="${cmd/ \[<project>\]/}"
    [ -n "$cmd" ]
    PATH="${BATS_TEST_TMPDIR}/stub:$PATH" run eval "$cmd"
    [ "$status" -eq 0 ]
    run jq -c 'keys' <<<"$output"
    [ "$output" = '["entry","generated_at","scope","version","waiting"]' ]
    PATH="${BATS_TEST_TMPDIR}/stub:$PATH" run eval "$cmd"
    run jq -r '.entry | has("summary"), .path' <<<"$output"
    [ "${lines[0]}" = "false" ]
    [ "${lines[1]}" = "/w/p" ]
    PATH="${BATS_TEST_TMPDIR}/stub:$PATH" run eval "$cmd"
    run jq -c '[.waiting.rows[] | [.project, .item, .ref]], (.waiting | keys)' <<<"$output"
    [ "${lines[0]}" = '[["p","session",null]]' ]
    [ "${lines[1]}" = '["degraded","rows"]' ]
}

@test "scope: the repository page keeps only the session row, never repository PR rows" {
    run _section '## Repository scope' '## Fallback'
    [ "$status" -eq 0 ]
    [[ "$output" == *"including the repository's open-PR rows"* ]] || false
    [[ "$output" == *'keep only that row and drop every row with a `ref`'* ]] || false
    [[ "$output" == *'no PR rows'* ]] || false
    [[ "$output" == *"The session row's \`next_step\`"* ]] || false
}

@test "scope: Step 1 pipe, Queen arm, keeps the whole document and collapses directives" {
    cat > "${BATS_TEST_TMPDIR}/queen.json" <<'JSON'
{"version": 2, "order": ["p", "q"], "projects": {"p": {}, "q": {}}, "grid": {"warnings": []},
 "scope": {"kind": "orchestrator", "repository": null, "local": false}, "focus": null,
 "directives": [{"project": "p", "title": "a"}, {"project": "p", "title": "b"},
    {"project": "q", "title": "c"}]}
JSON
    _stub_borg "${BATS_TEST_TMPDIR}/queen.json"
    local cmd
    cmd="$(_step1_command)"
    cmd="${cmd/ \[<project>\]/}"
    PATH="${BATS_TEST_TMPDIR}/stub:$PATH" run eval "$cmd"
    [ "$status" -eq 0 ]
    run jq -c '[.order, (.projects | keys), (.directives | map({project, n}))]' <<<"$output"
    [ "$output" = '[["p","q"],["p","q"],[{"project":"p","n":2},{"project":"q","n":1}]]' ]
}
