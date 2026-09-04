"""
Staging -> normalized schema transformations.

Every transformation applied here should be documented in
reports/data_quality_report.md: what was malformed, what was dropped,
what was inferred, and what remains uncertain.

This module intentionally starts as a skeleton — fill in each function
as the corresponding staging table is loaded (Week 2).
"""


def resolve_franchise_identity(raw_team_rows):
    """
    Collapse relocated/renamed franchises (e.g. Seattle SuperSonics ->
    Oklahoma City Thunder) to a single stable franchise_id.

    TODO: implement mapping table + resolution logic; document every
    merge decision in reports/data_quality_report.md.
    """
    raise NotImplementedError


def normalize_minutes(value):
    """
    Normalize minutes played across formats: "38:00" (MM:SS-ish string)
    vs 38.0 (float). Returns float minutes or None if unparseable.
    """
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str) and ":" in value:
        minutes, _, seconds = value.partition(":")
        try:
            return int(minutes) + int(seconds or 0) / 60
        except ValueError:
            return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def cast_staging_row(row: dict, type_map: dict) -> dict:
    """
    Cast a raw (all-string/None) staging row to typed Python values
    according to type_map = {column_name: python_type}. Failed casts
    are logged rather than silently coerced — see project plan,
    "No types".
    """
    typed = {}
    for column, value in row.items():
        target_type = type_map.get(column)
        if target_type is None or value is None:
            typed[column] = value
            continue
        try:
            typed[column] = target_type(value)
        except (TypeError, ValueError):
            typed[column] = None
            print(f"WARN: failed cast for column={column!r} value={value!r}")
    return typed
