# From Inside Game to Outside Game
### Tracing the NBA's Three-Point Revolution, 2000–2026

Relational Databases — Group Project · PostgreSQL + Metabase

**Team:** Aditya Verma · Angela Wei · Disha Khati · Gursimrat Grewal · Yash Tiwari

## The Question

How did NBA shot selection move from the paint to the three-point line, which
franchises moved first, and did moving early actually win games? We answer this
at four increasing levels of resolution — league trend, team ranking, win
correlation, and roster composition — using **26 seasons (2000–01 through
2025–26)** pulled directly from the NBA's own stats API.

See [`docs/project_plan.pdf`](docs/project_plan.pdf) for the full write-up
(domain, data source rationale, schema, seven-week plan, and risks).

## Data Source

Raw JSON from `stats.nba.com`, accessed via the [`nba_api`](https://github.com/swar/nba_api)
Python client — not a pre-cleaned dataset. Sourcing raw data means we design
the schema, choose the keys, and handle the cleaning ourselves.

| # | Endpoint | Table | Rows |
|---|----------|-------|------|
| 1 | `LeagueGameLog` (per season) | `team_game` | ~68,400 |
| 2 | `CommonTeamRoster` (per team-season) | `roster` | ~11,700 |
| 3 | `CommonPlayerInfo` | `player` | ~2,300 |
| 4 | `LeagueDashTeamStats` (per season) | `team_season` | ~780 |
| 5 | `TeamYearByYearStats` | `team_season_history` | ~780 |
| 6 | `franchisehistory` | `team` | ~36 |
| 7 | (derived) | `season` | 26 |

## Repository Layout

```
├── ingestion/          # Pulls raw JSON from nba_api, caches to data/raw, rate-limited + retried
├── cleaning/           # Staging → typed/normalized transformations, documented
├── sql/
│   ├── schema/         # DDL: table definitions, keys, indexes
│   └── queries/        # ~25 queries, organized by narrative layer 1–4
├── data/
│   ├── raw/            # Cached raw JSON (gitignored — regenerate via ingestion/)
│   └── staging/        # Untyped staging tables / exports (gitignored)
├── dashboard/           # Metabase dashboard export / setup notes
├── reports/             # Data quality report, performance report (indexing benchmarks)
├── notebooks/           # Exploratory analysis
├── docs/                # Project plan PDF, ER diagram
└── tests/               # Validation: row counts, referential integrity, spot checks
```

## Setup

```bash
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

Configure a local PostgreSQL instance and set connection details in `.env`
(see `.env.example`).

## Pipeline

1. **Ingest** — `python ingestion/pull_gamelogs.py` (and similar scripts per
   endpoint) pulls raw JSON season-by-season, caches to `data/raw/`, retries
   on failure, and rate-limits to ~1 request/sec.
2. **Load to staging** — raw JSON landed into staging tables as text
   (`cleaning/load_staging.py`).
3. **Clean & type** — documented transformations from staging into the
   normalized schema (`cleaning/transform.py`), including franchise-identity
   resolution and column-name mapping across endpoints.
4. **Validate** — `tests/` checks row counts, referential integrity, and spot
   checks against published figures.
5. **Query** — the query library in `sql/queries/` walks through all four
   narrative layers, from aggregation through window functions to multi-table
   joins.
6. **Dashboard** — Metabase, connected to the indexed Postgres database.

## Seven-Week Plan

| Week | Focus |
|------|-------|
| 1 | Ingestion script, pull & cache raw JSON, design schema |
| 2 | Clean, type, load to staging → normalized tables; validate |
| 3 | Layers 1–2: league curve and team ranking |
| 4 | Layers 3–4: win correlation and roster composition |
| 5 | Indexing and optimization |
| 6 | Dashboard build |
| 7 | Write-up, rehearsal, buffer |

## License

Course project — for academic use.
