"""
Pull LeagueGameLog for every season 2000-01 through 2025-26.

Raw JSON is cached to data/raw/ so a re-run never re-pulls a season that
already succeeded. Failures are logged and skipped rather than aborting
the whole run — see docs/project_plan.pdf, "Unreliable delivery".
"""

import json
import os
import pathlib
import time

from dotenv import load_dotenv
from nba_api.stats.endpoints import leaguegamelog

load_dotenv()

RAW_DIR = pathlib.Path(__file__).resolve().parent.parent / "data" / "raw"
RAW_DIR.mkdir(parents=True, exist_ok=True)

REQUEST_DELAY = float(os.getenv("REQUEST_DELAY_SECONDS", "1.0"))
START_YEAR = 2000
END_YEAR = 2025  # last season start year -> 2025-26


def season_str(year: int) -> str:
    return f"{year}-{str(year + 1)[-2:]}"


def pull_season(season: str, timeout: int = 60) -> bool:
    path = RAW_DIR / f"gamelog_{season}.json"
    if path.exists():
        print(f"skip  {season} (cached)")
        return True
    try:
        resp = leaguegamelog.LeagueGameLog(season=season, timeout=timeout)
        path.write_text(json.dumps(resp.get_dict()))
        print(f"ok    {season}")
        return True
    except Exception as exc:  # noqa: BLE001 - log and continue
        print(f"FAILED {season}: {exc}")
        return False


def main() -> None:
    results = {}
    for year in range(START_YEAR, END_YEAR + 1):
        season = season_str(year)
        results[season] = pull_season(season)
        time.sleep(REQUEST_DELAY)

    failed = [s for s, ok in results.items() if not ok]
    print(f"\nDone. {len(results) - len(failed)}/{len(results)} seasons cached.")
    if failed:
        print(f"Failed seasons (re-run to retry): {failed}")


if __name__ == "__main__":
    main()
