# Rebuilding the dashboard on your machine

This takes you from a fresh clone to the full Phase 3 Metabase dashboard in
about 10 minutes: "NBA Three Point Revolution", with 17 charts in three
sections, a short story paragraph above every chart, and a Season filter.
You need no API pulls and no Python packages.

Everything runs in Docker, so it works the same on macOS, Windows and Linux.
All passwords below are local-only defaults from `docker-compose.yml`.

## What you need

- **Docker Desktop**, installed and running.
- **git**.
- **Python 3.8+**, but only for step 5. It uses the standard library only, so you don't need a venv.
  On Windows the command is `python` instead of `python3`.

## 1. Clone and start the stack

```bash
git clone https://github.com/dkhati2/dsai691_nba_analytics_dashboard.git
cd dsai691_nba_analytics_dashboard
docker compose up -d
docker compose ps
```

Wait until `nba_postgres` shows `(healthy)` and `nba_metabase` shows `running`.
pgAdmin also starts (from `docker-compose.override.yml`), but you don't need it here.

| Service | Address from your computer |
|---|---|
| Metabase | http://localhost:3000 |
| pgAdmin | http://localhost:5050 |
| Postgres | `127.0.0.1:5433` (user `postgres`, password `nba_local_pw`) |

## 2. Load the data

The Postgres container already created the empty `nba_three_point_revolution`
database, so skip Part A of the script and run Part B only:

```bash
sed -n '/^-- PART B/,/END OF PART B/p' sql/create_and_load.sql | docker compose exec -T db psql -U postgres -d nba_three_point_revolution -q
```

The last thing it prints is a row-count table. You should see:

| table | rows |
|---|---|
| season | 26 |
| team | 30 |
| team_game | 62,508 |
| team_season | 776 |
| team_season_history | 776 |
| player, roster | 0 (not loaded yet) |
| problem_games | 0 |

It reads `data/csv/*.csv`, which `docker-compose.yml` mounts into the
container at `/data/csv`. Running it again is safe, because it drops and
rebuilds every table.

On Windows without `sed`, use pgAdmin instead. Register a server with host
`db`, port `5432`, user `postgres` and password `nba_local_pw`. Open
`sql/create_and_load.sql` in the Query Tool on `nba_three_point_revolution`,
highlight from `PART B` down to `END OF PART B`, and press F5.

## 3. Create your Metabase account

Open http://localhost:3000. The first visit runs a setup wizard: create an
admin account with any email and password. This is a login on your
computer only, not your USF account. If the wizard asks you to add data, you
can skip that step and add the connection in step 4.

## 4. Connect Metabase to Postgres

Click the gear icon, then **Admin settings → Databases → Add database**:

| Field | Value |
|---|---|
| Database type | PostgreSQL |
| Display name | NBA Three Point Revolution |
| Host | `db` |
| Port | `5432` |
| Database name | `nba_three_point_revolution` |
| Username | `postgres` |
| Password | `nba_local_pw` |

**Host is `db`, not `localhost`, and the port is `5432`, not `5433`.**
Metabase runs inside Docker. There, `localhost` means the Metabase container
itself, and `db` is the Postgres service name on the shared Docker network.
`5433` is only how your computer reaches Postgres from outside Docker.

Instead of filling in this form, you can pass `--connect-db` in step 5 and
the script adds the same connection for you.

## 5. Build the dashboard

```bash
python3 dashboard/build_dashboard.py --email you@example.com
```

Use the email from step 3. The script asks for your Metabase password, or
reads it from the `MB_PASSWORD` environment variable. It then:

1. Reads every query from `sql/dashboard_queries.sql`.
2. Reads chart types, chart settings and the layout from `dashboard/dashboard_spec.json`.
3. Creates a collection "NBA Three Point Revolution" and one saved question per card.
   Each one is run once, so any SQL error stops the script right away.
4. Creates the dashboard with the three section headings, the story text
   above each chart, and every card in place. Each chart also gets its story
   text as a description, shown under its ⓘ icon.
5. Adds a **Season** filter wired to Q7 and Q8.

At the end it prints a link such as `http://localhost:3000/dashboard/2`.

Options:

| Flag | What it does |
|---|---|
| `--dry-run` | Prints what would be built. It doesn't contact Metabase. |
| `--connect-db` | Adds the Postgres connection from step 4 if it's missing. |
| `--replace` | Archives an existing dashboard with the same name, then rebuilds it. |
| `--url` | Use a Metabase that isn't at `http://localhost:3000`. |

## 6. Check it

- The dashboard has three sections: **L1 · The league curve**, **L2 · Who
  moved first** and **L3 · Did it work?**
- The number cards at the top read **17%**, **41.5%** and **2.4×**.
- Every chart has a paragraph above it, and the page ends with a block
  called **The answer**.
- Pick `2016-17` in the **Season** filter. Q8 should show Houston, Cleveland
  and Boston. Q7 should show that season's top 10 teams, starting with Houston
  at +14.6, with the last column shaded blue.

## 7. Export screenshots for the submission

The assignment asks for screenshots taken with Metabase's own export and
sharing features:

- **Whole dashboard:** click the **share** icon (the box with an arrow, top
  right of the dashboard) and choose **Export as PDF**. Pick a season in the
  Season filter first, so Q7 and Q8 show a meaningful view, and say which
  season in the caption.
- **One chart:** hover over the chart, open its **⋯** menu, choose
  **Download results**, then **.png**. Only charts offer .png. The number tiles
  (Q1) and tables (Q7, Q8, Q15) only offer data files, so the dashboard PDF
  covers those.

Put one chart per page in the submission PDF with a one-line caption. The
story paragraph above each chart works well as that caption. Submit it with
`sql/dashboard_queries.sql`, and have only one person submit.

## Changing the dashboard

The two files the script reads are the source of truth, so change those
rather than only clicking in Metabase:

- **To change a query**, edit `sql/dashboard_queries.sql`. Each query starts
  with a `-- Qn.` header line, and the script splits the file on those lines.
- **To change a chart type, its settings, its position or its story text**,
  edit `dashboard/dashboard_spec.json`. Each card's `query`
  field (`"Q7"`, `"Q1a"`, ...) is how it is matched to its query; the `name`
  is the title shown on the dashboard. `col`/`row`/`w`/`h`
  are positions on Metabase's 24-column grid. Entries with `"text"` are the
  story paragraphs (Markdown), and entries with `"heading"` are section titles.
- **Q7 and Q8 carry an optional Metabase clause**, `[[AND season = {{season}}]]`,
  in the SQL file itself (the line marked `-- Metabase filter`). Cards with
  `"filter": true` in the spec are wired to the Season filter, and the script
  stops if one of them has no `{{season}}` clause.

Then rebuild with `--replace`.

If you rearranged the dashboard by dragging in Metabase and want to keep
that layout, copy the new positions into `dashboard_spec.json`. Otherwise
the next `--replace` resets them.

## Troubleshooting

| Problem | Fix |
|---|---|
| `Cannot reach Metabase` | Run `docker compose ps`. Metabase can take a minute to boot on first start. |
| `HTTP 401` on login | Wrong email or password. Use the Metabase account from step 3. |
| `No Postgres connection` | Do step 4, or rerun with `--connect-db`. |
| A card fails to run | Check that step 2 printed the expected row counts. |
| Metabase connection fails | Use host `db` and port `5432`, not `localhost`/`5433`. |
| Port 5432 or 3000 already in use | Stop the other service, or change the left-hand port in `docker-compose.yml`. |
| Charts show no data | The tables are empty: rerun step 2. |

## Where things live

- **Data:** the database is stored in the Docker volume `pgdata`. It survives
  restarts and `docker compose down`. It's only deleted by
  `docker compose down -v` or by removing the volume.
- **Metabase:** your login, connection and dashboard are stored in the volume
  `mbdata`, and only on your machine. Each teammate builds their own copy with
  step 5.
- **Starting again later:** open Docker Desktop and run `docker compose up -d`.
  Nothing needs reloading.
