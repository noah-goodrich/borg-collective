#!/usr/bin/env bats
# Tests for _borg_print_briefing via the `borg link --brief` subcommand.
#
# WHAT THE CASES HERE COVER: the narrative half of `--brief` and everything reached without a live
# sweep — the fallback ladder's reason lines, the two short circuits (empty registry, all-archived),
# the breadth of the projected prompt, `--all` forwarding, the xtrace guard, `waiting_reason` never
# rendering where a summary goes, and both of `_borg_print_briefing`'s no-page rungs (the document
# failing to BUILD and the fallback page failing to RENDER) being loud on stderr and non-zero out.
#
# (Deliberately NOT a case count, here or anywhere downstream. This header once carried one, and it
# was wrong by three within a day: a count is invalidated by every insertion and nothing fails when
# it goes stale — the same reason line pins in this repo are anchored by test name rather than by
# number. Say what the cases cover.)
#
# WHAT CHANGED HERE ON 2026-08-27, AND WHY NOTHING WAS SILENTLY DELETED. `--brief` no longer walks
# the registry: it builds the ONE `borg link` document, projects it into the narrative prompt, and
# renders THAT SAME DOCUMENT when the narrative is unavailable (docs/plans/directives/
# 2026-08-27-fold-brief-into-the-document.md). Most cases are untouched; three are consciously
# rewritten and one keeps its assertion with new provenance:
#   - "inactive projects appear under inactive header" — REWRITTEN. The "Inactive (>30 days):" block
#     and the 30-day active/inactive split were `_borg_print_briefing`'s own; they have no
#     counterpart in `render.SECTIONS` and are deliberately retired. The case now asserts the same
#     underlying claim — a long-dormant project is still ON the page, with its relative time — which
#     is the property the header existed to serve.
#   - "no debug variable lines in output" — REWRITTEN, THEN REWRITTEN AGAIN as "the xtrace guard
#     keeps trace lines out of the briefing". The first rewrite re-pointed the names and left the
#     case just as vacuous: bats never runs with xtrace on, so deleting the guard changed nothing.
#     It now drives borg under `zsh -x` with an empty PS4 and the mutation is verified. See the
#     case's own comment.
#   - "empty summary + set waiting_reason never displays waiting_reason as the summary" — REWRITTEN.
#     The \x1f field-shift defect it guarded is gone with the `read` loop (JSON cannot field-shift),
#     but the SEMANTIC claim still has teeth: `waiting_reason` is on the wire and the board row must
#     never print it as a summary. Re-pointed at the document.
#   - "empty registry shows scan hint" — SAME ASSERTION, NEW ORIGIN. The hint now comes from the
#     document's own `(.order | length) == 0` short circuit rather than a registry read. (It keyed
#     off `total_projects` on the first pass, which is the UNFILTERED count and silently stopped
#     firing for an all-archived registry; a paired case below covers that half.)
# The `fallback_reason` ladder's four branches, and the document rendering under each, are pinned in
# tests/link_sweep.bats where a sweep genuinely runs — see its "fallback" block. Asserting the
# subprocess count here would be vacuous: setup_temp_dirs neutralizes both network seams.

load test_helper/setup

BORG_CMD="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs

    # Mock bin dir — borg.zsh resets PATH, so use BORG_PATH_PREFIX to inject mocks
    export MOCK_BIN="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$MOCK_BIN"
    export BORG_PATH_PREFIX="$MOCK_BIN"

    # Seed registry: one waiting project (recent) + one inactive
    local recent
    recent=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    cat > "$BORG_REGISTRY" <<EOF
{
  "projects": {
    "my-active-project": {
      "path": "/tmp/my-active-project",
      "status": "waiting",
      "source": "cli",
      "last_activity": "$recent",
      "summary": "Working on the login feature.",
      "waiting_reason": "Blocked on design review"
    },
    "old-project": {
      "path": "/tmp/old-project",
      "status": "idle",
      "source": "cli",
      "last_activity": "2020-01-01T00:00:00Z",
      "summary": "Old work."
    }
  }
}
EOF

    # Default: stub claude to fail (simulates not-logged-in)
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$MOCK_BIN/claude"
}

# ── Fallback (claude unavailable) ─────────────────────────────────────────────

@test "briefing: fallback shows active project when claude fails" {
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    [[ "$output" == *"my-active-project"* ]] || false
}

@test "briefing: fallback shows project status" {
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    [[ "$output" == *"waiting"* ]] || false
}

# REWRITTEN 2026-08-27. Was: asserts an "Inactive (>30 days):" header. That header, and the 30-day
# split that fed it, belonged to the deleted registry walk and have no counterpart in the document's
# seven-section spine — the board shows every non-archived project with its relative time and lets
# the reader see dormancy rather than bucketing it. The claim worth keeping is that a project last
# touched in 2020 is still ON the page and still says how long ago that was, which is what a reader
# used the header for.
@test "briefing: a long-dormant project still renders, with how long ago it was touched" {
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    [[ "$output" == *"old-project"* ]] || false
    # `relative_activity` off the wire, not a zsh recomputation. core.relative_time's last bucket is
    # "<N>d ago" with no year branch, and 2020-01-01 is four digits of days back from any date this
    # suite can run on — so a four-or-more-digit day count is the assertion that the dormant row
    # carries a real age rather than "never" or a blank.
    [[ "$output" =~ [0-9]{4,}d\ ago ]] || false
}

# REWRITTEN TWICE, AND THE FIRST REWRITE WAS STILL DECORATION. The subject is the
# `setopt LOCAL_OPTIONS; set +x` at the top of _borg_print_briefing. The original case named locals
# (`proj_status=`, `rel_time='`) that the 2026-08-27 fold deleted, so it could never fail again; the
# first rewrite re-pointed it at the NEW locals but kept invoking borg the ordinary way — and bats
# never runs with xtrace on, so deleting `set +x` produced no trace at all and the case stayed green
# either way. New names, same vacuum.
#
# THE FIX IS THE INVOCATION, NOT THE NAMES: drive borg under `zsh -x` with an EMPTY PS4, which is
# exactly the condition the guard's own comment describes ("trace output pollutes the briefing when
# PS4 is empty" — with the default `+%N:%i> ` prefix a reader can at least tell trace from output).
# `setopt LOCAL_OPTIONS` scopes the suppression to this function, so the rest of the script still
# traces and the assertions below are specifically about the briefing's own locals.
#
# MUTATION THAT TURNS THIS RED, VERIFIED: delete the `set +x` line. Measured 7 matching trace lines
# on the author's machine — `doc=`, `rows=`, `payload=`, `_brief_py_args=` all appear verbatim at
# column 0.
@test "briefing: the xtrace guard keeps trace lines out of the briefing" {
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "Focus: my-active-project — waiting on design review"
EOF
    chmod +x "$MOCK_BIN/claude"

    local trace="${BATS_TEST_TMPDIR}/xtrace.log"
    run env PS4= zsh -x "$BORG_CMD" link --brief --local
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; false; }
    # The narrative really was reached, so the whole function body ran under the guard rather than
    # returning early somewhere above it.
    [[ "$output" == *"Focus: my-active-project"* ]] || false
    printf '%s\n' "$output" > "$trace"

    # ANCHORED AT COLUMN 0, via grep rather than a `[[ ]]` glob: with PS4 empty a trace line IS the
    # bare assignment, while these same names appear mid-line inside the jq program text and the
    # prompt, both of which are legitimately on stdout. `grep` exits 1 for "no lines selected", which
    # is the passing case; a match exits 0 and prints the offending lines into the failure output.
    run grep -nE '^(doc|payload|rows|_brief_py_args|briefing_prompt)=' "$trace"
    [ "$status" -eq 1 ] || { printf 'xtrace leaked:\n%s\n' "$output" >&2; false; }
}

# ── Error message filtering ────────────────────────────────────────────────────

@test "briefing: 'Not logged in' from claude triggers fallback" {
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "Not logged in · Please run /login"
exit 0
EOF
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    # Error message must NOT appear in output
    [[ "$output" != *"Not logged in"* ]] || false
    # Fallback project listing must appear instead
    [[ "$output" == *"my-active-project"* ]] || false
}

@test "briefing: API error from claude triggers fallback" {
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "Error: API error 401 Unauthorized"
exit 1
EOF
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    [[ "$output" == *"my-active-project"* ]] || false
}

# ── Fallback provenance (2026-08-10 directive: silent fallback is the core defect) ────────────

@test "briefing: fallback with nonzero exit prints a reason line naming the exit code" {
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "Error: API error 401 Unauthorized" >&2
exit 1
EOF
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    [[ "$output" == *"narrative unavailable"* ]] || false
    [[ "$output" == *"exited 1"* ]] || false
    # The captured stderr text must actually surface, not be swallowed like the old /dev/null path.
    [[ "$output" == *"API error 401 Unauthorized"* ]] || false
}

@test "briefing: fallback distinguishes the not-logged-in case from a generic exit" {
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "Not logged in · Please run /login"
exit 0
EOF
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    [[ "$output" == *"narrative unavailable"* ]] || false
    [[ "$output" == *"not logged in"* ]] || false
}

@test "briefing: successful LLM output prints no fallback-reason line" {
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "Focus: my-active-project — waiting on design review"
EOF
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    [[ "$output" != *"narrative unavailable"* ]] || false
}

# ── LLM briefing (claude succeeds) ────────────────────────────────────────────

@test "briefing: LLM output is shown when claude succeeds" {
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "my-active-project  [waiting, just now]"
echo "  Last: Working on the login feature."
echo "  Next: Finish the design review."
echo "  Blocked: Blocked on design review"
echo ""
echo "Focus: my-active-project — waiting on design review"
EOF
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    [[ "$output" == *"my-active-project"* ]] || false
    [[ "$output" == *"Focus:"* ]] || false
}

# ── waiting_reason is never a summary (2026-08-10 directive defect 2, re-pointed) ─────────────
#
# ORIGINALLY a field-collapse regression: with a tab delimiter, an empty summary shifted
# waiting_reason into its place and the fallback printed a blocker string as if it were work done.
# The \x1f delimiter fixed it, and the 2026-08-27 fold deleted the `read` loop entirely — JSON has
# no field-shift failure mode, so the MECHANISM this case guarded is gone.
#
# KEPT ANYWAY, RE-POINTED AT THE DOCUMENT, because the SEMANTIC claim is a shipped acceptance
# criterion and is still live: `waiting_reason` rides the wire (`.projects[].waiting_reason`) and the
# board row must never render it where a summary goes. Retiring the case with the delimiter would
# have dropped that guarantee silently.

@test "briefing: empty summary + set waiting_reason never displays waiting_reason as the summary" {
    local recent
    recent=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    cat > "$BORG_REGISTRY" <<EOF
{
  "projects": {
    "field-collapse-project": {
      "path": "/tmp/field-collapse-project",
      "status": "waiting",
      "source": "cli",
      "last_activity": "$recent",
      "summary": null,
      "waiting_reason": "Claude is waiting for your input"
    }
  }
}
EOF
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    [[ "$output" == *"field-collapse-project"* ]] || false
    # The board row prints name / status / relative time and NOTHING from waiting_reason —
    # render._overview_row never reads that field. A substring match on the reason text is the
    # assertion regardless of which renderer produced the page.
    [[ "$output" != *"Claude is waiting for your input"* ]] || false
}

# ── Empty registry ─────────────────────────────────────────────────────────────
#
# SAME ASSERTION, NEW ORIGIN (2026-08-27). The hint used to come from a registry read that found no
# active and no inactive names; it now comes from the DOCUMENT's own
# `(.order // []) | length == 0`, which is why the short circuit survived the fold at all: it is the
# one case where there is nothing for a narrative to say and paying `claude -p` to say it is waste.
#
# `.order`, NOT `.total_projects` — this comment named the latter for one round and was describing
# code that had already been changed. `core.assemble` fills `total_projects` from the UNFILTERED
# project map on purpose, so it counts archived rows the page never shows; `.order` is the
# post-archived-filter list, and it is exactly the list the projection below feeds to the prompt. The
# paired all-archived case is where the difference bites, and it carries the argument in full.

@test "briefing: empty registry shows scan hint" {
    echo '{"projects":{}}' > "$BORG_REGISTRY"
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    [[ "$output" == *"borg scan"* ]] || false
}

# AN ALL-ARCHIVED REGISTRY IS THE OTHER HALF OF THE SAME SHORT CIRCUIT, and it is the half that
# `total_projects` got wrong. `core.assemble` sets `total_projects` from the UNFILTERED project map
# deliberately, so an all-archived registry reports `total_projects: 1` with `order: []` — the short
# circuit did not fire, and `claude -p` was billed to narrate a board with no rows on it. The deleted
# registry walk excluded archived entries from BOTH its lists, so this printed the scan hint before
# the fold. `.order` is the list actually projected into the prompt, so it is the count that answers
# the question the short circuit is asking.
#
# MUTATION THAT TURNS THIS RED: key the short circuit off `.total_projects // 0` again.
@test "briefing: an all-archived registry short-circuits without an LLM call" {
    export CLAUDE_TRACE="${BATS_TEST_TMPDIR}/claude-trace.log"
    : > "$CLAUDE_TRACE"
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "called" >> "$CLAUDE_TRACE"
echo "NARRATIVE-THAT-SHOULD-NOT-HAPPEN"
EOF
    chmod +x "$MOCK_BIN/claude"

    cat > "$BORG_REGISTRY" <<'EOF'
{
  "projects": {
    "retired-project": {
      "path": "/tmp/retired-project",
      "status": "archived",
      "source": "cli",
      "last_activity": "2020-01-01T00:00:00Z",
      "summary": "Done with this one."
    }
  }
}
EOF

    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; false; }
    [[ "$output" == *"borg scan"* ]] || false
    [[ "$output" != *"NARRATIVE-THAT-SHOULD-NOT-HAPPEN"* ]] || false
    [ ! -s "$CLAUDE_TRACE" ]
}

# ── The prompt's breadth is the page's breadth ────────────────────────────────
#
# THE DEFECT THIS PINS, MEASURED BEFORE IT WAS FIXED: in repository scope the projection read the
# TOP-LEVEL `.directives` / `.assimilated`, which `cli.py`'s `need_aggregate = mode == "json" or ...`
# always fills with the registry-WIDE aggregate — while `render._scoped_rows` narrows QUEUED and
# SHIPPED to `doc.focus[key]` for the same scope. On the author's real registry that was
# "QUEUED: 141 open directives" plus three collective-wide plan titles in the prompt, against
# "nothing queued" / "nothing shipped yet" on the fallback page rendered from THE SAME BYTES. One
# invocation, two answers — which is the failure class the whole fold exists to remove.
#
# ASSERTED ON THE PROMPT, not on prose: the mock captures `claude -p`'s argument verbatim, so the
# case reads the exact bytes the model would have been handed.
#
# MUTATION THAT TURNS THIS RED: change `$breadth.directives` / `$breadth.assimilated` back to
# `$d.directives` / `$d.assimilated` in _borg_print_briefing's jq.
@test "briefing: in repository scope the prompt's QUEUED/SHIPPED match the page's, not the registry's" {
    local ws="${BATS_TEST_TMPDIR}/ws"
    mkdir -p "$ws/alpha/docs/plans/directives" "$ws/alpha/docs/plans/assimilated" "$ws/beta"
    echo "# Alpha's very own directive" > "$ws/alpha/docs/plans/directives/2026-08-01-alpha-only.md"
    echo "# Alpha's very own shipped plan" > "$ws/alpha/docs/plans/assimilated/2026-07-01-alpha-shipped.md"

    cat > "$BORG_REGISTRY" <<EOF
{
  "projects": {
    "alpha": {
      "path": "$ws/alpha",
      "status": "idle",
      "source": "cli",
      "last_activity": "2026-08-01T00:00:00Z",
      "summary": "Alpha."
    },
    "beta": {
      "path": "$ws/beta",
      "status": "idle",
      "source": "cli",
      "last_activity": "2026-08-02T00:00:00Z",
      "summary": "Beta."
    }
  }
}
EOF

    export PROMPT_FILE="${BATS_TEST_TMPDIR}/prompt.txt"
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "-p" ] && printf '%s' "$2" > "$PROMPT_FILE"
echo "NARRATIVE"
EOF
    chmod +x "$MOCK_BIN/claude"

    run bash -c "cd '$ws/beta' && '$BORG_CMD' link --brief --local"
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; false; }

    run cat "$PROMPT_FILE"
    [ "$status" -eq 0 ]
    # The scope really is beta's — without this the QUEUED assertion below could pass for the wrong
    # reason (an orchestrator-scope document that happens to have found no directives at all).
    [[ "$output" == *"SCOPE: repository — beta"* ]] || false
    [[ "$output" == *"QUEUED: 0 open directives"* ]] || false
    [[ "$output" != *"SHIPPED RECENTLY:"* ]] || false
    [[ "$output" != *"alpha-only"* ]] || false
    [[ "$output" != *"alpha-shipped"* ]] || false

    # THE CONTROL. The same registry, one directory up: orchestrator scope must still carry the
    # aggregate, or the assertions above would be satisfied by a projection that dropped the two
    # lists entirely.
    run bash -c "cd '$ws' && '$BORG_CMD' link --brief --local"
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; false; }
    run cat "$PROMPT_FILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"SCOPE: orchestrator"* ]] || false
    [[ "$output" == *"QUEUED: 1 open directives"* ]] || false
    [[ "$output" == *"SHIPPED RECENTLY:"* ]] || false
}

# ── A broken projection is a fallback, never an empty prompt ──────────────────
#
# `payload=$(... | jq -r '...' 2>/dev/null) || payload=""` discarded jq's stderr AND its exit status,
# so a projection that broke against a future document shape shipped a prompt reading `DOCUMENT:`
# followed by nothing. The model then invented a briefing from an empty board and it printed with NO
# reason line, because `fallback_reason` was only ever set on `claude` failures — a confident
# narrative with no input, which is precisely the shape this directive exists to make impossible.
#
# THE MOCK IS A PASS-THROUGH, failing ONLY the projection. borg.zsh runs jq many times per
# invocation (the `.order` short circuit immediately above it, for one), so hiding jq outright would
# take the empty-registry branch and never reach the code under test.
#
# MUTATION THAT TURNS THIS RED: delete the `if [[ -z "$payload" ]]` block that sets
# `fallback_reason` (restoring `2>/dev/null`), which lets the empty prompt reach `claude -p`.
@test "briefing: a failed projection falls back to the document and never pays for claude" {
    local real_jq
    real_jq=$(command -v jq)
    [ -n "$real_jq" ]

    export CLAUDE_TRACE="${BATS_TEST_TMPDIR}/claude-trace.log"
    : > "$CLAUDE_TRACE"
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "called" >> "$CLAUDE_TRACE"
echo "NARRATIVE-FROM-AN-EMPTY-BOARD"
EOF
    chmod +x "$MOCK_BIN/claude"

    cat > "$MOCK_BIN/jq" <<EOF
#!/usr/bin/env bash
for a in "\$@"; do
    case "\$a" in
        *"SCOPE: "*)
            echo "jq: error: MOCKED-PROJECTION-FAILURE" >&2
            exit 5
            ;;
    esac
done
exec "$real_jq" "\$@"
EOF
    chmod +x "$MOCK_BIN/jq"

    run "$BORG_CMD" link --brief --local
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; false; }
    [[ "$output" == *"narrative unavailable"* ]] || false
    [[ "$output" == *"the document projection produced nothing"* ]] || false
    # jq's own stderr reaches the reason line, the same contract the `claude -p exited N` branch has.
    [[ "$output" == *"MOCKED-PROJECTION-FAILURE"* ]] || false
    # The real page renders under it, from the document that was built before the projection ran.
    [[ "$output" == *"THE BORG COLLECTIVE"* ]] || false
    [[ "$output" == *"my-active-project"* ]] || false
    # And nothing was billed for a briefing with no input.
    [[ "$output" != *"NARRATIVE-FROM-AN-EMPTY-BOARD"* ]] || false
    [ ! -s "$CLAUDE_TRACE" ]
}

# ── `--all` reaches the document build ────────────────────────────────────────
#
# UNPINNED UNTIL 2026-08-28, AND THAT IS THE POINT. `_borg_print_briefing`'s whole forwarding
# contract is two lines (`--all`, `--local`); `--local` is pinned by subprocess count in
# tests/link_sweep.bats, but `--all` had NOTHING. Deleting `(( ${1:-0} )) && _brief_py_args+=(--all)`
# left briefing.bats, link_sweep.bats and cli_contract.bats all green with the flag gone, so
# `borg link --brief --all` would have silently degraded to `borg link --brief` — the same
# capability-nothing-asserts shape as `borg recon` shipping dead (CLAUDE.md, "Learned").
#
# ASSERTED ON THE PROJECTED PROMPT, WITH ITS OWN CONTROL. The mock captures `claude -p`'s argument
# verbatim, so the case reads the bytes the document actually produced. An archived project is the
# only observable `--all` has: it is the sole thing the flag adds to `.order`. The no-flag leg is
# what makes the assertion honest — without it, "retired-project appears" would also pass for a
# build that ignored archiving altogether.
#
# MUTATION THAT TURNS THIS RED, VERIFIED: delete the `--all` line from `_borg_print_briefing`.
@test "briefing: --all puts archived projects in the prompt, and its absence keeps them out" {
    export PROMPT_FILE="${BATS_TEST_TMPDIR}/prompt.txt"
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "-p" ] && printf '%s' "$2" > "$PROMPT_FILE"
echo "NARRATIVE"
EOF
    chmod +x "$MOCK_BIN/claude"

    cat > "$BORG_REGISTRY" <<'EOF'
{
  "projects": {
    "live-project": {
      "path": "/tmp/live-project",
      "status": "idle",
      "source": "cli",
      "last_activity": "2026-08-01T00:00:00Z",
      "summary": "Still going."
    },
    "retired-project": {
      "path": "/tmp/retired-project",
      "status": "archived",
      "source": "cli",
      "last_activity": "2026-07-01T00:00:00Z",
      "summary": "Done with this one."
    }
  }
}
EOF

    # THE CONTROL: no --all, so the archived row is off the wire and out of the prompt.
    run "$BORG_CMD" link --brief --local
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; false; }
    run cat "$PROMPT_FILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PROJECT: live-project"* ]] || false
    [[ "$output" != *"PROJECT: retired-project"* ]] || false

    # THE FLAG: same registry, same command, one flag — the archived row is now on the board the
    # narrative is asked to describe.
    : > "$PROMPT_FILE"
    run "$BORG_CMD" link --brief --all --local
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; false; }
    run cat "$PROMPT_FILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PROJECT: live-project"* ]] || false
    [[ "$output" == *"PROJECT: retired-project"* ]] || false
}

# ── Both no-page rungs are loud, on STDERR, and are not exit 0 ────────────────
#
# `_borg_print_briefing` has exactly two ways to return having printed no page: the document fails to
# BUILD (`_borg_py ... --json` produces nothing) or the fallback page fails to RENDER
# (`--render-document` fails). Both used to `warn` — which writes to STDOUT, see its definition beside
# `info`/`die` at the top of borg.zsh — and return 0. That is the silent-failure shape
# docs/plans/directives/2026-08-10-briefing-fallback-and-summary-provenance.md Phase 1 exists to
# remove, and the fallback rung reintroduced it at the last rung of the ladder that implements it.
#
# THE ASSERTIONS READ SEPARATED STREAMS, NOT `$output`, AND THAT IS THE POINT OF THIS BLOCK.
# bats `run` MERGES fd2 into `$output`, so a case that asserts `[[ "$output" == *"Could not ..."* ]]`
# passes identically whether the reason went to stdout or stderr: deleting `>&2` from borg.zsh left
# all three suites green. The two cases below redirect the streams to separate files and assert on
# each — the reason IS on stderr, and is NOT on stdout, which is the half that has teeth. Files
# rather than `run --separate-stderr` so the pin does not depend on the bats version CI installs.
# Same family as CLAUDE.md's "`cmd >> file 2>/dev/null` does NOT silence a redirect-open error" and
# the zsh-EPIPE-under-`run` note: this repo keeps getting bitten by which stream a byte landed on.
#
# THE MOCKS ARE PASS-THROUGHS ON python3, each failing exactly ONE argument. Hiding python3 outright
# would take the BUILD branch for both cases and the render case would never reach its own code.
#
# MUTATION THAT TURNS THESE RED, VERIFIED BOTH WAYS: (a) drop `>&2` from either `warn` — the stderr
# assertion fails and the "not on stdout" assertion fails with it; (b) restore `|| true` / `return 0`
# on either rung — the non-zero assertion fails.

# Reads a command's streams into `$brief_stdout` / `$brief_stderr` / `$brief_status`, unmerged.
# `run` is deliberately NOT used: its merge is exactly what these cases exist to defeat.
_run_brief_separated() {
    local out_file="${BATS_TEST_TMPDIR}/brief.out"
    local err_file="${BATS_TEST_TMPDIR}/brief.err"
    : > "$out_file"
    : > "$err_file"
    brief_status=0
    "$BORG_CMD" "$@" > "$out_file" 2> "$err_file" || brief_status=$?
    brief_stdout=$(cat "$out_file")
    brief_stderr=$(cat "$err_file")
}

@test "briefing: a failed document build names its reason on stderr and exits non-zero" {
    local real_python
    real_python=$(command -v python3)
    [ -n "$real_python" ]

    cat > "$MOCK_BIN/python3" <<EOF
#!/usr/bin/env bash
for a in "\$@"; do
    if [ "\$a" = "--json" ]; then
        echo "MOCKED-BUILD-FAILURE" >&2
        exit 9
    fi
done
exec "$real_python" "\$@"
EOF
    chmod +x "$MOCK_BIN/python3"

    _run_brief_separated link --brief --local
    [ "$brief_status" -eq 9 ] || {
        printf 'expected exit 9, got %s\nSTDOUT:\n%s\nSTDERR:\n%s\n' \
            "$brief_status" "$brief_stdout" "$brief_stderr" >&2
        false
    }
    # THE CHANNEL, not just the text.
    [[ "$brief_stderr" == *"Could not build the borg link document"* ]] || false
    [[ "$brief_stdout" != *"Could not build the borg link document"* ]] || false
    # The exit code and the child's own stderr both reach the reason line, the same contract the
    # `claude -p exited N`, projection and render branches have.
    [[ "$brief_stderr" == *"exit 9"* ]] || false
    [[ "$brief_stderr" == *"MOCKED-BUILD-FAILURE"* ]] || false
    # And nothing resembling a page was printed.
    [[ "$brief_stdout" != *"THE BORG COLLECTIVE"* ]] || false
}

@test "briefing: a failed fallback render names its reason on stderr and exits non-zero" {
    local real_python
    real_python=$(command -v python3)
    [ -n "$real_python" ]

    cat > "$MOCK_BIN/python3" <<EOF
#!/usr/bin/env bash
for a in "\$@"; do
    if [ "\$a" = "--render-document" ]; then
        echo "MOCKED-RENDER-FAILURE" >&2
        exit 7
    fi
done
exec "$real_python" "\$@"
EOF
    chmod +x "$MOCK_BIN/python3"

    # The default claude mock exits 1, so the narrative fails and the fallback render is reached.
    _run_brief_separated link --brief --local
    [ "$brief_status" -eq 7 ] || {
        printf 'expected exit 7, got %s\nSTDOUT:\n%s\nSTDERR:\n%s\n' \
            "$brief_status" "$brief_stdout" "$brief_stderr" >&2
        false
    }
    # THE CHANNEL, not just the text: stdout at this point IS the page, and a warning spliced into it
    # is indistinguishable from content.
    [[ "$brief_stderr" == *"Could not render the borg link document"* ]] || false
    [[ "$brief_stdout" != *"Could not render the borg link document"* ]] || false
    [[ "$brief_stderr" == *"exit 7"* ]] || false
    # The child's own stderr is the reason, the same contract the `claude -p exited N` and the
    # projection branches have.
    [[ "$brief_stderr" == *"MOCKED-RENDER-FAILURE"* ]] || false
    # And the page really is absent — this is not a warning printed alongside a rendered document.
    [[ "$brief_stdout" != *"THE BORG COLLECTIVE"* ]] || false
}
