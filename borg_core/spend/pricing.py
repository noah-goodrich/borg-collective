"""Per-MTok price table (the token-cost skill table; 5.x models use these rates as stand-ins)."""

from __future__ import annotations

from dataclasses import dataclass

COLD_WRITE_TOKENS = 40_000


@dataclass(frozen=True)
class Rate:
    """USD per million tokens."""

    fresh: float
    out: float
    write_5m: float
    write_1h: float
    read: float


RATES = (
    ("opus", Rate(5, 25, 6.25, 10, 0.50)),
    ("sonnet", Rate(3, 15, 3.75, 6, 0.30)),
    ("haiku", Rate(1, 5, 1.25, 2, 0.10)),
    ("fable", Rate(10, 50, 12.5, 20, 1)),
)


def rate_for(model: str) -> Rate | None:
    """The rate for a model id by family substring, or None when the model is unknown (never priced as zero)."""
    lowered = model.lower()
    for family, rate in RATES:
        if family in lowered:
            return rate
    return None
