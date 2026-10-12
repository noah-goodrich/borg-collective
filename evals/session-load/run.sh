#!/usr/bin/env bash
# Session-load eval: does a REAL headless session see each borg skill exactly once, and fire each
# borg lifecycle hook exactly once per logical event?  Directive:
# docs/plans/directives/2026-09-02-session-load-eval-skill-registration-and-hooks.md (SL1-SL5)
#
#   CHECKER   offline  -> check.py grades a synthesized clean session (passes) and the same session
#                         with a planted duplicate skill + second plugin dir (must go red, naming both
#                         counts). This is the case that keeps the execution floor satisfiable on a
#                         machine with no `claude`, exactly as VERBS does in lifecycle-manifests.
#   LIVE      model    -> starts `claude -p` headless with --output-format stream-json, and grades what
#                         the session REPORTED: the `init` event's skills/plugins and the per-event
#                         `hook_started` counts. It does not grep install paths; `borg setup`'s output
#                         is owned by the 31 unit cases in tests/plugin_dedup.bats and
#                         tests/setup_skill_cleanup.bats.
#
# Flags (the first two are shared by every harness `make eval` globs; an unknown flag exits 2):
#   --skip-model     skip LIVE; CHECKER still runs
#   --skip-network   ACCEPTED AND INERT -- nothing here reads the wire
#   --skills-only    LIVE grades skills only        } separate modes, because a machine may have
#   --hooks-only     LIVE grades hooks only         } hooks but a stale plugin, or the reverse
#
# INPUTS, resolved the way the other harnesses resolve theirs:
#   BORG_EVAL_PYTHON       interpreter; else $REPO/.venv/bin/python; else bare python3
#   BORG_EVAL_CLAUDE       the claude CLI; else `claude` on PATH. LIVE SKIPs, naming the resolved
#                          value, only when THAT is absent -- and the per-mode floor below then fails
#                          the run, because a LIVE request that ran nothing verified nothing.
#   BORG_EVAL_CLAUDE_HOME  the config dir read for the non-borg hook baseline; else $HOME/.claude
#   BORG_EVAL_REPO         the checkout (the oracle redirects the evidence tree through it)
#
# ISOLATION. The session runs with XDG_CONFIG_HOME and XDG_STATE_HOME redirected into $OUT, because the
# borg hooks derive BORG_DIR and the state root from those (CLAUDE.md "Learned": hooks recompute their
# own config paths; HOME alone leaks). So the registry, state.json and logs the real hooks write land in
# the sandbox. HOME is deliberately NOT redirected: the claim under test is what the INSTALLED plugin
# set does, and OAuth credentials resolve through HOME. `--no-session-persistence` keeps the transcript
# out of ~/.claude/projects, and the cwd is an empty directory under $OUT, so the session is
# project-mode and never the orchestrator root.
#
# CORTEX CODE IS NOT DRIVEN HERE, ON PURPOSE (SL5): CoCo fires its hooks independently, so there is no
# cross-CLI exactly-once to assert. Decision and reasoning are recorded in the directive.
#
# MODEL TIER IS PINNED, never inherited (see headless_pins.bats and the lifecycle-manifests eval). It is
# haiku/low rather than the orchestrator tier because registration and hook dispatch happen before and
# after the model turn and do not depend on it; the cheapest tier is the honest choice here.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${BORG_EVAL_REPO:-$(cd "$HERE/../.." && pwd)}"

if [ -n "${BORG_EVAL_PYTHON:-}" ]; then
    PYTHON="$BORG_EVAL_PYTHON"
elif [ -x "$REPO/.venv/bin/python" ]; then
    PYTHON="$REPO/.venv/bin/python"
else
    PYTHON="python3"
fi
CLAUDE_BIN="${BORG_EVAL_CLAUDE:-claude}"
CLAUDE_HOME="${BORG_EVAL_CLAUDE_HOME:-${HOME:-/nonexistent}/.claude}"

# GUARD BEFORE THE rm -rf (borg.zsh is the tracked root marker; see evals/s4-k3/run.sh).
if [ ! -f "$REPO/borg.zsh" ]; then
    echo "ERROR: REPO does not look like the borg-collective checkout: $REPO" >&2
    exit 2
fi

OUT="$REPO/evals/session-load/out"
CHECK="$HERE/check.py"

EVAL_MODEL=haiku
EVAL_EFFORT=low

SKIP_MODEL=0
SKIP_NETWORK=0
MODE=both
while [ $# -gt 0 ]; do
    case "$1" in
        --skip-model)   SKIP_MODEL=1 ;;
        --skip-network) SKIP_NETWORK=1 ;;
        --skills-only)  MODE=skills ;;
        --hooks-only)   MODE=hooks ;;
        -h|--help)      echo "usage: evals/session-load/run.sh [--skip-model] [--skip-network] [--skills-only|--hooks-only]"; exit 0 ;;
        *)              echo "unknown flag: $1" >&2; exit 2 ;;
    esac
    shift
done

rm -rf "$OUT"
mkdir -p "$OUT"

PASS=0; FAIL=0; SKIPPED=0
SKILLS_RAN=0; HOOKS_RAN=0
ok()   { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad()  { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }
skip() { echo "  SKIP  $1"; SKIPPED=$((SKIPPED+1)); }

# Print a check.py transcript as PASS/FAIL lines and bump the per-mode counters.
_report() {
    local line
    while IFS= read -r line; do
        case "$line" in
            "CHECK pass skills "*) SKILLS_RAN=$((SKILLS_RAN+1)); ok "${line#CHECK pass skills }" ;;
            "CHECK fail skills "*) SKILLS_RAN=$((SKILLS_RAN+1)); bad "${line#CHECK fail skills }" ;;
            "CHECK pass hooks "*)  HOOKS_RAN=$((HOOKS_RAN+1));   ok "${line#CHECK pass hooks }" ;;
            "CHECK fail hooks "*)  HOOKS_RAN=$((HOOKS_RAN+1));   bad "${line#CHECK fail hooks }" ;;
        esac
    done < "$1"
}

# ── CHECKER (offline) ────────────────────────────────────────────────────────────────────────────
# A synthesized session built from the repo's own authored skill list. Clean must exit 0; a planted
# duplicate skill and a second plugin dir must exit 1 and name the counts. Both directions, because a
# checker asserted only green passes just as well when it always exits 0.
if ! command -v "$PYTHON" >/dev/null 2>&1; then
    skip "CHECKER: interpreter '$PYTHON' not found -- set BORG_EVAL_PYTHON"
else
    synth() {
        local dup="$1" s
        printf '{"type":"system","subtype":"init","skills":['
        for s in "$REPO"/skills/*/SKILL.md; do
            s="${s%/SKILL.md}"; s="${s##*/}"
            printf '"borg-collective:%s",' "$s"
            if [ "$dup" = dup ] && [ "$s" = borg-plan ]; then printf '"%s",' "$s"; fi
        done
        printf '"other:x"],"plugins":[{"name":"borg-collective","path":"%s/none1"}' "$OUT"
        if [ "$dup" = dup ]; then printf ',{"name":"borg-collective","path":"%s/none2"}' "$OUT"; fi
        printf ']}\n'
        printf '{"type":"system","subtype":"hook_started","hook_event":"SessionStart"}\n'
        printf '{"type":"system","subtype":"hook_started","hook_event":"SessionStart"}\n'
        printf '{"type":"system","subtype":"hook_started","hook_event":"Stop"}\n'
        printf '{"type":"system","subtype":"hook_started","hook_event":"Stop"}\n'
        if [ "$dup" = dup ]; then printf '{"type":"system","subtype":"hook_started","hook_event":"SessionStart"}\n'; fi
    }
    mkdir -p "$OUT/checker/home"
    synth clean > "$OUT/checker/clean.jsonl"
    synth dup > "$OUT/checker/dup.jsonl"
    "$PYTHON" "$CHECK" --events "$OUT/checker/clean.jsonl" --repo "$REPO" --claude-home "$OUT/checker/home" \
        > "$OUT/checker/clean.out" 2>&1; clean_rc=$?
    "$PYTHON" "$CHECK" --events "$OUT/checker/dup.jsonl" --repo "$REPO" --claude-home "$OUT/checker/home" \
        > "$OUT/checker/dup.out" 2>&1; dup_rc=$?
    if [ "$clean_rc" -eq 0 ]; then
        ok "CHECKER: a clean synthesized session exits 0"
    else
        bad "CHECKER: a clean synthesized session exited $clean_rc (see $OUT/checker/clean.out)"
    fi
    if [ "$dup_rc" -eq 1 ] && grep -q 'observed 2 of 1 authored' "$OUT/checker/dup.out" \
        && grep -q 'fired 3 of 2 authored' "$OUT/checker/dup.out"; then
        ok "CHECKER: a planted duplicate skill, plugin dir and SessionStart hook exit 1, naming 2 of 1 (plugin) and 3 of 2 (hooks)"
    else
        bad "CHECKER: the planted duplicate did not turn red with both counts named (rc $dup_rc; see $OUT/checker/dup.out)"
    fi
fi

# ── LIVE (model) ─────────────────────────────────────────────────────────────────────────────────
LIVE_REQUESTED=0
if [ "$SKIP_MODEL" -eq 0 ]; then
    LIVE_REQUESTED=1
    if ! command -v "$CLAUDE_BIN" >/dev/null 2>&1; then
        skip "LIVE: resolved claude CLI '$CLAUDE_BIN' not found -- install it or set BORG_EVAL_CLAUDE"
    elif ! command -v "$PYTHON" >/dev/null 2>&1; then
        skip "LIVE: interpreter '$PYTHON' not found -- set BORG_EVAL_PYTHON"
    else
        mkdir -p "$OUT/xdg-config" "$OUT/xdg-state" "$OUT/project"
        ( cd "$OUT/project" && unset BORG_ORCHESTRATOR_ROOT BORG_DIR BORG_REGISTRY \
            && XDG_CONFIG_HOME="$OUT/xdg-config" XDG_STATE_HOME="$OUT/xdg-state" \
               "$CLAUDE_BIN" -p 'Reply with the single word OK.' --model "$EVAL_MODEL" --effort "$EVAL_EFFORT" \
               --output-format stream-json --verbose --include-hook-events --no-session-persistence \
               > "$OUT/session.jsonl" 2> "$OUT/session.err" )
        session_rc=$?
        if [ "$session_rc" -ne 0 ] && [ ! -s "$OUT/session.jsonl" ]; then
            bad "LIVE: premise broken: '$CLAUDE_BIN -p' exited $session_rc with no events -- $(head -1 "$OUT/session.err" 2>/dev/null)"
        else
            "$PYTHON" "$CHECK" --events "$OUT/session.jsonl" --repo "$REPO" --claude-home "$CLAUDE_HOME" \
                --mode "$MODE" > "$OUT/live.out" 2> "$OUT/live.err"
            check_rc=$?
            if [ "$check_rc" -eq 3 ]; then
                bad "LIVE: $(head -1 "$OUT/live.err")"
            else
                _report "$OUT/live.out"
            fi
        fi
    fi
fi

echo
echo "RESULT: $PASS pass, $FAIL fail, $SKIPPED skip"

# EXECUTION FLOORS: one global, then one per LIVE mode. SKIPs never gate, but a run in which nothing
# executed, or in which a requested mode graded nothing, verified nothing.
if [ $((PASS + FAIL)) -eq 0 ]; then
    echo "every case skipped: nothing was verified" >&2
    exit 1
fi
if [ "$LIVE_REQUESTED" -eq 1 ]; then
    if [ "$MODE" != hooks ] && [ "$SKILLS_RAN" -eq 0 ]; then
        echo "skills mode was requested but no skill was graded" >&2
        exit 1
    fi
    if [ "$MODE" != skills ] && [ "$HOOKS_RAN" -eq 0 ]; then
        echo "hooks mode was requested but no hook event was graded" >&2
        exit 1
    fi
fi
[ "$FAIL" -eq 0 ]
