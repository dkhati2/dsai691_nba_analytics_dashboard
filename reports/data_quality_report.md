# Data Quality Report

_Living document — update as cleaning decisions are made (Week 2 deliverable)._

## Row Count Reconciliation

| Table | Rows expected | Rows loaded | Delta | Notes |
|---|---|---|---|---|
| team_game | ~68,400 | | | |
| roster | ~11,700 | | | |
| player | ~2,300 | | | |
| team_season | ~780 | | | |
| team_season_history | ~780 | | | |
| team | ~36 | | | |
| season | 26 | | | |

## Franchise Identity Decisions

Document every relocation/rename resolution here (e.g. Seattle SuperSonics →
Oklahoma City Thunder, New Jersey → Brooklyn, Charlotte splits/merges) and the
franchise_id each maps to.

## Column Name Mapping

Document the mapping from endpoint-specific column names (`TEAM_ID`,
`TeamID`, `TEAM_ABBREVIATION`, etc.) to the normalized schema.

## Nulls: What They Mean

Note, per column, whether nulls in a given season range mean "did not exist,"
"not recorded," or "genuinely zero."

## Dropped / Uncertain Records

Log anything dropped during cleaning and why, and anything inferred rather
than directly observed.

## Spot Checks Against Published Figures

| Metric | Season | Our value | Published value | Source |
|---|---|---|---|---|
| League 3PA rate | | | | |
