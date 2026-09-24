from pathlib import Path
from google import genai
from google.genai import types
from dotenv import load_dotenv
import time
from google.genai.errors import ServerError, ClientError

load_dotenv()

SYSTEM = """Rewrite this SQL query by replacing all correlated subqueries with
standard joins, CTEs, and pre-aggregations. Return ONLY the SQL code, no
explanations, no markdown fences. The result must return the same rows
in the same order. Use PostgreSQL-compatible syntax."""

HEADER = """-- Unnested (join-based) query catalog for IMDb schema
-- Generated via Gemini API as equivalents of nested_queries.sql.
--

"""

def parse(path: Path) -> list[tuple[str, str, str]]:
    text = path.read_text()
    out = []
    current_qid = None
    current_desc = None
    sql_lines = []

    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("-- Q") and stripped[4:6].isdigit():
            if current_qid and sql_lines:
                out.append((current_qid, current_desc, "\n".join(sql_lines).strip()))
                sql_lines = []
            
            header_part = stripped[3:]
            if ":" in header_part:
                current_qid, current_desc = header_part.split(":", 1)
                current_qid = current_qid.strip()
                current_desc = current_desc.strip()
            else:
                current_qid = header_part.strip()
                current_desc = ""
        elif current_qid is not None:
            sql_lines.append(line)
            if stripped.endswith(";"):
                out.append((current_qid, current_desc, "\n".join(sql_lines).strip()))
                current_qid = None
                current_desc = None
                sql_lines = []

    return out

def main():
    print("Starting script...")
    client = genai.Client()
    
    input_path = Path("nested_queries.sql")
    if not input_path.exists():
        print(f"Error: {input_path} not found in the current directory.")
        return

    queries = parse(input_path)
    print(f"Found {len(queries)} queries in nested_queries.sql.")
    
    output_path = Path("unnested_queries.sql")
    completed_ids = set()
    
    if output_path.exists():
        out_text = output_path.read_text()
        for line in out_text.splitlines():
            if line.startswith("-- Q") and "(unnested)" in line:
                tokens = line.split()
                if len(tokens) > 1:
                    completed_ids.add(tokens[1])
    else:
        output_path.write_text(HEADER)
        print("unnested_queries.sql initialized.")

    remaining_queries = []
    for qid, desc, sql in queries:
        normalized_id = f"Q{int(qid.lstrip('Q'))}"
        if qid not in completed_ids and normalized_id not in completed_ids:
            remaining_queries.append((qid, desc, sql))
        else:
            print(f"  Skipping {qid} (already completed)")

    highest_completed = max([int(q.lstrip('Q')) for q in completed_ids]) if completed_ids else 0
    if highest_completed > 0:
        print(f"unnested_queries.sql completed up till Q{highest_completed:02d}, starting at Q{highest_completed + 1:02d} and onwards.")
    else:
        print("Starting fresh processing from Q01.")

    print(f"Remaining queries to process: {len(remaining_queries)}")

    for qid, desc, sql in remaining_queries:
        print(f"  {qid} -> unnesting...")
        prompt = f"Query {qid}: {desc}\n\nSQL:\n{sql}"
        
        for attempt in range(5):
            try:
                resp = client.models.generate_content(
                    model="gemini-3.1-flash-lite",
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        system_instruction=SYSTEM,
                        temperature=0.0,
                        max_output_tokens=4096,
                    )
                )
                result = resp.text.strip()
                block = f"-- Q{qid[1:]} (unnested): {desc}\n{result}\n\n"
                with output_path.open("a", encoding="utf-8") as f:
                    f.write(block)
                print(f"  {qid} completed successfully.")
                break
            except (ServerError, ClientError) as e:
                wait_time = 30
                if isinstance(e, ClientError) and getattr(e, 'code', None) == 429:
                    print(f"  Rate limit hit (Quota exceeded). Waiting 30 seconds before retry...")
                else:
                    print(f"  Server busy or error, retrying in {wait_time} seconds...")
                
                if attempt < 4:
                    time.sleep(wait_time)
                else:
                    print(f"  Skipping {qid} due to persistent errors.")
                    error_block = f"-- Q{qid[1:]} (unnested): {desc}\n-- ERROR: Failed due to rate limit or server error.\n\n"
                    with output_path.open("a", encoding="utf-8") as f:
                        f.write(error_block)

    print("Processing complete. All results saved to unnested_queries.sql")

if __name__ == "__main__":
    main()