"""Plan-state deriver and writer: parse acceptance criteria, resolve their evidence annotations to
`pass`/`fail`/`unknown`, and flip `- [ ]` -> `- [x]` for passes only.

W2 of docs/plans/directives/2026-09-10-link-up-writes-back-plan-state.md. `core.py` is PURE (it is on
pyproject.toml's clean-arch Domain list by basename); `shell.py` owns every filesystem, subprocess and
environment read; `cli.py` is the `--json` / `--apply` seam the `/borg-link-up` skill calls.
"""
