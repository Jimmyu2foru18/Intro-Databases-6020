"""Unnest nested SQL queries via DSPy, saving to sql/unnested_queries.sql."""

import re
from pathlib import Path

import dspy


class UnnestSQL(dspy.Signature):
    """Rewrite a SQL query by replacing all correlated subqueries with
    standard joins, CTEs, and pre-aggregations. Return ONLY the SQL code,
    no explanations, no markdown fences. The result must return the same
    rows in the same order. Use PostgreSQL-compatible syntax."""

    nested_sql: str = dspy.InputField(desc="The original SQL query with correlated subqueries")
    unnested_sql: str = dspy.OutputField(desc="The rewritten SQL query with standard joins")


HEADER = """-- Unnested (join-based) query catalog for IMDb schema
-- Generated via DSPy as equivalents of nested_queries.sql.
--

"""


def parse(path: Path) -> list[tuple[str, str, str]]:
    text = path.read_text()
    pattern = re.compile(
        r"-- (?P<qid>Q\d{2}):\s*(?P<desc>[^\n]+)\n.*?(?P<sql>SELECT.*?;)",
        re.DOTALL | re.IGNORECASE,
    )
    out = []
    for match in pattern.finditer(text):
        qid = match.group("qid")
        desc = match.group("desc").strip()
        sql = match.group("sql").strip()
        out.append((qid, desc, sql))
    return out


def main() -> None:
    lm = dspy.OpenAI(model="gpt-4o", max_tokens=4096, temperature=0)
    dspy.settings.configure(lm=lm)

    unnest = dspy.Predict(UnnestSQL)
    queries = parse(Path("sql/nested_queries.sql"))
    parts = [HEADER]

    for qid, desc, sql in queries:
        print(f"  {qid} -> unnesting...")
        result = unnest(nested_sql=sql)
        unnested = result.unnested_sql.strip()
        parts.append(f"-- {qid} (unnested): {desc}\n{unnested}\n\n")

    output_path = Path("sql/unnested_queries.sql")
    output_path.write_text("".join(parts))
    print(f"Wrote {len(queries)} unnested queries to {output_path}")


if __name__ == "__main__":
    main()