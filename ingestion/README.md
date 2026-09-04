# Ingestion

One script per endpoint, following the same pattern as `pull_gamelogs.py`:
cache raw JSON to `data/raw/`, skip anything already cached, log and continue
past failures, and rate-limit to `REQUEST_DELAY_SECONDS` (default 1s).

| Script | Endpoint | Target table |
|---|---|---|
| `pull_gamelogs.py` | `LeagueGameLog` | `team_game` |
| `pull_rosters.py` *(todo)* | `CommonTeamRoster` | `roster` |
| `pull_player_info.py` *(todo)* | `CommonPlayerInfo` | `player` |
| `pull_team_stats.py` *(todo)* | `LeagueDashTeamStats` | `team_season` |
| `pull_team_history.py` *(todo)* | `TeamYearByYearStats` | `team_season_history` |
| `pull_franchise_history.py` *(todo)* | `franchisehistory` | `team` |

Run all pulls with:

```bash
python -m ingestion.pull_gamelogs
```
