"""
Validation tests for the cleaning layer (Week 2 deliverable).

Run with: pytest
"""

from cleaning.transform import normalize_minutes


def test_normalize_minutes_from_colon_string():
    assert normalize_minutes("38:00") == 38.0
    assert normalize_minutes("38:30") == 38.5


def test_normalize_minutes_from_float():
    assert normalize_minutes(38.0) == 38.0


def test_normalize_minutes_none():
    assert normalize_minutes(None) is None


def test_normalize_minutes_unparseable():
    assert normalize_minutes("not-a-number") is None
