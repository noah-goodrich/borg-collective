# Project Plan: Fixture — an annotation with no value

- Plan-slug: ``

## Objective

The form a naive reader accepts and the gate must not: the line is PRESENT, so the `grep -m1` that
guards the no-annotation case succeeds, and only the emptiness check after the backtick-unwrap
refuses it. Without this fixture, deleting that check breaks nothing in the suite -- verified by
mutation on 2026-09-28.
