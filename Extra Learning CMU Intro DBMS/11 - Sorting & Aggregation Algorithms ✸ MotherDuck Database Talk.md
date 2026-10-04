# Database Systems — Sorting, External Merge Sort, and Aggregation

## 1. Where We Are in the Course

The course has been building a database system from the bottom up:

1. **Disk Manager**

   * Reads and writes pages to disk.
2. **Buffer Pool Manager**

   * Brings pages from disk into memory.
   * Decides which pages stay in memory and which are evicted.
3. **Indexes / Data Structures**

   * B+ trees, hash tables, etc.
   * Allow efficient access to stored data.
4. **Query Execution**

   * Takes a SQL query and actually produces its result.

The next part of the course focuses on **query execution**.

The major topics are:

* Sorting
* Joins
* Query execution plans
* Aggregation
* Hashing
* Cost estimation

This lecture focuses primarily on **sorting and aggregation**.

---

# 2. Query Plans

A **query plan** is the data structure that describes how a database will execute a query.

A query plan is usually represented as a **tree**, although a **DAG (Directed Acyclic Graph)** can sometimes be better.

### General structure

```text
              Final Result
                   ↑
              Projection
                   ↑
                Filter
                   ↑
                 Join
                ↙   ↘
            Table A  Table B
```

### Leaf nodes

The bottom of the query plan contains the data sources:

* Tables
* Files
* Materialized data
* Other operators

### Internal nodes

Internal nodes are **relational operators**, such as:

* Filter
* Projection
* Join
* Sort
* Aggregate

Each operator receives data, performs some computation, and passes its result upward.

### Root node

The root produces the final result that is returned to the client.

---

# 3. Important Query Execution Questions

There are many implementation decisions hidden behind the simple query-plan diagram.

For example:

* Do operators send individual tuples?
* Do they send batches?
* Do they send columns?
* Do they send entire results?
* Does data get **pushed** from the bottom upward?
* Does the parent **pull** data from its children?
* Can intermediate results be reused?

These details matter for performance, but the important high-level idea is:

> A query plan is a collection of relational operators that transform stored data into the final query result.

---

# 4. Why Disk-Based Databases Change Everything

The database system cannot assume that everything fits in RAM.

Two things may be too large for memory:

1. The original table.
2. Intermediate results produced by earlier operators.

For example:

```text
Table
  ↓
Filter
  ↓
Projection
  ↓
Join
  ↓
Huge intermediate result
  ↓
Sort
```

That intermediate result might be larger than the available buffer pool.

Therefore, the database may need to **spill data to disk**.

---

# 5. Why We Care About Sequential I/O

When working with disk-based data, the database wants to maximize:

> **Sequential I/O**

and minimize:

> **Random I/O**

Sequential access means reading or writing data in an organized order:

```text
Page 1 → Page 2 → Page 3 → Page 4 → Page 5
```

Random access might look like:

```text
Page 91 → Page 4 → Page 238 → Page 17 → Page 600
```

Sequential I/O is generally much more efficient.

This is why a database may choose an algorithm that has worse theoretical CPU complexity but performs better on disk.

---

# 6. Why the Database Should Manage Memory

The operating system does not know what the query plan is doing.

The database does.

For example, the database knows:

```text
I'm currently executing a sort.
I will need these pages next.
I am producing a large intermediate result.
I will need these pages again during the merge.
```

Therefore, the database can make better decisions about:

* Which pages to keep
* Which pages to evict
* What to prefetch
* What to write to disk
* When to read data
* How to organize I/O

This is one reason databases use their own **buffer pool manager** rather than relying entirely on OS memory management.

---

# 7. Why Do We Need Sorting?

The relational model is fundamentally **unordered**.

SQL uses **bag semantics**, meaning:

* Duplicate tuples can exist.
* There is no inherent ordering.

If the user wants sorted results, SQL provides:

```sql
ORDER BY
```

Example:

```sql
SELECT *
FROM Enroll
ORDER BY student_id ASC;
```

The database therefore needs efficient sorting algorithms.

---

# 8. Sorting Is Useful Even Without ORDER BY

An important idea:

> A database may sort data even when the user did not explicitly request sorted output.

Why?

Because sorted data can make other operations faster.

### Example: DISTINCT

Suppose the data is:

```text
1
1
2
2
2
3
4
4
```

Because it is sorted, duplicate removal is easy:

```text
1 → keep
1 → discard
2 → keep
2 → discard
2 → discard
3 → keep
4 → keep
4 → discard
```

You only need to compare each value with the previous value.

---

# 9. Sorting Can Help Joins

Some join algorithms use sorting.

A **sort-merge join** works efficiently when both inputs are sorted on the join key.

This is why sorting is an important building block for query execution.

---

# 10. Sorting Can Help Build an Index

Suppose a system needs to temporarily build a B+ tree.

Instead of inserting every record individually:

```text
Insert record 1
Insert record 2
Insert record 3
...
```

it can:

1. Sort the records.
2. Scan the sorted records.
3. Build the B+ tree efficiently.

This can be much faster.

SQL Server has used this idea with temporary structures sometimes referred to as **spooling indexes**.

---

# 11. In-Memory Sorting

If the entire dataset fits in memory, the database can use a normal in-memory sorting algorithm.

Examples include:

* Quicksort
* Heapsort
* Timsort
* Powersort
* Other in-memory algorithms

The exact choice is less important when everything fits in RAM.

### Key rule

```text
If everything fits in memory:
    Use an appropriate in-memory sorting algorithm.
```

The difficult case is when the data does **not** fit in memory.

---

# 12. Mostly-Sorted Data

Some sorting algorithms can take advantage of data that is already mostly sorted.

Instead of treating the input as completely random, they can detect existing order and exploit it.

This can be significantly faster than blindly performing a complete sort.

---

# 13. Runs

External sorting works with **runs**.

A run is a portion of data that is already sorted.

For example:

```text
Input:

7 3 9 2 6 1 8 4

After creating sorted runs:

Run 1:
3 7

Run 2:
2 9

Run 3:
1 6

Run 4:
4 8
```

The database can then merge these sorted runs together.

---

# 14. What Is Actually Being Sorted?

In a database, we are not necessarily sorting just integers.

Conceptually, we are sorting:

```text
(sort_key, value)
```

For example:

```text
(student_id, tuple)
```

The **sort key** is the attribute being used for ordering.

The value represents the data associated with that key.

---

# 15. Early vs. Late Materialization

The value stored alongside a sort key depends on the type of database system.

## Early Materialization

More common in **row stores**.

The sorted data contains:

```text
Sort Key + Entire Tuple
```

Example:

```text
student_id | name | GPA | major
```

When a page is fetched, the row store already has the rest of the tuple.

---

## Late Materialization

Commonly associated with **column stores**.

Instead of carrying the entire tuple around, the system can carry:

```text
Sort Key + Record ID
```

or an offset/pointer.

Example:

```text
student_id → record ID
```

If the rest of the tuple is needed later, the database follows the record ID.

### Why?

Column stores may only need a few columns.

Carrying unnecessary data through every operator wastes memory and bandwidth.

---

# 16. Sort Key

The **sort key** is the attribute or set of attributes used to determine ordering.

Example:

```sql
ORDER BY student_id;
```

The sort key is:

```text
student_id
```

For:

```sql
ORDER BY last_name, first_name;
```

the sort key is effectively:

```text
(last_name, first_name)
```

---

# 17. The Three Main Sorting Cases

A useful exam-level decision tree:

```text
Does all data fit in memory?
        |
       YES
        ↓
Use an in-memory sorting algorithm.
        |
       NO
        ↓
Is there ORDER BY + LIMIT?
        |
       YES
        ↓
Use Top-N Heap Sort.
        |
       NO
        ↓
Use External Merge Sort.
```

---

# 18. Top-N Heap Sort

Top-N sorting is a special optimization.

Suppose the query asks:

```sql
SELECT *
FROM Enroll
ORDER BY student_id
LIMIT 4;
```

You do **not** need to completely sort the entire table.

You only need the best four records.

---

# 19. Top-N Heap Sort Idea

Instead of:

```text
Sort 1 billion records
↓
Return first 4
```

do:

```text
Scan all records once
↓
Maintain a heap containing the best 4
↓
Ignore records that cannot enter the top 4
↓
Return the heap
```

This can dramatically reduce memory usage.

---

# 20. Top-N Example

Suppose we want the smallest four values.

Input:

```text
3, 4, 6, 2, 9, 1, 4, 8
```

Start:

```text
3
```

Add 4:

```text
2? Conceptually sorted:
3, 4
```

Add 6:

```text
3, 4, 6
```

Add 2:

```text
2, 3, 4, 6
```

Now 9 arrives.

Since 9 is larger than the current fourth-best value, it cannot enter the top four.

Ignore it.

Then 1 arrives:

```text
1, 2, 3, 4
```

The previous 6 gets removed.

---

# 21. Top-N With Ties

SQL can request that ties be preserved.

For example:

```text
LIMIT 4 WITH TIES
```

If the fourth-best value is:

```text
4
```

and there are multiple records with key `4`, the database may need to return all of them.

Therefore, the output may contain more than four tuples.

Example:

```text
1
2
3
4
4
4
```

The result has six tuples even though N = 4.

---

# 22. Top-N Complexity

The database must still scan the input:

```text
O(N)
```

because it has to determine whether each record belongs in the top N.

But it does **not** have to fully sort all N records.

The important benefit is memory:

```text
Memory ≈ O(K)
```

where K is the requested top-N size.

This is excellent when:

```text
N = billions
K = 10
```

---

# 23. Memory Allocation for Top-N

The original table does **not** need to fit in memory.

The database can scan the table sequentially:

```text
Disk
 ↓
Page
 ↓
Inspect tuples
 ↓
Update Top-N heap
 ↓
Next page
```

The important structure that needs to fit is the Top-N heap.

If the user requests:

```text
LIMIT 10
```

the heap is small.

If the user requests:

```text
LIMIT 1 billion
```

the heap itself may become too large.

---

# 24. Resource Management

Database systems have to estimate how much memory queries need.

For example:

```text
Query A → 100 MB
Query B → 100 MB
Query C → 100 MB
```

The database needs to decide how much memory each query can use.

Some systems allow queries to borrow unused memory from other queries.

The exact resource-management strategy depends on the database system.

---

# 25. Cardinality Estimates

The database may not know the exact number of output records ahead of time.

Instead, it uses statistics such as:

* Histograms
* Number of distinct values
* Cardinality estimates
* Selectivity estimates

Because estimates can be wrong, systems often use a safety margin.

Example:

```text
Estimated records = 100
Expected actual = maybe 150
```

The database may allocate enough memory for more than 100.

### Important

Query cost estimation is difficult and is a major topic in database systems.

---

# 26. External Merge Sort

When data is too large for memory and a general sort is required, use:

> **External Merge Sort**

The basic idea:

1. Break the input into manageable chunks.
2. Sort each chunk in memory.
3. Write the sorted chunks back to disk.
4. Merge the sorted chunks.
5. Repeat until one completely sorted run remains.

---

# 27. Why Merge Sort Works Well for Databases

The key advantage is that it can perform mostly **sequential I/O**.

Instead of randomly jumping around the disk, the database can:

```text
Read sequentially
↓
Sort
↓
Write sequentially
↓
Read sequentially
↓
Merge
↓
Write sequentially
```

This makes it much better for disk-based data than many ordinary in-memory algorithms.

---

# 28. External Merge Sort Phases

There are two major ideas:

### Phase 0 — Create Sorted Runs

Read chunks that fit into memory.

For each chunk:

```text
Read chunk
↓
Sort in memory
↓
Write sorted run to disk
```

### Merge Passes

Then merge sorted runs:

```text
Run A + Run B
      ↓
Larger sorted run
```

Then:

```text
Run C + Run D
      ↓
Larger sorted run
```

Continue until one sorted run remains.

---

# 29. Two-Way Merge

A **two-way merge** combines two sorted runs.

Example:

```text
Run A:
2 5 8

Run B:
1 3 7
```

Compare the first elements:

```text
2 vs 1 → output 1
```

Then:

```text
2 vs 3 → output 2
```

Then:

```text
5 vs 3 → output 3
```

Continue:

```text
2 5 8
1 3 7
↓
1 2 3 5 7 8
```

---

# 30. Why Only a Few Pages Need to Be in Memory

Suppose we are merging two sorted runs.

We only need the current page from each run:

```text
Run A → [current page]
Run B → [current page]
Output → [output page]
```

So for two-way merge:

```text
2 input buffers
+
1 output buffer
=
3 buffer pages minimum
```

This is a very important concept.

---

# 31. Three-Buffer Example

Suppose:

```text
B = 3
```

Then:

```text
Buffer 1 → Run A
Buffer 2 → Run B
Buffer 3 → Output
```

As the output buffer fills:

```text
Output buffer full
↓
Write it to disk
↓
Reuse buffer
```

The input buffers continue advancing through their runs.

---

# 32. Why We Don't Need the Entire Run in Memory

Suppose Run A is:

```text
2 3 4 6 47 89
```

and Run B is:

```text
1 5 7 8
```

We don't need all of Run A and Run B in memory.

We only need the current pages.

Because each run is already sorted, once we have consumed a value, we know we do not need to go backward.

---

# 33. External Merge Sort Pass 0

Suppose the input is:

```text
[unsorted page]
[unsorted page]
[unsorted page]
...
```

For each page:

```text
Read page
↓
Sort page in memory
↓
Write sorted page to disk
```

The result is:

```text
Sorted run
Sorted run
Sorted run
Sorted run
...
```

Each run is one page in the simple example.

---

# 34. Pass 1

Now merge pairs:

```text
Run 1 + Run 2 → 2-page sorted run

Run 3 + Run 4 → 2-page sorted run

Run 5 + Run 6 → 2-page sorted run
```

---

# 35. Pass 2

Merge the larger runs again:

```text
2-page run + 2-page run
        ↓
4-page run
```

---

# 36. Pass 3

Continue:

```text
4-page run + 4-page run
        ↓
8-page run
```

Eventually the entire dataset becomes one sorted run.

---

# 37. External Merge Sort Visualization

Conceptually:

```text
Pass 0:

Page  Page  Page  Page  Page  Page  Page  Page
 ↓     ↓     ↓     ↓     ↓     ↓     ↓     ↓
 R1    R2    R3    R4    R5    R6    R7    R8


Pass 1:

R1 + R2 → R12
R3 + R4 → R34
R5 + R6 → R56
R7 + R8 → R78


Pass 2:

R12 + R34 → R1234
R56 + R78 → R5678


Pass 3:

R1234 + R5678
       ↓
Final sorted run
```

---

# 38. Number of Passes

For the simple two-way case, the number of passes is approximately:

```text
1 + log₂(N)
```

where:

* `N` = number of pages
* `1` = pass 0
* `log₂(N)` = number of merge levels

---

# 39. I/O Cost

Every pass generally requires reading and writing the data.

Therefore, the cost is approximately:

```text
2N × number of passes
```

For the simple two-way case:

```text
I/O ≈ 2N(1 + log₂N)
```

where N is the number of pages.

The important point is:

> External sorting is dominated by disk I/O.

---

# 40. K-Way External Merge Sort

Instead of merging only two runs at a time, we can merge K runs.

Example:

```text
Run 1
Run 2
Run 3
Run 4
Run 5
```

can be merged together.

This reduces the number of passes.

However, more input runs require more buffer pages.

---

# 41. General External Merge Sort

Suppose:

* `N` = total number of pages
* `B` = available buffer pages

During pass 0, we can sort approximately:

```text
B pages at a time
```

Therefore, the number of initial runs is:

```text
ceil(N / B)
```

---

# 42. Why We Need B-1 Input Buffers

During a merge pass, one buffer page must be reserved for output.

Therefore:

```text
B - 1
```

buffers can be used for input runs.

So a K-way merge can merge approximately:

```text
B - 1 runs
```

at once.

---

# 43. Example: N = 108, B = 5

Given:

```text
N = 108 pages
B = 5 buffer pages
```

### Pass 0

Each run can contain up to 5 pages.

Number of runs:

```text
ceil(108 / 5)
= ceil(21.6)
= 22 runs
```

So we create:

```text
21 runs × 5 pages
+
1 run × 3 pages
```

---

# 44. Pass 1 for N = 108, B = 5

We have:

```text
5 buffers
```

One is needed for output.

Therefore:

```text
4 input buffers
```

So we can merge four runs at a time.

Each new run can contain approximately:

```text
4 × 5 = 20 pages
```

Thus the 22 initial runs can be consolidated into larger runs.

---

# 45. Why More Buffer Pool Space Helps

If we increase B:

```text
More memory
↓
Larger initial runs
↓
Fewer merge passes
↓
Less disk I/O
↓
Better performance
```

This is why memory allocation can have a huge effect on external sorting.

---

# 46. The I/O Stall Problem

A naive implementation might do:

```text
Read
↓
Wait
↓
Compute
↓
Wait
↓
Write
↓
Wait
↓
Read
↓
...
```

The CPU spends a lot of time waiting for I/O.

This is bad.

Modern storage devices can handle multiple outstanding I/O operations.

Therefore, the database wants to overlap:

```text
CPU work
+
I/O work
```

---

# 47. Double Buffering

**Double buffering** helps hide I/O latency.

Instead of using all buffers for one piece of work:

```text
Buffer group A → current work
Buffer group B → next work
```

While one group is:

```text
Sorting / merging / writing
```

the other can be:

```text
Reading the next data
```

Then they switch.

Conceptually:

```text
Time →

Buffers A:
[READ] → [SORT] → [WRITE]

Buffers B:
       [READ] → [SORT] → [WRITE]

Buffers A:
              [READ] → [SORT] → [WRITE]
```

This is called **ping-ponging** between buffer groups.

---

# 48. Tradeoff of Double Buffering

Double buffering improves throughput because it hides I/O stalls.

But it means:

> Fewer buffers are available for creating very large sorted runs.

So there is a tradeoff:

```text
More buffers for sorting
→ larger runs
→ fewer passes

More buffers for overlapping I/O
→ less waiting
→ better throughput
```

A database must balance both.

---

# 49. Modern Storage and Parallel I/O

Modern SSDs achieve high performance when they have many outstanding I/O requests.

Therefore, a database should avoid:

```text
Issue one I/O
↓
Wait
↓
Issue next I/O
↓
Wait
```

Instead:

```text
Issue many I/O operations
↓
Do useful CPU work
↓
Process completed I/O
```

---

# 50. Sorting Optimization: Comparison Cost

In textbook algorithms, comparing two integers looks cheap:

```text
3 < 7
```

Real database values may be:

* Long strings
* VARCHARs
* Multiple columns
* Variable-length values

Comparing two strings may require checking many bytes.

When sorting billions of records, the comparison cost becomes significant.

---

# 51. Code Specialization

One optimization is **code specialization**.

Instead of using a generic comparison function:

```text
compare(a, b)
```

the database can generate specialized code for:

```text
integer comparison
float comparison
string comparison
date comparison
...
```

This reduces overhead.

---

# 52. Why Generic Comparison Is Expensive

A generic comparison may need to determine:

```text
What type is this?
↓
How are these bytes represented?
↓
How should I compare them?
↓
Call comparison function
```

A specialized function already knows the type.

Therefore:

```text
Specialized comparison
↓
Fewer instructions
↓
Less function-call overhead
↓
Faster sorting
```

---

# 53. JIT / Code Generation

Some systems can generate comparison code dynamically.

For example:

```text
SQL query arrives
↓
Determine sort key types
↓
Generate specialized comparison function
↓
Compile to machine code
↓
Use during sorting
```

This is an example of **JIT compilation / code generation**.

---

# 54. Prefix / Suffix Truncation

String comparisons can also be optimized by comparing a fixed-size prefix first.

Example:

```text
Alexander
Alexandria
```

Compare the first few bytes.

If the prefixes differ:

```text
prefix(Alexand...) < prefix(Alexan...)
```

the database can often determine the ordering quickly.

If the prefixes are identical, it performs the more expensive full comparison.

Conceptually:

```text
Fast prefix comparison
        ↓
Different?
   /          \
 YES           NO
 ↓              ↓
Done       Full comparison
```

This avoids expensive full string comparisons in many cases.

---

# 55. Fixed-Length Representations

Variable-length strings are difficult to compare efficiently.

Systems may transform values into normalized binary representations so they can be compared efficiently.

The goal is:

```text
Variable-length complex representation
            ↓
Compact fixed-length representation
            ↓
Fast comparison
```

This is particularly useful when sorting large amounts of data.

---

# 56. Can We Use an Existing Index Instead of Sorting?

Sometimes.

If a suitable sorted index exists, such as a B+ tree, the database can potentially scan its leaf nodes in sorted order.

Example:

```text
B+ Tree leaf nodes:

1 → 2 → 3 → 4 → 5 → 6 → 7
```

Scanning the leaves gives sorted data.

Therefore:

```text
Existing sorted index
↓
Scan leaf nodes
↓
Already sorted
```

No external merge sort is necessary.

---

# 57. Clustered vs. Unclustered Index

This distinction is very important.

## Clustered

The table's tuples are physically stored in approximately the same order as the index.

Example:

```text
B+ tree order:
1 2 3 4 5

Table pages:
1 2 3 4 5
```

Scanning the index can lead to mostly sequential table access.

This is good.

---

## Unclustered

The index order and physical tuple locations are different.

Example:

```text
Index order:
1 → 2 → 3 → 4 → 5

Physical pages:
5 → 1 → 4 → 2 → 3
```

Following the index may cause many random I/Os.

That can be extremely expensive.

---

# 58. Why an Unclustered Index Can Be Bad for ORDER BY

Suppose the query needs:

```text
1
2
3
4
5
```

but the tuples are physically scattered:

```text
Page 50
Page 3
Page 91
Page 7
Page 120
```

The database must perform many random reads.

At that point, doing:

```text
Sequential scan
↓
External merge sort
```

may be faster.

---

# 59. Important Sorting Decision Tree

Memorize this:

```text
                Need sorting?
                     |
                    YES
                     |
          Does suitable sorted
             index exist?
             /             \
           YES              NO
            |                |
   Can it provide data       |
   efficiently?              |
       /      \              |
     YES       NO            |
      |         \            |
Use index       External Merge Sort
```

And before that:

```text
If everything fits in memory:
    Use in-memory sort.

If ORDER BY + LIMIT:
    Use Top-N heap.

Otherwise:
    External merge sort.
```

---

# 60. Aggregation

Aggregation means computing a summary over multiple tuples.

Examples:

```sql
COUNT(*)
SUM(gpa)
AVG(gpa)
MIN(gpa)
MAX(gpa)
```

Often aggregation is combined with:

```sql
GROUP BY
```

Example:

```sql
SELECT course_id, AVG(gpa)
FROM ...
GROUP BY course_id;
```

---

# 61. Two Major Strategies for Aggregation

The lecture presents two major approaches:

1. **Sorting**
2. **Hashing**

This is one of the major recurring ideas in database systems.

The same choice appears in joins:

```text
Sort-Merge Join
vs.
Hash Join
```

---

# 62. Aggregation Using Sorting

Suppose we want:

```sql
SELECT course_id, AVG(gpa)
FROM ...
GROUP BY course_id;
```

We can:

```text
Input
 ↓
Sort by course_id
 ↓
Scan sorted data
 ↓
Compute each group's aggregate
```

---

# 63. Why Sorting Makes GROUP BY Easy

Suppose the sorted data is:

```text
Course 15445 → GPA 3.0
Course 15445 → GPA 3.5
Course 15445 → GPA 4.0
Course 15721 → GPA 2.5
Course 15721 → GPA 3.0
Course 15826 → GPA 3.8
```

All records belonging to the same group are next to each other.

Therefore, we can maintain a running aggregate.

---

# 64. Running Aggregate

For AVG:

Maintain:

```text
count
sum
```

Then:

```text
AVG = sum / count
```

For example:

```text
Course 15445:

GPA:
3.0
3.5
4.0
```

Running values:

```text
count = 1
sum = 3.0

count = 2
sum = 6.5

count = 3
sum = 10.5
```

At the end:

```text
AVG = 10.5 / 3
    = 3.5
```

---

# 65. How the Database Knows a Group Is Finished

Because the data is sorted:

```text
15445
15445
15445
15721
15721
15826
```

When the database moves from:

```text
15445 → 15721
```

it knows there will never be another 15445 later.

Therefore, it can finalize the 15445 aggregate.

This is the key advantage of sorted aggregation.

---

# 66. Aggregation Functions

### COUNT

Maintain:

```text
count += 1
```

### SUM

Maintain:

```text
sum += value
```

### MIN

Maintain:

```text
min = min(min, value)
```

### MAX

Maintain:

```text
max = max(max, value)
```

### AVG

Maintain:

```text
sum += value
count += 1

average = sum / count
```

---

# 67. DISTINCT Using Sorting

Consider:

```sql
SELECT DISTINCT course_id
FROM Enroll;
```

Sort:

```text
1
1
1
2
2
3
4
4
```

Then scan:

```text
1 → output
1 → skip
1 → skip
2 → output
2 → skip
3 → output
4 → output
4 → skip
```

Result:

```text
1
2
3
4
```

---

# 68. Why DISTINCT + ORDER BY Is Especially Convenient

Suppose the query requests:

```sql
SELECT DISTINCT course_id
FROM Enroll
ORDER BY course_id;
```

The database already needs sorted data.

Therefore:

```text
Sort
 ↓
Remove duplicates during scan
 ↓
Already in requested order
```

No separate hash table is necessary.

This is an example of **piggybacking** one operation on another.

---

# 69. Hash-Based Aggregation

If the data does not need to be sorted, hashing is often preferable.

Basic idea:

```text
Scan input
 ↓
Hash grouping key
 ↓
Find group in hash table
 ↓
Update aggregate
```

Example:

```text
course_id = 15445
       ↓
    hash()
       ↓
Hash table entry for 15445
       ↓
Update SUM/COUNT/etc.
```

---

# 70. Why Hashing Can Be Better

If we only need:

```sql
GROUP BY course_id
```

we don't care about the ordering of the groups.

Sorting would do extra work.

Hashing can directly organize records by group.

Therefore:

```text
No ordering required
        ↓
Hash aggregation is often better
```

---

# 71. Sorting vs Hashing

| Requirement               | Good Choice             |
| ------------------------- | ----------------------- |
| Everything fits in memory | In-memory sort or hash  |
| ORDER BY required         | Sorting                 |
| ORDER BY + LIMIT          | Top-N heap              |
| General large sort        | External merge sort     |
| GROUP BY without ordering | Often hashing           |
| DISTINCT + ORDER BY       | Sorting can handle both |
| Sort-merge join           | Sorting                 |
| Hash join                 | Hashing                 |

---

# 72. External Hash Aggregation

What if the hash table does not fit in memory?

We cannot simply keep inserting into one giant hash table.

Instead, we can use **partitioning**.

The process is:

```text
Input
 ↓
Hash using H1
 ↓
Partitions
 ↓
Process one partition at a time
 ↓
Build in-memory hash table
 ↓
Produce results
```

---

# 73. External Hashing — Phase 1

Scan the input.

For every tuple:

```text
key
 ↓
H1(key)
 ↓
Partition number
```

For example:

```text
Partition 0
Partition 1
Partition 2
Partition 3
...
```

The tuples are written to disk according to their partition.

---

# 74. Why Partitioning Helps

Suppose the original input contains:

```text
1 billion tuples
```

but each partition contains:

```text
10 million tuples
```

and 10 million tuples fit in memory.

Then the database can process:

```text
Partition 0
↓
Partition 1
↓
Partition 2
...
```

one at a time.

---

# 75. External Hash Aggregation — Phase 2

For each partition:

```text
Read partition
 ↓
Build in-memory hash table
 ↓
Compute aggregation
 ↓
Write results
 ↓
Clear hash table
 ↓
Process next partition
```

Because all tuples with the same grouping key were sent to the same partition, the database will not need to see that key in another partition.

---

# 76. Why the Same Key Stays Together

A deterministic hash function produces the same result for the same key.

Therefore:

```text
hash(15445) = X
```

every time.

So every occurrence of:

```text
15445
```

goes to the same partition.

Once that partition has been completely processed, the database knows it will not see 15445 in another partition.

---

# 77. Why Use a Different Hash Function in Phase 2?

The first hash function:

```text
H1
```

is used to partition the data.

The second phase can use a different hash function:

```text
H2
```

to distribute the keys inside the in-memory hash table.

Conceptually:

```text
Phase 1:
Input → H1 → Partitions

Phase 2:
Partition → H2 → In-memory hash table
```

This helps avoid reproducing the same distribution problems from the first phase.

---

# 78. Hash Collisions

Different keys can produce the same hash location.

Example:

```text
hash(A) → slot 4
hash(B) → slot 4
```

This is a collision.

A hash table can handle collisions using techniques such as:

* Linear probing
* Chaining
* Other collision-resolution mechanisms

The lecture's example assumes a **linear probing hash table**.

---

# 79. External Hashing and Sequential I/O

Partitioning converts the original data into manageable sequential blocks.

Instead of randomly accessing a huge dataset:

```text
Huge unsorted dataset
```

we create:

```text
Partition 0 → sequential pages
Partition 1 → sequential pages
Partition 2 → sequential pages
...
```

Then process each partition sequentially.

Again, the general database strategy is:

> Transform difficult random access into manageable sequential access.

---

# 80. External Hash Aggregation Example

Suppose we want:

```sql
SELECT DISTINCT course_id
FROM Enroll;
```

### Phase 1

```text
Scan Enroll
 ↓
Hash course_id using H1
 ↓
Write tuple to partition
```

Result:

```text
Partition 0
Partition 1
Partition 2
Partition 3
```

### Phase 2

Process partition 0:

```text
Read partition 0
 ↓
Hash each course_id
 ↓
If key not present:
    insert
Else:
    ignore
```

When finished:

```text
Output distinct values
Clear hash table
```

Then process partition 1, and so on.

---

# 81. External Hashing vs External Sorting

Both algorithms use the same general philosophy.

### External Sort

```text
Partition into sorted runs
↓
Merge runs
```

### External Hash

```text
Partition using hash
↓
Process partitions independently
```

Both:

* Break large data into manageable pieces.
* Spill intermediate data to disk.
* Process one manageable piece at a time.
* Prefer sequential I/O.

---

# 82. The Big Database Pattern

This is one of the most important ideas from the lecture:

> When data is too large for memory, reorganize it into sequential blocks that can be processed efficiently.

For sorting:

```text
Huge data
↓
Sorted runs
↓
Sequential merge
```

For hashing:

```text
Huge data
↓
Hash partitions
↓
Sequential partition processing
```

---

# 83. Why Sequential I/O Keeps Appearing

The database wants to avoid:

```text
Random disk access
```

and favor:

```text
Sequential disk access
```

because sequential I/O is generally much faster.

This idea appears repeatedly in:

* External sorting
* External hashing
* Buffer management
* Query execution
* Join algorithms

---

# 84. Double Buffering + External Algorithms

External algorithms can stall when they need disk I/O.

Double buffering allows:

```text
Worker A:
Compute / merge / write

Worker B:
Read next data
```

Then they switch.

The goal is to make:

```text
CPU work
```

overlap with:

```text
I/O work
```

so the system spends less time idle.

---

# 85. How Everything Connects

The lecture's ideas form one larger pipeline:

```text
SQL Query
   ↓
Query Plan
   ↓
Relational Operators
   ↓
Need to process large data
   ↓
Does data fit in memory?
   ├── YES → In-memory algorithms
   │
   └── NO
        ↓
   External algorithms
        ↓
   Sequential I/O
        ↓
   Buffer Pool
        ↓
   Disk
```

---

# 86. Sorting Decision Cheat Sheet

### Case 1: Everything fits in memory

```text
Use an in-memory sorting algorithm.
```

Examples:

```text
Quicksort
Heapsort
Timsort
Powersort
```

---

### Case 2: ORDER BY + LIMIT

```text
Use Top-N Heap.
```

Example:

```sql
ORDER BY student_id
LIMIT 10;
```

You only need to maintain the best 10 records.

---

### Case 3: Large general sort

```text
Use External Merge Sort.
```

Especially when:

```text
Input > available memory
```

---

### Case 4: Existing suitable clustered B+ tree

You may be able to:

```text
Scan B+ tree leaf nodes
```

instead of sorting.

---

### Case 5: GROUP BY without ordering

Usually consider:

```text
Hash aggregation
```

---

### Case 6: DISTINCT + ORDER BY

Sorting can perform both:

```text
Sort
↓
Remove adjacent duplicates
```

---

# 87. Important Formulas

## Initial external-sort runs

```text
Number of initial runs = ceil(N / B)
```

Where:

* `N` = number of input pages
* `B` = available buffer pages

---

## Merge fan-in

Approximately:

```text
B - 1
```

because one buffer is needed for output.

---

## Two-way merge passes

Approximately:

```text
1 + log₂(N)
```

for the simple case where the initial runs are one page each.

---

## Approximate I/O

For external sorting:

```text
2N × number of passes
```

The `2N` comes from:

```text
N reads + N writes
```

per pass.

---

# 88. Worked External Sort Example

Given:

```text
N = 108 pages
B = 5 buffers
```

### Step 1: Pass 0

```text
ceil(108 / 5)
= 22 initial runs
```

Most runs contain 5 pages.

The final run contains:

```text
3 pages
```

---

### Step 2: Merge

There are:

```text
B - 1 = 4
```

input buffers available.

Therefore, we can merge four runs at a time.

Each full merged run can be approximately:

```text
4 × 5 = 20 pages
```

---

### Step 3: Continue

Each merge pass produces larger runs.

Conceptually:

```text
108 pages
 ↓
22 runs
 ↓
larger runs
 ↓
larger runs
 ↓
final sorted run
```

More buffers would reduce the number of passes.

---

# 89. Top-N vs Full Sort

This distinction is extremely important.

Suppose:

```text
N = 1,000,000,000 records
K = 10
```

Full sort:

```text
Sort all 1 billion records
```

Top-N:

```text
Scan 1 billion records
Maintain 10 best records
```

The second approach avoids doing unnecessary work.

### Remember:

> If you only need a small number of ordered results, don't sort everything.

---

# 90. Sorting vs Hashing — Core Comparison

| Property                    | Sorting             | Hashing                    |
| --------------------------- | ------------------- | -------------------------- |
| Produces ordered data       | Yes                 | No                         |
| Good for ORDER BY           | Yes                 | No                         |
| Good for DISTINCT           | Yes                 | Yes                        |
| Good for GROUP BY           | Yes                 | Usually better             |
| Can support sort-merge join | Yes                 | No                         |
| Hash join support           | No                  | Yes                        |
| Large data                  | External merge sort | External hash/partitioning |
| Sequential I/O              | Yes                 | Yes                        |
| Needs ordering?             | Naturally           | No                         |

---

# 91. Why Hashing Is Often Better for Aggregation

If the query only says:

```sql
GROUP BY course_id
```

the final groups don't need to be sorted.

Sorting does unnecessary work:

```text
Sort everything
↓
Group values
```

Hashing can instead do:

```text
Hash course_id
↓
Find group
↓
Update aggregate
```

Therefore, hashing is often faster.

---

# 92. When Sorting Wins for Aggregation

Sorting becomes especially attractive when the query already requires ordering.

Example:

```sql
SELECT DISTINCT course_id
FROM Enroll
ORDER BY course_id;
```

The sort is already necessary.

So:

```text
Sort
↓
Remove duplicates
↓
Return sorted output
```

This allows the database to reuse the sorting work.

---

# 93. Physical vs Logical Considerations

The database may choose an algorithm based on:

* Available memory
* Number of tuples
* Number of pages
* Number of distinct values
* Whether ordering is required
* Whether an index exists
* Whether the index is clustered
* Disk speed
* SSD parallelism
* Expected intermediate-result size
* Concurrent queries

Therefore, there is rarely one algorithm that is always best.

---

# 94. Cost Estimation

Database systems need to estimate:

```text
How many tuples?
How many pages?
How many distinct values?
How much memory?
How much I/O?
How much CPU?
```

These estimates influence query-plan decisions.

For example:

```text
Estimated result = 1,000 rows
```

might make an in-memory hash table appropriate.

But:

```text
Estimated result = 1 billion rows
```

might require external processing.

---

# 95. Why Estimates Are Imperfect

Database statistics are summaries rather than exact descriptions of the current query result.

Therefore:

```text
Estimated = 100,000
Actual = 500,000
```

is possible.

Systems often add safety margins.

The lecture emphasizes that **query cost estimation is difficult** and is one of the harder areas of database systems.

---

# 96. Important Exam Vocabulary

### Query Plan

A tree/DAG describing how a query is executed.

### Operator

A computation in a query plan, such as filter, projection, join, sort, or aggregation.

### Run

A portion of data that has been sorted.

### External Sort

A sorting algorithm designed for datasets larger than available memory.

### External Merge Sort

Creates sorted runs and repeatedly merges them.

### Top-N Heap

Maintains only the best N records needed by an ordered query with a limit.

### Sort Key

The attribute(s) used to order records.

### Early Materialization

Carry the full tuple with the sort key.

### Late Materialization

Carry a record ID/reference and retrieve remaining columns later.

### Sequential I/O

Reading or writing nearby pages in order.

### Random I/O

Accessing unrelated pages in arbitrary order.

### Double Buffering

Using separate buffer groups to overlap computation and I/O.

### Hash Aggregation

Uses a hash table to maintain groups and their aggregate values.

### External Hash Aggregation

Partitions data using a hash function so each partition can be processed independently.

### Clustered Index

An index whose ordering is aligned with the physical organization of table data.

### Unclustered Index

An index whose ordering does not match the physical organization of table data.

### Cardinality

The number of tuples in a relation or intermediate result.

### Selectivity

The fraction of tuples expected to pass a predicate.

---

# 97. Common Exam Questions

## Q: Why can't we always use quicksort?

Because quicksort assumes the data can be processed efficiently in memory.

If the data does not fit in memory, repeatedly moving data between memory and disk can produce poor I/O behavior.

Use:

```text
External Merge Sort
```

for large disk-based sorting.

---

## Q: Why does external merge sort work well on disk?

Because it organizes work into mostly sequential reads and writes.

---

## Q: Why do we need an output buffer?

During merging, input pages must be read while the resulting sorted data is written somewhere.

Therefore:

```text
Input buffers + output buffer
```

are required.

---

## Q: Why is the merge fan-in B-1?

Because one of the B buffers must be reserved for output.

Therefore:

```text
B buffers
- 1 output buffer
= B-1 input buffers
```

---

## Q: What happens during pass 0?

The database:

```text
Reads chunks
→ sorts them in memory
→ writes sorted runs to disk
```

---

## Q: What happens during later passes?

The database merges already-sorted runs into increasingly larger sorted runs.

---

## Q: Why can Top-N avoid sorting the entire table?

Because only the best N records are required.

The database can maintain a heap containing only those candidates.

---

## Q: Does the original table have to fit in memory for Top-N?

No.

The database can scan the table sequentially while keeping only the Top-N structure in memory.

---

## Q: Why is hashing often better than sorting for GROUP BY?

Because hashing directly groups records without requiring them to be ordered.

---

## Q: Why might sorting still be used for GROUP BY?

If the query already requires sorted output, the database can reuse the sorted data.

---

## Q: Why is an unclustered index potentially bad for ORDER BY?

Because following the index may require random accesses to many table pages.

---

## Q: Why is a clustered index useful for ORDER BY?

Because the table data is physically organized in an order compatible with the index, allowing more sequential access.

---

# 98. Step-by-Step: Solve an External Merge Sort Problem

When given an exam problem, follow these steps.

### Step 1 — Identify N

Find the total number of input pages.

```text
N = total pages
```

### Step 2 — Identify B

Find the number of available buffer pages.

```text
B = buffer pages
```

### Step 3 — Calculate initial runs

```text
ceil(N / B)
```

### Step 4 — Determine merge fan-in

```text
B - 1
```

### Step 5 — Determine how runs grow

Each merge combines approximately:

```text
B - 1
```

runs.

### Step 6 — Continue until one run remains

Think:

```text
Initial runs
↓
Merge
↓
Fewer larger runs
↓
Merge
↓
Fewer larger runs
↓
One final run
```

### Step 7 — Calculate I/O

Use:

```text
2N per full pass
```

and multiply by the number of passes.

---

# 99. Step-by-Step: Solve a Top-N Problem

Given:

```sql
ORDER BY x
LIMIT K
```

Ask:

1. Is only a small number of records needed?
2. Does the query request the top/bottom K?
3. Can a heap hold K records in memory?

If yes:

```text
Scan input once
↓
Maintain Top-K heap
↓
Discard values that cannot enter the heap
↓
Return final K
```

Do not fully sort the input.

---

# 100. Step-by-Step: Solve a Sorting-Based GROUP BY

Given:

```sql
GROUP BY key
```

If using sorting:

1. Sort tuples by `key`.
2. Set current group.
3. Initialize aggregate.
4. Scan tuples.
5. If the key matches the current group:

   * Update aggregate.
6. If the key changes:

   * Finalize previous group.
   * Start new group.
7. Output final group.

---

# 101. Step-by-Step: Solve Hash Aggregation

1. Create hash table.
2. Scan tuples.
3. Hash the grouping key.
4. Find corresponding hash-table entry.
5. If it doesn't exist:

   * Create it.
6. Update aggregate.
7. Continue until input is exhausted.
8. Output hash-table contents.

If the hash table does not fit:

```text
Partition first
↓
Process partitions independently
```

---

# 102. External Hash Aggregation Procedure

### Phase 1

```text
Input
 ↓
H1(key)
 ↓
Partition 0
Partition 1
Partition 2
...
```

Write partitions to disk.

### Phase 2

```text
Partition 0
 ↓
H2(key)
 ↓
In-memory hash table
 ↓
Aggregate
 ↓
Output
```

Then repeat for every partition.

---

# 103. Key Connections to Previous Lectures

This lecture builds directly on earlier database concepts.

### Buffer Pool

External algorithms depend on the buffer pool to:

```text
Read pages
Write pages
Manage memory
Evict pages
```

### Hash Tables

The same hash-table concepts used for indexes can be used for:

```text
Hash aggregation
Hash joins
Partitioning
```

### B+ Trees

B+ trees can sometimes provide sorted access without explicitly sorting.

### Concurrency

Multiple workers may execute query operators simultaneously, which is why the latching/concurrency material from the previous lecture matters.

---

# 104. MotherDuck / DuckDB Guest Talk — Main Ideas

The guest speaker discussed **MotherDuck**, a cloud data warehouse built around DuckDB.

The important conceptual ideas from the talk are:

* Modern hardware is extremely powerful.
* Many workloads do not actually scan their entire data lake.
* A large amount of stored data does not necessarily mean a query needs a distributed system.
* Single-node databases can be extremely efficient.
* DuckDB is lightweight and embeddable.
* MotherDuck combines local DuckDB execution with cloud execution.
* Queries can use **dual execution**, where some operations execute locally and others execute in the cloud.

---

# 105. Why Single-Node Systems Can Be Attractive

Historically, machines were much weaker.

A common strategy was:

```text
Many weak machines
↓
Distributed system
↓
Combine their resources
```

Modern machines can have:

```text
Hundreds of CPU cores
+
Large amounts of RAM
```

Therefore, some workloads can be handled efficiently by a single powerful node.

Advantages include:

* Less network overhead
* Less distributed coordination
* Simpler architecture
* Less resource-management overhead
* Potentially lower cost

---

# 106. MotherDuck's Basic Architecture

The guest speaker described a model where:

```text
Local DuckDB
      ↓
Cloud DuckDB
```

work together.

A query can be divided so that:

```text
Some operations → local
Some operations → cloud
```

For example:

```text
Cloud:
Filter + Aggregate
       ↓
Small result
       ↓
Local:
Join with local dataset
```

This avoids downloading a huge dataset when only a small summary is required.

---

# 107. Why Local Execution Can Be Fast

Network communication adds latency.

If every operation requires:

```text
Browser
 ↓
Network
 ↓
Cloud database
 ↓
Network
 ↓
Browser
```

interactive applications can become slower.

Running DuckDB locally can provide:

```text
Query
 ↓
Local execution
 ↓
Immediate result
```

This is useful for:

* Interactive analytics
* Browser-based applications
* Data previews
* Local development

---

# 108. Scaling Along Two Dimensions

The guest speaker described thinking about workloads using two axes:

```text
Amount of Data
        ↑
        |
        |
        |
        +----------------→ Amount of Compute
```

Different workloads require different solutions.

### Small Data + Small Compute

Use local DuckDB.

### Large Data + Small Compute

Move computation closer to the data.

### Small Data + Large Compute

Use a powerful machine.

### Large Data + Large Compute

Use larger cloud resources / specialized architecture.

---

# 109. Concurrent Users

Even if each query is individually small, many simultaneous users can create a large total compute requirement.

For example:

```text
100 users
×
moderate query
=
large aggregate workload
```

The guest speaker described lightweight DuckDB instances being created on demand for individual users.

These were referred to as **ducklings**.

---

# 110. DuckDB's Extension Model

MotherDuck integrates with DuckDB through its extension mechanisms.

The system can extend several parts of the query lifecycle:

```text
Parse
 ↓
Bind
 ↓
Optimize
 ↓
Execute
```

Cloud-aware functionality can be incorporated into these stages.

---

# 111. Query Splitting

A major idea is determining:

```text
What should execute locally?
What should execute in the cloud?
```

For example:

```text
Local data
      \
       Join → Local
      /
Cloud:
Filter
 ↓
Aggregate
 ↓
Small result
```

The goal is to minimize unnecessary network transfer.

---

# 112. Cloud Compute and Storage

Cloud systems commonly separate:

```text
Compute
Storage
```

The guest speaker discussed using lightweight compute resources that can be:

* Started quickly
* Used efficiently
* Shut down aggressively
* Recreated when needed

This helps reduce cost.

---

# 113. Main Takeaway From the Guest Lecture

The broader database lesson is:

> Database architecture should match the workload and hardware available.

Distributed systems are not automatically better.

Sometimes:

```text
One powerful machine
+
Efficient database engine
```

can outperform a complicated distributed system because it avoids:

* Network overhead
* Coordination
* Distributed scheduling
* Data movement

---

# 114. Final Big-Picture Summary

The most important ideas from this lecture are:

### Query Plans

```text
SQL
 ↓
Query Plan
 ↓
Operators
 ↓
Final Result
```

### Sorting

```text
Fits in memory
→ In-memory sort

ORDER BY + LIMIT
→ Top-N heap

Too large for memory
→ External merge sort
```

### External Merge Sort

```text
Input
 ↓
Create sorted runs
 ↓
Merge runs
 ↓
Larger runs
 ↓
Repeat
 ↓
Final sorted run
```

### External Hashing

```text
Input
 ↓
Partition with hash
 ↓
Process one partition at a time
 ↓
In-memory hash table
 ↓
Aggregation
```

### Aggregation

```text
Need ordering?
    ↓
  Sorting

Don't need ordering?
    ↓
  Hashing is often better
```

### Disk Performance

Always think:

```text
Sequential I/O > Random I/O
```

and:

```text
Overlap computation with I/O
```

using techniques such as double buffering.

---

# 115. Exam Cheat Sheet

## Sorting

```text
In-memory data
→ Use normal sorting algorithm

ORDER BY + LIMIT K
→ Top-K heap

Large data
→ External merge sort
```

## External Sort

```text
Initial runs = ceil(N / B)

Merge fan-in ≈ B - 1

I/O per full pass ≈ 2N
```

## Why B-1?

```text
B total buffers
- 1 output buffer
= B-1 input buffers
```

## Top-N

```text
Scan entire input
+
Maintain only K candidates
```

## DISTINCT with sorting

```text
Sort
↓
Compare current value with previous
↓
Discard duplicates
```

## GROUP BY with sorting

```text
Sort by grouping key
↓
Scan
↓
Maintain running aggregate
↓
Key changes
↓
Finalize group
```

## GROUP BY with hashing

```text
Hash grouping key
↓
Find group
↓
Update aggregate
```

## External hash aggregation

```text
Partition with H1
↓
Process partitions independently
↓
Hash with H2
↓
Build in-memory hash table
```

## Index + ORDER BY

```text
Suitable clustered B+ tree
→ Scan leaves

Unclustered index
→ May cause random I/O
→ External sort may be better
```

## Core Principle

```text
When data does not fit in memory:

Reorganize it into manageable sequential
blocks so the database can process them
with mostly sequential I/O.
```

---

# 116. What You Should Be Able to Do for the Midterm

You should be able to:

* Explain what a query plan is.
* Identify relational operators.
* Explain why databases need external algorithms.
* Explain why sequential I/O is preferred.
* Distinguish in-memory sorting from external sorting.
* Explain Top-N heap sort.
* Explain how ties affect Top-N.
* Calculate the number of initial external-sort runs.
* Calculate the merge fan-in.
* Explain pass 0.
* Explain merge passes.
* Calculate approximate external-sort I/O.
* Explain double buffering.
* Explain why comparisons can be expensive.
* Explain code specialization.
* Explain prefix-based string comparison optimization.
* Explain when a B+ tree can eliminate the need for sorting.
* Distinguish clustered and unclustered indexes.
* Explain sorting-based aggregation.
* Explain hash-based aggregation.
* Explain external hash aggregation.
* Explain why a different hash function may be used during the second phase.
* Explain why hashing is often better for GROUP BY.
* Explain why sorting may still be preferable when ORDER BY is required.
* Recognize the importance of sequential I/O.
* Understand the basic motivation behind single-node/cloud hybrid systems such as MotherDuck.

---

# 117. The Most Important Things to Memorize

If you are short on study time, focus on these:

### 1. External Merge Sort

```text
Sort chunks in memory
→ Write sorted runs
→ Merge runs
→ Repeat
```

### 2. Formula

```text
Initial runs = ceil(N / B)
```

### 3. Merge Fan-In

```text
B - 1
```

### 4. I/O

```text
Approximately 2N per full pass
```

### 5. Top-N

```text
ORDER BY + LIMIT
→ Keep only the best K records
```

### 6. Aggregation

```text
Need sorted output?
→ Sort

Don't need sorted output?
→ Hash
```

### 7. DISTINCT

```text
Sort
→ Remove adjacent duplicates
```

### 8. External Hashing

```text
Partition
→ Process partitions one at a time
```

### 9. Disk Principle

```text
Sequential I/O is preferred over random I/O.
```

### 10. Double Buffering

```text
Compute on one buffer group
while reading/writing another.
```

### 11. Indexes

```text
Clustered sorted index
→ Can often provide sorted access efficiently.

Unclustered index
→ May cause expensive random I/O.
```

### 12. Big Picture

```text
Database performance is not just about
asymptotic CPU complexity.

You must also consider:

Memory
Disk I/O
Sequential vs random access
CPU cost
Concurrency
Network overhead
```
