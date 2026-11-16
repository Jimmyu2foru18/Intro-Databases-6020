# StayBase / Booking Platform

This package consolidates the database deliverables created in this chat.

## Contents

| File | Purpose |
|---|---|
| `booking_platform.sql` | MySQL database, relational tables, keys, checks, indexes, and integrity triggers |
| `booking_platform_tests.sql` | Fixture data and negative tests that expect invalid operations to be rejected |
| `constraints.txt` | Plain-English explanation of each required database rule and its implementation |
| `IMPORT_INSIDE_AIRBNB.md` | Instructions for obtaining and importing real listing data |
| `import_inside_airbnb.py` | Python importer for the official Inside Airbnb detailed listings CSV/CSV.GZ |
| `requirements.txt` | Python dependency for the importer |
| `DIAGRAMDB_CHEN_GUIDE.md` | Entities, attributes, EER specialization, and relationship cardinalities for the Chen diagram |

## Requirements

- MySQL 8.0.16 or later (for enforced `CHECK` constraints).
- Python 3.10+ recommended for the data importer.
- `mysql-connector-python` for importing the CSV.
- DiagramDB account/site access if you are drawing the conceptual Chen/EER diagram there.

## Suggested order

1. Read `constraints.txt` and `DIAGRAMDB_CHEN_GUIDE.md`.
2. Create the schema and triggers: `mysql -u root -p < booking_platform.sql`.
3. Run the negative constraint tests in a disposable database: `mysql -u root -p < booking_platform_tests.sql`.
4. Download the detailed Inside Airbnb listings CSV.GZ as explained in `IMPORT_INSIDE_AIRBNB.md`.
5. Install the Python dependency: `python -m pip install -r requirements.txt`.
6. Import a small sample first, then the full selected city snapshot.

## Importer example

```bash
python -m pip install -r requirements.txt
python import_inside_airbnb.py data/listings.csv.gz --limit 100 --user root --database booking_platform
```

Then import the full file after verifying the sample:

```bash
python import_inside_airbnb.py data/listings.csv.gz --user root --database booking_platform
```

Set the `MYSQL_PASSWORD` environment variable rather than placing a password in
shell history. The importer defaults to `localhost:3306`, user `root`, and
 database `booking_platform`; override these with its command-line options or
environment variables.

## Real-world data caveats

The importer imports listing metadata and amenities, not bookings, payment
cards, payments, or individual reviews. Imported host users are synthetic local
records based on source host IDs; contact details are placeholders. Source
review aggregates are stored in `imported_listing_source` rather than being
misrepresented as this application's own review rows. Some fields (such as
cleaning fee, cancellation policy, and the bookable date window) use documented
demo defaults because the public listing snapshot does not provide an exact
matching value for the StayBase schema.

Get the detailed listings export and snapshot date from:
https://insideairbnb.com/get-the-data/

Check attribution and license terms:
https://insideairbnb.com/data-policies/

## Validation status

The Python importer passed a local Python syntax compilation check when this
package was assembled. The SQL files have not been run against a live MySQL
server in this environment. Run them on your MySQL version and retain the
actual test output as evidence; do not claim database tests passed until they
have been executed successfully.
