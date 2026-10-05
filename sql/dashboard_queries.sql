--  DSAI 691 Group Project, Phase 3: queries powering the Metabase dashboard
--  Team: Aditya Verma, Angela Wei, Disha Khati, Gursimrat Grewal, Yash Tiwari
--  Database: nba_three_point_revolution (built by create_and_load.sql)
--
--  HOW TO USE IN METABASE
--    + New > SQL query > database "NBA Three Point Revolution", paste one
--    query, run it, click Visualization, pick the chart type named in the
--    query's header, then Save and add it to the dashboard
--    "NBA Three Point Revolution". One query = one card.

-- #####################################################################
-- L1  THE LEAGUE CURVE
-- #####################################################################

-- Q1. Headline numbers: 3PA share, first season vs latest season.
--     Chart: three Number cards (one per column), or a single Table.
WITH by_season AS (
    SELECT season,
           100.0 * SUM(fg3a) / SUM(fga) AS pct_shots_from_three
    FROM team_game
    GROUP BY season
)
SELECT ROUND(f.pct_shots_from_three, 1)                          AS share_2000_01,
       ROUND(l.pct_shots_from_three, 1)                          AS share_2025_26,
       ROUND(l.pct_shots_from_three / f.pct_shots_from_three, 1) AS times_larger
FROM by_season f
CROSS JOIN by_season l
WHERE f.season = (SELECT MIN(season) FROM by_season)
  AND l.season = (SELECT MAX(season) FROM by_season);


-- Q2. The headline curve: share of shots taken from three, by season.
--     Chart: Line. X = season, Y = pct_shots_from_three (series by era_label
--     optional). Add threes_per_team_game as a second line on the right axis.
SELECT s.season,
       s.era_label,
       ROUND(100.0 * SUM(g.fg3a) / SUM(g.fga), 1) AS pct_shots_from_three,
       ROUND(AVG(g.fg3a), 1)                      AS threes_per_team_game
FROM team_game g
JOIN season s ON s.season = g.season
GROUP BY s.season, s.era_label
ORDER BY s.season;


-- Q3. Where the points come from: share of points scored on twos,
--     threes and free throws, by season.
--     Chart: Stacked area (or 100% stacked bar). X = season.
SELECT season,
       ROUND(100.0 * SUM(2 * (fgm - fg3m)) / SUM(points), 1) AS pct_points_from_twos,
       ROUND(100.0 * SUM(3 * fg3m)         / SUM(points), 1) AS pct_points_from_threes,
       ROUND(100.0 * SUM(ftm)              / SUM(points), 1) AS pct_points_from_free_throws
FROM team_game
GROUP BY season
ORDER BY season;


-- Q4. Finding the inflection point: season-over-season change in 3PA
--     share. The tallest bars mark when the shift accelerated.
--     Chart: Bar. X = season, Y = change_pct_points.
WITH by_season AS (
    SELECT season,
           100.0 * SUM(fg3a) / SUM(fga) AS pct_shots_from_three
    FROM team_game
    GROUP BY season
)
SELECT season,
       ROUND(pct_shots_from_three, 1) AS pct_shots_from_three,
       ROUND(pct_shots_from_three
             - LAG(pct_shots_from_three) OVER (ORDER BY season), 1) AS change_pct_points
FROM by_season
ORDER BY season;


-- Q5. Volume exploded, accuracy barely moved: 3PA share vs 3P% by era.
--     Chart: Bar (grouped). X = era_label, Y = both percentage columns.
SELECT s.era_label,
       MIN(s.season) || ' to ' || MAX(s.season)    AS seasons,
       ROUND(100.0 * SUM(g.fg3a) / SUM(g.fga), 1)  AS pct_shots_from_three,
       ROUND(100.0 * SUM(g.fg3m) / SUM(g.fg3a), 1) AS three_point_pct,
       ROUND(100.0 * SUM(g.fgm - g.fg3m)
                   / SUM(g.fga - g.fg3a), 1)       AS two_point_pct
FROM team_game g
JOIN season s ON s.season = g.season
GROUP BY s.era_label
ORDER BY MIN(s.season);


-- Q6. Did offense get better? Points per team game and effective
--     field-goal percentage, by season.
--     Chart: Line with two Y axes. X = season.
SELECT season,
       ROUND(AVG(points), 1)                                       AS points_per_team_game,
       ROUND(100.0 * (SUM(fgm) + 0.5 * SUM(fg3m)) / SUM(fga), 1)   AS effective_fg_pct
FROM team_game
GROUP BY season
ORDER BY season;


-- #####################################################################
-- L2  WHO MOVED FIRST
-- #####################################################################

-- Q7. Every team's 3PA share relative to the league average that season.
--     Positive = shooting more threes than the league. AVG() OVER gives
--     the league average without a second query.
--     Chart: Pivot table (rows = team_name, columns = season,
--     value = vs_league_pct_points, conditional color), or Line filtered
--     to a few teams (Houston, Golden State, San Antonio, Memphis).
WITH team_rate AS (
    SELECT g.season,
           t.team_name,
           100.0 * SUM(g.fg3a) / SUM(g.fga) AS pct_shots_from_three
    FROM team_game g
    JOIN team t ON t.team_id = g.team_id
    GROUP BY g.season, t.team_name
)
SELECT season,
       team_name,
       ROUND(pct_shots_from_three, 1) AS pct_shots_from_three,
       ROUND(pct_shots_from_three
             - AVG(pct_shots_from_three) OVER (PARTITION BY season), 1) AS vs_league_pct_points
FROM team_rate
ORDER BY season, vs_league_pct_points DESC;


-- Q8. The leaders: the three highest 3PA-share teams each season.
--     Chart: Table.
WITH team_rate AS (
    SELECT g.season,
           t.team_name,
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


-- Q9. Adoption year: the first season each franchise took at least 35% of
--     its shots from three (a level no team reached before 2009-10).
--     Earlier year = earlier adopter.
--     Chart: Row (horizontal bar). X = team_name, Y = first_season_start_year,
--     sorted ascending.
WITH team_rate AS (
    SELECT g.team_id,
           s.season,
           s.season_start_year,
           SUM(g.fg3a)::NUMERIC / SUM(g.fga) AS share
    FROM team_game g
    JOIN season s ON s.season = g.season
    GROUP BY g.team_id, s.season, s.season_start_year
),
first_cross AS (
    SELECT team_id, season, season_start_year,
           ROW_NUMBER() OVER (PARTITION BY team_id ORDER BY season_start_year) AS rn
    FROM team_rate
    WHERE share >= 0.35
)
SELECT t.team_name,
       f.season            AS first_season_at_35_pct,
       f.season_start_year AS first_season_start_year,
       CASE WHEN f.season_start_year <= 2014 THEN 'early adopter'
            WHEN f.season_start_year <= 2016 THEN 'mainstream'
            ELSE 'late adopter' END AS adopter_group
FROM first_cross f
JOIN team t ON t.team_id = f.team_id
WHERE f.rn = 1
ORDER BY f.season_start_year, t.team_name;


-- Q10. Who led during the acceleration era (2009-10 to 2014-15)? Number of
--      seasons each franchise ranked in the league's top five by 3PA share,
--      keeping only franchises that did it more than once (HAVING).
--      Chart: Bar. X = team_name, Y = top5_seasons.
WITH team_rank AS (
    SELECT g.team_id,
           g.season,
           RANK() OVER (PARTITION BY g.season
                        ORDER BY SUM(g.fg3a)::NUMERIC / SUM(g.fga) DESC) AS season_rank
    FROM team_game g
    JOIN season s ON s.season = g.season
    WHERE s.era_label = 'acceleration'
    GROUP BY g.team_id, g.season
)
SELECT t.team_name,
       COUNT(*) AS top5_seasons
FROM team_rank r
JOIN team t ON t.team_id = r.team_id
WHERE r.season_rank <= 5
GROUP BY t.team_name
HAVING COUNT(*) >= 2
ORDER BY top5_seasons DESC, t.team_name;


-- #####################################################################
-- L3  DID IT WORK?
-- #####################################################################

-- Q11. Every team-season: 3PA share vs win percentage, colored by era.
--      Chart: Scatter. X = pct_shots_from_three, Y = win_pct,
--      series = era_label.
SELECT t.team_name,
       h.season,
       s.era_label,
       ROUND(100.0 * SUM(g.fg3a) / SUM(g.fga), 1) AS pct_shots_from_three,
       h.win_pct
FROM team_season_history h
JOIN team t      ON t.team_id = h.team_id
JOIN season s    ON s.season  = h.season
JOIN team_game g ON g.team_id = h.team_id AND g.season = h.season
GROUP BY t.team_name, h.season, s.era_label, h.win_pct
ORDER BY h.season, t.team_name;


-- Q12. Is winning tied to shooting threes, and does that change over time?
--      Correlation between team win % and (a) 3PA per game, (b) 3P%,
--      computed separately for each season.
--      Chart: Line. X = season, two series.
SELECT h.season,
       ROUND(CORR(ts.fg3a_per_game, h.win_pct)::NUMERIC, 2) AS corr_3pa_volume_vs_win_pct,
       ROUND(CORR(ts.fg3_pct,       h.win_pct)::NUMERIC, 2) AS corr_3p_accuracy_vs_win_pct
FROM team_season_history h
JOIN team_season ts ON ts.team_id = h.team_id AND ts.season = h.season
GROUP BY h.season
ORDER BY h.season;


-- Q13. Did moving early pay off later? Teams are split each season into
--      above / below the league-average 3PA share. Their win % is then
--      followed into the same season, the next season and two seasons on
--      (LEAD over each team's seasons). Covers seasons through 2023-24 so
--      both follow-up seasons exist.
--      Chart: Bar (grouped). X = three_point_profile, Y = the three win %
--      columns. Or Line by season with series = three_point_profile.
WITH team_rate AS (
    SELECT g.team_id,
           g.season,
           SUM(g.fg3a)::NUMERIC / SUM(g.fga) AS share
    FROM team_game g
    GROUP BY g.team_id, g.season
),
profiled AS (
    SELECT r.team_id,
           r.season,
           CASE WHEN r.share > AVG(r.share) OVER (PARTITION BY r.season)
                THEN 'above league avg' ELSE 'below league avg' END AS three_point_profile,
           h.win_pct,
           LEAD(h.win_pct, 1) OVER (PARTITION BY r.team_id ORDER BY r.season) AS win_pct_next,
           LEAD(h.win_pct, 2) OVER (PARTITION BY r.team_id ORDER BY r.season) AS win_pct_plus2
    FROM team_rate r
    JOIN team_season_history h ON h.team_id = r.team_id AND h.season = r.season
)
SELECT p.three_point_profile,
       s.era_label,
       COUNT(*)                                  AS team_seasons,
       ROUND(100 * AVG(p.win_pct), 1)       AS win_pct_same_season,
       ROUND(100 * AVG(p.win_pct_next), 1)  AS win_pct_next_season,
       ROUND(100 * AVG(p.win_pct_plus2), 1) AS win_pct_two_seasons_later
FROM profiled p
JOIN season s ON s.season = p.season
WHERE p.win_pct_plus2 IS NOT NULL
GROUP BY p.three_point_profile, s.era_label
ORDER BY MIN(s.season_start_year), p.three_point_profile;


-- Q14. Game level: how often does the team that makes more threes win?
--      Each team_game row is joined to its opponent's row for the same
--      game (self-join on the shared game id, team_game_id / 100).
--      Chart: Line. X = season, Y = win_pct_when_more_threes_made.
WITH matchup AS (
    SELECT g.season,
           g.win,
           g.fg3m AS threes_made,
           o.fg3m AS opp_threes_made
    FROM team_game g
    JOIN team_game o
      ON o.team_game_id / 100 = g.team_game_id / 100
     AND o.team_id <> g.team_id
)
SELECT season,
       ROUND(100.0 * AVG(win::INT) FILTER (WHERE threes_made > opp_threes_made), 1)
           AS win_pct_when_more_threes_made,
       ROUND(100.0 * COUNT(*) FILTER (WHERE threes_made = opp_threes_made)
             / COUNT(*), 1) AS pct_games_threes_tied
FROM matchup
GROUP BY season
ORDER BY season;


-- Q15. Best records of the last decade next to their three-point profile.
--      Chart: Table (conditional formatting on win_pct and league_rank_3pa).
WITH ranked AS (
    SELECT ts.team_id,
           ts.season,
           ts.fg3a_per_game,
           ts.fg3_pct,
           RANK() OVER (PARTITION BY ts.season ORDER BY ts.fg3a_per_game DESC) AS league_rank_3pa
    FROM team_season ts
)
SELECT h.season,
       t.team_name,
       h.wins,
       h.losses,
       h.win_pct,
       r.fg3a_per_game,
       ROUND(100 * r.fg3_pct, 1) AS three_point_pct,
       r.league_rank_3pa
FROM team_season_history h
JOIN team t   ON t.team_id = h.team_id
JOIN ranked r ON r.team_id = h.team_id AND r.season = h.season
WHERE h.season >= '2015-16'
ORDER BY h.win_pct DESC
LIMIT 15;
