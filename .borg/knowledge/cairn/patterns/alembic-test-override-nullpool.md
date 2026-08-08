---
id: alembic-test-override-nullpool
project: cairn
domain: testing
tags:
- alembic
- sqlalchemy
- testing
- nullpool
- integration-tests
preconditions: []
steps:
- In alembic/env.py, check for config.get_main_option('sqlalchemy.url') override before
  calling get_engine()
- 'When a test URL override is present, create a fresh engine with NullPool: create_engine(test_url,
  poolclass=NullPool)'
- In tests, call config.set_main_option('sqlalchemy.url', TEST_DB_URL) before running
  upgrade/downgrade
- In test teardown, always run alembic downgrade base to return DB to empty state
pitfalls:
- Without NullPool, connection pooling can hold open connections that block DROP TABLE
  or other exclusive-lock DDL during downgrade
- lru_cache on get_engine() will return the production engine if the override is not
  checked first in env.py
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.698173+00:00'
updated_at: '2026-06-11 23:12:50.698173+00:00'
---

# alembic-test-override-nullpool

## description

Configure Alembic's env.py so integration tests can inject a test database URL and NullPool without touching the lru_cache-backed production engine
