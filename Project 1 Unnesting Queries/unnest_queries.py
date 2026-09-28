import re
import sys
import time
from pathlib import Path
from dotenv import load_dotenv
from google import genai
from google.genai import types
from google.genai.errors import APIError

load_dotenv()

SYSTEM_PROMPT = """Rewrite this SQL query by replacing all correlated subqueries with standard joins, CTEs, and pre-aggregations.
Return ONLY the SQL code. Do not include markdown code blocks or explanations.
The output must return identical rows in identical order using PostgreSQL syntax."""

HEADER = "-- Unnested query catalog\n-- Generated via Gemini API\n\n"


def parse_queries(src: Path) -> list[tuple[str, str, str]]:
    text = src.read_text(encoding="utf-8")
    queries = []
    qid, desc, sql_lines = None, "", []

    for line in text.splitlines():
        if line.startswith("-- Q"):
            if qid and sql_lines:
                queries.append((qid, desc, "\n".join(sql_lines).strip()))
                sql_lines = []

            header = line.strip()[3:]
            if ":" in header:
                qid, desc = map(str.strip, header.split(":", 1))
            else:
                qid, desc = header.strip(), ""
        elif qid:
            sql_lines.append(line)
            if line.strip().endswith(";"):
                queries.append((qid, desc, "\n".join(sql_lines).strip()))
                qid, desc, sql_lines = None, "", []

    return queries


def get_completed_ids(dst: Path) -> set[str]:
    if not dst.exists():
        dst.write_text(HEADER, encoding="utf-8")
        return set()

    content = dst.read_text(encoding="utf-8")
    return set(re.findall(r"^-- (Q\d+)", content, re.MULTILINE))


def main():
    src = Path("nested_queries.sql")
    dst = Path("unnested_queries.sql")

    if not src.exists():
        sys.exit(f"Error: File not found: {src}")

    queries = parse_queries(src)
    completed = get_completed_ids(dst)
    client = genai.Client()

    for qid, desc, sql in queries:
        if qid in completed:
            continue

        print(f"Processing {qid}...")
        prompt = f"Query {qid}: {desc}\n\nSQL:\n{sql}"
        success = False

        for attempt in range(5):
            try:
                resp = client.models.generate_content(
                    model="gemini-2.5-flash",
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        system_instruction=SYSTEM_PROMPT,
                        temperature=0.0,
                    ),
                )

                sql_out = resp.text.strip()
                block = f"-- {qid} (unnested): {desc}\n{sql_out}\n\n"

                with dst.open("a", encoding="utf-8") as f:
                    f.write(block)

                success = True
                break

            except APIError as err:
                print(f"  Attempt {attempt + 1} failed ({err.code}): retrying in 30s")
                time.sleep(30)

        if not success:
            print(f"  Failed to process {qid}")
            error_block = f"-- {qid} (unnested): {desc}\n-- ERROR: Unnesting failed.\n\n"
            with dst.open("a", encoding="utf-8") as f:
                f.write(error_block)


if __name__ == "__main__":
    main()
