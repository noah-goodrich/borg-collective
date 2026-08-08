---
id: 20260418-self-heal-install
date: '2026-06-16'
project: borg-collective
domain: infrastructure
tags:
- ssh-agent
- idempotency
- install.sh
- self-healing
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.167653+00:00'
updated_at: '2026-06-16 10:27:02.167654+00:00'
---

# 20260418-self-heal-install

## decision

Add heal_ssh_agent_dir() to install.sh to fix permissions and strip grpcfuse xattr on every re-run

## context

The grpcfuse xattr corruption can recur any time Docker Desktop updates or re-mounts; a one-time fix would require manual intervention on recurrence

## reasoning

install.sh is already idempotent and re-run periodically. Adding the heal function there means the fix is automatically reapplied without a separate recovery runbook. Cost is negligible (two chmod/xattr calls).
