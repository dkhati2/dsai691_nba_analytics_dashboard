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

## Phase 3 hand-off (read this first)

Phase 3 (due 9 Oct, 60 pts) is the dashboard phase: `dashboard_queries.sql`
with every query behind a chart, plus a PDF of screenshots taken with
Metabase's export/share feature. The rubric grades SQL variety (joins across
real relationships, GROUP BY + aggregates, HAVING; window functions earn the
top band), chart-to-query traceability, chart variety, and a single organized
.sql file. It does not require any new data to be loaded.

### 1. Get the Phase 2 database running (about 5 minutes)

All passwords below are the local-only defaults in `docker-compose.yml` and
`docker-compose.override.yml`; they are the same on every machine.

```bash
git clone https://github.com/dkhati2/dsai691_nba_analytics_dashboard.git
cd dsai691_nba_analytics_dashboard
docker compose up -d        # Postgres (host port 5433), Metabase :3000, pgAdmin :5050
```

**Load the data in pgAdmin** (http://localhost:5050, login `yash@usfca.edu` /
`nba_local_pw`). Register a server: host `db`, port `5432`, user `postgres`,
password `nba_local_pw`. Open `sql/create_and_load.sql`; run Part A on the
`postgres` database, then Part B on `nba_three_point_revolution`. The last
statement prints row counts: season 26, team 30, team_game 62,508,
team_season 776, team_season_history 776, problem_games 0.

**Connect Metabase** (http://localhost:3000). First visit creates your own
admin account. Then Admin settings, Databases, Add database: PostgreSQL,
host `db`, port `5432`, database `nba_three_point_revolution`, user `postgres`,
password `nba_local_pw`. Host is `db`, not `localhost`, and port is `5432`,
not `5433`: Metabase talks to Postgres inside the Docker network.

### 2. What is loaded

| Table | Rows | How |
|---|---|---|
| `season` | 26 | from `data/csv/season.csv` (committed) |
| `team` | 30 | from `data/csv/team.csv` (committed) |
| `team_game` | 62,508 | from `data/csv/team_game.csv` (committed); 2000-01 to 2025-26, one row per team per game |
| `team_season` | 776 | derived in the script from `team_game` (3PA/game, 3P%) |
| `team_season_history` | 776 | derived in the script from `team_game` (W, L, win%) |
| `player`, `roster` | 0 | tables exist with keys; not loaded |

Source for everything: `stats.nba.com` `LeagueGameLog` via `nba_api`, pulled by
`ingestion/pull_gamelogs.py` and cleaned by `cleaning/export_csv.py` (cleaning
decisions are in that file's docstring). To regenerate: `python -m
ingestion.pull_gamelogs` (slow, caches to gitignored `data/raw/`), then
`python3 -m cleaning.export_csv`.

### 3. Where to start on the queries

Part C of `sql/create_and_load.sql` has seven working queries (league curve,
era comparison, per-season RANK() window function, CORR() against win%, best
records, home-court, data quality) that join `team_game`, `season`, `team`,
`team_season` and `team_season_history`. They cover story layers 1 to 3 from
the Phase 1 plan and are a direct starting point for `dashboard_queries.sql`.
`sql/queries/layer1..3` has three more.

### 4. Optional, only if someone wants layer 4

`player` and `roster` are empty, so `sql/queries/layer4_roster_composition/`
returns nothing. Filling them means two new ingestion scripts
(`CommonPlayerInfo`, `CommonTeamRoster`; about 776 API calls at 1/sec).
`team_season.off_rating`, `def_rating`, `pace` are NULL (`LeagueDashTeamStats`).
`team.city` is blank and relocated franchises carry their current name in old
seasons (Seattle 2003-04 shows as Oklahoma City). None of this is required by
the Phase 3 rubric.

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
