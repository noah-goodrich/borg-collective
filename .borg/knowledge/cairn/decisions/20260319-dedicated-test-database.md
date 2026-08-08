---
id: 20260319-dedicated-test-database
date: '2026-06-11'
project: cairn
domain: testing
tags:
- alembic
- postgres
- integration-testing
- database
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 20:31:17.983213+00:00'
updated_at: '2026-06-11 20:31:17.983213+00:00'
---

# 20260319-dedicated-test-database

## decision

Use a dedicated cairn_test database for migration integration tests, always running downgrade base before and after

## context

Migration tests need to run upgrade/downgrade cycles destructively without touching production data

## reasoning

Isolates destructive DDL operations; prevents test pollution of the production cairn DB; downgrade before+after ensures a clean slate for repeatable runs
