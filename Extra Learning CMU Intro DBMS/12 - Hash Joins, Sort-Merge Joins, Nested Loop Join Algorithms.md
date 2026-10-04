# Database Systems — Join Algorithms

## 1. Why Joins Matter

### Definition

A **join** combines tuples from two tables based on a matching condition, usually an equality between join keys.

For example:

```sql
SELECT *
FROM R
JOIN S
  ON R.id = S.id;
```

The join takes a tuple from `R` and a matching tuple from `S` and produces one combined output tuple.

### Why Databases Need Joins

Database tables are commonly separated into multiple tables instead of storing everything in one giant table.

For example:

```text
Students
--------
sid
name

Courses
-------
cid
name

Enrolled
--------
sid
cid
grade
```

To reconstruct information about students, courses, and grades, the database must join these tables.

### Normal Forms

The lecture briefly mentioned **normalization**.

* A large universal table contains lots of duplicated data.
* Normalization breaks the data into smaller related tables.
* Joins reconstruct the information when needed.

The lecture specifically said that detailed knowledge of normal forms and Armstrong's axioms is **not a major focus of this course**.

### Key Point

> Joins allow a database to break data into separate tables while still being able to reconstruct the desired information.

---

# 2. Types of Joins

## Equi-Join / Inner Join

The primary type of join discussed in this lecture.

A join is based on equality:

```sql
R.id = S.id
```

The database takes matching values from both tables.

### Binary Join

The algorithms in this lecture are primarily **binary join algorithms**.

That means:

```text
Table R + Table S
       ↓
      JOIN
       ↓
   Result table
```

They operate on **two tables at a time**.

Even when a SQL query contains three or more tables, the optimizer generally constructs a sequence of binary joins.

Example:

```text
A JOIN B JOIN C
```

Could become:

```text
(A JOIN B) JOIN C
```

or:

```text
A JOIN (B JOIN C)
```

The order can have a huge impact on performance.

---

## Other Join Types

The same basic algorithms can be adapted for:

* Left outer joins
* Full outer joins
* Anti-joins
* Other theta joins
* Non-equality predicates

These are not the main focus of this lecture.

---

# 3. Multi-Way Joins

A **multi-way join** attempts to join more than two tables at once.

Although possible, these algorithms are difficult to optimize.

Most database systems instead use binary joins.

Examples of systems using binary join strategies include:

* PostgreSQL
* Oracle
* MySQL
* DuckDB

### Worst-Case Optimal Joins

More advanced systems can use **worst-case optimal joins**.

These can efficiently handle certain multi-way joins, especially graph-like queries involving many self-joins.

They are outside the scope of this course.

---

# 4. Join Ordering

When joining two tables, a general rule is:

> Prefer the smaller table as the outer/build side when appropriate.

For queries involving multiple tables, the database optimizer must determine the best order.

For example:

```text
A JOIN B JOIN C
```

Possible execution orders:

```text
(A JOIN B) JOIN C
```

or:

```text
(A JOIN C) JOIN B
```

or:

```text
(B JOIN C) JOIN A
```

The optimizer uses statistics about the tables to estimate which plan will be cheapest.

### Important

For this lecture, the main focus is **how the join itself is performed**, not how the optimizer chooses the algorithm.

---

# 5. Query Plans

A database query plan is generally represented as a **tree** or **DAG**.

Conceptually:

```text
             Final Result
                  ↑
               Join
              ↗    ↖
           Table R  Table S
```

Data flows upward through operators.

For example:

```text
Tables
  ↓
Scan
  ↓
Join
  ↓
Filter
  ↓
Output
```

The database must decide:

* What data the join outputs
* How much data it outputs
* How expensive the algorithm is
* Which join algorithm is best

---

# 6. Early vs. Late Materialization

This becomes important when discussing what a join outputs.

## Early Materialization

With **early materialization**, tuples contain all required attributes.

Suppose:

```text
R(id, name, age)
S(id, course)
```

After joining:

```text
R.id = S.id
```

the output may contain:

```text
R.id
R.name
R.age
S.id
S.course
```

The complete tuple is passed upward.

### Advantage

The database does not need to return to the base tables later to retrieve those attributes.

### Disadvantage

More data must be moved and stored.

---

## Late Materialization

With **late materialization**, the system passes only the information needed at the current stage.

For example:

```text
R.id
S.id
```

might be enough to perform the join.

Instead of passing every attribute, the system may pass record IDs or only the required columns.

Later, if another operator needs:

```text
S.course
```

the database can retrieve it from the base table/column.

### Advantage

Less data is read and moved.

This can be particularly useful in **column stores**.

### When Late Materialization Is Especially Useful

If the join is highly selective:

```text
1,000,000 tuples
        ↓
      JOIN
        ↓
       10 tuples
```

There is little reason to carry every column through the join.

### Key Idea

```text
Early materialization
→ carry complete tuples

Late materialization
→ carry only what is currently needed
→ fetch additional attributes later
```

---

# 7. Join Cost Model

For this lecture, the primary performance metric is:

> **Disk I/O**

The lecture intentionally ignores many CPU costs because disk I/O is assumed to be much more expensive.

## What Is Ignored?

Generally ignored:

* Hash computation cost
* Hash table probing cost
* Key comparisons
* CPU computation
* Final output cost

## What Is Counted?

Count:

* Reading pages from disk
* Writing pages to disk
* Reading spilled data back from disk

---

# 8. Notation

The lecture uses:

| Symbol | Meaning                          |
| ------ | -------------------------------- |
| `R`    | First table                      |
| `S`    | Second table                     |
| `M`    | Number of pages in R             |
| `N`    | Number of pages in S             |
| `m`    | Number of tuples in R            |
| `n`    | Number of tuples in S            |
| `B`    | Number of available buffer pages |

Remember:

```text
Capital letter → pages
Lowercase letter → tuples
```

For example:

```text
R:
M pages
m tuples

S:
N pages
n tuples
```

---

# 9. Why Disk I/O Matters

Suppose the database has to repeatedly scan a table from disk.

Even if the CPU operation is simple, repeated disk access can make the query extremely slow.

Therefore:

> Database join algorithms try to minimize unnecessary disk I/O.

This is why techniques such as:

* Buffering
* Blocking
* Hashing
* Sorting
* Partitioning

are so important.

---

# 10. Divide and Conquer

A major design pattern used throughout the lecture is:

> **Divide a large problem into smaller problems, solve the smaller problems efficiently, and combine the results.**

This appears in:

* External merge sort
* Block nested-loop join
* Hash joins
* Partitioned hash joins

Conceptually:

```text
Large Problem
     ↓
Divide
     ↓
Small Problems
     ↓
Solve Efficiently
     ↓
Combine
     ↓
Final Result
```

---

# 11. Nested-Loop Join

The simplest join algorithm is the **nested-loop join**.

The basic implementation is essentially two nested loops.

### Pseudocode

```text
for each tuple r in R:
    for each tuple s in S:
        if r.key == s.key:
            output(r, s)
```

The outer loop processes `R`.

The inner loop scans `S`.

---

# 12. Naive Nested-Loop Join

### Definition

For every tuple in the outer table, scan the entire inner table.

```text
R:
r1
r2
r3
...

For r1 → scan ALL of S
For r2 → scan ALL of S
For r3 → scan ALL of S
...
```

### Cost

If `R` is the outer table:

```text
M + mN
```

Where:

* `M` = scan R once
* `m` = number of tuples in R
* `N` = pages in S

The expensive part is:

```text
mN
```

because the entire inner table is repeatedly scanned.

---

# 13. Naive Nested-Loop Example

Suppose:

```text
R = 1,000 pages
R = 100,000 tuples

S = 500 pages
S = 40,000 tuples
```

If `R` is outer:

```text
M + mN
= 1,000 + (100,000)(500)
= 50,001,000 I/Os
```

Approximately:

```text
50 million I/Os
```

This is extremely expensive.

### Main Problem

The same pages of `S` are repeatedly read.

```text
R tuple 1 → scan S
R tuple 2 → scan S again
R tuple 3 → scan S again
...
```

---

# 14. Outer vs. Inner Table

Terminology comes from the nested loops.

```text
Outer loop → Outer table
Inner loop → Inner table
```

Typical diagram:

```text
Outer              Inner
  R       JOIN        S
```

The lecture emphasizes:

> When using nested-loop algorithms, generally place the smaller table on the outer side.

Why?

Because the outer table determines how many times the inner table is scanned.

---

# 15. Block Nested-Loop Join

Naive nested loops operate one tuple at a time.

A better strategy is to process **blocks/pages of tuples at once**.

Instead of:

```text
one tuple from R
    ↓
scan S
```

we do:

```text
block of R
    ↓
scan S
```

### Basic Idea

```text
For each block of R:
    For each block/page of S:
        Compare tuples in the two blocks
```

### Cost

With a simple block model:

```text
M + MN
```

when one page/block of R is processed at a time.

This is much better than:

```text
M + mN
```

because `m` can be much larger than `M`.

---

# 16. Buffering and Block Nested-Loop Join

Real systems have multiple buffer pages.

If there are `B` buffer pages, approximately:

```text
B - 2
```

can be used for the outer relation.

The remaining buffers can be used for:

* The inner input
* Output

### Cost

A common formula is:

```text
M + ceil(M / (B - 2)) × N
```

This means:

1. Read R once.
2. Divide R into batches that fit in memory.
3. For each batch, scan S.
4. Join the tuples in memory.

---

# 17. Why Buffering Is So Powerful

Suppose the database has enough memory to hold the relevant pages.

Instead of repeatedly reading from disk:

```text
Disk → R
Disk → S
Disk → R
Disk → S
...
```

the database can do:

```text
Disk → R
Disk → S
       ↓
     Memory
       ↓
   Join in memory
```

If everything fits in memory, the cost can approach:

```text
M + N
```

because each table only needs to be read once.

### Major Lesson

> Nested-loop joins are terrible when they repeatedly access disk, but can be extremely fast when the data fits in memory.

This distinction is very important for understanding later hash joins.

---

# 18. Why the Smaller Table Should Be Outer

Suppose:

```text
R = 1,000 pages
S = 500 pages
```

Put `S` outside.

```text
S → outer
R → inner
```

because the inner table is repeatedly scanned.

The database should generally minimize the number of times it scans the larger relation.

### Important Exam Point

Do **not** choose the smaller table based only on number of tuples.

For disk I/O, the important measurement is usually:

> **Number of pages**

because disk I/O operates on pages.

---

# 19. Index Nested-Loop Join

Suppose the inner table already has an index on the join key.

Instead of scanning the entire inner table, the database can use the index.

### Basic Algorithm

```text
For each tuple r in outer table:
    extract join key
    probe index on S
    find matching tuple(s)
    output match
```

Conceptually:

```text
R
↓
Scan tuples
↓
Extract key
↓
Index lookup
↓
S
```

### Cost

The general form is:

```text
M + mC
```

where:

* `M` = scan outer table
* `m` = number of tuples in outer table
* `C` = cost of probing the index

### Why Is C Not Given Exactly?

It depends on:

* Index type
* Index size
* Data distribution
* Whether the key is unique
* Number of matching tuples

For example, a B+ tree may have logarithmic traversal plus additional leaf scanning.

---

# 20. Hash Join vs. Index Nested-Loop Join

The high-level difference:

### Index Nested-Loop

```text
Existing index
      ↓
Probe index
```

### Hash Join

```text
Build a hash table
      ↓
Probe hash table
```

A hash join is essentially building a temporary lookup structure specifically for the join.

---

# 21. Main Nested-Loop Takeaways

### If everything fits in memory:

Nested-loop can be:

```text
VERY FAST
```

### If disk I/O is required:

You want to:

1. Put the smaller table on the outside.
2. Process as many outer pages as possible at once.
3. Use available buffer memory.
4. Avoid repeatedly scanning the inner table.

### Main Algorithms

```text
Naive Nested Loop
        ↓
Block Nested Loop
        ↓
Index Nested Loop
```

---

# 22. Sort-Merge Join

The second major algorithm is the **sort-merge join**.

It is based on sorting both tables by their join keys.

### Two Major Phases

```text
Phase 1: Sort
Phase 2: Merge
```

Conceptually:

```text
R ──→ Sort R ──┐
               ├──→ Merge → Join Result
S ──→ Sort S ──┘
```

The sorting phase can use **external merge sort** if the tables do not fit in memory.

---

# 23. Why Sort-Merge Join Works

Suppose both tables are sorted:

```text
R: 100 200 200 400 500
S: 100 100 200 300 400
```

Because the values are sorted, the database knows that once it passes a certain value, it cannot suddenly encounter a smaller value later.

This allows the database to move forward instead of repeatedly scanning the entire table.

---

# 24. Sort-Merge Join: Merge Phase

Two cursors begin at the beginning:

```text
R cursor → first tuple
S cursor → first tuple
```

Compare the join keys.

### If Equal

```text
R.key == S.key
```

Output the combined tuple.

### If R.key < S.key

Move the R cursor forward.

### If S.key < R.key

Move the S cursor forward.

The exact cursor movement depends on which value is smaller.

---

# 25. Backtracking in Sort-Merge Join

Duplicate join keys make the algorithm more complicated.

Suppose:

```text
R:
100
200
200
400

S:
100
200
300
400
```

When multiple tuples have the same join key, the database may need to revisit the matching portion of the other table.

The algorithm therefore tracks the last relevant value/position.

### Why?

Suppose:

```text
R = 200
S = 200
```

They match.

But then another tuple in R is also:

```text
R = 200
```

The algorithm needs to find the matching `200` in S again.

Therefore, it may need to backtrack to the beginning of the matching group.

---

# 26. Sort-Merge Example

Consider:

```text
R:
100
200
200
400
500

S:
100
100
200
300
400
500
```

### Step 1

Compare:

```text
100 = 100
```

Match.

Move the inner cursor.

### Step 2

```text
100 = 100
```

Another match.

### Step 3

Inner cursor reaches:

```text
200
```

while R is still:

```text
100
```

Since:

```text
200 > 100
```

there cannot be another `100` later in S.

Move R forward.

### Step 4

Now:

```text
200 = 200
```

Match.

### Step 5

If R contains another `200`, the algorithm can backtrack to the beginning of the matching `200` region in S.

### Step 6

Eventually:

```text
400 = 400
```

Match.

### Step 7

Eventually:

```text
500 = 500
```

Match.

### Step 8

If the next value on one side is greater than the maximum possible matching value on the other side, the algorithm can terminate early.

---

# 27. Why Sorting Helps

Suppose:

```text
R = 300
S = 400
```

Because S is sorted and we are already at `400`, we know there is no later `300`.

There is no need to scan the rest of S.

This is the major advantage of sorted data.

---

# 28. Sort-Merge Join Cost

The algorithm has two major costs.

### Sort Phase

Cost:

```text
Cost(sort R) + Cost(sort S)
```

If using external merge sort, use the external sort formula from the previous lecture.

### Merge Phase

Without significant backtracking:

```text
M + N
```

because the sorted tables can each be scanned once.

### Total

Conceptually:

```text
Sort(R) + Sort(S) + Merge
```

---

# 29. Sort-Merge Numerical Example

Given:

```text
Sort R = 4,000 I/Os
Sort S = 2,000 I/Os
Merge  = 1,500 I/Os
```

Total:

```text
4,000 + 2,000 + 1,500
= 7,500 I/Os
```

---

# 30. When Sort-Merge Join Is Good

Sort-merge join is particularly useful when:

### 1. Data is already sorted

If the join keys are already sorted, the database may not need to perform the sorting phase.

### 2. Output must be sorted

If the query also contains:

```sql
ORDER BY join_key
```

the sorting work can serve both purposes.

Conceptually:

```text
Sort once
   ↓
Join
   ↓
Already sorted output
```

This can avoid an additional sort.

---

# 31. Sort-Merge vs. Hash Join

In general:

> Hash join is usually preferred over sort-merge join for ordinary equality joins.

However:

> Sort-merge join can be preferable when the data is already sorted or sorted output is needed.

---

# 32. Worst-Case Join Data

A difficult situation occurs when almost every tuple has the same join key.

For example:

```text
R:
1
1
1
1
1
...

S:
1
1
1
1
1
...
```

The join result can become enormous.

No join algorithm can magically eliminate the cost of producing all those matches.

### Key Point

> Data distribution matters.

---

# 33. Hash Join

The most important algorithm in the lecture is the **hash join**.

The basic idea:

> Use a hash function to quickly locate tuples that could possibly match.

If two join keys are equal:

```text
R.key = S.key
```

then:

```text
hash(R.key) = hash(S.key)
```

Therefore, matching tuples should end up in the same hash location/partition.

---

# 34. Basic In-Memory Hash Join

Hash join has two main phases.

```text
Phase 1: Build
Phase 2: Probe
```

### Build Phase

Take the outer/build table and create a hash table.

```text
Scan R
 ↓
Hash R.key
 ↓
Insert into hash table
```

### Probe Phase

Scan the other table and probe the hash table.

```text
Scan S
 ↓
Hash S.key
 ↓
Probe hash table
 ↓
Check actual key
 ↓
Output match
```

---

# 35. Hash Join Pseudocode

```text
Build phase:
    create hash table

    for each tuple r in R:
        h = hash(r.key)
        insert r into hash table[h]

Probe phase:
    for each tuple s in S:
        h = hash(s.key)
        search hash table[h]

        if matching key exists:
            output(r, s)
```

Notice that the loops are **not nested**.

They are sequential:

```text
Scan R
  ↓
Build hash table
  ↓
Scan S
  ↓
Probe hash table
```

---

# 36. Why Hash Join Is Fast

Naive nested-loop join does:

```text
For every R tuple:
    scan all of S
```

Hash join instead does:

```text
Build lookup structure for R
        ↓
Hash each S key
        ↓
Go directly to likely matching area
```

Instead of searching all of S, the database narrows the search to a small portion.

This is another example of:

> **Divide and conquer**

---

# 37. Hash Tables and Collisions

A hash function does not guarantee that every key maps to a unique slot.

Therefore:

```text
hash(A) = 5
hash(B) = 5
```

is possible.

The database still needs to compare the actual join keys.

Therefore, the hash table must contain enough information to verify an actual match.

### Important

Hash equality does **not** automatically mean key equality.

The hash function identifies candidates.

The actual key comparison confirms the match.

---

# 38. Common Hash Table Implementation

The lecture notes that real systems often use:

> **Linear probing hash tables**

because they are simple and fast.

---

# 39. Bloom Filters

A useful optimization for hash joins is a **Bloom filter**.

### Basic Idea

While building the hash table, also build a Bloom filter.

```text
R
 ↓
Build hash table
 ↓
Build Bloom filter
```

Then when probing with S:

```text
S tuple
  ↓
Bloom filter
  ↓
Does it possibly exist?
 / \
No  Yes
↓    ↓
Skip  Probe hash table
```

---

# 40. Why Bloom Filters Help

A Bloom filter can quickly determine:

> "This value definitely does not exist."

If the Bloom filter says **no**, the database avoids the more expensive hash-table lookup.

If it says **yes**, the database performs the actual hash-table probe.

### Important Property

Bloom filters can have false positives.

They cannot safely say "definitely present."

Conceptually:

```text
Bloom says NO
→ definitely not present

Bloom says YES
→ maybe present
→ check actual hash table
```

---

# 41. When Bloom Filters Are Most Useful

Bloom filters are especially useful when the join is **highly selective**.

Example:

```text
1,000,000 tuples
        ↓
Join
        ↓
1,000 matching tuples
```

Most tuples will not match.

The Bloom filter allows the system to reject many tuples cheaply.

The lecture described this optimization as potentially producing a significant performance improvement for highly selective joins.

This is sometimes called:

> **Sideways Information Passing (SIP)**

or a **Bloom join**.

---

# 42. In-Memory Hash Join vs. Disk-Based Hash Join

The simple hash join assumes the hash table fits in memory.

But what if:

```text
R = 500 GB
Memory = 16 GB
```

The entire hash table cannot fit.

Trying to build one giant hash table would result in expensive disk I/O.

The solution is:

> Partition the tables first.

---

# 43. Partitioned Hash Join / Grace Hash Join

The disk-based version uses two phases:

```text
Phase 1 → Partition
Phase 2 → Join partitions
```

This is often called:

* Partitioned hash join
* Grace hash join

The idea comes from early database systems research involving the Grace database machine.

---

# 44. Grace Hash Join — Phase 1

Scan both tables.

For every tuple:

```text
hash(join key)
      ↓
choose partition
```

For example:

```text
R
 ↓
Hash
 ↓
┌──────┬──────┬──────┬──────┐
│ R0   │ R1   │ R2   │ R3   │
└──────┴──────┴──────┴──────┘

S
 ↓
Hash
 ↓
┌──────┬──────┬──────┬──────┐
│ S0   │ S1   │ S2   │ S3   │
└──────┴──────┴──────┴──────┘
```

Matching keys are guaranteed to go to corresponding partitions.

---

# 45. Why Partitioning Is Correct

Suppose:

```text
R.key = 100
S.key = 100
```

Because the same deterministic hash function is used:

```text
hash(100) = same value
```

Therefore:

```text
R100 → partition X
S100 → partition X
```

They cannot end up in different partitions if the algorithm is implemented correctly.

Therefore, instead of comparing every R tuple against every S tuple, the database only needs to compare:

```text
R0 with S0
R1 with S1
R2 with S2
...
```

---

# 46. Grace Hash Join — Phase 2

For each matching partition:

1. Load the smaller partition into memory.
2. Build an in-memory hash table.
3. Scan the corresponding partition from the other table.
4. Probe the hash table.
5. Produce matches.
6. Throw away the hash table.
7. Move to the next partition.

Conceptually:

```text
R0 + S0
 ↓
Build hash table
 ↓
Probe
 ↓
Output

R1 + S1
 ↓
Build hash table
 ↓
Probe
 ↓
Output
```

Only one partition needs to be processed at a time.

---

# 47. Why Grace Hash Join Works

The original problem was:

```text
Entire table too large for memory
```

Partitioning changes it to:

```text
Large table
     ↓
Smaller partitions
     ↓
One partition fits in memory
     ↓
Fast in-memory hash join
```

This is another example of divide and conquer.

---

# 48. Number of Partitions

The database system determines how many partitions to create based on available memory and the expected data size.

The lecture emphasizes that memory is finite.

You cannot simply assume:

```text
Use all available memory
```

because other operators and processes also need memory.

The database administrator/system may impose a memory limit for operations such as hash joins.

---

# 49. Recursive Partitioning

What if one partition is still too large to fit into memory?

Partition it again.

```text
Large partition
      ↓
Hash again
      ↓
Smaller partitions
      ↓
Hash join
```

This is called:

> **Recursive partitioning**

A second hash function or different hash seed can be used for the additional partitioning level.

---

# 50. Example of Recursive Partitioning

Suppose:

```text
Partition 2
```

becomes too large.

Instead of repartitioning everything:

```text
Partition 0 → fine
Partition 1 → fine
Partition 2 → TOO LARGE
Partition 3 → fine
```

Only the problematic partition needs further processing.

```text
Partition 2
     ↓
New hash
     ↓
┌──────┬──────┬──────┐
│ 2A   │ 2B   │ 2C   │
└──────┴──────┴──────┘
```

The smaller partitions can remain unchanged.

---

# 51. Degenerate / Worst Case

If all keys have the same value:

```text
1
1
1
1
1
...
```

partitioning does not help.

Everything still hashes to the same partition.

Repeated partitioning cannot magically separate identical keys.

### Important

> No join algorithm can completely eliminate a pathological data distribution.

In these cases, the system may fall back to another algorithm such as block nested-loop join.

---

# 52. Hash Join Cost

The lecture gives the approximate cost of a partitioned hash join as:

```text
3(M + N)
```

Why?

The data is roughly:

### 1. Read

```text
M + N
```

Read both input tables.

### 2. Write

```text
M + N
```

Write the partitions to disk.

### 3. Read Again

```text
M + N
```

Read the partitions back.

Total:

```text
3(M + N)
```

This ignores additional complications such as recursive partitioning.

---

# 53. Numerical Hash Join Example

Suppose:

```text
M + N = 150 pages
```

Then:

```text
3(M + N)
= 3(150)
= 450 I/Os
```

So the approximate hash join cost is:

```text
450 I/Os
```

---

# 54. Comparing the Algorithms

For the lecture's example:

| Algorithm             |    Approximate Cost |
| --------------------- | ------------------: |
| In-memory nested-loop |            150 I/Os |
| Partitioned hash join |            450 I/Os |
| Sort-merge join       |            750 I/Os |
| Naive nested-loop     | Extremely expensive |

The important point is that **there is no universally fastest algorithm**.

The best algorithm depends on:

* Data size
* Available memory
* Data distribution
* Existing indexes
* Whether data is already sorted
* Whether output must be sorted
* Selectivity
* Hardware

---

# 55. Hybrid Hash Join

A more advanced optimization is the **hybrid hash join**.

The basic idea:

> Keep a particularly useful/hot partition in memory while spilling the other partitions to disk.

Suppose:

```text
Partition 0 → small/hot → keep in memory
Partition 1 → disk
Partition 2 → disk
Partition 3 → disk
```

The in-memory partition can be joined immediately.

The other partitions use the normal Grace hash join process.

---

# 56. Why Hybrid Hash Join Helps

If one partition is accessed heavily and fits in memory, there is no reason to write it to disk and read it back.

Instead:

```text
Hot partition
     ↓
Keep in memory
     ↓
Build hash table
     ↓
Join directly
```

Other partitions:

```text
Other partitions
     ↓
Write to disk
     ↓
Read later
     ↓
Normal hash join
```

This can reduce I/O.

### Challenge

The system must determine which partition will be "hot."

That depends on data distribution, which can be difficult to predict.

---

# 57. Probe Table Size

For a hash join, the **probe table** can be relatively large.

Ideally, the relevant build-side hash table should fit in memory.

If the system knows the table size, it can allocate an appropriately sized hash table.

If the size is unknown, more dynamic hashing techniques could be considered, such as:

* Extendible hashing
* Linear hashing

However, these can have more overhead than simple linear probing.

---

# 58. Query Optimization

The database system needs to decide:

```text
Which join algorithm should I use?
```

Possible choices:

```text
Nested Loop
Index Nested Loop
Block Nested Loop
Sort-Merge
Hash Join
```

The optimizer estimates the costs based on:

* Table sizes
* Number of pages
* Number of tuples
* Data distributions
* Available indexes
* Available memory
* Expected join result size
* Existing sort order

---

# 59. Why Query Optimization Is Difficult

Estimating table size is already difficult.

Estimating the result size after:

```text
R JOIN S
```

is harder.

Estimating after multiple joins is even harder.

For example:

```text
A JOIN B
    ↓
Result
    ↓
JOIN C
    ↓
Result
    ↓
JOIN D
```

The optimizer must estimate the size of every intermediate result.

These estimates can be very wrong.

---

# 60. Hash Join as a Common Fallback

Because estimates are often inaccurate, hash join is frequently a strong default.

The lecture's overall rule of thumb:

> Hashing is usually preferable to sorting for equality joins unless sorting is already useful or required.

---

# 61. When Each Join Algorithm Is Useful

| Algorithm                   | Best Situation                              |
| --------------------------- | ------------------------------------------- |
| Naive Nested Loop           | Very small/in-memory data                   |
| Block Nested Loop           | Limited memory, simple implementation       |
| Index Nested Loop           | Useful existing index on join key           |
| Sort-Merge Join             | Data already sorted or sorted output needed |
| In-Memory Hash Join         | Build side fits in memory                   |
| Grace/Partitioned Hash Join | Tables do not fit in memory                 |
| Hybrid Hash Join            | One partition can remain in memory          |
| Bloom-Filter Hash Join      | Highly selective join                       |

---

# 62. Nested Loop vs. Hash Join

| Feature                | Nested Loop             | Hash Join                   |
| ---------------------- | ----------------------- | --------------------------- |
| Basic idea             | Compare tuples directly | Hash keys                   |
| Implementation         | Nested loops            | Build + probe               |
| Existing index needed? | No                      | No                          |
| Good in memory?        | Yes                     | Yes                         |
| Good with disk?        | Naive version is poor   | Partitioned version is good |
| Equality joins         | Works                   | Excellent                   |
| Additional structure   | Buffers/index           | Hash table                  |
| Main strength          | Simplicity              | Fast lookup                 |

---

# 63. Hash Join vs. Sort-Merge Join

| Feature                           | Hash Join                 | Sort-Merge Join               |
| --------------------------------- | ------------------------- | ----------------------------- |
| Main technique                    | Hashing                   | Sorting                       |
| Typical equality join performance | Usually better            | Usually slower                |
| Requires sorting?                 | No                        | Yes, unless already sorted    |
| Handles disk data?                | Yes, through partitioning | Yes, through external sorting |
| Sorted output                     | No                        | Yes                           |
| Good if data already sorted       | Not necessarily           | Yes                           |
| Main advantage                    | Fast equality lookup      | Sorting + joining together    |

---

# 64. Block Nested Loop vs. Naive Nested Loop

| Feature      | Naive           | Block                 |
| ------------ | --------------- | --------------------- |
| Processes    | One tuple       | Multiple pages/tuples |
| Memory usage | Minimal         | Uses buffer pool      |
| Disk scans   | Very repetitive | Fewer                 |
| Cost         | `M + mN`        | `M + ceil(M/(B-2))N`  |
| Performance  | Poor            | Much better           |

### Main Lesson

The algorithms are not asymptotically different in the simple sense, but **constants matter enormously in database systems**.

---

# 65. Important Formulas

## Naive Nested Loop

If R is outer:

```text
Cost = M + mN
```

---

## Block Nested Loop

```text
Cost = M + ceil(M / (B - 2)) × N
```

Where:

```text
B = number of buffer pages
```

---

## Index Nested Loop

```text
Cost ≈ M + mC
```

Where:

```text
C = cost of one index probe
```

`C` depends on the index and data distribution.

---

## Sort-Merge Join

Conceptually:

```text
Cost =
Sort(R)
+ Sort(S)
+ Merge
```

Without significant backtracking:

```text
Merge = M + N
```

---

## Partitioned Hash Join

Approximate cost:

```text
Cost = 3(M + N)
```

This assumes one partitioning pass and one read-back phase.

Recursive partitioning can increase the cost.

---

# 66. Critical Concepts to Understand

## Build Side

The table used to build the hash table.

```text
R
 ↓
Hash table
```

## Probe Side

The table scanned afterward to search the hash table.

```text
S
 ↓
Probe hash table
```

## Outer Table

The table associated with the outer side of a nested-loop-style algorithm.

## Inner Table

The table associated with the inner side.

## Join Key

The attribute(s) used to match tuples.

Example:

```sql
ON R.id = S.id
```

`id` is the join key.

## Partition

A subset of a table created by hashing its join key.

## Buffer Page

A page of memory available for processing data.

---

# 67. The Most Important Mental Models

### Nested Loop

```text
For every R:
    scan S
```

Problem:

```text
Repeated scans
```

---

### Block Nested Loop

```text
For every block of R:
    scan S
```

Improvement:

```text
Process many R tuples at once
```

---

### Index Nested Loop

```text
For every R:
    lookup matching S using index
```

Improvement:

```text
Don't scan all of S
```

---

### Sort-Merge

```text
Sort R
Sort S
   ↓
Walk through both
```

Improvement:

```text
Sorted order eliminates unnecessary searching
```

---

### Hash Join

```text
Hash R
   ↓
Build hash table

Hash S
   ↓
Probe hash table
```

Improvement:

```text
Use hashing to narrow the search
```

---

### Grace Hash Join

```text
R ──→ Partition ──→ R0 R1 R2
S ──→ Partition ──→ S0 S1 S2
                         ↓
                  Join matching
                    partitions
```

Improvement:

```text
Break a huge problem into
memory-sized problems.
```

---

# 68. Common Mistakes

### Mistake 1: Thinking the smallest number of tuples always determines the smaller table

For disk I/O, focus on:

```text
Number of pages
```

not just number of tuples.

---

### Mistake 2: Thinking nested-loop join is always slow

Not necessarily.

If everything fits in memory:

```text
Nested loop can be extremely fast.
```

The major problem is repeated disk I/O.

---

### Mistake 3: Thinking hash equality guarantees key equality

Hash collisions can occur.

Therefore:

```text
Same hash
≠
Definitely same key
```

The actual key must still be compared.

---

### Mistake 4: Forgetting the build/probe distinction

Hash join:

```text
Build → create hash table
Probe → search hash table
```

---

### Mistake 5: Assuming hash join always fits in memory

If the build table is too large:

```text
Partition first.
```

---

### Mistake 6: Thinking partitioning always solves everything

If all keys are identical, they may all go into one partition.

Recursive partitioning cannot fix pathological distributions indefinitely.

---

### Mistake 7: Assuming sort-merge is always worse

Hash join is generally preferable, but sort-merge is useful when:

* Data is already sorted.
* Output needs to be sorted.
* Sorting can serve another operation.

---

### Mistake 8: Confusing sorting's merge phase with join's merge phase

External merge sort has its own merge process.

Sort-merge join also has a merge phase.

They are related but **not the same operation**.

---

# 69. Exam Review — Must-Know Definitions

### Join

Combines tuples from two tables based on a join predicate.

### Equi-Join

Join based on equality.

```text
R.key = S.key
```

### Binary Join

Join involving two input relations.

### Outer Table

The table used by the outer loop/side.

### Inner Table

The table used by the inner loop/side.

### Build Side

The table used to construct a hash table.

### Probe Side

The table used to search the hash table.

### Block Nested-Loop Join

Processes multiple outer pages at once instead of one tuple at a time.

### Index Nested-Loop Join

Uses an existing index to locate matching tuples.

### Sort-Merge Join

Sorts both relations by the join key and then merges them.

### Hash Join

Builds a hash table on one relation and probes it using the other.

### Grace Hash Join

Partitions relations using hashing so individual partitions can fit into memory.

### Bloom Filter

A compact structure used to quickly reject values that definitely do not exist.

### Recursive Partitioning

Partitions an oversized partition again so it can eventually fit into memory.

### Hybrid Hash Join

Keeps a useful/hot partition in memory while spilling other partitions to disk.

---

# 70. Exam Review — Must-Know Methods

## Method 1: Naive Nested Loop

Given:

```text
R: M pages, m tuples
S: N pages
```

Use:

```text
M + mN
```

Then identify which table should be outer.

---

## Method 2: Block Nested Loop

Given:

```text
R = M pages
S = N pages
B = buffer pages
```

Use:

```text
M + ceil(M/(B-2))N
```

Remember:

```text
B - 2
```

is approximately the number of buffers available for the outer relation.

---

## Method 3: Index Nested Loop

Use:

```text
M + mC
```

where `C` is the index probe cost.

Do not assume a fixed value for `C`.

---

## Method 4: Sort-Merge Join

Break it into:

```text
1. Sort R
2. Sort S
3. Merge
```

Without significant duplicate-key backtracking:

```text
Merge = M + N
```

Total:

```text
Sort(R) + Sort(S) + M + N
```

---

## Method 5: Partitioned Hash Join

Remember:

```text
3(M + N)
```

Conceptually:

```text
Read
↓
Partition + Write
↓
Read partitions
↓
Join in memory
```

---

# 71. Exam Review — Algorithm Selection

Ask these questions:

### Question 1

**Does the relevant data fit in memory?**

If yes:

```text
In-memory nested loop
```

or:

```text
In-memory hash join
```

may be extremely fast.

---

### Question 2

**Is there an existing useful index?**

If yes:

```text
Index nested-loop join
```

may be attractive.

---

### Question 3

**Is the data already sorted?**

If yes:

```text
Sort-merge join
```

becomes more attractive.

---

### Question 4

**Does the final output need to be sorted?**

If yes:

```text
Sort-merge join
```

may allow sorting and joining to be combined.

---

### Question 5

**Does the hash table fit in memory?**

If yes:

```text
In-memory hash join
```

If no:

```text
Partitioned/Grace hash join
```

---

### Question 6

**Is the join highly selective?**

If yes:

```text
Bloom filter
```

may significantly improve a hash join.

---

# 72. Big Picture: The Three Main Strategies

The lecture's most important conceptual summary is that there are essentially three major strategies:

```text
              JOIN
                │
       ┌────────┼────────┐
       ↓        ↓        ↓
     LOOPS    HASHING   SORTING
       │        │        │
       ↓        ↓        ↓
 Nested Loop  Hash Join  Sort-Merge
```

Everything else is largely a variation or optimization of these strategies.

---

# 73. Join Algorithm Decision Tree

```text
                    JOIN
                      │
          Does data fit in memory?
             /                 \
           YES                  NO
            │                    │
      ┌─────┴─────┐        Need disk processing
      ↓           ↓               │
   Hash Join   Nested Loop        ↓
                            ┌─────┴──────┐
                            ↓            ↓
                         Hash Join   Sort-Merge
                            │            │
                       Partition      External
                         data           Sort
```

Then consider:

```text
Existing index?
      ↓
Index Nested Loop
```

and:

```text
Already sorted / ORDER BY?
      ↓
Sort-Merge may be advantageous
```

---

# 74. Most Important Lecture Takeaways

1. **Joins are one of the most expensive operations in single-node database systems.**

2. **Disk I/O is the primary cost metric for this lecture.**

3. **Divide and conquer is the major strategy used to make joins efficient.**

4. **Naive nested-loop join is extremely expensive when it repeatedly scans disk.**

5. **Block nested-loop join improves performance by processing multiple pages at once.**

6. **The smaller table is generally preferred on the outer/build side when appropriate.**

7. **Index nested-loop join uses an existing index to avoid scanning the inner table.**

8. **Sort-merge join sorts both tables and then scans them together.**

9. **Sort-merge is especially useful when the data is already sorted or sorted output is needed.**

10. **Hash join is generally the preferred algorithm for equality joins.**

11. **Hash joins have a build phase and a probe phase.**

12. **Bloom filters can make selective hash joins faster.**

13. **If the hash table does not fit in memory, partition the data.**

14. **Grace/partitioned hash join uses partitioning to make smaller in-memory joins possible.**

15. **Recursive partitioning handles partitions that are still too large.**

16. **Hybrid hash join can keep a hot partition in memory to reduce disk I/O.**

17. **Data distribution matters. Extremely skewed data can make every algorithm more difficult.**

18. **There is no universally best join algorithm.**

19. **Query optimizers choose join algorithms based on estimates of costs and data characteristics.**

20. **In practice, hash join is often the fallback because optimizer estimates can be inaccurate.**

---

# 75. Final Cheat Sheet

## Join Cost Formulas

```text
Naive Nested Loop:
M + mN
```

```text
Block Nested Loop:
M + ceil(M/(B-2))N
```

```text
Index Nested Loop:
M + mC
```

```text
Sort-Merge:
Sort(R) + Sort(S) + Merge
```

```text
Merge without significant backtracking:
M + N
```

```text
Partitioned Hash Join:
3(M + N)
```

---

## Join Algorithms

```text
Naive Nested Loop
→ For every R tuple, scan S
```

```text
Block Nested Loop
→ For every R block, scan S
```

```text
Index Nested Loop
→ For every R tuple, probe S's index
```

```text
Sort-Merge
→ Sort both → merge
```

```text
Hash Join
→ Build hash table → probe
```

```text
Grace Hash Join
→ Partition → build/probe each partition
```

```text
Hybrid Hash Join
→ Keep hot partition in memory
→ Spill remaining partitions
```

---

## Hash Join Vocabulary

```text
Build side
    ↓
Create hash table

Probe side
    ↓
Search hash table

Partition
    ↓
Divide data by hash value

Recursive partitioning
    ↓
Partition oversized partitions again

Bloom filter
    ↓
Quickly reject impossible matches
```

---

## What to Remember for the Exam

```text
Smaller outer table
        ↓
Less repeated work
```

```text
More buffer pages
        ↓
Larger blocks
        ↓
Fewer disk scans
```

```text
Existing index
        ↓
Consider index nested loop
```

```text
Already sorted / need sorted output
        ↓
Consider sort-merge
```

```text
Equality join + no useful index
        ↓
Hash join
```

```text
Hash table too large
        ↓
Partitioned hash join
```

```text
Highly selective join
        ↓
Bloom filter can help
```

### The single most important idea

> **Database join optimization is primarily about avoiding unnecessary disk I/O by using memory, indexing, sorting, or hashing to reduce how much data must be repeatedly scanned.**
