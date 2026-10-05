-- =====================================================================
--  From Inside Game to Outside Game: the NBA three-point revolution
--  DSAI 691 Group Project, Phase 2: create database, tables, import data
--
--  Team: Aditya Verma, Angela Wei, Disha Khati, Gursimrat Grewal, Yash Tiwari
--  Data: stats.nba.com LeagueGameLog, 2000-01 through 2025-26, exported
--        to CSV by cleaning/export_csv.py. The three CSVs are committed
--        in data/csv/ so this script runs without any API pull.
--
--  HOW TO RUN IN PGADMIN (three parts, in order)
--
--    PART A  Create the database.
--            Open the Query Tool on the default "postgres" database,
--            highlight PART A only, press F5. Run once; skip it if the
--            database already exists.
--
--    PART B  Tables, constraints, data import, derived tables, indexes.
--            In the browser tree, refresh Databases, right-click
--            nba_three_point_revolution > Query Tool, then highlight
--            from the start of PART B to the end of PART B and press F5.
--            Safe to re-run: it drops and rebuilds every table.
--            The last statement returns a row-count check.
--
--    PART C  Understanding the data. Highlight any one query and press
--            F5 to see its result.
--
--  COPY PATHS
--    COPY runs on the database server, so the path is where the CSVs sit
--    on the machine running Postgres:
--      Postgres in Docker (our setup; docker-compose.yml mounts
--      ./data/csv into the container):   /data/csv/season.csv
--      Postgres installed on a Mac:      /Users/<you>/dsai691_nba_analytics_dashboard/data/csv/season.csv
--      Postgres installed on Windows:    C:/Users/<you>/dsai691_nba_analytics_dashboard/data/csv/season.csv
--    Those three COPY lines are the only thing to change between machines.
--    On Windows, if COPY reports "permission denied", the postgres service
--    account cannot read your user folder: copy data/csv to C:/nba_csv and
--    point the three paths there.
-- =====================================================================


-- #####################################################################
-- PART A: create the database (run on the "postgres" database)
-- #####################################################################

CREATE DATABASE nba_three_point_revolution;


-- #####################################################################
-- PART B: tables, constraints and data import
--         (run on nba_three_point_revolution)
-- #####################################################################

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Drop in reverse dependency order so a re-run always starts clean
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS roster              CASCADE;
DROP TABLE IF EXISTS team_season_history CASCADE;
DROP TABLE IF EXISTS team_season         CASCADE;
DROP TABLE IF EXISTS team_game           CASCADE;
DROP TABLE IF EXISTS player              CASCADE;
DROP TABLE IF EXISTS team                CASCADE;
DROP TABLE IF EXISTS season              CASCADE;

-- ---------------------------------------------------------------------
-- 2. Tables and constraints
-- ---------------------------------------------------------------------

-- One row per NBA season, 2000-01 through 2025-26.
CREATE TABLE season (
    season             TEXT    PRIMARY KEY,
    season_start_year  INTEGER NOT NULL UNIQUE,
    era_label          TEXT,
    notes              TEXT,
    CONSTRAINT chk_season_format CHECK (season ~ '^[0-9]{4}-[0-9]{2}$'),
    CONSTRAINT chk_season_year   CHECK (season_start_year BETWEEN 1946 AND 2100),
    CONSTRAINT chk_season_label  CHECK (substr(season, 1, 4)::INTEGER = season_start_year),
    CONSTRAINT chk_era_label     CHECK (era_label IN ('pre-revolution', 'acceleration', 'post-revolution'))
);

-- One row per NBA team_id. For the relocations in this window (Seattle ->
-- Oklahoma City, New Jersey -> Brooklyn) the NBA kept the same team_id, so
-- franchise_id currently equals team_id. The one exception is the 2002
-- Charlotte -> New Orleans move, where the NBA later reassigned the pre-2002
-- Charlotte seasons to today's Charlotte team_id; resolving that is a
-- Phase 3 cleaning item.
CREATE TABLE team (
    team_id       BIGINT PRIMARY KEY,
    franchise_id  BIGINT NOT NULL,
    team_name     TEXT   NOT NULL,
    abbreviation  TEXT   NOT NULL,
    city          TEXT,
    active_from   TEXT   REFERENCES season (season),
    active_to     TEXT   REFERENCES season (season),
    CONSTRAINT chk_team_abbrev CHECK (abbreviation ~ '^[A-Z]{2,4}$'),
    CONSTRAINT chk_team_active CHECK (active_from <= active_to)
);

-- Player dimension. Created now so roster's foreign key is enforced;
-- populated in Phase 3 from the CommonPlayerInfo endpoint.
CREATE TABLE player (
    player_id      BIGINT PRIMARY KEY,
    full_name      TEXT   NOT NULL,
    height_inches  INTEGER CHECK (height_inches BETWEEN 60 AND 96),
    weight_lbs     INTEGER CHECK (weight_lbs BETWEEN 120 AND 400),
    position       TEXT,
    draft_year     INTEGER CHECK (draft_year BETWEEN 1946 AND 2100)
);

-- The fact table: one row per team per game (two rows per game).
-- team_game_id = NBA GAME_ID * 100 + (team_id - 1610612736).
CREATE TABLE team_game (
    team_game_id      BIGINT  PRIMARY KEY,
    team_id           BIGINT  NOT NULL REFERENCES team (team_id),
    season            TEXT    NOT NULL REFERENCES season (season),
    game_date         DATE    NOT NULL,
    is_home           BOOLEAN NOT NULL,
    opponent_team_id  BIGINT  REFERENCES team (team_id),
    win               BOOLEAN NOT NULL,
    fga               INTEGER NOT NULL,
    fgm               INTEGER NOT NULL,
    fg3a              INTEGER NOT NULL,
    fg3m              INTEGER NOT NULL,
    fta               INTEGER NOT NULL,
    ftm               INTEGER NOT NULL,
    points            INTEGER NOT NULL,
    -- A team plays at most one game per day.
    CONSTRAINT uq_team_game_day   UNIQUE (team_id, game_date),
    CONSTRAINT chk_not_self       CHECK (opponent_team_id <> team_id),
    CONSTRAINT chk_fg_made        CHECK (fgm  BETWEEN 0 AND fga),
    CONSTRAINT chk_fg3_made       CHECK (fg3m BETWEEN 0 AND fg3a),
    CONSTRAINT chk_fg3_subset     CHECK (fg3a <= fga),
    CONSTRAINT chk_ft_made        CHECK (ftm  BETWEEN 0 AND fta),
    CONSTRAINT chk_points         CHECK (points >= 0),
    -- fgm already includes made threes, so points = 2*fgm + fg3m + ftm.
    CONSTRAINT chk_points_formula CHECK (points = 2 * fgm + fg3m + ftm)
);

-- Season-level team shooting profile, derived from team_game below.
CREATE TABLE team_season (
    team_id        BIGINT  NOT NULL REFERENCES team (team_id),
    season         TEXT    NOT NULL REFERENCES season (season),
    fg3a_per_game  NUMERIC CHECK (fg3a_per_game >= 0),
    fg3_pct        NUMERIC CHECK (fg3_pct BETWEEN 0 AND 1),
    off_rating     NUMERIC,
    def_rating     NUMERIC,
    pace           NUMERIC,
    PRIMARY KEY (team_id, season)
);

-- Season win/loss record, derived from team_game below.
CREATE TABLE team_season_history (
    team_id  BIGINT  NOT NULL REFERENCES team (team_id),
    season   TEXT    NOT NULL REFERENCES season (season),
    wins     INTEGER NOT NULL CHECK (wins   >= 0),
    losses   INTEGER NOT NULL CHECK (losses >= 0),
    win_pct  NUMERIC NOT NULL CHECK (win_pct BETWEEN 0 AND 1),
    PRIMARY KEY (team_id, season)
);

-- Which players were on which team each season. Populated in Phase 3
-- from the CommonTeamRoster endpoint.
CREATE TABLE roster (
    team_id        BIGINT NOT NULL REFERENCES team (team_id),
    season         TEXT   NOT NULL REFERENCES season (season),
    player_id      BIGINT NOT NULL REFERENCES player (player_id),
    jersey_number  TEXT,
    position       TEXT,
    PRIMARY KEY (team_id, season, player_id)
);

-- ---------------------------------------------------------------------
-- 3. Load source data with COPY
--    Order matters: season before team (team.active_from references it),
--    team before team_game.
--    >>> On another machine, change ONLY these three paths (see top). <<<
-- ---------------------------------------------------------------------
COPY season    FROM '/data/csv/season.csv'    WITH (FORMAT csv, HEADER true);
COPY team      FROM '/data/csv/team.csv'      WITH (FORMAT csv, HEADER true);
COPY team_game FROM '/data/csv/team_game.csv' WITH (FORMAT csv, HEADER true);

-- ---------------------------------------------------------------------
-- 4. Derived tables
-- ---------------------------------------------------------------------

-- Win/loss record per team-season, counted from the game log.
INSERT INTO team_season_history (team_id, season, wins, losses, win_pct)
SELECT team_id,
       season,
       COUNT(*) FILTER (WHERE win),
       COUNT(*) FILTER (WHERE NOT win),
       ROUND(COUNT(*) FILTER (WHERE win)::NUMERIC / COUNT(*), 3)
FROM team_game
GROUP BY team_id, season;

-- Three-point volume and accuracy per team-season. off_rating,
-- def_rating and pace need possession data (turnovers, offensive
-- rebounds) that team_game does not carry, so they stay NULL until the
-- LeagueDashTeamStats pull lands in Phase 3.
INSERT INTO team_season (team_id, season, fg3a_per_game, fg3_pct)
SELECT team_id,
       season,
       ROUND(AVG(fg3a), 2),
       ROUND(SUM(fg3m)::NUMERIC / NULLIF(SUM(fg3a), 0), 3)
FROM team_game
GROUP BY team_id, season;

-- ---------------------------------------------------------------------
-- 5. Indexes for the dashboard queries
-- ---------------------------------------------------------------------
CREATE INDEX idx_team_game_season            ON team_game (season);
CREATE INDEX idx_team_game_team_season       ON team_game (team_id, season);
CREATE INDEX idx_team_game_opponent          ON team_game (opponent_team_id);
CREATE INDEX idx_roster_team_season          ON roster (team_id, season);
CREATE INDEX idx_roster_player               ON roster (player_id);
CREATE INDEX idx_team_season_season          ON team_season (season);
CREATE INDEX idx_team_season_history_season  ON team_season_history (season);

COMMIT;

ANALYZE;

-- Row-count check. Expected: season 26, team 30, team_game 62508,
-- team_season 776, team_season_history 776, player 0, roster 0.
-- (776, not 780: the league had 29 teams until the Bobcats joined in
-- 2004-05. player and roster are loaded in Phase 3.)
-- problem_games counts games without exactly two rows, one winner and at
-- most one home team. Expected: 0.
SELECT 'season' AS table_name, COUNT(*) AS row_count FROM season
UNION ALL SELECT 'team',                COUNT(*) FROM team
UNION ALL SELECT 'team_game',           COUNT(*) FROM team_game
UNION ALL SELECT 'team_season',         COUNT(*) FROM team_season
UNION ALL SELECT 'team_season_history', COUNT(*) FROM team_season_history
UNION ALL SELECT 'player',              COUNT(*) FROM player
UNION ALL SELECT 'roster',              COUNT(*) FROM roster
UNION ALL
SELECT 'problem_games', COUNT(*)
FROM (
    SELECT team_game_id / 100
    FROM team_game
    GROUP BY team_game_id / 100
    HAVING COUNT(*) <> 2
        OR COUNT(*) FILTER (WHERE win) <> 1
        OR COUNT(*) FILTER (WHERE is_home) > 1
) g;

-- ============================ END OF PART B ===========================


-- #####################################################################
-- PART C: understanding the data
--         Highlight one query at a time and press F5.
-- #####################################################################

-- C1. The headline curve: share of all shots taken from three, by season.
--     Expect roughly 17% in 2000-01 rising to over 40% by 2025-26.
SELECT s.season,
       s.era_label,
       ROUND(100.0 * SUM(g.fg3a) / SUM(g.fga), 1) AS pct_shots_from_three,
       ROUND(SUM(g.fg3a)::NUMERIC / COUNT(*), 1)  AS threes_attempted_per_team_game
FROM team_game g
JOIN season s ON s.season = g.season
GROUP BY s.season, s.era_label
ORDER BY s.season;

-- C2. Volume exploded but accuracy barely moved: league 3P% by era.
SELECT s.era_label,
       MIN(s.season) AS first_season,
       MAX(s.season) AS last_season,
       ROUND(100.0 * SUM(g.fg3m) / SUM(g.fg3a), 1) AS three_point_pct,
       ROUND(100.0 * SUM(g.fg3a) / SUM(g.fga), 1)  AS pct_shots_from_three
FROM team_game g
JOIN season s ON s.season = g.season
GROUP BY s.era_label
ORDER BY MIN(s.season);

-- C3. Who moved first: the three highest three-point-rate teams each season.
--     team_name is the franchise's current name, so 2003-04 shows
--     "Oklahoma City Thunder" for the Seattle SuperSonics.
WITH team_rate AS (
    SELECT g.season, t.team_name,
           ROUND(100.0 * SUM(g.fg3a) / SUM(g.fga), 1) AS pct_shots_from_three,
           RANK() OVER (PARTITION BY g.season
                        ORDER BY SUM(g.fg3a)::NUMERIC / SUM(g.fga) DESC) AS season_rank
    FROM team_game g
    JOIN team t ON t.team_id = g.team_id
    GROUP BY g.season, t.team_name
)
SELECT season, season_rank, team_name, pct_shots_from_three
FROM team_rate
WHERE season_rank <= 3
ORDER BY season, season_rank;

-- C4. Did shooting more threes go with winning? Per season, the correlation
--     between a team's three-point attempts per game and its win percentage,
--     and between its three-point accuracy and its win percentage.
SELECT h.season,
       ROUND(CORR(ts.fg3a_per_game, h.win_pct)::NUMERIC, 2) AS corr_3pa_volume_vs_win_pct,
       ROUND(CORR(ts.fg3_pct,       h.win_pct)::NUMERIC, 2) AS corr_3p_accuracy_vs_win_pct
FROM team_season_history h
JOIN team_season ts ON ts.team_id = h.team_id AND ts.season = h.season
GROUP BY h.season
ORDER BY h.season;

-- C5. Best regular-season records since 2015-16 next to their three-point
--     profile. Ties on win_pct are broken by wins, then season.
SELECT h.season, t.team_name, h.wins, h.losses, h.win_pct,
       ts.fg3a_per_game, ts.fg3_pct
FROM team_season_history h
JOIN team t         ON t.team_id = h.team_id
JOIN team_season ts ON ts.team_id = h.team_id AND ts.season = h.season
WHERE h.season >= '2015-16'
ORDER BY h.win_pct DESC, h.wins DESC, h.season
LIMIT 15;

-- C6. Home-court advantage over time (neutral-site games excluded).
SELECT season,
       ROUND(100.0 * AVG(win::INT) FILTER (WHERE is_home), 1) AS home_win_pct,
       COUNT(*) FILTER (WHERE is_home) AS home_games
FROM team_game
GROUP BY season
ORDER BY season;

-- C7. Data quality: seasons with fewer games (lockout, COVID) and
--     neutral-site games with no home team.
SELECT s.season, s.notes,
       COUNT(DISTINCT g.team_game_id / 100) AS games_played,
       COUNT(DISTINCT g.team_game_id / 100)
           - COUNT(DISTINCT g.team_game_id / 100) FILTER (WHERE g.is_home) AS neutral_site_games
FROM season s
JOIN team_game g ON g.season = s.season
GROUP BY s.season, s.notes
ORDER BY s.season;
