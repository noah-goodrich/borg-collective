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
