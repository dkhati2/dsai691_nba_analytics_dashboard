-- Layer 1: the core curve of the entire project.
-- Three-point attempt rate by season, league-wide.

SELECT season,
       ROUND(100.0 * SUM(fg3a) / SUM(fga), 1) AS pct_of_shots_from_three
FROM team_game
WHERE fg3a IS NOT NULL
GROUP BY season
ORDER BY season;
