-- Layer 3: does an early jump in three-point rate correlate with wins
-- in the same season, and in the following two seasons?

WITH team_rate AS (
    SELECT
        team_id,
        season,
        100.0 * SUM(fg3a) / NULLIF(SUM(fga), 0) AS pct_from_three
    FROM team_game
    GROUP BY team_id, season
)
SELECT
    r.team_id,
    r.season,
    r.pct_from_three,
    h.win_pct,
    LAG(h.win_pct, -1) OVER (PARTITION BY r.team_id ORDER BY r.season) AS win_pct_next_season,
    LAG(h.win_pct, -2) OVER (PARTITION BY r.team_id ORDER BY r.season) AS win_pct_two_seasons_later
FROM team_rate r
JOIN team_season_history h
    ON h.team_id = r.team_id AND h.season = r.season
ORDER BY r.team_id, r.season;
