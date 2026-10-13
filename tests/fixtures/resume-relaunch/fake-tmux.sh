#!/usr/bin/env bash
# Fake tmux for tests/resume_relaunch.bats. State lives in $FT (pane table, captures, call log). The scenario in
# $FT/scenario decides what a freshly started "claude" shows: clean | size | trust | perm | unknown | forked.
# It also plays the SessionStart hook: it appends a session_start event and re-binds @borg_sid.
FT="${FT:?}"
FIX="${FIXDIR:?}"
panes="$FT/panes"
touch "$panes"
FORK="ffffffff-0000-4000-8000-000000000001"
log() { printf '%s\n' "$*" >>"$FT/calls.log"; }
subst() { # <fmt> <id> <bound> <pid> <cmd>
    local f="$1"
    f="${f//#\{pane_id\}/$2}"
    f="${f//#\{@borg_sid\}/$3}"
    f="${f//#\{pane_pid\}/$4}"
    f="${f//#\{pane_current_command\}/$5}"
    f="${f//#\{pane_in_mode\}/0}"
    f="${f//#\{pane_dead\}/0}"
    f="${f//#\{pane_synchronized\}/0}"
    f="${f//#\{session_name\}/s}"
    printf '%s\n' "$f"
}
setp() { # <id> <field 2|3|4> <value>
    local id="$1" k="$2" v="$3" a b c d
    while IFS="|" read -r a b c d; do
        if [ "$a" = "$id" ]; then
            case "$k" in 2) b="$v" ;; 3) c="$v" ;; 4) d="$v" ;; esac
        fi
        printf '%s|%s|%s|%s\n' "$a" "$b" "$c" "$d"
    done <"$panes" >"$panes.n"
    mv "$panes.n" "$panes"
}
event() { # <sid>
    printf '{"t":%s,"ev":"session_start","sid":"%s","reason":"resume"}\n' \
        "${BORG_RESUME_NOW_EPOCH:-0}" "$1" >>"$BORG_RESUME_DIR/events/$1.jsonl"
}
started() { # <pane id>: claude is up; show what the scenario says
    local id="$1" sid
    sid="$(cat "$FT/want_sid" 2>/dev/null)"
    setp "$id" 4 claude
    case "$(cat "$FT/scenario")" in
        clean)
            cp "$FIX/idle.txt" "$FT/cap.$id"
            setp "$id" 2 "$sid"
            event "$sid"
            ;;
        size)
            cp "$FIX/resume_size.txt" "$FT/cap.$id"
            echo size >"$FT/state.$id"
            ;;
        trust) printf 'Do you trust this folder?\n Enter to confirm · Esc to cancel\n' >"$FT/cap.$id" ;;
        perm) printf 'Do you want to proceed?\n ❯ 1. Yes\n   2. No\n Esc to cancel\n' >"$FT/cap.$id" ;;
        unknown) cp "$FIX/unknown.txt" "$FT/cap.$id" ;;
        forked)
            cp "$FIX/idle.txt" "$FT/cap.$id"
            setp "$id" 2 "$FORK"
            event "$FORK"
            ;;
    esac
}
cmd="$1"
shift
case "$cmd" in
    list-panes)
        [ -e "$FT/down" ] && exit 1
        fmt=""
        while [ $# -gt 0 ]; do
            [ "$1" = "-F" ] && fmt="$2"
            shift
        done
        while IFS="|" read -r a b c d; do
            [ -n "$a" ] && subst "$fmt" "$a" "$b" "$c" "$d"
        done <"$panes"
        ;;
    has-session)
        [ -e "$FT/down" ] && exit 1
        [ -e "$FT/nosession" ] && exit 1
        ;;
    list-clients) ;;
    new-window | new-session)
        log "$cmd $*"
        for a in "$@"; do log "ARG[$a]"; done
        n=$(($(wc -l <"$panes") + 9))
        id="%$n"
        printf '%s||%s|%s\n' "$id" "$$" "zsh" >>"$panes"
        rm -f "$FT/down"
        started "$id"
        echo "$id"
        ;;
    capture-pane)
        t=""
        while [ $# -gt 0 ]; do
            [ "$1" = "-t" ] && t="$2"
            shift
        done
        cat "$FT/cap.$t" 2>/dev/null
        ;;
    set-option)
        log "set-option $*"
        setp "$3" 2 "$5" 2>/dev/null
        ;;
    send-keys)
        log "send-keys $*"
        t="$2"
        shift 2
        lit=0
        if [ "$1" = "-l" ]; then
            lit=1
            shift
        fi
        key="$1"
        if [ "$lit" = 1 ]; then
            case "$key" in
                cd\ *)
                    printf '%s\n' "$ $key" >>"$FT/cap.$t"
                    echo "$key" >"$FT/typed.$t"
                    ;;
                *) echo "$key" >"$FT/picked.$t" ;;
            esac
        elif [ "$key" = Enter ]; then
            if [ -e "$FT/typed.$t" ]; then
                rm -f "$FT/typed.$t"
                started "$t"
            elif [ "$(cat "$FT/state.$t" 2>/dev/null)" = size ]; then
                sid="$(cat "$FT/want_sid")"
                cp "$FIX/idle.txt" "$FT/cap.$t"
                if [ "$(cat "$FT/picked.$t" 2>/dev/null)" = 2 ]; then
                    setp "$t" 2 "$sid"
                    event "$sid"
                else
                    setp "$t" 2 "$FORK"
                    event "$FORK"
                fi
                rm -f "$FT/state.$t"
            fi
        fi
        ;;
esac
exit 0
