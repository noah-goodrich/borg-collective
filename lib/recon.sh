#!/usr/bin/env sh
# shellcheck shell=bash  # lint as bash: sourced by both bash (tests) and zsh (borg CLI)
# lib/recon.sh — source-agnostic "recon fan-out" engine for borg.
#
# The reusable engine behind a "morning link-up": sweep activity across sources since a mark,
# normalize every finding into a common Item shape, reconcile against local .borg checkpoints,
# and emit one machine-readable reconciled document. The judgment/synthesis layer lives in the
# borg-recon skill; this file is the mechanical spine it drives.
#
# Design contract (Recon Contract v0):
#   1. Inputs: since (ISO ts), projects (from the registry), sources (subset of adapters).
#   2. Fan-out: one independent recon track per source, concurrent, bounded. Each adapter returns
#      a terse summary AND a normalized JSON array of Items. No raw dumps.
#   3. Item = {project, source, ref, title, state, changed, owner, action_needed, urgency, one_line}.
#   4. Reconcile: merge Items by project; detect + surface contradictions between a project's local
#      .borg checkpoint blockers and live source state.
#   5. Synthesis (by-project, two action lists, kickoff batch) is the skill's job — not here.
#
# Sourceable from both bash and zsh: $0 fallback covers zsh (no BASH_SOURCE). Uses only POSIX-ish
# constructs plus jq (already a hard borg dependency).

# ── Configuration ─────────────────────────────────────────────────────────────

# BORG_DIR resolution mirrors the rest of borg (XDG-first). Do not assume it is exported.
_recon_borg_dir() {
    printf '%s\n' "${BORG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/borg}"
}

# Directory that holds this lib, used to locate the shipped reference adapters.
_recon_lib_dir() {
    # ${BASH_SOURCE[0]} in bash, $0 in zsh when sourced.
    dirname "${BASH_SOURCE[0]:-$0}"
}

# Colon-separated search path for adapters. User-injected adapters (e.g. an employer layer on a work
# machine) live in the config dir and take precedence over the repo's shipped reference adapters,
# so a machine can override or extend the source set WITHOUT touching this repo.
_recon_adapter_path() {
    if [ -n "${BORG_RECON_ADAPTER_PATH:-}" ]; then
        printf '%s\n' "$BORG_RECON_ADAPTER_PATH"
        return 0
    fi
    printf '%s:%s\n' "$(_recon_borg_dir)/recon/adapters" "$(_recon_lib_dir)/recon/adapters"
}

# Max concurrent recon tracks (bounded termination — never rely on judgment to stop a fan-out).
_recon_max_tracks() {
    printf '%s\n' "${BORG_RECON_MAX_TRACKS:-8}"
}

# Per-adapter timeout in seconds. A slow or hung source must never wedge the whole sweep.
_recon_track_timeout() {
    printf '%s\n' "${BORG_RECON_TRACK_TIMEOUT:-30}"
}

# Run a command under a timeout when `timeout` exists; otherwise run it bare. Mirrors _borg_timeout.
_recon_timeout() {
    _secs="$1"; shift
    if command -v timeout >/dev/null 2>&1; then
        timeout "$_secs" "$@"
    else
        "$@"
    fi
}

# ── 1. Resolve `since` ──────────────────────────────────────────────────────────

# Convert an epoch seconds value to a UTC ISO 8601 timestamp.
_recon_epoch_to_iso() {
    _e="$1"
    date -u -r "$_e" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
        || date -u -d "@$_e" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null
}

# mtime (epoch seconds) of a file, portable across BSD (macOS) and GNU stat.
_recon_file_mtime() {
    # GNU first — see _borg_file_mtime in borg.zsh: GNU `stat -f` prints a filesystem block to
    # STDOUT before exiting 1, so a bsd||gnu chain concatenates garbage with the real answer.
    stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null
}

# Newest checkpoint mtime (epoch) across a whitespace/newline-separated list of project dirs.
# Echoes nothing when no checkpoints exist. Uses `find` (quoted -name) rather than a bare glob so
# it is safe when sourced into zsh, where an unmatched glob is a fatal NOMATCH error.
_recon_newest_checkpoint_epoch() {
    _newest=""
    for _dir in "$@"; do
        _cdir="$_dir/.borg/checkpoints"
        [ -d "$_cdir" ] || continue
        _max=$(find "$_cdir" -maxdepth 1 -type f -name '*.md' 2>/dev/null \
            | while IFS= read -r _cp; do _recon_file_mtime "$_cp"; done \
            | sort -rn | head -1)
        case "$_max" in ''|*[!0-9]*) continue ;; esac
        if [ -z "$_newest" ] || [ "$_max" -gt "$_newest" ]; then
            _newest="$_max"
        fi
    done
    [ -n "$_newest" ] && printf '%s\n' "$_newest"
}

# Resolve the `since` marker. Precedence:
#   1. explicit ISO ts (arg 1, if non-empty)
#   2. newest .borg checkpoint mtime across the given project dirs
#   3. the last-run marker written by a previous sweep
#   4. fallback: 24h ago
# Args: <explicit_since> [project_dir ...]
_recon_resolve_since() {
    _explicit="$1"; shift
    if [ -n "$_explicit" ]; then
        printf '%s\n' "$_explicit"
        return 0
    fi
    _epoch=$(_recon_newest_checkpoint_epoch "$@")
    if [ -n "$_epoch" ]; then
        _recon_epoch_to_iso "$_epoch"
        return 0
    fi
    _marker="$(_recon_borg_dir)/recon/last-run"
    if [ -f "$_marker" ]; then
        _val=$(head -1 "$_marker" 2>/dev/null | tr -d '[:space:]')
        [ -n "$_val" ] && { printf '%s\n' "$_val"; return 0; }
    fi
    _fallback=$(( $(date +%s) - 86400 ))
    _recon_epoch_to_iso "$_fallback"
}

# Persist the mark used by this sweep so the next sweep can default to it.
_recon_write_last_run() {
    _iso="$1"
    _dir="$(_recon_borg_dir)/recon"
    mkdir -p "$_dir" 2>/dev/null || return 0
    printf '%s\n' "$_iso" > "$_dir/last-run" 2>/dev/null || true
}

# ── 2. Adapter discovery ─────────────────────────────────────────────────────────

# Discover available source adapters. An adapter is any executable file named
# `recon-adapter-<source>` on the adapter search path. Emits one line per source:
#     <source>\t<absolute-adapter-path>
# Deduped by source name — the first hit on the path wins, so a user/config-dir adapter shadows
# a repo one of the same name. This is the ONLY registration mechanism: dropping an executable on
# the path adds a source. employer-specific adapters are injected this way, never hardcoded here.
_recon_discover_adapters() {
    _path=$(_recon_adapter_path)
    _oldifs="$IFS"; IFS=":"
    # shellcheck disable=SC2086
    set -- $_path
    IFS="$_oldifs"
    # Gather candidates from every search dir first (quoted -name → no shell glob → zsh-NOMATCH-safe),
    # then dedup in a single pass so first-on-path wins and state survives across dirs.
    _cands=""
    for _d in "$@"; do
        [ -d "$_d" ] || continue
        _found=$(find "$_d" -maxdepth 1 -type f -name 'recon-adapter-*' 2>/dev/null)
        [ -n "$_found" ] && _cands="$_cands$_found
"
    done
    printf '%s' "$_cands" | {
        _seen=" "
        while IFS= read -r _f; do
            [ -n "$_f" ] && [ -x "$_f" ] || continue
            _base=$(basename "$_f")
            _src=${_base#recon-adapter-}
            case "$_seen" in *" $_src "*) continue ;; esac
            _seen="$_seen$_src "
            printf '%s\t%s\n' "$_src" "$_f"
        done
    }
}

# ── 3. Fan-out ────────────────────────────────────────────────────────────────────

# Validate that an adapter's raw stdout is a well-formed track object:
#   {"source": string, "summary": string, "items": array}
# Returns 0 when valid.
_recon_validate_track() {
    printf '%s' "$1" | jq -e \
        '(.source|type=="string") and (.summary|type=="string") and (.items|type=="array")' \
        >/dev/null 2>&1
}

# Validate one Item against the v0 schema (required fields + enum constraints). Returns 0 when valid.
_recon_validate_item() {
    printf '%s' "$1" | jq -e '
        (.project|type=="string") and (.source|type=="string") and (.ref|type=="string")
        and (.title|type=="string") and (.state|type=="string") and (.changed|type=="string")
        and ((.owner=="you") or (.owner=="agent") or (.owner=="unknown"))
        and (.action_needed|type=="boolean")
        and ((.urgency=="now") or (.urgency=="this_week") or (.urgency=="fyi"))
        and (.one_line|type=="string")
    ' >/dev/null 2>&1
}

# Run a single adapter and normalize its output to a track object written to <outfile>.
# On any failure (non-zero exit, timeout, malformed output) writes a synthetic failed-track object
# so one bad source never aborts the sweep. Args: <source> <adapter_path> <since> <projects_file> <outfile>
_recon_run_adapter() {
    _src="$1"; _adapter="$2"; _since="$3"; _projects="$4"; _out="$5"
    _raw=$(_recon_timeout "$(_recon_track_timeout)" \
        "$_adapter" --since "$_since" --projects "$_projects" 2>/dev/null)
    _rc=$?
    if [ "$_rc" -ne 0 ] || [ -z "$_raw" ] || ! _recon_validate_track "$_raw"; then
        jq -n --arg s "$_src" --arg rc "$_rc" \
            '{source:$s, summary:("track failed (rc=" + $rc + ") or emitted malformed output"),
              items:[], ok:false}' > "$_out"
        return 0
    fi
    # Keep only schema-valid items; flag how many were dropped. Adapters should already comply,
    # but the engine is the last line of defense against a raw dump leaking through.
    printf '%s' "$_raw" | jq '
        def valid:
            (.project|type=="string") and (.source|type=="string") and (.ref|type=="string")
            and (.title|type=="string") and (.state|type=="string") and (.changed|type=="string")
            and ((.owner=="you") or (.owner=="agent") or (.owner=="unknown"))
            and (.action_needed|type=="boolean")
            and ((.urgency=="now") or (.urgency=="this_week") or (.urgency=="fyi"))
            and (.one_line|type=="string");
        .ok = true
        | .dropped = ([.items[] | select(valid | not)] | length)
        | .items = [.items[] | select(valid)]' > "$_out" 2>/dev/null \
        || jq -n --arg s "$_src" '{source:$s, summary:"post-processing failed", items:[], ok:false}' > "$_out"
}

# Fan out over the discovered/selected adapters concurrently, bounded by BORG_RECON_MAX_TRACKS.
# Args: <since> <projects_file> <outdir> then the adapter list as pairs: <source> <path> <source> <path>...
# Writes <outdir>/<source>.json per track. Blocks until every track completes.
_recon_fanout() {
    _since="$1"; _projects="$2"; _outdir="$3"; shift 3
    mkdir -p "$_outdir"
    _max=$(_recon_max_tracks)
    _running=0
    while [ "$#" -ge 2 ]; do
        _src="$1"; _adapter="$2"; shift 2
        _recon_run_adapter "$_src" "$_adapter" "$_since" "$_projects" "$_outdir/$_src.json" &
        _running=$((_running + 1))
        if [ "$_running" -ge "$_max" ]; then
            wait
            _running=0
        fi
    done
    wait
}

# ── 4. Reconcile ──────────────────────────────────────────────────────────────────

# Merge all track item arrays into a flat item array, then group by project.
# Args: one or more track JSON files. Echoes {"<project>": [Item,...], ...}.
_recon_merge_by_project() {
    jq -s '[.[].items[]] | group_by(.project)
           | map({key: .[0].project, value: .}) | from_entries' "$@" 2>/dev/null \
        || printf '{}\n'
}

# Extract the raw "## 4. Blockers" section text from a project's newest checkpoint.
# Echoes nothing when there is no checkpoint. Used to detect stale-blocker contradictions.
_recon_checkpoint_blockers() {
    _dir="$1"
    _cdir="$_dir/.borg/checkpoints"
    [ -d "$_cdir" ] || return 0
    # Checkpoint filenames are ISO-dated (YYYY-MM-DD-HHMM.md), so lexical sort == chronological;
    # tail -1 is the newest. find with a quoted -name avoids a zsh-fatal unmatched glob.
    _newest=$(find "$_cdir" -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort | tail -1)
    [ -n "$_newest" ] || return 0
    awk '/^## *4\.? *Blockers/{f=1;next} /^## /{f=0} f' "$_newest" 2>/dev/null
}

# Detect contradictions for ONE project: a live Item shows a resolved-ish state while the
# project's checkpoint still lists that ref as a blocker. This is the mechanical half of
# reconcile point 4 — the skill layer adds judgment on top. Args: <project> <blockers_text> <items_json>
# Echoes a JSON array of contradiction records (possibly empty).
_recon_project_contradictions() {
    _project="$1"; _blockers="$2"; _items="$3"
    [ -n "$_blockers" ] || { printf '[]\n'; return 0; }
    printf '%s' "$_items" | jq --arg b "$_blockers" --arg p "$_project" '
        [ .[]
          | . as $it
          | select($it.state | ascii_downcase | test("resolv|close|merg|done|fixed|shipped|complete"))
          | select(($it.ref | length) > 0)
          | select($b | contains($it.ref))
          | {project: $p, ref: $it.ref,
             checkpoint_says: "listed as a blocker in the latest checkpoint",
             source_says: ($it.state + " — " + $it.one_line),
             note: "checkpoint still calls this blocked, but the source shows it resolved — confirm and update"} ]
    ' 2>/dev/null || printf '[]\n'
}

# ── Assemble ────────────────────────────────────────────────────────────────────

# Build the final reconciled document from its parts.
# Args: <since> <sources_json_array> <items_by_project_json> <contradictions_json_array>
_recon_assemble() {
    _since="$1"; _sources="$2"; _byproj="$3"; _contra="$4"
    jq -n \
        --arg since "$_since" \
        --arg gen "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --argjson sources "$_sources" \
        --argjson byproj "$_byproj" \
        --argjson contra "$_contra" \
        '{since: $since, generated_at: $gen, sources: $sources,
          items_by_project: $byproj, contradictions: $contra}'
}

