# Query Execution, Processing Models, Access Methods, and Expression Evaluation

## 1. Query Execution Overview

### Definition

**Query execution** is the process of taking a query plan and actually running its operators to produce the final result.

A database system combines several components:

* Buffer pool
* Page layouts
* Storage/access methods
* Query operators
* Join algorithms
* Aggregation algorithms
* Sorting algorithms
* Expression evaluation
* Query processing models

The overall goal is to turn a SQL query into actual operations that read, process, and produce data.

### Query Plan

A relational database represents a query as a **query plan** consisting of operators.

Conceptually:

```text
             Projection
                 |
              Hash Join
             /         \
        Scan R         Scan S
```

The data logically moves through the operators until it reaches the root.

```text
Tables
  ↓
Scan
  ↓
Filter
  ↓
Join
  ↓
Projection
  ↓
Final Result
```

### DAG vs. Tree

A query plan is conceptually a **DAG (Directed Acyclic Graph)**.

Most database systems implement query plans as trees.

A tree is a special case of a DAG.

The important idea is that operators are connected together and exchange data.

### Logical vs. Physical Data Flow

The query plan diagram may make it look like data is physically pushed upward:

```text
Scan → Filter → Join → Projection
```

But the actual implementation may work differently.

For example, a **pull-based** system starts at the root and requests data from operators below it.

A **push-based** system starts at the leaves and pushes data toward the root.

This distinction is important throughout query execution.

---

# 2. Pipelines and Pipeline Breakers

### Definition

A **pipeline** is a sequence of operators through which tuples can continuously flow without waiting for the entire input to be processed.

For example:

```text
Scan → Filter → Projection
```

A tuple can move through all three operators immediately.

### Pipeline Breaker

A **pipeline breaker** is an operator that must receive all or a significant amount of its input before it can produce output.

Common examples:

* Sorting
* Hash table construction for a hash join
* Certain aggregation operations

### Hash Join Example

Suppose we have:

```text
        Hash Join
        /       \
     Scan R    Scan S
```

For a hash join:

```text
Scan R
  ↓
Build Hash Table
  ↓
Pipeline Breaker
  ↓
Probe using S
```

You cannot safely probe the hash table until the build phase has finished.

Otherwise, the hash table may not contain tuples that should match.

### Sort Example

Sorting is also a pipeline breaker.

You cannot output the first tuple in sorted order until you know which tuple belongs first.

Therefore:

```text
Scan
 ↓
Sort   ← Pipeline breaker
 ↓
Output
```

### Why Pipelines Matter

Pipelines allow the database to process data without unnecessarily materializing intermediate results.

Instead of:

```text
Read tuple
Store tuple
Read next tuple
Store tuple
...
Then process everything
```

the system can do:

```text
Read tuple
 ↓
Filter
 ↓
Join
 ↓
Project
 ↓
Output
```

all in one continuous pipeline.

---

# 3. Query Processing Models

There are three major processing models:

1. **Iterator model**
2. **Materialization model**
3. **Vectorized / batch model**

The main difference is **how much data is passed between operators at a time**.

| Model           | Data Passed            | Typical Use |
| --------------- | ---------------------- | ----------- |
| Iterator        | One tuple              | OLTP        |
| Materialization | All tuples             | Rare        |
| Vectorized      | Batch/vector of tuples | OLAP        |

A useful memory trick:

```text
Iterator       → 1 tuple
Materialization → ALL tuples
Vectorization   → SOME tuples
```

---

# 4. Iterator Model / Volcano Model

### Definition

The **iterator model** is a query-processing model where each operator exposes a `next()` function.

Each call asks an operator:

> "Give me the next tuple."

It is also called:

* Iterator model
* Volcano model
* Pipeline model

### Basic Interface

Operators commonly have:

```text
open()
next()
close()
```

### `open()`

Initializes the operator.

It might:

* Open a file
* Initialize an index iterator
* Allocate temporary memory
* Prepare internal state

### `next()`

Returns:

* The next tuple, or
* `NULL` / end-of-stream when there are no more tuples

### `close()`

Cleans up resources.

For example:

* Close files
* Free temporary memory
* Destroy iterators

---

## Iterator Execution

Consider:

```text
        Projection
             |
          Hash Join
         /         \
      Scan R       Scan S
```

The database starts at the root:

```text
Projection.next()
```

Projection needs data, so it calls:

```text
HashJoin.next()
```

Hash Join needs to build its hash table, so it calls:

```text
ScanR.next()
```

Scan R returns tuples one at a time:

```text
R1
R2
R3
...
```

The hash join builds its hash table.

When Scan R returns:

```text
NULL
```

the hash table is complete.

The hash join can now begin probing using Scan S:

```text
ScanS.next()
 ↓
Probe Hash Table
 ↓
Match?
 ↓
Projection
 ↓
Final Output
```

### Text Flow

```text
Query Runtime
     |
     v
Projection.next()
     |
     v
HashJoin.next()
     |
     v
ScanR.next()
     |
     v
R tuple
     |
     v
Build Hash Table
```

After R is finished:

```text
HashJoin
   |
   v
ScanS.next()
   |
   v
Hash Probe
   |
   v
Projection
   |
   v
Output
```

---

# 5. Iterator Model: Important Execution Idea

The iterator model is **pull-based**.

The operator above asks the operator below for data.

```text
Root
 ↓
"Give me a tuple."
 ↓
Child
 ↓
"Give me a tuple."
 ↓
Child
```

The request travels downward while the data travels upward.

```text
CONTROL:
Root → Child → Child → Scan

DATA:
Scan → Child → Child → Root
```

### Why This Is Useful

Each operator only needs to know the interface of its child.

It does **not** need to know exactly how the child gets its data.

For example, a scan could internally:

* Read one page at a time
* Use an index
* Materialize data
* Maintain a cursor

The parent does not care.

It only calls:

```text
next()
```

---

# 6. Iterator Model Example

Consider:

```text
Projection
    |
   Join
  /   \
Filter Scan
  |
Scan
```

For one tuple:

```text
Scan
 ↓
Filter
 ↓
Join
 ↓
Projection
 ↓
Output
```

The entire tuple can travel through the pipeline before the next tuple is requested.

This is why it is called a **pipeline model**.

### Advantages

* Simple interface
* Easy to implement
* Easy to debug
* Good for small result sets
* Good for OLTP workloads
* Easy to implement `LIMIT`
* Operators can be composed cleanly

### Disadvantages

Every tuple may require several function calls.

For example, processing one billion tuples could mean an enormous number of:

```text
next()
next()
next()
next()
...
```

Function-call overhead can become significant on modern CPUs.

---

# 7. LIMIT and the Iterator Model

The iterator model handles `LIMIT` efficiently.

Suppose:

```sql
SELECT *
FROM Students
LIMIT 10;
```

The system only needs ten tuples.

The limit operator can stop requesting tuples after receiving ten.

```text
Scan
 ↓
Filter
 ↓
Limit 10
 ↓
Output
```

Once ten tuples have been produced:

```text
STOP calling next()
```

It does **not** need to scan the entire table.

This is one of the major advantages of the iterator model.

---

# 8. Materialization Model

### Definition

The **materialization model** passes the entire output of an operator to its parent at once.

Instead of:

```text
next() → tuple
next() → tuple
next() → tuple
```

the operator effectively does:

```text
execute()
 ↓
produce ALL tuples
 ↓
return entire result
```

### Comparison

Iterator:

```text
Operator A
   |
   | one tuple
   v
Operator B
```

Materialization:

```text
Operator A
   |
   | ALL tuples
   v
Operator B
```

### Example

Suppose table `S` contains one billion tuples.

With materialization:

```text
Scan S
 ↓
Store 1 billion tuples
 ↓
Send all to Filter
 ↓
Filter removes most of them
```

If only ten tuples match, the database unnecessarily moved a billion tuples.

---

# 9. Operator Fusion

### Definition

**Operator fusion** combines multiple operators so that work is performed as early and as close to the data source as possible.

Instead of:

```text
Scan
 ↓
Materialize 1 billion tuples
 ↓
Filter
 ↓
Keep 10
```

we can do:

```text
Scan
 ↓
Filter immediately
 ↓
Keep only 10
```

### Example

Instead of:

```text
Scan → Filter → Projection
```

the database can conceptually create:

```text
Scan + Filter + Projection
```

as one larger operation.

### Why It Helps Materialization

Materialization is especially expensive when intermediate results are large.

Operator fusion prevents unnecessary data from being passed between operators.

### OLAP Use

Materialization can make sense when:

* Large amounts of data are required
* You want to reduce repeated function calls
* You are working with columns rather than individual tuples

However, the pure materialization model is relatively uncommon.

---

# 10. Vectorized / Batch Processing Model

### Definition

The **vectorized model** processes a batch of tuples at once instead of one tuple at a time or all tuples at once.

For example:

```text
Iterator:
1 tuple

Vectorized:
1024 tuples

Materialization:
1,000,000,000 tuples
```

A common batch size is around:

```text
1024
2048
```

The exact size depends on the system.

### Basic Idea

```text
Scan
 ↓
Batch of tuples
 ↓
Filter batch
 ↓
Join batch
 ↓
Projection batch
 ↓
Output batch
```

### Why Vectorization Is Good for OLAP

OLAP workloads often process large numbers of tuples.

Calling `next()` individually for every tuple creates unnecessary overhead.

Vectorization allows the system to perform operations over many tuples together.

---

# 11. Vectorization and CPU Efficiency

Modern CPUs can perform **SIMD** operations.

### SIMD

**SIMD = Single Instruction, Multiple Data**

Instead of:

```text
process tuple 1
process tuple 2
process tuple 3
process tuple 4
```

the CPU can potentially process multiple values using one instruction.

Conceptually:

```text
[value1 value2 value3 value4]
          ↓
       SIMD operation
          ↓
[result1 result2 result3 result4]
```

This works particularly well with vectorized database execution because values are already grouped together.

Vectorized processing can also potentially take advantage of:

* CPU caches
* SIMD registers
* GPUs
* Tight loops
* Reduced branching

---

# 12. Vectorized Execution Example

Suppose we have:

```sql
SELECT *
FROM Students
WHERE age > 18;
```

Instead of:

```text
Check tuple 1
Check tuple 2
Check tuple 3
...
```

the system can process:

```text
[18, 22, 30, 15, 21, 40, ...]
```

as a batch.

Conceptually:

```text
Age Batch
   ↓
age > 18
   ↓
[false, true, true, false, true, true]
   ↓
Keep matching tuples
```

This is much better suited to analytical workloads.

---

# 13. Iterator vs. Materialization vs. Vectorization

| Feature        | Iterator       | Materialization  | Vectorization       |
| -------------- | -------------- | ---------------- | ------------------- |
| Amount of data | One tuple      | Entire result    | Batch               |
| Function calls | Many           | Few              | Fewer               |
| Memory use     | Low            | Potentially high | Moderate            |
| OLTP           | Excellent      | Can work         | Less common         |
| OLAP           | Less efficient | Can be expensive | Excellent           |
| LIMIT          | Excellent      | Poor             | Good                |
| CPU efficiency | Lower          | Better           | Very high           |
| Common today   | Very common    | Rare             | Very common in OLAP |

### Memory Trick

```text
ITERATOR       = ONE
MATERIALIZE    = ALL
VECTORIZE      = MANY
```

---

# 14. Pull-Based Query Processing

### Definition

In a **pull-based model**, an operator requests data from its child.

The query starts at the root.

```text
Root
 ↓
Request data
 ↓
Child
 ↓
Request data
 ↓
Scan
```

This is commonly implemented with `next()`.

### Example

```text
Projection.next()
      ↓
Join.next()
      ↓
Scan.next()
      ↓
Tuple returned
      ↑
      |
      +-------- back upward
```

### Advantages

* Simple
* Easy to implement
* Easy to debug
* Easy to control output
* Works well with `LIMIT`
* Common in traditional databases

---

# 15. Push-Based Query Processing

### Definition

In a **push-based model**, operators process data starting from the bottom and push results upward.

There is no requirement for the root to repeatedly call `next()`.

Instead, a scheduler determines which pipeline/task should execute.

```text
Scan
 ↓
Filter
 ↓
Join
 ↓
Projection
 ↓
Output
```

### Scheduler

A higher-level scheduler can see the individual tasks and their dependencies.

For example:

```text
Pipeline 1:
Scan R → Build Hash Table
             |
             v
Pipeline 2:
Scan S → Probe Hash → Projection
```

Pipeline 2 cannot execute until Pipeline 1 has built the hash table.

Therefore:

```text
Scheduler
   |
   +--> Pipeline 1
   |
   +--> Pipeline 2
```

with:

```text
Pipeline 1 → Pipeline 2
dependency
```

---

# 16. Push vs. Pull

| Feature               | Pull-Based             | Push-Based            |
| --------------------- | ---------------------- | --------------------- |
| Direction             | Root requests downward | Leaves produce upward |
| Typical interface     | `next()`               | Scheduled tasks       |
| Control               | Implicit through calls | Explicit scheduler    |
| LIMIT                 | Easy                   | More difficult        |
| Implementation        | Simpler                | More complex          |
| Scheduling            | Less global control    | More global control   |
| Pipeline optimization | Good                   | Potentially excellent |

### Important Point

Neither approach is universally "better."

The choice involves engineering and workload trade-offs.

Push-based execution is particularly common in modern OLAP systems.

---

# 17. Processing Model vs. Processing Direction

These are **different concepts**.

### Processing Model

Determines how much data moves between operators:

```text
Iterator
Materialization
Vectorization
```

### Processing Direction

Determines how execution is driven:

```text
Pull
Push
```

They are independent.

Therefore, a system could theoretically combine:

```text
Vectorization + Pull
```

or:

```text
Vectorization + Push
```

Modern analytical systems often use vectorization with push-based execution.

---

# 18. Supporting Multiple Processing Models

A database could theoretically support:

* Iterator
* Materialization
* Vectorization

at the same time.

But this creates a major engineering problem.

The system would have to maintain multiple implementations of operators.

A vector size of `1` could technically behave similarly to the iterator model:

```text
Vector size = 1
≈
Iterator
```

However, maintaining multiple implementations is generally not worth the complexity.

Some older database systems instead have separate execution engines for different workloads.

For example, some systems have:

```text
Row-store engine
+
Column-store / analytical engine
```

This allows different execution strategies for OLTP and OLAP.

---

# 19. Access Methods

### Definition

An **access method** determines how the database gets data from the leaf nodes of a query plan.

Relational algebra tells us **what** data we want, but not exactly **how to retrieve it**.

For example:

```sql
SELECT *
FROM Students
WHERE age < 30;
```

Relational algebra describes the selection.

The database still needs to decide:

> How do I find the matching students?

The main access methods are:

1. Sequential scan
2. Index scan
3. Multi-index scan

---

# 20. Sequential Scan

### Definition

A **sequential scan** reads the table's pages one after another.

It is the fallback method.

```text
Page 1
 ↓
Page 2
 ↓
Page 3
 ↓
Page 4
 ↓
...
```

### Basic Process

1. Find the first page.
2. Read the page.
3. Examine its tuples.
4. Return matching tuples.
5. Move to the next page.
6. Continue until the table is exhausted.

### Cursor

The scan maintains a cursor indicating where it currently is.

For example:

```text
Current page = 5
Current tuple = 17
```

When the next tuple is requested, the scan knows where to continue.

### Why Sequential Scans Are Not Always Bad

A sequential scan sounds inefficient, but databases have many optimizations:

* Compression
* Encoding
* Prefetching
* Parallel scanning
* Clustering
* Sorting
* Data skipping
* Vectorization
* Cache efficiency

---

# 21. Prefetching

### Definition

**Prefetching** means reading data into memory before it is actually needed.

Suppose the database knows it will scan:

```text
Page 1 → Page 2 → Page 3 → Page 4
```

It can fetch several pages ahead of time.

```text
CPU processing Page 1
       |
       +--> Disk/storage fetching Pages 2–4
```

When the CPU needs Page 2, it may already be in memory.

This reduces waiting for storage.

---

# 22. Other Sequential Scan Optimizations

Sequential scans can benefit from:

### Compression

More tuples can fit into each page.

```text
Uncompressed:
Page → 100 tuples

Compressed:
Page → 300 tuples
```

### Clustering

Related data is stored near each other.

### Sorting

Sorted data can make:

* Binary searches possible
* Sort-merge joins efficient
* Range queries faster

### Parallelism

Multiple workers can scan different portions of the table.

### Vectorization

Multiple tuples can be processed together.

### Data Skipping

The database can sometimes determine that an entire region cannot contain matching data and skip it.

---

# 23. Approximate Queries

### Definition

An **approximate query** intentionally returns an estimate instead of an exact answer.

Example:

Instead of determining the exact number of website visitors:

```text
Exact count = 12,438,291
```

you may accept:

```text
Approximately 12.4 million
```

### Why?

If the exact answer is unnecessary, scanning all the data may be wasteful.

Some systems provide approximate versions of aggregate operations.

Examples:

```text
Approximate COUNT
Approximate MIN
Approximate MAX
```

### Important

Approximate queries are **lossy**.

The result may not be exact.

The database cannot know whether approximate results are acceptable for your application, so the user/application must choose this behavior.

---

# 24. Zone Maps

### Definition

A **zone map** stores summary statistics about a region of data.

Common statistics include:

* Minimum
* Maximum
* Number of NULLs
* Number of distinct values
* Other aggregates

Conceptually:

```text
Data Block
+----------------+
| 100            |
| 200            |
| 250            |
| 400            |
+----------------+

Zone Map:
MIN = 100
MAX = 400
```

---

# 25. Zone Map Example

Suppose we have:

```sql
SELECT *
FROM table
WHERE value > 600;
```

A data block has:

```text
MIN = 100
MAX = 400
```

The maximum value is only `400`.

Therefore:

```text
Can this block contain value > 600?

NO
```

The database can skip the entire block.

```text
Query:
value > 600

Block 1:
MAX = 400
       ↓
     SKIP

Block 2:
MAX = 900
       ↓
     READ
```

### Key Idea

A zone map does **not** tell the database exactly which tuple matches.

It tells the database whether a block **could possibly contain** a match.

### Why This Is Powerful

Instead of:

```text
Scan 1 billion tuples
```

the database may be able to:

```text
Check metadata
 ↓
Skip large portions
 ↓
Read only potentially relevant data
```

Zone maps are widely used in analytical systems and columnar file formats.

---

# 26. Index Scans

### Definition

An **index scan** uses an existing index to locate tuples matching a predicate.

Example:

```sql
SELECT *
FROM Students
WHERE age < 30;
```

If there is an index on:

```text
age
```

the database may use it instead of scanning the entire table.

---

# 27. Choosing an Index

Suppose we have:

```sql
SELECT *
FROM Students
WHERE age < 30
  AND department = 'CS'
  AND country = 'US';
```

and indexes on:

```text
age
department
```

The database must determine which index is more useful.

### Scenario A

```text
99 students have age < 30
2 students are in CS
```

The department index is better.

### Scenario B

```text
2 students have age < 30
99 students are in CS
```

The age index is better.

### Key Concept: Selectivity

A predicate is more **selective** when it eliminates more records.

```text
2 matching rows
```

is more selective than:

```text
99 matching rows
```

The query optimizer uses statistics to estimate which access path is cheapest.

---

# 28. Index Type Matters

Different indexes support different operations.

For example:

### B+ Tree

Can support:

```text
=
<
>
<=
>=
ranges
```

### Hash Index

Best suited for equality:

```text
=
```

A hash index generally cannot efficiently answer:

```sql
WHERE age < 30
```

because hashing destroys the ordering information.

Therefore, the database must consider both:

1. Which index is selective?
2. Can that index support the predicate?

---

# 29. Multi-Index Scans

Some database systems can use multiple indexes for one query.

Suppose:

```sql
WHERE age < 30
  AND department = 'CS'
```

with:

```text
Index on age
Index on department
```

The database can:

```text
Age Index
   ↓
IDs matching age < 30

Department Index
   ↓
IDs matching department = CS

       ↓
INTERSECTION

       ↓
Matching record IDs
       ↓
Fetch tuples
```

For an `AND` condition:

```text
A AND B
```

use:

```text
INTERSECTION(A, B)
```

For an `OR` condition:

```text
A OR B
```

use:

```text
UNION(A, B)
```

---

# 30. Multi-Index Scan Names

Different systems use different names for similar techniques.

| Database        | Term             |
| --------------- | ---------------- |
| PostgreSQL      | Bitmap scan      |
| MySQL           | Index Merge      |
| General concept | Multi-index scan |

The basic idea is:

```text
Index 1 → matching record IDs
Index 2 → matching record IDs
             ↓
      UNION / INTERSECTION
             ↓
      Fetch records
```

---

# 31. SELECT Access Methods Summary

A database can generally choose between:

```text
Sequential Scan
       OR
Index Scan
       OR
Multi-Index Scan
```

The choice depends on:

* Available indexes
* Predicate selectivity
* Index type
* Data distribution
* Estimated cost
* Number of tuples expected

---

# 32. Data Modification Queries

The same access methods used for `SELECT` can be reused for:

```sql
INSERT
UPDATE
DELETE
```

This avoids reimplementing table scanning logic.

For example:

```sql
DELETE FROM Students
WHERE age < 18;
```

Conceptually:

```text
Scan / Index Scan
       ↓
Find matching Record IDs
       ↓
Delete tuples
```

For an update:

```text
Scan / Index Scan
       ↓
Find matching tuples
       ↓
Modify tuples
```

The access method finds the records; the modification operator performs the change.

---

# 33. INSERT and Composition

An insert operator can accept tuples produced by another operator.

For example:

```sql
INSERT INTO NewStudents
SELECT *
FROM Students
WHERE major = 'CS';
```

Conceptually:

```text
Scan Students
      ↓
Filter
      ↓
Projection
      ↓
Insert
      ↓
NewStudents
```

The insert operator does not need to know where its input came from.

It only needs tuples in the expected format.

This creates a clean separation between operators.

---

# 34. UPDATE, DELETE, and Physical Data Movement

Modifying a tuple can change where that tuple physically exists.

This becomes dangerous when the access method is scanning the same structure being modified.

For example:

```text
Index ordered by salary
```

Suppose:

```text
Andy = $999
```

The query increases salaries below `$1100` by `$100`.

Andy becomes:

```text
$999 → $1099
```

Because the index is ordered by salary, Andy may physically move.

The scan may later encounter Andy again.

This can cause:

```text
Andy: $999
   ↓
update
   ↓
Andy: $1099
   ↓
scan encounters Andy again
   ↓
update again
   ↓
$1199
```

This is incorrect.

---

# 35. The Halloween Problem

### Definition

The **Halloween problem** occurs when modifying a tuple changes its physical location, causing the scan/access method to encounter the same logical tuple multiple times.

### Example

Suppose:

```sql
UPDATE Employees
SET salary = salary + 100
WHERE salary < 1100;
```

Starting data:

```text
Andy → $999
```

The update makes:

```text
Andy → $1099
```

If the index is organized by salary, Andy may move to a different location.

The scan could encounter Andy again and apply the update twice.

### Logical vs. Physical Identity

Logically:

```text
There is only ONE Andy.
```

Physically:

```text
Andy existed at location A
        ↓
salary changed
        ↓
Andy moved to location B
```

A naive scan may treat the second physical appearance as a new tuple.

---

# 36. Handling the Halloween Problem

The system must track which logical tuples have already been processed.

Possible strategies include:

* Tracking modified record IDs
* Using temporary storage
* Marking tuples as processed
* Materializing the set of records before modifying them

The exact implementation can vary.

### Exam Tip

Remember:

> **If an update can change the physical location used by the scan, think "Halloween problem."**

---

# 37. Expression Evaluation

SQL contains expressions that must be evaluated while the query executes.

Examples:

```sql
WHERE age > 18
```

```sql
WHERE R.id = S.id
```

```sql
WHERE salary + 100 > 1000
```

The database must determine whether these expressions evaluate to true or false.

---

# 38. Expression Trees

Expressions can be represented as trees.

For example:

```sql
WHERE s.value = $1 + 9
```

can conceptually become:

```text
             =
           /   \
     s.value     +
                / \
              $1   9
```

The database evaluates this expression tree for each tuple.

---

# 39. Example of Expression Evaluation

Suppose:

```text
s.value = 1000
$1 = 991
```

Expression:

```text
s.value = $1 + 9
```

Evaluation:

```text
$1
 ↓
991

9
 ↓

991 + 9
 ↓
1000

s.value
 ↓
1000

1000 = 1000
 ↓
TRUE
```

The operator can then determine:

```text
TRUE → emit tuple
FALSE → discard tuple
```

---

# 40. Execution Context

The database maintains an **execution context** containing information needed to evaluate expressions.

This can include:

* Current tuple
* Tuple schema
* Parameter values
* Column locations/offsets
* Other execution state

Instead of repeatedly searching for this information, the database can prepare the context ahead of time.

This is important because expressions may be evaluated millions or billions of times.

---

# 41. Expression Tree Traversal

The expression tree can be evaluated using a depth-first traversal.

Example:

```text
        =
      /   \
   value   +
          / \
        $1   9
```

Steps:

1. Evaluate `value`.
2. Evaluate `$1`.
3. Evaluate `9`.
4. Add `$1 + 9`.
5. Compare `value` with the result.
6. Return `TRUE` or `FALSE`.

For:

```text
value = 1000
$1 = 991
```

we get:

```text
991 + 9 = 1000
1000 = 1000
TRUE
```

---

# 42. Why Expression Trees Can Be Slow

Expression trees are a useful abstraction, but evaluating them repeatedly can introduce overhead.

For every tuple, the system may have to:

```text
Follow pointer
 ↓
Visit expression node
 ↓
Follow pointer
 ↓
Visit another node
 ↓
Look up value
 ↓
Perform operation
 ↓
Return result
```

With one billion tuples, this overhead becomes significant.

The database therefore wants to eliminate as much interpretation and indirection as possible.

---

# 43. Compiling Expressions

Instead of interpreting the expression tree every time, the database can compile the expression into executable code.

For example:

Expression:

```sql
value = 1000
```

Instead of:

```text
Walk expression tree
```

the database can effectively generate:

```text
check(value):
    return value == 1000
```

The compiled code can then run directly over the data.

---

# 44. JIT Compilation

### Definition

**JIT = Just-In-Time compilation**

The database generates executable code for a query or part of a query while the query is running.

Conceptually:

```text
SQL
 ↓
Query Plan
 ↓
Expression
 ↓
Generate Code
 ↓
Compile
 ↓
Execute
```

### Why JIT Helps

It removes some of the overhead of:

* Expression tree traversal
* Function calls
* Indirection
* Interpretation

---

# 45. PostgreSQL JIT Example

The lecture demonstrated a PostgreSQL query over roughly **50 million rows**.

The table was first warmed into the buffer pool so the experiment focused on execution rather than disk I/O.

Without JIT:

```text
~4 seconds
```

With JIT:

```text
~2.7 seconds
```

The JIT process itself added compilation overhead.

The lecture example showed approximately:

```text
JIT compilation overhead ≈ 381 ms
```

The important lesson is not the exact numbers but the trade-off:

```text
Compilation Cost
       ↓
Faster Execution
```

JIT is worthwhile when the execution savings outweigh the compilation cost.

---

# 46. JIT Cost Model

Compilation is not free.

Therefore, the database can estimate:

```text
Cost of compiling
vs.
Expected execution savings
```

If:

```text
Compilation cost > expected benefit
```

then JIT may not be worthwhile.

If:

```text
Compilation cost < expected benefit
```

then JIT can be worthwhile.

This is another example of a database making decisions based on cost.

---

# 47. PostgreSQL vs. DuckDB Example

The lecture compared PostgreSQL and DuckDB.

### PostgreSQL

The example used:

* Row-oriented storage
* Pull-based execution
* Iterator-style execution
* JIT compilation

With JIT, the query took approximately:

```text
2.7 seconds
```

### DuckDB

DuckDB used:

* Column-oriented storage
* Vectorized execution
* Push-based execution

The same general workload completed in less than a second in the lecture example.

### Main Lesson

Different systems make different engineering trade-offs.

```text
PostgreSQL
→ Excellent general/OLTP-oriented design
→ Can use JIT to improve analytical workloads

DuckDB
→ Specifically designed around analytical workloads
→ Vectorization + columnar execution can be extremely efficient for OLAP
```

The important point is that the **same SQL query can have radically different physical execution strategies**.

---

# 48. Constant Folding

### Definition

**Constant folding** evaluates expressions involving constants ahead of time.

Suppose the database sees:

```text
UPPER('hello')
```

The value never changes.

Instead of calculating it for every tuple:

```text
tuple 1 → UPPER('hello')
tuple 2 → UPPER('hello')
tuple 3 → UPPER('hello')
...
```

calculate it once:

```text
UPPER('hello')
     ↓
'HELLO'
```

Then reuse:

```text
'HELLO'
```

### Why It Helps

If a query processes one billion tuples, performing a constant calculation one billion times is wasteful.

---

# 49. Common Subexpression Elimination

### Definition

**Common subexpression elimination** detects repeated expressions and calculates them only once.

Suppose a query contains:

```text
expression A
AND
expression A
```

Instead of:

```text
calculate A
calculate A again
```

the database can calculate:

```text
A
 ↓
save result
 ↓
reuse result
```

### Conceptual Example

```text
        AND
       /   \
      A     A
```

can become:

```text
        AND
       /   \
      A-----+
       |
   computed once
```

This reduces duplicated work.

---

# 50. Prepared Statements

### Definition

A **prepared statement** allows a query to be parsed/optimized ahead of time and reused with different parameter values.

Example:

```sql
PREPARE xxx AS
SELECT *
FROM Students
WHERE value = $1 + 9;
```

Then:

```sql
EXECUTE xxx(991);
```

The parameter:

```text
$1 = 991
```

is substituted during execution.

---

# 51. Why Prepared Statements Help

Without preparation, repeatedly executing a query may require repeated work:

```text
Parse SQL
 ↓
Optimize
 ↓
Create plan
 ↓
Execute
```

With a prepared statement:

```text
Prepare once
 ↓
Reuse plan
 ↓
Execute
 ↓
Execute
 ↓
Execute
```

This can save repeated planning work.

### Trade-Off

A single cached plan may not be optimal for every parameter value.

For example:

```text
Parameter A → very selective
Parameter B → matches half the table
```

The best execution strategy may differ.

Therefore, prepared/cached plans involve trade-offs.

---

# 52. Query Processing: Putting Everything Together

A SQL query goes through many stages.

Conceptually:

```text
SQL Query
   ↓
Query Plan
   ↓
Physical Operators
   ↓
Choose Processing Model
   ↓
Choose Processing Direction
   ↓
Choose Access Methods
   ↓
Execute Operators
   ↓
Evaluate Expressions
   ↓
Produce Result
```

The database has many choices at each stage.

---

# 53. Same SQL, Different Execution Strategies

Consider:

```sql
SELECT name
FROM Students
WHERE age < 30;
```

The database could execute this using:

### Sequential Scan

```text
Scan every page
 ↓
Check age
 ↓
Return matches
```

### Index Scan

```text
Age index
 ↓
Find age < 30
 ↓
Fetch matching tuples
```

### Vectorized Scan

```text
Read batch
 ↓
Check 1024 values
 ↓
Return matching batch
```

### Compiled Expression

```text
Generate code for age < 30
 ↓
Run compiled predicate
```

All produce the same logical result.

The physical execution is different.

---

# 54. OLTP vs. OLAP

### OLTP

**Online Transaction Processing**

Typically involves:

* Small queries
* Few tuples
* Frequent updates
* Point lookups
* Index usage
* Low latency

Good strategies include:

```text
Index scans
Iterator model
Pull-based execution
```

### OLAP

**Online Analytical Processing**

Typically involves:

* Large scans
* Large aggregations
* Many tuples
* Analytical queries
* Sequential access
* Batch processing

Good strategies include:

```text
Vectorization
Columnar storage
Push-based execution
Sequential scans
Data skipping
SIMD
```

---

# 55. Important Comparisons

## Processing Models

| Concept         | Meaning                  | Difference                            |
| --------------- | ------------------------ | ------------------------------------- |
| Iterator        | Pass one tuple at a time | Low memory, many function calls       |
| Materialization | Pass all tuples          | Potentially huge intermediate results |
| Vectorization   | Pass batches             | Good balance and CPU efficiency       |

## Processing Direction

| Concept | Meaning                    | Difference                   |
| ------- | -------------------------- | ---------------------------- |
| Pull    | Parent asks child for data | Usually `next()`             |
| Push    | Child produces data upward | Scheduler controls execution |

## Access Methods

| Access Method    | Meaning                       | Best Situation                |
| ---------------- | ----------------------------- | ----------------------------- |
| Sequential Scan  | Read table pages sequentially | No useful index / large scan  |
| Index Scan       | Use one index                 | Selective predicate           |
| Multi-Index Scan | Combine several indexes       | Multiple selective predicates |

## Index Types

| Index      | Good For                   |
| ---------- | -------------------------- |
| B+ Tree    | Equality and range queries |
| Hash Index | Equality lookups           |

## OLTP vs. OLAP

| Feature       | OLTP               | OLAP                  |
| ------------- | ------------------ | --------------------- |
| Data accessed | Small amount       | Large amount          |
| Common access | Index              | Sequential            |
| Processing    | Iterator           | Vectorized            |
| Storage       | Often row-oriented | Often column-oriented |
| Goal          | Low latency        | High throughput       |

---

# 56. Pull vs. Push Diagram

### Pull

```text
            Root
             |
        next() ↓
             |
           Join
             |
        next() ↓
             |
           Scan
             |
             ↓
           Tuple
             |
             ↑
          Result
```

The root asks for data.

### Push

```text
Scan
 ↓
Filter
 ↓
Join
 ↓
Projection
 ↓
Output
```

The scheduler starts tasks and data moves upward.

---

# 57. Iterator vs. Vectorized Example

Suppose we need to process one million tuples.

### Iterator

```text
Tuple 1 → next()
Tuple 2 → next()
Tuple 3 → next()
...
Tuple 1,000,000 → next()
```

### Vectorized

```text
Batch 1 → 1024 tuples
Batch 2 → 1024 tuples
Batch 3 → 1024 tuples
...
```

Vectorization reduces the number of calls and enables efficient CPU processing.

---

# 58. Query Access Decision Strategy

When thinking about how a query should execute, use this process.

### Step 1: Look at the predicate

Ask:

```text
What does the WHERE clause ask for?
```

For example:

```sql
WHERE age < 30
```

### Step 2: Check indexes

Ask:

```text
Is there an index on age?
```

### Step 3: Check selectivity

Ask:

```text
How many tuples will match?
```

If very few match, an index may be excellent.

If most rows match, a sequential scan may be better.

### Step 4: Check index capabilities

Ask:

```text
Does the index support this predicate?
```

For example:

```text
B+ Tree + age < 30
```

works well.

A hash index is not designed for that range predicate.

### Step 5: Consider workload

For:

```text
OLTP
```

index scans are often valuable.

For:

```text
OLAP
```

large sequential scans and vectorization are often better.

---

# 59. Query Execution Decision Tree

```text
                    SQL Query
                       |
                       v
              What data is needed?
                       |
              +--------+--------+
              |                 |
        Small/selective      Large scan
              |                 |
        Useful index?       Sequential scan
          /       \              |
        Yes        No         Vectorization
         |          |              |
    Index Scan   Seq. Scan       Data Skipping
```

This is simplified; the actual optimizer considers many additional factors.

---

# 60. Common Mistakes

* Confusing **logical query plans** with physical execution.
* Assuming data is always physically pushed upward through the query plan.
* Forgetting that a pipeline breaker must process significant input before producing output.
* Confusing the **processing model** with the **processing direction**.
* Thinking iterator means the entire query only processes one tuple total.
* Forgetting that iterator means one tuple **between operator calls**.
* Assuming materialization is always faster because it uses fewer function calls.
* Forgetting that materialization can create enormous intermediate results.
* Confusing vectorization with vector databases.
* Assuming vectorization means processing the entire table at once.
* Forgetting that vectorization processes **batches**.
* Assuming a sequential scan is automatically bad.
* Forgetting about compression and prefetching.
* Assuming an index is always better than a sequential scan.
* Choosing an index without considering selectivity.
* Using a hash index for a range predicate.
* Forgetting that multi-index scans can use intersections for `AND`.
* Forgetting that `OR` generally corresponds to a union of matching record IDs.
* Confusing approximate queries with zone maps.
* Thinking zone maps give exact matching tuples.
* Forgetting that zone maps are used to determine which blocks can be skipped.
* Forgetting the Halloween problem when an update changes physical tuple location.
* Thinking an expression tree is necessarily the fastest way to evaluate expressions.
* Forgetting JIT compilation has an upfront cost.
* Assuming JIT is always worth using.
* Confusing constant folding with common subexpression elimination.

---

# 61. Exam Review

## Must-Know Definitions

* **Query Plan:** A structure of physical/logical operators used to execute a query.
* **DAG:** Directed Acyclic Graph; a query plan can conceptually be represented as one.
* **Pipeline:** A sequence of operators through which tuples can flow continuously.
* **Pipeline Breaker:** An operator that must process substantial input before producing output.
* **Iterator Model:** Processes one tuple at a time using functions such as `next()`.
* **Volcano Model:** Another name commonly used for the iterator model.
* **Materialization Model:** Passes an operator's entire result to the next operator.
* **Vectorization:** Processes data in batches/vectors.
* **Pull-Based Execution:** Parent operators request data from children.
* **Push-Based Execution:** Operators process and push results toward consumers.
* **Access Method:** The mechanism used to retrieve data from leaf nodes.
* **Sequential Scan:** Reads table pages sequentially.
* **Index Scan:** Uses an index to locate matching records.
* **Multi-Index Scan:** Combines results from multiple indexes.
* **Zone Map:** Metadata containing statistics about a region of data to determine whether it can be skipped.
* **Halloween Problem:** A modification causes a tuple to move physically and potentially be processed multiple times.
* **Expression Tree:** Tree representation of a SQL expression.
* **JIT Compilation:** Compiling query code during execution.
* **Constant Folding:** Computing constant expressions ahead of time.
* **Common Subexpression Elimination:** Computing repeated expressions once and reusing the result.
* **Prepared Statement:** A reusable query structure with parameters.

---

# 62. Must-Know Methods

### Method 1: Understand Iterator Execution

1. Start at the root.
2. Call `next()`.
3. The operator requests data from its child.
4. Continue downward until reaching a scan.
5. Scan produces a tuple.
6. Tuple moves upward through operators.
7. Repeat until the root produces the final result.
8. Stop when `NULL` / end-of-stream is returned.

---

### Method 2: Identify a Pipeline Breaker

Ask:

> Can this operator produce correct output before receiving all required input?

If **no**, it is likely a pipeline breaker.

Examples:

```text
Sort
Hash-table build
```

---

### Method 3: Choose an Access Method

1. Check whether a useful index exists.
2. Determine whether the index supports the predicate.
3. Estimate selectivity.
4. Estimate how many tuples will be retrieved.
5. Compare index scan vs. sequential scan.
6. Consider multiple indexes if available.

---

### Method 4: Solve Multi-Index Conditions

For:

```sql
WHERE A AND B
```

think:

```text
Index(A)
   ∩
Index(B)
```

For:

```sql
WHERE A OR B
```

think:

```text
Index(A)
   ∪
Index(B)
```

Then:

```text
Record IDs
    ↓
Fetch actual tuples
```

---

### Method 5: Recognize the Halloween Problem

When you see an update:

```sql
UPDATE ...
SET indexed_column = ...
WHERE indexed_column ...
```

ask:

> Could changing this value move the tuple in the structure being scanned?

If yes:

```text
Think Halloween Problem
```

---

### Method 6: Evaluate an Expression Tree

1. Start at the root.
2. Traverse toward the required child values.
3. Retrieve tuple attributes from the execution context.
4. Retrieve parameter values.
5. Evaluate constants.
6. Perform arithmetic/functions.
7. Return to the parent operator.
8. Continue until the root produces the final Boolean result.

---

### Method 7: Optimize an Expression

Look for:

```text
Constants
Repeated subexpressions
Expensive function calls
```

Then consider:

```text
Constant Folding
Common Subexpression Elimination
JIT Compilation
```

---

# 63. Must-Know SQL Syntax

### Sequential Scan Example

```sql
SELECT *
FROM Students
WHERE age < 30;
```

### Index-Eligible Predicate

```sql
SELECT *
FROM Students
WHERE age < 30
  AND department = 'CS';
```

### Update Example

```sql
UPDATE Employees
SET salary = salary + 100
WHERE salary < 1100;
```

This type of update is useful for understanding the Halloween problem.

### Prepared Statement

```sql
PREPARE xxx AS
SELECT *
FROM Students
WHERE value = $1 + 9;
```

Execute it with:

```sql
EXECUTE xxx(991);
```

Conceptually:

```text
$1 = 991

991 + 9
= 1000
```

---

# 64. Important Execution Pseudocode

## Iterator

```text
open()

while true:
    tuple = next()

    if tuple == NULL:
        break

    process(tuple)

close()
```

## Vectorized

```text
open()

while true:
    batch = next_batch()

    if batch == EMPTY:
        break

    process(batch)

close()
```

## Pull-Based

```text
root.next()
    ↓
child.next()
    ↓
child.next()
    ↓
scan
    ↓
tuple
    ↑
    |
return result
```

## Push-Based

```text
scheduler
    ↓
run scan
    ↓
run filter
    ↓
run join
    ↓
run projection
    ↓
output
```

---

# 65. Important Conceptual Formulas / Rules

### Iterator Data Amount

```text
Iterator = 1 tuple at a time
```

### Materialization

```text
Materialization = entire operator output
```

### Vectorization

```text
Vectorization = batch of tuples
```

### Boolean Index Combination

```text
A AND B → A ∩ B
A OR B  → A ∪ B
```

### JIT Trade-Off

```text
JIT is beneficial when:

Execution savings > Compilation cost
```

### Zone Map Rule

If a predicate requires:

```text
value > X
```

and:

```text
MAX(block) <= X
```

then:

```text
SKIP BLOCK
```

because the block cannot contain a matching value.

---

# 66. Final Cheat Sheet / Memory Sheet

## Query Execution

```text
SQL
 ↓
Query Plan
 ↓
Physical Operators
 ↓
Processing Model
 ↓
Processing Direction
 ↓
Access Methods
 ↓
Expression Evaluation
 ↓
Result
```

## Three Processing Models

```text
ITERATOR
→ 1 tuple
→ next()
→ good for OLTP

MATERIALIZATION
→ ALL tuples
→ potentially huge intermediates
→ rare

VECTORIZATION
→ batch
→ SIMD-friendly
→ good for OLAP
```

## Two Processing Directions

```text
PULL
→ Root asks children
→ next()
→ simpler

PUSH
→ Leaves push upward
→ scheduler
→ more global control
```

## Access Methods

```text
Sequential Scan
→ fallback
→ reads pages sequentially

Index Scan
→ uses one index
→ good for selective predicates

Multi-Index Scan
→ multiple indexes
→ AND = intersection
→ OR = union
```

## Index Rules

```text
B+ Tree
→ equality + ranges

Hash Index
→ equality
→ not designed for range scans
```

## Data Skipping

```text
Approximate Query
→ intentionally approximate
→ potentially inaccurate

Zone Map
→ exact query result
→ skips blocks that cannot match
```

## Halloween Problem

```text
Scan
 ↓
Find tuple
 ↓
Modify indexed value
 ↓
Tuple physically moves
 ↓
Scan finds it again
 ↓
Tuple modified twice
```

**Remember:**

> If an update can move a tuple while the scan is still running, think **Halloween Problem**.

## Expression Evaluation

```text
SQL Expression
 ↓
Expression Tree
 ↓
Traverse tree
 ↓
Evaluate values
 ↓
TRUE / FALSE
```

But interpretation can be expensive.

Optimization:

```text
Expression Tree
 ↓
Compile
 ↓
Machine Code
 ↓
Faster execution
```

## Expression Optimizations

```text
Constant Folding
→ calculate constants once

Common Subexpression Elimination
→ calculate repeated expressions once

JIT Compilation
→ generate executable code
```

## OLTP

```text
Small results
Frequent updates
Index scans
Iterator
Pull-based
Low latency
```

## OLAP

```text
Large scans
Large results
Sequential scans
Vectorization
Columnar processing
Often push-based
SIMD
Data skipping
High throughput
```

## Biggest Takeaway

The same SQL query does **not** have one fixed execution strategy.

A database can choose different:

```text
Access methods
      +
Processing models
      +
Processing directions
      +
Storage formats
      +
Expression evaluation techniques
      +
Optimizations
```

depending on:

* Workload
* Data size
* Selectivity
* Available indexes
* Storage layout
* Hardware
* Expected result size
* Estimated execution cost

The database's job is ultimately to find an efficient **physical way to execute the same logical query**.
