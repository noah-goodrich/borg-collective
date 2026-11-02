# Keep .borg/state.json out of git in a registered repository, without a redundant line.
# Git decides, so a broader rule (.borg/*) or a .borg/ rule with a !.borg/checkpoints/ carve-out counts as ignored.
# Only when git cannot answer (rc 128, e.g. a non-git directory) does the literal grep decide, as it always did.
# Returns 0 when it appended a line, 1 when nothing was needed.
_borg_ensure_state_gitignored() {
    local dir="$1" gi="$1/.gitignore" rc=0
    git -C "$dir" check-ignore -q .borg/state.json 2>/dev/null || rc=$?
    case $rc in
        0) return 1 ;;
        1) ;;
        *) grep -qF ".borg/state.json" "$gi" 2>/dev/null && return 1 ;;
    esac
    echo ".borg/state.json" >> "$gi"
    return 0
}
