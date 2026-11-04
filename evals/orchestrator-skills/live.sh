#!/usr/bin/env bash
# LIVE run of the orchestrator-skills cases: drives headless `claude -p` through real sandbox repositories, reduces each
# run to a trace and grades it with check.py. A developer command that spends money, so it is not under run.sh, not in
# any Makefile target and not in CI: `make eval` stays offline and replays what this script recorded.
#
#   usage: evals/orchestrator-skills/live.sh [--case NAME[,NAME...]] [--list] [--dry-run] [--record] [--keep]
#
#   --case NAME   which cases to run. NAME is a case id (RS1, RV2, BG3 ...) or a GROUP that runs one skill's cases
#                 together: resume (RS1-RS4), review (RV1, RV2, RV4; RV3 is graded on RV1's run), break-glass (BG1-BG3).
#                 Step 3b adds: switch (SW1-SW3), pane (PN1-PN3), collective-review (CR1, CR2), adhd (AD1, AD3, AD2 in that order so each negative follows its positive; AD4 is graded
#                 on AD2's run, as RV3 is on RV1's). ADP is the adhd-guardrails FIRING PROBE: not a graded case, never in
#                 a group or in the default selection, runs only when named.
#                 Repeatable and comma-separated; EVAL_CASES="RS1 review" does the same. Default: all graded cases.
#   --list        print the case ids and their groups, run nothing
#   --dry-run     print the claude argv each selected case would run, spend nothing (offline; run.sh uses it)
#   --record      write the sanitized graded runs (pass or fail; a skip is not evidence)  to evals/orchestrator-skills/recorded/ (what run.sh replays offline)
#   --record-only record the selected cases from the run directory a previous invocation left, spending nothing
#   --keep        keep the run directory (it is kept anyway: the stream is the only way to diagnose a failed case)
#
# Environment:
#   EVAL_MODEL             default claude-opus-5-5. This eval grades ORCHESTRATOR-session skills, so it runs on the pinned
#                          Opus at the lifecycle harness's effort, as an orchestrator session would. A full id, never an
#                          alias, so a moving alias cannot change what is measured.
#   EVAL_EFFORT            default xhigh
#   EVAL_MAX_BUDGET_USD    per-case cap passed as --max-budget-usd (default 1.00; the step 3b cases default lower, see _case_cap,
#                          and an explicit value here overrides every case)
#   EVAL_TOTAL_BUDGET_USD  stop before a case whose cap could take the invocation's recorded spend past this (default: none)
#   EVAL_PLUGIN_DIR        a built plugin directory; default: this checkout, built to <run dir>/plugin
#   EVAL_OUT               the run directory (default <repo>/evals/orchestrator-skills/out)
#   BORG_EVAL_HISTORY      the run-history file (borg_core/evals/history.py)
#
# WHAT IS GRADED, AND WHAT IS NOT. Every case is a Tier 2 SCRIPT grader over the reduced trace and the sandbox files. No
# case grades whether an answer is GOOD. borg-review in particular is graded for SHAPE (the diagnostic block, M equal to
# the plan's criteria count, exactly one recommendation, a gates ledger in order before the first edit), not for the
# quality of its diagnosis: AC3 allows `llm` graders only for the ledger's judge items and borg-review is not one
# (Noah, 2026-11-02). A shape-correct but wrong diagnosis passes.
#
# ISOLATION. Every case runs in its own sandbox (repo, HOME, state dir) under the run directory, with a PATH that is an
# allowlist. borg-resume reads a ledger seeded under the sandbox state dir, never the real resume ledger. break-glass
# writes only the sandbox repository's .claude/settings.local.json, and a case hashes the sandbox HOME's settings.json
# before and after. The sandbox HOME links ONE real directory, ~/Library, because claude finds its keychain credentials
# through it: a HOME without it is "Not logged in" (measured 2026-11-03). ~/.claude, ~/.config and ~/.local are the
# sandbox's own, so no real settings, hooks, extensions or CLAUDE.md reach the session.
#
# A claude -p session ends when the command returns, so a CronCreate made by RS2 dies with it; nothing persists.
#
# TWO GRANTS A HEADLESS RUN NEEDS, both measured 2026-11-03 on claude 2.1.300 and both scoped to one sandbox path:
#   * break-glass writes .claude/settings.local.json, a protected path: acceptEdits refuses it and an allow rule for it
#     (relative or absolute) does not lift that. allow-write.sh, registered as a PermissionRequest hook through
#     --settings for the BG cases only, allows exactly the sandbox repository's file. It is on for BG2 and BG3 as well,
#     so their "the file did not change" cannot be a refused write.
#   * borg-review reads references/gates.md from the plugin build, outside the sandbox repository, and a headless Read
#     there is refused; the RV cases get --add-dir <plugin build>.
#
# THE SPIKES this design rested on (each one cheap call, 2026-11-03): CronCreate is callable in -p (a deferred tool: the
# model loads it with ToolSearch first) and its input is in the stream; a disable-model-invocation skill runs when
# slash-invoked in -p; `borg-resume status` on a seeded ledger needs no network and no model. The settings.local.json
# write was NOT possible without the hook above.
#
# KNOWN LIVE FAILURES, recorded and replayed offline (recorded/live-verdicts.json): on claude-opus-5-5 at xhigh, RV2 and
# RV4 failed twice each. The skill reads references/gates.md and does the gates' work, but never emits the five-line
# ledger (RV2) or the `Gates: trivial` line (RV4). They are findings about the skill, not about this harness.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${BORG_EVAL_REPO:-$(cd "$HERE/../.." && pwd)}"
REAL_HOME="${BORG_EVAL_REAL_HOME:-$HOME}"
export BORG_EVAL_REAL_HOME="$REAL_HOME"

# shellcheck source=/dev/null
source "$HERE/fixtures.sh"

EVAL_MODEL="${EVAL_MODEL:-claude-opus-5-5}"
EVAL_EFFORT="${EVAL_EFFORT:-xhigh}"
CAP_EXPLICIT="${EVAL_MAX_BUDGET_USD:+1}"
EVAL_MAX_BUDGET_USD="${EVAL_MAX_BUDGET_USD:-1.00}"
OUT="${EVAL_OUT:-$REPO/evals/orchestrator-skills/out}"
PYTHON="$(_os_python "$REPO")"

ALL_CASES="RS1 RS2 RS3 RS4 RV1 RV2 RV4 BG1 BG2 BG3 SW1 SW2 SW3 PN1 PN2 PN3 CR1 CR2 AD1 AD3 AD2"
SELECT="${EVAL_CASES:-}"
LIST=0; DRY=0; RECORD=0; RECORD_ONLY=0
while [ $# -gt 0 ]; do
    case "$1" in
        --case) SELECT="$SELECT $(printf '%s' "$2" | tr ',' ' ')"; shift ;;
        --list) LIST=1 ;;
        --dry-run) DRY=1 ;;
        --record) RECORD=1 ;;
        --record-only) RECORD=1; RECORD_ONLY=1 ;;
        --keep) ;;
        -h|--help) sed -n '2,38p' "$0"; exit 0 ;;
        *) echo "unknown flag: $1" >&2; exit 2 ;;
    esac
    shift
done

_group_of() {
    case "$1" in
        RS*) echo resume ;;
        RV*) echo review ;;
        BG*) echo break-glass ;;
        SW*) echo switch ;;
        PN*) echo pane ;;
        CR*) echo collective-review ;;
        ADP) echo adhd-probe ;;
        AD*) echo adhd ;;
    esac
}

# The per-case cap passed as --max-budget-usd. The original cases keep EVAL_MAX_BUDGET_USD (default 1.00). The step 3b
# ceilings are lower because the runs are small (the stub cases are one command); an explicit EVAL_MAX_BUDGET_USD wins.
_case_cap() {
    [ -n "$CAP_EXPLICIT" ] && { echo "$EVAL_MAX_BUDGET_USD"; return; }
    case "$(_group_of "$1")" in
        switch|pane) echo 0.40 ;;
        adhd|adhd-probe) echo 0.50 ;;
        collective-review) echo 0.75 ;;
        *) echo "$EVAL_MAX_BUDGET_USD" ;;
    esac
}

# Expand the selection: groups to their cases, RV3 to RV1 (it has no run of its own), an unknown name is refused.
_selected() {
    local tok c out=""
    [ -z "${SELECT// /}" ] && SELECT="$ALL_CASES"
    for tok in $SELECT; do
        case "$tok" in
            resume) out="$out RS1 RS2 RS3 RS4" ;;
            review) out="$out RV1 RV2 RV4" ;;
            break-glass|bg) out="$out BG1 BG2 BG3" ;;
            switch) out="$out SW1 SW2 SW3" ;;
            pane) out="$out PN1 PN2 PN3" ;;
            collective-review|cr) out="$out CR1 CR2" ;;
            adhd) out="$out AD1 AD2 AD3" ;;
            RV3) out="$out RV1" ;;
            AD4) out="$out AD2" ;;
            ADP) out="$out ADP" ;;
            *) case " $ALL_CASES " in *" $tok "*) out="$out $tok" ;; *) echo "unknown case: $tok" >&2; return 2 ;; esac ;;
        esac
    done
    for c in $ALL_CASES ADP; do
        case " $out " in *" $c "*) printf '%s ' "$c" ;; esac
    done
    echo
}

if [ "$LIST" -eq 1 ]; then
    for c in $ALL_CASES; do echo "$c $(_group_of "$c")"; done
    echo "RV3 review (graded on RV1's run)"
    echo "AD4 adhd (graded on AD2's run)"
    echo "ADP adhd-probe (a firing measurement, not a graded case)"
    exit 0
fi

CASES="$(_selected)" || exit 2

# ── per-case definitions ─────────────────────────────────────────────────────────────────────────────────────────
# borg-resume is on the PATH for every resume case except RS2, which hides it: that is the skill's own definition of an
# unavailable watcher.
_with_resume() {
    case "$1" in
        RS2) echo 0 ;;
        RS*) echo 1 ;;
        *) echo 0 ;;
    esac
}

_allowed_tools() {
    case "$(_group_of "$1")" in
        resume) echo 'Bash(borg-resume:*) Bash(TZ=*) Bash(date:*) Bash(uname:*) Bash(launchctl:*) Bash(command:*) Bash(ls:*) Bash(cat:*) Bash(test:*) Bash(echo:*) CronCreate' ;;
        review) echo 'Bash(git:*) Bash(ls:*) Bash(cat:*) Bash(python3:*) Bash(bash:*) Bash(head:*) Bash(grep:*) Bash(wc:*) Bash(test:*)' ;;
        break-glass) echo 'Bash(git:*) Bash(ls:*) Bash(cat:*) Bash(test:*) Bash(command:*)' ;;
        switch) echo 'Bash(borg:*) Bash(command:*) Bash(echo:*)' ;;
        pane) echo 'Bash(drone:*) Bash(command:*) Bash(echo:*)' ;;
        collective-review) echo 'Bash(git:*) Bash(ls:*) Bash(cat:*) Bash(grep:*) Bash(head:*) Bash(wc:*) Bash(test:*)' ;;
        adhd|adhd-probe) echo 'Read Edit Write Bash(git:*) Bash(ls:*) Bash(cat:*) Bash(python3:*) Bash(grep:*) Bash(head:*) Bash(wc:*) Bash(test:*)' ;;
    esac
}

# Build the sandbox for one case. Args: <case> <sandbox>. Prints nothing.
_prepare() {
    local c="$1" sb="$2"
    mkdir -p "$sb/state"
    _os_home "$sb/home"
    case "$c" in
        RS1) _os_repo_resume "$sb/repo"; _os_seed_resume "$sb/state" active ;;
        RS2) _os_repo_resume "$sb/repo" ;;
        RS3) _os_repo_resume "$sb/repo"; _os_seed_resume "$sb/state" terminal ;;
        RS4) _os_repo_resume "$sb/repo"; _os_seed_resume "$sb/state" paused ;;
        RV1) _os_repo_review "$sb/repo" ;;
        RV2) _os_repo_gates "$sb/repo" ;;
        RV4) _os_repo_trivial "$sb/repo" ;;
        BG1|BG2|BG3) _os_repo_breakglass "$sb/repo" ;;
        SW*|PN*) mkdir -p "$sb/repo" ;;
        CR1) _os_repo_schema "$sb/repo" ;;
        CR2) _os_repo_typo "$sb/repo" ;;
        AD*) _os_repo_plan "$sb/repo"
             _os_adhd_context "$REPO/skills/adhd-guardrails/SKILL.md" "$sb/adhd-context.md" "$([ "$c" = AD3 ] && echo 1 || echo 0)" ;;
    esac
}

_prompt() {
    case "$1" in
        RS1|RS2|RS3|RS4) _os_prompt_resume "$2" ;;
        RV1) _os_prompt_review ;;
        RV2) _os_prompt_gates ;;
        RV4) _os_prompt_trivial ;;
        BG1) _os_prompt_bg1 ;;
        BG2) _os_prompt_bg2 ;;
        BG3) _os_prompt_bg3 ;;
        SW1) _os_prompt_sw1 ;;
        SW2) _os_prompt_sw2 ;;
        SW3) _os_prompt_sw3 ;;
        PN1) _os_prompt_pn1 ;;
        PN2) _os_prompt_pn2 ;;
        PN3) _os_prompt_pn3 ;;
        CR1|CR2) _os_prompt_cr ;;
        AD1|ADP) _os_prompt_ad1 ;;
        AD2|AD3) _os_prompt_ad2 ;;
    esac
}

# The expectations the grader compares against, derived from the fixtures and the seeded ledger. Args: <case> <sandbox>
_expect() {
    local c="$1" sb="$2" base
    base="$(jq -nc --arg run "$_OS_WF_RUN" --arg script "$sb/repo/$_OS_WF_SCRIPT_REL" '{runId:$run, scriptPath:$script}')"
    case "$c" in
        RS1|RS3) jq -c --argjson b "$base" '. + $b' "$sb/state/expect.json" ;;
        RS2|RS4) printf '%s\n' "$base" ;;
        RV1) jq -nc --arg stray "$_OS_STRAY_FILE" '{criteria:3, stray:$stray}' ;;
        BG1) jq -nc '{preexisting:"Bash(make test:*)", tool:"alembic"}' ;;
        SW1) jq -nc '{name:"beacon-web"}' ;;
        SW3) jq -nc '{name:"nonesuch-repo"}' ;;
        PN1) jq -nc '{direction:"right"}' ;;
        PN3) jq -nc '{direction:"left"}' ;;
        CR1) jq -nc '{owner:"The Database Architect"}' ;;
        AD3) jq -nc --argjson n "$_OS_CAP_COUNT" --argjson l "$_OS_CAP_LIMIT" '{count:$n, limit:$l}' ;;
        *) echo '{}' ;;
    esac
}

_stub_mode() {
    case "$1" in
        SW3) echo switch-fail ;;
        PN3) echo pane-reuse-zoomed ;;
        *) echo pane-new ;;
    esac
}

# The environment variables a case's claude process gets on top of the inherited ones. Args: <case> <sandbox>
_env_args() {
    local c="$1" sb="$2"
    printf '%s\n' "HOME=$sb/home" "XDG_STATE_HOME=$sb/state/xdg" "XDG_CONFIG_HOME=$sb/home/.config" \
        "XDG_DATA_HOME=$sb/home/.local/share" "GIT_CONFIG_GLOBAL=/dev/null" "GIT_CONFIG_NOSYSTEM=1" \
        "GIT_AUTHOR_NAME=eval" "GIT_AUTHOR_EMAIL=eval@localhost" "GIT_COMMITTER_NAME=eval" \
        "GIT_COMMITTER_EMAIL=eval@localhost" "BORG_IN_CONTAINER=0"
    case "$c" in
        BG*) printf '%s\n' "EVAL_ALLOW_WRITE=$sb/repo/.claude/settings.local.json" ;;
        # BORG_NO_SESSION_HOOKS=1: the plugin's SessionStart hook runs `borg link repo --json`, which the stub logged ahead
        # of the model's own call (measured 2026-11-04, SW1's first run). The log must hold only what the skill ran.
        SW*|PN*) printf '%s\n' "EVAL_STUB_LOG=$sb/state/stub.log" "EVAL_STUB_MODE=$(_stub_mode "$c")" "BORG_NO_SESSION_HOOKS=1" ;;
        RS*) printf '%s\n' "BORG_RESUME_DIR=$sb/state/resume" "BORG_RESUME_PROJECTS_DIR=$sb/state/projects" \
                "BORG_RESUME_NOW_EPOCH=$_OS_SEED_EPOCH" ;;
    esac
}

# The break-glass cases only: a --settings document registering allow-write.sh, which grants the one protected file the
# skill's job is to write. See allow-write.sh for why an allow rule cannot. Printed empty for every other case.
_settings_json() {
    case "$1" in
        BG*) printf '{"hooks":{"PermissionRequest":[{"matcher":"Edit|Write|MultiEdit","hooks":[{"type":"command","command":"bash %s/allow-write.sh"}]}]}}' "$HERE" ;;
    esac
}

# The claude argv for one case, in the global array ARGV, so --dry-run and the real run cannot drift.
# Args: <case> <plugin-dir> <prompt>
_build_argv() {
    ARGV=(-p "$3" --model "$EVAL_MODEL" --effort "$EVAL_EFFORT" --permission-mode acceptEdits
          --allowedTools "$(_allowed_tools "$1")" --output-format stream-json --verbose
          --max-budget-usd "$(_case_cap "$1")")
    # AD1-AD3 load NO plugin: adhd-guardrails is user-invocable: false and "always active" guidance, so its body is delivered
    # through --append-system-prompt-file and the grade does not depend on the model firing it. ADP (the probe) loads the
    # plugin and appends nothing, which is the only way to see whether the Skill tool fires.
    case "$1" in
        AD1|AD2|AD3) ARGV+=(--append-system-prompt-file "${APPEND_FILE:-<append-file>}") ;;
        *) ARGV+=(--plugin-dir "$2") ;;
    esac
    case "$1" in
        BG*) ARGV+=(--settings "$(_settings_json "$1")") ;;
        # THE SKILL'S reference file lives in the plugin build, outside the sandbox repository, and a headless Read of a
        # path outside the working directory is refused (measured 2026-11-03: RV2's Read of references/gates.md came
        # back denied and the model said so). --add-dir grants that one directory, read access as any session has it.
        RV*|CR*) ARGV+=(--add-dir "$2") ;;
    esac
}

_record() {
    local c
    rm -rf "$OUT/.stage"
    mkdir -p "$OUT/.stage"
    for c in $1; do
        # A PASS is a known-good. A FAIL is recorded too, as a finding: run.sh replays it and requires the same verdict.
        if grep -qE "^CHECK (pass|fail) $c " "$OUT/$c/verdict.txt" 2>/dev/null; then
            mkdir -p "$OUT/.stage/$c"
            cp "$OUT/$c/meta.json" "$OUT/$c/stream.jsonl" "$OUT/$c/verdict.txt" "$OUT/.stage/$c/"
        else
            echo "not recording $c: it was skipped or never graded"
        fi
    done
    "$PYTHON" "$HERE/check.py" sanitize "$OUT/.stage" "$HERE/recorded" "$REPO" && echo "recorded to $HERE/recorded"
}

if [ "$RECORD_ONLY" -eq 1 ]; then
    _record "$CASES"
    exit $?
fi

if [ "$DRY" -eq 1 ]; then
    for c in $CASES; do
        prompt="$(_prompt "$c" /sandbox/repo)"
        _os_prompt_leaks "$prompt" || { echo "DRY-RUN REFUSED $c: the prompt leaks a hint" >&2; exit 2; }
        echo "CASE $c group=$(_group_of "$c") borg-resume-on-path=$(_with_resume "$c")"
        _build_argv "$c" '<plugin>' "$prompt"
        printf '  claude'; printf ' %q' "${ARGV[@]}"; echo
    done
    exit 0
fi

# ── preflight ────────────────────────────────────────────────────────────────────────────────────────────────────
_rec() {
    PYTHONPATH="$REPO" "$PYTHON" -m borg_core.evals.history --record --harness orchestrator-skills --case "$1" \
        --verdict "$2" --reason "$3" --repo "$REPO" ${4:+--result "$4"} \
        || echo "warning: could not append to the eval history" >&2
}
_abort() { echo "$1" >&2; exit 2; }

for tool in claude jq git zsh; do
    command -v "$tool" >/dev/null 2>&1 || _abort "$tool not found on PATH; the live run cannot start"
done
command -v "$PYTHON" >/dev/null 2>&1 || _abort "interpreter '$PYTHON' not found"

mkdir -p "$OUT"
PLUGIN="${EVAL_PLUGIN_DIR:-$OUT/plugin}"
if [ -z "${EVAL_PLUGIN_DIR:-}" ]; then
    rm -rf "$OUT/plugin"
    PLUGIN_DIR_OVERRIDE="$OUT/plugin" "$REPO/scripts/build-plugin.sh" > "$OUT/plugin-build.log" 2>&1 \
        || _abort "plugin build failed, see $OUT/plugin-build.log"
fi
for f in skills/borg-review/references/gates.md skills/break-glass/SKILL.md skills/borg-resume/SKILL.md; do
    [ -f "$PLUGIN/$f" ] || _abort "the plugin build lacks $f"
done
grep -q '^disable-model-invocation: true' "$PLUGIN/skills/break-glass/SKILL.md" \
    || _abort "the plugin build's break-glass is not disable-model-invocation: true"

# THE USAGE GUARDIAN. A live eval must not push a working session into its limit: stop at 85 percent.
_session_pct() {
    local f="${BORG_USAGE_SAMPLES:-$REAL_HOME/.local/state/borg/usage-samples.jsonl}"
    [ -f "$f" ] && tail -1 "$f" | jq -r '.session_pct // 0' 2>/dev/null || echo 0
}

_clean_env_unset() {
    local name
    for name in $(compgen -e | grep -E '^(CLAUDECODE|CLAUDE_CODE_|CLAUDE_AGENT_SDK)'); do printf '%s\n' "-u" "$name"; done
}

SPENT=0
RAN=""
PASSED=""
# THE PAIRING for a negative: when its positive ran in this invocation and did not pass, the negative's "nothing happened"
# is not evidence. Returns 1 only in that case. Args: <positive> <negative>
_pair() {
    case " $RAN " in
        *" $1 "*) case " $PASSED " in *" $1 "*) return 0 ;; *) return 1 ;; esac ;;
    esac
    return 0
}
_run_case() {
    local c="$1" sb="$OUT/$1" prompt pct cost verdict line envargs=() unsets=() bin stublog
    rm -rf "$sb"
    mkdir -p "$sb"
    pct="$(_session_pct)"
    if [ "${pct%.*}" -ge 85 ]; then
        echo "STOP: the usage guardian reads session_pct=$pct, not starting $c" >&2
        return 3
    fi
    if [ -n "${EVAL_TOTAL_BUDGET_USD:-}" ] \
        && awk -v s="$SPENT" -v m="$(_case_cap "$c")" -v t="$EVAL_TOTAL_BUDGET_USD" 'BEGIN{exit !(s+m>t)}'; then
        echo "STOP: $c could take the invocation past EVAL_TOTAL_BUDGET_USD=$EVAL_TOTAL_BUDGET_USD (spent $SPENT)" >&2
        return 4
    fi
    ( _prepare "$c" "$sb" ) || { echo "  SKIP  $c fixture could not be built"; _rec "$c" skip "fixture could not be built"; return 0; }
    prompt="$(_prompt "$c" "$sb/repo")"
    _os_prompt_leaks "$prompt" || { echo "  FAIL  $c prompt leaks a hint"; return 0; }
    printf '%s' "$prompt" > "$sb/prompt.txt"

    case "$(_group_of "$c")" in
        switch|pane) bin="$(_os_stub_bin "$sb/bin")"; stublog="$sb/state/stub.log"; : > "$stublog" ;;
        *) bin="$(_os_allowlist_bin "$sb/bin" "$(_with_resume "$c")")"; stublog="" ;;
    esac
    APPEND_FILE="$sb/adhd-context.md"
    while IFS= read -r line; do envargs+=("$line"); done < <(_env_args "$c" "$sb")
    while IFS= read -r line; do unsets+=("$line"); done < <(_clean_env_unset)
    _build_argv "$c" "$PLUGIN" "$prompt"

    "$PYTHON" "$HERE/check.py" snapshot "$sb/repo" "$sb/home" ${stublog:+"$stublog"} > "$sb/before.json"
    # BORG_PATH_PREFIX keeps the sandbox bin in front if a skill reaches borg.zsh, which rebuilds PATH at startup.
    ( cd "$sb/repo" && env ${unsets[@]+"${unsets[@]}"} "${envargs[@]}" PATH="$bin" BORG_ROOT="$REPO" BORG_PATH_PREFIX="$bin" \
        claude "${ARGV[@]}" > "$sb/stream.jsonl" 2> "$sb/stderr.txt" )
    "$PYTHON" "$HERE/check.py" snapshot "$sb/repo" "$sb/home" ${stublog:+"$stublog"} > "$sb/after.json"

    jq -nc --arg case "$c" --arg sandbox "$sb" --arg plugin "$PLUGIN" --argjson expect "$(_expect "$c" "$sb")" \
        --slurpfile before "$sb/before.json" --slurpfile after "$sb/after.json" \
        '{case:$case, sandbox:$sandbox, plugin:$plugin, expect:$expect, before:$before[0], after:$after[0]}' > "$sb/meta.json"
    "$PYTHON" "$HERE/check.py" reduce "$sb/stream.jsonl" "$sb/meta.json" > "$sb/trace.json" 2> "$sb/reduce.err" \
        || { echo "  FAIL  $c the stream could not be reduced (see $sb/reduce.err)"; _rec "$c" fail "" "$sb/stream.jsonl"; return 0; }
    cp "$sb/trace.json" "$sb/$c.trace.json"
    cost="$(jq -r '.result.cost // 0' "$sb/trace.json")"
    SPENT="$(awk -v a="$SPENT" -v b="$cost" 'BEGIN{printf "%.4f", a+b}')"
    echo "   $c: \$$cost · $(jq -r '"\(.result.turns // "?") turns · \((.result.models // []) | join(",")) · \(.result.subtype // "?") · \(.result.denials // 0) denied"' "$sb/trace.json")"
    if [ "$c" = ADP ]; then
        # The firing probe: a measurement, never a verdict. Nothing is appended to the eval history.
        "$PYTHON" "$HERE/check.py" probe "$sb/trace.json" | tee "$sb/probe.txt"
        RAN="$RAN $c"
        return 0
    fi
    # RV1 is also RV3's run and AD2 is also AD4's; grade both from it. `verdict` prints one CHECK line per id it grades.
    "$PYTHON" "$HERE/check.py" verdict "$sb/trace.json" > "$sb/verdict.txt" 2>&1
    while read -r _ verdict id msg; do
        # THE PAIRING: BG2 and BG3 assert "nothing changed", which a skill that never loaded satisfies as well. When
        # BG1 ran in this invocation and did not pass, the skill is unproven and neither verdict is evidence.
        case "$id" in
            BG2|BG3)
                _pair BG1 "$id" || { verdict=skip; msg="BG1 did not pass in this run: the skill is unproven"; }
                ;;
            SW2) _pair SW1 "$id" || { verdict=skip; msg="SW1 did not pass in this run: the skill is unproven"; } ;;
            PN2) _pair PN1 "$id" || { verdict=skip; msg="PN1 did not pass in this run: the skill is unproven"; } ;;
            CR2) _pair CR1 "$id" || { verdict=skip; msg="CR1 did not pass in this run: the skill is unproven"; } ;;
            AD2) _pair AD1 "$id" || { verdict=skip; msg="AD1 did not pass in this run: the guardrails are unproven"; } ;;
            AD4) _pair AD3 "$id" || { verdict=skip; msg="AD3 did not pass in this run: the guardrails are unproven"; } ;;
        esac
        [ "$verdict" = pass ] && PASSED="$PASSED $id"
        case "$verdict" in
            pass) echo "  PASS  $id $msg"; _rec "$id" pass "" "$sb/stream.jsonl" ;;
            fail) echo "  FAIL  $id $msg"; _rec "$id" fail "$msg" "$sb/stream.jsonl" ;;
            skip) echo "  SKIP  $id $msg"; _rec "$id" skip "$msg" "$sb/stream.jsonl" ;;
        esac
    done < <(grep '^CHECK ' "$sb/verdict.txt")
    RAN="$RAN $c"
    _sweep_sandbox "$c" "$sb"
}

# Remove a sandbox once its case PASSED (224 leftovers had to be cleaned up on 2026-11-04). The stream, trace and verdict
# stay: they are the only way to diagnose a case. A failed or skipped case keeps everything. Args: <case> <sandbox>
_sweep_sandbox() {
    local c="$1" sb="$2"
    case " $PASSED " in *" $c "*) ;; *) return 0 ;; esac
    [ -n "$sb" ] && [ "$sb" != "/" ] || return 0
    rm -f "$sb/home/Library"
    rm -rf "$sb/repo" "$sb/home" "$sb/state" "$sb/bin"
}

echo "== orchestrator-skills live: ${CASES}"
echo "   model: $EVAL_MODEL (effort $EVAL_EFFORT), per-case cap \$$EVAL_MAX_BUDGET_USD (step 3b cases: see _case_cap), plugin: ${PLUGIN##*/}"
RC=0
for c in $CASES; do
    _run_case "$c" || { RC=$?; break; }
done
echo
echo "spent: \$$SPENT over$RAN"

if [ "$RECORD" -eq 1 ]; then
    _record "$RAN"
fi
exit "$RC"
