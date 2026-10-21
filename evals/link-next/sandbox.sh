#!/usr/bin/env bash
# Build the throwaway plugin that `claude plugin eval` runs one case against.
#
#   usage: sandbox.sh <case> <out-dir>
#
# The runner takes a PLUGIN directory (Phase 0 of 2026-10-03-evals-for-everything), and this repository is not
# one, so the sandbox is: .claude-plugin/plugin.json + a COPY of the one skill the case grades + the case itself
# under evals/<case>/. The run is hermetic (fresh HOME, empty cwd), so a stub `borg` cannot reach PATH before the
# skill's load-time injection; the sandbox copy therefore swaps ONE span of the skill for the fixture, and nothing
# else, which is the fallback the directive's B3 names:
#
#   borg-link  the single injected-command line between the PAGE markers becomes the fixture page.
#   borg-next  it has no injection line; its one sentence "Run `borg next --rows --json` with the Bash tool (it
#              logs nothing). It prints" becomes "The command already ran and printed ... That is". Everything
#              after it, including the rule that the reply never says "declined", is untouched.
#
# The swap is a literal match that must hit EXACTLY ONCE. If the skill text drifts so the span is gone (or
# doubles), this exits 1 instead of grading a skill that no longer matches the fixture; the offline harness
# (run.sh) builds every sandbox on every run, so that drift is caught in CI and never reaches a model.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${BORG_EVAL_REPO:-$(cd "$HERE/../.." && pwd)}"
CASE="${1:?usage: sandbox.sh <case> <out-dir>}"
OUT="${2:?usage: sandbox.sh <case> <out-dir>}"
CASEDIR="$HERE/cases/$CASE"

[ -f "$CASEDIR/sandbox.conf" ] || { echo "no such case: $CASE" >&2; exit 2; }
skill="$(sed -n 's/^skill=//p' "$CASEDIR/sandbox.conf")"
fixture="$HERE/$(sed -n 's/^fixture=//p' "$CASEDIR/sandbox.conf")"
[ -n "$skill" ] && [ -f "$fixture" ] && [ -f "$REPO/skills/$skill/SKILL.md" ] || {
    echo "bad sandbox.conf for $CASE (skill '$skill', fixture '$fixture')" >&2
    exit 2
}

mkdir -p "$OUT/.claude-plugin" "$OUT/skills" "$OUT/evals"
printf '{"name":"borg-eval","version":"0.0.0","description":"throwaway sandbox for evals/link-next"}\n' \
    > "$OUT/.claude-plugin/plugin.json"
cp -R "$REPO/skills/$skill" "$OUT/skills/$skill"
cp -R "$CASEDIR" "$OUT/evals/$CASE"
rm -f "$OUT/evals/$CASE/sandbox.conf"

src="$REPO/skills/$skill/SKILL.md"
dst="$OUT/skills/$skill/SKILL.md"
case "$skill" in
    borg-link)
        awk -v fx="$fixture" '
            /^!`NO_COLOR=1 borg link / { hits++; while ((getline l < fx) > 0) print l; close(fx); next }
            { print }
            END { if (hits != 1) { print "injection line matched " hits+0 " times, want 1" > "/dev/stderr"; exit 1 } }
        ' "$src" > "$dst"
        ;;
    borg-next)
        awk -v fx="$fixture" '
            BEGIN { old = "Run `borg next --rows --json` with the Bash tool (it logs nothing). It prints"
                    getline json < fx; close(fx) }
            { i = index($0, old)
              if (i) { hits++
                       $0 = substr($0, 1, i - 1) "The command `borg next --rows --json` already ran and printed:\n\n" json \
                            "\n\nThat is" substr($0, i + length(old)) }
              print }
            END { if (hits != 1) { print "command sentence matched " hits+0 " times, want 1" > "/dev/stderr"; exit 1 } }
        ' "$src" > "$dst"
        ;;
    *)
        echo "no swap defined for skill '$skill'" >&2
        exit 2
        ;;
esac
