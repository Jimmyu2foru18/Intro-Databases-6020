# Database Systems – Buffer Optimizations, Storage Models & LSM Trees

## 1. Big Picture

This lecture connects three major areas of database storage:

1. **Buffer Pool Optimizations**

   * Multiple buffer pools
   * Prefetching
   * Scan sharing

2. **How Tables Are Physically Stored**

   * Tuple-oriented storage
   * Index-organized storage
   * Log-structured storage

3. **Log-Structured Merge Trees (LSM Trees)**

   * Memtables
   * SSTables
   * Compaction
   * Level compaction
   * Universal compaction
   * Bloom/filter metadata

The main theme is:

> **A database knows much more about its workload than the operating system does, so the database can make storage decisions specifically for its queries.**

---

# Part I – Buffer Pool Optimizations

## 2. Review: What Is the Buffer Manager?

The **buffer manager** is the database component responsible for managing database pages in memory.

Its job includes:

* Bringing pages from disk into memory
* Keeping track of which pages are in memory
* Giving other database components access to those pages
* Tracking whether pages are dirty
* Deciding which page to evict when memory is full
* Managing the database's buffer pool

### Important terminology

| Term               | Meaning                                             |
| ------------------ | --------------------------------------------------- |
| **Page**           | Fixed-size unit of database storage                 |
| **Frame**          | Location in RAM that holds a page                   |
| **Buffer pool**    | Collection of frames managed by the database        |
| **Eviction**       | Removing a page from memory                         |
| **Dirty page**     | Page modified in memory but not yet written to disk |
| **Page directory** | Metadata that helps locate database pages/files     |

The buffer manager gives the database the illusion that the entire database can be accessed as though it were in memory even when the database is much larger than RAM.

---

# 3. Why Can the Database Optimize Memory Better Than the OS?

The operating system sees the database as an application.

The database, however, knows:

* What query is running
* What the query plan looks like
* Which pages will probably be needed next
* Which pages contain indexes
* Which pages belong to tables
* Whether an access is sequential
* Whether a page is likely to be reused
* Which operation is more important

Therefore:

> **Database-level storage management can use information that the operating system does not have.**

This allows techniques such as:

* Multiple buffer pools
* Prefetching
* Scan sharing
* Query-aware eviction
* Database-level I/O scheduling

---

# 4. Multiple Buffer Pools

Normally we think of a database as having one large buffer pool:

```text
Database
   ↓
Buffer Pool
   ↓
Pages
```

But the database does not have to organize memory as one giant pool.

It can divide memory into multiple buffer pools:

```text
              Buffer Manager
                    |
       +------------+------------+
       |            |            |
   Buffer Pool 1 Buffer Pool 2 Buffer Pool 3
       |            |            |
    Tables        Indexes      Other pages
```

## Why use multiple buffer pools?

Different types of data may have different access patterns.

For example:

* Table pages
* Index pages
* Large objects
* Different databases
* Different tables

could each use different buffer pools.

### Example

You could have:

```text
Buffer Pool 1 → Table A
Buffer Pool 2 → Table B
Buffer Pool 3 → Indexes
Buffer Pool 4 → Large objects
```

Each pool could potentially have different policies.

---

## Benefits

### 1. Better eviction decisions

If you know a pool contains only index pages, you can use a policy designed for those pages.

### 2. Reduced contention

Multiple workers do not necessarily have to fight over one giant data structure.

This can reduce **latch contention**.

### 3. Workload-specific optimization

Different pools can be optimized for different access patterns.

---

## Important Rule: A Page Should Not Exist in Multiple Pools

A physical page should belong to **one buffer pool at a time**.

Why?

Suppose the same page existed in two pools:

```text
Pool A → Page 100
Pool B → Page 100
```

If one copy changes:

```text
Pool A → Page 100 = NEW
Pool B → Page 100 = OLD
```

Now the system has to keep the copies synchronized.

Therefore:

> **One physical page → one buffer pool at a time.**

---

# 5. How Does the Database Decide Which Buffer Pool?

There are several approaches.

## Method 1: Object-Based Mapping

The database can look at an object ID.

For example:

```text
Record ID
   ↓
Object ID
   ↓
Which buffer pool?
```

For example:

```text
Object 10 → Buffer Pool 1
Object 20 → Buffer Pool 2
Object 30 → Buffer Pool 3
```

The database can then immediately determine where to find the page.

---

## Method 2: Hashing

Another simple method is hashing.

Conceptually:

```text
Buffer Pool = hash(page/record ID) % number_of_pools
```

Example:

```text
Page ID = 123
Number of pools = 4

hash(123) % 4
    ↓
Pool 3
```

The exact hash function can vary.

### Important idea

The hash determines **where the page belongs**.

---

# 6. Disk Scheduling With Multiple Buffer Pools

Multiple buffer pools can generate many I/O requests.

For example:

```text
Pool 1 → Read Page 500
Pool 2 → Read Page 102
Pool 3 → Read Page 510
Pool 4 → Read Page 103
```

Instead of performing them randomly, the database can use a **disk scheduler**.

The scheduler sees all requests and can reorder them to improve I/O efficiency.

```text
Requests
   ↓
Disk Scheduler
   ↓
Reordered requests
   ↓
Storage
```

This is another example of the database using information the OS may not understand at the same level.

---

# 7. Prefetching

## Definition

**Prefetching** means retrieving data **before the query explicitly asks for it**, because the database predicts that the data will be needed soon.

### Basic idea

Suppose a query is scanning:

```text
Page 0 → Page 1 → Page 2 → Page 3 → Page 4
```

The query is currently processing Page 1.

The database can recognize the sequential pattern:

```text
Currently processing Page 1

        ↓

Prefetch Page 2
Prefetch Page 3
```

While the query works on Page 1, the disk is loading Pages 2 and 3.

Then:

```text
Query requests Page 2
          ↓
Page 2 is already in memory
          ↓
No waiting for disk
```

---

# 8. Why Prefetching Helps

Without prefetching:

```text
Read Page 1
     ↓
Wait
     ↓
Process Page 1
     ↓
Read Page 2
     ↓
Wait
     ↓
Process Page 2
```

With prefetching:

```text
Read Page 1
     ↓
Process Page 1
     +
Disk fetches Page 2
     ↓
Page 2 already available
```

The goal is to overlap:

> **Computation + I/O**

---

# 9. Database Prefetching vs OS Prefetching

The operating system can also perform prefetching.

However, the OS usually sees a file as a sequence of bytes/pages.

The database understands the **meaning of those pages**.

### Example

Suppose an index tells the database that the query will need:

```text
Page 3
Page 5
Page 8
```

but not:

```text
Page 4
Page 6
Page 7
```

The OS may simply see:

```text
Page 2
Page 3
Page 4
Page 5
...
```

and prefetch sequentially.

The database can be smarter because it knows the query plan and index structure.

---

# 10. Example: Prefetching With a B+ Tree

Suppose we have an index:

```text
              Root
             /    \
          Page 1  Page 2
                    |
              Leaf Pages
              3   5   8
```

The query wants a range of keys.

The database follows the index and determines that it needs:

```text
Page 3 → Page 5 → Page 8
```

These pages may not be physically sequential.

The database can prefetch exactly those pages.

### Key takeaway

> **The database can prefetch based on logical relationships between pages, not just physical sequential order.**

---

# 11. Scan Sharing

## Definition

**Scan sharing** allows multiple queries scanning the same table to share the work of reading the table pages.

It is sometimes called a **synchronized scan**.

---

## Without Scan Sharing

Suppose Query 1 scans Table A:

```text
Q1:
Page 0
Page 1
Page 2
Page 3
Page 4
...
```

Then Query 2 starts scanning the same table.

Without scan sharing:

```text
Q1 → Page 0 → Page 1 → Page 2 → ...

Q2 → Page 0 → Page 1 → Page 2 → ...
```

The database may read the same pages from storage again.

---

## With Scan Sharing

Instead:

```text
Q1
 ↓
Page 0
 ↓
Page 1
 ↓
Page 2
 ↓
Page 3
 ↓
...

Q2 joins Q1's scan
```

Query 2 can "ride along" with Query 1.

Both queries can perform different calculations on the same pages.

---

# 12. Why Scan Sharing Is Powerful

Suppose:

```text
Query 1 → SUM(salary)
Query 2 → AVG(salary)
```

Both queries need to scan the same table.

Instead of:

```text
Read table once for Q1
Read table again for Q2
```

the database can:

```text
Read page
   ↓
Give page to Q1
   ↓
Give same page to Q2
```

Therefore:

> **One page fetch can satisfy multiple pieces of computational work.**

This reduces I/O.

---

# 13. Scan Sharing ≠ Result Caching

These are different concepts.

### Result caching

Run:

```sql
SELECT SUM(salary) FROM Employees;
```

Save the result.

If the exact query runs again:

```text
Return saved result
```

### Scan sharing

The queries may be different:

```sql
SELECT SUM(salary) ...
```

and

```sql
SELECT AVG(salary) ...
```

They share the underlying scan.

### Difference

| Result Caching                        | Scan Sharing                               |
| ------------------------------------- | ------------------------------------------ |
| Reuses query result                   | Reuses page scan                           |
| Happens after computation             | Happens during execution                   |
| Queries usually need matching results | Queries can perform different computations |
| Higher-level optimization             | Lower-level storage/execution optimization |

---

# Part II – Tuple-Oriented Storage

# 14. Review: Slotted Pages

In tuple-oriented storage, a database stores complete tuples/rows inside pages.

A typical slotted page contains:

```text
+-------------------------+
| Page Header             |
+-------------------------+
| Slot Array              |
+-------------------------+
|                         |
| Free Space              |
|                         |
+-------------------------+
| Tuple 3                 |
| Tuple 2                 |
| Tuple 1                 |
+-------------------------+
```

The exact direction can vary between systems.

---

# 15. What Is the Slot Array?

The slot array contains offsets telling the database where tuples are located inside the page.

For example:

```text
Slot 0 → Offset 500
Slot 1 → Offset 420
Slot 2 → Offset 350
```

This provides **indirection**.

The tuple can move within the page without changing its logical identity.

---

# 16. Why Is Indirection Useful?

Suppose:

```text
Tuple A
Tuple B
Tuple C
```

Tuple B is deleted.

The database can compact the page:

```text
Before:
A | B | C

After:
A | C
```

C might physically move.

The slot array is updated to point to C's new location.

The rest of the system does not have to know that C physically moved.

---

# 17. Record IDs

A **Record ID (RID)** provides a way to physically locate a tuple.

Conceptually:

```text
Record ID =
    File ID
    +
    Page ID
    +
    Slot Number
```

Example:

```text
File 3
Page 100
Slot 7
```

means:

```text
File 3
   ↓
Page 100
   ↓
Slot 7
   ↓
Tuple
```

---

# 18. Reading a Tuple in Tuple-Oriented Storage

Suppose an index tells us the RID.

### Step 1

Use the index to find the RID.

```text
Key → RID
```

### Step 2

Use the page directory/file metadata to locate the page.

```text
RID → Page
```

### Step 3

Bring the page into memory if necessary.

### Step 4

Use the slot number to find the tuple.

```text
Page → Slot → Tuple
```

So the process is:

```text
Logical key
    ↓
Index
    ↓
RID
    ↓
Page
    ↓
Slot
    ↓
Tuple
```

---

# 19. Insert in Tuple-Oriented Storage

For an insert:

1. Find a page with enough free space.
2. Retrieve the page.
3. Find/create a free slot.
4. Insert the tuple.
5. Update page metadata.

If no existing page has enough room:

```text
Allocate new page
       ↓
Insert tuple
```

Inserts are generally straightforward.

---

# 20. Updates Can Be Expensive

Suppose we update a tuple.

If the new tuple fits in the existing page:

```text
Old tuple
   ↓
Update
   ↓
Done
```

But suppose the new tuple is larger.

Example:

```text
Old:
Name = James

New:
Name = James + a lot of additional information
```

If there is not enough free space in the page, the database may have to:

```text
Delete old tuple
      ↓
Insert new tuple elsewhere
```

This is more expensive.

---

# 21. Fragmentation

Tuple storage can create wasted space.

For example:

```text
Slot array ↓

[Slots]

Free space
   ↓
   ↓
   ↓

[Tuple][Tuple][Tuple]
```

The slot array grows from one direction while tuple data grows from the other.

They may not meet perfectly.

Therefore, some space may remain unusable.

This is **fragmentation**.

---

# 22. Large I/O for Small Updates

Suppose:

```text
Page size = 16 KB
Tuple update = 8 bytes
```

The database may still need to retrieve the entire page.

Conceptually:

```text
Disk
 ↓
16 KB page
 ↓
Update 8 bytes
```

Therefore, the amount of data physically transferred can be much larger than the data being changed.

---

# 23. Batch Updates

Suppose 10 tuples are stored on 10 different pages.

Updating all 10 may require:

```text
Page 1 → Memory
Page 2 → Memory
Page 3 → Memory
...
Page 10 → Memory
```

Even though the logical operation is:

> "Update 10 tuples."

The physical work may involve 10 separate page fetches.

---

# Part III – Index-Organized Storage

# 24. What Is Index-Organized Storage?

In normal tuple storage:

```text
Index
 ↓
RID
 ↓
Table page
 ↓
Tuple
```

There are two major lookups.

Index-organized storage instead uses the **index itself as the storage structure for the table**.

Conceptually:

```text
Index
 ↓
Tuple
```

The leaf nodes contain the actual tuple rather than a RID.

---

# 25. Normal Index vs Index-Organized Storage

### Tuple-oriented

```text
Key
 ↓
Index
 ↓
RID
 ↓
Page
 ↓
Tuple
```

### Index-organized

```text
Key
 ↓
Index
 ↓
Tuple
```

This can eliminate the additional table lookup.

---

# 26. Structure of Index-Organized Storage

A B+ tree is a common choice.

Conceptually:

```text
              Root
             /    \
          Inner    Inner
            \       /
             Leaf
              ↓
       Key → Offset
              ↓
            Tuple
```

The leaf node contains:

```text
Key + Offset
```

The offset identifies where the tuple is stored within the page.

---

# 27. Reading From Index-Organized Storage

Suppose we want:

```text
email = james@example.com
```

### Step 1

Search the tree.

### Step 2

Reach the correct leaf.

### Step 3

Search the key-offset array.

### Step 4

Use the offset to find the tuple.

So:

```text
Key
 ↓
B+ Tree
 ↓
Leaf
 ↓
Binary search key-offset array
 ↓
Tuple
```

There is no separate RID → table heap lookup.

---

# 28. Systems Mentioned in the Lecture

The lecture mentions index-organized storage as being used/supported by systems such as:

* SQLite
* MySQL/InnoDB
* Oracle
* SQL Server

The exact default behavior varies by system.

---

# Part IV – Log-Structured Storage

# 29. Why Do We Need Another Storage Model?

Tuple-oriented storage is good for many reads and straightforward inserts.

However, updates can be expensive.

The database may have to:

```text
Read page
 ↓
Modify tuple
 ↓
Write page
```

Some storage systems also do not allow arbitrary in-place modification.

Examples mentioned in the lecture include:

* Hadoop-style storage
* Google Colossus
* Amazon S3/object storage

These systems may favor creating new data rather than overwriting existing data.

This motivates:

> **Log-structured storage**

---

# 30. Log-Structured Storage – Main Idea

Instead of repeatedly modifying data in place:

```text
OLD RECORD
   ↓
UPDATE
   ↓
OVERWRITE
```

we append new information:

```text
Record A
Record B
Record C
Update A
Update B
Delete C
...
```

The key idea is:

> **Prefer appends and sequential I/O over random in-place updates.**

---

# 31. Why Are Appends Fast?

Sequential I/O is generally easier for storage systems to perform efficiently than many random writes.

Instead of:

```text
Write Page 100
Write Page 7
Write Page 903
Write Page 12
```

we can try to write sequentially:

```text
Page 100
Page 101
Page 102
Page 103
...
```

This can greatly improve write performance.

---

# 32. LSM Tree

A common implementation of log-structured storage is the:

**Log-Structured Merge Tree (LSM Tree)**

The lecture traces this family of ideas to work from the 1990s and earlier log-structured file systems.

The major components are:

```text
             Memory
                |
             Memtable
                |
             Flush
                ↓
             SSTable
                |
          Compaction
                ↓
       Larger SSTables
```

---

# 33. Memtable

The **memtable** is an in-memory data structure containing recent changes.

It could use structures such as:

* B+ trees
* Skip lists
* Tries
* Other ordered structures

The exact structure isn't the important part.

The important idea is:

> **New writes initially go into the memtable.**

---

# 34. SSTable

An **SSTable** is an immutable, sorted file stored on disk.

SSTable generally means:

**Sorted String Table**

The exact expansion can vary historically, but the important properties are:

* Sorted
* Immutable
* Stored on disk
* Created from a memtable

---

# 35. Writing to an LSM Tree

Suppose we insert:

```text
Key 101 → A1
Key 102 → B1
```

They go into the memtable:

```text
MEMTABLE

101 → A1
102 → B1
```

Now suppose we update:

```text
101 → A2
```

The in-memory structure can change:

```text
101 → A2
102 → B1
```

The old A1 value does not necessarily have to remain in the active memtable.

---

# 36. Memtable Becomes Full

Eventually:

```text
Memtable
████████████████
████████████████
████████████████
        ↓
      FULL
```

The database then:

1. Stops using the current memtable for new writes.
2. Creates a new memtable.
3. Converts the old memtable into an SSTable.
4. Sorts the data by key.
5. Writes the SSTable to disk.
6. Continues accepting writes in the new memtable.

Conceptually:

```text
Memtable
   ↓
Sort
   ↓
Flush
   ↓
SSTable
   ↓
Disk
```

---

# 37. SSTables Are Immutable

Once an SSTable is written:

> **We do not normally modify it in place.**

Instead, new changes are written to newer structures.

Example:

```text
Old SSTable:
101 → A1

New SSTable:
101 → A2
```

The newest value is the logically valid one.

---

# 38. Multiple SSTables

Over time:

```text
Memtable
   ↓
SSTable 1

Memtable
   ↓
SSTable 2

Memtable
   ↓
SSTable 3

Memtable
   ↓
SSTable 4
```

These files are generally ordered by age:

```text
Newest
   ↓
SSTable 4
SSTable 3
SSTable 2
SSTable 1
   ↓
Oldest
```

Within each SSTable, keys are sorted:

```text
100
101
102
103
104
...
```

---

# 39. Why Do We Need Compaction?

Suppose we update the same key many times:

```text
101 → A1
101 → A2
101 → A3
101 → A4
...
101 → A1000
```

We don't need all 1,000 versions forever.

We generally only need the latest logically valid version.

Therefore:

> **Compaction combines SSTables and removes obsolete information.**

---

# 40. What Compaction Does

Suppose:

```text
SSTable A:
101 → A1
102 → B1

SSTable B:
101 → A2
102 → B2
```

If B is newer:

```text
New compacted SSTable:

101 → A2
102 → B2
```

The old versions can be discarded.

---

# 41. Deletes in LSM Trees

Deletes work differently from tuple-oriented storage.

Instead of immediately finding and physically removing the tuple, the system can write a **delete marker** (often called a tombstone).

Example:

```text
101 → DELETE
```

The physical old record may still exist in an older SSTable.

But logically:

```text
101 does not exist
```

During compaction, obsolete records can eventually be removed.

---

# 42. Tombstone Example

Suppose:

```text
Old SSTable:
101 → James
```

Then we delete James:

```text
New SSTable:
101 → DELETE
```

A read checks the newest information.

It sees:

```text
101 → DELETE
```

Therefore:

```text
Return "not found"
```

even though the older physical record still exists.

---

# 43. Reads in an LSM Tree

A read usually proceeds from newest information to oldest.

### Step 1

Check the memtable.

```text
Is key 101 here?
```

If yes:

```text
Return result
```

### Step 2

If not found, search SSTables.

Start with the newest SSTables.

```text
Memtable
   ↓
Newest SSTable
   ↓
Older SSTable
   ↓
Older SSTable
   ↓
...
```

The first valid version found is the one that matters.

---

# 44. The Read Problem

LSM trees make writes fast.

But now a read may have to search many files.

Imagine:

```text
Memtable
SSTable 1
SSTable 2
SSTable 3
SSTable 4
SSTable 5
SSTable 6
...
```

Finding one key could potentially require checking many structures.

This is one of the main trade-offs of LSM trees:

> **Faster writes can come at the cost of more complicated/slower reads.**

---

# 45. Summary Tables / Metadata

To improve reads, LSM systems maintain metadata describing what keys might exist in each SSTable.

For example:

```text
SSTable 1 → Keys A–F
SSTable 2 → Keys G–M
SSTable 3 → Keys N–Z
```

If we're searching for:

```text
Key = X
```

we immediately know:

```text
SSTable 3 might contain X
```

but:

```text
SSTable 1 cannot contain X
SSTable 2 cannot contain X
```

This avoids unnecessary disk reads.

---

# 46. Bloom Filters

A **Bloom filter** is one possible structure used to determine whether a key **might** exist in a file.

Important property:

> A Bloom filter can produce false positives, but not false negatives.

Meaning:

### Bloom filter says:

**"Definitely not here."**

→ It is safe to skip the file.

### Bloom filter says:

**"Maybe here."**

→ You must actually check the file.

Example:

```text
Search key 101

Bloom filter:
"Nope."
   ↓
Skip SSTable
```

or:

```text
Bloom filter:
"Maybe."
   ↓
Actually search SSTable
```

The lecture also mentions that range-based filters can be useful, especially for range queries.

---

# 47. Blind Writes vs Read-Modify-Write

An important distinction:

### Blind write

You know the entire new value already.

For example:

```text
SET salary = 80,000
```

You don't necessarily need to read the old value first.

You can simply write:

```text
Key → New Tuple
```

### Read-modify-write

Suppose:

```sql
UPDATE Employee
SET age = age + 1;
```

You need the existing value to calculate the new one.

Conceptually:

```text
Read old tuple
      ↓
Calculate new value
      ↓
Write new tuple
```

---

# 48. Full Tuple vs Individual Attribute

In the LSM approach discussed in lecture, the stored value is generally the **full tuple**, not just one isolated attribute.

For example:

```text
Key 101 →

Name: James
Age: 22
Major: CS
GPA: 3.5
```

If the tuple is updated, the system may store a new version containing the tuple's attributes.

This makes reading the logical record possible even when older versions exist elsewhere.

---

# Part V – Compaction

# 49. What Is Compaction?

**Compaction** is the process of merging SSTables and removing obsolete records.

It can:

* Remove old versions
* Remove deleted records when safe
* Reduce the number of SSTables
* Organize key ranges
* Improve read performance

But:

> **Compaction itself costs CPU, memory, disk reads, and disk writes.**

---

# 50. Why Not Compact Everything Immediately?

Because compaction is expensive.

Suppose we have:

```text
10 GB of SSTables
```

A compaction might require:

```text
Read 10 GB
      ↓
Process/merge
      ↓
Write 10 GB
```

That is a lot of I/O.

If the database spends all its time compacting:

```text
Compaction ↑
Query performance ↓
```

Therefore, compaction must be carefully scheduled.

---

# 51. Compaction Triggers

A database may trigger compaction based on things such as:

* SSTable size
* Number of SSTables
* Size of a particular level
* Number of overlapping key ranges
* Number of files
* Other system-specific thresholds

There is no single perfect trigger for every workload.

---

# 52. Level Compaction

**Level compaction** organizes SSTables into multiple levels.

Conceptually:

```text
Level 0
  ↓
Level 1
  ↓
Level 2
  ↓
Level 3
  ↓
...
```

The SSTables generally become larger as you move down the levels.

---

# 53. Level 0

Level 0 is special.

New SSTables are created from memtables and placed here.

Because they are created at different times, their key ranges can overlap.

Example:

```text
SSTable 1: A → R
SSTable 2: E → T
SSTable 3: B → Q
```

These ranges overlap heavily.

---

# 54. Why Overlapping Ranges Are a Problem

Suppose we want key:

```text
Q
```

It could exist in:

```text
SSTable 1
SSTable 2
SSTable 3
```

Therefore, we may have to search multiple SSTables.

This makes reads more expensive.

---

# 55. Level 1 and Below

During compaction, Level 0 SSTables are merged into larger SSTables.

The goal is to create **non-overlapping key ranges within a level**.

Example:

```text
Level 1:

SSTable A → A–F
SSTable B → G–M
SSTable C → N–T
SSTable D → U–Z
```

Now if we search for:

```text
Q
```

we know exactly which SSTable could contain it:

```text
N–T
```

Therefore:

> **Only one SSTable needs to be searched at that level.**

---

# 56. Why Multiple Levels?

Multiple levels provide a balance between:

* Write efficiency
* Read efficiency
* Compaction cost

The levels progressively organize the data so that searches become more targeted.

The system does **not** necessarily have a fixed number of levels forever. The structure can grow as the amount of data grows.

---

# 57. Example of Level Compaction

Suppose Level 0 contains:

```text
SSTable A: A–R
SSTable B: E–T
SSTable C: B–Q
```

Compaction reads them and merges their contents.

Suppose the resulting Level 1 files are:

```text
SSTable D: A–H
SSTable E: I–T
```

Now the ranges do not overlap.

Searching for:

```text
Q
```

only requires checking:

```text
SSTable E
```

instead of all three Level 0 files.

---

# 58. Merge Algorithm

Compaction resembles a **sort-merge** process.

Suppose:

```text
Newest SSTable:
101 → A2
102 → B2
103 → DELETE

Older SSTable:
101 → A1
102 → B1
103 → C1
104 → D1
```

Use cursors:

```text
Newest cursor
       ↓
Older cursor
       ↓
```

Compare keys.

### Key 101

Both contain 101.

The newest version wins:

```text
101 → A2
```

Ignore:

```text
101 → A1
```

### Key 102

Again:

```text
102 → B2
```

Ignore older B1.

### Key 103

Newest record says:

```text
103 → DELETE
```

Therefore the older:

```text
103 → C1
```

is obsolete.

### Key 104

Only the older table contains it:

```text
104 → D1
```

Keep it.

---

# 59. Universal Compaction

The lecture also describes **universal compaction**.

Instead of maintaining multiple levels, the system maintains SSTables and performs more targeted merges.

Conceptually:

```text
SSTable 1
SSTable 2
SSTable 3
     ↓
Compaction
     ↓
Large SSTable
```

Then:

```text
SSTable 4
SSTable 5
     ↓
Compaction
     ↓
Large SSTable
```

---

# 60. Level vs Universal Compaction

| Feature    | Level Compaction                    | Universal Compaction             |
| ---------- | ----------------------------------- | -------------------------------- |
| Levels     | Multiple                            | Essentially one level            |
| Key ranges | Non-overlapping within lower levels | Can remain more flexible         |
| Reads      | Can be efficient                    | Potentially more files to search |
| Writes     | More background organization        | Can favor write-heavy workloads  |
| Compaction | More structured                     | More targeted                    |
| Main idea  | Organize data into levels           | Merge selected SSTables          |

---

# 61. Level Compaction – Main Trade-Off

### Advantages

* Better-organized reads
* Non-overlapping key ranges
* Easier to identify which SSTable may contain a key

### Disadvantages

* Compaction can be expensive
* Large amounts of data may be read and rewritten
* Can create **write amplification**

---

# 62. Universal Compaction – Main Trade-Off

### Advantages

* Can be useful for heavy write workloads
* More targeted compactions
* Avoids some repeated level-to-level rewriting

### Disadvantages

* Reads may need to inspect more SSTables
* Finding a key can potentially require more work

---

# 63. Read vs Write Trade-Off

This is one of the most important ideas from the lecture.

### Tuple-oriented storage

Generally:

```text
Reads → straightforward
Writes/updates → potentially expensive
```

### Log-structured storage

Generally:

```text
Writes → very fast
Reads → potentially more complicated
Compaction → expensive
```

Think of it as:

```text
                 Faster Writes
                      ↑
                      |
                LSM / Log
                      |
                      |
                Tuple Store
                      |
                      ↓
                 Simpler Reads
```

The actual performance depends on the workload and implementation.

---

# 64. Write Amplification

## Definition

**Write amplification** occurs when a small logical write causes significantly more physical data to be written.

Example:

```text
Logical operation:
Update 1 tuple
```

But because of repeated compactions:

```text
Write tuple
   ↓
Read/write during compaction
   ↓
Read/write again
   ↓
Read/write again
```

The same logical data may be physically rewritten multiple times.

---

# 65. Example of Write Amplification

Suppose:

```text
Update:
Key 101 → A2
```

Initially:

```text
SSTable 1
```

Later it gets compacted:

```text
SSTable 1 + SSTable 2
       ↓
SSTable 3
```

Later:

```text
SSTable 3 + SSTable 4
       ↓
SSTable 5
```

The original update may have been physically rewritten multiple times.

That is **write amplification**.

---

# 66. LSM Tree Overall Picture

```text
                 WRITES
                   ↓
              +----------+
              | Memtable |
              +----------+
                   |
                 Flush
                   ↓
          +----------------+
          |   SSTables     |
          +----------------+
                   |
             Compaction
                   ↓
       +----------------------+
       | Larger SSTables      |
       | Organized by levels  |
       +----------------------+
                   |
                 Reads
                   ↑
          Search newest first
```

---

# Part VI – RocksDB / LevelDB

# 67. LevelDB

The lecture discusses **LevelDB**, a key-value storage engine associated with Google and the Bigtable team.

It is an example of an embedded storage engine using log-structured techniques.

---

# 68. RocksDB

**RocksDB** originated as a fork of LevelDB associated with Facebook/Meta.

It became widely used as a storage component in other systems.

The lecture emphasizes that RocksDB uses a buffer manager rather than simply relying on memory mapping for its storage management.

---

# 69. Why Is RocksDB Important?

RocksDB provides a practical example of LSM-based storage.

It supports compaction strategies such as:

* Level compaction
* Universal compaction

and has been used as a storage component in various database systems.

---

# Part VII – Project 1

# 70. Project 1 Components

The lecture says Project 1 involves building a buffer manager system.

Major components include:

### 1. ARC Replacement Policy

You implement the **Adaptive Replacement Cache (ARC)** algorithm.

Its job is to decide:

> **Which page should be evicted when the buffer pool is full?**

---

### 2. Disk Scheduler

The disk scheduler handles requests to read/write pages.

Conceptually:

```text
Database component
       ↓
"Give me Page 100"
       ↓
Disk Scheduler
       ↓
Storage
       ↓
Memory
```

The scheduler manages the I/O operations.

---

### 3. Buffer Pool

The buffer pool stores pages in frames.

When a requested page isn't present:

```text
Page request
    ↓
Check page table
    ↓
Page missing
    ↓
Disk scheduler
    ↓
Load page
    ↓
Need free frame?
    ↓
If no → ARC chooses victim
    ↓
Insert page
```

---

# 71. ARC in Project 1

ARC stands for:

**Adaptive Replacement Cache**

The goal is to adapt between:

* Recently used pages
* Frequently used pages

rather than relying on only one concept.

ARC uses lists and **ghost entries** to remember information about recently evicted pages.

The lecture says the detailed ARC algorithm will be covered in recitation.

---

# 72. Asynchronous I/O

The disk scheduler is expected to support asynchronous I/O.

The basic idea is:

```text
Request I/O
     ↓
Don't necessarily block everything
     ↓
I/O happens
     ↓
Callback/promise signals completion
```

This allows other work to continue while storage operations are pending.

---

# 73. Project 1 Architecture

A simplified view:

```text
            Query / Database
                   |
                   ↓
             Buffer Manager
                   |
             +-----+-----+
             |           |
        Page Table       ARC
             |           |
             +-----+-----+
                   |
                   ↓
             Disk Scheduler
                   |
                   ↓
                Storage
```

The buffer manager:

* Receives page requests
* Checks whether pages are already in memory
* Requests missing pages from the disk scheduler
* Uses ARC when it needs to evict something
* Manages frames/pages

---

# 74. Project Warning

The lecture emphasizes:

> **Only modify the files the project instructions tell you to modify.**

The grading environment may overwrite or replace other files.

The projects are also cumulative, meaning later projects build on the buffer manager implementation.

Therefore:

> A broken Project 1 implementation can make later projects significantly harder.

---

# Part VIII – OLTP vs OLAP

The guest speaker from SingleStore introduces another major concept.

There are two broad database workload categories:

1. **OLTP**
2. **OLAP**

---

# 75. OLTP

**OLTP = Online Transaction Processing**

Typical characteristics:

* Many concurrent transactions
* Small reads/writes
* Fast response times
* Frequent updates
* Individual records matter
* Strong transactional requirements
* ACID properties are important

Examples:

```text
Bank transaction
Online purchase
Updating an account
Changing a user's information
```

---

# 76. OLTP Example

Suppose a bank transaction says:

```text
Transfer $100
from Account A
to Account B
```

The system needs to quickly find specific rows and update them.

It does not need to scan the entire database.

Therefore, row-oriented structures are often useful.

---

# 77. OLTP Data Structures

The speaker mentions structures such as:

* B-trees/B+ trees
* Skip lists
* Row-oriented storage

The goal is efficient point lookups and updates.

Conceptually:

```text
Find one row
     ↓
Index
     ↓
Row
     ↓
Update
```

---

# 78. OLAP

**OLAP = Online Analytical Processing**

Typical characteristics:

* Large queries
* Large scans
* Aggregations
* Reporting
* Dashboards
* Data warehouses
* Large datasets
* Queries may process huge amounts of data

Example:

```sql
SELECT department, AVG(salary)
FROM Employees
GROUP BY department;
```

The database may need to process a very large percentage of the table.

---

# 79. OLAP Data Structures

OLAP systems commonly use **column-oriented storage**.

Examples mentioned by the speaker include:

* Snowflake
* ClickHouse
* Amazon Redshift
* Google BigQuery
* Vertica

The key strength is:

> **Very fast large-scale scans.**

---

# 80. Row Store vs Column Store

| Feature            | Row Store        | Column Store               |
| ------------------ | ---------------- | -------------------------- |
| Stores             | Complete rows    | Columns                    |
| Point lookups      | Very strong      | Generally less natural     |
| Individual updates | Generally strong | Generally more complicated |
| Large scans        | Less specialized | Very strong                |
| OLTP               | Common           | Less common                |
| OLAP               | Less specialized | Common                     |
| Example workload   | Bank transaction | Analytics/reporting        |

---

# 81. Why Not Just Use One?

The speaker emphasizes that row and column stores are optimized for fundamentally different workloads.

### Row store

Excellent for:

```text
"Find this one customer and update their address."
```

### Column store

Excellent for:

```text
"Calculate the average purchase amount across billions of rows."
```

These workloads have very different requirements.

---

# 82. SingleStore's Approach

The guest speaker describes SingleStore as a system that attempts to combine strong analytical performance with transactional capabilities.

The speaker describes the approach as:

> A column store with techniques that make it work well for transactional workloads.

The system can use:

* Column-oriented storage
* Secondary hash indexes
* A row store for hot data
* Techniques for transactional access
* In-memory row-store tables for workloads that need them

---

# 83. Hot Rows

A **hot row** is a row that is accessed or modified frequently.

The speaker describes a row-store component that can be used for these hot rows while the larger analytical data remains column-oriented.

Conceptually:

```text
                 SingleStore
                     |
          +----------+----------+
          |                     |
      Hot data              Large data
          |                     |
      Row store            Column store
          |                     |
       Fast point          Fast scans
        access
```

---

# 84. Hybrid Workloads

Some applications need both:

```text
Transactions
      +
Analytics
```

Examples mentioned include:

* Dashboards
* Logistics
* Manufacturing
* Streaming
* AI-related workloads

The challenge is supporting:

```text
Fast individual updates
        +
Large analytical scans
```

without one workload destroying the performance of the other.

---

# Part IX – Key Comparisons

## 85. Tuple-Oriented vs Index-Organized vs LSM

| Feature             | Tuple-Oriented             | Index-Organized                  | LSM                           |
| ------------------- | -------------------------- | -------------------------------- | ----------------------------- |
| Main storage        | Pages of tuples            | Index contains tuples            | Memtable + SSTables           |
| Read                | Index → RID → tuple        | Index → tuple                    | Memtable → SSTables           |
| Insert              | Straightforward            | Tree insertion/rebalancing       | Very fast append-style        |
| Update              | Can be expensive           | Tree/page update                 | New version/write             |
| Delete              | Modify tuple/page          | Modify index structure           | Delete marker/tombstone       |
| In-place updates    | Yes                        | Yes, depending on implementation | Generally avoided on SSTables |
| Compaction          | Not central                | Tree maintenance                 | Very important                |
| Sequential writes   | Less emphasized            | Less emphasized                  | Major advantage               |
| Read complexity     | Relatively straightforward | Direct lookup                    | Can involve multiple files    |
| Write amplification | Lower in this context      | Depends                          | Can be significant            |

---

# 86. Buffer Optimization Comparison

| Optimization          | Main Idea                   | Main Benefit               |
| --------------------- | --------------------------- | -------------------------- |
| Multiple buffer pools | Separate memory pools       | Workload-specific policies |
| Prefetching           | Load pages before needed    | Hide I/O latency           |
| Scan sharing          | Multiple queries share scan | Avoid duplicate page reads |
| Disk scheduling       | Reorder I/O                 | Better storage efficiency  |

---

# 87. Level vs Universal Compaction

### Level Compaction

```text
Level 0
 ↓
Level 1
 ↓
Level 2
 ↓
Level 3
```

Focus:

> Organize data into increasingly larger levels with non-overlapping key ranges.

### Universal Compaction

```text
SSTable
SSTable
SSTable
   ↓
Targeted merge
   ↓
Larger SSTable
```

Focus:

> Perform more targeted merges without maintaining the same multi-level organization.

---

# Part X – Important Definitions

## Buffer Pool

Database-managed memory used to hold database pages.

## Buffer Manager

Component that manages pages and frames in the buffer pool.

## Multiple Buffer Pools

Dividing the buffer pool into separate regions that can use different policies.

## Prefetching

Loading pages before they are requested because the database predicts they will be needed.

## Scan Sharing

Allowing multiple queries to share the same underlying table scan.

## Tuple-Oriented Storage

Storage where complete records/rows are stored together in pages.

## Slotted Page

A page layout containing a slot array and tuple data, allowing tuples to move within a page.

## Record ID (RID)

Identifier used to physically locate a tuple, typically involving file/page/slot information.

## Index-Organized Storage

Storage where the index structure itself contains the table's tuples.

## Log-Structured Storage

A storage design that favors appending new data instead of performing in-place updates.

## LSM Tree

Log-Structured Merge Tree; uses memory structures and immutable sorted files with compaction.

## Memtable

In-memory structure containing recent writes.

## SSTable

Immutable sorted file on disk.

## Compaction

Merging SSTables and removing obsolete versions.

## Tombstone

A marker indicating that a key/record has been logically deleted.

## Level Compaction

Compaction strategy using multiple levels with increasingly larger SSTables and generally non-overlapping ranges at lower levels.

## Universal Compaction

Compaction strategy that keeps SSTables in a more flexible organization and performs targeted merges.

## Write Amplification

When one logical write results in multiple physical writes because of rewriting/compaction.

## Bloom Filter

Probabilistic structure that can tell you a key is definitely absent or possibly present.

## OLTP

Online Transaction Processing; many small, fast, concurrent transactional operations.

## OLAP

Online Analytical Processing; large-scale analytical queries and scans.

## Row Store

Stores complete records together.

## Column Store

Stores values by column, making large scans/analytics efficient.

---

# Part XI – Common Mistakes

## Mistake 1: Thinking Prefetching Means Reading Everything

No.

Prefetching means:

> Predict what will be needed and load it ahead of time.

The database should not blindly load every page.

---

## Mistake 2: Confusing Scan Sharing With Result Caching

**Result caching:**

```text
Query → Result → Save result
```

**Scan sharing:**

```text
Query 1 ─┐
         ├→ Same page scan
Query 2 ─┘
```

They operate at different levels.

---

## Mistake 3: Thinking an SSTable Is Modified in Place

SSTables are intended to be immutable.

Instead:

```text
Old SSTable
+
New SSTable
     ↓
Compaction
     ↓
New SSTable
```

---

## Mistake 4: Thinking Deletes Immediately Remove the Physical Data

In an LSM system, a delete can initially be represented by a tombstone.

The old physical record may remain until compaction.

---

## Mistake 5: Thinking LSM Reads Only Search One File

Not necessarily.

A key may exist in:

```text
Memtable
SSTable 1
SSTable 2
SSTable 3
...
```

The system uses ordering, metadata, filters, and compaction to reduce the work.

---

## Mistake 6: Confusing Bloom Filters

A Bloom filter can say:

> "Definitely not here."

or:

> "Maybe here."

It cannot safely say:

> "Definitely here."

because false positives are possible.

---

## Mistake 7: Thinking Compaction Is Free

Compaction requires:

* CPU
* Memory
* Disk reads
* Disk writes
* I/O bandwidth

Too much compaction can slow normal queries.

---

# Part XII – Exam-Focused Concepts

## 88. Know These Three Buffer Optimizations

### Multiple Buffer Pools

**Question:** Why?

**Answer:**

To separate workloads/data types and allow different replacement strategies while reducing contention.

---

### Prefetching

**Question:** Why?

**Answer:**

To retrieve pages before they are requested and hide disk latency.

---

### Scan Sharing

**Question:** Why?

**Answer:**

To let multiple queries reuse the same page scan rather than independently scanning the same table.

---

# 89. Know the Storage Progression

Remember:

```text
Tuple-Oriented
      ↓
Index-Organized
      ↓
Log-Structured
```

### Tuple-oriented

```text
Index → RID → Page → Tuple
```

### Index-organized

```text
Index → Tuple
```

### LSM

```text
Write → Memtable → SSTable → Compaction
```

---

# 90. Know the LSM Write Process

Memorize this sequence:

```text
1. Write to Memtable
        ↓
2. Memtable fills
        ↓
3. Flush to SSTable
        ↓
4. Create new Memtable
        ↓
5. Repeat
        ↓
6. Compact SSTables
        ↓
7. Remove obsolete versions
```

---

# 91. Know the LSM Read Process

```text
1. Check Memtable
        ↓
2. Check newest SSTables
        ↓
3. Check older SSTables
        ↓
4. Use metadata/filters to skip files
        ↓
5. Return newest valid version
```

---

# 92. Know Why Compaction Exists

Without compaction:

```text
SSTable 1
SSTable 2
SSTable 3
SSTable 4
SSTable 5
...
```

Reads become increasingly expensive.

Compaction:

```text
Many SSTables
      ↓
Merge
      ↓
Fewer organized SSTables
```

It removes:

* Old versions
* Obsolete updates
* Old delete information when safe

---

# 93. Know the Fundamental LSM Trade-Off

### Benefit

```text
Fast writes
```

because the system favors sequential/appended writes.

### Cost

```text
More complicated reads
+
Compaction
+
Write amplification
```

Therefore:

> **LSM trees trade some read/maintenance complexity for efficient writes.**

---

# Part XIII – Practice Questions

## Question 1

What is the purpose of multiple buffer pools?

### Answer

To separate different types of data/workloads so the database can use different policies and reduce contention.

---

## Question 2

Why should a physical page generally exist in only one buffer pool?

### Answer

Having duplicate copies would create consistency problems because both copies could be modified independently.

---

## Question 3

What is prefetching?

### Answer

Loading pages into memory before the query explicitly requests them based on predicted future access.

---

## Question 4

Why can database prefetching be more sophisticated than OS prefetching?

### Answer

The database understands the query plan, indexes, and logical relationships between pages. The OS generally does not understand the contents or meaning of database pages.

---

## Question 5

What is scan sharing?

### Answer

Allowing multiple queries that scan the same table to share the same underlying page scan.

---

## Question 6

What is the difference between scan sharing and result caching?

### Answer

Result caching reuses a previously computed query result. Scan sharing allows multiple queries to share the process of reading the underlying data.

---

## Question 7

What does a Record ID usually contain?

### Answer

Information such as:

```text
File ID
Page ID
Slot number
```

which identifies the physical location of a tuple.

---

## Question 8

What problem does the slot array solve?

### Answer

It provides indirection so tuples can move within a page without requiring every reference to the tuple to be changed.

---

## Question 9

What is index-organized storage?

### Answer

A storage model where the index structure itself contains the tuples rather than merely pointing to tuples elsewhere.

---

## Question 10

Why can index-organized storage make reads simpler?

### Answer

The lookup can go directly from the index to the tuple instead of:

```text
Index → RID → Page → Tuple
```

---

## Question 11

Why are LSM-tree writes fast?

### Answer

Writes are initially performed in memory and are eventually flushed as sequential/immutable SSTables instead of requiring frequent random in-place updates.

---

## Question 12

What is a memtable?

### Answer

An in-memory data structure containing recent writes/changes.

---

## Question 13

What happens when a memtable becomes full?

### Answer

It is flushed to disk as an SSTable, and a new memtable is created for incoming writes.

---

## Question 14

What is an SSTable?

### Answer

An immutable, sorted file containing database records/changes stored on disk.

---

## Question 15

Why do LSM systems need compaction?

### Answer

To merge SSTables, remove obsolete versions/deletes, reduce the number of files, and improve read efficiency.

---

## Question 16

Suppose:

```text
Old SSTable:
101 → A1

New SSTable:
101 → A2
```

Which value should a read return?

### Answer

```text
A2
```

because it is the newer version.

---

## Question 17

What is a tombstone?

### Answer

A record indicating that a key has been logically deleted.

---

## Question 18

Why can a deleted record still physically exist?

### Answer

Because the delete may initially be represented by a tombstone. Physical cleanup can occur later during compaction.

---

## Question 19

What is a Bloom filter used for?

### Answer

To quickly determine whether a key is definitely absent from an SSTable or might be present.

---

## Question 20

Can a Bloom filter have a false positive?

### Answer

Yes.

It can say:

```text
"Maybe present"
```

when the key is actually absent.

It should not produce false negatives.

---

## Question 21

Why are Level 0 SSTables problematic for reads?

### Answer

Their key ranges can overlap, so a key may potentially exist in multiple SSTables.

---

## Question 22

Why are lower levels useful in level compaction?

### Answer

They organize SSTables into non-overlapping key ranges, allowing a search to identify which SSTable could contain a key.

---

## Question 23

Why don't we compact everything constantly?

### Answer

Compaction consumes CPU, memory, disk bandwidth, and I/O. Excessive compaction can slow normal query execution.

---

## Question 24

What is write amplification?

### Answer

When one logical write causes the data to be physically rewritten multiple times, often because of compaction.

---

## Question 25

What is the main difference between OLTP and OLAP?

### Answer

**OLTP** focuses on many small, fast, concurrent transactions.

**OLAP** focuses on large analytical queries, scans, aggregations, and reporting.

---

# Part XIV – Scenario Questions

## Scenario 1

A query scans:

```text
Page 1
Page 2
Page 3
Page 4
Page 5
```

While processing Page 2, the database loads Pages 3 and 4.

### What optimization is this?

**Answer: Prefetching**

---

## Scenario 2

Two queries need to scan the same table but calculate different aggregates.

### What optimization could allow them to share the table scan?

**Answer: Scan sharing / synchronized scans**

---

## Scenario 3

You need to find one employee by primary key.

The system uses:

```text
B+ tree → RID → Page → Tuple
```

### What storage model is this?

**Answer: Tuple-oriented storage**

---

## Scenario 4

The leaf node of the B+ tree directly contains the employee tuple.

### What storage model is this?

**Answer: Index-organized storage**

---

## Scenario 5

A database receives thousands of updates and stores them in memory before flushing sorted immutable files to disk.

### What storage architecture is this?

**Answer: LSM/log-structured storage**

---

## Scenario 6

You see:

```text
101 → A1
101 → A2
101 → A3
101 → DELETE
```

What eventually allows the system to remove the obsolete versions?

**Answer: Compaction**

---

## Scenario 7

You search for key 500. A Bloom filter says:

> "Definitely not present."

What should the database do?

**Answer: Skip that SSTable.**

---

## Scenario 8

A Bloom filter says:

> "Key 500 might be present."

What should the database do?

**Answer: Actually search/check the SSTable.**

---

## Scenario 9

A Level 0 SSTable covers:

```text
A–R
```

and another covers:

```text
E–T
```

You need key Q.

Could either file contain Q?

**Answer: Yes.**

Their ranges overlap.

---

## Scenario 10

After compaction, the database has:

```text
SSTable 1 → A–F
SSTable 2 → G–M
SSTable 3 → N–Z
```

You need key Q.

Which SSTable needs to be searched?

**Answer: SSTable 3.**

---

# Part XV – Super Important Takeaways

If you only have a few minutes before an exam, know these:

### 1. Database knows more than the OS

```text
Database
   ↓
Knows query plan + data relationships
   ↓
Can make smarter storage decisions
```

---

### 2. Three buffer optimizations

```text
Multiple Buffer Pools
        +
Prefetching
        +
Scan Sharing
```

---

### 3. Tuple storage

```text
Key
 ↓
Index
 ↓
RID
 ↓
Page
 ↓
Tuple
```

---

### 4. Index-organized storage

```text
Key
 ↓
Index
 ↓
Tuple
```

---

### 5. LSM storage

```text
Write
 ↓
Memtable
 ↓
SSTable
 ↓
Compaction
 ↓
Larger SSTables
```

---

### 6. SSTables are immutable

Don't think:

```text
Open SSTable → Modify it
```

Think:

```text
Create new data
      ↓
New SSTable
      ↓
Compaction later
```

---

### 7. Deletes use tombstones

```text
DELETE key 101
      ↓
101 → DELETE
```

The old physical record can remain until compaction.

---

### 8. Level compaction

```text
Level 0:
Overlapping ranges

        ↓

Level 1:
Non-overlapping ranges

        ↓

Level 2:
Larger organized ranges
```

---

### 9. LSM trade-off

```text
          LSM
           |
     Fast Writes
           |
           ↓
   More Read Complexity
           +
      Compaction
           +
   Write Amplification
```

---

### 10. OLTP vs OLAP

```text
OLTP
↓
Small transactions
↓
Fast point lookups
↓
Row-oriented

OLAP
↓
Large scans
↓
Analytics
↓
Column-oriented
```

---

# Final Mental Model

The entire lecture can be remembered as one progression:

```text
                 DATABASE STORAGE
                       |
        +--------------+--------------+
        |                             |
   MEMORY SIDE                    DISK SIDE
        |                             |
  Buffer Manager                 Storage Model
        |                             |
   +----+----+                 +------+------+------+
   |    |    |                 |      |      |
Multi  Pre- Scan            Tuple  Index   Log
Pool  fetch Sharing         Store  Store  Structured
                                            |
                                          LSM
                                            |
                                  +---------+---------+
                                  |                   |
                              Memtable            SSTables
                                  |                   |
                               Flush              Compact
                                                      |
                                           +----------+----------+
                                           |                     |
                                      Level Compaction   Universal
                                                           Compaction
```

The central database-design idea is:

> **Different workloads require different physical storage strategies. Database systems exploit their knowledge of queries, access patterns, and data organization to reduce I/O and improve performance.**
