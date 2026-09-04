-- Layer 2: rank all 30 franchises by three-point rate per season,
-- relative to that season's league average.

WITH team_rate AS (
    SELECT
        team_id,
        season,
        100.0 * SUM(fg3a) / NULLIF(SUM(fga), 0) AS pct_from_three
    FROM team_game
    GROUP BY team_id, season
)
SELECT
    season,
    team_id,
    pct_from_three,
    ROUND(pct_from_three - AVG(pct_from_three) OVER (PARTITION BY season), 1) AS vs_league_avg,
    RANK() OVER (PARTITION BY season ORDER BY pct_from_three DESC) AS season_rank
FROM team_rate
ORDER BY season, season_rank;
