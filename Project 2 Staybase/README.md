# StayBase / Booking Platform

This package consolidates the database deliverables created in this chat.

## Contents

| File | Purpose |
|---|---|
| `Staybase.sql` | MySQL database, relational tables, keys, checks, indexes, and integrity triggers |
| `staybase_test.sql` | Fixture data and negative tests that expect invalid operations to be rejected |
| `constraints.txt` | Plain-English explanation of each required database rule and its implementation |
| `staybase_chen_er.png` | Chen notation ER/EER conceptual diagram |
| `RELATIONAL_MODEL_PROMPT.txt` | Prompt template to generate/formalize the relational model |
| `CHEN_ER_DIAGRAM_PROMPT.txt` | Prompt template to generate a Chen ER diagram |

## Requirements

- MySQL 8.0.16 or later (for enforced `CHECK` constraints).

## Suggested order

1. Read `constraints.txt`.
2. Create the schema and triggers: `mysql -u root -p < Staybase.sql`.
3. Run the negative constraint tests in a disposable database:
   `mysql -u root -p < booking_platform_tests.sql`.
4. Use `RELATIONAL_MODEL_PROMPT.txt` and `CHEN_ER_DIAGRAM_PROMPT.txt` as
   prompt templates if you need to regenerate the relational model or Chen
   diagram as text deliverables.

## Validation status

The SQL files have not been run against a live MySQL server in this environment.
Run them on your MySQL version and retain the actual test output as evidence;
do not claim database tests passed until they have been executed successfully.
