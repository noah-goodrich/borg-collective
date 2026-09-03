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
# `make eval` IS THE SAFE ONE, AND SAFE NOW MEANS OFFLINE RATHER THAN MERELY MODEL-FREE. It forwards
# both --skip-model and --skip-network, so it runs only the cases that need neither a headless model
# run nor the wire. The full sweep, which spends money and needs an authenticated `gh`, is opt-in as
# `make eval-live`, which clears EVAL_ARGS as it always did. That way round is deliberate: the
# target a CI clause names must not be the one that reaches the network, or CI acquires a network
# dependency by default and the offline guarantee becomes a matter of remembering a flag.
#
# --skip-network IS THE HALF THAT WAS MISSING, and its absence made the sentence above false of the
# very target it describes. --skip-model alone still left E2 shelling one `gh pr view` per declared
# ref and E3 fanning `borg recon` over the github adapter, so with `gh` authenticated and the wire
# down `make eval` exited non-zero and named three manifest rows as unresolved — a transport failure
# reported as a data defect, which is the conflation E2's own comment forbids for the 401 case. The
# safe/live split is therefore offline-vs-everything; "model-free" was never the property the CI
# clause needed.
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
#
# THE SELECTION FLOOR: `found` at 0 is a FAILURE, not a no-op. This recipe used to print "nothing to
# eval" and then run `test "$failed" -eq 0`, so a tree where the glob selected no harness reported
# exactly the shape of a tree whose every harness ran and found nothing wrong. That is the recorded
# reason AC6's "deterministic cases green in CI" sat at zero members across three checkpoints with
# nobody noticing -- there is no reading of green that means "selected nothing", and a target whose
# entire job is to run the harnesses has failed at that job when it runs none. The reason goes to
# STDERR, where whoever is reading a red gate's log will find it, and it sets `failed` rather than
# exiting, so the aggregate-don't-abort design above governs this failure like any other. The other
# floor -- a harness that WAS selected, ran, and executed no case -- deliberately is not here:
# run.sh owns it, on the usual principle that the artifact implementing a command owns its
# invariant.
#
# EVAL_ARGS IS VALIDATED BEFORE IT IS FORWARDED, because a documented extension point must not also
# be a channel for a green run that ran nothing. Two rejections, both word-by-word over the value.
# ("Forwarded", not "spliced": splicing is precisely what this recipe stopped doing, for the reason
# the environment paragraph below gives.)
#
# `-h` and `--help` AS WHOLE WORDS. The harness's own flag loop honours them: it prints usage and
# exits 0 before a single counter increments or any execution floor runs, so `make eval
# EVAL_ARGS=--help` reported SUCCESS for a run that verified nothing -- the same fact the selection
# floor below exists to catch, arriving through the front door instead of through an empty glob.
# Matched as whole words and never as a substring, or a future `--with-hooks` would be refused for
# containing an `h` sequence nobody meant to type.
#
# ANY WORD CONTAINING A SHELL METACHARACTER. Unquoted word splitting is how one variable carries
# several flags, so the expansion cannot simply be quoted -- that would make EVAL_ARGS a single
# argument and break the multi-flag default above. A `;` in the value therefore used to terminate
# `bash "$r" ...` and detach the harness's exit status from `|| failed=1`, leaving `failed` a report
# on whatever ran last.
#
# THE VALUE REACHES THE RECIPE THROUGH THE ENVIRONMENT (`export EVAL_ARGS`, read as `$$EVAL_ARGS`)
# AND NOT AS SPLICED RECIPE TEXT, which is what makes the check above reachable at all. With
# `$(EVAL_ARGS)` written into the recipe, make substitutes before /bin/sh parses, so a value holding
# a `;` broke the VALIDATOR'S OWN `for` statement: `make eval EVAL_ARGS='--bogus; true'` died on a
# shell syntax error before any word was inspected, non-zero but unnamed, which is precisely the
# "green run that ran nothing" shape one layer up. Measured on this change, not theorised. Through
# the environment the value is data the whole way: word splitting still yields the several flags,
# a metacharacter is an ordinary character inside a word, and the rejection can name it.
#
# WHAT THE `$` REJECTION DOES NOT COVER, because nothing in a recipe can: make expands `$(...)` and
# `${...}` in a command-line assignment while parsing it, long before this recipe exists, so
# `make eval EVAL_ARGS='--x$(id)'` arrives here already collapsed to `--x` (an undefined make
# variable, hence empty). The check therefore governs a `$` that SURVIVES to the shell, not make's
# own expansion. That is safe rather than merely unreachable: the collapsed word is not a flag the
# harness knows, so run.sh's own `*) unknown flag` arm exits 2 and the run is red -- measured. The
# failure mode this whole block exists to prevent is a GREEN run that ran nothing, and make's
# expansion cannot produce one.
EVAL_ARGS ?= --skip-model --skip-network
export EVAL_ARGS

eval:
	@bad_arg=''; \
	for a in $$EVAL_ARGS; do \
		case "$$a" in \
			-h|--help) \
				bad_arg="$$a exits the harness before its counters and floors run";; \
			*';'*|*'&'*|*'|'*|*'`'*|*'$$'*|*'('*|*')'*|*'<'*|*'>'*|*'"'*|*"'"*|*'\'*) \
				bad_arg="$$a contains a shell metacharacter";; \
		esac; \
	done; \
	if [ -n "$$bad_arg" ]; then \
		echo "refusing EVAL_ARGS: $$bad_arg" >&2; \
		exit 1; \
	fi; \
	failed=0; found=0; \
	for r in evals/*/run.sh; do \
		[ -e "$$r" ] || continue; \
		found=1; \
		echo "== $$r $$EVAL_ARGS"; \
		bash "$$r" $$EVAL_ARGS || failed=1; \
	done; \
	if [ "$$found" -eq 0 ]; then \
		echo "no evals/*/run.sh present -- nothing was selected, so nothing was eval'd" >&2; \
		failed=1; \
	fi; \
	test "$$failed" -eq 0

eval-live:
	@$(MAKE) --no-print-directory eval EVAL_ARGS=
