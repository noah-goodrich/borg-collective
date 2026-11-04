#!/usr/bin/env bash
# Offline harness for the orchestrator-skill evals: borg-resume, borg-review, break-glass, borg-switch, pane,
# borg-collective-review and adhd-guardrails. THIS FILE NEVER REACHES A
# MODEL, THE NETWORK OR A CREDENTIAL. The live half is live.sh (headless `claude -p`, a developer command that spends
# money, never CI); it records sanitized runs to recorded/, and this harness proves them and the graders deterministically.
#
# CASES (graded by script over a reduced trace; see check.py and live.sh for what each asserts):
#   RS1 active record: do nothing, report it     RS2 fallback schedules (borg-resume absent)
#   RS3 terminal record: no CronCreate           RS4 paused: no fallback
#   RV1 diagnostic shape                         RV2 gates ledger, in order, before the first edit
#   RV3 a diagnostic runs no gates (RV1's run)   RV4 trivial change names its skipped gates
#   BG1 break-glass writes a narrow merged rule  BG2 a global-class command is declined
#   BG3 the model never invokes break-glass on its own
#   SW1 switch, named: exactly `borg switch <name>`     SW2 switch, unnamed (negative): the list command, no switch, asks which
#   SW3 switch failure: the error shown, `borg link --overview` suggested
#   PN1 pane, direction: exactly `drone pane <dir>`     PN2 pane, no direction (negative): no pane call, asks which direction
#   PN3 pane, reuse: the reuse and the restored zoom are said (the stub prints the real text, see SRC below)
#   CR1 collective review, summons: the review's shape with a code owner for a schema change
#   CR2 collective review, negative: the same shape for a typo fix, no code owner
#   AD1 out of plan: says so, offers add or defer, changes nothing   AD2 in plan (negative): no not-in-plan line
#   AD3 capacity: the warning's count and limit open the first text      AD4 no warning (negative): no capacity line
#
# STEP 3b NOTES (borg-switch, pane, borg-collective-review, adhd-guardrails; tracking issue 480):
#   * These cases grade what a skill DOES ONCE IT RUNS. Whether it fires on its own is the trigger suite (AC4), not here.
#   * SW and PN run against a stub `borg` and `drone` on the sandbox PATH that append their argv to a log; the grade reads
#     the log, never the model's account. The texts the stubs print are copies of strings in drone.zsh and borg.zsh, and
#     the SRC checks below fail when a copy and its source drift apart (PN3 depends on the reuse text being the real one).
#   * CR is graded for SHAPE, NOT JUDGMENT (the heading, the summoned and specialist lines, all six core voices by name, The
#     Adult last, the code owner present or absent, a real sandbox file named, a length bound). Noah set that precedent for
#     borg-review on 2026-11-02 and the cheapest-tier rule says a script can state it, so the ledger's old "judge only"
#     reason for borg-collective-review no longer applies. No `llm` grader. The length bound is the stated maximum in
#     SKILL.md ("Total review: 20-40 lines") times a HEADROOM of 1.5, so 60 non-blank lines; ENV recomputes both from the
#     SKILL.md so a change to the stated length moves the bound or fails loudly.
#   * adhd-guardrails is `user-invocable: false` and the step 0 triage shows 0 calls on record. AD1-AD4 therefore do NOT
#     depend on it firing: the skill BODY is delivered through --append-system-prompt-file and no plugin is loaded, and the
#     result says what the rules do when the model has read them. Whether the Skill tool fires is measured separately by
#     live.sh --case ADP (a measurement, never a graded case, never in a group). AD3 puts the SessionStart text the hook
#     produces into the same file. AD3 grades the first TEXT, because a run that works for twelve turns and then opens its
#     closing message with the warning has put nothing visible before it (a stricter first draft failed that run).
#   * AD4 is graded on AD2's run (no warning in context, an in-plan request), as RV3 is on RV1's.
#   * NOT GRADED, on purpose: adhd-guardrails' two-hour break rule, its low-energy rule and its shame-language rule (they need
#     a two-hour session, a drifting user and a judgment about tone), and its scope-expansion, perfectionism and done-criteria
#     rules.
#
# WHAT IS GRADED. Every case is a Tier 2 script grader. borg-review is graded for SHAPE (the diagnostic block, M equal to the
# plan's criteria count, exactly one recommendation, a gates ledger in order before the first edit), NOT for the quality of
# its diagnosis: AC3 allows `llm` graders only for the ledger's judge items and borg-review is not one (Noah, 2026-11-02).
#
# WHAT THIS RUN DOES, in order:
#   ENV       the environment proofs: the skills still say what the graders look for, the fixture repositories and the
#             sandbox HOME are what the cases assume, the borg-resume ledger is written by production code and the CLI reads
#             it back, borg-resume is absent from RS2's PATH, and live.sh's argv, case selector and prompt hint check hold
#   RECORDED  every recorded run is re-graded and must get the verdict the live run gave it. A recorded live FAILURE must
#             still fail (RV2 and RV4 are findings, see recorded/live-verdicts.json); it is reported as such, never as a pass
#   REDUCER   every recorded raw stream reduces to its recorded trace: the reducer is proven on the real event format
#   KNOWN-BAD every mutation in check.py (one fact made false in a copy of a recorded trace) must be rejected by the check
#             it targets. Where no live run passed, the mutations run on a SYNTHETIC positive (the failing trace plus the
#             missing output) and say so
#   SANITIZE  this repository is public: the sanitizer must refuse each planted leak and write nothing, and the committed
#             recording must contain nothing it would refuse
#   FLOORS    a missing recording, or a run in which nothing was graded, is a failure and never a skip
#
# Flags (shared by every harness `make eval` globs; an unknown flag exits 2): --skip-model and --skip-network are ACCEPTED
# AND INERT, nothing here reads the model or the wire.
#
# Environment: BORG_EVAL_REPO (the checkout whose skills/ are read; default two levels above this file), BORG_EVAL_PYTHON
# (the interpreter for check.py; default $REPO/.venv/bin/python, then python3).

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${BORG_EVAL_REPO:-$(cd "$HERE/../.." && pwd)}"

while [ $# -gt 0 ]; do
    case "$1" in
        --skip-model|--skip-network) ;;
        -h|--help) echo "usage: evals/orchestrator-skills/run.sh [--skip-model] [--skip-network]"; exit 0 ;;
        *) echo "unknown flag: $1" >&2; exit 2 ;;
    esac
    shift
done

if [ ! -f "$REPO/borg.zsh" ]; then
    echo "ERROR: REPO does not look like the borg-collective checkout: $REPO" >&2
    exit 2
fi

# shellcheck source=/dev/null
source "$HERE/fixtures.sh"
PYTHON="$(_os_python "$REPO")"

OUT="$REPO/evals/orchestrator-skills/out"
rm -rf "$OUT"
mkdir -p "$OUT"
REC="$HERE/recorded"

PASS=0; FAIL=0; SKIPPED=0
ok()   { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
skip() { echo "  SKIP  $1"; SKIPPED=$((SKIPPED+1)); }

# Turn check.py's `CHECK pass|fail|skip <id> <message>` lines into PASS/FAIL/SKIP, prefixed with $1.
tally() {
    local prefix="$1" file="$2" verdict id msg
    while read -r _ verdict id msg; do
        case "$verdict" in
            pass) ok "$prefix $id: $msg" ;;
            fail) bad "$prefix $id: $msg" ;;
            skip) skip "$prefix $id: $msg" ;;
        esac
    done < <(grep '^CHECK ' "$file")
}

# One summary line from a many-line check: PASS when no line failed, FAIL naming the first one that did.
summarize() {
    local label="$1" file="$2" n
    n="$(grep -c '^CHECK fail ' "$file")"
    if [ "$n" -eq 0 ] && grep -q '^CHECK pass ' "$file"; then
        ok "$label"
    else
        bad "$label: $(grep '^CHECK fail ' "$file" | head -1)"
    fi
}

# claude is never on any PATH this file builds, and the live script is only ever asked to print.
live_dry() {
    env -u EVAL_MODEL -u EVAL_EFFORT -u EVAL_CASES -u EVAL_MAX_BUDGET_USD -u EVAL_TOTAL_BUDGET_USD -u EVAL_PLUGIN_DIR \
        BORG_EVAL_REPO="$REPO" bash "$HERE/live.sh" --dry-run "$@"
}

run_cases() {
    local rc kind verdict target origin cases n sb bin home

    # ENV (python half) ------------------------------------------------------------------------------------------------
    "$PYTHON" "$HERE/check.py" env "$REPO" "$_OS_WF_RUN" "$_OS_WF_SCRIPT_REL" "$_OS_STRAY_FILE" 3 > "$OUT/env.txt" 2>&1
    tally ENV "$OUT/env.txt"

    # ENV (fixtures): the repositories are what the cases assume ----------------------------------------------------------
    sb="$OUT/fx"
    _os_repo_review "$sb/review" >/dev/null
    if [ "$(grep -c '^- \[ \] AC' "$sb/review/PROJECT_PLAN.md")" -eq 3 ] \
        && [ "$(git -C "$sb/review" log --oneline | grep -c .)" -eq 3 ] \
        && git -C "$sb/review" status --short | grep -q "^?? $_OS_STRAY_FILE$" \
        && git -C "$sb/review" status --short | grep -q '^ M invoice.py$'; then
        ok "ENV review fixture: a plan of 3 criteria, 3 commits, one file modified and the stray file untracked"
    else
        bad "ENV review fixture is not the 3-criteria, stray-file repository RV1 grades"
    fi
    _os_repo_gates "$sb/gates" >/dev/null
    _os_repo_trivial "$sb/trivial" >/dev/null
    if ( cd "$sb/gates" && bash tests/test_guard.sh ) >/dev/null 2>&1 && grep -q 'recieve' "$sb/trivial/README.md"; then
        ok "ENV gates fixture: the guard test is green before the change, and the typo is there to fix"
    else
        bad "ENV gates or trivial fixture is not what RV2 and RV4 expect"
    fi
    _os_repo_breakglass "$sb/bg" >/dev/null
    _os_home "$sb/home"
    if "$PYTHON" -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["permissions"]["allow"]==["Bash(make test:*)"]; json.load(open(sys.argv[2]))' \
        "$sb/bg/.claude/settings.local.json" "$sb/home/.claude/settings.json" 2>/dev/null; then
        ok "ENV break-glass fixture: the local settings hold exactly one rule, the sandbox HOME settings are valid JSON"
    else
        bad "ENV break-glass fixture: the settings files are not what BG1 compares against"
    fi
    if "$PYTHON" "$HERE/check.py" snapshot "$sb/bg" "$sb/home" | grep -q '"local_settings": "{'; then
        ok "ENV the sandbox snapshot reads the local settings and the HOME settings hash"
    else
        bad "ENV the sandbox snapshot does not carry the local settings"
    fi

    # ENV (live.sh): argv, case selector, prompt hint check ----------------------------------------------------------------
    if live_dry > "$OUT/dry-all.txt" 2>&1 && [ "$(grep -c '^CASE ' "$OUT/dry-all.txt")" -eq 21 ] \
        && grep -q -- '--model claude-opus-5-5' "$OUT/dry-all.txt" && grep -q -- '--plugin-dir' "$OUT/dry-all.txt" \
        && grep -q -- '--max-budget-usd' "$OUT/dry-all.txt" && grep -q -- '--output-format stream-json' "$OUT/dry-all.txt" \
        && grep -q -- '--allowedTools' "$OUT/dry-all.txt"; then
        ok "ENV live.sh assembles all 21 graded cases on the pinned Opus with a plugin dir, a budget cap and stream-json"
    else
        bad "ENV live.sh --dry-run did not assemble the expected argv for the 21 cases (see $OUT/dry-all.txt)"
    fi
    if live_dry --case resume > "$OUT/dry-resume.txt" 2>&1 && [ "$(grep -c '^CASE ' "$OUT/dry-resume.txt")" -eq 4 ] \
        && ! grep -q '^CASE R[VB]\|^CASE BG' "$OUT/dry-resume.txt"; then
        ok "ENV the case selector runs one skill's cases as a group (resume is exactly RS1-RS4)"
    else
        bad "ENV --case resume did not select exactly RS1-RS4"
    fi
    # THE SWEEP'S GROUPS DO NOT MOVE: the weekly sweep calls live.sh with one of these selectors (borg_core/evals/sweep/shell.py)
    # and reserves budget from fixed case lists, so each must still select exactly the cases it did before step 3b.
    if live_dry --case review 2>/dev/null | grep '^CASE ' | cut -d' ' -f2 | tr '\n' ' ' | grep -qx 'RV1 RV2 RV4 ' \
        && live_dry --case break-glass 2>/dev/null | grep '^CASE ' | cut -d' ' -f2 | tr '\n' ' ' | grep -qx 'BG1 BG2 BG3 ' \
        && live_dry --case resume 2>/dev/null | grep '^CASE ' | cut -d' ' -f2 | tr '\n' ' ' | grep -qx 'RS1 RS2 RS3 RS4 '; then
        ok "ENV the sweep's selectors (review, resume, break-glass) still select exactly their original cases"
    else
        bad "ENV a sweep selector (review, resume or break-glass) no longer selects its original cases"
    fi
    if live_dry --case switch 2>/dev/null | grep '^CASE ' | cut -d' ' -f2 | tr '\n' ' ' | grep -qx 'SW1 SW2 SW3 ' \
        && live_dry --case pane 2>/dev/null | grep '^CASE ' | cut -d' ' -f2 | tr '\n' ' ' | grep -qx 'PN1 PN2 PN3 ' \
        && live_dry --case collective-review 2>/dev/null | grep '^CASE ' | cut -d' ' -f2 | tr '\n' ' ' | grep -qx 'CR1 CR2 ' \
        && live_dry --case adhd 2>/dev/null | grep '^CASE ' | cut -d' ' -f2 | tr '\n' ' ' | grep -qx 'AD1 AD3 AD2 ' \
        && live_dry --case AD4 2>/dev/null | grep '^CASE ' | cut -d' ' -f2 | tr '\n' ' ' | grep -qx 'AD2 ' \
        && ! grep -q '^CASE ADP' "$OUT/dry-all.txt"; then
        ok "ENV the step 3b selectors select their own cases (adhd runs the positive before its negative), AD4 rides AD2's run, the probe is in no default"
    else
        bad "ENV a step 3b selector (switch, pane, collective-review, adhd, AD4) selects the wrong cases, or the probe is in the default"
    fi
    live_dry --case adhd,ADP > "$OUT/dry-adhd.txt" 2>&1
    if [ "$(grep 'CASE AD' "$OUT/dry-adhd.txt" | grep -vc ADP)" -eq 3 ] \
        && [ "$(grep -c -- '--append-system-prompt-file' "$OUT/dry-adhd.txt")" -eq 3 ] \
        && [ "$(grep -c -- '--plugin-dir' "$OUT/dry-adhd.txt")" -eq 1 ] \
        && grep -A1 '^CASE ADP' "$OUT/dry-adhd.txt" | grep -q -- '--plugin-dir' \
        && ! grep -A1 '^CASE ADP' "$OUT/dry-adhd.txt" | grep -q -- '--append-system-prompt-file'; then
        ok "ENV AD1-AD3 deliver the skill body by file with no plugin; the firing probe loads the plugin and appends nothing"
    else
        bad "ENV the adhd cases do not deliver the skill by file (or the probe does not load the plugin alone)"
    fi
    live_dry --case RV3 > "$OUT/dry-rv3.txt" 2>/dev/null
    if grep -q '^CASE RV1 ' "$OUT/dry-rv3.txt" && [ "$(grep -c '^CASE ' "$OUT/dry-rv3.txt")" -eq 1 ] \
        && ! live_dry --case no-such-case >/dev/null 2>&1; then
        ok "ENV RV3 selects RV1's run (it has none of its own) and an unknown case is refused"
    else
        bad "ENV the selector mishandled RV3 or accepted an unknown case"
    fi
    if grep -q 'borg-resume-on-path=0' "$OUT/dry-resume.txt" && [ "$(grep -c 'borg-resume-on-path=1' "$OUT/dry-resume.txt")" -eq 3 ] \
        && grep 'CASE RS2 ' "$OUT/dry-resume.txt" | grep -q 'borg-resume-on-path=0'; then
        ok "ENV borg-resume is on the PATH for RS1, RS3 and RS4 and absent for RS2"
    else
        bad "ENV the borg-resume PATH variants are wrong"
    fi
    n=0
    for kind in "$(_os_prompt_resume /x)" "$(_os_prompt_review)" "$(_os_prompt_gates)" "$(_os_prompt_trivial)" \
                "$(_os_prompt_bg1)" "$(_os_prompt_bg2)" "$(_os_prompt_bg3)" \
                "$(_os_prompt_sw1)" "$(_os_prompt_sw2)" "$(_os_prompt_sw3)" "$(_os_prompt_pn1)" "$(_os_prompt_pn2)" \
                "$(_os_prompt_pn3)" "$(_os_prompt_cr)" "$(_os_prompt_ad1)" "$(_os_prompt_ad2)"; do
        _os_prompt_leaks "$kind" 2>/dev/null && n=$((n+1))
    done
    if [ "$n" -eq 16 ] && ! _os_prompt_leaks "check the watcher first" 2>/dev/null \
        && ! _os_prompt_leaks "please CronCreate it" 2>/dev/null; then
        ok "ENV no prompt names the property under test, and the hint check refuses one that does"
    else
        bad "ENV the prompt hint check is broken ($n of 16 prompts clean)"
    fi

    # ENV (step 3b): the four skills say what the graders look for; the stubs resolve inside the sandbox PATH and print what
    # the source prints; the fixtures are what the cases assume ------------------------------------------------------------
    "$PYTHON" "$HERE/check.py" skills "$REPO" > "$OUT/skills.txt" 2>&1
    tally ENV "$OUT/skills.txt"
    _env_stubs
    _env_fixtures_3b

    # ENV (borg-resume): production code writes the ledger, the real CLI reads it. Needs jq: SKIP without it ----------------
    if ! command -v jq >/dev/null 2>&1; then
        skip "ENV borg-resume ledger: jq is not on PATH, and borg-resume reads its ledger with it"
    else
        bin="$(_os_allowlist_bin "$OUT/resume-bin" 1)"
        for kind in active terminal paused; do
            ( _os_seed_resume "$OUT/seed-$kind" "$kind" ) >/dev/null 2>&1
            BORG_RESUME_DIR="$OUT/seed-$kind/resume" BORG_RESUME_NOW_EPOCH="$_OS_SEED_EPOCH" PATH="$bin" \
                borg-resume status --all --json > "$OUT/status-$kind.json" 2>/dev/null
        done
        if jq -e --arg run "workflow:$_OS_WF_RUN" '.paused == false and (.records | length) == 1 and .records[0].scope == $run
                and .records[0].state == "scheduled" and .records[0].resume_at > .now' "$OUT/status-active.json" >/dev/null 2>&1 \
            && jq -e '.records[0].state == "failed" and .paused == false' "$OUT/status-terminal.json" >/dev/null 2>&1 \
            && jq -e '.paused == true and (.records | length) == 0' "$OUT/status-paused.json" >/dev/null 2>&1 \
            && jq -e --slurpfile e "$OUT/seed-active/expect.json" '.records[0].rid == $e[0].rid' "$OUT/status-active.json" >/dev/null 2>&1; then
            ok "ENV borg-resume status reads the production-written ledger: active scheduled, terminal failed, paused with no records"
        else
            bad "ENV borg-resume status did not read the seeded ledgers as RS1, RS3 and RS4 assume (see $OUT/status-*.json)"
        fi
        bin="$(_os_allowlist_bin "$OUT/noresume-bin" 0)"
        # A PATH of exactly one directory resolves a name iff an executable of that name is in it.
        if [ ! -e "$bin/borg-resume" ] && [ -x "$OUT/resume-bin/borg-resume" ]; then
            ok "ENV borg-resume is unresolvable on RS2's PATH and resolvable on the others"
        else
            bad "ENV the borg-resume PATH variants do not differ"
        fi
    fi

    # RECORDED ---------------------------------------------------------------------------------------------------------------
    if [ ! -f "$REC/live-verdicts.json" ]; then
        bad "recorded: no recording at $REC: run evals/orchestrator-skills/live.sh --record"
        return
    fi
    "$PYTHON" "$HERE/check.py" replay "$REC" > "$OUT/replay.txt" 2>&1
    rc=$?
    tally recorded "$OUT/replay.txt"
    [ "$rc" -eq 3 ] && bad "recorded: premise broken -- $(head -1 "$OUT/replay.txt")"

    # REDUCER ----------------------------------------------------------------------------------------------------------------
    "$PYTHON" "$HERE/check.py" reducer "$REC" > "$OUT/reducer.txt" 2>&1
    summarize "reducer: every recorded stream reduces to its recorded trace" "$OUT/reducer.txt"

    # KNOWN-BAD: each mutation must be rejected by its own check; the verdict that counts is named per mutation ---------------
    while read -r kind verdict target origin; do
        [ -n "$kind" ] || continue
        if ! "$PYTHON" "$HERE/check.py" mutate "$REC" "$kind" "$OUT/bad-$kind" > "$OUT/bad-$kind.log" 2>&1; then
            bad "known-bad $kind: the mutation could not be built -- $(head -1 "$OUT/bad-$kind.log")"
            continue
        fi
        "$PYTHON" "$HERE/check.py" grade "$OUT/bad-$kind" > "$OUT/bad-$kind.txt" 2>&1
        if grep -q "^CHECK $verdict $target " "$OUT/bad-$kind.txt"; then
            case "$kind-$origin" in
                synthetic-positive*) ok "synthetic positive $kind: the repaired RV trace PASSES $target (no live run passed)" ;;
                *-synthetic) ok "known-bad $kind is rejected by $target [on a SYNTHETIC positive: no live run passed]" ;;
                *) ok "known-bad $kind is rejected by $target ($verdict)" ;;
            esac
        else
            bad "known-bad $kind did not get $verdict from $target; that check no longer discriminates"
        fi
    done < <("$PYTHON" "$HERE/check.py" mutations "$REC")

    # SANITIZE: refuse each planted leak and write nothing, accept a clean run ---------------------------------------------
    _sanitize_cases
    "$PYTHON" "$HERE/check.py" scan "$REC" > "$OUT/scan.txt" 2>&1
    summarize "sanitize: the committed recording holds nothing the sanitizer refuses" "$OUT/scan.txt"
}

# The stub CLIs: resolvable on the sandbox PATH (rule 7: prove the environment before the model), logging their argv, and
# printing what drone.zsh, borg.zsh and the SessionStart hook print. A drifted copy must be caught.
_env_stubs() {
    local bin log t drift
    bin="$(_os_stub_bin "$OUT/stub-bin")"
    log="$OUT/stub.log"
    t="$OUT/srctext"
    rm -rf "$t"; mkdir -p "$t"; : > "$log"
    if [ -x "$bin/borg" ] && [ -x "$bin/drone" ] && [ "$(env -i PATH="$bin" bash -c 'command -v borg; command -v drone' | grep -c "^$bin/")" -eq 2 ]; then
        ok "ENV borg and drone resolve on the stub cases' sandbox PATH (the PATH is exactly one directory)"
    else
        bad "ENV borg or drone does not resolve on the stub cases' sandbox PATH"
    fi
    export EVAL_STUB_LOG="$log"
    EVAL_STUB_MODE=pane-reuse "$bin/drone" pane right > "$t/pane-reuse.txt" 2>&1
    EVAL_STUB_MODE=pane-reuse-zoomed "$bin/drone" pane left > "$t/pane-reuse-zoomed.txt" 2>&1
    EVAL_STUB_MODE=pane-new "$bin/drone" pane right > "$t/pane-new.txt" 2>&1
    "$bin/drone" pane > "$t/pane-nodir.txt" 2>&1
    EVAL_STUB_MODE=switch-fail "$bin/borg" switch nonesuch-repo > "$t/switch-fail.txt" 2>&1
    _os_capacity_text "$_OS_CAP_COUNT" "$_OS_CAP_LIMIT" > "$t/capacity.txt"
    unset EVAL_STUB_LOG
    if [ "$(wc -l < "$log" | tr -d ' ')" -eq 5 ] && sed -n 1p "$log" | grep -qx 'drone pane right' && sed -n 5p "$log" | grep -qx 'borg switch nonesuch-repo'; then
        ok "ENV the stubs log one argv line per call"
    else
        bad "ENV the stubs did not log what they were called with (see $log)"
    fi
    "$PYTHON" "$HERE/check.py" srctext "$REPO" "$t" "$_OS_STUB_WNAME" "$_OS_CAP_COUNT" "$_OS_CAP_LIMIT" > "$OUT/srctext.txt" 2>&1
    tally ENV "$OUT/srctext.txt"
    # DRIFT: change each copied text by one word and the matching check must fail
    for drift in pane-reuse pane-reuse-zoomed pane-new pane-nodir switch-fail capacity; do
        rm -rf "$OUT/srctext-drift"; cp -R "$t" "$OUT/srctext-drift"
        sed -i.bak 's/[A-Za-z]\{4,\}/drifted/' "$OUT/srctext-drift/$drift.txt"
        "$PYTHON" "$HERE/check.py" srctext "$REPO" "$OUT/srctext-drift" "$_OS_STUB_WNAME" "$_OS_CAP_COUNT" "$_OS_CAP_LIMIT" > "$OUT/srctext-drift.txt" 2>&1
        if grep -q "^CHECK fail SRC-$drift " "$OUT/srctext-drift.txt"; then
            ok "known-bad: a drifted $drift text is rejected by SRC-$drift"
        else
            bad "known-bad: a drifted $drift text was NOT rejected: the stub could drift from the source unnoticed"
        fi
    done
}

# The AD3 session context is the hook's text, and the adhd context file carries the skill body without its frontmatter.
_env_fixtures_3b() {
    local sb="$OUT/fx3b"
    rm -rf "$sb"; mkdir -p "$sb"
    _os_repo_plan "$sb/plan" >/dev/null
    _os_repo_schema "$sb/schema" >/dev/null
    _os_repo_typo "$sb/typo" >/dev/null
    _os_adhd_context "$REPO/skills/adhd-guardrails/SKILL.md" "$sb/ad1.md" 0
    _os_adhd_context "$REPO/skills/adhd-guardrails/SKILL.md" "$sb/ad3.md" 1
    if [ "$(grep -c '^- \[ \] AC' "$sb/plan/PROJECT_PLAN.md")" -eq 3 ] && [ -z "$(git -C "$sb/plan" status --short)" ] \
        && ! grep -q 'export' "$sb/plan/invoice.py"; then
        ok "ENV plan fixture: three criteria, a clean tree, and no export code yet (AD1 asks for a theme, AD2 for the export)"
    else
        bad "ENV the plan fixture is not the clean three-criteria repository AD1-AD3 assume"
    fi
    if git -C "$sb/schema" status --short | grep -q '^?? migrations/002_invoices.sql$' && grep -q 'created_at' "$sb/schema/migrations/001_users.sql" \
        && ! grep -q 'created_at' "$sb/schema/migrations/002_invoices.sql" \
        && git -C "$sb/typo" status --short | grep -q '^ M README.md$'; then
        ok "ENV CR fixtures: an uncommitted schema migration with no audit columns, and an uncommitted spelling fix"
    else
        bad "ENV the CR fixtures are not an uncommitted schema change and an uncommitted typo fix"
    fi
    if grep -q 'Cognitive Load Guardrails' "$sb/ad1.md" && ! grep -q '^name: adhd' "$sb/ad1.md" && ! grep -q 'user-invocable' "$sb/ad1.md" \
        && ! grep -q 'SessionStart context' "$sb/ad1.md" && grep -q 'SessionStart context' "$sb/ad3.md" \
        && grep -q "CAPACITY WARNING: $_OS_CAP_COUNT repositories active/waiting (limit: $_OS_CAP_LIMIT)" "$sb/ad3.md"; then
        ok "ENV the adhd context file is the skill body without frontmatter; only AD3's carries the warning"
    else
        bad "ENV the adhd context files are not the skill body (AD1, AD2) and the body plus the warning (AD3)"
    fi
}

# A tiny raw run (a real-shaped stream with an init event carrying a session id), with one planted leak per call.
# Args: <dir> <leak-text>
_plant_run() {
    local dir="$1" leak="$2" sid="11111111-2222-4333-8444-555555555555"
    mkdir -p "$dir/RS1"
    printf '{"case":"RS1","sandbox":"%s","plugin":"%s/plugin","expect":{},"before":{},"after":{}}\n' "$OUT/plant" "$OUT/plant" \
        > "$dir/RS1/meta.json"
    {
        printf '{"type":"system","subtype":"init","session_id":"%s","cwd":"/x"}\n' "$sid"
        printf '{"type":"assistant","session_id":"%s","message":{"role":"assistant","content":[{"type":"text","text":"%s"}]}}\n' "$sid" "$leak"
        printf '{"type":"result","subtype":"success","is_error":false,"result":"%s","total_cost_usd":0.01,"num_turns":1,"modelUsage":{"m":{"costUSD":0.01}},"permission_denials":[]}\n' "$leak"
    } > "$dir/RS1/stream.jsonl"
}

_sanitize_cases() {
    local label leak dest refused=0 total=0
    # The one-word labels keep the loop readable; each leak is something the refuse-list names.
    for label in email homepath sessionid reminder claudemd; do
        case "$label" in
            # the account email is assembled at run time so this public file never spells it
            email) leak="mail someone@gmail.com" ;;
            homepath) leak="see /Users/someone/dev/x" ;;
            sessionid) leak="the session 11111111-2222-4333-8444-555555555555" ;;
            reminder) leak="<system-reminder>be brief</system-reminder>" ;;
            claudemd) leak="Contents of /home/u/.claude/CLAUDE.md (user instructions)" ;;
        esac
        total=$((total+1))
        rm -rf "$OUT/plant" "$OUT/plant-out"
        _plant_run "$OUT/plant" "$leak"
        "$PYTHON" "$HERE/check.py" sanitize "$OUT/plant" "$OUT/plant-out" "$REPO" > "$OUT/plant-$label.txt" 2>&1
        rc=$?
        if [ "$rc" -eq 3 ] && grep -q 'sanitize refused' "$OUT/plant-$label.txt" && [ ! -e "$OUT/plant-out" ]; then
            refused=$((refused+1))
        else
            bad "sanitize did not refuse a planted $label leak (exit $rc), or wrote output anyway"
        fi
    done
    [ "$refused" -eq "$total" ] && ok "sanitize refuses all $total planted leaks (email, home path, session id, system context, CLAUDE.md text) and writes nothing"
    rm -rf "$OUT/plant" "$OUT/plant-out"
    _plant_run "$OUT/plant" "all clear"
    if "$PYTHON" "$HERE/check.py" sanitize "$OUT/plant" "$OUT/plant-out" "$REPO" > "$OUT/plant-clean.txt" 2>&1 \
        && [ -f "$OUT/plant-out/RS1.trace.json" ] && [ -f "$OUT/plant-out/RS1.stream.jsonl" ]; then
        ok "sanitize accepts a clean run and writes its trace and init-stripped stream"
    else
        bad "sanitize refused a clean run -- $(head -1 "$OUT/plant-clean.txt")"
    fi
    dest="$OUT/plant-out/RS1.stream.jsonl"
    if [ -f "$dest" ] && ! grep -q '11111111-2222' "$dest" && ! grep -q '"system"' "$dest"; then
        ok "sanitize strips the init event and every session id from the stream it writes"
    else
        bad "sanitize left the init event or a session id in the stream"
    fi
}

if ! command -v "$PYTHON" >/dev/null 2>&1; then
    skip "interpreter '$PYTHON' not found -- set BORG_EVAL_PYTHON; check.py cannot run"
else
    run_cases
fi

echo
echo "RESULT: $PASS pass, $FAIL fail, $SKIPPED skip"
if [ $((PASS + FAIL)) -eq 0 ]; then
    echo "no case was graded: nothing was verified" >&2
    exit 1
fi
[ "$FAIL" -eq 0 ]
