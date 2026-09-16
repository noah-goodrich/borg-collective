#!/usr/bin/env bats
# Every "Local Extensions" block in every skill and agent must agree with the precedence rule that
# borg_core/extensions/core.winner() actually implements.
#
# WHY THIS TEST EXISTS. The loading contract is prose, duplicated across 12 blocks in 5 files, with
# no include mechanism available for skill markdown. That means a contract change needs 12
# synchronized hand-edits and nothing catches a missed one -- which happened while writing this very
# change: two blocks with a differently-worded closing sentence were skipped by a prose-matching
# pass. The blocks also originally said only "later files extend or override earlier ones", the
# repo-wins rule, while core.winner() returns MACHINE for a prefer-tool file. A prefer-tool
# extension in a skill slot is not hypothetical -- it is the configuration this feature shipped
# with -- so the prose and the code disagreed about the live case.

ROOT="${BATS_TEST_DIRNAME}/.."

_blocks_with_paths() {
    grep -rlE '^2\. `<(project root|repo path)>/\.borg/(skill|agent)-extensions/' \
        "$ROOT/skills" "$ROOT/agents" 2>/dev/null | sort
}

@test "extensions: at least one file declares a Local Extensions block" {
    # Guards the guard: if the grep pattern ever stops matching, every case below would pass
    # vacuously on an empty file list.
    local n
    n=$(_blocks_with_paths | wc -l | tr -d ' ')
    [ "$n" -ge 4 ] || { echo "only $n files matched — the anchor pattern has drifted"; false; }
}

@test "extensions: every block states the prefer-tool precedence exception" {
    local f paths excs
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        paths=$(grep -cE '^2\. `<(project root|repo path)>/\.borg/(skill|agent)-extensions/' "$f")
        excs=$(grep -c 'Precedence has one exception' "$f" || true)
        [ "$paths" -eq "$excs" ] || {
            echo "$f: $paths extension block(s) but $excs precedence note(s)"; false; }
    done < <(_blocks_with_paths)
}

@test "extensions: every block points at the canonical reference" {
    local f paths refs
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        paths=$(grep -cE '^2\. `<(project root|repo path)>/\.borg/(skill|agent)-extensions/' "$f")
        refs=$(grep -c 'docs/extensions.md' "$f" || true)
        [ "$refs" -ge "$paths" ] || {
            echo "$f: $paths block(s) but only $refs pointer(s) at docs/extensions.md"; false; }
    done < <(_blocks_with_paths)
}

@test "extensions: the canonical reference agrees that machine wins for prefer-tool" {
    # The prose the blocks now carry is only correct if docs/extensions.md says the same thing.
    grep -q 'prefer-tool.*inverts it' "$ROOT/docs/extensions.md" \
        || grep -q 'the layer that owns the fact wins' "$ROOT/docs/extensions.md" \
        || { echo "docs/extensions.md no longer states the precedence rule"; false; }
}

@test "extensions: borg-review has NO 03-followup block" {
    # Its contract is to end on exactly one action; a post-recommendation hook invites a second.
    ! grep -q 'skill-extensions/borg-review/03-followup' "$ROOT/skills/borg-review/SKILL.md"
}

# ── The two oracles that were missing when #205 shipped ─────────────────────────────────────────

@test "skills: every SKILL.md starts with YAML frontmatter on line 1" {
    # Filed as BLOCKING on #205: an editing artifact put a stray prose line ABOVE borg-plan's `---`,
    # so the block stopped being frontmatter and the skill's name/description stopped being read.
    # Five CI lanes went green on it, because nothing asserted this. The mechanism was a Python
    # slice whose bounds were reversed (`t[66:4]` is ""), and `str.replace("", X, 1)` inserts at
    # position 0 — so the failure mode is specifically "content prepended to the file", which is
    # exactly what line 1 catches.
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

@test "step075: the gate still tells the model to STOP when children are found" {
    # The other BLOCKING finding on #205. The slug fix replaced all of Step 0.75 and deleted the
    # `✗ Blocked` output format and the "Do NOT proceed" sentence along with it — leaving a step
    # that computed the right answer (nine directives) and then shipped anyway. A gate that
    # measures correctly and does not act is the same defect as one that acts on a wrong
    # measurement; this pins the ACTION, which no test covered before.
    local step
    step=$(sed -n '/^## Step 0.75/,/^## Step 1/p' "$ROOT/skills/borg-assimilate/SKILL.md")
    [[ "$step" == *"✗ Blocked"* ]] || { echo "no blocked-output format in Step 0.75"; false; }
    [[ "$step" == *"Do NOT proceed to criteria evaluation or shipping"* ]] || {
        echo "Step 0.75 no longer instructs the model to stop"; false; }
    # And the discriminating half: it must still say what to do when there is nothing to find,
    # or a reader cannot tell "blocked" from "checked and clear".
    [[ "$step" == *"proceed to Step 1 without comment"* ]] || {
        echo "Step 0.75 does not say what happens on the clean path"; false; }
}
