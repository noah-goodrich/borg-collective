# Project Plan: Fixture — an annotation with no value

## Objective

The form a naive reader accepts and the gate must not: the line is PRESENT, so the `grep -m1` that
guards the no-annotation case succeeds, and only the emptiness check after the backtick-unwrap
refuses it.

SCOPED CLAIM, because the first draft of this comment overstated it and the verify gate's reviewer
caught it. Deleting that check breaks nothing in `prose_contracts.bats` ALONE without this fixture —
verified by mutation 2026-09-28, where test 6 is the only catch in this file. It does NOT break
nothing in the wider suite: `tests/promote_next.bats`'s "an annotation present but valueless is a
refusal, not an empty slug" already catches the same mutation and predates this fixture. So this
case adds LOCAL coverage, making this file's discrimination floor self-sufficient rather than
dependent on a sibling suite — which is worth having, but is not the novel catch the first draft
claimed.
