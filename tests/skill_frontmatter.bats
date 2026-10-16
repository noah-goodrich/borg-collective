#!/usr/bin/env bats
# Two oracles that were missing when the Step 0.75 slug fix was first written, each pinning a
# defect that five green CI lanes did not see.

ROOT="${BATS_TEST_DIRNAME}/.."

@test "skills: every SKILL.md starts with YAML frontmatter on line 1" {
    # An editing artifact put a stray prose line ABOVE borg-plan's `---`, so the block stopped being
    # frontmatter and the skill's name/description stopped being read. The mechanism was a Python
    # slice with reversed bounds — `t[66:4]` is "" — and `str.replace("", X, 1)` INSERTS AT POSITION
    # 0, turning a replace into a prepend. So the failure mode is "content prepended to the file",
    # which is exactly what line 1 catches, for every skill rather than just the one that broke.
    local f bad=0
    for f in "$ROOT"/skills/*/SKILL.md; do
        [ -f "$f" ] || continue
        if [ "$(head -1 "$f")" != "---" ]; then
            echo "not frontmatter-first: $f -> $(head -1 "$f")"
            bad=1
        fi
    done
    [ "$bad" -eq 0 ]
}

@test "skills: the frontmatter check is looking at a non-empty set" {
    # Guards the guard: if the glob ever stops matching, the case above passes vacuously.
    local n
    n=$(find "$ROOT/skills" -maxdepth 2 -name SKILL.md -type f | wc -l | tr -d ' ')
    [ "$n" -ge 10 ] || { echo "only $n SKILL.md found — the glob has drifted"; false; }
}

@test "step075: the gate tells the model to STOP when children are found" {
    # A gate that measures correctly and does not act is the same defect as one that acts on a wrong
    # measurement. This pins the ACTION; the helper's tests pin the measurement.
    local step
    step=$(sed -n '/^## Step 0.75/,/^## Step 1/p' "$ROOT/skills/borg-assimilate/SKILL.md")
    [[ "$step" == *"✗ Blocked"* ]] || { echo "no blocked-output format in Step 0.75"; false; }
    [[ "$step" == *"Do NOT proceed to criteria evaluation or shipping"* ]] || {
        echo "Step 0.75 no longer instructs the model to stop"; false; }
    [[ "$step" == *"proceed to Step 1 without comment"* ]] || {
        echo "Step 0.75 does not say what happens on the clean path"; false; }
}

# The skill listing loads every description at session start, whether or not the skill runs, so a description is a
# standing cost. 320 characters is about 80 tokens. The description is also what triggers the skill, so the cap
# bounds detail and the trigger-phrase cases below pin what must survive the trimming.
DESCRIPTION_CAP=320

# The description as one line: the folded block (or single line) with its indentation collapsed.
_description_of() {
    awk '
        NR == 1 { next }
        /^---$/ { exit }
        /^description:/ { sub(/^description:[ \t]*>?[ \t]*/, ""); d = $0; grab = 1; next }
        grab && /^[ \t]/ { d = d " " $0; next }
        { grab = 0 }
        END { gsub(/[ \t]+/, " ", d); sub(/^ /, "", d); sub(/ $/, "", d); printf "%s", d }
    ' "$1"
}

@test "skills: every description stays under the 320-character cap" {
    local f d bad=0 n=0
    for f in "$ROOT"/skills/*/SKILL.md; do
        d=$(_description_of "$f")
        n=$((n + 1))
        if [ "${#d}" -gt "$DESCRIPTION_CAP" ]; then
            echo "${f#"$ROOT"/}: description is ${#d} characters, over the ${DESCRIPTION_CAP} cap"
            bad=1
        fi
    done
    [ "$n" -ge 10 ] || { echo "only $n skills measured"; false; }
    [ "$bad" -eq 0 ]
}

@test "skills: the trimmed descriptions keep the phrases users type" {
    [[ "$(_description_of "$ROOT/skills/borg-recon/SKILL.md")" == *"morning link-up"*"catch me up"*"recon"* ]]
    [[ "$(_description_of "$ROOT/skills/borg-link/SKILL.md")" == *"status"*"overview"*"briefing"* ]]
    [[ "$(_description_of "$ROOT/skills/fable-reviewer/SKILL.md")" == *"/fable-reviewer"*"apply the gates"*"fable mode"* ]]
    [[ "$(_description_of "$ROOT/skills/borg-resume/SKILL.md")" == *"session limit"*"usage limit"*"resume after reset"* ]]
    [[ "$(_description_of "$ROOT/skills/borg-link-up/SKILL.md")" == *"Link up"*"ending a session"* ]]
}

@test "skills: no borg skill reuses the name of a built-in skill" {
    # `borg-collective:simplify` duplicated the built-in `simplify`, so both loaded and both matched one request.
    [ ! -e "$ROOT/skills/simplify" ]
}
