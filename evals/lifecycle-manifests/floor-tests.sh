#!/usr/bin/env bash
# Oracle for evals/lifecycle-manifests/run.sh's guards and fixtures. NEEDS NO MODEL, so CI runs it
# on the same leg as the rest of the suite while the cases it guards cannot run there at all --
# through `tests/eval_lifecycle_floor.bats`, which `bats tests/*.bats` collects by existing. The
# first version of this header made that claim with NO caller anywhere in the tree, so the "floor"
# was a script someone had to remember to run: the shape its own second paragraph decries.
#
# WHAT IT NEEDS: an interpreter with an importable pytest (the same premise `tests/eval_floor.bats`
# refuses to skip over), because run.sh's offline VERBS case is what keeps the global floor
# satisfiable in cases 5 and 7 below. Absent, this file FAILS by name rather than skipping.
#
# WHY THIS FILE EXISTS. run.sh is model-only: all six cases call `claude`, so no CI job can execute
# them and their only forcing function is someone remembering. That is exactly the shape that let
# `make eval-live` report SUCCESS at exit 0 on a machine with no `claude` installed and the entire
# model sweep absent -- a green run of nothing. The repair was a mode floor, and then the discovery
# that the floor ITSELF had no oracle and could be deleted with every gate staying green. So the
# floor lands with its pair, and the pair runs where the floor does not.
#
# EVERY CASE IS IN THE FIRING DIRECTION AND THE DIRECTION THAT PROVES IT DISCRIMINATES. A guard
# asserted only firing is satisfied just as well by an artifact that always fails.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
RUN="$HERE/run.sh"

# shellcheck source=/dev/null
source "$HERE/fixtures.sh"

PASS=0; FAIL=0
ok()  { echo "  PASS  $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL  $1"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# THE PREMISE, CHECKED BEFORE ANY CASE. Same ladder run.sh climbs, so this file cannot pass an
# interpreter run.sh will not find.
PYTHON="$(_eval_python "$REPO")"
if ! "$PYTHON" -c 'import pytest' >/dev/null 2>&1; then
    echo "premise broken: no interpreter with an importable pytest -- run 'pip install --group dev'" >&2
    exit 1
fi

# A SANDBOX `$REPO` FOR EVERY run.sh INVOCATION BELOW, never the real checkout. run.sh `rm -rf`s
# `$REPO/evals/lifecycle-manifests/out` on every run, and a floor test that aims that at the tree it
# lives in mutates the checkout under test. Same recipe as `tests/eval_floor.bats`'s
# `_eval_sandbox_repo`: every root entry symlinked in EXCEPT `evals/`, which is what the deletion
# lands in. `borg.zsh` comes along because run.sh's checkout guard demands it.
SANDBOX="$WORK/repo"
mkdir -p "$SANDBOX"
for entry in "$REPO"/*; do
    [ "${entry##*/}" = "evals" ] && continue
    ln -sfn "$entry" "$SANDBOX/${entry##*/}"
done
export BORG_EVAL_REPO="$SANDBOX" BORG_EVAL_PYTHON="$PYTHON"

echo "== floor: fixture builders =="

# ── 1. the manifest fixture VALIDATES, both directions ───────────────────────────────────────────
#
# THE CASE THAT ALREADY CAUGHT A REAL DEFECT. The first builder used an escaped default expansion
# and leaked backslashes into the JSON, so `discover()` rejected the file. "Rejected" and "absent"
# are indistinguishable downstream, so every negative case would have passed for the wrong reason.
d="$(_eval_repo_with_manifest "$WORK/valid" prog)"
if [ -f "$d/$_EVAL_MANIFEST_DIR/prog.json" ] && python3 -c '
import json, sys
json.load(open(sys.argv[1]))' "$d/$_EVAL_MANIFEST_DIR/prog.json" 2>/dev/null; then
    ok "manifest fixture is parseable JSON"
else
    bad "manifest fixture is not parseable JSON"
fi

if PYTHONPATH="$REPO" python3 -c '
import sys
from borg_core.manifest import shell
ms, warns = shell.discover([sys.argv[1]])
sys.exit(0 if len(ms) == 1 and not warns else 1)' "$d" 2>/dev/null; then
    ok "manifest fixture is DISCOVERABLE with zero warnings"
else
    bad "manifest fixture is rejected by discover() — negatives would pass for the wrong reason"
fi

# The discriminating direction: a deliberately malformed row MUST be rejected, or the assertion
# above proves nothing about validity.
bd="$(_eval_repo_with_manifest "$WORK/badrows" prog '[{"ref":"not-a-ref"}]')"
if PYTHONPATH="$REPO" python3 -c '
import sys
from borg_core.manifest import shell
ms, warns = shell.discover([sys.argv[1]])
sys.exit(0 if not ms and warns else 1)' "$bd" 2>/dev/null; then
    ok "a malformed-row fixture IS rejected (the check discriminates)"
else
    bad "a malformed-row fixture was accepted — the validity check is vacuous"
fi

# ── 2. the manifest-LESS fixture provably has no .borg ───────────────────────────────────────────
#
# "No manifest" is the premise of N2, and a stray `.borg` silently inverts it.
# A `.borg` is PLANTED FIRST, so the builder's removal is genuinely required. Without this the
# assertion passed whether or not the builder removed anything — `_eval_repo` never creates `.borg`,
# so "absent because removed" and "absent because never made" were indistinguishable.
mkdir -p "$WORK/none/$_EVAL_MANIFEST_DIR"
printf '{"program":"stale","rows":[]}\n' > "$WORK/none/$_EVAL_MANIFEST_DIR/stale.json"
nd="$(_eval_repo_without_manifest "$WORK/none")"
if [ ! -e "$nd/.borg" ] && [ ! -e "$nd/$_EVAL_MANIFEST_DIR" ]; then
    ok "manifest-less fixture has NO .borg and no manifest root at all"
else
    bad "manifest-less fixture carries a manifest root or .borg — N2's premise is inverted"
fi
if [ -d "$d/$_EVAL_MANIFEST_DIR" ]; then
    ok "and the with-manifest fixture does carry one (the pair discriminates)"
else
    bad "with-manifest fixture has no manifest root"
fi

# ── 3. fixtures carry a real commit ──────────────────────────────────────────────────────────────
#
# A repository with no commit fails for reasons unrelated to any assertion, and git refuses to
# commit at all on a bare Linux runner without an identity -- which is why _eval_git_env exports
# GIT_AUTHOR_* rather than writing a .gitconfig the sandbox's redirected $HOME would hide.
if git -C "$d" rev-parse HEAD >/dev/null 2>&1; then
    ok "fixture repository has a commit"
else
    bad "fixture repository has no commit — cases would fail for an unrelated reason"
fi

echo "== floor: the allowlist bin dir =="

# ── 4. the allowlist contains bash, and does NOT contain the real gh ─────────────────────────────
#
# Rule 3: a `#!/usr/bin/env bash` shebang searches the PATH UNDER TEST for its own interpreter, so
# omitting bash means the stub never runs. Rule 2: the point is that the real gh is unreachable,
# and asserting that by name is stronger than assuming a directory list excludes it.
printf '#!/bin/sh\necho "{\\"number\\":7}"\n' > "$WORK/ghstub"
chmod +x "$WORK/ghstub"
bindir="$(_eval_allowlist_bin "$WORK/bin" "$WORK/ghstub")"
if [ -e "$bindir/bash" ]; then
    ok "allowlist includes bash (the shebang can resolve)"
else
    bad "allowlist omits bash — a bash-shebang stub cannot run"
fi
real_gh="$(command -v gh 2>/dev/null || true)"
stub_target="$(readlink "$bindir/gh" 2>/dev/null || echo "$bindir/gh")"
if [ -z "$real_gh" ] || [ "$stub_target" != "$real_gh" ]; then
    ok "allowlist's gh is the STUB, not the real binary"
else
    bad "allowlist's gh resolves to the real binary"
fi
# THE CASE THAT WOULD HAVE SAVED TWO SWEEPS. `claude` absent from the allowlist means every model
# case invokes a command that does not exist, and "the skill never ran" is indistinguishable from
# "the skill ran and declined" in the output. Asserted by name.
# CONDITIONAL ON THE MACHINE HAVING ONE, like the `gh` check above: a CI runner has no `claude`, and
# "the allowlist carries what this machine lacks" is not a fact a symlink can make true.
real_claude="$(command -v claude 2>/dev/null || true)"
if [ -z "$real_claude" ]; then
    ok "claude is absent on this machine, so the allowlist cannot be asked to carry it"
elif PATH="$bindir" command -v claude >/dev/null 2>&1; then
    ok "claude is reachable under the allowlist PATH"
else
    bad "claude is NOT on the allowlist — every model case would fail without running the skill"
fi
# Discriminates: a binary deliberately left off must NOT be reachable, or the allowlist is not
# actually restricting anything and rule 2's whole point is lost.
if PATH="$bindir" command -v curl >/dev/null 2>&1; then
    bad "allowlist is not restricting — curl leaked through"
else
    ok "a binary not on the list is unreachable (the allowlist restricts)"
fi

if PATH="$bindir" gh 2>/dev/null | grep -q '"number"'; then
    ok "the gh stub is reachable and answers under the allowlist PATH"
else
    bad "the gh stub does not answer under the allowlist PATH"
fi

# THE CASE THAT WOULD HAVE CAUGHT THE STALE ALLOWLIST (measured 2026-10-30). The skills resolve the
# borg source dir with `command -v borg | xargs readlink -f | xargs dirname` and the link-up prepare
# step runs `borg checkpoint-prepare`, so `borg`, `zsh` (borg's interpreter), `xargs` and `readlink`
# must resolve under the allowlist PATH, and `borg` must land in THIS checkout, because
# `PYTHONPATH=<that dir>` is what imports the `borg_core` under test. A September allowlist had none of
# them: every live positive failed with "`borg` isn't on PATH" for a reason unrelated to the skills,
# and nothing noticed because CI runs this harness offline.
for need in borg zsh xargs readlink; do
    if PATH="$bindir" command -v "$need" >/dev/null 2>&1; then
        ok "$need is reachable under the allowlist PATH (a skill command needs it)"
    else
        bad "$need is NOT on the allowlist — a skill command that names it cannot run in the sandbox"
    fi
done
borg_real="$(PATH="$bindir" readlink -f "$bindir/borg" 2>/dev/null || true)"
if [ -n "$borg_real" ] && [ "$borg_real" = "$(readlink -f "$REPO/borg.zsh")" ]; then
    ok "the allowlist's borg resolves to this checkout's borg.zsh"
else
    bad "the allowlist's borg does not resolve to this checkout ($borg_real)"
fi

# THE `gh` STUB MUST SURVIVE THE READER THE SKILLS USE (measured 2026-10-30). run.sh embeds the stub as a
# heredoc; this extracts that exact text and feeds its answer to `borg checkpoint-prepare`'s own parser. A
# September stub answered `{"number":7}`, the parser (correctly) wants a pull-request URL, and /borg-link-up
# reported "no pull request for this branch" and wrote no row. A PAIR: the old shape must be REFUSED by the
# same parser, or the check would pass on a parser that accepts anything. Then the merge marker: a PR must
# read OPEN, and MERGED after `gh pr merge`, or /borg-assimilate cannot verify what it just did.
awk "/<<'GH'/{f=1;next} /^GH\$/{f=0} f" "$HERE/run.sh" > "$WORK/ghstub-run"
chmod +x "$WORK/ghstub-run"
mkdir -p "$WORK/ghstate" && cp "$WORK/ghstub-run" "$WORK/ghstate/gh"
stub_view="$("$WORK/ghstate/gh" pr view --json number,url 2>/dev/null)"
pr_ref() { PYTHONPATH="$REPO" "$PYTHON" -c 'import sys
from borg_core.checkpoint import prepare_shell as p
print(p._pr_from_json(sys.argv[1])[0])' "$1" 2>/dev/null; }
if [ "$(pr_ref "$stub_view")" = "o/r#7" ]; then
    ok "the gh stub's pr view parses to o/r#7 under checkpoint-prepare's reader"
else
    bad "the gh stub's pr view does not parse to o/r#7 ($stub_view)"
fi
if [ -z "$(pr_ref '{"number":7}')" ]; then
    ok "the reader refuses the old number-only shape (so the check above discriminates)"
else
    bad "the reader accepted a number-only answer; the stub check proves nothing"
fi

# THE WHOLE CHAIN, NOT ITS PARTS: the real `borg checkpoint-prepare`, run inside a feature-branch fixture
# under the sandbox PATH, must report the stubbed PR. Each piece above passed while this did not, because
# `borg.zsh` rebuilds PATH at startup and put the real `gh` first; `BORG_PATH_PREFIX` is what keeps the
# stub in front, and this is the case that fails if run.sh stops passing it or the stub stops parsing.
bindir_real="$(_eval_allowlist_bin "$WORK/bin-real" "$WORK/ghstub-run")"
prep="$(_eval_repo_with_source "$WORK/prep")"
_eval_feature_branch "$prep"
# The feature branch must really be PUSHED (to the local bare repo behind the github.com/o/r URL), and the
# remote URL must still be the one `gh` slug resolution reads. A silent `remote add` failure left it unpushed.
if [ -n "$(git -C "$prep" ls-remote origin feature/ci-gate 2>/dev/null)" ] \
    && [ "$(git -C "$prep" config --get remote.origin.url)" = "https://github.com/o/r.git" ]; then
    ok "the feature-branch fixture is pushed, and origin keeps the github.com/o/r URL"
else
    bad "the feature-branch fixture is not pushed (git ls-remote origin finds no feature/ci-gate)"
fi
prep_out="$(cd "$prep" && PATH="$bindir_real" BORG_PATH_PREFIX="$bindir_real" borg checkpoint-prepare 2>&1)"
if printf '%s\n' "$prep_out" | grep -q '^PR_REF: o/r#7 '; then
    ok "borg checkpoint-prepare inside the sandbox reports PR_REF o/r#7 (stub in front of the real gh)"
else
    bad "borg checkpoint-prepare did not report the stubbed PR: $(printf '%s\n' "$prep_out" | grep '^PR_REF')"
fi
# shellcheck disable=SC2016
# JUSTIFICATION: the single quotes keep `$BIN` LITERAL on purpose -- the text searched for is run.sh's own source line.
if grep -q 'BORG_PATH_PREFIX="\$BIN"' "$HERE/run.sh"; then
    ok "run.sh passes BORG_PATH_PREFIX to every skill run"
else
    bad "run.sh does not pass BORG_PATH_PREFIX; borg.zsh will put the real gh ahead of the stub"
fi
before_state="$("$WORK/ghstate/gh" pr view --json state 2>/dev/null | jq -r .state)"
"$WORK/ghstate/gh" pr merge 7 --squash >/dev/null 2>&1
after_state="$("$WORK/ghstate/gh" pr view --json state 2>/dev/null | jq -r .state)"
if [ "$before_state" = "OPEN" ] && [ "$after_state" = "MERGED" ]; then
    ok "the gh stub reads OPEN before gh pr merge and MERGED after"
else
    bad "the gh stub's state is $before_state then $after_state; expected OPEN then MERGED"
fi

echo "== floor: run.sh's own guards =="

# ── 5. --skip-model runs VERBS, skips all six model cases BY NAME, and exits 0 ───────────────────
#
# Counted on the `  SKIP  ` / `  PASS  ` case prefixes, never on a word that also appears in the
# RESULT line -- see case 7 for the measurement that made that rule.
if [ -x "$RUN" ]; then
    out="$("$RUN" --skip-model 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ]; then ok "--skip-model exits 0"; else bad "--skip-model exits $rc"; fi
    n_skip=$(printf '%s\n' "$out" | grep -cE '^  SKIP  .*--skip-model|^  SKIP  .*did not run')
    n_pass=$(printf '%s\n' "$out" | grep -cE '^  PASS  VERBS')
    if [ "$n_skip" -eq 6 ] && [ "$n_pass" -eq 1 ]; then
        ok "--skip-model: six model cases SKIP naming the flag, and VERBS executed"
    else
        bad "--skip-model: expected 6 SKIP / 1 VERBS PASS case lines, got $n_skip / $n_pass"
    fi
    if printf '%s\n' "$out" | grep -q 'nothing was verified'; then
        bad "--skip-model tripped the global floor — VERBS did not count as executed"
    else
        ok "--skip-model does not trip the global floor (VERBS counts as executed)"
    fi

    # ── 6. --skip-network is ACCEPTED and inert ─────────────────────────────────────────────────
    #
    # `make eval` globs evals/*/run.sh and passes EVAL_ARGS to every harness, so an unknown flag
    # exits 2 and turns the whole target red for a reason unrelated to this harness.
    "$RUN" --skip-network --skip-model >/dev/null 2>&1
    if [ $? -ne 2 ]; then
        ok "--skip-network is accepted (does not exit 2)"
    else
        bad "--skip-network exits 2 — make eval would go red on every harness"
    fi

    # ── 7. the model floor FIRES when the sweep is requested and claude is hidden ────────────────
    #
    # And the cases must SKIP rather than FAIL in that same run: an absent `claude` is a different
    # fact from a wrong one, and conflating them is exactly what the floor must not do.
    #
    # A DELIBERATELY CLAUDE-LESS DIR, not the allowlist. This case previously reused `$bindir` and
    # passed for the wrong reason: the allowlist did not contain `claude` at all, so "hidden" was
    # indistinguishable from "never there" — and that omission was the actual bug that made every
    # model case fail without running the skill. Hiding it now has to be done on purpose.
    nodir="$WORK/noclaude"
    mkdir -p "$nodir"
    for b in bash sh env git jq python3 sed grep awk cat printf date mkdir rm ls dirname basename tr wc sort head tail; do
        src=$(command -v "$b" 2>/dev/null) && ln -sf "$src" "$nodir/$b"
    done
    out="$(PATH="$nodir" "$RUN" 2>&1)"; rc=$?
    if [ "$rc" -ne 0 ]; then
        ok "model floor FIRES at rc $rc when claude is unavailable"
    else
        bad "model floor did not fire — a sweep of nothing exited 0"
    fi
    # THE MODEL FLOOR'S REASON AND NOT THE GLOBAL ONE'S. VERBS executes in this run, so a non-zero
    # exit here can only be the mode floor -- unless VERBS silently stopped counting, in which case
    # the global floor fires first and prints its own sentence. Refuting that sentence is what keeps
    # this case from passing on the wrong floor.
    if printf '%s\n' "$out" | grep -q 'the model sweep was requested but no model case executed'; then
        ok "the reason printed is the MODEL floor's"
    else
        bad "the model floor's reason is missing — a different floor (or none) produced the rc"
    fi
    if printf '%s\n' "$out" | grep -q 'nothing was verified'; then
        bad "the GLOBAL floor fired — VERBS did not execute under the claude-less PATH"
    else
        ok "and the global floor did not (VERBS still executed)"
    fi
    # ANCHORED ON A CASE LINE, not anywhere in the output. The first version grepped for `skip`
    # and the summary line itself says "N skipped" — so replacing every SKIP with a FAIL left the
    # check green. Fourth instance in this session of one root cause: matching a string that also
    # appears somewhere innocuous. Count the `  SKIP  ` case prefix and require the FAIL prefix to
    # be absent, which is the pair that actually discriminates.
    n_skip=$(printf '%s\n' "$out" | grep -cE '^  SKIP  ')
    n_fail=$(printf '%s\n' "$out" | grep -cE '^  FAIL  ')
    if [ "$n_skip" -eq 6 ] && [ "$n_fail" -eq 0 ]; then
        ok "all six cases SKIP and none FAILs when claude is absent"
    else
        bad "expected 6 SKIP / 0 FAIL case lines, got $n_skip / $n_fail — absent input read as a defect"
    fi

    # ── 8. EVAL_PLUGIN_DIR reaches the six model cases and not the probe ─────────────────────────
    #
    # Without it a live run after a skill change loads the INSTALLED plugin and grades the previous
    # release's bodies. A stub `claude` records its argv and answers the probe, so the six cases run
    # (and mostly FAIL, which is irrelevant here) and the log shows exactly which calls carried the
    # flag. A PAIR: the same run without the variable must carry it nowhere, or case 8a would pass
    # on a harness that always adds the flag.
    stubdir="$WORK/stubclaude"
    mkdir -p "$stubdir"
    # shellcheck disable=SC2016
    # JUSTIFICATION: the script body is written LITERALLY; `$*` and `$CLAUDE_ARGS_LOG` must expand when the STUB runs, not here.
    printf '#!/bin/sh\necho "$*" >> "$CLAUDE_ARGS_LOG"\ncase "$*" in *READY*) echo READY ;; esac\nexit 0\n' > "$stubdir/claude"
    chmod +x "$stubdir/claude"
    for b in bash sh env git jq python3 sed grep awk cat printf date mkdir rm ls dirname basename tr wc sort head tail; do
        src=$(command -v "$b" 2>/dev/null) && ln -sf "$src" "$stubdir/$b"
    done
    CLAUDE_ARGS_LOG="$WORK/args-with.log"; export CLAUDE_ARGS_LOG
    : > "$CLAUDE_ARGS_LOG"
    PATH="$stubdir:/usr/bin:/bin" EVAL_PLUGIN_DIR="/plugin/under/test" EVAL_MAX_BUDGET_USD=3 "$RUN" >/dev/null 2>&1
    n_calls=$(grep -c -- ' --model ' "$CLAUDE_ARGS_LOG")
    n_flag=$(grep -c -- '--plugin-dir /plugin/under/test' "$CLAUDE_ARGS_LOG")
    n_budget=$(grep -c -- '--max-budget-usd 3' "$CLAUDE_ARGS_LOG")
    n_probe=$(grep -- 'READY' "$CLAUDE_ARGS_LOG" | grep -c -- '--plugin-dir')
    # The allow-list is not optional: without it a headless case cannot run the skill's own commands.
    n_allow=$(grep -cF -- '--allowedTools Bash(PYTHONPATH=*)' "$CLAUDE_ARGS_LOG")
    if [ "$n_calls" -eq 7 ] && [ "$n_flag" -eq 6 ] && [ "$n_budget" -eq 6 ] && [ "$n_probe" -eq 0 ] && [ "$n_allow" -eq 6 ]; then
        ok "EVAL_PLUGIN_DIR, EVAL_MAX_BUDGET_USD and the tool allow-list reach all six model cases and not the probe"
    else
        bad "plugin-dir/budget/allow-list forwarding: expected 7 calls, 6 flagged, 6 budgeted, 0 on the probe, 6 allowed; got $n_calls/$n_flag/$n_budget/$n_probe/$n_allow"
    fi
    CLAUDE_ARGS_LOG="$WORK/args-without.log"; export CLAUDE_ARGS_LOG
    : > "$CLAUDE_ARGS_LOG"
    PATH="$stubdir:/usr/bin:/bin" "$RUN" >/dev/null 2>&1
    n_calls=$(grep -c -- ' --model ' "$CLAUDE_ARGS_LOG")
    n_flag=$(grep -c -- '--plugin-dir\|--max-budget-usd' "$CLAUDE_ARGS_LOG")
    if [ "$n_calls" -eq 7 ] && [ "$n_flag" -eq 0 ]; then
        ok "without the variables no call carries either flag (the pair that makes the case above discriminate)"
    else
        bad "unset variables: expected 7 calls and 0 flagged, got $n_calls/$n_flag"
    fi
else
    bad "run.sh is not executable — nothing below could be checked"
fi

echo
echo "floor: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
