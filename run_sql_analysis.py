"""
DecodeLabs | Data Analytics | Project 3: SQL Data Analysis

What this script does (IPO framework):
    INPUT   Cleaned_Dataset.xlsx (Project 1 output)  ->  loaded into a SQLite table called `orders`
    PROCESS every query in queries.sql is executed against that table
    OUTPUT  orders.db, SQL_Results.xlsx, sql_results.json

It also re-computes the key numbers with pandas and checks that SQL and pandas agree.

Usage (arguments are optional; put the files in the same folder and just run it):
    python run_sql_analysis.py
    python run_sql_analysis.py <Cleaned_Dataset.xlsx> <output_dir>

Needs only: pandas, openpyxl (sqlite3 ships with Python).
"""
import os
import re
import sys
import json
import glob
import sqlite3

import pandas as pd
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

BASE = os.path.dirname(os.path.abspath(__file__))
if len(sys.argv) > 1:
    SRC = sys.argv[1]
else:
    SRC = os.path.join(BASE, "Cleaned_Dataset.xlsx")
    if not os.path.exists(SRC):  # tolerate names like Cleaned_Dataset_xlsx.xlsx or Cleaned_Dataset (1).xlsx
        found = sorted(glob.glob(os.path.join(BASE, "Cleaned_Dataset*.xlsx")))
        if not found:
            raise SystemExit("Cleaned_Dataset.xlsx not found. Put it in this folder: " + BASE)
        SRC = found[0]
        print("Using input file:", SRC)
OUT = sys.argv[2] if len(sys.argv) > 2 else BASE
SQL_FILE = os.path.join(BASE, "queries.sql")
DB_FILE = os.path.join(OUT, "orders.db")
os.makedirs(OUT, exist_ok=True)

# ============================================================ INPUT: Excel -> SQLite
df = pd.read_excel(SRC, sheet_name="Cleaned_Data")
df.columns = [str(c).strip() for c in df.columns]          # guard against stray header spaces
df["Date"] = pd.to_datetime(df["Date"]).dt.strftime("%Y-%m-%d")  # SQLite stores dates as ISO text

SCHEMA = """
CREATE TABLE orders (
    OrderID          TEXT PRIMARY KEY,
    Date             TEXT    NOT NULL,
    CustomerID       TEXT    NOT NULL,
    Product          TEXT    NOT NULL,
    Quantity         INTEGER NOT NULL CHECK (Quantity > 0),
    UnitPrice        REAL    NOT NULL CHECK (UnitPrice > 0),
    ShippingAddress  TEXT,
    PaymentMethod    TEXT    NOT NULL,
    OrderStatus      TEXT    NOT NULL,
    TrackingNumber   TEXT    UNIQUE,
    ItemsInCart      INTEGER,
    CouponCode       TEXT    NOT NULL,
    ReferralSource   TEXT,
    TotalPrice       REAL    NOT NULL
)"""
if os.path.exists(DB_FILE):
    os.remove(DB_FILE)
conn = sqlite3.connect(DB_FILE)
conn.execute(SCHEMA)
cols = [r[1] for r in conn.execute("PRAGMA table_info(orders)")]
assert cols == list(df.columns), f"Column mismatch: {cols} vs {list(df.columns)}"
conn.executemany(f"INSERT INTO orders VALUES ({','.join('?' * len(cols))})", df.itertuples(index=False, name=None))
conn.commit()
n_db = conn.execute("SELECT COUNT(*) FROM orders").fetchone()[0]
print(f"Loaded {n_db:,} rows into orders.db (PRIMARY KEY on OrderID accepted every row)")

# ============================================================ PROCESS: run queries.sql
text = open(SQL_FILE, encoding="utf-8").read()
parts = re.split(r"(?m)^-- @(Q\d+)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*$", text)
queries = []
for i in range(1, len(parts), 4):
    qid, section, title, body = parts[i], parts[i + 1], parts[i + 2], parts[i + 3]
    question = ""
    sql_lines = []
    for line in body.strip().splitlines():
        if line.startswith("-- Business question:"):
            question = line.replace("-- Business question:", "").strip()
        elif line.startswith("-- Expected result:"):
            question += " " + line.replace("-- ", "").strip()
        elif line.strip().startswith("--") and not sql_lines:
            continue
        elif line.strip().startswith("--") and not line.strip().startswith("-- @"):
            continue
        elif line.startswith("-- ====="):
            continue
        else:
            sql_lines.append(line)
    sql = "\n".join(sql_lines).strip()
    queries.append({"id": qid, "section": section, "title": title, "question": question, "sql": sql})

results = {}
for q in queries:
    res = pd.read_sql_query(q["sql"].rstrip(";"), conn)
    results[q["id"]] = res
    print(f"{q['id']}  {len(res):>3} rows  {q['title']}")

# ============================================================ VERIFY: SQL vs independent pandas
raw = pd.read_excel(SRC, sheet_name="Cleaned_Data")
raw.columns = [str(c).strip() for c in raw.columns]
raw["Date"] = pd.to_datetime(raw["Date"])
risk = raw["OrderStatus"].isin(["Cancelled", "Returned"])
h1 = raw[raw["Date"].dt.month <= 6].groupby(raw["Date"].dt.year)["TotalPrice"].sum()
q2, q9, q14, q17, q18, q19, q4 = (results[k] for k in ("Q02", "Q09", "Q14", "Q17", "Q18", "Q19", "Q04"))
checks = [
    ("Total orders", int(q2.loc[0, "total_orders"]), len(raw)),
    ("Unique customers", int(q2.loc[0, "unique_customers"]), raw["CustomerID"].nunique()),
    ("Total order value", float(q2.loc[0, "total_order_value"]), round(raw["TotalPrice"].sum(), 2)),
    ("Average order value", float(q2.loc[0, "avg_order_value"]), round(raw["TotalPrice"].mean(), 2)),
    ("Duplicate OrderIDs (rows returned)", len(results["Q03"]), int(raw["OrderID"].duplicated().sum())),
    ("Orders above IQR fence ($3,330.41)", len(q4), int((raw["TotalPrice"] > 3330.41).sum())),
    ("Repeat customers", len(q17), int((raw["CustomerID"].value_counts() > 1).sum())),
    ("Cancelled + returned order value", float(q9.loc[q9["status_group"].str.startswith("At risk"), "order_value"].iloc[0]),
     round(raw.loc[risk, "TotalPrice"].sum(), 2)),
    ("Cancelled + returned orders", int(q9.loc[q9["status_group"].str.startswith("At risk"), "orders"].iloc[0]), int(risk.sum())),
    ("Median order value", float(q19.loc[0, "median_order_value"]), round(raw["TotalPrice"].median(), 2)),
    ("Orders above average", int(q18.loc[0, "orders_above_average"]), int((raw["TotalPrice"] > raw["TotalPrice"].mean()).sum())),
]
for y in (2023, 2024, 2025):
    checks.append((f"H1 {y} revenue", float(q14.loc[q14["year"] == str(y), "revenue"].iloc[0]), round(h1[y], 2)))
verification = []
for name, sql_v, pd_v in checks:
    ok = abs(float(sql_v) - float(pd_v)) < 0.011
    verification.append({"check": name, "sql_result": sql_v, "pandas_result": pd_v, "match": bool(ok)})
all_ok = all(v["match"] for v in verification)
print(f"\nVerification (SQL vs pandas): {sum(v['match'] for v in verification)}/{len(verification)} match  ->  {'PASS' if all_ok else 'FAIL'}")
if not all_ok:
    for v in verification:
        if not v["match"]:
            print("  MISMATCH:", v)

# ============================================================ OUTPUT: workbook + JSON
HF = Font(name="Arial", bold=True, color="FFFFFF", size=10)
HFILL = PatternFill("solid", start_color="1F3A5F")
BF = Font(name="Arial", size=10)
TF = Font(name="Arial", bold=True, size=13, color="1F3A5F")
NF = Font(name="Arial", italic=True, size=9, color="595959")
thin = Side(style="thin", color="BFBFBF")
BOX = Border(left=thin, right=thin, top=thin, bottom=thin)


def style_table(ws, top, ncols, nrows):
    for j in range(1, ncols + 1):
        c = ws.cell(top, j)
        c.font, c.fill, c.border = HF, HFILL, BOX
        c.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        width = max([len(str(ws.cell(r, j).value or "")) for r in range(top, top + nrows + 1)] + [10])
        ws.column_dimensions[get_column_letter(j)].width = min(width + 3, 46)
    for r in range(top + 1, top + nrows + 1):
        for j in range(1, ncols + 1):
            c = ws.cell(r, j)
            c.font, c.border = BF, BOX
            if isinstance(c.value, float):
                c.number_format = "#,##0.00"


xlsx = os.path.join(OUT, "SQL_Results.xlsx")
with pd.ExcelWriter(xlsx, engine="openpyxl") as xw:
    idx = pd.DataFrame([{"Query": q["id"], "Section": q["section"], "Title": q["title"], "Rows returned": len(results[q["id"]])} for q in queries])
    idx.to_excel(xw, sheet_name="Index", index=False, startrow=2)
    pd.DataFrame(verification).to_excel(xw, sheet_name="Verification", index=False, startrow=2)
    for q in queries:
        results[q["id"]].to_excel(xw, sheet_name=q["id"], index=False, startrow=4)
    wb = xw.book
    ws = wb["Index"]
    ws["A1"], ws["A1"].font = f"SQL Query Index ({len(queries)} queries on table: orders)", TF
    style_table(ws, 3, 4, len(idx))
    ws = wb["Verification"]
    ws["A1"], ws["A1"].font = "Verification: SQL result vs independent pandas calculation", TF
    ws["A2"], ws["A2"].font = "Static values written by run_sql_analysis.py. match = True when the two agree to the cent.", NF
    style_table(ws, 3, 4, len(verification))
    for q in queries:
        ws = wb[q["id"]]
        ws["A1"], ws["A1"].font = f"{q['id']}. {q['title']}", TF
        ws["A2"], ws["A2"].font = q["question"], NF
        ws["A3"], ws["A3"].font = f"Section: {q['section']}", NF
        n = len(results[q["id"]])
        if n:
            style_table(ws, 5, len(results[q["id"]].columns), n)
        else:
            ws["A5"] = "(0 rows returned)"
            ws["A5"].font = BF
out_json = {
    "rows_loaded": n_db,
    "queries": [{**q, "rows": len(results[q["id"]]), "result": json.loads(results[q["id"]].to_json(orient="records"))} for q in queries],
    "verification": verification,
    "all_checks_pass": all_ok,
    "sqlite_version": sqlite3.sqlite_version,
}
with open(os.path.join(OUT, "sql_results.json"), "w", encoding="utf-8") as f:
    json.dump(out_json, f, indent=2, ensure_ascii=False)
conn.close()
print("\nDone. Created: orders.db, SQL_Results.xlsx, sql_results.json")
