#!/usr/bin/env zsh
# lib/desktop.zsh — Claude Desktop session reader
#
# Claude Desktop conversations are server-side. Integration relies on a
# Claude Desktop Project with instructions to write session reports to
# ~/.config/borg/desktop/{topic-slug}.json

BORG_DESKTOP_DIR="$BORG_DIR/desktop"

borg_desktop_init() {
    /bin/mkdir -p "$BORG_DESKTOP_DIR"
}

# Read all Desktop session reports and merge into registry
# Desktop entries get source=desktop, tmux fields=null
borg_desktop_scan() {
    borg_desktop_init
    local f name data
    for f in "$BORG_DESKTOP_DIR"/*.json(N); do
        [[ -f "$f" ]] || continue
        name=$(basename "$f" .json)
        data=$(cat "$f" 2>/dev/null) || continue

        local topic proj_status summary next_steps last_activity
        topic=$(echo "$data" | jq -r '.topic // ""')
        proj_status=$(echo "$data" | jq -r '.status // "idle"')
        summary=$(echo "$data" | jq -r '.summary // ""')
        next_steps=$(echo "$data" | jq -r '.next_steps // ""')
        last_activity=$(echo "$data" | jq -r '.last_activity // ""')

        # Use topic as the display name if available, else filename
        local project="${topic:-$name}"
        # Slugify for registry key
        local key="${name}"

        local json
        json=$(jq -n \
            --arg path "null" \
            --arg source "desktop" \
            --arg status "$proj_status" \
            --arg summary "$([ -n "$next_steps" ] && echo "$summary Next: $next_steps" || echo "$summary")" \
            --arg last_activity "$last_activity" \
            --arg display_name "$project" \
            '{
                path: null,
                source: $source,
                tmux_session: null,
                tmux_window: null,
                claude_session_id: null,
                last_activity: (if $last_activity != "" then $last_activity else null end),
                status: $status,
                summary: (if $summary != "" then $summary else null end),
                display_name: $display_name
            }')

        borg_registry_merge "$key" "$json"
    done
}

borg_desktop_report_path() {
    local slug="$1"
    echo "$BORG_DESKTOP_DIR/${slug}.json"
}
