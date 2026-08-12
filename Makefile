.PHONY: clean test lint format

# Python toolchain surface: borg_core/ only (Part 3 of the python-core-and-toolchain directive).
# merge-tree/ and docs/infoviz/harness/ belong to the separate viz/infoviz program and are
# deliberately out of scope here. borg_core/ doesn't exist until Part 3's first commit -- test/lint
# no-op gracefully (not a failure) until then, same as pytest legitimately collecting zero tests.

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
