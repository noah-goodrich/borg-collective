---
name: simplify
description: >
  Review changed code for reuse, quality, and efficiency, then fix any issues found. Operates
  only on files touched in the current session. Catches dead code, redundant logic, reinvented
  utilities, and unnecessary complexity before it ships. Fixes — does not just report.
user-invocable: true
---

# Simplify — Clean Up Before You Ship

Your job is to make the changed code simpler. Not shorter for its own sake — fewer moving parts.
Find problems, fix them, report what changed. Do not add features. Do not refactor things that
weren't touched. Do not suggest — act.

## Step 1: Identify Changed Files

Run `git diff --name-only` for unstaged changes and `git diff --cached --name-only` for staged
changes. Union the two lists. If both are empty, fall back to `git diff HEAD~1 --name-only`.

Work only on files in that list. Do not touch anything else, even if you notice problems.

## Step 2: Load Changed Code and Surrounding Context

For each changed file:
1. Read the full file (not just the diff)
2. Note the language, imports, and any utilities/helpers already imported or available

Then do a fast scan of the broader codebase for shared utilities:
- Look for `utils`, `helpers`, `common`, or similarly named modules in the same package
- Check what's already imported at the top of each changed file — those are free to use
- If the project has a clear domain layer (e.g. `domain/`, `lib/`, `core/`), skim its public
  surface for functions the new code might be able to call instead of reimplementing

The goal is to know what exists before deciding whether the new code reinvented it.

## Step 3: Review for These Issues (in priority order)

**Reuse violations** — new code reimplements something that already exists nearby:
- A helper function that duplicates an existing utility
- A loop that could be a built-in (`any()`, `sum()`, list comprehension, etc.)
- Inline logic that an already-imported library handles (e.g. manually parsing a string that
  `pathlib` or `re` would handle in one line)
- Copy-paste from another function in the same file

**Dead code** — code that cannot be reached or has no effect:
- Variables assigned but never read
- Branches that can never be true given the surrounding logic
- Imports that are unused
- Functions defined but never called within the changed scope

**Unnecessary complexity** — code that works but is harder to read or maintain than it needs to be:
- A 10-line block that a standard library call would replace
- Nested conditionals that could be flattened with an early return
- A mutable accumulator pattern where a comprehension would be clearer
- A class or abstraction introduced for a single use case with no clear extension point

**Redundant logic** — the same computation performed more than once:
- The same expression evaluated in multiple branches without caching
- Repeated lookups into a dict/object that could be assigned once

**Style drift** — new code that doesn't match the style of the surrounding file:
- Inconsistent naming convention (snake_case vs camelCase in the same file)
- Comment style that differs from the rest of the file
- Blank line conventions that break the file's existing pattern

Do NOT flag:
- Things that are merely imperfect but working and clear
- Style preferences that aren't already established in the file
- Anything outside the changed files
- Anything that would change behavior

## Step 4: Fix What You Find

For each issue found, edit the file directly. Do not list issues and ask for permission — fix them.

Apply fixes that are:
- Mechanical (unused import removal, variable inlining, early-return flattening)
- Safe (no behavior change, no public API change)
- Local to the changed file (no cross-file ripple effects)

If a fix would require changing callers in other files, flag it instead of applying it:
> "Found: [description]. Fix requires changing [other file(s)] — skipping to avoid scope creep.
> Consider addressing separately."

## Step 5: Report

After all edits are done, output a compact summary:

```
Simplify pass complete.

Fixed:
  • [file:line] — [what and why, one line]
  • [file:line] — [what and why, one line]

Skipped (needs wider change):
  • [description] — [why skipped]

No issues found:
  • [file] — looks clean
```

If nothing needed fixing, say so directly: "No simplifications found. Code looks clean."

Do not pad the report. Do not suggest further improvements. The pass is done when the report
is printed.
