"""
Export the cached LeagueGameLog JSON (data/raw/gamelog_*.json) to three
clean CSV files that sql/create_and_load.sql loads with COPY:

    data/csv/season.csv      26 rows, one per season
    data/csv/team.csv        one row per NBA team_id seen in the logs
    data/csv/team_game.csv   one row per team per game (~62,500)

Standard library only, so it runs without the project venv:

    python3 -m cleaning.export_csv

Cleaning decisions (document in reports/data_quality_report.md):
  * team_game_id = GAME_ID * 100 + (TEAM_ID - 1610612736). Each game has
    two rows (one per team); this makes a unique, stable surrogate key.
  * is_home is derived from MATCHUP: "DET vs. ATL" = home, "DET @ ATL" = away.
  * opponent_team_id is resolved from the opponent abbreviation in MATCHUP,
    looked up within the same season so reused abbreviations never collide.
  * Rows with no result (WL blank) are dropped: the only case in 2000-2026
    is Celtics vs Pacers on 2013-04-16, cancelled after the Boston
    Marathon bombing and never made up.
  * Neutral-site games (international games, NBA Cup finals) appear as
    "@" for both teams, so both rows get is_home = FALSE. That is correct.
  * franchise_id = team_id for now. Relocations (Seattle -> OKC,
    New Jersey -> Brooklyn) keep the same NBA team_id, so they already
    collapse correctly. Full franchise-history resolution is Phase 3 work.
  * city is left blank: splitting "Portland Trail Blazers" into city and
    nickname is not reliably a last-word split.
  * Era labels are an editorial choice, set in ERAS below.
"""

import csv
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW_DIR = ROOT / "data" / "raw"
OUT_DIR = ROOT / "data" / "csv"

TEAM_ID_BASE = 1610612736
ERAS = [
    (2000, 2008, "pre-revolution"),
    (2009, 2014, "acceleration"),
    (2015, 2025, "post-revolution"),
]
SEASON_NOTES = {
    "2011-12": "Lockout-shortened: 66 games per team",
    "2019-20": "COVID-shortened: season suspended, bubble restart",
    "2020-21": "COVID-shortened: 72 games per team",
}
NEEDED = ["TEAM_ID", "TEAM_ABBREVIATION", "TEAM_NAME", "GAME_ID", "GAME_DATE",
          "MATCHUP", "WL", "FGA", "FGM", "FG3A", "FG3M", "FTA", "FTM", "PTS"]


def era_label(year):
    for low, high, label in ERAS:
        if low <= year <= high:
            return label
    return ""


def as_int(value):
    if value is None or value == "":
        return ""
    return int(float(value))


def main():
    paths = sorted(RAW_DIR.glob("gamelog_*.json"))
    if not paths:
        sys.exit(f"No gamelog files in {RAW_DIR}. Run: python -m ingestion.pull_gamelogs")
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    seasons, teams, games = [], {}, []
    unresolved_opponents = 0
    dropped_unplayed = 0

    for path in paths:
        season = path.stem.replace("gamelog_", "")
        start_year = int(season.split("-")[0])
        seasons.append([season, start_year, era_label(start_year), SEASON_NOTES.get(season, "")])

        result_set = json.loads(path.read_text())["resultSets"][0]
        idx = {h: i for i, h in enumerate(result_set["headers"])}
        missing = [c for c in NEEDED if c not in idx]
        if missing:
            sys.exit(f"{path.name}: expected columns missing: {missing}")
        rows = result_set["rowSet"]
        abbrev_to_id = {r[idx["TEAM_ABBREVIATION"]]: r[idx["TEAM_ID"]] for r in rows}

        for r in rows:
            if not r[idx["WL"]]:
                dropped_unplayed += 1
                continue
            team_id = r[idx["TEAM_ID"]]
            name, abbrev = r[idx["TEAM_NAME"]], r[idx["TEAM_ABBREVIATION"]]
            if team_id in teams:
                # Later seasons win on name, so renamed teams keep their current name.
                teams[team_id].update(name=name, abbrev=abbrev, last=season)
            else:
                teams[team_id] = dict(name=name, abbrev=abbrev, first=season, last=season)

            matchup = r[idx["MATCHUP"]] or ""
            opponent = abbrev_to_id.get(matchup.split()[-1]) if matchup else None
            if opponent is None:
                unresolved_opponents += 1
            wl = r[idx["WL"]]
            games.append([
                int(r[idx["GAME_ID"]]) * 100 + (team_id - TEAM_ID_BASE),
                team_id,
                season,
                r[idx["GAME_DATE"]],
                "@" not in matchup,
                opponent if opponent is not None else "",
                wl == "W",
                as_int(r[idx["FGA"]]), as_int(r[idx["FGM"]]),
                as_int(r[idx["FG3A"]]), as_int(r[idx["FG3M"]]),
                as_int(r[idx["FTA"]]), as_int(r[idx["FTM"]]),
                as_int(r[idx["PTS"]]),
            ])

    def write(name, header, rows):
        with open(OUT_DIR / name, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(header)
            w.writerows(rows)
        print(f"wrote {name:16s} {len(rows):>6} rows")

    write("season.csv", ["season", "season_start_year", "era_label", "notes"], seasons)
    write("team.csv",
          ["team_id", "franchise_id", "team_name", "abbreviation", "city", "active_from", "active_to"],
          [[t, t, v["name"], v["abbrev"], "", v["first"], v["last"]] for t, v in sorted(teams.items())])
    write("team_game.csv",
          ["team_game_id", "team_id", "season", "game_date", "is_home", "opponent_team_id",
           "win", "fga", "fgm", "fg3a", "fg3m", "fta", "ftm", "points"],
          games)
    print(f"dropped {dropped_unplayed} rows for games with no result (never played)")
    if unresolved_opponents:
        print(f"WARNING: {unresolved_opponents} rows with unresolved opponent (left blank)")


if __name__ == "__main__":
    main()
