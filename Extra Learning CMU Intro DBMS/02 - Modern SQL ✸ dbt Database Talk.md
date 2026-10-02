## SQL, Nested Queries, CTEs, Window Functions & DBT

## 1. Date and Time Functions

SQL date/time operations can behave differently across database systems.

### Important idea

**SQL is standardized, but individual database systems do not always implement every function the same way.**

For example:

* PostgreSQL may support a particular date-difference function.
* SQLite may not support that same function.
* MySQL, SQL Server, DuckDB, PostgreSQL, etc. may use different syntax.

Therefore:

> **Never assume that a date function available in one DBMS works identically in another.**

---

## 2. Calculating Date Differences in SQLite

SQLite does not provide the same `DATEDIFF` functionality used by some other systems.

One approach is to convert timestamps into **Julian day numbers**.

Conceptually:

```sql
julianday(timestamp2) - julianday(timestamp1)
```

This produces the number of days between the two timestamps.

### Example

If the difference is approximately:

```text
238.75 days
```

and you want only the whole number of days, you can convert/cast the result to an integer.

```sql
CAST(julianday(date2) - julianday(date1) AS INTEGER)
```

Result:

```text
238
```

### Another approach: Unix Epoch

A Unix timestamp represents time as the number of seconds since:

```text
January 1, 1970
```

You can convert timestamps to Unix-epoch values and then perform arithmetic.

For example:

```text
difference in seconds
---------------------
60 seconds/minute
60 minutes/hour
24 hours/day
```

This can be used to calculate a difference in days.

### Key lesson

Date calculations are a common source of mistakes because:

1. Different DBMSs use different functions.
2. Dates and timestamps may have different types.
3. Results may be decimals.
4. Type conversion/casting may be necessary.

### Exam reminder

If a question asks you to calculate dates:

**Check which database system you are using first.**

---

# 3. Output Control

The relational model is fundamentally **unordered**.

If you want SQL results in a particular order, you must explicitly specify that order.

---

## `ORDER BY`

Use `ORDER BY` to sort query results.

```sql
SELECT *
FROM Student
ORDER BY name;
```

Descending order:

```sql
SELECT *
FROM Student
ORDER BY name DESC;
```

### Important

Without `ORDER BY`, you should **not assume a particular row order**.

Even if a DBMS happens to return rows in a particular order, that order is not necessarily guaranteed.

---

# 4. `LIMIT` and `OFFSET`

Sometimes you do not want every row.

You may want:

* the first 5 rows
* the first 10 rows
* rows 11–20
* a particular page of results

### `LIMIT`

Example:

```sql
SELECT *
FROM Student
LIMIT 5;
```

Means:

> Return at most 5 rows.

### `OFFSET`

```sql
SELECT *
FROM Student
LIMIT 5 OFFSET 10;
```

Conceptually:

> Skip the first 10 rows and return the next 5.

This is useful for pagination.

---

## SQL Standard vs DBMS-Specific Syntax

`LIMIT` is widely supported, but it is not the standard syntax used by every DBMS.

Different systems can have different approaches.

For example:

```sql
LIMIT 10
```

Some systems use alternatives such as:

```sql
FETCH FIRST 10 ROWS ONLY
```

SQL Server commonly uses:

```sql
TOP 10
```

### Main lesson

> **SQL syntax can vary between database systems.**

---

# 5. Using Query Results as Tables

Sometimes one SQL query produces a result that you want to use in another query.

Instead of sending the result back to the application and then running another query, SQL can allow the result to be used as a table.

This can be done using:

* temporary tables
* nested queries
* CTEs
* derived tables

---

# 6. Nested Queries / Subqueries

A **nested query**, also called a **subquery**, is a SQL query inside another SQL query.

General structure:

```sql
SELECT ...
FROM ...
WHERE ... (
    SELECT ...
);
```

The outer query uses the result produced by the inner query.

### Terminology

```text
Outer query
    ↓
Inner query / subquery
```

---

## Where Can Subqueries Appear?

Subqueries can appear in several places, including:

### `WHERE`

```sql
SELECT name
FROM Student
WHERE sid IN (
    SELECT sid
    FROM Enrolled
    WHERE cid = 445
);
```

### `FROM`

A query can produce a temporary/derived table that another query uses.

### `SELECT`

A subquery can sometimes produce a value used in the output.

### Other clauses

Some database systems also allow subqueries in other parts of a SQL statement.

---

# 7. Why Nested Queries Can Be Expensive

A naive way to execute a nested query would be:

```text
For every row in outer query:
    Run the entire inner query
```

This is similar to nested loops:

```text
FOR each student
    RUN inner query
```

If there are millions of rows, this can become extremely expensive.

### Better possibility

A DBMS may be able to:

1. Execute the inner query once.
2. Save/cache its result.
3. Reuse that result.
4. Or rewrite the nested query as a join.

### Important concept

Database systems have **query optimizers** that try to transform SQL into more efficient execution plans.

---

# 8. Subquery vs Join

A nested query can sometimes be rewritten as a join.

For example:

```sql
SELECT name
FROM Student
WHERE sid IN (
    SELECT sid
    FROM Enrolled
    WHERE cid = 445
);
```

The database may be able to transform this into an equivalent join.

The exact performance depends on:

* database system
* indexes
* table sizes
* query structure
* optimizer capabilities
* data distribution

### Important

There is **not always one universally fastest SQL formulation**.

Different DBMSs may optimize equivalent queries differently.

---

# 9. `IN` and Set Membership

`IN` is used to test whether a value belongs to a set of values.

Example:

```sql
WHERE sid IN (
    SELECT sid
    FROM Enrolled
    WHERE cid = 445
)
```

Read this as:

> Find students whose `sid` is in the set of student IDs returned by the inner query.

### Conceptual example

Inner query:

```text
{10, 15, 22, 31}
```

Outer query:

```sql
WHERE sid IN (10, 15, 22, 31)
```

Only students with those IDs match.

---

# 10. Example — Students in Course 445

### Question

> Find the names of students enrolled in course 445.

### Step 1 — Determine the desired output

We want:

```sql
SELECT name
FROM Student
```

### Step 2 — Determine the condition

We only want students whose IDs appear in the enrollment records for course 445.

### Step 3 — Write the inner query

```sql
SELECT sid
FROM Enrolled
WHERE cid = 445
```

### Step 4 — Connect the queries

```sql
SELECT name
FROM Student
WHERE sid IN (
    SELECT sid
    FROM Enrolled
    WHERE cid = 445
);
```

### How to think about it

```text
Student
   |
   | sid IN
   ↓
Students enrolled in 445
```

---

# 11. Other Subquery Operators

SQL provides several ways to compare values with subquery results.

Common examples include:

### `IN`

Matches if the value appears in the result set.

```sql
WHERE sid IN (...)
```

### `NOT IN`

Matches if the value does not appear in the result set.

```sql
WHERE sid NOT IN (...)
```

### `ANY`

Matches if a comparison is true for at least one value.

### `ALL`

Requires a comparison to be true for all values.

### `EXISTS`

Checks whether the subquery produces at least one row.

```sql
WHERE EXISTS (...)
```

### `NOT EXISTS`

Checks whether the subquery produces no rows.

```sql
WHERE NOT EXISTS (...)
```

---

# 12. Example — Highest-ID Student Enrolled in a Course

### Question

> Find the student record with the highest student ID among students enrolled in at least one course.

One approach is:

```sql
SELECT sid, name
FROM Student
WHERE sid = (
    SELECT MAX(sid)
    FROM Enrolled
);
```

### Inner query

```sql
SELECT MAX(sid)
FROM Enrolled
```

Produces the highest student ID appearing in `Enrolled`.

### Outer query

Find the student whose ID equals that value.

---

## Alternative Approaches

The same logical result might be obtained using:

* `MAX()`
* sorting
* `ORDER BY`
* `LIMIT`
* a join
* a CTE

Example concept:

```sql
ORDER BY sid DESC
LIMIT 1
```

### Key point

SQL often provides **multiple ways to express the same logical question**.

---

# 13. Correlated Subqueries

A **correlated subquery** is a subquery that references a value from the outer query.

This means:

> The inner query depends on the current row of the outer query.

### Conceptual structure

```sql
SELECT ...
FROM Course c
WHERE EXISTS (
    SELECT ...
    FROM Enrolled e
    WHERE e.cid = c.cid
);
```

Notice:

```text
e.cid = c.cid
       ↑
       Outer query
```

The inner query references `c.cid` from the outer query.

---

# 14. Correlated vs Non-Correlated Subqueries

### Non-correlated

The inner query can be evaluated independently.

```sql
SELECT sid
FROM Enrolled
WHERE cid = 445
```

It does not depend on the current row of the outer query.

### Correlated

The inner query depends on the outer row.

```sql
WHERE EXISTS (
    SELECT *
    FROM Enrolled e
    WHERE e.cid = c.cid
)
```

The value of `c.cid` changes as the outer query processes different courses.

---

# 15. Example — Courses With No Students

### Question

> Find courses that have no students enrolled.

One conceptual solution uses `NOT EXISTS`:

```sql
SELECT *
FROM Course c
WHERE NOT EXISTS (
    SELECT *
    FROM Enrolled e
    WHERE e.cid = c.cid
);
```

### How it works

For each course:

1. Look at the current course.
2. Search `Enrolled`.
3. Check whether a matching `cid` exists.
4. If one exists → do not return the course.
5. If none exists → return the course.

This is a **correlated subquery** because:

```sql
e.cid = c.cid
```

connects the inner query to the current outer row.

---

# 16. Lateral Joins

A **lateral join** allows a query on one side to reference values produced by another query at the same level.

Think of it conceptually as:

```text
Query A
   ↓
Query B can use Query A's result
```

This creates a dependency between the queries.

### Why this is interesting

Normally, SQL tries to avoid requiring a particular execution order.

A lateral operation introduces a dependency:

> The previous query must produce something that the later query needs.

---

# 17. Lateral Join Example

Suppose we want information about each course and then want to run another query using that particular course.

Conceptually:

```sql
SELECT *
FROM Course c
LATERAL ...
```

The inner/lateral query can reference:

```sql
c.cid
```

from the outer course row.

---

# 18. Example — Enrollment Count and Average GPA

Suppose we want:

* course
* number of enrolled students
* average GPA of enrolled students
* sorted by enrollment count

Conceptually:

```text
Course
   |
   +--> Count enrolled students
   |
   +--> Calculate average GPA
```

The lateral queries can reference the current course.

### Important idea

Lateral joins are useful when a later query needs to be evaluated using values from the current row of an earlier query.

---

# 19. CTE — Common Table Expression

**CTE = Common Table Expression**

A CTE allows you to define a temporary named result inside a SQL statement.

Basic syntax:

```sql
WITH cte_name AS (
    SELECT ...
)
SELECT ...
FROM cte_name;
```

Think of it as:

> **Create a temporary named result, then use it in the rest of the query.**

---

# 20. Why Use a CTE?

CTEs can make complicated SQL easier to understand.

Instead of:

```text
Large query
    └── nested query
         └── another nested query
              └── another query
```

you can organize the logic:

```text
WITH step1 AS (...)
WITH step2 AS (...)
SELECT ...
```

This makes the intermediate results easier to identify.

---

# 21. CTE Example

```sql
WITH highest_student AS (
    SELECT MAX(sid) AS max_sid
    FROM Enrolled
)
SELECT s.sid, s.name
FROM Student s
JOIN highest_student h
  ON s.sid = h.max_sid;
```

### Step 1

The CTE calculates:

```sql
MAX(sid)
```

### Step 2

The outer query treats `highest_student` like a table.

### Step 3

The result is joined to `Student`.

---

# 22. CTE vs Temporary Table

### Temporary table

A temporary table may exist independently of the query and can potentially be used by multiple statements.

### CTE

A CTE exists within the scope of the SQL statement.

Conceptually:

```text
WITH CTE
   ↓
Main query
   ↓
CTE disappears after statement
```

This makes CTEs useful for organizing complex queries without manually creating and deleting temporary tables.

---

# 23. CTE vs Nested Query

Both can express similar logic.

### Nested query

```sql
SELECT ...
FROM Student
WHERE sid = (
    SELECT MAX(sid)
    FROM Enrolled
);
```

### CTE

```sql
WITH highest AS (
    SELECT MAX(sid) AS sid
    FROM Enrolled
)
SELECT s.*
FROM Student s
JOIN highest h
  ON s.sid = h.sid;
```

### Main difference

A nested query embeds the logic where it is needed.

A CTE defines the logic **up front** and gives it a name.

---

# 24. Window Functions

Window functions are used when you want to perform calculations across related rows **without collapsing those rows into a single result**.

This is one of the most important differences between:

### `GROUP BY`

and

### Window functions

---

## `GROUP BY`

Aggregation usually reduces multiple rows into fewer rows.

Example:

```sql
SELECT cid, COUNT(*)
FROM Enrolled
GROUP BY cid;
```

You get approximately:

```text
Course   Count
------   -----
101       25
102       31
103       18
```

One row per course.

---

## Window Function

A window function can calculate information about a group while **keeping the individual rows**.

Example:

```sql
SELECT *,
       ROW_NUMBER() OVER ()
FROM Enrolled;
```

Every enrollment row remains.

A new column is added:

```text
sid    cid    row_number
---    ---    ----------
10     101       1
15     101       2
22     102       3
31     102       4
...
```

---

# 25. `OVER`

Window functions use the `OVER` clause.

General structure:

```sql
function() OVER (...)
```

Example:

```sql
ROW_NUMBER() OVER ()
```

The `OVER` clause specifies the window over which the function operates.

---

# 26. `PARTITION BY`

`PARTITION BY` divides the rows into groups for the window function.

Example:

```sql
ROW_NUMBER() OVER (
    PARTITION BY cid
)
```

This means:

> Number the rows separately for each course.

Instead of one continuous sequence:

```text
1
2
3
4
5
6
```

the numbering resets for each course:

```text
Course 101:
1
2
3

Course 102:
1
2
3

Course 103:
1
2
```

### Important

`PARTITION BY` in a window function is conceptually similar to grouping, but it **does not collapse the rows**.

---

# 27. `ORDER BY` Inside a Window

You can also specify an order within the window.

Example:

```sql
ROW_NUMBER() OVER (
    PARTITION BY cid
    ORDER BY sid
)
```

Meaning:

1. Divide rows by course.
2. Sort students by ID within each course.
3. Assign row numbers.

Example:

```text
cid    sid    row_number
---    ---    ----------
101     10        1
101     15        2
101     22        3
102      5        1
102     17        2
102     31        3
```

---

# 28. Common Window Functions

### `ROW_NUMBER()`

Assigns a unique sequential number to rows within a window.

```sql
ROW_NUMBER() OVER (...)
```

### `RANK()`

Assigns ranks according to an ordering.

Ties can receive the same rank.

### Aggregate window functions

You can use familiar aggregate functions as window functions:

```sql
COUNT()
SUM()
AVG()
MIN()
MAX()
```

For example:

```sql
AVG(gpa) OVER (...)
```

---

# 29. Moving Averages

Window functions are especially useful for time-series data.

Suppose we record temperature:

```text
Time       Temperature
08:00      70
09:00      72
10:00      75
11:00      77
12:00      80
```

A moving average can calculate an average over a nearby group of observations.

This can also be used for:

* stock prices
* sales
* website traffic
* sensor measurements
* temperatures
* financial data

### Main idea

Window functions allow calculations that depend on **position/order** while still keeping individual rows.

---

# 30. `GROUP BY` vs Window Functions

| Feature                        | `GROUP BY` | Window Function         |
| ------------------------------ | ---------- | ----------------------- |
| Creates groups                 | Yes        | Yes, through partitions |
| Keeps individual rows          | Usually no | Yes                     |
| Produces one result per group  | Yes        | No                      |
| Can calculate ranking          | No         | Yes                     |
| Can use `ROW_NUMBER()`         | No         | Yes                     |
| Useful for moving calculations | Limited    | Yes                     |
| Uses `OVER`                    | No         | Yes                     |

### Easy way to remember

**GROUP BY = collapse rows**

**Window function = keep rows + add calculations**

---

# 31. Important SQL Concepts From Video 3

## Relational Model

The relational model represents data as relations/tables.

It separates:

```text
What the data means
        from
How the data is physically stored
```

---

## Declarative SQL

SQL generally describes:

> **What result do I want?**

rather than:

> **Exactly what steps should the computer perform?**

This gives the DBMS freedom to optimize the query.

---

## Query Optimizer

The DBMS can potentially:

* reorder operations
* use indexes
* transform subqueries into joins
* reduce intermediate results
* choose different execution strategies

The goal is to produce the requested result efficiently.

---

# 32. Query Optimization Example

Suppose:

```text
Table R = 1 trillion rows
Table S = 1 trillion rows
```

You need only 5 rows from S.

### Bad conceptual order

```text
R
↓
Join with huge S
↓
Filter S
```

This could create an enormous amount of unnecessary work.

### Better conceptual order

```text
S
↓
Filter to 5 rows
↓
Join with R
```

The DBMS can potentially choose the more efficient strategy.

### Why SQL helps

You write:

```sql
SELECT ...
FROM ...
WHERE ...
```

The optimizer determines an execution plan.

---

# 33. Why Declarative SQL Matters

Data sizes and distributions change.

A strategy that worked well when a table contained:

```text
1,000 rows
```

may be terrible when it contains:

```text
1,000,000,000 rows
```

If the application hardcodes the physical execution strategy, the application may become inefficient as the data changes.

With declarative SQL:

```text
Application
     ↓
"What result do I want?"
     ↓
SQL
     ↓
Query Optimizer
     ↓
Execution Plan
```

The DBMS can adapt the physical execution strategy.

---

# 34. DBT — What Is It?

The second part of the lecture introduces **dbt (data build tool)**.

Important:

> **dbt is not a database.**

It is also not itself a data warehouse.

Instead, dbt helps teams **transform, organize, test, document, and manage data inside their existing data warehouses**.

---

# 35. Modern Data Architecture

A typical data environment may have many data sources:

```text
Transactional databases
Advertising
Payments
Finance
Sales
Customer support
Telemetry
        ↓
   Extract / Load
        ↓
Data Warehouse / Data Lake
        ↓
   Transformations
        ↓
Business-ready data
        ↓
BI / Analytics / AI / ML / Applications
```

Examples of data warehouses mentioned:

* Snowflake
* BigQuery
* Redshift
* Databricks

dbt works with these systems rather than replacing them.

---

# 36. The Problem dbt Addresses

Organizations can accumulate hundreds or thousands of tables.

Without good organization, problems can include:

### Data lineage problems

It becomes difficult to determine:

> Where did this data come from?

### Documentation problems

People may not know:

* what a table means
* what columns mean
* whether a table already exists

### Deployment problems

People may directly modify production data systems.

### Quality problems

Data may be incorrect or broken without automated checks.

### Duplicated business logic

Different dashboards or teams may independently implement the same business definition.

For example:

```text
"What counts as a customer?"
```

could be calculated differently in 20 different places.

That creates inconsistent results.

---

# 37. Raw Data vs Transformed Data

A common architecture separates:

### Raw data

Data loaded directly from sources.

Examples:

```text
Salesforce
PostgreSQL
Payments
Advertising
```

### Transformed data

Data that has been cleaned and transformed into business-friendly datasets.

Conceptually:

```text
RAW DATA
   ↓
Staging
   ↓
Intermediate transformations
   ↓
Business models
   ↓
BI / Analytics
```

---

# 38. dbt's Transformation Layer

dbt helps create transformations between raw data and business-facing data.

For example:

```text
Raw customer data
        ↓
Clean columns
        ↓
Remove invalid records
        ↓
Apply business rules
        ↓
Customer model
        ↓
Dashboard
```

The result is a higher-level abstraction that is easier for analysts and business users to query.

---

# 39. dbt Uses SQL

A dbt model is fundamentally based on SQL.

For example:

```sql
SELECT *
FROM some_source;
```

dbt then uses that SQL definition to build a table or view in the data warehouse.

---

# 40. Version Control

One major benefit of dbt is that transformation logic can be treated like software code.

The SQL can be stored in:

```text
Git
```

This enables:

* version history
* collaboration
* code review
* branching
* controlled deployment
* rollback

Instead of having undocumented SQL sitting directly in production.

---

# 41. Data Lineage

**Data lineage** describes where data comes from and how it flows through transformations.

Example:

```text
Raw Source
    ↓
Staging Model
    ↓
Customer Model
    ↓
Business Model
    ↓
Dashboard
```

This allows someone to trace:

> "Where did this dashboard's data come from?"

---

# 42. Dependency Graph

dbt can represent transformations as a dependency graph.

Example:

```text
Source A ──┐
           ↓
       Staging A
           ↓
     Intermediate
        ↙     ↘
   Model A    Model B
        \      /
         ↓    ↓
       Final Model
           ↓
       Dashboard
```

Each node can represent a data source, model, table, or view.

The dependency relationships tell dbt what must be built before something else.

---

# 43. dbt Models

A model is essentially a SQL transformation that dbt manages.

For example:

```sql
SELECT
    customer_id,
    name,
    email
FROM raw_customers
WHERE deleted = FALSE;
```

dbt can materialize the result as:

* a table
* a view
* or other supported materialization strategies

---

# 44. Staging Models

A **staging model** is often an early transformation layer.

Typical tasks include:

* renaming columns
* filtering invalid records
* standardizing values
* handling deleted records
* preparing raw data for later transformations

Conceptually:

```text
Raw Source
    ↓
Staging
    ↓
Intermediate
    ↓
Final Business Model
```

---

# 45. Templating

dbt adds a templating language called **Jinja**.

This allows SQL projects to include programming-like features such as:

* variables
* loops
* reusable logic
* dynamic SQL generation

This is different from ordinary SQL itself.

### Key distinction

```text
SQL
↓
Defines data transformation

Jinja
↓
Helps generate/control SQL
```

---

# 46. Testing Data

dbt can be used to create assertions about data.

For example:

```text
invoice_id should:
    ✓ be unique
    ✓ not be NULL
```

If the assumption fails, the data test can identify the problem.

This is similar to software testing:

```text
Software:
    test that code behaves correctly

Data:
    test that data satisfies expected rules
```

---

# 47. Data Quality

Data quality tests can help detect:

* duplicate IDs
* NULL values where they should not exist
* unexpected relationships
* invalid values
* broken assumptions

Example:

```text
invoice_id
-----------
101
102
103
103  ← duplicate
```

If `invoice_id` is supposed to be unique, a test should detect the violation.

---

# 48. Reusable Data Models

One important idea in dbt is **reuse**.

Instead of every analyst independently calculating:

```text
Customer definition
```

you can create one trusted model:

```text
dim_customers
```

Then many downstream users can build from it.

```text
                 ┌── Dashboard A
                 │
dim_customers ───┼── Dashboard B
                 │
                 ├── Data Science
                 │
                 └── ML Model
```

This reduces duplicated business logic.

---

# 49. Dimensional Model

The lecture mentioned a final model such as:

```text
dim_stripe_customers
```

This represents a business-friendly dataset.

Instead of forcing analysts to query dozens of raw tables:

```text
Raw Table 1
Raw Table 2
Raw Table 3
...
Raw Table 40
```

dbt can transform those sources into a cleaner model:

```text
dim_customers
```

The analyst can then query one organized dataset.

---

# 50. dbt vs Database

These are different concepts.

| Database / Warehouse   | dbt                                      |
| ---------------------- | ---------------------------------------- |
| Stores data            | Defines/transforms data                  |
| Executes SQL           | Generates/manages SQL transformations    |
| Manages data storage   | Manages transformation workflow          |
| Query execution engine | Uses existing warehouse execution engine |
| Holds tables           | Builds tables/views/models               |
| Example: PostgreSQL    | Example: dbt                             |

### Important

dbt does **not** replace:

```text
Snowflake
BigQuery
Redshift
Databricks
PostgreSQL
```

Instead, it sends queries to the data platform where the data lives.

---

# 51. dbt's Execution Model

Conceptually:

```text
Developer writes SQL
        ↓
dbt project
        ↓
Dependency graph
        ↓
Determine build order
        ↓
Generate/run SQL
        ↓
Data warehouse
        ↓
Tables / Views
```

The data warehouse performs the actual query execution.

---

# 52. Why dbt Is Useful

The lecture emphasized several benefits:

### 1. Version control

SQL transformation logic can be managed like software.

### 2. Data lineage

You can see where data comes from.

### 3. Testing

You can verify assumptions about the data.

### 4. Documentation

Teams can document data models and columns.

### 5. Reuse

Other teams can build on existing models.

### 6. Controlled development

Developers can work on transformations before deploying them to production.

### 7. Dependency management

dbt can determine the order in which models need to be built.

---

# 53. Big Picture — From SQL to Data Engineering

The lecture connects several ideas:

```text
DATABASE
   ↓
Stores structured data
   ↓
SQL
   ↓
Queries and transforms data
   ↓
QUERY OPTIMIZER
   ↓
Executes queries efficiently
   ↓
DATA WAREHOUSE
   ↓
Stores large-scale analytical data
   ↓
DBT
   ↓
Organizes transformations
   ↓
DATA MODELS
   ↓
BI / ANALYTICS / AI / ML
```

---

# 54. Important Vocabulary

| Term                | Meaning                                                                     |
| ------------------- | --------------------------------------------------------------------------- |
| DBMS                | Software that manages a database                                            |
| Relation            | Table in the relational model                                               |
| Tuple               | Row                                                                         |
| Attribute           | Column                                                                      |
| Primary Key         | Uniquely identifies a row                                                   |
| Foreign Key         | References a key in another table                                           |
| Subquery            | Query inside another query                                                  |
| Correlated Subquery | Subquery that references the outer query                                    |
| CTE                 | Named temporary result defined with `WITH`                                  |
| Window Function     | Performs calculations across related rows while retaining rows              |
| Partition           | Group of rows processed by a window function                                |
| `OVER`              | Defines the window for a window function                                    |
| `ORDER BY`          | Controls result ordering                                                    |
| `LIMIT`             | Restricts number of returned rows                                           |
| `OFFSET`            | Skips rows before returning results                                         |
| Lateral Join        | Allows a query to reference values from a preceding query at the same level |
| Data Lineage        | Tracks where data comes from and how it is transformed                      |
| Data Warehouse      | Centralized system for analytical data                                      |
| dbt                 | Tool for managing/transformation of data in warehouses                      |
| Jinja               | Templating language used by dbt                                             |
| Data Model          | Structured representation of transformed/business data                      |

---

# 55. SQL Syntax Quick Reference

## Sort

```sql
SELECT *
FROM Student
ORDER BY name ASC;
```

Descending:

```sql
ORDER BY name DESC;
```

---

## Limit

```sql
SELECT *
FROM Student
LIMIT 10;
```

---

## Offset

```sql
SELECT *
FROM Student
LIMIT 10 OFFSET 20;
```

---

## Subquery

```sql
SELECT name
FROM Student
WHERE sid IN (
    SELECT sid
    FROM Enrolled
    WHERE cid = 445
);
```

---

## `MAX()` Subquery

```sql
SELECT *
FROM Student
WHERE sid = (
    SELECT MAX(sid)
    FROM Enrolled
);
```

---

## Correlated Subquery

```sql
SELECT *
FROM Course c
WHERE NOT EXISTS (
    SELECT *
    FROM Enrolled e
    WHERE e.cid = c.cid
);
```

---

## CTE

```sql
WITH highest AS (
    SELECT MAX(sid) AS sid
    FROM Enrolled
)
SELECT *
FROM Student s
JOIN highest h
  ON s.sid = h.sid;
```

---

## Window Function

```sql
SELECT *,
       ROW_NUMBER() OVER () AS row_num
FROM Enrolled;
```

---

## Partitioned Window Function

```sql
SELECT *,
       ROW_NUMBER() OVER (
           PARTITION BY cid
           ORDER BY sid
       ) AS row_num
FROM Enrolled;
```

---

# 56. Selection vs Projection vs Window Functions

These are easy to confuse.

### Selection

**Filters rows.**

Relational algebra:

```text
σ
```

SQL:

```sql
WHERE
```

---

### Projection

**Chooses/calculates columns.**

Relational algebra:

```text
π
```

SQL:

```sql
SELECT column1, column2
```

---

### Window Function

**Calculates information across related rows while retaining the original rows.**

SQL:

```sql
ROW_NUMBER() OVER (...)
AVG(gpa) OVER (...)
```

---

# 57. Nested Query vs CTE vs Window Function

| Technique           | Main Purpose                                                   |
| ------------------- | -------------------------------------------------------------- |
| Nested query        | Put one query inside another                                   |
| Correlated subquery | Inner query depends on outer row                               |
| CTE                 | Give an intermediate query a name                              |
| Lateral join        | Allow a query to reference a preceding query at the same level |
| Window function     | Calculate across rows without collapsing them                  |
| `GROUP BY`          | Combine rows into groups and produce aggregate results         |

---

# 58. How to Approach Nested Query Problems

When solving homework problems, use this method.

### Step 1 — Start with the desired output

Ask:

> What columns do I need to return?

Example:

```sql
SELECT name
FROM Student
```

### Step 2 — Determine what must be true

Example:

> The student must be enrolled in course 445.

### Step 3 — Identify the table containing that information

```text
Enrolled
```

### Step 4 — Write the inner query independently

```sql
SELECT sid
FROM Enrolled
WHERE cid = 445
```

### Step 5 — Connect it to the outer query

```sql
WHERE sid IN (...)
```

### Step 6 — Put everything together

```sql
SELECT name
FROM Student
WHERE sid IN (
    SELECT sid
    FROM Enrolled
    WHERE cid = 445
);
```

---

# 59. How to Approach Correlated Subqueries

Ask:

> Does the inner query need information from the current row of the outer query?

If **yes**, think about a correlated subquery.

Example:

```sql
SELECT *
FROM Course c
WHERE NOT EXISTS (
    SELECT *
    FROM Enrolled e
    WHERE e.cid = c.cid
);
```

The key clue is:

```sql
e.cid = c.cid
```

The inner query depends on the current `Course`.

---

# 60. How to Approach Window Functions

Ask:

> Do I need information about other rows but still want to keep every original row?

If yes, consider a window function.

### Example

Need to number students within each course:

```sql
ROW_NUMBER() OVER (
    PARTITION BY cid
    ORDER BY sid
)
```

Break it down:

```text
ROW_NUMBER()
     ↓
What calculation?

PARTITION BY cid
     ↓
What groups?

ORDER BY sid
     ↓
What order inside each group?
```

---

# 61. Exam-Style Questions

### Concept Questions

1. What is a subquery?
2. What is the difference between a correlated and non-correlated subquery?
3. What does `IN` do?
4. What does `EXISTS` do?
5. What is a CTE?
6. Why might a CTE be easier to read than a deeply nested query?
7. What is a lateral join?
8. What is a window function?
9. What does `OVER` do?
10. What does `PARTITION BY` do?
11. What is the difference between `GROUP BY` and a window function?
12. Why is `ORDER BY` necessary when a specific output order is required?
13. What is `LIMIT`?
14. What is `OFFSET`?
15. Why can date functions behave differently between DBMSs?
16. What is data lineage?
17. What is dbt?
18. Is dbt a database?
19. What does dbt use to define transformations?
20. Why is version control useful for SQL transformations?

---

# 62. SQL Practice Problems

## Problem 1

Find the names of students enrolled in course 445.

Think:

```text
Student
   ↓
sid IN
   ↓
Enrolled where cid = 445
```

---

## Problem 2

Find the student with the highest ID who is enrolled in a course.

Think:

```text
MAX(sid)
   ↓
match with Student
```

---

## Problem 3

Find courses with no students.

Think:

```text
Course
   ↓
NOT EXISTS
   ↓
matching Enrolled row
```

---

## Problem 4

Number all enrollments within each course.

Think:

```sql
ROW_NUMBER()
OVER (
    PARTITION BY cid
    ORDER BY sid
)
```

---

## Problem 5

Explain the difference:

```sql
GROUP BY cid
```

and:

```sql
PARTITION BY cid
```

Remember:

```text
GROUP BY
→ reduces rows

PARTITION BY
→ organizes rows for a window calculation
→ keeps the rows
```

---

# 63. Video 3 — Most Important Takeaways

### 1. SQL results are unordered unless you specify an order.

Use:

```sql
ORDER BY
```

---

### 2. SQL syntax differs across database systems.

Do not assume PostgreSQL syntax works identically in SQLite, MySQL, DuckDB, SQL Server, etc.

---

### 3. Subqueries allow queries inside queries.

```sql
SELECT ...
WHERE ... IN (
    SELECT ...
);
```

---

### 4. Correlated subqueries depend on the outer query.

```sql
WHERE e.cid = c.cid
```

---

### 5. CTEs organize intermediate query results.

```sql
WITH name AS (
    SELECT ...
)
SELECT ...
FROM name;
```

---

### 6. Window functions calculate across rows without collapsing them.

```sql
ROW_NUMBER() OVER (...)
```

---

### 7. `PARTITION BY` creates groups inside a window.

```sql
PARTITION BY cid
```

---

### 8. `ORDER BY` inside a window determines the order of the calculation.

```sql
OVER (
    PARTITION BY cid
    ORDER BY sid
)
```

---

### 9. dbt is a transformation and workflow tool, not a database.

It helps teams:

* transform data
* organize SQL
* track dependencies
* test data
* document data
* visualize lineage
* version-control business logic

---

### 10. The central theme of the lecture

The course is moving from simply **writing SQL queries** toward understanding how databases and data systems manage increasingly complicated data workflows.

The overall progression is:

```text
RELATIONAL MODEL
       ↓
SQL
       ↓
SUBQUERIES
       ↓
CTEs
       ↓
WINDOW FUNCTIONS
       ↓
QUERY OPTIMIZATION
       ↓
DATA WAREHOUSES
       ↓
DBT / DATA TRANSFORMATIONS
       ↓
ANALYTICS / BI / AI / ML
```

## ⭐ Final Memory Sheet

```text
ORDER BY
= sort results

LIMIT
= restrict number of rows

OFFSET
= skip rows

IN
= value belongs to a set

EXISTS
= at least one matching row exists

NOT EXISTS
= no matching row exists

SUBQUERY
= query inside another query

CORRELATED SUBQUERY
= inner query depends on outer query

CTE
= named temporary result using WITH

LATERAL
= later query can reference preceding query's result

WINDOW FUNCTION
= calculate across rows while keeping rows

PARTITION BY
= divide window rows into groups

ROW_NUMBER()
= sequential position

RANK()
= rank according to ordering

GROUP BY
= group/collapse rows

dbt
= SQL-based data transformation/workflow tool

DATA LINEAGE
= where data comes from and how it flows

JINJA
= templating language used by dbt
```
