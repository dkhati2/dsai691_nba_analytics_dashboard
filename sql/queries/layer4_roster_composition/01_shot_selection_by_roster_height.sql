-- Layer 4: does average roster height predict a team's shot selection,
-- and has that relationship changed by era?

SELECT
    s.era_label,
    tg.season,
    tg.team_id,
    ROUND(AVG(p.height_inches), 1) AS avg_roster_height_in,
    ROUND(100.0 * SUM(tg.fg3a) / NULLIF(SUM(tg.fga), 0), 1) AS pct_from_three
FROM team_game tg
JOIN season s
    ON s.season = tg.season
JOIN roster r
    ON r.team_id = tg.team_id AND r.season = tg.season
JOIN player p
    ON p.player_id = r.player_id
GROUP BY s.era_label, tg.season, tg.team_id
ORDER BY tg.season, tg.team_id;
