# Dashboard (Metabase)

One Metabase dashboard, **NBA Three Point Revolution**, tells the project's
story in three sections. Each section opens with a short intro, and each
chart has a paragraph above it saying what it shows and what it means.

| Section | Question | Charts |
|---|---|---|
| L1 · The league curve | When did shot selection change? | Q1–Q6: headline numbers, 3PA share by season, points by shot type, season-over-season change, era comparison, scoring efficiency |
| L2 · Who moved first | Which franchises led the change? | Q7–Q10: top 10 vs league average, top 3 each season, adoption year, acceleration-era leaders |
| L3 · Did it work? | Did shooting threes go with winning? | Q11–Q15: team-season scatter, correlation with win %, next-season win %, three-point battle win %, best records |

A **Season** filter at the top drives Q7 and Q8. Layer 4 (roster position
and body type) waits on the `player` and `roster` tables, which aren't
loaded yet.

## Files

| File | What it is |
|---|---|
| [`SETUP.md`](SETUP.md) | Step-by-step guide from a fresh clone to the finished dashboard, plus how to export screenshots |
| [`build_dashboard.py`](build_dashboard.py) | Rebuilds the whole dashboard through Metabase's API (Python standard library only) |
| [`dashboard_spec.json`](dashboard_spec.json) | Chart types, settings, layout, story text and descriptions the script uses |
| [`../sql/dashboard_queries.sql`](../sql/dashboard_queries.sql) | The SQL behind every chart, labeled Q1–Q15 to match the chart titles |
