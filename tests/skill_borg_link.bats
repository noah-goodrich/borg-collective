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
QUEEN="${BORG_HOME}/skills/borg-link/references/queen-view.md"
FALLBACK="${BORG_HOME}/skills/borg-link/references/fallback.md"
RATIONALE="${BORG_HOME}/skills/borg-link/references/rationale.md"

# SKILL.md is a router plus the repository page (context-diet S4b, #383). The Queen view, the Fallback
# and the design history moved to references/, so each assertion below reads the file its text lives in.

@test "references: SKILL.md names each references file with its read condition, and rationale.md is never read at runtime" {
    [ -f "$QUEEN" ] && [ -f "$FALLBACK" ] && [ -f "$RATIONALE" ]
    run cat "$SKILL"
    [[ "$output" == *'Read `references/queen-view.md`'*'Read it ONLY in this scope.'* ]] || false
    [[ "$output" == *'Read `references/fallback.md`'*'Read it only then.'* ]] || false
    [[ "$output" == *'the **repository page**'*'Read no references file.'* ]] || false
    [[ "$output" != *'references/rationale.md'* ]] || false
    run head -3 "$RATIONALE"
    [[ "$output" == *'editor history only'* ]] || false
    run cat "$RATIONALE"
    [[ "$output" == *'This file is never read at runtime.'* ]] || false
}

@test "references: SKILL.md states the drone-start rule" {
    run cat "$SKILL"
    [[ "$output" == *'the SessionStart hook already injected the latest checkpoint'* ]] || false
    [[ "$output" == *'never as a session-start ritual'* ]] || false
}

@test "A6 primary path: SKILL.md runs the engine and no longer forbids shelling out" {
    run cat "$SKILL"
    [ "$status" -eq 0 ]
    [[ "$output" == *"borg link --json"* ]] || false
    [[ "$output" != *"Do **not** shell out to"* ]] || false
    [[ "$output" == *"--brief"* ]] || false
    [[ "$output" == *"--refresh"* ]] || false
}

@test "A6 fallback contract: the section exists, states its trigger, and forbids the staleness downgrade in exact words" {
    run cat "$FALLBACK"
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
    run cat "$SKILL" "$QUEEN" "$FALLBACK"
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
    [[ "$output" == *"never the \`.borg-project\` marker or your guess from the cwd"* ]] || false
    [[ "$output" != *'**Mode selection.**'* ]] || false
    [[ "$output" != *'Marker found + no argument'* ]] || false
    run cat "$RATIONALE"
    [[ "$output" == *'The `.borg-project` marker is NOT the mode decision.'* ]] || false
}

@test "scope: the marker walk survives only inside the Fallback section" {
    local fb_line walk_line
    fb_line="$(grep -n '^## Fallback' "$FALLBACK" | head -1 | cut -d: -f1)"
    walk_line="$(grep -n 'MARKER-WALK-BEGIN' "$FALLBACK" | head -1 | cut -d: -f1)"
    [ -n "$fb_line" ] && [ -n "$walk_line" ]
    [ "$walk_line" -gt "$fb_line" ]
    [ "$(grep -c 'MARKER-WALK-BEGIN' "$FALLBACK")" -eq 1 ]
    [ "$(grep -c 'MARKER-WALK-BEGIN' "$SKILL")" -eq 0 ]
    [ "$(grep -c 'MARKER-WALK-BEGIN' "$QUEEN")" -eq 0 ]
}

@test "scope: user-facing text says Queen, contract names are unchanged" {
    run cat "$SKILL" "$QUEEN"
    [ "$status" -eq 0 ]
    [[ "$output" == *'## Queen view'* ]] || false
    [[ "$output" == *'Queen session'* ]] || false
    [[ "$output" == *'BORG_ORCHESTRATOR_ROOT'* ]] || false
    [[ "$output" == *'`scope.kind == "orchestrator"`'* ]] || false
}

@test "scope: the repository section never instructs rendering the board or repo-level sections" {
    run _section '## Repository scope' '## Guardrails'
    [ "$status" -eq 0 ]
    [[ "$output" == *'**Never render:**'* ]] || false
    [[ "$output" == *'the registry-wide board'* ]] || false
    [[ "$output" == *'any other worktree or repository'* ]] || false
    [[ "$output" == *'QUEUED/SHIPPED'* ]] || false
    [[ "$output" != *'## The collective'* ]] || false
    [[ "$output" != *'Recently shipped'* ]] || false
    [[ "$output" != *'Queued:'* ]] || false
    [[ "$output" != *'Plan: <'* ]] || false
}

@test "scope: the Queen view does not leak into the repository page and vice versa" {
    run cat "$QUEEN"
    [ "$status" -eq 0 ]
    [[ "$output" == *'## The collective'* ]] || false
    [[ "$output" == *'never use it to render a repository or a worktree'* ]] || false
    [[ "$output" != *'Never render, even though'* ]] || false
}

@test "scope: the repository page reads the checkpoint from its own directory, never the union" {
    run _section '## Repository scope' '## Guardrails'
    [ "$status" -eq 0 ]
    [[ "$output" == *'<entry.path>/.borg/checkpoints'* ]] || false
    [[ "$output" == *'and nowhere else'* ]] || false
    [[ "$output" == *'NAME-sort newest first'* ]] || false
    [[ "$output" == *"Never use another directory's checkpoint."* ]] || false
    [[ "$output" == *'`focus.checkpoint_head`'* ]] || false
    [[ "$output" == *'`entry.summary`'* ]] || false
    [[ "$output" == *'do not reconstruct'* ]] || false
}

# DECISION 5 (2026-10-13): the skill renders the repository page in the SAME ORDER as the engine -- identity,
# session and checkpoints, then the Queen pointer, then the waiting row, and the page ENDS on the next-action
# line (link-unification L3). It used to end on the pointer, which made the skill's page differ from `borg link`'s.
@test "scope: the repository page puts the Queen pointer before WAITING and ends on the next action" {
    local line='For the overview of every repository, run /borg-link in the Queen session.'
    [ "$(grep -cxF "$line" "$SKILL")" -eq 1 ]
    run _section '## Repository scope' '## Guardrails'
    [[ "$output" == *'the page ENDS on `Next:`'* ]] || false
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

@test "scope: Guardrails and Fallback also end the repository page on the next action, not the pointer" {
    ! grep -n -A1 'ends with the$' "$SKILL" "$FALLBACK" | grep -q 'Queen pointer line'
    ! grep -q 'the next action, the Queen pointer line' "$SKILL" "$FALLBACK"
    grep -q 'the Queen pointer line, the next action last' "$FALLBACK"
    grep -q 'the page ENDS on `Next:`' "$SKILL"
    grep -q 'ends on the$' "$RATIONALE"
}

@test "scope: a detached HEAD is reported as detached at the short sha, not as a branch called HEAD" {
    run _section '## Repository scope' '## Guardrails'
    [[ "$output" == *'rev-parse --short HEAD'* ]] || false
    [[ "$output" == *'detached at <short sha>'* ]] || false
}

@test "scope: an unregistered directory gets the hint page, never the Queen view" {
    run cat "$SKILL"
    [[ "$output" == *'`.scope.unregistered == true` → the **hint page**'* ]] || false
    [[ "$output" == *'`borg add`'* ]] || false
    [[ "$output" == *'Render no board or overview'* ]] || false
    cat > "${BATS_TEST_TMPDIR}/unreg.json" <<'JSON'
{"version": 2, "generated_at": "t", "order": ["secret-a", "secret-b"], "projects": {"secret-a": {}, "secret-b": {}},
 "directives": [{"project": "secret-a", "title": "x"}], "grid": {"warnings": []}, "focus": null,
 "scope": {"kind": "orchestrator", "repository": null, "local": false, "unregistered": true}}
JSON
    _stub_borg "${BATS_TEST_TMPDIR}/unreg.json"
    local cmd
    cmd="$(_step1_command)"
    cmd="${cmd/ \[<repository>\]/}"
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
    cmd="${cmd/ \[<repository>\]/}"
    [ -n "$cmd" ]
    PATH="${BATS_TEST_TMPDIR}/stub:$PATH" run eval "$cmd"
    [ "$status" -eq 0 ]
    run jq -c 'keys' <<<"$output"
    [ "$output" = '["compass","entry","generated_at","scope","version","waiting"]' ]
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
    run _section '## Repository scope' '## Guardrails'
    [ "$status" -eq 0 ]
    [[ "$output" == *'drop every row with a `ref`'* ]] || false
    run cat "$RATIONALE"
    [[ "$output" == *"including the repository's open-PR rows"* ]] || false
    run _section '## Repository scope' '## Guardrails'
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
    cmd="${cmd/ \[<repository>\]/}"
    PATH="${BATS_TEST_TMPDIR}/stub:$PATH" run eval "$cmd"
    [ "$status" -eq 0 ]
    run jq -c '[.order, (.projects | keys), (.directives | map({project, n}))]' <<<"$output"
    [ "$output" = '[["p","q"],["p","q"],[{"project":"p","n":2},{"project":"q","n":1}]]' ]
}

# --- The compass (the owner's map) ------------------------------------------------------------------
# The block is synthetic here; the cases RUN the extracted Step 1 pipe, so the whitelist is exercised.

_compass_json() {
    cat > "${BATS_TEST_TMPDIR}/compass.json" <<'JSON'
{"version": 2, "generated_at": "t", "order": ["p", "q"], "projects": {"p": {}, "q": {}},
 "directives": [], "grid": {"warnings": []}, "scope": {"kind": "SCOPE", "repository": "p", "local": false},
 "focus": {"name": "p", "entry": {"path": "/w/p", "status": "idle"}},
 "waiting": {"rows": [], "degraded": null},
 "compass": {"found": true, "map_dir": "/m", "leg": {"text": "ship alpha"},
   "destinations": [{"id": "alpha", "state": "late"}, {"id": "beta", "state": "on-track"}],
   "parking": [{"text": "revisit", "due": true}],
   "repositories": {"p": {"destination": "alpha", "on_leg": true}, "q": {"destination": "beta", "on_leg": false}}}}
JSON
    sed -i.bak "s/SCOPE/$1/" "${BATS_TEST_TMPDIR}/compass.json"
    _stub_borg "${BATS_TEST_TMPDIR}/compass.json"
}

@test "compass: the repository arm whitelists the leg and this repository's own slice, nothing registry-wide" {
    _compass_json repository
    local cmd
    cmd="$(_step1_command)"
    cmd="${cmd/ \[<repository>\]/}"
    PATH="${BATS_TEST_TMPDIR}/stub:$PATH" run eval "$cmd"
    [ "$status" -eq 0 ]
    run jq -c '.compass' <<<"$output"
    [ "$output" = '{"found":true,"map_dir":"/m","leg":{"text":"ship alpha"},"repository":{"destination":"alpha","on_leg":true},"destinations":[{"id":"alpha","state":"late"}]}' ]
}

@test "compass: the repository arm of an engine with no compass still answers, with nothing in the block" {
    _compass_json repository
    jq 'del(.compass)' "${BATS_TEST_TMPDIR}/compass.json" > "${BATS_TEST_TMPDIR}/old.json"
    _stub_borg "${BATS_TEST_TMPDIR}/old.json"
    local cmd
    cmd="$(_step1_command)"
    cmd="${cmd/ \[<repository>\]/}"
    PATH="${BATS_TEST_TMPDIR}/stub:$PATH" run eval "$cmd"
    [ "$status" -eq 0 ]
    run jq -c '.compass' <<<"$output"
    [ "$output" = '{"found":null,"map_dir":null,"leg":null,"repository":{},"destinations":[]}' ]
}

@test "compass: the Queen arm passes the whole compass block through" {
    _compass_json orchestrator
    local cmd
    cmd="$(_step1_command)"
    cmd="${cmd/ \[<repository>\]/}"
    PATH="${BATS_TEST_TMPDIR}/stub:$PATH" run eval "$cmd"
    [ "$status" -eq 0 ]
    run jq -c '[.compass.parking[0].due, (.compass.destinations | length), (.compass.repositories | keys)]' <<<"$output"
    [ "$output" = '[true,2,["p","q"]]' ]
}

@test "compass: the skill says how to read it, and the version gate is untouched" {
    run cat "$SKILL"
    [ "$status" -eq 0 ]
    [[ "$output" == *'**`.compass`**'* ]] || false
    [[ "$output" == *'no map at `<map_dir>`'* ]] || false
    [[ "$output" == *"off route: \`<repository>\` is not on today's leg"* ]] || false
    [[ "$output" == *'`== 2` → proceed silently.'* ]] || false
    [[ "$output" != *'parking:'* ]] || false
    run cat "$QUEEN"
    [[ "$output" == *'`due == true`'* ]] || false
    [[ "$output" == *'parking: `<text>` (look again `<look>`, seen `<seen>`)'* ]] || false
}

@test "scope: Step 1 pipe is compact and its Queen arm deletes eight unread repository fields, keeping the rest" {
    cat > "${BATS_TEST_TMPDIR}/queen2.json" <<'JSON'
{"version": 2, "order": ["p"], "grid": {"warnings": []}, "focus": null,
 "scope": {"kind": "orchestrator", "repository": null, "local": false},
 "directives": [{"project": "p", "title": "a"}],
 "projects": {"p": {"status": "idle", "summary": "s", "relative_activity": "1h", "tmux_window": "w",
    "waiting_reason": null, "future_field": 1, "claude_session_id": "x", "path": "/w/p", "repo": "/w/.git",
    "clock_divergence": 3, "tmux_session": "borg", "source": "claude", "notify_origin": "n",
    "last_activity": "t"}}}
JSON
    _stub_borg "${BATS_TEST_TMPDIR}/queen2.json"
    local cmd
    cmd="$(_step1_command)"
    [[ "$cmd" == *"jq -c '"* ]] || false
    cmd="${cmd/ \[<repository>\]/}"
    PATH="${BATS_TEST_TMPDIR}/stub:$PATH" run eval "$cmd"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    run jq -c '.projects.p | keys' <<<"$output"
    [ "$output" = '["future_field","relative_activity","status","summary","tmux_window","waiting_reason"]' ]
}

@test "scope: Queen arm drops the unread grid and compass fields, keeps the read ones and passes unknown ones" {
    cat > "${BATS_TEST_TMPDIR}/queen3.json" <<'JSON'
{"version": 2, "order": ["p"], "projects": {"p": {}}, "focus": null, "directives": [],
 "scope": {"kind": "orchestrator", "repository": null, "local": false},
 "grid": {"warnings": [], "future_grid_key": 7, "manifests": [
   {"id": "m", "path": "/w/m.json", "desc": "d", "repos": ["o/r"], "levels": [["o/r#1"]],
    "gates": [{"ref": "o/r#1", "kind": "decision"}], "ready": {"state": "known", "refs": []},
    "future_manifest_key": 1,
    "nodes": {"o/r#1": {"ref": "o/r#1", "title": "t", "state": "open", "state_source": "swept",
      "lane": "_default", "order": "1", "why": "w", "next": false, "gate": null, "level": 0, "seq": 0,
      "parents": [], "children": [], "draft": false, "ready": false, "future_node_key": 2}}}]},
 "compass": {"found": true, "map_dir": "/m", "today": "2026-10-15", "leg": {"text": "x"},
   "destinations": [{"id": "a", "status": "active", "state": "late", "domain": "d", "definition": "x",
     "target": "t", "next_waypoint": {"name": "n"}, "due": null, "repositories": ["p"]}],
   "parking": [{"text": "due one", "due": true}, {"text": "not yet", "due": false}],
   "repositories": {"p": {"destination": "a", "on_leg": true}}}}
JSON
    _stub_borg "${BATS_TEST_TMPDIR}/queen3.json"
    local cmd
    cmd="$(_step1_command)"
    cmd="${cmd/ \[<repository>\]/}"
    PATH="${BATS_TEST_TMPDIR}/stub:$PATH" run eval "$cmd"
    [ "$status" -eq 0 ]
    local doc="$output"
    run jq -c '.grid.manifests[0] | [has("path"), has("levels")]' <<<"$doc"
    [ "$output" = '[false,false]' ]
    run jq -c '.grid.manifests[0].nodes[] | [has("ref"), has("why"), has("order"), has("lane"), has("gate")]' <<<"$doc"
    [ "$output" = '[false,false,false,false,false]' ]
    run jq -c '.compass | [has("today"), (.destinations[0] | [has("domain"), has("definition"), has("target"), has("next_waypoint"), has("due")])]' <<<"$doc"
    [ "$output" = '[false,[false,false,false,false,false]]' ]
    run jq -c '.compass.parking | map(.text)' <<<"$doc"
    [ "$output" = '["due one"]' ]
    run jq -c '.grid.manifests[0] | [.id, .desc, .repos, .gates[0].kind, .ready.state, .future_manifest_key]' <<<"$doc"
    [ "$output" = '["m","d",["o/r"],"decision","known",1]' ]
    run jq -c '.grid.manifests[0].nodes["o/r#1"] | [.title, .state, .state_source, .next, .level, .seq, .parents, .children, .draft, .ready, .future_node_key]' <<<"$doc"
    [ "$output" = '["t","open","swept",false,0,0,[],[],false,false,2]' ]
    run jq -c '[.grid.future_grid_key, .compass.destinations[0].state, .compass.destinations[0].status, .compass.repositories.p.on_leg]' <<<"$doc"
    [ "$output" = '[7,"late","active",true]' ]
}
