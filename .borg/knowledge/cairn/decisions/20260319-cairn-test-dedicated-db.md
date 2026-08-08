---
id: 20260319-cairn-test-dedicated-db
date: '2026-06-11'
project: cairn
domain: testing
tags:
- alembic
- postgresql
- testing
- integration-tests
- isolation
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 23:12:50.696582+00:00'
updated_at: '2026-06-11 23:12:50.696582+00:00'
---

# 20260319-cairn-test-dedicated-db

## decision

Use a dedicated cairn_test database for migration integration tests; tests always run downgrade base before and after each run

## context

Migration integration tests (upgrade/downgrade cycles) need a real Postgres database but must not touch the production cairn DB

## reasoning

Complete isolation from production data; downgrade-before-and-after ensures tests start from a known clean state regardless of previous test run outcome
