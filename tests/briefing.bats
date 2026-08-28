#!/usr/bin/env bats
# Tests for _borg_print_briefing via the `borg link --brief` subcommand.
#
# WHAT CHANGED HERE ON 2026-08-27, AND WHY NOTHING WAS SILENTLY DELETED. `--brief` no longer walks
# the registry: it builds the ONE `borg link` document, projects it into the narrative prompt, and
# renders THAT SAME DOCUMENT when the narrative is unavailable (docs/plans/directives/
# 2026-08-27-fold-brief-into-the-document.md). Of the 12 cases here, eight are untouched, three are
# consciously rewritten and one keeps its assertion with new provenance:
#   - "inactive projects appear under inactive header" — REWRITTEN. The "Inactive (>30 days):" block
#     and the 30-day active/inactive split were `_borg_print_briefing`'s own; they have no
#     counterpart in `render.SECTIONS` and are deliberately retired. The case now asserts the same
#     underlying claim — a long-dormant project is still ON the page, with its relative time — which
#     is the property the header existed to serve.
#   - "no debug variable lines in output" — REWRITTEN. It named locals (`proj_status=`, `rel_time='`)
#     that no longer exist, so it would have gone vacuously green. Re-pointed at the locals the
#     rewritten function actually has, and the `setopt LOCAL_OPTIONS; set +x` it guards is still
#     there.
#   - "empty summary + set waiting_reason never displays waiting_reason as the summary" — REWRITTEN.
#     The \x1f field-shift defect it guarded is gone with the `read` loop (JSON cannot field-shift),
#     but the SEMANTIC claim still has teeth: `waiting_reason` is on the wire and the board row must
#     never print it as a summary. Re-pointed at the document.
#   - "empty registry shows scan hint" — SAME ASSERTION, NEW ORIGIN. The hint now comes from the
#     document's own `total_projects == 0` short circuit rather than a registry read.
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

# REWRITTEN 2026-08-27. The `setopt LOCAL_OPTIONS; set +x` at the top of _borg_print_briefing is
# still the subject; only the names changed. The old case named `proj_status=` / `rel_time='` /
# `last_activity=`, which the fold deleted along with the per-project `read` loop — leaving a case
# that could never fail again. These are the locals the rewritten function actually assigns, plus
# the array it builds the Python argv in.
@test "briefing: no debug variable lines in output" {
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    # Should not contain shell variable assignment traces
    [[ "$output" != *"entry='"* ]] || false
    [[ "$output" != *"doc="* ]] || false
    [[ "$output" != *"payload="* ]] || false
    [[ "$output" != *"total="* ]] || false
    [[ "$output" != *"_brief_py_args="* ]] || false
    [[ "$output" != *"briefing_prompt="* ]] || false
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
# active and no inactive names; it now comes from the DOCUMENT's own `total_projects == 0`, which is
# why the short circuit survived the fold at all: it is the one case where there is nothing for a
# narrative to say and paying `claude -p` to say it is waste.

@test "briefing: empty registry shows scan hint" {
    echo '{"projects":{}}' > "$BORG_REGISTRY"
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    [[ "$output" == *"borg scan"* ]] || false
}
