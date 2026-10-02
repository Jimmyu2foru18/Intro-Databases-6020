## Data Systems, Relational Model & Relational Algebra

---

# 1. What Is a Database System?

## Database vs. Database System

These terms are related but **not the same thing**.

### Database

A **database** is a collection of related data intended to represent some part of the real world.

For example, a music database might contain:

* Artists
* Albums
* Release years
* Relationships between artists and albums

Example:

```text
Artist
----------------
id | name
1  | Wu-Tang Clan
2  | Nas

Album
----------------
id | name       | year
10 | Album A    | 1995
11 | Album B    | 1996
```

The database is the **data itself**.

---

### Database System / DBMS

A **database management system (DBMS)** is the software responsible for storing, managing, querying, and protecting the database.

Examples include:

* PostgreSQL
* MySQL
* SQLite
* Microsoft SQL Server
* ClickHouse
* MongoDB
* Redis

The DBMS provides functionality such as:

* Data storage
* Query processing
* Query optimization
* Concurrency control
* Recovery
* Integrity constraints
* Indexing
* Transactions
* Data security

### Important distinction

```text
Database
    ↓
The actual data

DBMS
    ↓
Software that manages the data
```

---

# 2. Why Do We Need Database Systems?

A simple approach would be to store everything in files such as CSV files and write application code to manipulate them.

For example:

```text
artists.csv
albums.csv
```

An application could read the files line-by-line and search for the required information.

This seems simple, but it creates many problems.

---

# 3. Why "Just Use Files" Is a Bad Database Design

Suppose we store artists in:

```text
artists.csv
```

and albums in:

```text
albums.csv
```

A program might have to:

1. Open the file.
2. Read every line.
3. Split each line on commas.
4. Find the desired artist.
5. Extract the required field.

## Problem 1: Sequential/Linear Scanning

If the desired record is near the end of the file, we may have to read almost the entire file.

```text
Record 1
Record 2
Record 3
Record 4
...
Record 1,000,000  ← desired record
```

This is essentially a **linear scan**.

### Problem

As the database grows, queries become increasingly expensive.

---

# 4. Hardcoded Data Layout

With a simple CSV implementation, application code may assume:

```text
Column 0 = artist name
Column 1 = year
Column 2 = something else
```

The application becomes tightly coupled to the physical file format.

If the file structure changes, the application may break.

---

# 5. Lack of Data Integrity

A simple file does not automatically prevent invalid data.

For example:

```text
Album:
    artist_id = 100
```

but:

```text
Artist table:
    ID 100 does not exist
```

Now the album refers to an artist that does not exist.

This creates a **dangling reference**.

A DBMS can enforce rules that prevent this.

---

# 6. Duplicate / Inconsistent Data

Suppose we store:

```text
Wu-Tang Clan
```

in one location and:

```text
Wu Tang Clan
```

somewhere else.

A human may recognize these as the same artist, but the computer sees two different strings.

This can create:

* Duplicate information
* Incorrect relationships
* Inconsistent data

---

# 7. Limited Data Representation

A simple file structure may assume:

```text
Album → One Artist
```

But real-world albums may have:

```text
Album → Multiple Artists
```

For example:

```text
Album A
    ├── Artist 1
    ├── Artist 2
    └── Artist 3
```

A basic CSV structure may not represent this relationship cleanly.

A relational database can model this using a separate relationship table.

---

# 8. Multiple Applications

Suppose the same data is used by:

```text
Python application
Java application
Rust application
Web application
```

If every application must implement its own file-parsing logic, then the same database logic must be duplicated across multiple programs.

This creates:

* Duplicated code
* More bugs
* Maintenance problems
* Inconsistent behavior

A DBMS provides a common interface to the data.

---

# 9. Concurrent Access

What happens if two programs try to modify the same file simultaneously?

```text
Thread A → write record
Thread B → write record
```

Possible problems include:

* Lost updates
* Corrupted data
* Race conditions
* Inconsistent state

Database systems provide **concurrency control** to handle multiple operations safely.

---

# 10. Durability and Crash Recovery

Imagine a bank database.

```text
Account balance: $1,000
↓
Deposit $500
↓
New balance: $1,500
```

What happens if the computer crashes while writing the update?

A database system must ensure that data is not accidentally lost or corrupted.

This is one reason databases provide:

* Transactions
* Logging
* Recovery
* Durability

---

# 11. Replication and Availability

A real application cannot always depend on a single machine.

If:

```text
Server A
```

fails, the application may need:

```text
Server B
Server C
```

with copies of the data.

Database systems can provide mechanisms for:

* Replication
* Synchronization
* Failover
* High availability

---

# 12. Main Idea

Writing your own database system inside every application is usually a bad idea.

A DBMS provides complicated functionality that applications should not have to reinvent.

```text
Application
     ↓
     SQL
     ↓
   DBMS
     ↓
Storage
```

The application focuses on **what data it wants**, while the DBMS handles **how to store and retrieve it efficiently and safely**.

---

# 13. Data Model

A **data model** is a high-level abstraction that defines:

* What types of data can exist
* How data is represented
* How data relates to other data
* How data can be manipulated

Think of a data model as the **rules or architecture for representing data**.

### Building analogy

```text
Data Model
    ↓
Rules for what a building can contain

Schema
    ↓
Blueprint for one specific building

Database Instance
    ↓
Actual building
```

---

# 14. Schema

A **schema** is a description of the structure of a particular database according to a data model.

For a relational database, a schema describes things such as:

* Tables
* Columns
* Data types
* Keys
* Constraints
* Relationships

Example:

```text
Student(
    sid INT,
    name VARCHAR,
    email VARCHAR
)
```

The schema describes what the database is supposed to look like.

---

# 15. Database Instance

The **database instance** is the actual data stored in the database at a particular point in time.

Schema:

```text
Student(
    sid INT,
    name VARCHAR
)
```

Instance:

```text
1 | James
2 | Sarah
3 | Mike
```

The schema describes the structure.

The instance contains the actual records.

---

# 16. Major Data Models

Different database systems can use different data models.

## Relational Model

Data is represented using relations/tables.

Examples:

* PostgreSQL
* MySQL
* SQLite
* SQL Server

---

## Key-Value Model

Data is stored as:

```text
key → value
```

Conceptually similar to a hash map:

```text
"user123" → "James"
"user456" → "Sarah"
```

Commonly used for:

* Caching
* Simple lookups
* Fast key-based access

---

## Document Model

Data is represented as documents, often using JSON-like structures.

Example:

```json
{
  "name": "James",
  "age": 21,
  "courses": ["CS", "Math"]
}
```

---

## Array / Vector Model

Useful for:

* Machine learning
* Scientific computing
* Vector search
* Semantic search
* RAG applications

Examples include:

```text
[0.12, 0.53, 0.91, 0.44]
```

---

## Older Data Models

Historical database models include:

* Hierarchical
* Network
* CODASYL-style systems
* IMS

These systems often required applications to navigate explicit data structures.

---

# 17. Why the Relational Model Matters

The course focuses heavily on the **relational model** because it provides a high-level way of describing data without requiring the application programmer to know exactly how the DBMS physically stores it.

The central idea is:

> Describe **what data you want**, rather than exactly **how to navigate through the stored data**.

This is a major difference between relational systems and older navigational systems.

---

# 18. Early Database Systems

Early database systems were very different from modern SQL databases.

Examples include:

* GE IDS
* IBM IMS
* CODASYL systems

These systems often required programmers to understand the structure used to store the data.

---

# 19. Navigational Database Model

In a navigational model, the programmer explicitly navigates through the database structure.

Conceptually:

```text
Start at Artist
      ↓
Find Album
      ↓
Follow relationship
      ↓
Find another Artist
      ↓
Continue
```

The programmer is responsible for specifying how to traverse the data.

---

# 20. Why Navigational Queries Are Problematic

Suppose we want:

> Find all artists that appear on a particular album.

A navigational program might explicitly traverse:

```text
Artists
   ↓
Albums
   ↓
Artists
```

The problem is that the programmer has effectively hardcoded the execution strategy.

---

## Problem: Data Changes

Suppose today:

```text
Artists = 1,000
Albums = 10,000
```

Tomorrow:

```text
Artists = 1,000,000
Albums = 50,000,000
```

The execution strategy that was reasonable before may now be terrible.

But if the program explicitly defines the traversal, the DBMS has limited ability to change it.

---

# 21. Declarative Querying

Relational databases introduced a fundamentally different idea.

Instead of saying:

> "Navigate through these structures in this exact order."

You say:

> "This is the result I want."

For example:

```sql
SELECT a.name
FROM Artist a
JOIN ArtistAlbum aa
    ON a.id = aa.artist_id
WHERE aa.album_id = 10;
```

The query describes **what result is wanted**.

The DBMS decides **how to produce it**.

---

# 22. Logical vs. Physical Level

This is one of the most important concepts in the lecture.

## Logical Level

Describes:

* Tables
* Columns
* Relationships
* Data types
* Constraints

Example:

```text
Artist(id, name)
Album(id, name, year)
```

---

## Physical Level

Describes how the data is actually stored.

For example:

```text
Files
Pages
Blocks
Indexes
Extents
Disk locations
Memory structures
```

The application normally does not need to know these details.

---

# 23. Data Independence

The separation between logical and physical representation gives us **data independence**.

### Physical Data Independence

The physical storage can change without requiring the application or logical schema to change.

For example:

```text
Before:
Sequential file

After:
B+ tree index
```

The SQL query can remain the same.

```sql
SELECT *
FROM Student
WHERE sid = 10;
```

The DBMS can change how it physically executes the query.

---

# 24. Three-Level View

A simplified architecture is:

```text
Application
     ↓
External Schema / Views
     ↓
Logical Schema
     ↓
Physical Schema
     ↓
Storage
```

---

## Physical Schema

Describes how information is physically organized.

Examples:

* Files
* Pages
* Indexes
* Storage locations

---

## Logical Schema

Describes the logical structure.

Example:

```text
Student
----------------
sid
name
email
```

---

## External Schema

Provides different views of the logical data to different applications/users.

For example, suppose the Student table contains:

```text
sid
name
email
password
```

An application may only be allowed to see:

```text
sid
name
email
```

A **view** can expose only the required information.

---

# 25. Relational Model — Three Core Ideas

The relational model has three important concepts.

### 1. Relations

Data is represented as high-level relations.

In practice, we usually call them:

```text
Tables
```

---

### 2. Relationships Through Values

Relationships between data are represented logically through values such as:

```text
Primary Keys
Foreign Keys
```

rather than physical memory pointers.

---

### 3. Constraints

The database can specify rules about what data is allowed.

Examples:

```text
id must be unique
name cannot be NULL
foreign key must reference an existing record
```

---

# 26. Relation

A **relation** is conceptually an unordered set of tuples.

In SQL terminology, we normally call it a:

> Table

Example:

```text
Student
+-----+--------+
| sid | name   |
+-----+--------+
| 1   | James  |
| 2   | Sarah  |
| 3   | Mike   |
+-----+--------+
```

---

# 27. Tuple

A **tuple** is a single record/row in a relation.

Example:

```text
(1, James)
```

is one tuple.

In SQL terminology:

```text
row
```

---

# 28. Attribute

An **attribute** is a property/column of a relation.

Example:

```text
Student(sid, name, email)
```

The attributes are:

```text
sid
name
email
```

In SQL terminology:

```text
column
```

---

# 29. Domain

A **domain** specifies the allowed values/types for an attribute.

Example:

```text
age → integer
name → string
GPA → decimal
```

A domain restricts what values are valid.

For example:

```text
GPA ∈ [0.0, 4.0]
```

---

# 30. NULL

`NULL` represents an **unknown or missing value**.

It does not necessarily mean:

```text
0
```

or:

```text
empty string
```

Instead:

```text
NULL = unknown / missing
```

SQL's treatment of `NULL` has special logical behavior that will matter later.

---

# 31. Primary Key

A **primary key** uniquely identifies a tuple in a relation.

Example:

```text
Student
----------------------
sid | name
1   | James
2   | Sarah
3   | Mike
```

Here:

```text
sid
```

is the primary key.

A primary key must uniquely identify a record.

---

# 32. Natural vs. Synthetic Keys

## Natural Key

A value that naturally exists in the real-world data.

Examples:

```text
email
SSN
ISBN
```

if they are guaranteed to be unique and appropriate.

---

## Synthetic Key

An artificially generated identifier.

Example:

```text
id
1
2
3
4
...
```

Often generated using a sequence or identity mechanism.

Example:

```text
Artist
----------------
id | name
1  | Wu-Tang Clan
2  | Nas
3  | Jay-Z
```

The `id` is not inherently part of the real-world artist; it is created by the database.

---

# 33. Foreign Key

A **foreign key** is an attribute whose value refers to a key in another relation.

Example:

```text
Artist
----------------
artist_id | name
1         | Wu-Tang Clan
2         | Nas
```

```text
Album
----------------
album_id | artist_id | name
10       | 1         | Album A
11       | 2         | Album B
```

Here:

```text
Album.artist_id
```

is a foreign key referencing:

```text
Artist.artist_id
```

---

# 34. Referential Integrity

Foreign keys help enforce **referential integrity**.

If:

```text
Album.artist_id = 100
```

then artist `100` must exist in the referenced relation, depending on the database constraint configuration.

This prevents invalid references such as:

```text
Album → Artist that doesn't exist
```

---

# 35. Many-to-Many Relationships

Suppose an album can contain multiple artists:

```text
Album A
 ├── Artist 1
 ├── Artist 2
 └── Artist 3
```

and an artist can appear on multiple albums:

```text
Artist 1
 ├── Album A
 ├── Album B
 └── Album C
```

This is a:

> Many-to-many relationship

---

# 36. Junction / Relationship Table

We can represent the many-to-many relationship using a separate relation.

```text
Artist
----------------
artist_id | name

Album
----------------
album_id | name

ArtistAlbum
------------------------
artist_id | album_id
```

Example:

```text
ArtistAlbum
----------------
artist_id | album_id
1         | 10
2         | 10
3         | 10
1         | 11
```

This means:

```text
Artist 1 → Album 10
Artist 2 → Album 10
Artist 3 → Album 10
Artist 1 → Album 11
```

---

# 37. Composite Primary Key

A relationship table can use multiple columns together as its primary key.

For:

```text
ArtistAlbum
----------------
artist_id | album_id
```

the combination:

```text
(artist_id, album_id)
```

can be the primary key.

This prevents the same relationship from being inserted twice.

Example:

```text
(1, 10)
(1, 10)   ← duplicate relationship
```

would violate the composite primary key.

---

# 38. Constraints

Constraints specify additional rules about what data is allowed.

Examples:

### NOT NULL

```sql
name VARCHAR(100) NOT NULL
```

The value cannot be `NULL`.

### UNIQUE

```sql
email VARCHAR(255) UNIQUE
```

The value must be unique.

### PRIMARY KEY

```sql
id INT PRIMARY KEY
```

Uniquely identifies each tuple.

### FOREIGN KEY

```sql
FOREIGN KEY (artist_id)
REFERENCES Artist(id)
```

Requires the referenced value to exist.

---

# 39. Global Assertions

More complex constraints can sometimes be expressed using database-wide assertions or checks.

Conceptually:

```text
Whenever data changes
        ↓
Run a condition
        ↓
Allow or reject the change
```

These can be more expensive because they may require examining additional data.

---

# 40. Data Manipulation Language (DML)

The language used to query/manipulate data is called **DML**.

Examples include:

```sql
SELECT
INSERT
UPDATE
DELETE
```

Even though `SELECT` does not modify stored data, it is generally considered part of data manipulation/querying because it operates on database relations.

---

# 41. Procedural vs. Declarative Languages

There are two important approaches to querying data.

## Procedural

You specify **how** to obtain the result.

Conceptually:

```text
1. Scan Artist
2. Find Album
3. Match IDs
4. Filter records
5. Return result
```

You specify the execution steps.

---

## Declarative

You specify **what result you want**.

Example:

```sql
SELECT a.name
FROM Artist a
JOIN ArtistAlbum aa
    ON a.id = aa.artist_id
WHERE aa.album_id = 10;
```

You do not explicitly specify:

```text
Use index X
Then scan table Y
Then perform hash join
```

The DBMS decides that.

---

# 42. Relational Algebra

**Relational algebra** is a formal language for manipulating relations.

It provides the fundamental building blocks used to express database queries.

The original relational algebra contains **seven basic operators**:

1. Selection
2. Projection
3. Union
4. Intersection
5. Difference
6. Cartesian Product
7. Join

Modern database systems extend these ideas with additional operators such as:

* Aggregation
* Sorting
* Grouping

---

# 43. Important Idea: Operators Can Be Chained

The output of one relational algebra operator is another relation.

Therefore:

```text
Relation
   ↓
Operator
   ↓
Relation
   ↓
Operator
   ↓
Relation
```

This allows complex queries to be built by combining simpler operations.

---

# 44. Selection — σ

### Purpose

**Selection filters rows/tuples.**

Think:

> "Which rows do I want?"

Symbol:

```text
σ
```

Example:

```text
σ age > 20 (Student)
```

means:

> Return students whose age is greater than 20.

---

## SQL Equivalent

```sql
SELECT *
FROM Student
WHERE age > 20;
```

So:

```text
Relational Algebra Selection
            ↓
         SQL WHERE
```

---

# 45. Selection with Multiple Conditions

Example:

```text
σ age > 20 AND major = 'CS' (Student)
```

SQL:

```sql
SELECT *
FROM Student
WHERE age > 20
  AND major = 'CS';
```

Selection removes tuples that do not satisfy the predicate.

---

# 46. Projection — π

### Purpose

**Projection chooses which attributes/columns appear in the result.**

Think:

> "Which columns do I want?"

Symbol:

```text
π
```

Example:

```text
π name, email (Student)
```

returns only:

```text
name
email
```

---

## SQL Equivalent

```sql
SELECT name, email
FROM Student;
```

So:

```text
Relational Algebra Projection
            ↓
      SQL SELECT list
```

---

# 47. Selection vs. Projection

This is extremely important.

| Operation  | Works On | Purpose         | SQL           |
| ---------- | -------- | --------------- | ------------- |
| Selection  | Rows     | Filters rows    | `WHERE`       |
| Projection | Columns  | Chooses columns | `SELECT` list |

### Memory trick

```text
Selection = Select ROWS

Projection = Select COLUMNS
```

Example:

```sql
SELECT name, email
FROM Student
WHERE major = 'CS';
```

Conceptually:

```text
Selection:
σ major='CS'

        ↓

Projection:
π name,email
```

---

# 48. Projection Can Transform Values

Projection does not have to simply copy columns.

It can calculate expressions.

Example:

```sql
SELECT id, value - 100
FROM R;
```

Conceptually:

```text
π id, value-100 (R)
```

The projection can:

* Select columns
* Reorder columns
* Remove columns
* Compute expressions
* Produce derived values

---

# 49. Union — ∪

Union combines two relations.

```text
R ∪ S
```

Conceptually:

```text
Rows in R
+
Rows in S
```

For the standard relational algebra operation, the two relations must be **union-compatible**.

That means their structures must be compatible for the operation.

---

## SQL

```sql
SELECT ...
FROM R

UNION

SELECT ...
FROM S;
```

---

# 50. Intersection — ∩

Intersection returns tuples that appear in both relations.

```text
R ∩ S
```

Conceptually:

```text
R = {1,2,3}
S = {2,3,4}

R ∩ S = {2,3}
```

SQL:

```sql
SELECT ...
FROM R

INTERSECT

SELECT ...
FROM S;
```

---

# 51. Difference — −

Difference returns tuples that appear in one relation but not the other.

```text
R − S
```

Example:

```text
R = {1,2,3}
S = {2,3,4}

R − S = {1}
```

SQL:

```sql
SELECT ...
FROM R

EXCEPT

SELECT ...
FROM S;
```

---

# 52. Cartesian Product — ×

The **Cartesian product** combines every tuple from one relation with every tuple from another.

```text
R × S
```

If:

```text
R has 3 rows
S has 4 rows
```

then:

```text
R × S
```

can produce:

```text
3 × 4 = 12 rows
```

---

## SQL

```sql
SELECT *
FROM R
CROSS JOIN S;
```

---

# 53. Why Cartesian Product Is Usually Not Enough

Suppose:

```text
Artists
```

contains 1,000 artists and:

```text
Albums
```

contains 10,000 albums.

A Cartesian product could produce:

```text
1,000 × 10,000
= 10,000,000
```

combinations.

But most of those combinations are meaningless.

We don't want:

```text
Artist A + Album Z
```

unless Artist A actually appears on Album Z.

This motivates **joins**.

---

# 54. Join

A join combines tuples from different relations according to a matching condition.

Conceptually:

```text
Cartesian Product
        +
     Filter
        ↓
       Join
```

For example:

```text
Artist.id = ArtistAlbum.artist_id
```

allows us to match an artist to the albums they appear on.

---

# 55. Natural Join

A **natural join** automatically matches columns with the same name and compatible types.

Conceptually:

```text
R ⋈ S
```

The matching attributes are used to determine which tuples belong together.

### Caution

Natural joins can be dangerous in practical SQL because the join condition is implicit.

If the schema changes and another column happens to have the same name, the behavior may change.

It is often clearer to explicitly specify the join condition.

---

# 56. Explicit Join Conditions

Prefer explicitly defining what should match.

Example:

```sql
SELECT *
FROM Artist a
JOIN ArtistAlbum aa
    ON a.artist_id = aa.artist_id;
```

This clearly states:

```text
Artist.artist_id
        =
ArtistAlbum.artist_id
```

---

# 57. Relational Algebra as Query Building Blocks

A SQL query can be thought of as a combination of relational algebra operations.

For example:

```sql
SELECT a.name
FROM Artist a
JOIN ArtistAlbum aa
    ON a.id = aa.artist_id
WHERE aa.album_id = 10;
```

Conceptually:

```text
Artist
   ↓
Join with ArtistAlbum
   ↓
Filter album_id = 10
   ↓
Project name
```

---

# 58. SQL vs. Relational Algebra

A major distinction:

### Relational Algebra

Procedural representation:

```text
Do operation A
↓
Then operation B
↓
Then operation C
```

### SQL

Declarative representation:

```text
Give me this result.
```

The DBMS is responsible for figuring out how to execute it.

---

# 59. Why Execution Order Matters

Consider two possible plans.

### Plan A

```text
Join R and S
      ↓
Filter result
```

### Plan B

```text
Filter S
      ↓
Join R and filtered S
```

These can produce the same logical answer but have very different performance.

---

# 60. Example: Small vs. Huge Tables

Suppose:

```text
R = 1 trillion rows
S = 1 trillion rows
```

and only:

```text
2 rows from S
```

satisfy the filter.

Bad strategy:

```text
R
+
S
↓
Huge Join
↓
Filter
```

Better possible strategy:

```text
S
↓
Filter
↓
Only 2 rows
↓
Join with R
```

The second strategy may dramatically reduce the amount of work.

This is one of the major reasons query optimization exists.

---

# 61. Declarative SQL Enables Query Optimization

When a programmer writes:

```sql
SELECT ...
FROM R
JOIN S ...
WHERE S.value = 102;
```

they do **not** have to specify:

```text
1. Scan R
2. Scan S
3. Join R and S
4. Filter
```

Instead, the DBMS can consider different execution strategies.

For example:

```text
Plan 1:
Join → Filter

Plan 2:
Filter → Join

Plan 3:
Index Scan → Join

Plan 4:
Sequential Scan → Hash Join
```

The optimizer can choose an appropriate plan.

---

# 62. Logical vs. Physical Query Plans

This leads to a major database-system concept.

## Logical Plan

Describes **what operations are required**.

Example:

```text
Scan R
   ↓
Join S
   ↓
Filter
   ↓
Projection
```

---

## Physical Plan

Describes **how those operations are actually executed**.

Example:

```text
Sequential Scan R
        ↓
Index Scan S
        ↓
Hash Join
        ↓
Filter
        ↓
Projection
```

The database system can change the physical plan without changing the SQL query.

---

# 63. Why This Abstraction Is Powerful

Suppose today the best plan is:

```text
Sequential Scan
```

but tomorrow the table becomes huge and an index is created.

The DBMS can choose:

```text
Index Scan
```

without requiring the application developer to rewrite the SQL.

This is the power of **physical data independence + declarative queries**.

---

# 64. Query Optimization

A query optimizer tries to find an efficient way to execute a declarative query.

Conceptually:

```text
SQL Query
    ↓
Logical Plan
    ↓
Alternative Plans
    ↓
Cost Estimation
    ↓
Chosen Physical Plan
    ↓
Execution
```

The optimizer is responsible for deciding things such as:

* Join order
* Join algorithm
* Index vs. sequential scan
* Predicate placement
* Projection placement
* Sort operations
* Other physical execution choices

---

# 65. Key Concepts to Remember

## Database

Collection of related data.

## DBMS

Software that manages the database.

## Data Model

Rules for representing data and relationships.

## Schema

Structure/blueprint of a particular database.

## Relation

A set of tuples; commonly called a table.

## Tuple

A row/record.

## Attribute

A column/property.

## Domain

Allowed values/types for an attribute.

## Primary Key

Uniquely identifies a tuple.

## Foreign Key

References a key in another relation.

## Constraint

Rule restricting valid database states.

## Relational Algebra

Formal operations for manipulating relations.

## Declarative Query

Specifies **what** result is wanted.

## Procedural Query

Specifies **how** to obtain the result.

## Query Optimizer

Determines an efficient physical execution strategy.

---

# 66. Relational Algebra Cheat Sheet

| Operator          | Symbol | Purpose                      | SQL Equivalent |
| ----------------- | -----: | ---------------------------- | -------------- |
| Selection         |    `σ` | Filter rows                  | `WHERE`        |
| Projection        |    `π` | Select columns/expressions   | `SELECT` list  |
| Union             |    `∪` | Combine compatible relations | `UNION`        |
| Intersection      |    `∩` | Rows common to both          | `INTERSECT`    |
| Difference        |    `−` | Rows in one but not another  | `EXCEPT`       |
| Cartesian Product |    `×` | Every combination            | `CROSS JOIN`   |
| Join              |    `⋈` | Combine matching tuples      | `JOIN`         |

---

# 67. Selection vs. Projection — Exam Tip

Remember:

```text
σ = Selection = Rows
π = Projection = Columns
```

Example:

```sql
SELECT name
FROM Student
WHERE major = 'CS';
```

Breakdown:

```text
WHERE major = 'CS'
        ↓
   Selection σ

SELECT name
        ↓
  Projection π
```

---

# 68. Primary Key vs. Foreign Key

| Primary Key                    | Foreign Key                     |
| ------------------------------ | ------------------------------- |
| Identifies a tuple             | References another relation     |
| Must uniquely identify records | Used to establish relationships |
| Defined in its own relation    | References a key elsewhere      |
| Example: `Artist.id`           | Example: `Album.artist_id`      |

---

# 69. Natural Key vs. Synthetic Key

| Natural Key                | Synthetic Key          |
| -------------------------- | ---------------------- |
| Comes from real-world data | Artificially generated |
| Example: ISBN              | Example: `id = 123`    |
| Can sometimes change       | Usually stable         |
| Must actually be unique    | Designed to be unique  |

---

# 70. Logical vs. Physical Data

### Logical

```text
Student
----------------
sid
name
email
```

### Physical

```text
Pages
Files
Indexes
Blocks
Disk locations
Memory buffers
```

The application should generally depend on the **logical representation**, not the physical implementation.

---

# 71. Main Historical Shift

The major conceptual evolution discussed in the lecture is:

```text
Early Database Systems
        ↓
Programmer navigates data structures
        ↓
Hardcoded execution strategy
        ↓
Relational Model
        ↓
Declarative Queries
        ↓
DBMS chooses execution strategy
```

---

# 72. Navigational vs. Relational Approach

| Navigational                             | Relational                              |
| ---------------------------------------- | --------------------------------------- |
| Programmer specifies traversal           | Programmer specifies desired result     |
| Depends heavily on physical organization | Abstracts physical organization         |
| Execution strategy is more hardcoded     | DBMS can choose strategy                |
| Changes in data distribution can hurt    | Optimizer can adapt                     |
| More tightly coupled to storage          | Physical data independence              |
| Older approach                           | Foundation of modern relational systems |

---

# 73. Why the Relational Model Won

The relational model provides:

1. High-level representation
2. Logical relationships
3. Constraints
4. Declarative querying
5. Physical data independence
6. Freedom for the DBMS to optimize execution

The key idea is:

> The programmer describes the desired result, while the database system determines an efficient way to produce it.

---

# 74. Big Picture of the Entire Lecture

The lecture progresses through this chain:

```text
Real World
    ↓
Data
    ↓
Data Model
    ↓
Schema
    ↓
Relations / Tables
    ↓
Tuples + Attributes
    ↓
Keys + Constraints
    ↓
Relational Algebra
    ↓
SQL
    ↓
Query Optimizer
    ↓
Physical Execution Plan
    ↓
Storage
```

---

# 75. Exam Review Questions

## Conceptual Questions

### 1. What is the difference between a database and a DBMS?

A database is the collection of data.

A DBMS is the software that manages the data.

---

### 2. Why shouldn't applications simply store everything in CSV files?

Problems include:

* Linear scans
* Hardcoded data layouts
* Lack of integrity constraints
* Poor concurrency control
* Poor crash recovery
* Difficulty representing relationships
* Duplicated application logic
* Difficult replication

---

### 3. What is a data model?

A high-level specification of how data is represented and how different pieces of data relate.

---

### 4. What is a schema?

The structural definition of a particular database according to a data model.

---

### 5. What is a relation?

A set of tuples representing data; commonly called a table.

---

### 6. What is a tuple?

A single row/record in a relation.

---

### 7. What is an attribute?

A column/property of a relation.

---

### 8. What is a primary key?

An attribute or set of attributes that uniquely identifies a tuple.

---

### 9. What is a foreign key?

An attribute or set of attributes whose values reference a key in another relation.

---

### 10. Why use a junction table?

To represent relationships such as many-to-many relationships.

Example:

```text
Student
   ↕
Enrollment
   ↕
Course
```

---

### 11. What is physical data independence?

The ability to change the physical storage implementation without requiring changes to the logical schema/application.

---

### 12. What is the difference between procedural and declarative querying?

```text
Procedural → How?
Declarative → What?
```

---

### 13. What does selection do?

Filters rows.

```text
σ
```

---

### 14. What does projection do?

Selects columns/expressions.

```text
π
```

---

### 15. Why is Cartesian product usually not enough?

Because it creates every possible combination of tuples, including combinations that are unrelated.

---

### 16. What does a join do?

Combines tuples from relations according to a matching condition.

---

### 17. Why is declarative SQL useful?

Because the DBMS can choose the physical execution strategy rather than forcing the programmer to hardcode one.

---

### 18. Why can two logically equivalent queries have different performance?

Because they may produce different physical execution plans.

For example:

```text
Filter → Join
```

may process far fewer tuples than:

```text
Join → Filter
```

---

# 76. Final Cheat Sheet

```text
DATABASE
= Collection of related data

DBMS
= Software that manages the database

DATA MODEL
= Rules for representing data

SCHEMA
= Blueprint/structure of a database

RELATION
= Table

TUPLE
= Row

ATTRIBUTE
= Column

DOMAIN
= Allowed values/types

PRIMARY KEY
= Unique identifier

FOREIGN KEY
= Reference to another relation

CONSTRAINT
= Rule restricting valid data

SELECTION σ
= Filter rows
= SQL WHERE

PROJECTION π
= Select columns/expressions
= SQL SELECT list

UNION ∪
= Combine relations

INTERSECTION ∩
= Common tuples

DIFFERENCE −
= Tuples in one relation but not another

CARTESIAN PRODUCT ×
= Every combination

JOIN ⋈
= Match/combine related tuples

PROCEDURAL
= Tell the system HOW

DECLARATIVE
= Tell the system WHAT

LOGICAL PLAN
= What operations are needed

PHYSICAL PLAN
= How operations are executed

QUERY OPTIMIZER
= Finds an efficient physical plan

PHYSICAL DATA INDEPENDENCE
= Change storage without changing the logical interface
```

---

# 77. Most Important Ideas from Video 3

If you only remember a few things, remember these:

### 1. Database ≠ DBMS

```text
Database = Data
DBMS = Software managing the data
```

### 2. Relational databases abstract physical storage

You should not have to know whether data is stored using:

```text
Files
Pages
Indexes
B+ trees
Hash tables
```

to write a query.

### 3. SQL is declarative

You say:

```text
"What data do I want?"
```

rather than:

```text
"Exactly how should you retrieve it?"
```

### 4. Relational algebra provides the building blocks

```text
Selection
Projection
Union
Intersection
Difference
Cartesian Product
Join
```

### 5. Selection and projection are different

```text
σ Selection  → rows
π Projection → columns
```

### 6. Keys represent relationships logically

```text
Primary Key
    ↓
Identifies record

Foreign Key
    ↓
Connects records
```

### 7. Declarative queries allow optimization

Because SQL does not force a particular execution strategy, the DBMS can choose among alternatives:

```text
Sequential Scan
Index Scan
Hash Join
Merge Join
Nested Loop
...
```

### 8. Query optimization is necessary because execution order matters

For large datasets:

```text
Filter → Join
```

can require dramatically less work than:

```text
Join → Filter
```

The DBMS's job is to find an efficient way to produce the requested result.
