-- Applied in Week 5 after benchmarking un-indexed multi-join queries.
-- See reports/performance_report.md for before/after EXPLAIN plans.

CREATE INDEX IF NOT EXISTS idx_team_game_season       ON team_game (season);
CREATE INDEX IF NOT EXISTS idx_team_game_team_season  ON team_game (team_id, season);
CREATE INDEX IF NOT EXISTS idx_roster_team_season     ON roster (team_id, season);
CREATE INDEX IF NOT EXISTS idx_roster_player          ON roster (player_id);
CREATE INDEX IF NOT EXISTS idx_team_season_season     ON team_season (season);
CREATE INDEX IF NOT EXISTS idx_team_season_history_season ON team_season_history (season);
