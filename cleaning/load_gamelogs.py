"""Load cached gamelog JSON into season, team, team_game."""
import json, os, pathlib, sys
import psycopg2
from dotenv import load_dotenv
from psycopg2.extras import execute_values

load_dotenv()
RAW_DIR = pathlib.Path(__file__).resolve().parent.parent / "data" / "raw"
TEAM_ID_BASE = 1610612736
ERAS = [(2000, 2008, "pre-revolution"),
        (2009, 2014, "acceleration"),
        (2015, 2025, "post-revolution")]
NEEDED = ["TEAM_ID", "TEAM_ABBREVIATION", "TEAM_NAME", "GAME_ID",
          "GAME_DATE", "MATCHUP", "WL", "FGM", "FGA", "FG3M", "FG3A",
          "FTM", "FTA", "PTS"]

def era_label(year):
    for lo, hi, label in ERAS:
        if lo <= year <= hi:
            return label
    return None

def as_int(v):
    if v is None or v == "":
        return None
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return None

def connect():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "nba_three_point_revolution"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD", ""))

def build():
    paths = sorted(RAW_DIR.glob("gamelog_*.json"))
    if not paths:
        sys.exit("No gamelog files in data/raw")
    seasons, teams, games = [], {}, []
    for path in paths:
        season = path.stem.replace("gamelog_", "")
        rs = json.loads(path.read_text())["resultSets"][0]
        idx = {h: i for i, h in enumerate(rs["headers"])}
        missing = [c for c in NEEDED if c not in idx]
        if missing:
            sys.exit(f"{path.name}: missing {missing}")
        year = int(season.split("-")[0])
        seasons.append((season, year, era_label(year), None))
        abbrev = {r[idx["TEAM_ABBREVIATION"]]: r[idx["TEAM_ID"]] for r in rs["rowSet"]}
        for r in rs["rowSet"]:
            tid = r[idx["TEAM_ID"]]
            nm, ab = r[idx["TEAM_NAME"]], r[idx["TEAM_ABBREVIATION"]]
            if tid in teams:
                teams[tid][0], teams[tid][1], teams[tid][3] = nm, ab, season
            else:
                teams[tid] = [nm, ab, season, season]
            m = r[idx["MATCHUP"]] or ""
            wl = r[idx["WL"]]
            games.append((int(r[idx["GAME_ID"]]) * 100 + tid - TEAM_ID_BASE,
                tid, season, r[idx["GAME_DATE"]], "@" not in m,
                abbrev.get(m.split()[-1] if m else None),
                True if wl == "W" else (False if wl == "L" else None),
                as_int(r[idx["FGA"]]), as_int(r[idx["FGM"]]),
                as_int(r[idx["FG3A"]]), as_int(r[idx["FG3M"]]),
                as_int(r[idx["FTA"]]), as_int(r[idx["FTM"]]),
                as_int(r[idx["PTS"]])))
    team_rows = [(t, t, n, a, None, f, l) for t, (n, a, f, l) in teams.items()]
    return seasons, team_rows, games

def main():
    seasons, teams, games = build()
    print(f"parsed {len(seasons)} seasons, {len(teams)} teams, {len(games)} games")
    conn = connect()
    try:
        with conn.cursor() as cur:
            execute_values(cur, "INSERT INTO season (season, season_start_year,"
                " era_label, notes) VALUES %s ON CONFLICT (season) DO NOTHING", seasons)
            execute_values(cur, "INSERT INTO team (team_id, franchise_id, team_name,"
                " abbreviation, city, active_from, active_to) VALUES %s"
                " ON CONFLICT (team_id) DO NOTHING", teams)
            execute_values(cur, "INSERT INTO team_game (team_game_id, team_id, season,"
                " game_date, is_home, opponent_team_id, win, fga, fgm, fg3a, fg3m,"
                " fta, ftm, points) VALUES %s ON CONFLICT (team_game_id) DO NOTHING",
                games, page_size=1000)
        conn.commit()
        print("loaded")
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

if __name__ == "__main__":
    main()
