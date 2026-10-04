# Database Storage Models, OLTP/OLAP, PAX, and Compression

## 1. Big Picture: Why Storage Models Matter

### Definition

A **storage model** describes how a database physically organizes table data in memory and on disk.

The relational model tells us **what the data logically looks like**:

```text
Table
├── id
├── name
├── age
└── salary
```

But the relational model does **not** require the database to physically store those attributes together.

The database can choose different physical organizations depending on the workload.

```text
Logical Layer
      ↓
Relational tables + SQL
      ↓
Physical Layer
      ↓
Row Store / Column Store / PAX / Compression
      ↓
Disk + Memory
```

### Key Idea

The application can still use:

```sql
CREATE TABLE ...
SELECT ...
INSERT ...
UPDATE ...
DELETE ...
```

even if the database underneath uses a completely different physical storage strategy.

This separation between the **logical model** and **physical implementation** is one of the major strengths of relational databases.

---

# 2. Database Workloads

There are three major workload categories discussed in the lecture:

1. **OLTP**
2. **OLAP**
3. **HTAP**

---

## 2.1 OLTP

### Definition

**OLTP = Online Transaction Processing**

OLTP systems handle many relatively small and fast transactions.

Typical characteristics:

* Lots of transactions
* Small amount of data accessed per transaction
* Frequent inserts
* Frequent updates
* Frequent deletes
* Usually simple queries
* Fast response time is important

### Examples

#### Reddit

Posting a comment might involve:

```text
username
timestamp
post_id
comment_text
```

Only a small amount of data is involved in each transaction.

#### Amazon

Adding an item to a cart might update:

```text
user
item
quantity
timestamp
```

Again, the individual transaction is small.

### Example OLTP Query

```sql
SELECT *
FROM users
WHERE username = 'Andy';
```

The database might use an index on `username` to quickly locate one user.

### OLTP Characteristics

```text
Many transactions
       ↓
Small amount of data per transaction
       ↓
Simple queries
       ↓
Fast reads/writes
```

---

## 2.2 OLAP

### Definition

**OLAP = Online Analytical Processing**

OLAP systems are designed for analyzing large amounts of existing data.

Instead of asking:

> "What is Andy's record?"

you ask:

> "What was the most commonly purchased product in Pittsburgh during a certain period?"

The database may need to examine millions or billions of records.

### Typical OLAP Operations

OLAP queries commonly involve:

* Aggregations
* `GROUP BY`
* Joins
* Window functions
* Nested queries
* Large scans
* Filtering across huge datasets

### Example

```sql
SELECT city, COUNT(*)
FROM orders
GROUP BY city;
```

The database potentially has to examine a large portion of the table.

### OLAP Characteristics

```text
Large amount of existing data
          ↓
Large scans
          ↓
Complex queries
          ↓
Aggregation / joins / analysis
```

---

## 2.3 HTAP

### Definition

**HTAP = Hybrid Transactional/Analytical Processing**

HTAP attempts to support both:

* Fast OLTP transactions
* Fast OLAP analytical queries

within the same system.

### Goal

Ideally:

```text
                ┌───────────────┐
                │    Database   │
                └───────┬───────┘
                        │
             ┌──────────┴──────────┐
             ↓                     ↓
          OLTP                   OLAP
      Fast updates          Fast analytics
```

The challenge is that the physical organization that is ideal for OLTP is often different from the organization ideal for OLAP.

---

# 3. OLTP vs. OLAP

| Concept            | OLTP                          | OLAP                         |
| ------------------ | ----------------------------- | ---------------------------- |
| Full name          | Online Transaction Processing | Online Analytical Processing |
| Main purpose       | Process transactions          | Analyze data                 |
| Data accessed      | Small amount                  | Large amount                 |
| Query complexity   | Usually simple                | Usually complex              |
| Writes             | Frequent                      | Less important               |
| Reads              | Often small lookups           | Large scans                  |
| Typical operations | INSERT, UPDATE, DELETE        | Aggregation, joins, analysis |
| Typical result     | One/few records               | Many records or summary      |
| Storage preference | Row-oriented                  | Column-oriented              |
| Example            | Buy an item                   | Find best-selling items      |

### Memory Trick

**OLTP = Transactions**

> "I need to change or retrieve this one thing."

**OLAP = Analysis**

> "I need to learn something from a lot of things."

---

# 4. Simple Workload Classification

The lecture describes workloads using two dimensions:

```text
                 COMPLEX
                    ↑
                    │
              OLAP  │
                    │
READ HEAVY ─────────┼───────── WRITE HEAVY
                    │
              OLTP  │
                    │
                    ↓
                 SIMPLE
```

The exact chart is not scientific. It is a way to reason about workloads.

### Query Complexity

Complexity can roughly depend on:

* Number of tables joined
* Number of aggregations
* Number of `GROUP BY` operations
* Number of nested queries
* Window functions
* Amount of data scanned

### Important

OLTP does **not** mean every query is a write.

An OLTP system can perform many reads.

The distinction is primarily about the **type of workload and transaction pattern**, not simply whether the SQL statement is `SELECT` or `UPDATE`.

---

# 5. Wikipedia Example

The lecture uses a simplified Wikipedia-like database.

Possible tables include:

```text
Users
Pages
Revisions
```

Conceptually:

```text
Users
  │
  │
  └── login information

Pages
  │
  └── articles

Revisions
  │
  └── different versions of articles
```

The important distinction is between accessing **one record** and analyzing **many records**.

### OLTP Example

Find the latest revision for one page:

```text
Page ID
   ↓
Index lookup
   ↓
Find page
   ↓
Find latest revision
```

This is a small, targeted operation.

### Another OLTP Example

When a user logs in:

```text
Username
   ↓
Find user
   ↓
Update last-login timestamp
```

Again, only a small amount of data is touched.

### OLAP Example

Instead of finding one user, ask:

> How many logins came from `.gov` hosts each month?

Now the database potentially needs to examine the entire login dataset.

That is an analytical workload.

---

# 6. Why the Relational Model Does Not Dictate Storage

A common misconception is:

> "If I have a relational table, all the columns must physically be stored together."

That is false.

A table such as:

```text
Users
--------------------------------
id | name | age | city | salary
```

could physically be stored as:

### Row-oriented

```text
1, Alice, 21, NY, 50000
2, Bob,   30, NY, 70000
3, Carl,  25, NJ, 60000
```

### Column-oriented

```text
id:
1
2
3

name:
Alice
Bob
Carl

age:
21
30
25

city:
NY
NY
NJ
```

The application still sees:

```text
Users(id, name, age, city, salary)
```

The physical organization is hidden underneath.

---

# 7. Row Storage / N-Ary Storage Model

## Definition

The **N-Ary Storage Model (NSM)** is the academic name for a traditional **row store**.

The attributes of each tuple are stored together.

### Example

Suppose we have:

```text
A    B    C    D
----------------
10   20   30   40
11   21   31   41
12   22   32   42
```

A row store physically organizes the data approximately like:

```text
Tuple 1:
10 | 20 | 30 | 40

Tuple 2:
11 | 21 | 31 | 41

Tuple 3:
12 | 22 | 32 | 42
```

The attributes belonging to one tuple are close together.

---

# 8. Why Row Storage Is Good for OLTP

Consider:

```sql
SELECT *
FROM users
WHERE username = 'Andy';
```

If the query needs essentially the entire user record, row storage is excellent.

The database finds Andy's tuple and retrieves all of his attributes together.

### Row Store Lookup

```text
Index
  ↓
Record ID
  ↓
Page
  ↓
Slot Array
  ↓
Tuple
  ↓
All attributes
```

---

# 9. Row Storage and Slotted Pages

The lecture connects row storage to the slotted-page structure discussed previously.

A page contains:

```text
+----------------------+
| Page Header          |
+----------------------+
| Slot Array           |
+----------------------+
|                      |
| Tuple Data           |
|                      |
|                      |
+----------------------+
```

The slot array tells the database where tuples are located inside the page.

### Lookup Process

1. Use an index to locate a record.
2. Obtain the record ID.
3. Determine which page contains the record.
4. Bring that page into memory.
5. Use the slot array.
6. Locate the tuple.
7. Read the tuple.

---

# 10. Row Storage and Inserts

Row stores are also good for inserts.

If a new tuple is:

```text
100 | Alice | 21 | NY | 50000
```

the database can find a page with free space and insert the entire tuple.

Conceptually:

```text
Free Space Map
      ↓
Page with free space
      ↓
Insert entire tuple
```

---

# 11. The Problem with Row Stores for OLAP

Suppose the table contains:

```text
UserID
Username
Password
Host
LastLogin
Address
Phone
Email
...
```

and the query only needs:

```text
Host
LastLogin
```

A row store still brings the other attributes along because they physically occupy the same page.

### Problem

```text
UserID      ← unnecessary
Username    ← unnecessary
Password    ← unnecessary
Host        ← NEEDED
LastLogin   ← NEEDED
Address     ← unnecessary
Phone       ← unnecessary
Email       ← unnecessary
```

The database may have to perform I/O for data the query never uses.

This causes:

* More disk I/O
* More memory usage
* More buffer-pool pressure
* More unnecessary data processing

---

# 12. The Key Row-vs-Column Insight

If the query only needs 2 out of 20 columns:

### Row store

```text
Read:
[A B C D E F G H I J K L M N O P Q R S T]
             ↑ ↑
          needed
```

You still bring the entire tuple.

### Column store

```text
A → don't read
B → don't read
C → don't read
D → READ
E → don't read
...
T → don't read
```

Only the required columns need to be accessed.

---

# 13. Column Storage / Decomposition Storage Model

## Definition

The **Decomposition Storage Model (DSM)**, commonly called a **column store**, stores each attribute separately.

Instead of storing complete tuples together, values from the same column are stored together.

### Row Store

```text
Tuple 1 → A B C D
Tuple 2 → A B C D
Tuple 3 → A B C D
```

### Column Store

```text
Column A → A A A
Column B → B B B
Column C → C C C
Column D → D D D
```

---

# 14. Why Column Stores Are Good for OLAP

Suppose an analytical query only needs:

```text
Host
LastLogin
```

The database can read:

```text
Host column
     ↓
filter

LastLogin column
     ↓
aggregation
```

It does not need to read:

```text
Username
Password
UserID
Address
Phone
...
```

### Main Benefit

**Avoid wasted I/O.**

Only the data necessary for the query is read.

---

# 15. Column Store Example

Suppose:

```text
UserID | Host       | LastLogin | Password
------------------------------------------------
1      | cmu.edu    | Jan       | ...
2      | google.com | Feb       | ...
3      | cmu.edu    | Feb       | ...
4      | yahoo.com  | Mar       | ...
```

A row store might physically have:

```text
1 | cmu.edu    | Jan | ...
2 | google.com | Feb | ...
3 | cmu.edu    | Feb | ...
4 | yahoo.com  | Mar | ...
```

A column store might have:

```text
UserID:
1
2
3
4

Host:
cmu.edu
google.com
cmu.edu
yahoo.com

LastLogin:
Jan
Feb
Feb
Mar

Password:
...
...
...
...
```

If the query asks:

```text
Find users from cmu.edu and group their logins by month.
```

only the relevant columns need to be accessed.

---

# 16. Column Stores and Fixed-Length Values

A major issue with column stores is efficiently finding the corresponding tuple across columns.

Ideally, column values are stored as fixed-length values.

For example:

```text
Integer = 4 bytes
Integer = 4 bytes
Integer = 4 bytes
Integer = 4 bytes
```

Then the database can calculate an offset directly.

### Example

Suppose each value is 4 bytes.

If the database wants tuple 5:

```text
offset = tuple_number × value_size
```

Conceptually:

```text
5 × 4 = 20 bytes
```

So it can jump directly to the required location.

---

# 17. Tuple Reconstruction

Suppose the database filters column `D`:

```text
D:
10
20
30 ← match
40
50
60 ← match
```

The database records:

```text
offset 3
offset 6
```

Then it can go to columns `A`, `B`, and `C` at those same offsets.

```text
D → find matches
      ↓
offsets: 3, 6
      ↓
A → retrieve 3, 6
B → retrieve 3, 6
C → retrieve 3, 6
      ↓
reconstruct tuples
```

This is one reason fixed-length values are useful.

---

# 18. Alternative: Embedded Tuple IDs

Another possibility is storing a tuple ID alongside every value.

For example:

```text
value | tuple_id
------+---------
10    | 1
20    | 2
30    | 3
40    | 4
```

This makes reconstruction easier because the tuple ID explicitly identifies which tuple the value belongs to.

### Why the Lecture Discourages This

It adds overhead.

Instead of storing only:

```text
30
```

you store:

```text
30 + tuple ID
```

for every value.

You also need additional structures to efficiently locate the corresponding values.

### Exam Point

The preferred approach discussed is:

> **Use fixed-length offsets rather than storing tuple IDs with every value.**

---

# 19. The Variable-Length Problem

Strings create a problem.

For example:

```text
Andy
Christopher
Bob
Alexander
```

These have different lengths.

If the values are variable length, you cannot simply calculate:

```text
offset = tuple_number × value_size
```

because there is no single `value_size`.

### Bad Approach

Pad every string:

```text
Andy............
Bob.............
Christopher.....
```

This wastes space.

### Lecture's Solution

Use **dictionary compression**.

Convert:

```text
Andy
Bob
Christopher
Alexander
```

into fixed-length integer codes:

```text
Andy        → 1
Bob         → 2
Christopher → 3
Alexander   → 4
```

The column stores:

```text
1
2
3
4
```

and a separate dictionary maps codes back to strings.

---

# 20. Advantages of Column Storage

### 1. Less I/O

Only required columns are read.

### 2. Better CPU efficiency

Values of the same type/domain are stored together.

### 3. Better compression

Similar data is grouped together.

### 4. Better analytical performance

Large scans over a small number of columns become much faster.

### 5. Better memory behavior

Less unnecessary data enters the buffer pool.

---

# 21. Disadvantages of Column Storage

Column stores are not ideal for everything.

### Point Queries

Finding one complete tuple requires retrieving values from multiple columns.

```text
Column A
Column B
Column C
Column D
    ↓
Reconstruct tuple
```

### Inserts

A new tuple may need to be written into many different column structures.

### Updates

Changing a tuple can require modifying multiple column structures.

### Deletes

Deletes may also require coordination across columns.

---

# 22. Row Store vs. Column Store

| Feature               | Row Store / NSM | Column Store / DSM    |
| --------------------- | --------------- | --------------------- |
| Stores                | Complete tuples | Individual attributes |
| Best for              | OLTP            | OLAP                  |
| Point lookup          | Excellent       | More expensive        |
| Full tuple retrieval  | Excellent       | More expensive        |
| Large analytical scan | Poorer          | Excellent             |
| Insert                | Fast            | More expensive        |
| Update                | Fast            | More expensive        |
| Read selected columns | Wasteful        | Excellent             |
| Compression           | Good            | Excellent             |
| Data locality         | Tuple-oriented  | Column-oriented       |

### Memory Trick

**ROW = record**

> "Give me this person."

**COLUMN = analysis**

> "Analyze this attribute across millions of people."

---

# 23. Why Pure Column Storage Is Not Perfect

Suppose you have:

```text
1 billion tuples
```

but after filtering you only need:

```text
1,000 tuples
```

A pure column store may find those 1,000 tuples efficiently.

But if the query needs:

```text
A
B
C
D
E
```

the database may need to retrieve those values across many separate column areas.

This means reconstructing tuples can become expensive.

The ideal solution should combine:

* Column-store benefits
* Some locality between attributes

That leads to **PAX**.

---

# 24. PAX / Hybrid Storage

## Definition

**PAX = Partition Attributes Across**

PAX is a hybrid organization that combines properties of row and column storage.

The lecture emphasizes that many systems described as "column stores" actually use this type of organization.

---

# 25. Core Idea of PAX

Instead of organizing the entire table as either:

```text
All rows
```

or:

```text
All columns
```

we divide the table into groups of tuples.

Each group is stored in a columnar format.

Conceptually:

```text
Entire Table
│
├── Row Group 1
│    ├── Column A
│    ├── Column B
│    └── Column C
│
├── Row Group 2
│    ├── Column A
│    ├── Column B
│    └── Column C
│
└── Row Group 3
     ├── Column A
     ├── Column B
     └── Column C
```

---

# 26. Row Groups

A **row group** is a group of tuples stored together.

The lecture mentions that different systems use different criteria for determining row-group size.

For example:

* Number of rows
* Amount of data

The exact size can be configured.

---

# 27. Column Chunks

Within each row group, each attribute is stored as a **column chunk**.

Example:

```text
Row Group
┌─────────────────────────┐
│ Column A chunk          │
├─────────────────────────┤
│ Column B chunk          │
├─────────────────────────┤
│ Column C chunk          │
└─────────────────────────┘
```

Thus:

* **Row group** = group of tuples
* **Column chunk** = one column's data within a row group

---

# 28. PAX and File Metadata

PAX-style formats store metadata describing things such as:

* Where data is located
* Compression method
* Dictionaries
* Column chunks
* Other storage information

The lecture emphasizes that the metadata/footer can be written after the data because the system may not know all of the final offsets and information until the file is finished.

Conceptually:

```text
Data
 ↓
Row Groups
 ↓
Column Chunks
 ↓
Metadata/Footer
```

---

# 29. Parquet and ORC

The lecture connects PAX-like organization to common analytical file formats such as:

* **Parquet**
* **ORC**

These formats organize data into row groups and column chunks and use metadata and compression to support analytical workloads.

### Important Terms

```text
File
 ↓
Row Group
 ↓
Column Chunk
 ↓
Compressed Data
```

---

# 30. PAX vs. Pure Column Store

| Feature                             | Pure Column Store | PAX / Hybrid                      |
| ----------------------------------- | ----------------- | --------------------------------- |
| Column locality                     | Excellent         | Excellent                         |
| Compression                         | Excellent         | Excellent                         |
| Selected-column scans               | Excellent         | Excellent                         |
| Tuple reconstruction                | More expensive    | Better locality                   |
| OLAP                                | Excellent         | Excellent                         |
| OLTP                                | Poor              | Better, but not necessarily ideal |
| Common in modern analytical formats | Less typical      | Very common                       |

### Main Idea

PAX attempts to get the best of both worlds:

```text
Column organization
       +
Locality between related tuples
       ↓
Good analytical performance
+
Better tuple reconstruction
```

---

# 31. I/O Is the Main Bottleneck

For this course, the lecture treats **I/O cost as the primary bottleneck**.

The goal is therefore:

> Get as much useful data as possible from each I/O operation.

This motivates compression.

---

# 32. Compression

## Definition

**Compression** reduces the amount of physical storage required for data.

For databases, compression can also reduce I/O.

Suppose an uncompressed page holds:

```text
10 tuples
```

but after compression it holds:

```text
100 tuples
```

The database can retrieve much more useful data per I/O.

```text
Disk
 ↓
Compressed page
 ↓
More useful tuples
 ↓
Memory
```

---

# 33. Compression Trade-Off

Compression introduces a classic trade-off:

```text
More CPU work
      ↕
Less storage + less I/O
```

The database spends CPU time compressing/decompressing data in exchange for:

* Smaller storage
* Less I/O
* More useful data per page

---

# 34. Requirements for Database Compression

The lecture gives several important goals.

### 1. Fixed-Length Values

Compression should ideally produce fixed-length values when offsets are required.

If compressed values have arbitrary sizes:

```text
value 1 → 3 bytes
value 2 → 7 bytes
value 3 → 2 bytes
```

the database cannot simply calculate an offset.

### 2. Delay Decompression

Ideally, queries should operate directly on compressed data.

```text
Compressed data
      ↓
Query directly
      ↓
Decompress only when necessary
```

### 3. Lossless Compression

For ordinary database storage, compression should not change the underlying data.

---

# 35. Lossless vs. Lossy Compression

| Type     | Meaning                                | Database Example          |
| -------- | -------------------------------------- | ------------------------- |
| Lossless | Original data can be recovered exactly | Database storage          |
| Lossy    | Some original information is discarded | MP3/MP4-style compression |

### Lossless

```text
Original
   ↓
Compress
   ↓
Decompress
   ↓
Exact original data
```

### Lossy

```text
Original
   ↓
Compress
   ↓
Some information discarded
   ↓
Approximation
```

The lecture states that ordinary database compression in this context should be **lossless**.

---

# 36. Types of Compression

The lecture discusses four levels:

1. Block/page-level compression
2. Tuple-level compression
3. Attribute-level compression
4. Columnar compression

The most important for modern column stores is **columnar compression**.

---

# 37. Block/Page-Level Compression

A whole block/page is compressed using a general-purpose algorithm.

Examples mentioned:

```text
gzip
Zstandard
LZ4
Snappy
```

Conceptually:

```text
Page
 ↓
Compression algorithm
 ↓
Compressed page
```

### Advantage

Simple and general-purpose.

### Disadvantage

The database may not understand the meaning of the compressed data.

The compression algorithm essentially sees an opaque stream of bytes.

---

# 38. Database-Aware Compression

A database can do better because it understands:

* Columns
* Data types
* Values
* Ordering
* Predicates
* Dictionaries

Therefore, the database can sometimes execute operations directly on compressed representations.

Example:

Instead of:

```text
"Andy" == "Andy"
```

the database may compare:

```text
17 == 17
```

where `17` is the dictionary code for `"Andy"`.

Integer comparison can be much cheaper than repeatedly processing strings.

---

# 39. Run-Length Encoding (RLE)

## Definition

**Run-Length Encoding** compresses repeated consecutive values.

Instead of:

```text
YES
YES
YES
YES
NO
NO
```

store something like:

```text
YES × 4
NO  × 2
```

---

# 40. RLE Example

Suppose:

```text
is_dead

YES
YES
YES
NO
NO
NO
NO
```

Instead of storing every value:

```text
YES YES YES NO NO NO NO
```

store:

```text
YES → start + length 3
NO  → start + length 4
```

The exact implementation can vary, but the fundamental idea is:

> Store a value once and record how many consecutive times it occurs.

---

# 41. When RLE Works Well

RLE is excellent when values repeat.

Example:

```text
YES YES YES YES YES YES
```

Very compressible.

### When RLE Performs Poorly

Alternating values:

```text
YES NO YES NO YES NO
```

Each run has length 1.

In some cases the compressed representation can actually be larger than the original.

---

# 42. Sorting and RLE

Sorting can make RLE much more effective.

Original:

```text
YES
NO
YES
NO
YES
NO
```

Poor compression.

After sorting:

```text
YES
YES
YES
NO
NO
NO
```

Now RLE becomes:

```text
YES × 3
NO × 3
```

### Important Trade-Off

Sorting based on one column may improve compression for that column but make other columns less favorable.

Choosing an optimal ordering can therefore be difficult.

---

# 43. Bit Packing

## Definition

**Bit packing** removes unused bits from fixed-width values.

Suppose a database stores:

```text
age
```

as a 32-bit integer.

But the values are only:

```text
18
21
25
30
40
```

You do not need all 32 bits to represent them.

If the maximum value fits in 8 bits, the database can store them using:

```text
8 bits
```

instead of:

```text
32 bits
```

---

# 44. Bit Packing Example

Without compression:

```text
32 bits × 8 values
```

With bit packing:

```text
8 bits × 8 values
```

This reduces storage while maintaining exact values.

The compressed values remain fixed-length, which preserves the ability to calculate offsets.

---

# 45. Patching

### Problem

Most values may fit into 8 bits, but occasionally there is a large outlier.

Example:

```text
10
15
20
25
30
999999
```

`999999` does not fit in 8 bits.

### Solution: Patching

Store most values in the compact representation.

Use a special marker for the outlier:

```text
Normal values → 8-bit representation

Outlier → special marker
          ↓
       Patch table
          ↓
       Full value
```

This allows the majority of values to remain compact.

---

# 46. Sentinel Values

A special bit pattern can act as a **sentinel**.

For example:

```text
11111111
```

might mean:

> "This is not the real value. Look in the patch table."

The actual value is then stored separately.

### Important

The sentinel cannot simultaneously represent an ordinary value.

If the real data contains that value, it must also be stored through the patch mechanism.

---

# 47. Bitmap Encoding

## Definition

Bitmap encoding represents values using bitmaps.

It is particularly useful when an attribute has **low cardinality**.

### Cardinality

**Cardinality** = number of distinct values in a column.

Example:

```text
is_dead:
YES
NO
```

Cardinality = 2.

That is very low cardinality.

---

# 48. Bitmap Example

Suppose:

```text
is_dead:

YES
NO
YES
YES
NO
```

Create a bitmap for `YES`:

```text
1 0 1 1 0
```

and potentially another for `NO`:

```text
0 1 0 0 1
```

The database can process these bitmaps extremely efficiently using CPU bit operations.

---

# 49. Why Bitmaps Can Be Fast

Modern CPUs can perform operations on many bits at once.

For example:

```text
10110010
AND
11110000
---------
10110000
```

This allows databases to process many boolean conditions simultaneously.

### Best Use Case

Low-cardinality columns such as:

```text
gender
status
is_active
is_deleted
category
```

when the number of unique values is small.

---

# 50. When Bitmap Encoding Is Bad

Suppose a column contains millions of distinct ZIP codes.

Creating a separate bitmap for every unique value would be expensive.

Therefore:

> Do not automatically bitmap-encode every column.

Bitmap techniques are most attractive when cardinality is low.

The lecture also mentions **Roaring Bitmaps** as a technique for compressing sparse bitmaps.

---

# 51. Delta Encoding

## Definition

**Delta encoding** stores the difference between consecutive values instead of storing every absolute value.

Suppose the data is:

```text
100
101
102
103
104
```

Instead of storing:

```text
100
101
102
103
104
```

store:

```text
Base = 100

+1
+1
+1
+1
```

The differences are much smaller.

---

# 52. Delta Encoding Example

For timestamps:

```text
10:00
10:01
10:02
10:03
10:04
```

the database can store:

```text
Base = 10:00

+1 minute
+1 minute
+1 minute
+1 minute
```

This can significantly reduce storage.

---

# 53. Delta Encoding + RLE

Compression techniques can be combined.

Example:

```text
100
101
102
103
104
```

Delta encoding:

```text
100
+1
+1
+1
+1
```

Then RLE:

```text
100
+1 × 4
```

This can compress even further.

### Important

Compression methods can be **composable**.

```text
Original
   ↓
Delta Encoding
   ↓
RLE
   ↓
Smaller representation
```

---

# 54. Frame of Reference

Another technique mentioned is **Frame of Reference (FOR)**.

Instead of storing absolute values, values are represented relative to a base value.

Conceptually:

```text
Base = minimum value

value 1 → difference from base
value 2 → difference from base
value 3 → difference from base
```

The fundamental idea is similar to delta encoding:

> Store small differences instead of large absolute values.

---

# 55. Dictionary Encoding

## Definition

**Dictionary encoding** replaces frequently occurring values with compact integer codes.

Example:

```text
Alice → 1
Bob   → 2
Carol → 3
Dave  → 4
```

The actual column stores:

```text
1
2
1
3
2
1
```

A separate dictionary stores the mapping.

---

# 56. Dictionary Structure

Conceptually:

```text
Code      Value
---------------------
1         Alice
2         Bob
3         Carol
4         Dave
```

The database can convert:

```text
Alice → 1
```

and:

```text
1 → Alice
```

The lecture emphasizes that the system may need both directions.

---

# 57. Why Dictionary Compression Is Powerful

Suppose a column contains long strings:

```text
Christopher
Christopher
Christopher
Christopher
Alexander
Alexander
Alexander
```

Instead of repeatedly storing the strings:

```text
Christopher
Christopher
Christopher
...
```

store:

```text
1
1
1
1
2
2
2
```

with:

```text
1 → Christopher
2 → Alexander
```

This can produce a large reduction in storage.

---

# 58. Dictionary Compression and Queries

A major advantage is that the database can sometimes execute queries on the compressed codes.

Instead of comparing:

```text
"Andy" = "Andy"
```

it can compare:

```text
17 = 17
```

The database can therefore operate on compact integer values.

---

# 59. Order-Preserving Dictionaries

The lecture discusses maintaining ordering in the dictionary.

Suppose:

```text
Alice
Bob
Charlie
David
```

are assigned ordered codes:

```text
Alice   → 1
Bob     → 2
Charlie → 3
David   → 4
```

Then range comparisons can be translated into comparisons of integer codes.

---

# 60. Example: Prefix/Range Query

Suppose the query is conceptually:

```sql
SELECT name
FROM users
WHERE name LIKE 'ad%';
```

Instead of scanning and comparing every original string directly, the database can:

1. Search the dictionary.
2. Determine which dictionary values satisfy the condition.
3. Determine their compressed-code range.
4. Scan the compressed column using integer comparisons.
5. Decompress only the matching values when necessary.

Conceptually:

```text
Original predicate
       ↓
Search dictionary
       ↓
Find code range
       ↓
Scan compressed integers
       ↓
Find matching tuples
       ↓
Decode values if necessary
```

This is one of the major advantages of database-aware compression.

---

# 61. Dictionary Compression and Deletes

Deletes are relatively easy.

A deleted value can be removed from the dictionary if the system no longer needs it.

The lecture notes that **inserts can be more difficult**.

If a new value needs to be inserted between existing ordered dictionary entries, maintaining the ordering can require recompression or restructuring.

---

# 62. Why OLAP Helps Compression

OLAP data is often relatively **immutable**.

That means data is:

* Written
* Analyzed
* Rarely changed

This is excellent for compression.

The database can spend more effort creating a highly compressed representation because it does not need to constantly modify the data.

---

# 63. Compression Comparison

| Technique                 | Best For                       | Main Idea                    |
| ------------------------- | ------------------------------ | ---------------------------- |
| RLE                       | Repeated values                | Store value + run length     |
| Bit packing               | Small numeric ranges           | Remove unused bits           |
| Patching                  | Mostly small values + outliers | Store outliers separately    |
| Bitmap                    | Low cardinality                | Represent values with bits   |
| Delta encoding            | Nearby values                  | Store differences            |
| Frame of Reference        | Values near a base             | Store offsets from reference |
| Dictionary                | Repeated strings/categories    | Replace values with codes    |
| General block compression | General-purpose data           | Compress entire blocks       |

---

# 64. Compression Techniques Can Be Combined

A major concept from the lecture is that compression methods are not necessarily mutually exclusive.

Example:

```text
Original values
      ↓
Delta encoding
      ↓
RLE
      ↓
Dictionary / additional compression
```

The result can be significantly smaller than using only one technique.

### Example

```text
Original:
100, 101, 102, 103, 104

Delta:
100, +1, +1, +1, +1

RLE:
100, +1 × 4
```

---

# 65. Compressed Data Should Ideally Be Queryable

A major goal of database compression is:

> Do not decompress everything just to answer a query.

Traditional compression might look like:

```text
Compressed data
      ↓
Decompress everything
      ↓
Run query
```

Database-aware compression tries to do:

```text
Compressed data
      ↓
Run query directly on compressed representation
      ↓
Decompress only when necessary
```

This can greatly reduce CPU and I/O costs.

---

# 66. MySQL Compressed Pages and Modification Logs

The lecture gives MySQL/InnoDB as an example of compressed pages.

Conceptually:

```text
Disk
 ↓
Compressed page
 ↓
Memory
```

If a write occurs, the system may maintain a **modification log** associated with the compressed page rather than immediately decompressing and rewriting the whole page.

### Modification Log

The modification log records changes that need to be applied.

Conceptually:

```text
Compressed Page
      +
Modification Log
```

When the system eventually needs the full uncompressed contents, it can:

1. Decompress the page.
2. Apply pending modifications.
3. Use the resulting data.
4. Keep or recreate the compressed representation.

---

# 67. Why Modification Logs Help

Suppose the database only needs to update a value and does not need to read the old contents.

Instead of:

```text
Compressed page
      ↓
Decompress
      ↓
Modify
      ↓
Recompress
```

it may be able to do:

```text
Compressed page
      +
Modification log
      ↓
Record update
```

This postpones expensive decompression.

---

# 68. When Decompression Is Necessary

If a query needs to inspect the actual contents of the compressed page, the database may need to:

```text
Compressed page
      ↓
Decompress
      ↓
Apply modification log
      ↓
Read data
```

The lecture's central idea is to postpone this work whenever possible.

---

# 69. Opaque Compression vs. Database-Aware Compression

### Opaque Compression

Algorithms such as:

```text
gzip
Snappy
LZ4
Zstandard
```

generally treat the input as bytes.

The database does not inherently understand the semantic meaning of the compressed representation.

```text
Database
   ↓
Bytes
   ↓
Compression algorithm
   ↓
Compressed bytes
```

### Database-Aware Compression

The database understands:

```text
Column
Data type
Values
Ordering
Dictionary
Predicate
```

Therefore it can potentially execute operations directly on the compressed form.

---

# 70. Overall Storage Evolution

The lecture can be understood as an evolution:

```text
Traditional Row Store
       ↓
Great for OLTP
       ↓
Problem: wasted I/O for OLAP
       ↓
Pure Column Store
       ↓
Great for OLAP
       ↓
Problem: tuple reconstruction / writes
       ↓
PAX / Hybrid Storage
       ↓
Column locality + tuple locality
       ↓
Compression
       ↓
Even less I/O + faster processing
```

---

# 71. Full Storage Model Comparison

| Model              | Physical Organization        | Best Workload             | Main Advantage                      | Main Disadvantage         |
| ------------------ | ---------------------------- | ------------------------- | ----------------------------------- | ------------------------- |
| NSM / Row Store    | Attributes of tuple together | OLTP                      | Fast tuple operations               | Reads unnecessary columns |
| DSM / Column Store | Each attribute separately    | OLAP                      | Reads only needed columns           | Tuple reconstruction      |
| PAX / Hybrid       | Columnar inside row groups   | OLAP / analytical systems | Combines locality + column benefits | More complex organization |

---

# 72. Query-Solving Strategy: Identify the Workload

When given a database scenario on an exam, ask:

### Step 1: How much data does each operation access?

```text
Small amount → likely OLTP
Large amount → likely OLAP
```

### Step 2: Is the query simple or complex?

```text
Simple lookup → likely OLTP
Joins + aggregation + windows → likely OLAP
```

### Step 3: Is the workload update-heavy or analysis-heavy?

```text
Frequent inserts/updates → row-oriented storage
Large analytical scans → column-oriented storage
```

### Step 4: How many columns are needed?

If the query needs:

```text
2 columns out of 100
```

a column store is especially attractive.

### Step 5: Is the data mostly immutable?

If yes, compression becomes especially attractive.

---

# 73. Query Example: Row Store vs. Column Store

Suppose:

```sql
SELECT COUNT(*)
FROM users
WHERE host LIKE '%.gov';
```

### Row Store

Potential process:

```text
Scan pages
   ↓
Load complete tuples
   ↓
Inspect host
   ↓
Ignore many unrelated attributes
   ↓
Count matches
```

Problem:

> The database loads data that the query does not need.

### Column Store

```text
Load host column
       ↓
Scan host values
       ↓
Find .gov matches
       ↓
COUNT(*)
```

Much less unnecessary I/O.

---

# 74. Query Example: Why Row Storage Is Good for Point Lookups

Suppose:

```sql
SELECT *
FROM users
WHERE username = 'Andy';
```

The query needs the complete record.

Row store:

```text
Index
 ↓
Page
 ↓
Tuple
 ↓
All attributes
```

This is exactly what a row store is good at.

---

# 75. Important SQL Connection

The SQL query itself does not have to change.

For example:

```sql
SELECT username, last_login
FROM users
WHERE host LIKE '%.gov';
```

The logical query remains the same.

The database's physical storage layer determines whether the query is executed against:

```text
Rows
```

or:

```text
Columns
```

or:

```text
PAX row groups
```

This demonstrates the separation between **logical SQL** and **physical storage**.

---

# Important Comparisons

## OLTP vs. OLAP vs. HTAP

| Concept | Main Goal         | Data Access   | Typical Query                 |
| ------- | ----------------- | ------------- | ----------------------------- |
| OLTP    | Fast transactions | Small amounts | Lookup/update one user        |
| OLAP    | Analyze data      | Large amounts | Aggregate millions of records |
| HTAP    | Both              | Small + large | Transactions + analytics      |

---

## Row Store vs. Column Store vs. PAX

|                   | Row Store     | Column Store | PAX                           |
| ----------------- | ------------- | ------------ | ----------------------------- |
| Tuple together?   | Yes           | No           | Within row group/local region |
| Columns together? | No            | Yes          | Yes, within row group         |
| OLTP              | Excellent     | Poor         | Moderate                      |
| OLAP              | Moderate/Poor | Excellent    | Excellent                     |
| Compression       | Good          | Excellent    | Excellent                     |
| Point queries     | Excellent     | Poorer       | Better than pure column       |
| Analytical scans  | Poorer        | Excellent    | Excellent                     |

---

## Lossless vs. Lossy

|                                    | Lossless       | Lossy                     |
| ---------------------------------- | -------------- | ------------------------- |
| Exact original recovered?          | Yes            | No                        |
| Appropriate for normal DB storage? | Yes            | Generally no              |
| Example                            | Dictionary/RLE | MP3/MP4-style compression |

---

## RLE vs. Delta Encoding

|          | RLE             | Delta                      |
| -------- | --------------- | -------------------------- |
| Exploits | Repeated values | Similar/consecutive values |
| Stores   | Value + count   | Difference                 |
| Example  | `A A A A → A×4` | `100,101,102 → 100,+1,+1`  |
| Best for | Long runs       | Slowly changing values     |

---

## Dictionary vs. Bitmap

|                    | Dictionary      | Bitmap                     |
| ------------------ | --------------- | -------------------------- |
| Representation     | Integer codes   | Bits                       |
| Best for           | Repeated values | Low-cardinality attributes |
| Strings            | Excellent       | Less direct                |
| CPU bit operations | Good            | Excellent                  |
| Example            | `Alice → 1`     | `YES → 10110`              |

---

# Common Mistakes

* **Mistake:** Thinking OLTP means only writes.

  * OLTP systems can perform many reads; the important distinction is the transactional workload.

* **Mistake:** Thinking OLAP always means `SELECT`.

  * The important distinction is large-scale analytical processing, not merely the SQL keyword.

* **Mistake:** Assuming relational tables dictate physical storage.

  * The relational model is logical; the storage implementation is physical.

* **Mistake:** Thinking row stores are always bad.

  * Row stores are excellent for point lookups and full-tuple operations.

* **Mistake:** Thinking column stores are always faster.

  * Column stores are optimized for analytical workloads, not necessarily individual tuple operations.

* **Mistake:** Forgetting that column stores can require tuple reconstruction.

  * Values may need to be gathered from multiple columns.

* **Mistake:** Confusing PAX with pure column storage.

  * PAX combines columnar organization within groups of tuples.

* **Mistake:** Assuming RLE always compresses data.

  * Alternating values can make RLE ineffective or even larger.

* **Mistake:** Using bitmap encoding for every column.

  * Bitmap encoding is particularly useful for low-cardinality data.

* **Mistake:** Assuming compressed data must always be decompressed before querying.

  * Database-aware compression can allow queries to operate directly on compressed representations.

* **Mistake:** Confusing lossless and lossy compression.

  * Normal database storage in this lecture uses lossless compression.

* **Mistake:** Forgetting why fixed-length values matter.

  * Fixed lengths allow direct offset calculations.

---

# Exam Review

## Must-Know Definitions

### OLTP

Online Transaction Processing; workload characterized by many fast transactions accessing relatively small amounts of data.

### OLAP

Online Analytical Processing; workload focused on analyzing large amounts of existing data using complex queries.

### HTAP

Hybrid Transactional/Analytical Processing; attempts to support both OLTP and OLAP workloads in one system.

### Storage Model

The physical organization of database data in memory and/or on disk.

### NSM

N-Ary Storage Model; row-oriented storage where a tuple's attributes are stored together.

### DSM

Decomposition Storage Model; column-oriented storage where attributes are stored separately.

### PAX

Partition Attributes Across; hybrid storage that organizes data into groups of tuples while storing attributes column-wise within those groups.

### Row Group

A group of tuples stored together in a PAX/columnar file organization.

### Column Chunk

The portion of a particular column stored inside a row group.

### Compression

Reducing the physical size of stored data to reduce storage and I/O costs.

### Lossless Compression

Compression where decompression recovers the exact original data.

### RLE

Run-Length Encoding; represents repeated values using a value and run length.

### Bit Packing

Stores values using only the number of bits actually necessary.

### Patching

Stores values that do not fit the normal compressed representation in a separate patch structure.

### Bitmap Encoding

Represents values using bitmaps, especially effective for low-cardinality attributes.

### Delta Encoding

Stores differences between values rather than complete absolute values.

### Dictionary Encoding

Replaces values with compact integer codes and stores a dictionary mapping codes to original values.

### Cardinality

The number of distinct values in a column.

---

# Must-Know Methods

## How to Identify OLTP vs. OLAP

1. Determine how much data each operation accesses.
2. Determine whether the operation is simple or complex.
3. Look for frequent inserts/updates/deletes.
4. Look for aggregation, joins, window functions, or large scans.
5. Small + transactional → OLTP.
6. Large + analytical → OLAP.
7. Both → potentially HTAP.

---

## How to Choose Row vs. Column Storage

1. Does the application frequently retrieve entire tuples?

   * Prefer row storage.

2. Does the application frequently perform point lookups?

   * Prefer row storage.

3. Does the workload scan huge tables?

   * Prefer column storage.

4. Does a query use only a few columns from a very wide table?

   * Column storage is especially beneficial.

5. Is the data mostly read-only?

   * Column storage + compression is especially attractive.

6. Is tuple reconstruction important?

   * PAX/hybrid storage can provide a better compromise.

---

## How to Analyze a Column-Store Query

```text
1. Identify predicate columns
        ↓
2. Read only needed column chunks
        ↓
3. Find matching tuple offsets
        ↓
4. Retrieve required columns at those offsets
        ↓
5. Perform aggregation / computation
        ↓
6. Decompress only when necessary
```

---

## How to Choose a Compression Method

### Repeated values?

Use:

```text
RLE
```

### Values are small compared to their declared type?

Use:

```text
Bit packing
```

### Mostly small values with occasional outliers?

Use:

```text
Bit packing + patching
```

### Very few unique values?

Consider:

```text
Bitmap encoding
```

### Values are close together?

Use:

```text
Delta encoding / Frame of Reference
```

### Many repeated strings/categories?

Use:

```text
Dictionary encoding
```

### Need general-purpose compression?

Use:

```text
gzip / Zstandard / LZ4 / Snappy
```

---

# Must-Know Syntax / SQL Examples

## Simple OLTP Lookup

```sql
SELECT *
FROM users
WHERE username = 'Andy';
```

### What it does

```text
SELECT *
    ↓
Return all columns

FROM users
    ↓
Use the users table

WHERE username = 'Andy'
    ↓
Find the matching user
```

---

## Analytical Query

```sql
SELECT city, COUNT(*)
FROM orders
GROUP BY city;
```

### What it does

```text
FROM
 ↓
Read orders

GROUP BY city
 ↓
Create groups

COUNT(*)
 ↓
Count records in each group

SELECT
 ↓
Return city + count
```

This type of large aggregation is representative of an OLAP workload.

---

## Analytical Filtering

```sql
SELECT COUNT(*)
FROM users
WHERE host LIKE '%.gov';
```

### Row Store

Potentially reads:

```text
Entire tuples
```

### Column Store

Can focus primarily on:

```text
host column
```

This is the core reason column storage can dramatically reduce I/O for analytical queries.

---

# Simple Architecture Diagram

```text
                    SQL Query
                       │
                       ↓
              Relational Model
                       │
             ┌─────────┴─────────┐
             │                   │
           OLTP                 OLAP
             │                   │
             ↓                   ↓
         Row Store          Column Store
             │                   │
             │              ┌────┴────┐
             │              │         │
             │             PAX    Compression
             │              │         │
             └──────────────┴─────────┘
                       │
                       ↓
                     Disk
```

---

# Complete Conceptual Flow

```text
DATABASE WORKLOAD
       │
       ├── OLTP
       │     │
       │     └── Small/simple/transactional
       │             ↓
       │          Row Store
       │
       ├── OLAP
       │     │
       │     └── Large/complex/analytical
       │             ↓
       │        Column Store
       │             ↓
       │            PAX
       │             ↓
       │        Compression
       │
       └── HTAP
             │
             └── Attempts to support both
```

---

# Final Cheat Sheet / Memory Sheet

## Workloads

```text
OLTP = transactions
OLAP = analysis
HTAP = both
```

### OLTP

```text
Small data
Simple queries
Frequent updates/inserts
Point lookups
→ Row store
```

### OLAP

```text
Huge data
Complex queries
Aggregations
Joins
Window functions
Large scans
→ Column store
```

---

## Storage

```text
NSM = Row Store
DSM = Column Store
PAX = Hybrid
```

### NSM

```text
[A B C D]
[A B C D]
[A B C D]
```

### DSM

```text
A A A
B B B
C C C
D D D
```

### PAX

```text
Row Group 1
 ├─ A A A
 ├─ B B B
 └─ C C C

Row Group 2
 ├─ A A A
 ├─ B B B
 └─ C C C
```

---

## Why Column Stores Win for OLAP

```text
Query needs 2 columns
        ↓
Read 2 columns
        ↓
Avoid unrelated columns
        ↓
Less I/O
        ↓
Less memory pressure
        ↓
Faster query
```

---

## Why Row Stores Win for OLTP

```text
Need one complete tuple
        ↓
Find page
        ↓
Find tuple
        ↓
Read all attributes together
        ↓
Fast
```

---

## Compression

```text
RLE
→ repeated values

Bit Packing
→ values use fewer bits than declared type

Patching
→ handle outliers

Bitmap
→ low cardinality

Delta
→ nearby values

Frame of Reference
→ values close to a base

Dictionary
→ repeated values → integer codes
```

---

## Most Important Compression Idea

```text
Compression
     ↓
Less storage
     ↓
Less I/O
     ↓
More useful data per I/O
     ↓
Faster analytical processing
```

---

## Most Important Exam Relationships

```text
OLTP
 ↓
Point queries
 ↓
Whole tuples
 ↓
ROW STORE
```

```text
OLAP
 ↓
Large scans
 ↓
Few columns
 ↓
COLUMN STORE
 ↓
Compression
```

```text
Pure Column Store
 ↓
Great analytical scans
 ↓
Expensive tuple reconstruction
 ↓
PAX / Hybrid
```

```text
Columnar Data
 ↓
Same data types together
 ↓
Repeated/similar values
 ↓
Better compression
 ↓
Less I/O
 ↓
Faster OLAP
```

---

# One-Minute Review

If you remember nothing else, remember this:

> **Row stores keep tuples together, making them good for OLTP and point queries. Column stores keep attributes together, making them good for OLAP and large analytical scans. PAX divides data into row groups and stores columns within each group, providing a hybrid approach used by many analytical systems. Column stores also compress extremely well because values from the same column share a domain and tend to be similar or repetitive. RLE handles repeated values, bit packing removes unused bits, bitmaps work well for low-cardinality data, delta encoding stores differences, and dictionary encoding replaces repeated values with compact integer codes. The overall goal is to reduce I/O and process as much useful data as possible per I/O operation.**
