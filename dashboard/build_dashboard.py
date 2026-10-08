"""
Rebuild the Phase 3 Metabase dashboard on any machine.

Reads the queries from sql/dashboard_queries.sql and the chart types,
chart settings and layout from dashboard/dashboard_spec.json, then uses the
Metabase REST API to create:
  * a collection "NBA Three Point Revolution" holding one saved question per card
  * a dashboard of the same name with the three section headings, the story
    text above each chart, every card in its saved position, and a Season
    filter wired to Q7 and Q8

Standard library only, so it runs without the project venv:

    python3 dashboard/build_dashboard.py --email you@usfca.edu

It asks for your Metabase password (or reads MB_PASSWORD). Metabase must
already be set up with the Postgres connection (see dashboard/SETUP.md);
pass --connect-db to have the script add that connection for you.
Check what it would build, without touching Metabase:

    python3 dashboard/build_dashboard.py --dry-run
"""
import argparse
import getpass
import json
import os
import pathlib
import re
import sys
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
SQL_FILE = ROOT / "sql" / "dashboard_queries.sql"
SPEC_FILE = ROOT / "dashboard" / "dashboard_spec.json"

PG_DB_NAME = "nba_three_point_revolution"
MB_DB_DISPLAY_NAME = "NBA Three Point Revolution"
SEASONS = [f"{y}-{(y + 1) % 100:02d}" for y in range(2000, 2026)]
SEASON_TAG = {
    "season": {
        "id": "6a1f3c52-9d4e-4b7a-8c21-5e0f2d9b7a11",
        "name": "season",
        "display-name": "Season",
        "type": "text",
        "required": False,
    }
}


def parse_queries(text):
    """Return {query number: SQL} from sql/dashboard_queries.sql (comments dropped)."""
    queries = {}
    for block in re.split(r"\n(?=-- Q\d+\.)", text)[1:]:
        number = int(re.match(r"-- Q(\d+)\.", block).group(1))
        block = re.split(r"\n-- #{10,}", block)[0]
        sql = "\n".join(l for l in block.strip().split("\n") if not l.startswith("--"))
        queries[number] = sql.strip()
    return queries


class Metabase:
    def __init__(self, url):
        self.url = url.rstrip("/")
        self.session = None

    def call(self, method, path, body=None):
        req = urllib.request.Request(self.url + path, method=method)
        req.add_header("Content-Type", "application/json")
        if self.session:
            req.add_header("X-Metabase-Session", self.session)
        data = json.dumps(body).encode() if body is not None else None
        try:
            with urllib.request.urlopen(req, data) as resp:
                raw = resp.read()
        except urllib.error.HTTPError as e:
            sys.exit(f"{method} {path} failed: HTTP {e.code} {e.read().decode()[:300]}")
        except urllib.error.URLError as e:
            sys.exit(f"Cannot reach Metabase at {self.url}: {e.reason}. Is `docker compose up -d` running?")
        return json.loads(raw) if raw else None

    def login(self, email, password):
        self.session = self.call("POST", "/api/session", {"username": email, "password": password})["id"]


def find_database(mb, connect):
    dbs = mb.call("GET", "/api/database")
    dbs = dbs.get("data", dbs)
    for db in dbs:
        if db["engine"] == "postgres" and db.get("details", {}).get("dbname") == PG_DB_NAME:
            return db["id"]
    if not connect:
        sys.exit(f"No Postgres connection to {PG_DB_NAME} in Metabase. Add it (dashboard/SETUP.md, "
                 "step 4) or rerun with --connect-db.")
    db = mb.call("POST", "/api/database", {
        "engine": "postgres",
        "name": MB_DB_DISPLAY_NAME,
        # Local-only defaults from docker-compose.yml. Host is the compose
        # service name and the port is the container side, because Metabase
        # reaches Postgres inside the Docker network.
        "details": {"host": "db", "port": 5432, "dbname": PG_DB_NAME,
                    "user": "postgres", "password": "nba_local_pw", "ssl": False},
    })
    print(f"Added Metabase connection to {PG_DB_NAME} (database id {db['id']})")
    return db["id"]


def build(args):
    spec = json.loads(SPEC_FILE.read_text())
    queries = parse_queries(SQL_FILE.read_text())

    # Resolve each card's SQL first so a broken spec fails before any writes.
    plan = []
    for item in spec["cards"]:
        if "heading" in item or "text" in item:
            plan.append((item, None))
            continue
        key = item["query"]                          # "Q1a", "Q7", ...
        number = int(re.match(r"Q(\d+)", key).group(1))
        if number not in queries:
            sys.exit(f"{key} is in dashboard_spec.json but Q{number} is missing from {SQL_FILE.name}")
        sql = queries[number]
        if item.get("filter") and "{{season}}" not in sql:
            sys.exit(f"Q{number} is wired to the Season filter but has no {{{{season}}}} clause in {SQL_FILE.name}")
        plan.append((item, sql))

    cards = sum(1 for _, sql in plan if sql)
    headings = sum(1 for item, _ in plan if "heading" in item)
    print(f"{cards} cards, {headings} headings, {len(plan) - cards - headings} text blocks, "
          f"{len(queries)} queries parsed")
    if args.dry_run:
        for item, sql in plan:
            if "text" in item:
                label = "text: " + item["text"].replace("**", "")[:60] + "..."
            else:
                label = item.get("heading") or f"{item['name']}  [{item['display']}]"
            flag = "  + Season filter" if item.get("filter") else ""
            print(f"  row {item['row']:>2} col {item['col']:>2} {item['w']:>2}x{item['h']}  {label}{flag}")
        return

    mb = Metabase(args.url)
    email = args.email or input("Metabase email: ")
    password = os.environ.get("MB_PASSWORD") or getpass.getpass("Metabase password: ")
    mb.login(email, password)
    db_id = find_database(mb, args.connect_db)

    existing = [d for d in mb.call("GET", "/api/dashboard") if d["name"] == spec["dashboard"]]
    if existing and not args.replace:
        sys.exit(f"A dashboard named '{spec['dashboard']}' already exists (id {existing[0]['id']}). "
                 "Rerun with --replace to archive it and build a fresh one.")
    for old in existing:
        mb.call("PUT", f"/api/dashboard/{old['id']}", {"archived": True})
        if old.get("collection_id"):
            mb.call("PUT", f"/api/collection/{old['collection_id']}", {"archived": True})
        print(f"Archived old dashboard {old['id']}")

    collection = mb.call("POST", "/api/collection", {
        "name": spec["dashboard"], "description": "Phase 3 dashboard cards (sql/dashboard_queries.sql)"})

    dashcards, next_id = [], -1
    for item, sql in plan:
        base = {"id": next_id, "col": item["col"], "row": item["row"],
                "size_x": item["w"], "size_y": item["h"]}
        next_id -= 1
        if sql is None:
            kind = "heading" if "heading" in item else "text"
            dashcards.append({**base, "card_id": None, "visualization_settings": {
                "virtual_card": {"name": None, "display": kind, "visualization_settings": {},
                                 "dataset_query": {}, "archived": False},
                "text": item[kind]}})
            continue
        card = mb.call("POST", "/api/card", {
            "name": item["name"], "display": item["display"], "collection_id": collection["id"],
            "description": item.get("description"),
            "visualization_settings": item["viz"],
            "dataset_query": {"type": "native", "database": db_id, "native": {
                "query": sql, "template-tags": SEASON_TAG if item.get("filter") else {}}},
        })
        result = mb.call("POST", f"/api/card/{card['id']}/query", {})
        if result.get("error"):
            sys.exit(f"{item['name']} failed to run: {result['error']}")
        print(f"  {item['name']}: {result['row_count']} rows")
        mappings = [{"parameter_id": "season_filter", "card_id": card["id"],
                     "target": ["variable", ["template-tag", "season"]]}] if item.get("filter") else []
        dashcards.append({**base, "card_id": card["id"], "visualization_settings": {},
                          "parameter_mappings": mappings})

    dashboard = mb.call("POST", "/api/dashboard", {
        "name": spec["dashboard"], "description": spec["description"], "collection_id": collection["id"]})
    mb.call("PUT", f"/api/dashboard/{dashboard['id']}", {
        "dashcards": dashcards,
        "parameters": [{"id": "season_filter", "name": "Season", "slug": "season",
                        "type": "string/=", "sectionId": "string", "values_query_type": "list",
                        "values_source_type": "static-list",
                        "values_source_config": {"values": SEASONS}}],
    })
    print(f"Done: {args.url.rstrip('/')}/dashboard/{dashboard['id']}")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--url", default="http://localhost:3000", help="Metabase URL")
    ap.add_argument("--email", help="your Metabase login email")
    ap.add_argument("--connect-db", action="store_true",
                    help="add the Postgres connection if Metabase doesn't have it yet")
    ap.add_argument("--replace", action="store_true",
                    help="archive an existing dashboard of the same name first")
    ap.add_argument("--dry-run", action="store_true", help="print the plan; don't contact Metabase")
    build(ap.parse_args())


if __name__ == "__main__":
    main()
