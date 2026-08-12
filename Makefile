.PHONY: clean test lint format

# Python toolchain surface: merge-tree/ + docs/infoviz/harness/. No borg_core/ yet (Part 3 of the
# python-core-and-toolchain directive). Part 2 adds tests to merge-tree/; until then `test` may
# legitimately collect zero tests (pytest exit 5) and that is not a failure.

clean:
	rm -rf dist/
	rm -rf build/
	rm -rf *.egg-info
	find . -name "__pycache__" -type d -exec rm -rf {} +
	find . -name "*.pyc" -delete
	rm -f .coverage
	rm -f coverage.xml

test:
	@set -e; \
	coverage run -m pytest || test $$? -eq 5; \
	coverage report -m

lint:
	ruff check merge-tree/ docs/infoviz/harness/
	mypy merge-tree/ docs/infoviz/harness/
	@if python3 -c "import clean_architecture_linter" > /dev/null 2>&1; then \
		pylint --load-plugins=clean_architecture_linter merge-tree/ docs/infoviz/harness/; \
	else \
		echo "pylint-clean-architecture not installed; falling back to plain pylint"; \
		pylint merge-tree/ docs/infoviz/harness/; \
	fi

format:
	ruff format merge-tree/ docs/infoviz/harness/
