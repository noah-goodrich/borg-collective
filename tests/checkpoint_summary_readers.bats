#!/usr/bin/env bats
# Every reader of a repository's one-line summary takes the NEWEST CHECKPOINT's tl;dr, never the registry's stored
# `summary`. The stored value is summarize.py's transcript heuristic, written once at session end, so it goes stale
# the moment a newer checkpoint lands; `borg link` moved off it first, and these cases pin the other readers:
# `borg next` (and nextpick, which is fed the same overlay), the switch brief (`next --switch`, `_borg_do_switch`),
# the switch picker's column (`cmd_ls --porcelain`), and the Queen's prompts (`borg link --brief`, and the
# orchestrator context `borg init` builds).
#
# THE FIXTURES DO NOT SUPPLY THE ANSWER. Each repository's registry row carries a stale sentence and its directory
# carries real checkpoint files with different tl;dr lines; the code under test has to derive which one wins. The
# older checkpoint is lexically earlier, so a reader that took the first file or the stored field is red.
# One implementation: `borg_core.link.shell.with_checkpoint_summaries`, one Python call for all repositories.

load test_helper/setup

BORG="${BATS_TEST_DIRNAME}/../borg.zsh"

STALE="Stale registry sentence from a long gone session."
OLDER="Older checkpoint line that a newer one supersedes."
FRESH="Fresh checkpoint line from the newest file."

setup() {
    setup_temp_dirs
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    export TRACE="${BATS_TEST_TMPDIR}/trace.log"
    : > "$TRACE"
    export TMUX_MOCK_HAS_SESSION=1
    export TMUX_MOCK_WINDOWS="w-alpha w-beta"
    unset BORG_WORK_PROJECTS
    export BORG_ORCHESTRATOR_ROOT="${BATS_TEST_TMPDIR}/queen"
    mkdir -p "$BORG_ORCHESTRATOR_ROOT"
    cd "$BORG_ORCHESTRATOR_ROOT"

    cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
echo "tmux $*" >> "$TRACE"
case "$1" in
    has-session) [ "${TMUX_MOCK_HAS_SESSION:-0}" = "1" ] && exit 0 || exit 1 ;;
    list-windows) printf '%s\n' $TMUX_MOCK_WINDOWS ;;
    list-panes) echo "0 %1" ;;
    display-message) echo "${TMUX_MOCK_CURRENT:-mock-window}" ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "$MOCK_BIN/tmux"
}

# A directory with two checkpoints: an older one and a newer one, whose tl;dr lines differ.
_checkpointed_dir() {
    local dir="${BATS_TEST_TMPDIR}/ws/$1"
    mkdir -p "$dir/.borg/checkpoints"
    printf '**tl;dr** -- %s\n\n## Accomplished\n\n- Older bullet.\n' "$OLDER" > "$dir/.borg/checkpoints/2026-10-01-0900.md"
    printf '**tl;dr** -- %s\n\n## Accomplished\n\n- Newer bullet.\n' "$FRESH" > "$dir/.borg/checkpoints/2026-10-02-0900.md"
    printf '%s' "$dir"
}

# alpha has checkpoints; beta has a stale registry summary and no checkpoint at all.
_write_registry() {
    local alpha beta
    alpha=$(_checkpointed_dir alpha)
    beta="${BATS_TEST_TMPDIR}/ws/beta"
    mkdir -p "$beta"
    cat > "$BORG_REGISTRY" <<JSON
{"projects": {
  "alpha": {"path":"$alpha","status":"waiting","source":"cli","tmux_window":"w-alpha",
            "last_activity":"2026-10-05T10:00:00Z","summary":"$STALE","waiting_reason":"needs a reply"},
  "beta":  {"path":"$beta","status":"idle","source":"cli","tmux_window":"w-beta",
            "last_activity":"2026-10-04T10:00:00Z","summary":"$STALE"}
}}
JSON
}

_count_overlay_calls() {
    grep -c "py -m borg_core.link.overlay" "$TRACE" || true
}

_trace_python() {
    local real
    real=$(command -v python3)
    printf '#!/usr/bin/env bash\necho "py $*" >> "$TRACE"\nexec "%s" "$@"\n' "$real" > "$MOCK_BIN/python3"
    chmod +x "$MOCK_BIN/python3"
}

# ── borg next ─────────────────────────────────────────────────────────────────

@test "next: prints the newest checkpoint's tl;dr, not the registry summary or an older checkpoint" {
    _write_registry
    run bash -c "zsh \"$BORG\" next 2>/dev/null"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Next up: alpha"* ]] || false
    [[ "$output" == *"$FRESH"* ]] || false
    [[ "$output" != *"$STALE"* ]] || false
    [[ "$output" != *"$OLDER"* ]] || false
}

@test "next: a repository with no checkpoint prints no summary, only waiting_reason and its relative time" {
    _write_registry
    jq '.projects.alpha.path = .projects.beta.path' "$BORG_REGISTRY" > "${BORG_REGISTRY}.new"
    mv "${BORG_REGISTRY}.new" "$BORG_REGISTRY"
    run bash -c "zsh \"$BORG\" next 2>/dev/null"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Next up: alpha"* ]] || false
    [[ "$output" == *"needs a reply"* ]] || false
    [[ "$output" == *"d ago"* ]] || false
    [[ "$output" != *"$STALE"* ]] || false
    [[ "$output" != *"$FRESH"* ]] || false
}

@test "next: all repositories are derived by ONE overlay call, none by a second reader" {
    _write_registry
    _trace_python
    run bash -c "zsh \"$BORG\" next 2>/dev/null"
    [ "$status" -eq 0 ]
    [ "$(_count_overlay_calls)" = "1" ]
}

@test "next --rows --json: the rows come from the same overlay, so nextpick ranks the derived registry" {
    _write_registry
    _trace_python
    run bash -c "zsh \"$BORG\" next --rows --json --local 2>/dev/null"
    [ "$status" -eq 0 ]
    printf '%s' "$output" | jq -e '.rows | length >= 0'
    [ "$(_count_overlay_calls)" = "1" ]
    [[ "$output" != *"$STALE"* ]] || false
}

# ── The switch brief (next --switch -> _borg_do_switch) ───────────────────────

@test "next --switch: the tmux brief carries the checkpoint tl;dr, not the registry summary" {
    _write_registry
    run bash -c "zsh \"$BORG\" next --switch 2>/dev/null"
    [ "$status" -eq 0 ]
    run grep "tmux display-message alpha |" "$TRACE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"${FRESH:0:40}"* ]] || false
    [[ "$output" != *"Stale registry"* ]] || false
}

@test "next --switch: with no checkpoint the brief is waiting_reason, never the registry summary" {
    _write_registry
    jq '.projects.alpha.path = .projects.beta.path' "$BORG_REGISTRY" > "${BORG_REGISTRY}.new"
    mv "${BORG_REGISTRY}.new" "$BORG_REGISTRY"
    run bash -c "zsh \"$BORG\" next --switch 2>/dev/null"
    [ "$status" -eq 0 ]
    run grep "tmux display-message alpha |" "$TRACE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"needs a reply"* ]] || false
    [[ "$output" != *"Stale registry"* ]] || false
}

@test "next --switch: costs one overlay call, the brief does not derive a second time" {
    _write_registry
    _trace_python
    run bash -c "zsh \"$BORG\" next --switch 2>/dev/null"
    [ "$status" -eq 0 ]
    [ "$(_count_overlay_calls)" = "1" ]
}

@test "_borg_do_switch (picker path, no summary handed in): interactive brief prints the checkpoint tl;dr" {
    _write_registry
    run bash -c "zsh -c \"set -- help; source '$BORG' >/dev/null 2>&1; _borg_do_switch alpha\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"$FRESH"* ]] || false
    [[ "$output" != *"$STALE"* ]] || false
}

@test "_borg_do_switch: deriving its own summary is exactly one overlay call" {
    _write_registry
    _trace_python
    run bash -c "zsh -c \"set -- help; source '$BORG' >/dev/null 2>&1; _borg_do_switch alpha\" 2>&1"
    [ "$status" -eq 0 ]
    [ "$(_count_overlay_calls)" = "1" ]
}

@test "_borg_do_switch: the no-window fallback status page shows the tl;dr and costs no second call" {
    _write_registry
    jq 'del(.projects.alpha.tmux_window)' "$BORG_REGISTRY" > "${BORG_REGISTRY}.new"
    mv "${BORG_REGISTRY}.new" "$BORG_REGISTRY"
    export TMUX_MOCK_WINDOWS="w-beta"
    _trace_python
    run bash -c "zsh -c \"set -- help; source '$BORG' >/dev/null 2>&1; _borg_do_switch alpha\" 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"$FRESH"* ]] || false
    [[ "$output" != *"$STALE"* ]] || false
    [ "$(_count_overlay_calls)" = "1" ]
}

# ── The switch picker (cmd_ls --porcelain, column 5) ──────────────────────────

@test "picker: column 5 is the checkpoint tl;dr, then waiting_reason, then relative time; never the stored summary" {
    _write_registry
    jq '.projects.beta.waiting_reason = null' "$BORG_REGISTRY" > "${BORG_REGISTRY}.new"
    mv "${BORG_REGISTRY}.new" "$BORG_REGISTRY"
    _trace_python
    run bash -c "zsh -c \"set -- help; source '$BORG' >/dev/null 2>&1; cmd_ls --porcelain\" 2>/dev/null"
    [ "$status" -eq 0 ]
    local alpha_col beta_col
    alpha_col=$(printf '%s\n' "$output" | awk -F'\t' '$1 == "alpha" { print $5 }')
    beta_col=$(printf '%s\n' "$output" | awk -F'\t' '$1 == "beta" { print $5 }')
    [ "$alpha_col" = "$FRESH" ]
    [[ "$beta_col" == *"d ago" ]] || false
    [[ "$output" != *"$STALE"* ]] || false
    [ "$(_count_overlay_calls)" = "1" ]
}

# ── The Queen's prompts ───────────────────────────────────────────────────────

@test "briefing: the --brief prompt carries the NEWEST checkpoint's tl;dr, not an older one or the registry's" {
    export PROMPT_FILE="${BATS_TEST_TMPDIR}/prompt.txt"
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "-p" ] && printf '%s' "$2" > "$PROMPT_FILE"
echo "NARRATIVE"
EOF
    chmod +x "$MOCK_BIN/claude"
    _write_registry
    run "$BORG" link --brief --local
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; false; }
    run cat "$PROMPT_FILE"
    [[ "$output" == *"$FRESH"* ]] || false
    [[ "$output" != *"$STALE"* ]] || false
    [[ "$output" != *"$OLDER"* ]] || false
}

@test "briefing: a repository with no checkpoint reaches the --brief prompt with the no-summary note" {
    export PROMPT_FILE="${BATS_TEST_TMPDIR}/prompt.txt"
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "-p" ] && printf '%s' "$2" > "$PROMPT_FILE"
echo "NARRATIVE"
EOF
    chmod +x "$MOCK_BIN/claude"
    _write_registry
    run "$BORG" link --brief --local
    [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; false; }
    run cat "$PROMPT_FILE"
    [[ "$output" == *"note: no summary on record"* ]] || false
    [[ "$output" != *"$STALE"* ]] || false
}

@test "orchestrator context (borg init's prompt): checkpoint tl;dr for alpha, no stored summary for either" {
    _write_registry
    _trace_python
    run bash -c "zsh -c \"set -- help; source '$BORG' >/dev/null 2>&1; _borg_orchestrator_context\" 2>/dev/null"
    [ "$status" -eq 0 ]
    local registry_lines
    registry_lines=$(printf '%s\n' "$output" | grep -E '^  (alpha|beta) \[')
    [[ "$registry_lines" == *"alpha [waiting]"*"$FRESH"* ]] || false
    [[ "$registry_lines" == *"beta [idle]"*"(no summary)"* ]] || false
    [[ "$output" != *"$STALE"* ]] || false
    [[ "$output" != *"$OLDER"* ]] || false
    [ "$(_count_overlay_calls)" = "1" ]
}

@test "a failing overlay call blanks the summaries instead of falling back to the stored ones" {
    _write_registry
    printf '#!/usr/bin/env bash\nexit 1\n' > "$MOCK_BIN/python3"
    chmod +x "$MOCK_BIN/python3"
    run bash -c "zsh -c \"set -- help; source '$BORG' >/dev/null 2>&1; borg_registry_with_state | _borg_checkpoint_summaries\" 2>/dev/null"
    [ "$status" -eq 0 ]
    [[ "$output" != *"$STALE"* ]] || false
    printf '%s' "$output" | jq -e '.projects.alpha.summary == null and .projects.beta.summary == null'
}
