-- Core schema for the NBA three-point revolution project.
-- Franchise identity (relocations/renames) is resolved to a single team_id
-- during cleaning; see docs/project_plan.pdf, "Franchise identity is unstable".

CREATE TABLE IF NOT EXISTS season (
    season          TEXT PRIMARY KEY,      -- e.g. '2015-16'
    season_start_year INTEGER NOT NULL,
    era_label       TEXT,                  -- e.g. 'pre-revolution', 'acceleration', 'post-revolution'
    notes           TEXT                   -- rule changes, coverage caveats
);

CREATE TABLE IF NOT EXISTS team (
    team_id         BIGINT PRIMARY KEY,
    franchise_id    BIGINT NOT NULL,       -- stable across relocations/renames
    team_name        TEXT NOT NULL,
    abbreviation     TEXT NOT NULL,
    city              TEXT,
    active_from       TEXT REFERENCES season(season),
    active_to         TEXT REFERENCES season(season)
);

CREATE TABLE IF NOT EXISTS player (
    player_id       BIGINT PRIMARY KEY,
    full_name       TEXT NOT NULL,
    height_inches   INTEGER,
    weight_lbs      INTEGER,
    position        TEXT,
    draft_year      INTEGER
);

CREATE TABLE IF NOT EXISTS team_game (
    team_game_id    BIGINT PRIMARY KEY,
    team_id         BIGINT NOT NULL REFERENCES team(team_id),
    season          TEXT NOT NULL REFERENCES season(season),
    game_date       DATE NOT NULL,
    is_home         BOOLEAN NOT NULL,
    opponent_team_id BIGINT REFERENCES team(team_id),
    win              BOOLEAN,
    fga              INTEGER,
    fgm              INTEGER,
    fg3a             INTEGER,
    fg3m             INTEGER,
    fta              INTEGER,
    ftm              INTEGER,
    points           INTEGER
);

CREATE TABLE IF NOT EXISTS team_season (
    team_id         BIGINT NOT NULL REFERENCES team(team_id),
    season          TEXT NOT NULL REFERENCES season(season),
    fg3a_per_game   NUMERIC,
    fg3_pct         NUMERIC,
    off_rating      NUMERIC,
    def_rating      NUMERIC,
    pace            NUMERIC,
    PRIMARY KEY (team_id, season)
);

CREATE TABLE IF NOT EXISTS team_season_history (
    team_id         BIGINT NOT NULL REFERENCES team(team_id),
    season          TEXT NOT NULL REFERENCES season(season),
    wins            INTEGER,
    losses          INTEGER,
    win_pct         NUMERIC,
    PRIMARY KEY (team_id, season)
);

CREATE TABLE IF NOT EXISTS roster (
    team_id         BIGINT NOT NULL REFERENCES team(team_id),
    season          TEXT NOT NULL REFERENCES season(season),
    player_id       BIGINT NOT NULL REFERENCES player(player_id),
    jersey_number   TEXT,
    position        TEXT,
    PRIMARY KEY (team_id, season, player_id)
);
