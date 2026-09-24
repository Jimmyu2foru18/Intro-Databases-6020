"""Unnest nested SQL queries via OpenAI API, saving to sql/unnested_queries.sql."""

from openai import OpenAI
import re
from pathlib import Path

SYSTEM = """Rewrite this SQL query by replacing all correlated subqueries with
standard joins, CTEs, and pre-aggregations. Return ONLY the SQL code, no
explanations, no markdown fences. The result must return the same rows
in the same order. Use PostgreSQL-compatible syntax."""

HEADER = """-- Unnested (join-based) query catalog for IMDb schema
-- Generated via OpenAI API as equivalents of nested_queries.sql.
--

"""

def parse(path: Path) -> list[tuple[str, str, str]]:
    text = path.read_text()
    pattern = re.compile(r"-- (Q\d{2}):.*?(?=\n-- Q\d{2}:|\Z)", re.DOTALL)
    out = []
    for m in pattern.finditer(text):
        qid = m.group(1)
        desc_m = re.search(r"-- (Q\d{2}): (.+)\n", m.group(0))
        desc = desc_m.group(2).strip() if desc_m else ""
        sql_m = re.search(r"SELECT.*?;", m.group(0), re.DOTALL)
        if sql_m:
            out.append((qid, desc, sql_m.group(0)))
    return out

def main():
    client = OpenAI()
    queries = parse(Path("sql/nested_queries.sql"))
    parts = [HEADER]
    for qid, desc, sql in queries:
        print(f"  {qid} -> unnesting...")
        resp = client.chat.completions.create(
            model="gpt-4.1",
            messages=[
                {"role": "system", "content": SYSTEM},
                {"role": "user", "content": f"Query {qid}: {desc}\n\nSQL:\n{sql}"},
            ],
            temperature=0,
            max_tokens=4096,
        )
        result = resp.choices[0].message.content.strip()
        parts.append(f"-- Q{qid[1:]} (unnested): {desc}\n{result}\n\n")
    Path("sql/unnested_queries.sql").write_text("".join(parts))
    print(f"Wrote {len(queries)} unnested queries to sql/unnested_queries.sql")

if __name__ == "__main__":
    main()
