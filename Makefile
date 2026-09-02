.PHONY: clean test lint format test-viz lint-viz format-viz spine eval eval-live

# TWO Python surfaces, deliberately separate — do not merge them.
#
#   test / lint / format          -> borg_core/   (python-core-and-toolchain, Part 3)
#   test-viz / lint-viz / format-viz -> merge-tree/ (the viz/infoviz program)
#
# The split is intentional: borg_core/ is the CLI core being migrated from zsh and is held to a 90%
# coverage floor and clean-architecture enforcement; merge-tree/ is the infoviz renderer program with
# a different shape (no layered domain/usecase split to enforce) and its own coverage reality.
#
# But "out of scope" had turned into "ungated". merge-tree/ carried 124 passing tests written by the
# directive's Part 2 -- curate.py at 99%, render_graph.py at 88% -- and `testpaths = ["borg_core"]`
# meant pytest never collected them, so no gate ran them and nothing would have caught a regression.
# These targets close that without dragging merge-tree into borg_core's rules.
#
# borg_core/ doesn't exist until Part 3's first commit -- test/lint no-op gracefully (not a failure)
# until then, same as pytest legitimately collecting zero tests.

clean:
	rm -rf dist/
	rm -rf build/
	rm -rf *.egg-info
	find . -name "__pycache__" -type d -exec rm -rf {} +
	find . -name "*.pyc" -delete
	rm -f .coverage
	rm -f coverage.xml

test:
	@if [ -d borg_core ]; then \
		set -e; \
		coverage run -m pytest || test $$? -eq 5; \
		coverage report -m --fail-under=90; \
	else \
		echo "borg_core/ does not exist yet (Part 3 not started) -- nothing to test"; \
	fi

lint:
	@if [ -d borg_core ]; then \
		set -e; \
		ruff check borg_core/; \
		mypy borg_core/; \
		if python3 -c "import clean_architecture_linter" > /dev/null 2>&1; then \
			pylint --load-plugins=clean_architecture_linter borg_core/; \
		else \
			echo "pylint-clean-architecture not installed; falling back to plain pylint"; \
			pylint borg_core/; \
		fi; \
	else \
		echo "borg_core/ does not exist yet (Part 3 not started) -- nothing to lint"; \
	fi

format:
	@if [ -d borg_core ]; then \
		ruff format borg_core/; \
	else \
		echo "borg_core/ does not exist yet (Part 3 not started) -- nothing to format"; \
	fi

# ── viz/infoviz program (merge-tree/) ────────────────────────────────────────────────────────────
# Separate coverage floor from borg_core's 90%: render.py is the LEGACY renderer that viz-1 slates
# for deletion once REVIEW_BUCKET is ported out of it, so it sits at 0% by design and would drag any
# whole-tree number down. The floor is therefore set on the modules that are actually live.

test-viz:
	@if [ -d merge-tree ]; then \
		set -e; \
		coverage run --source=merge-tree -m pytest merge-tree/ || test $$? -eq 5; \
		coverage report -m --include='merge-tree/curate.py,merge-tree/render_graph.py,merge-tree/spine.py,merge-tree/gather.py,merge-tree/programs.py,merge-tree/coordinator.py' --fail-under=85; \
	else \
		echo "merge-tree/ not present -- nothing to test"; \
	fi

lint-viz:
	@if [ -d merge-tree ]; then \
		set -e; \
		ruff check merge-tree/; \
	else \
		echo "merge-tree/ not present -- nothing to lint"; \
	fi

format-viz:
	@if [ -d merge-tree ]; then \
		ruff format merge-tree/; \
	else \
		echo "merge-tree/ not present -- nothing to format"; \
	fi

# ── S6 (viz-2): the one documented command that refreshes the spine end to end ───────────────────
# Regenerates story.json's skeleton from the latest gather while preserving judgment from the
# overlay. Safe to run at any time: the skeleton always wins on structure, the overlay always wins
# on prose, and anything unjudged is reported rather than silently rendered blank.
spine:
	python3 merge-tree/spine.py

# ── AC6: the eval harness ────────────────────────────────────────────────────────────────────────
# `make eval` IS THE SAFE ONE. It forwards --skip-model, so it runs only the cases that need no
# headless model run. The full sweep, which spends money and needs an authenticated `gh`, is opt-in
# as `make eval-live`. That way round is deliberate: the target a CI clause names must not be the
# one that reaches the network, or CI acquires a network dependency by default and the offline
# guarantee becomes a matter of remembering a flag.
#
# AC6's verify clause named `make eval --skip-model`, which exits 2 whatever this file contains:
# make's getopt consumes any leading-dash word anywhere in argv before a goal is built, so the word
# never reaches a recipe. A make VARIABLE is the only form that does. EVAL_ARGS stays as the
# extension point because each harness takes its own flags.
#
# The loop AGGREGATES rather than aborting. Every harness runs, failures are recorded, and the
# target exits non-zero at the end -- `set -e` would report only the first failing harness, which
# is the same argument that keeps run.sh on PASS/FAIL counters instead of `set -e`.
#
# `found`, not `[ -d evals ]`: the guard has to be on the GLOB. With no nullglob, a directory that
# exists but holds no run.sh passes a directory test and then hands the literal pattern to bash.
EVAL_ARGS ?= --skip-model

eval:
	@failed=0; found=0; \
	for r in evals/*/run.sh; do \
		[ -e "$$r" ] || continue; \
		found=1; \
		echo "== $$r $(EVAL_ARGS)"; \
		bash "$$r" $(EVAL_ARGS) || failed=1; \
	done; \
	if [ "$$found" -eq 0 ]; then echo "no evals/*/run.sh present -- nothing to eval"; fi; \
	test "$$failed" -eq 0

eval-live:
	@$(MAKE) --no-print-directory eval EVAL_ARGS=
