"""Builds reports/phase2_submission.pdf from the screenshots in shots/.
Add a screenshot: drop the PNG in shots/ and fill its filename in SECTIONS."""
import pathlib
from PIL import Image as PILImage
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (Image, KeepTogether, PageBreak, Paragraph,
                                SimpleDocTemplate, Spacer, Table, TableStyle)

HERE = pathlib.Path(__file__).parent
SHOTS = HERE / "shots"
OUT = HERE / "phase2_submission.pdf"

ss = getSampleStyleSheet()
H1 = ParagraphStyle("H1", parent=ss["Heading1"], fontSize=15, spaceBefore=6, spaceAfter=6,
                    textColor=colors.HexColor("#1F3A5F"))
H2 = ParagraphStyle("H2", parent=ss["Heading2"], fontSize=12, spaceBefore=10, spaceAfter=4)
BODY = ParagraphStyle("B", parent=ss["BodyText"], fontSize=10, leading=14)
CAP = ParagraphStyle("C", parent=BODY, fontSize=9, textColor=colors.HexColor("#555555"))
PEND = ParagraphStyle("P", parent=BODY, textColor=colors.HexColor("#B00020"))

MAX_W, MAX_H = 6.5 * inch, 5.6 * inch


def shot(name):
    path = SHOTS / name
    w, h = PILImage.open(path).size
    scale = min(MAX_W / w, MAX_H / h)
    return Image(str(path), width=w * scale, height=h * scale)


# (heading, explanation, screenshot filename or None if still to capture)
SECTIONS = [
    ("PART 1. Database and tables in PostgreSQL", None, None),
    ("1.1 Data loaded: row counts",
     "Result of the final validation query in Part B of create_and_load.sql, run in pgAdmin. "
     "All five populated tables match expectations. team_season and team_season_history have 776 "
     "rows rather than 780 because the league had 29 teams until the Charlotte Bobcats joined in "
     "2004-05. problem_games = 0 confirms every game has exactly two team rows, one winner and at "
     "most one home team. player and roster are created with their keys but are loaded in Phase 3.",
     "01_row_counts.png"),
    ("1.2 The seven tables in pgAdmin",
     "Schema nba_three_point_revolution.public after running the script.",
     "02_tables.png"),
    ("PART 2. Understanding the data with SQL", None, None),
    ("2.1 The three-point curve (query C1)",
     "Share of all field-goal attempts taken from three, by season. It rises from 17.0% in 2000-01 "
     "to 41.5% in 2025-26, with the steepest climb after 2014-15.",
     "03_c1_curve.png"),
    ("2.2 Volume changed, accuracy did not (query C2)",
     "League three-point percentage stays between 35.5% and 35.9% across all three eras while the "
     "share of shots from three nearly doubles. Teams did not get better at threes; they chose to "
     "take many more.",
     "04_c2_eras.png"),
    ("2.3 Who moved first (query C3)",
     "Top three teams by three-point rate each season (window function RANK), 78 rows in total. Boston "
     "led the early 2000s and Phoenix took over in 2004-05. Further down the result, Orlando leads "
     "2007-08 to 2011-12 and Houston leads 2013-14 to 2019-20, taking more than half its shots from "
     "three in 2017-18 and 2018-19. Relocated franchises appear under their current name because the "
     "same team_id was kept, so 2003-04 shows Oklahoma City for the Seattle SuperSonics.",
     "05_c3_first_movers.png"),
    ("2.4 Three-point volume and accuracy against winning (query C4)",
     "Per-season correlation between a team's three-point attempts per game and its win "
     "percentage, and between three-point accuracy and win percentage. Accuracy correlates with "
     "winning more strongly than volume in 25 of the 26 seasons.",
     "06_c4_correlation.png"),
    ("2.5 Best records since 2015-16 (query C5)",
     "The 15 best regular-season records since 2015-16 with each team's three-point profile, "
     "joining team_season_history, team and team_season. Every team on the list attempts at least "
     "18 threes a game, and 13 of the 15 attempt more than 30.",
     "07_c5_best_records.png"),
    ("2.6 Home-court advantage over time (query C6)",
     "Home win percentage by season. 2011-12 has 990 games (lockout) and 2012-13 has 1,229 because "
     "one game was cancelled after the Boston Marathon bombing and dropped during cleaning.",
     "08_c6_home_court.png"),
    ("PART 3. Metabase", None, None),
    ("3.1 Metabase running in Docker, with our tables",
     "Metabase served by the nba_metabase Docker container at localhost:3000 (address bar). "
     "Browse, Databases, NBA Three Point Revolution lists all seven tables synced from PostgreSQL.",
     "09_metabase_tables.png"),
    ("3.2 Metabase connected to PostgreSQL",
     "Admin settings, Databases: the NBA Three Point Revolution PostgreSQL database shows status "
     "Connected. Metabase reaches Postgres over the Docker network at host db, port 5432.",
     "10_metabase_connected.png"),
    ("3.3 A question built on the data",
     "Native SQL question in Metabase against team_game, shown as a line chart: the share of shots "
     "from three rises from 17.0% in 2000-01 to a peak of 42.1% in 2024-25.",
     "11_metabase_chart.png"),
]


def build():
    story = [
        Paragraph("From Inside Game to Outside Game", ParagraphStyle(
            "T", parent=ss["Title"], fontSize=20, textColor=colors.HexColor("#1F3A5F"))),
        Paragraph("Tracing the NBA's Three-Point Revolution, 2000-01 to 2025-26", ss["Heading3"]),
        Spacer(1, 6),
        Paragraph("DSAI 691 Relational Databases, Group Project Phase 2: "
                  "Populate PostgreSQL and Install Metabase", BODY),
        Paragraph("Team: Aditya Verma, Angela Wei, Disha Khati, Gursimrat Grewal, Yash Tiwari", BODY),
        Spacer(1, 10),
    ]
    summary = [
        ["Deliverable", "Where"],
        ["Database and tables created", "create_and_load.sql Part A and B; section 1"],
        ["Data imported with COPY", "create_and_load.sql Part B; section 1.1"],
        ["Understanding the data with SQL", "create_and_load.sql Part C; section 2"],
        ["Metabase installed on Docker", "docker-compose.yml; section 3.1"],
        ["Metabase connected to PostgreSQL", "sections 3.2 and 3.3"],
    ]
    t = Table(summary, colWidths=[2.8 * inch, 3.7 * inch])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1F3A5F")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 9),
        ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#BBBBBB")),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#F2F5F9")]),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))
    story += [t, Spacer(1, 10), Paragraph(
        "Data source: stats.nba.com LeagueGameLog via the nba_api Python client, 26 seasons, "
        "62,508 team-game rows after cleaning. Raw JSON is exported to CSV by "
        "cleaning/export_csv.py and loaded with COPY; CSV files are not submitted.", BODY)]

    for heading, text, image in SECTIONS:
        if text is None:
            story += [PageBreak(), Paragraph(heading, H1)]
            continue
        block = [Paragraph(heading, H2), Paragraph(text, BODY), Spacer(1, 4)]
        if image:
            block += [shot(image)]
        else:
            block += [Paragraph("[Screenshot to be added]", PEND)]
        story.append(KeepTogether(block + [Spacer(1, 8)]))

    SimpleDocTemplate(str(OUT), pagesize=letter, leftMargin=inch, rightMargin=inch,
                      topMargin=0.8 * inch, bottomMargin=0.8 * inch,
                      title="DSAI 691 Phase 2 Submission").build(story)
    pending = [h for h, t, i in SECTIONS if t and not i]
    print(f"built {OUT.name}; pending screenshots: {len(pending)}")


if __name__ == "__main__":
    build()
