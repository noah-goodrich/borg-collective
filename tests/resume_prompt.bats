#!/usr/bin/env bats
# Prompt renderer for borg-resume (slice S6): borg-resume prompt <rid>.
# Inputs are static fixtures under tests/fixtures/resume-prompt/ (a record per class plus one inventory JSON in
# the S5 shape). Goldens are tests/fixtures/resume-prompt/golden-<variant>.md; regenerate with UPDATE_GOLDEN=1.

setup() {
    BIN="${BATS_TEST_DIRNAME}/../bin/borg-resume"
    FX="${BATS_TEST_DIRNAME}/fixtures/resume-prompt"
    command -v jq >/dev/null || skip "jq not installed"
    export BORG_RESUME_DIR="${BATS_TEST_TMPDIR}/resume"
    export BORG_IN_CONTAINER=0
    unset BORG_RESUME_DISABLE BORG_RESUME_AUTO_COMPACT
    RID="r_7f3a2c"
    mkdir -p "$BORG_RESUME_DIR/pending"
}

# stage <class> : copy the class record into pending/
stage() { cp "$FX/record_$1.json" "$BORG_RESUME_DIR/pending/$RID.json"; }
render() { run "$BIN" prompt "$RID" --inventory "$FX/inventory.json"; }
pfile() { printf '%s/prompts/%s.md' "$BORG_RESUME_DIR" "$RID"; }

# absent <fixed-string> <file> : fails the test when the string is present (bare "! grep" is ignored by errexit)
absent() { if LC_ALL=C grep -qF -- "$1" "$2"; then echo "unexpected: $1" >&2; return 1; fi; }

golden() {
    local name="$1" g="$FX/golden-$1.md"
    if [ "${UPDATE_GOLDEN:-}" = "1" ]; then cp "$(pfile)" "$g"; fi
    run diff -u "$g" "$(pfile)"
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; return 1; }
}

@test "usage_limit variant matches golden" {
    stage usage_limit
    render
    [ "$status" -eq 0 ]
    golden usage_limit
}

@test "transient variant matches golden" {
    stage transient
    render
    [ "$status" -eq 0 ]
    golden transient
}

@test "max_output_tokens variant says smaller steps" {
    stage max_output_tokens
    render
    [ "$status" -eq 0 ]
    grep -q "smaller steps" "$(pfile)"
    golden max_output_tokens
}

@test "prompt_too_long variant, compact on by default" {
    stage prompt_too_long
    render
    [ "$status" -eq 0 ]
    golden prompt_too_long
    run "$BIN" prompt "$RID" --compact-line
    [ "$status" -eq 0 ]
    [ "$output" = "/compact" ]
}

@test "prompt_too_long with the flag off: no /compact, stop-and-tell variant" {
    stage prompt_too_long
    export BORG_RESUME_AUTO_COMPACT=0
    render
    [ "$status" -eq 0 ]
    golden prompt_too_long_nocompact
    run "$BIN" prompt "$RID" --compact-line
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

@test "compact-line is only for prompt_too_long" {
    stage usage_limit
    run "$BIN" prompt "$RID" --compact-line
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

@test "process_death variant matches golden" {
    stage process_death
    render
    [ "$status" -eq 0 ]
    grep -q "git status" "$(pfile)"
    golden process_death
}

@test "notify-only class is refused and writes nothing" {
    stage usage_limit
    sed -i.bak 's/"usage_limit"/"auth_failed"/' "$BORG_RESUME_DIR/pending/$RID.json"
    render
    [ "$status" -eq 3 ]
    [ ! -e "$(pfile)" ]
}

@test "every runId, scriptPath and Agent-tool agent_id appears" {
    stage usage_limit
    render
    [ "$status" -eq 0 ]
    local f; f="$(pfile)"
    for s in wf_ab12cd wf_cd34ef wf_inline1 /work/example/flows/build.js /work/example/flows/review.js \
        a0000000000000002 a0000000000000003; do
        grep -qF "$s" "$f" || { echo "missing $s" >&2; return 1; }
    done
}

@test "workflow-owned agents are never listed as Agents or SendMessage targets" {
    stage usage_limit
    render
    absent "wfagent" "$(pfile)"
    absent 'to: "wf' "$(pfile)"
    grep -q 'SendMessage({ to: "a0000000000000002"' "$(pfile)"
}

@test "done, running, interrupted and finished items never get a resume action" {
    stage usage_limit
    render
    local f; f="$(pfile)"
    absent "a0000000000000004" "$f"
    absent "a0000000000000005" "$f"
    absent "a0000000000000006" "$f"
    absent "wf_usr001" "$f"
    absent "wf_fin001" "$f"
    absent "wfagent0000000009" "$f"
    absent "User skipped" "$f"
}

@test "finished_with_failures carries the U8 fallback" {
    stage usage_limit
    render
    grep -q 'resumeFromRunId: "wf_cd34ef"' "$(pfile)"
    grep -qi "new run with the same args" "$(pfile)"
}

@test "inline-only workflow tells the model to write the script out first" {
    stage usage_limit
    render
    grep -q "wf_inline1" "$(pfile)"
    grep -qi "write the manifest" "$(pfile)"
}

@test "injected line is one clean line with only the rid and a fixed sentence" {
    stage usage_limit
    run "$BIN" prompt "$RID" --inventory "$FX/inventory.json" --line
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" = "1" ]
    case "$output" in "[borg-resume r_7f3a2c] "*) ;; *) return 1 ;; esac
    printf '%s' "$output" | LC_ALL=C grep -q '[[:cntrl:]]' && return 1
    case "$output" in *'`'* | *'$('* | *Refactor* | *contributor*) return 1 ;; esac
    case "$output" in *"prompts/r_7f3a2c.md"*"borg-resume ack r_7f3a2c") ;; *) return 1 ;; esac
}

@test "line builder rejects a hostile rid" {
    run "$BIN" prompt 'r_1; rm -rf x' --line
    [ "$status" -ne 0 ]
    run "$BIN" prompt $'r_1\nboom' --line
    [ "$status" -ne 0 ]
}

@test "line wording follows the class" {
    stage transient
    run "$BIN" prompt "$RID" --line
    [[ "$output" == *"API error"* ]]
    stage max_output_tokens
    run "$BIN" prompt "$RID" --line
    [[ "$output" == *"output token"* ]]
}

@test "hostile transcript text appears only inside fences and has no control chars" {
    stage usage_limit
    render
    local f; f="$(pfile)"
    absent "$(printf '\033')" "$f"
    run awk '
        /^ *`{3,}/ { fence = !fence; next }
        !fence && (/`/ || /\$\(/) { print NR ": " $0; bad = 1 }
        END { exit bad }' "$f"
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; return 1; }
    grep -q 'touch /tmp/pwn' "$f"
}

@test "fence is longer than any backtick run in the quoted text" {
    stage usage_limit
    render
    grep -q '^ *````' "$(pfile)"
}

@test "rendered lines stay under 100 columns" {
    stage usage_limit
    render
    run awk 'length($0) >= 100 { print NR ": " length($0); bad = 1 } END { exit bad }' "$(pfile)"
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; return 1; }
}

@test "rendering is deterministic" {
    stage usage_limit
    render
    cp "$(pfile)" "$BATS_TEST_TMPDIR/a.md"
    render
    run cmp "$BATS_TEST_TMPDIR/a.md" "$(pfile)"
    [ "$status" -eq 0 ]
}

@test "attempt counter reflects the record" {
    stage usage_limit
    sed -i.bak 's/"attempt": 0/"attempt": 2/' "$BORG_RESUME_DIR/pending/$RID.json"
    render
    grep -q "attempt 3 of 3" "$(pfile)"
}

@test "unknown rid and bad usage fail cleanly" {
    run "$BIN" prompt r_nope00 --inventory "$FX/inventory.json"
    [ "$status" -ne 0 ]
    run "$BIN" prompt
    [ "$status" -eq 2 ]
}

@test "without --inventory an unknown session (found:false) fails and writes nothing" {
    export BORG_RESUME_PROJECTS_DIR="${BATS_TEST_TMPDIR}/projects"
    mkdir -p "$BORG_RESUME_PROJECTS_DIR"
    stage usage_limit
    run "$BIN" prompt "$RID"
    [ "$status" -eq 1 ]
    [ ! -e "$(pfile)" ]
}

@test "empty or found:false inventory fails, nothing written" {
    stage usage_limit
    : >"$BATS_TEST_TMPDIR/empty.json"
    run "$BIN" prompt "$RID" --inventory "$BATS_TEST_TMPDIR/empty.json"
    [ "$status" -eq 1 ]
    printf '{"found":false,"session":null,"agents":[],"workflows":[]}\n' >"$BATS_TEST_TMPDIR/nf.json"
    run "$BIN" prompt "$RID" --inventory "$BATS_TEST_TMPDIR/nf.json"
    [ "$status" -eq 1 ]
    [ ! -e "$(pfile)" ]
}

@test "interrupted_by_user session is notify-only" {
    stage usage_limit
    jq '.session.turn_state = "interrupted_by_user"' "$FX/inventory.json" >"$BATS_TEST_TMPDIR/inv.json"
    run "$BIN" prompt "$RID" --inventory "$BATS_TEST_TMPDIR/inv.json"
    [ "$status" -eq 3 ]
    [ ! -e "$(pfile)" ]
}

@test "terminal record states and done/ records are notify-only" {
    stage usage_limit
    jq '.state = "superseded"' "$BORG_RESUME_DIR/pending/$RID.json" >"$BATS_TEST_TMPDIR/r.json"
    cp "$BATS_TEST_TMPDIR/r.json" "$BORG_RESUME_DIR/pending/$RID.json"
    render
    [ "$status" -eq 3 ]
    rm -f "$BORG_RESUME_DIR/pending/$RID.json"
    mkdir -p "$BORG_RESUME_DIR/done"
    cp "$FX/record_usage_limit.json" "$BORG_RESUME_DIR/done/$RID.json"
    render
    [ "$status" -ne 0 ]
    [ ! -e "$(pfile)" ]
}

@test "main-task continue line only for scope main" {
    stage usage_limit
    render
    grep -q "Main task: continue" "$(pfile)"
    jq '.scope = "agent"' "$FX/record_usage_limit.json" >"$BORG_RESUME_DIR/pending/$RID.json"
    render
    [ "$status" -eq 0 ]
    absent "Main task: continue" "$(pfile)"
}

@test "withheld script path is not rendered as a Workflow call" {
    stage usage_limit
    jq '.workflows[0].script_path = "/work/ex (1)/#a,b.js"' "$FX/inventory.json" >"$BATS_TEST_TMPDIR/inv.json"
    run "$BIN" prompt "$RID" --inventory "$BATS_TEST_TMPDIR/inv.json"
    [ "$status" -eq 0 ]
    absent 'scriptPath: "<' "$(pfile)"
    grep -q "script path unsafe" "$(pfile)"
}

@test "trailing-newline id is rejected" {
    stage usage_limit
    jq '.workflows[0].run_id = "wf_ab12cd\n"' "$FX/inventory.json" >"$BATS_TEST_TMPDIR/inv.json"
    run "$BIN" prompt "$RID" --inventory "$BATS_TEST_TMPDIR/inv.json"
    [ "$status" -eq 0 ]
    grep -q "<invalid-id>" "$(pfile)"
}

@test "record rid mismatch is an error" {
    stage usage_limit
    sed -i.bak 's/"r_7f3a2c"/"r_other"/' "$BORG_RESUME_DIR/pending/$RID.json"
    render
    [ "$status" -eq 1 ]
}

@test "flag-off line does not claim compaction" {
    stage prompt_too_long
    export BORG_RESUME_AUTO_COMPACT=0
    run "$BIN" prompt "$RID" --line
    [ "$status" -eq 0 ]
    absent "has been compacted" <(printf '%s' "$output") 2>/dev/null || true
    case "$output" in *"has been compacted"*) return 1 ;; esac
}

@test "spike ids are not shown and U8 fallback only with finished_with_failures" {
    stage usage_limit
    render
    absent "U8" "$(pfile)"
    jq '.workflows |= map(select(.status != "finished_with_failures"))' "$FX/inventory.json" >"$BATS_TEST_TMPDIR/inv.json"
    run "$BIN" prompt "$RID" --inventory "$BATS_TEST_TMPDIR/inv.json"
    absent "new run with the same args" "$(pfile)"
}
