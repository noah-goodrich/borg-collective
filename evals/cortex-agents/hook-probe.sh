#!/usr/bin/env bash
# Hook probe recorder (S0 of #516). Register it for each Cortex event as: bash hook-probe.sh <EventName>, with PROBE_REC
# naming a scratch dir. Appends {event, payload, env_names} to $PROBE_REC/events.jsonl and answers with a per-event
# CANARY-<event>-7f3a additionalContext plus a SYSCANARY systemMessage. PROBE_GATES=1 adds blocking tests: prompt
# containing BLOCKME (exit 2), tool input containing blockA (exit 2) or blockB (deny JSON), first Stop (exit 2).
payload="$(cat)"
rec="${PROBE_REC:?set PROBE_REC to a scratch directory}"
event="$1"
envn="$(env | grep -E '^(CLAUDE_|CORTEX_)' | cut -d= -f1 | jq -R . | jq -sc .)"
jq -nc --arg e "$event" --arg p "$payload" --argjson env "$envn" \
    '{event: $e, payload: ($p | try fromjson catch $p), env_names: $env}' >> "$rec/events.jsonl"
if [ "${PROBE_GATES:-0}" = 1 ]; then
    case "$event" in
        UserPromptSubmit)
            if printf '%s' "$payload" | jq -e '.prompt | contains("BLOCKME")' >/dev/null; then
                echo "GATE-UPS-BLOCK" >&2; exit 2
            fi ;;
        PreToolUse)
            if printf '%s' "$payload" | jq -e '.tool_input | tostring | contains("blockA")' >/dev/null; then
                echo "GATE-PTU-EXIT2" >&2; exit 2
            fi
            if printf '%s' "$payload" | jq -e '.tool_input | tostring | contains("blockB")' >/dev/null; then
                jq -nc '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: "GATE-PTU-DENY-REASON"}}'
                exit 0
            fi ;;
        Stop)
            if [ ! -f "$rec/stop-blocked" ]; then
                : > "$rec/stop-blocked"; echo "GATE-STOP-BLOCK reply with the word STOPGATE" >&2; exit 2
            fi ;;
    esac
fi
jq -nc --arg e "$event" '{hookSpecificOutput: {hookEventName: $e, additionalContext: ("CANARY-" + $e + "-7f3a")}, systemMessage: ("SYSCANARY-" + $e + "-7f3a")}'
exit 0
