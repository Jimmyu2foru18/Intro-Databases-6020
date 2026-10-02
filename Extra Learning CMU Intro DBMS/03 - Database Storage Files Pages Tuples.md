# Database Storage Architecture

## 1. From SQL and Relational Algebra to Database System Internals

### Definition

A **database management system (DBMS)** is a software system that stores, organizes, retrieves, and modifies data while providing an interface through which applications can execute queries.

Earlier topics focused on the **logical/application level**:

* Relational model
* Relational algebra
* SQL
* Tables
* Queries
* Query results

This lecture begins moving into the **implementation level**:

> How does a database actually store data and execute operations on that data?

### Database System Layering

A database can be thought of as a collection of layers. Each layer exposes an API to the layer above it.

```text
Application
    ↓
SQL / Query Interface
    ↓
Query Planner / Optimizer
    ↓
Execution Engine / Access Methods
    ↓
Buffer Manager
    ↓
Storage Manager / Disk Manager
    ↓
Files / Pages
    ↓
Disk / SSD / Network Storage
```

Each layer hides implementation details from the layers above it.

### Main Components

| Component                      | Main Responsibility                                    |
| ------------------------------ | ------------------------------------------------------ |
| Query Planner / Optimizer      | Converts SQL into an efficient physical execution plan |
| Execution Engine               | Executes the physical plan                             |
| Access Methods                 | Provides ways to access stored data                    |
| Buffer Manager                 | Moves pages between disk and memory                    |
| Storage Manager / Disk Manager | Manages files and pages on persistent storage          |
| Files                          | Physical database storage                              |
| Pages                          | Fixed-size units used to organize database files       |
| Tuples                         | Individual records stored inside pages                 |

### Key Idea

The semester moves **from the bottom upward**:

```text
Disk / Storage
      ↓
Pages
      ↓
Buffer Manager
      ↓
Access Methods
      ↓
Execution Engine
      ↓
Query Optimization
      ↓
SQL/Application
```

This lecture focuses primarily on **storage and how databases organize data on disk**.

---

# 2. Disk-Based Database Architecture

## Definition

A **disk-based DBMS** assumes that the primary persistent copy of the database is stored on **nonvolatile storage**.

Examples:

* SSD
* Hard disk
* Network storage
* Cloud storage such as Amazon S3

Data must generally be moved from persistent storage into memory before the database can operate on it.

### Basic Architecture

```text
             Database System
                  │
                  ↓
             Main Memory
                (DRAM)
                  │
          Read / Write Pages
                  │
                  ↓
          Persistent Storage
        SSD / HDD / Network
```

### Why?

The database cannot normally perform its operations directly on arbitrary disk bytes as efficiently as it can operate on data already in RAM.

Therefore:

1. Data exists persistently on disk.
2. A query requests data.
3. The database finds the appropriate page.
4. The page is loaded into memory.
5. The database operates on the in-memory page.
6. Modified pages eventually get written back to disk.

---

# 3. Volatile vs. Nonvolatile Storage

## Volatile Storage

**Volatile storage** loses its contents when power is removed.

Examples:

* DRAM
* CPU caches
* CPU registers

For this lecture, the important volatile storage is **DRAM**.

## Nonvolatile Storage

**Nonvolatile storage** retains data after power is removed, assuming the storage device itself remains intact.

Examples:

* SSD
* HDD
* Network storage
* Cloud object storage

### Comparison

| Property                   | Volatile Storage          | Nonvolatile Storage |
| -------------------------- | ------------------------- | ------------------- |
| Retains data without power | No                        | Yes                 |
| Example                    | DRAM                      | SSD                 |
| Typical access             | Random / byte-addressable | Block/page-oriented |
| Speed                      | Faster                    | Slower              |
| Capacity                   | Smaller                   | Larger              |
| Cost per byte              | Higher                    | Lower               |

### Important Terminology

**Byte-addressable**

The system can directly access individual byte addresses.

**Block-addressable**

Data is accessed in blocks rather than individual bytes.

For example, if a storage device uses 4 KB blocks and you need one byte:

```text
Request 1 byte
     ↓
Storage must access the block containing that byte
     ↓
4 KB block
```

You cannot simply retrieve one isolated byte from the storage device.

---

# 4. Storage Hierarchy

Computer storage consists of multiple levels.

```text
Fastest / Smallest / Most Expensive
                ↓
        CPU Registers
                ↓
           CPU Cache
                ↓
             DRAM
                ↓
              SSD
                ↓
              HDD
                ↓
        Network Storage
                ↓
              Tape
                ↓
Slowest / Largest / Cheapest
```

As you move downward:

* Capacity generally increases.
* Cost per byte decreases.
* Access latency increases.

### Important Database Boundary

For this course, the professor simplifies the hierarchy into:

```text
CPU Storage
──────────────
Memory (DRAM)
──────────────  ← Important boundary
Disk / Persistent Storage
```

The course primarily asks:

> Is the data currently in memory, or is it on disk?

CPU cache behavior is mostly ignored for now.

---

# 5. Why Disk Access Matters

Database algorithms cannot assume that every memory access costs the same amount of time.

A major database performance problem is **I/O latency**.

### General Principle

```text
Memory access
     ↓
Very fast

Disk access
     ↓
Much slower
```

Therefore:

> A good database system tries to minimize expensive disk I/O.

The exact latency depends on:

* Hardware
* Storage device
* Amount of data
* Number of concurrent requests
* Access pattern
* Sequential vs. random access

### Exam Idea

If asked why database systems care so much about disk accesses:

**Because disk I/O is significantly slower than memory access, so excessive disk operations can dominate query execution time.**

---

# 6. Sequential I/O vs. Random I/O

## Sequential Access

**Sequential I/O** accesses data that is located near other requested data.

Example:

```text
Page 1 → Page 2 → Page 3 → Page 4 → Page 5
```

The data is physically or logically contiguous.

### Advantages

* Efficient
* Can retrieve large amounts of nearby data
* Especially beneficial for scans

---

## Random Access

**Random I/O** jumps between unrelated locations.

Example:

```text
Page 1
  ↓
Page 800
  ↓
Page 14
  ↓
Page 5000
  ↓
Page 27
```

### Disadvantage

Each access may require another expensive storage operation.

---

## Comparison

| Sequential I/O                | Random I/O                         |
| ----------------------------- | ---------------------------------- |
| Reads nearby/contiguous data  | Jumps between locations            |
| Generally faster              | Generally slower                   |
| Good for scans                | Expensive for scattered accesses   |
| Useful for large reads/writes | Often expensive on storage devices |

### Database Design Principle

> When possible, database systems try to maximize sequential access and minimize random I/O.

---

# 7. Why Database Systems Sometimes Reorganize Writes

The lecture gives MySQL's handling of dirty pages as an example.

A **dirty page** is a page in memory that has been modified but whose changes have not yet been written to persistent storage.

Instead of immediately performing many random writes, a system can first organize writes sequentially.

Conceptually:

```text
Dirty pages
   ↓
Sequential write
   ↓
Temporary / double-write area
   ↓
Later random writes
```

The goal is to reduce the performance cost of random I/O and avoid unnecessarily blocking execution while storage operations occur.

---

# 8. The Database Must Be Larger Than Memory

One of the fundamental goals of a database system is to support databases that are larger than available RAM.

For example:

```text
Available RAM = 8 GB
Database      = 100 GB
```

This is completely normal.

The DBMS creates the illusion that it can operate on the entire database even though only part of it can be in memory at once.

### Basic Process

```text
Disk
 │
 │ Fetch page
 ↓
Memory
 │
 │ Process data
 ↓
Memory
 │
 │ Write modified page
 ↓
Disk
```

### Working Set

The **working set** is the data that currently needs to be in memory for the running workload.

If:

```text
Working Set > Available Memory
```

the system may experience serious performance problems because it cannot keep all required data in memory.

---

# 9. Database Files

At the operating-system level, a database is fundamentally a collection of files.

The files themselves are not necessarily special to the operating system.

For example:

```text
Database
   ↓
Files
   ↓
Pages
   ↓
Bytes
```

The DBMS gives meaning to those bytes.

### Single-File Databases

Some systems store the entire database in one file.

Examples mentioned:

* SQLite
* DuckDB

Conceptually:

```text
database.db
├── Page
├── Page
├── Page
├── Page
└── ...
```

### Multi-File Databases

Many DBMSs distribute database contents across multiple files.

```text
Database
├── File A
├── File B
├── File C
└── File D
```

The exact organization depends on the database system.

---

# 10. Database File Formats

Historically, database file formats are usually **proprietary**.

This means a file created by one DBMS generally cannot simply be opened by another DBMS.

For example:

```text
PostgreSQL storage format
        ≠
MySQL storage format
        ≠
Oracle storage format
```

The bytes only have meaning according to the system that understands that format.

### Portable File Formats

There are also open, portable formats.

An example mentioned is:

**Parquet**

Parquet is designed as an open file format that can be read and written by multiple systems.

The lecture notes that this topic becomes more relevant when discussing column-oriented storage.

---

# 11. File Systems

Most DBMSs use the operating system's existing file system.

Examples mentioned include:

* ext4
* Windows file systems

The DBMS generally does not need to create an entirely new file system.

### Custom File Systems

Some high-end systems have used specialized storage management.

An example mentioned is:

**Oracle ASM**

The general idea is that the database system can take greater control over how storage is organized rather than relying entirely on the operating system's normal file-system organization.

The lecture notes that this is more common in specialized/high-end systems because it requires significant engineering effort.

---

# 12. Storage Manager / Disk Manager

## Definition

The **storage manager** is the database component responsible for managing persistent storage.

It handles operations such as:

* Reading pages
* Writing pages
* Tracking pages
* Managing files
* Tracking available space
* Determining where new data can be stored

It is sometimes called the **disk manager**.

### Basic Responsibility

```text
Higher-level DBMS
       ↓
"Give me page X"
       ↓
Storage Manager
       ↓
Find page X
       ↓
Read from disk
       ↓
Return page
```

### Important Distinction

The storage manager is primarily concerned with the physical storage of the database.

It does **not necessarily create multiple logical replicas** of a page.

Replication can instead happen:

* Below the DBMS, such as through RAID/storage infrastructure
* Above the storage manager, such as distributed database replication

---

# 13. Pages

## Definition

A **page** is a fixed-size block of database data.

Pages are the fundamental units used by a DBMS to organize files.

Conceptually:

```text
Database File
┌──────────────┐
│    Page 1    │
├──────────────┤
│    Page 2    │
├──────────────┤
│    Page 3    │
├──────────────┤
│    Page 4    │
└──────────────┘
```

Pages may contain:

* Tuples
* Metadata
* Catalog information
* Index information
* Page-directory information
* Other database structures

---

# 14. Page IDs

Every database page needs a way to be identified.

A **Page ID** is a unique identifier used by the database system to locate a particular page.

A Page ID might represent:

* A logical page number
* An offset
* A combination of file and page information

Example:

```text
Page ID = 42
```

The system can then determine where page 42 physically resides.

### Logical vs. Physical Location

A Page ID does not necessarily have to be the physical disk address.

It can be:

```text
Page ID
   ↓
Page Directory
   ↓
File
   ↓
Physical Offset
```

This abstraction allows the database to move physical data without changing its logical identifier.

---

# 15. Page Directory

## Definition

A **page directory** is metadata that tracks where database pages are located.

Think of it as:

> A database inside the database that keeps track of database pages.

Conceptually:

```text
Page Directory
├── Page 1 → File A, Offset 0
├── Page 2 → File A, Offset 4096
├── Page 3 → File B, Offset 8192
└── Page 4 → File C, Offset 0
```

It may also maintain information such as:

* Available pages
* Free space
* Empty pages
* Page type
* Location of pages

### Why Is It Useful?

Suppose the execution engine requests:

```text
Get Page 23
```

The system can use the page directory to determine:

```text
Page 23
   ↓
File B
   ↓
Offset X
   ↓
Read page
```

---

# 16. Simple Page Address Calculation

If all pages have the same size and are stored sequentially in one file, the location can be calculated using arithmetic.

For example:

```text
Offset = Starting Offset + (Page ID × Page Size)
```

### Example

Suppose:

```text
Starting offset = 0
Page ID = 5
Page size = 4096 bytes
```

Then:

```text
Offset = 0 + (5 × 4096)
       = 20480 bytes
```

So the system can jump directly to that location.

### Important

If pages are distributed across multiple files, a page directory may first be needed to determine **which file** contains the page.

---

# 17. Synchronizing the Page Directory

The page directory needs to correspond correctly with the actual data pages.

Suppose:

```text
Page Directory says:
Page 10 → File A

But Page 10 was actually moved to File B
```

The system could no longer immediately find the page.

Therefore, the page directory needs to be maintained carefully.

### Recovery Trade-Off

The lecture explains that the page directory does not necessarily have to be perfectly synchronized on persistent storage at every instant.

If enough metadata exists to reconstruct it after a crash:

```text
Crash
 ↓
Reconstruct Page Directory
 ↓
Continue
```

The trade-off becomes:

| Approach                           | Runtime                   | Recovery        |
| ---------------------------------- | ------------------------- | --------------- |
| Keep directory highly synchronized | Potentially more overhead | Faster          |
| Relax persistent synchronization   | Potentially faster        | Slower recovery |

---

# 18. Page Metadata

A page may maintain metadata describing:

* Page size
* Checksum
* Page version
* Page type
* Free space
* Transaction visibility
* Compression/encoding information
* Other page-specific information

Some systems may include enough metadata to make a page relatively self-describing.

---

# 19. Checksums

A **checksum** is metadata used to detect corruption.

Conceptually:

```text
Data
 ↓
Checksum calculated
 ↓
Stored with page

Later:
Read page
 ↓
Calculate/check checksum
 ↓
Compare
```

If the values do not match, the page may have been corrupted.

### Why It Matters

Storage failures or crashes can potentially result in corrupted data.

A checksum provides a way to detect that corruption.

---

# 20. Hardware Pages, OS Pages, and Database Pages

One of the most important distinctions in this lecture is that there are multiple meanings of the word **page**.

There are three important levels:

```text
Hardware Page
      ↓
Operating-System Page
      ↓
Database Page
```

They are related but are not necessarily the same size.

---

## Hardware Page

The hardware/storage layer has an atomic unit of storage.

The lecture uses approximately:

**4 KB**

as the conceptual hardware page size.

The important idea is:

> Hardware can guarantee atomicity only up to a particular unit.

If a system needs to write more than that unit, additional mechanisms may be necessary to guarantee safe updates.

---

## OS Page

The operating system also manages memory using pages.

Linux commonly uses:

**4 KB pages**

Linux can also support larger **huge pages**, such as:

* 2 MB
* 1 GB

depending on configuration and architecture.

---

## Database Page

The DBMS chooses its own page size.

Examples mentioned in the lecture include:

| System       |      Approximate Default / Common Page Size |
| ------------ | ------------------------------------------: |
| SQLite       | Can be as small as 512 bytes; commonly 4 KB |
| Oracle       |                                4 KB default |
| RocksDB      |                                        4 KB |
| WiredTiger   |                                        4 KB |
| SQL Server   |                                        8 KB |
| PostgreSQL   |                                        8 KB |
| MySQL/InnoDB |                                       16 KB |

Exact behavior can vary by system and configuration.

### Important Exam Concept

Do **not** assume:

```text
Hardware page = OS page = Database page
```

They are separate concepts.

---

# 21. Choosing a Database Page Size

There is no universally correct database page size.

The appropriate size depends on:

* Hardware
* Workload
* Data types
* Table width
* Record size
* Read/write ratio

---

## Read-Heavy Workloads

Read-heavy workloads often benefit from **larger pages**.

Why?

Suppose a query needs many nearby records:

```text
Large page
┌──────────────────────────────┐
│ Tuple │ Tuple │ Tuple │ ...  │
└──────────────────────────────┘
```

One page fetch brings in lots of useful nearby data.

This is especially useful for sequential scans.

---

## Write-Heavy Workloads

Write-heavy workloads may benefit from smaller pages.

Suppose only one byte changes.

With a 4 KB page:

```text
Change 1 byte
      ↓
Write 4 KB page
```

With a much larger page:

```text
Change 1 byte
      ↓
Write much larger page
```

Therefore, larger pages can increase write amplification.

### General Trade-Off

| Workload    | Page-size tendency     |
| ----------- | ---------------------- |
| Read-heavy  | Larger pages can help  |
| Write-heavy | Smaller pages can help |

For the course, the professor initially uses approximately **4–16 KB pages**, with later lectures discussing larger pages and read-heavy workloads.

---

# 22. Heap Files

## Definition

A **heap file** is an unordered collection of pages.

It is called "heap" because records do not have to be stored in sorted order.

Conceptually:

```text
Heap File
├── Page 1
│   ├── Tuple A
│   └── Tuple C
├── Page 2
│   ├── Tuple B
│   └── Tuple D
└── Page 3
    └── Tuple E
```

There is no requirement that:

```text
A < B < C < D < E
```

### Why Heap Files Work Well with the Relational Model

The relational model treats a relation as an unordered collection of tuples.

Therefore, tuples can be placed wherever there is available space.

---

# 23. Other File Organizations

The lecture mentions several alternatives.

| Organization      | Basic Idea                               |
| ----------------- | ---------------------------------------- |
| Heap File         | Unordered collection of pages            |
| Tree File         | Pages organized using a tree             |
| Sequential / ISAM | Data organized sequentially              |
| Hash Organization | Data placed according to a hash function |

For this lecture, the focus is on **heap files**.

---

# 24. Heap File API

A basic heap-file implementation needs operations such as:

### Create Page

Create a new page when additional storage is needed.

### Get Page

Retrieve a particular page.

```text
getPage(PageID)
```

### Iterate Pages

Return pages sequentially.

```text
for each PageID:
    process page
```

This supports operations such as sequential scans.

### Find Free Space

The system must determine where a new tuple can be placed.

---

# 25. Why Free-Space Tracking Matters

Suppose pages are 8 KB, but tuples are much smaller.

```text
Page
┌─────────────────────────────┐
│ Tuple A                     │
│ Tuple B                     │
│                             │
│       FREE SPACE            │
│                             │
└─────────────────────────────┘
```

The DBMS should reuse that free space rather than continually allocating new pages.

Therefore, metadata can track:

* Amount of free space
* Completely empty pages
* Pages containing tuples
* Pages available for insertion

---

# 26. Basic Page Layout

At a high level:

```text
Database
   ↓
Files
   ↓
Pages
   ↓
Page Header
   ↓
Tuples / Data
```

The page itself normally has a **header** containing metadata.

---

# 27. Page Header

A **page header** contains metadata about the page.

Possible information includes:

* Page size
* Page type
* Checksum
* Version
* Free-space information
* Transaction visibility
* Compression/encoding metadata
* Other system-specific information

### Important Principle

The page header describes the page.

The tuple header describes the tuple.

Do not confuse the two.

---

# 28. Row-Oriented Storage

This lecture focuses on a **row-oriented** or **tuple-oriented** storage model.

## Definition

In row-oriented storage, all attributes belonging to one tuple are stored together.

Example table:

```text
Students

ID | Name | Major | GPA
------------------------
1  | Bob  | CS    | 3.5
2  | Amy  | Math  | 3.8
```

Row-oriented physical storage is conceptually:

```text
Tuple 1:
[1][Bob][CS][3.5]

Tuple 2:
[2][Amy][Math][3.8]
```

### Advantage

If a query needs an entire row, much of the required data is located together.

---

# 29. Alternative Storage Models

The lecture mentions three broad approaches:

1. Tuple-oriented storage
2. Log-structured storage
3. Index-organized storage

### Tuple-Oriented

Store the tuple as a complete unit.

```text
[ID][Name][Major][GPA]
```

### Log-Structured

Instead of maintaining only one physical copy of the tuple, changes/deltas can be recorded over time.

```text
Original tuple
      ↓
Update
      ↓
Delta
      ↓
Another update
      ↓
Another delta
```

Multiple pieces may need to be combined to reconstruct the current state.

### Index-Organized

Data is organized using a tree-like structure.

The lecture postpones detailed discussion of these alternatives.

---

# 30. The Problem with a Simple Fixed-Length Tuple Array

A naive design could assume that all tuples have the same length.

```text
Page
┌──────────────┐
│ Header       │
├──────────────┤
│ Tuple 1      │
├──────────────┤
│ Tuple 2      │
├──────────────┤
│ Tuple 3      │
└──────────────┘
```

The DBMS could calculate:

```text
Tuple Offset = Header + (Tuple Number × Tuple Size)
```

This works well when every tuple has the same fixed size.

---

# 31. Problems with Simple Tuple Placement

## Problem 1: Deletion

Suppose:

```text
Tuple 1
Tuple 2
Tuple 3
```

Delete Tuple 2:

```text
Tuple 1
FREE SPACE
Tuple 3
```

Now the database cannot simply assume that tuple 3 occupies slot 2.

---

## Problem 2: Searching for Free Space

The system could scan the page:

```text
Find first free slot
      ↓
Put new tuple there
```

But repeatedly scanning for free slots becomes expensive.

---

## Problem 3: Compaction

The system could move Tuple 3 into Tuple 2's old location:

```text
Before:

Tuple 1
FREE
Tuple 3

After:

Tuple 1
Tuple 3
```

But now Tuple 3's physical location changed.

Any structure pointing directly to its physical location might need to be updated.

This creates a large **blast radius** for a small modification.

---

## Problem 4: Variable-Length Data

If tuples contain strings or other variable-length attributes:

```text
Tuple A = 20 bytes
Tuple B = 100 bytes
Tuple C = 40 bytes
```

Simple fixed-size slots no longer work well.

Free space can become fragmented.

---

# 32. Slotted Pages

## Definition

A **slotted page** is a page organization technique that uses a slot array to indirectly locate tuples within a page.

This solves many problems associated with variable-length tuples and tuple movement.

### General Layout

```text
┌─────────────────────────────┐
│ Page Header                 │
├─────────────────────────────┤
│ Slot Array                  │
│                             │
│ Slot 1 → Tuple location     │
│ Slot 2 → Tuple location     │
│ Slot 3 → Tuple location     │
│ ...                         │
│                             │
│        FREE SPACE           │
│                             │
├─────────────────────────────┤
│ Tuple Data                  │
│ Tuple Data                  │
│ Tuple Data                  │
└─────────────────────────────┘
```

The slot array grows downward while tuple data grows upward from the opposite side.

Eventually:

```text
Slot Array ↓
             ↓
       FREE SPACE
             ↑
Tuple Data ↑
```

When they meet, the page is considered full.

---

# 33. How Slotted Pages Work

Each slot contains an offset describing where a tuple is located inside the page.

Example:

```text
Slot 1 → offset 700
Slot 2 → offset 600
Slot 3 → offset 400
```

The actual tuple data might be located elsewhere in the page.

### Accessing Tuple 2

```text
Tuple 2
   ↓
Slot 2
   ↓
Offset = 600
   ↓
Read tuple at offset 600
```

The slot is an **indirection layer**.

---

# 34. Why Indirection Matters

Suppose Tuple 3 moves from:

```text
Offset 400
```

to:

```text
Offset 250
```

Without indirection, every structure pointing to offset 400 might need to be updated.

With a slot:

```text
Slot 3 → 400
```

becomes:

```text
Slot 3 → 250
```

The tuple's logical identity can remain the same.

### Major Advantage

> Physical movement of a tuple inside a page does not necessarily require updating every structure that references the tuple.

This dramatically reduces the modification's blast radius.

---

# 35. Compaction in a Slotted Page

Suppose:

```text
Slot 1 → Tuple A
Slot 2 → Tuple B
Slot 3 → Tuple C
```

Tuple B is deleted.

The page may become:

```text
Tuple A
FREE
Tuple C
```

The DBMS can compact the page:

```text
Tuple A
Tuple C
```

and simply update:

```text
Slot 3 → new location of Tuple C
```

The index does not necessarily need to know that Tuple C moved.

### Performance Principle

Once a page is already in memory, rearranging its bytes is relatively cheap compared with fetching another page from disk.

Therefore:

> It can be worthwhile to perform in-memory organization or compaction rather than paying additional disk I/O.

---

# 36. Record IDs / Tuple IDs / Row IDs

A database needs a way to identify a logical tuple.

Different systems may call this:

* Record ID (RID)
* Tuple ID (TID)
* Row ID
* Other system-specific names

The basic idea is similar.

A record identifier can conceptually contain:

```text
File ID
+
Page ID
+
Slot Number
```

Example:

```text
RID = (File 3, Page 42, Slot 5)
```

This identifies the physical location of the tuple.

---

# 37. Logical Identity vs. Physical Location

This is an important distinction.

A tuple has a **logical identity**, while the physical bytes can potentially move.

For example:

```text
Logical Tuple
      ↓
RID
      ↓
Page 42
      ↓
Slot 5
      ↓
Physical bytes
```

If the tuple moves within the page:

```text
Page 42
Slot 5 → new offset
```

the logical tuple can remain the same.

### Important Application Rule

Applications generally should **not depend on physical record IDs remaining permanently unchanged**.

Database reorganization or compaction can change physical locations.

---

# 38. Examples of Record Identifiers

The lecture mentions examples from different systems:

* Ingres: tuple ID
* PostgreSQL: `ctid`
* SQLite: `rowid`

These systems implement physical/logical identifiers differently.

### Important Difference

Some systems derive physical identifiers from storage structures rather than explicitly storing them as application-level data.

SQLite's `rowid` is particularly notable because it is an actual row identifier maintained by SQLite.

---

# 39. Tuple Structure

A tuple is fundamentally a collection of bytes.

Conceptually:

```text
Tuple
┌────────────────────────────┐
│ Tuple Header               │
├────────────────────────────┤
│ Attribute 1                │
├────────────────────────────┤
│ Attribute 2                │
├────────────────────────────┤
│ Attribute 3                │
├────────────────────────────┤
│ ...                        │
└────────────────────────────┘
```

---

# 40. Tuple Header

A tuple header can contain metadata such as:

* Visibility information
* Transaction information
* NULL bitmap
* Other tuple-specific metadata

The tuple header generally does **not** need to repeatedly store the entire table schema.

The database catalog maintains schema information.

---

# 41. Database Catalog

The **catalog** contains metadata describing database objects.

For example:

```text
Table: Students

Column 1 → ID → INTEGER
Column 2 → Name → VARCHAR
Column 3 → GPA → DOUBLE
```

When the DBMS reads the bytes of a tuple, the catalog tells it how to interpret those bytes.

### Key Principle

```text
Raw bytes
   +
Schema information
   ↓
Meaningful attributes
```

---

# 42. Attribute Ordering

In a basic row-oriented system, attributes are generally stored in the order defined by the schema.

Example:

```sql
CREATE TABLE Student (
	ID INTEGER,
	GPA DOUBLE,
	Age INTEGER
);
```

Conceptually:

```text
[ID][GPA][Age]
```

The physical representation may include padding for alignment.

---

# 43. Memory Alignment and Padding

Hardware often prefers values to be aligned to particular boundaries.

For example, assume a system works with 64-bit words.

Suppose we have:

```text
INTEGER = 32 bits
DOUBLE  = 64 bits
```

A naive layout might create misalignment.

The database can use **padding** to align values.

Example:

```text
32-bit ID
32-bit padding
64-bit timestamp
```

Instead of:

```text
32-bit ID
64-bit timestamp crossing a boundary
```

### Why Padding?

Padding:

* Uses extra space
* Can make access simpler
* Can avoid values crossing alignment boundaries
* Can improve compatibility with hardware/compiler expectations

### Trade-Off

```text
Padding
   ↓
More storage
   +
Better alignment
```

---

# 44. Alternative: Reordering Attributes

Another theoretical approach is to physically reorder attributes to improve alignment.

For example:

```text
Logical schema:
A | B | C | D

Physical:
A | C | B | D
```

The system would need metadata to understand the mapping.

The lecture notes that this idea appears in research but is not generally used by the systems discussed.

---

# 45. Basic Data Types

Common database attributes include:

* Integers
* Floating-point values
* Strings
* Timestamps
* Dates
* Numeric/decimal values
* Binary values

The exact binary representation can depend on the DBMS and hardware architecture.

---

# 46. Integer Representation

Integers are generally represented similarly to native machine integer types.

Examples:

```text
32-bit integer
64-bit integer
```

Their physical representation depends on the system's conventions.

---

# 47. Endianness

**Endianness** describes the order in which bytes of multi-byte values are stored.

The two common concepts are:

* Little-endian
* Big-endian

For this lecture, the professor assumes a typical x86 environment and does not focus on the details.

### Important Clarification

If a database is moved between systems with different byte-order conventions, the DBMS may need to account for endianness.

---

# 48. Floating-Point Numbers

Floating-point values are typically represented according to **IEEE 754**.

Examples:

```text
FLOAT
DOUBLE
```

These formats are supported directly by modern hardware.

### Advantage

Floating-point operations are very fast because processors have hardware instructions for them.

### Disadvantage

Floating-point numbers cannot represent every decimal value exactly.

---

# 49. Floating-Point Precision Problem

Consider:

```text
x = 0.1
y = 0.2

x + y
```

You might expect:

```text
0.3
```

But the actual binary floating-point representation may produce a value extremely close to 0.3 rather than exactly 0.3.

For example, conceptually:

```text
0.1 + 0.2
≈ 0.30000000000000004
```

The exact displayed result depends on the language and formatting.

### Why?

Some decimal fractions cannot be represented exactly using binary floating-point representation.

---

# 50. Floating-Point vs. Fixed-Precision Decimal

This is an important comparison.

| Floating Point                        | Fixed-Precision Decimal                      |
| ------------------------------------- | -------------------------------------------- |
| Hardware-supported                    | Usually implemented by DBMS/software         |
| Very fast                             | More computationally expensive               |
| Approximate representation            | Designed to preserve exact decimal precision |
| IEEE 754                              | DBMS-specific representation                 |
| Good for many scientific calculations | Useful for financial/decimal calculations    |

---

# 51. Fixed-Precision / Exact Numeric Values

Database systems provide decimal/numeric types when exact decimal behavior is important.

Examples:

```sql
DECIMAL(10,2)
```

or:

```sql
NUMERIC
```

The database can maintain metadata describing:

* Precision
* Scale
* Sign
* Other representation information

The underlying bytes can then be interpreted using that metadata.

---

# 52. Why Databases Implement Numeric Types Themselves

Consider money:

```text
$0.10 + $0.20
```

You generally expect:

```text
$0.30
```

Unexpected floating-point rounding can be undesirable in financial calculations.

Therefore, database systems may implement exact decimal arithmetic themselves.

### Trade-Off

```text
Hardware FLOAT
    ↓
Very fast
    ↓
Approximation possible

Database NUMERIC
    ↓
More computation
    ↓
Exact decimal semantics
```

---

# 53. PostgreSQL Numeric Example

PostgreSQL has a `numeric` type for exact decimal-style arithmetic.

Conceptually, its internal representation contains:

```text
Metadata
├── Sign
├── Scale
├── Other numeric information
└── Byte representation of value
```

When performing arithmetic, PostgreSQL must interpret this representation.

Therefore:

```text
NUMERIC + NUMERIC
```

is much more involved than simply performing a CPU floating-point addition.

### Important Principle

The DBMS sacrifices some computational speed to provide the desired numerical semantics.

---

# 54. NULL Representation

The DBMS must represent whether an attribute contains a value or `NULL`.

The lecture discusses three approaches.

---

## Method 1: NULL Bitmap

The most common row-store approach is a **NULL bitmap** in the tuple header.

Example:

```text
Columns:
ID | Name | GPA | Major

NULL bitmap:
 0    1     0      1
```

Conceptually:

```text
0 = not NULL
1 = NULL
```

The exact bit convention can vary by implementation.

### Advantages

* Compact
* Simple
* One bitmap can describe all attributes

---

# 55. Method 2: Special NULL Values

Another approach is to reserve a particular value to represent `NULL`.

Example concept:

```text
INTEGER range:
... normal values ...

Reserved value:
MIN_INT = NULL
```

Now the system does not need a separate NULL bitmap.

### Disadvantage

One legitimate value from the type's domain is sacrificed.

### Where Useful?

The lecture notes this approach is more common in **column-oriented systems** and some specialized in-memory systems.

---

# 56. Method 3: Per-Attribute NULL Flag

A third approach is to store a separate flag for each attribute.

Conceptually:

```text
[NULL flag][Value]
[NULL flag][Value]
[NULL flag][Value]
```

The lecture strongly discourages this approach for row stores because the metadata overhead can be significant.

### Why?

A single bit is difficult to store efficiently by itself due to alignment and byte-level storage requirements.

---

# 57. NULL Representation Comparison

| Method             | Basic Idea                      | Main Advantage          | Main Disadvantage      |
| ------------------ | ------------------------------- | ----------------------- | ---------------------- |
| NULL bitmap        | Bitmap in tuple header          | Compact                 | Requires bitmap        |
| Special value      | Reserve one data value for NULL | No bitmap               | Loses one domain value |
| Per-attribute flag | Flag beside every value         | Straightforward concept | High metadata overhead |

### Lecture Rule of Thumb

```text
Row Store
   ↓
NULL bitmap

Column Store
   ↓
Special-value techniques can be useful
```

---

# 58. Variable-Length Attributes

Some attributes do not have a fixed size.

Examples:

```text
VARCHAR
TEXT
BLOB
VARBINARY
```

A tuple may therefore have:

```text
ID       = 4 bytes
Name     = 5 bytes
Comment  = 2000 bytes
```

The database needs a way to represent these variable-sized values.

---

# 59. Inline Storage

If the variable-length value is small enough, it can be stored directly inside the tuple.

Conceptually:

```text
[Length][Actual Bytes]
```

Example:

```text
[5][HELLO]
```

The length tells the DBMS how many bytes belong to the attribute.

---

# 60. Overflow Pages

If an attribute becomes too large to fit conveniently inside the tuple/page, the database can use **overflow pages**.

Conceptually:

```text
Original Tuple
┌───────────────────────┐
│ ID                    │
│ Name                  │
│ Pointer ──────────────┼─────────┐
└───────────────────────┘         │
                                  ↓
                          Overflow Page
                          ┌───────────────┐
                          │ Large Value   │
                          └───────────────┘
```

The tuple contains a reference to the external/overflow data.

---

# 61. Overflow Page Access

Suppose:

```text
Tuple:
ID = 10
Content = very large
```

The tuple might contain:

```text
Content size = 50 KB
Overflow Page = 120
Offset = 200
```

The DBMS can then follow the reference:

```text
Tuple
 ↓
Overflow pointer
 ↓
Page 120
 ↓
Offset 200
 ↓
Large value
```

---

# 62. Database-Specific Overflow Thresholds

Different systems use different thresholds.

The lecture gives examples including:

* PostgreSQL: values larger than roughly 2 KB may be moved/compressed using its storage mechanism despite 8 KB pages.
* MySQL / SQL Server / Oracle: large values may be moved when they exceed an appropriate fraction or capacity of the page.

The exact behavior depends on the DBMS and configuration.

### Exam Tip

Do not memorize these thresholds as universal database rules.

The important concept is:

> Different DBMSs use different strategies for storing values that are too large to fit efficiently inside a normal tuple/page.

---

# 63. Chained Overflow Pages

A single overflow page may not be large enough.

Therefore, overflow pages can be chained.

```text
Tuple
  ↓
Overflow Page 1
  ↓
Overflow Page 2
  ↓
Overflow Page 3
  ↓
...
```

Each page can contain a pointer to the next page.

This allows very large values to be reconstructed from multiple pages.

---

# 64. Prefixes for Large Strings

The lecture discusses a technique for reducing unnecessary overflow-page reads.

Suppose a large string is stored externally.

Instead of storing only:

```text
[length][pointer]
```

the tuple can also store a small **prefix**.

Example:

```text
Tuple:
Prefix = "Andy..."
Pointer → Overflow Page
```

If the query asks:

```sql
WHERE content LIKE 'Andy%'
```

the database may be able to inspect the prefix first.

If the prefix clearly does not match:

```text
Prefix = "Robert..."
```

there may be no need to fetch the overflow page.

### Principle

> Store a small amount of extra information to avoid expensive disk I/O when possible.

---

# 65. Compression of Overflow Data

Overflow data can potentially be compressed.

Examples mentioned:

* Snappy
* Gzip

The trade-off is:

```text
Compression
   ↓
Less storage / I/O
   +
CPU work to compress/decompress
```

This is another example of trading CPU work for reduced I/O.

---

# 66. External Value Storage

Sometimes very large objects should not be stored directly inside the database.

Examples:

* Large videos
* Huge files
* Other very large binary objects

Instead, the database can store a reference.

```text
Database Tuple
┌───────────────────────┐
│ ID                    │
│ Name                  │
│ External URI ─────────┼────→ External Storage
└───────────────────────┘
```

The actual file is maintained outside the DBMS.

---

# 67. External Value Storage Trade-Off

### Advantages

* Large files can use cheaper storage
* Database pages remain relatively small
* Database does not need to physically contain the entire object

### Disadvantages

The DBMS may not be able to provide the same guarantees for external data.

For example:

* Transactional guarantees may differ
* Durability guarantees may differ
* Backup behavior may differ
* Recovery behavior may differ

### Examples Mentioned

* Oracle BFILEs
* Microsoft FILESTREAM

---

# 68. Files → Pages → Tuples → Attributes

The entire storage hierarchy can now be visualized:

```text
Database
│
├── Files
│    │
│    ├── Pages
│    │    │
│    │    ├── Page Header
│    │    │
│    │    ├── Slot Array
│    │    │
│    │    └── Tuples
│    │         │
│    │         ├── Tuple Header
│    │         └── Attributes
│    │              ├── Integer
│    │              ├── String
│    │              ├── Numeric
│    │              └── ...
│    │
│    └── ...
│
└── ...
```

This hierarchy is one of the most important things to understand from the lecture.

---

# 69. Complete Page Retrieval Flow

Suppose a query asks for a tuple stored on Page 2.

### Step 1 — Query Execution

The execution engine requests:

```text
Get Page 2
```

### Step 2 — Locate the Page

The storage system uses its metadata/page directory to determine where Page 2 exists.

```text
Page 2
 ↓
File A
 ↓
Offset X
```

### Step 3 — Read the Page

The page is fetched from persistent storage.

```text
Disk
 ↓
Page 2
 ↓
Memory
```

### Step 4 — Buffer Manager Holds the Page

The page is placed into a memory frame.

### Step 5 — Execution Engine Receives It

The execution engine receives a reference/pointer to the in-memory page.

### Step 6 — Interpret the Page

The execution engine uses:

* Page metadata
* Slot array
* Tuple metadata
* Catalog/schema

to determine what the bytes mean.

### Step 7 — Perform Operation

The query might:

* Read a tuple
* Update a tuple
* Delete a tuple
* Insert a tuple

### Step 8 — Page Becomes Dirty

If modified:

```text
Clean page
   ↓
Modification
   ↓
Dirty page
```

### Step 9 — Write Back

Eventually the buffer/storage system writes the modified page back to persistent storage.

```text
Memory
   ↓
Disk
```

---

# 70. Full Storage Architecture

```text
                 SQL Query
                    │
                    ↓
          Query Planner / Optimizer
                    │
                    ↓
             Execution Engine
                    │
                    ↓
              Access Methods
                    │
                    ↓
              Buffer Manager
                    │
          ┌─────────┴─────────┐
          │                   │
      Memory                Disk
      Frames              Page Files
                              │
                              ↓
                            Pages
                              │
                              ↓
                           Tuples
                              │
                              ↓
                         Attributes
```

---

# 71. Abstraction Between Layers

One of the most important architectural ideas is **abstraction**.

Higher-level components should not need to know every physical storage detail.

For example, the execution engine can request:

```text
Give me Page 42
```

without necessarily caring whether Page 42 is physically organized using:

* A particular slot layout
* A particular file arrangement
* A particular storage device
* A particular page-directory implementation

### Why?

This allows the database to change internal implementations without redesigning the entire system.

```text
Same API
   ↓
Different implementation
```

---

# 72. Abstraction Trade-Off

Abstraction is useful, but it is not free.

Too much abstraction can introduce:

* Performance overhead
* Additional metadata
* Extra layers
* Additional indirection

Database systems therefore balance:

```text
Modularity
     ↕
Performance
```

---

# 73. Important Comparisons

| Concept          | Meaning                            | Difference                                 |
| ---------------- | ---------------------------------- | ------------------------------------------ |
| Volatile         | Loses data without power           | DRAM                                       |
| Nonvolatile      | Retains data without power         | SSD/HDD                                    |
| Random I/O       | Access scattered locations         | Usually more expensive                     |
| Sequential I/O   | Access nearby/contiguous data      | Usually more efficient                     |
| File             | OS-level storage object            | Contains database pages                    |
| Page             | Fixed-size DB storage unit         | Contains tuples/metadata                   |
| Tuple            | Database record                    | Contains attributes                        |
| Attribute        | Individual field/value             | Part of tuple                              |
| Page ID          | Identifies a page                  | Locates a page                             |
| Record ID        | Identifies a tuple/location        | Usually includes page + slot               |
| Page header      | Metadata about page                | Describes page                             |
| Tuple header     | Metadata about tuple               | Describes tuple                            |
| Heap file        | Unordered page collection          | Tuples can be placed wherever space exists |
| Slotted page     | Page with slot array               | Handles variable-length tuples/movement    |
| Floating point   | Approximate numeric representation | Fast but not exact for every decimal       |
| Fixed decimal    | Exact decimal representation       | More computation                           |
| Inline storage   | Value stored in tuple              | Best for smaller values                    |
| Overflow storage | Large value stored elsewhere       | Avoids oversized tuples/pages              |
| Internal storage | Data managed by DBMS               | DBMS controls it                           |
| External storage | Data outside DBMS                  | DBMS stores a reference                    |

---

# 74. Hardware Page vs. OS Page vs. Database Page

| Type                | Controlled By    | Purpose                       |
| ------------------- | ---------------- | ----------------------------- |
| Hardware page/block | Hardware/storage | Atomic/storage-level unit     |
| OS page             | Operating system | Virtual memory management     |
| Database page       | DBMS             | Database storage organization |

### Memory Trick

Think:

```text
Hardware → OS → Database
```

Each layer has its own concept of a page.

---

# 75. Heap File vs. Slotted Page

These are not exactly competing concepts.

A **heap file** describes how pages are organized as a collection.

A **slotted page** describes how tuples are organized **inside an individual page**.

```text
Heap File
    ↓
Page
    ↓
Slotted Page Layout
    ↓
Tuples
```

This distinction is important.

---

# 76. Page ID vs. Record ID

### Page ID

Identifies a page.

```text
Page ID = 42
```

### Record ID

Identifies a tuple, often through:

```text
File ID
+
Page ID
+
Slot ID
```

Memory trick:

```text
Page ID → "Which page?"

Record ID → "Which record inside that page?"
```

---

# 77. Common Mistakes

* Assuming databases are stored directly as SQL tables on disk.
* Assuming the OS understands the internal meaning of database files.
* Assuming database pages are always 4 KB.
* Confusing hardware pages with database pages.
* Assuming disk and RAM have similar access costs.
* Ignoring random vs. sequential I/O.
* Assuming tuples must be physically sorted.
* Assuming a tuple's physical location never changes.
* Confusing a Page ID with a Record ID.
* Assuming every tuple must have a fixed size.
* Forgetting that variable-length values complicate page organization.
* Assuming floating-point numbers represent every decimal exactly.
* Using floating point when exact decimal semantics are required.
* Storing a separate NULL flag beside every attribute without considering overhead.
* Assuming large values must always be stored directly inside the tuple.
* Assuming an external file automatically receives the same durability guarantees as database-managed storage.
* Assuming the page directory is simply an ordinary application table.
* Assuming changing a tuple's physical location must always require updating an index.
* Forgetting that slotted pages provide indirection that helps avoid this problem.

---

# 78. Exam and Homework Tips

### Tip 1 — Know the Storage Hierarchy

Be able to explain:

```text
CPU
 ↓
Memory
 ↓
Disk
```

and why moving data between memory and disk is expensive.

---

### Tip 2 — Know Why Sequential I/O Matters

If asked which access pattern is generally preferable for large amounts of disk data:

```text
Sequential access
```

is generally more efficient than scattered random access.

---

### Tip 3 — Know the Purpose of Pages

A page is the DBMS's basic fixed-size unit for moving and organizing data.

---

### Tip 4 — Know the Purpose of the Buffer Manager

The buffer manager handles movement of pages between:

```text
Disk ↔ Memory
```

This lecture introduces that responsibility; later lectures cover it in more detail.

---

### Tip 5 — Understand Slotted Pages

This is likely one of the most important concepts.

Remember:

```text
Header
Slot Array
Free Space
Tuple Data
```

The slot array provides **indirection**.

---

### Tip 6 — Understand Why Indirection Helps

If a tuple moves:

```text
Without slot indirection:
Tuple moves → many references may need updates

With slot indirection:
Tuple moves → update slot entry
```

---

### Tip 7 — Understand Variable-Length Data

Variable-length records make simple fixed-offset layouts difficult.

Slotted pages solve this by storing offsets in a slot array.

---

### Tip 8 — Understand Floating Point

Remember:

```text
0.1 + 0.2
```

does not necessarily produce an exactly represented:

```text
0.3
```

in binary floating point.

For exact decimal semantics, databases provide numeric/decimal types.

---

### Tip 9 — Understand NULL Representation

For row-oriented storage, the lecture emphasizes:

```text
NULL bitmap
```

as the common approach.

---

### Tip 10 — Understand Overflow Pages

Large attributes can be stored outside the main tuple/page.

```text
Tuple
 ↓
Pointer
 ↓
Overflow Page
```

---

# 79. Step-by-Step: Finding a Tuple

Given a logical request for a tuple:

### Step 1

Determine the tuple's record identifier.

```text
RID
```

### Step 2

Extract the relevant page information.

```text
RID
 ↓
Page ID
```

### Step 3

Use the page directory/storage metadata to find the page.

```text
Page ID
 ↓
File + Offset
```

### Step 4

Read the page from disk if necessary.

```text
Disk
 ↓
Memory
```

### Step 5

Use the page's slot array.

```text
Slot ID
 ↓
Tuple Offset
```

### Step 6

Read the tuple.

```text
Tuple Offset
 ↓
Tuple Header
 ↓
Attributes
```

### Step 7

Use schema/catalog information to interpret the bytes.

```text
Raw Bytes
+
Schema
 ↓
Actual Values
```

---

# 80. Step-by-Step: Inserting a Tuple

Conceptually:

### Step 1

Determine the tuple's size.

### Step 2

Find a page with sufficient free space.

```text
Free-space metadata
       ↓
Candidate page
```

### Step 3

Load the page into memory if necessary.

### Step 4

Add the tuple data to the page.

### Step 5

Add/update a slot entry.

```text
New Slot
   ↓
Tuple Offset
```

### Step 6

Update page metadata/free-space information.

### Step 7

Mark the page dirty.

```text
Page modified
     ↓
Dirty
```

### Step 8

Eventually write the page back to persistent storage.

---

# 81. Step-by-Step: Deleting a Tuple

### Step 1

Find the tuple's page.

### Step 2

Find the tuple using its slot.

### Step 3

Mark the tuple as deleted or remove it according to the DBMS's implementation.

### Step 4

Potentially compact the page.

### Step 5

If the tuple moves during compaction, update the relevant slot entry.

### Step 6

Update free-space metadata.

### Step 7

Mark the page dirty.

---

# 82. Step-by-Step: Updating a Tuple

An update can be more complicated if the tuple changes size.

### Case A — Same Size

```text
Read page
 ↓
Modify tuple
 ↓
Mark dirty
```

### Case B — Tuple Becomes Smaller

There may be additional free space.

### Case C — Tuple Becomes Larger

The DBMS may need to:

1. Find additional space.
2. Move the tuple.
3. Update the slot entry.
4. Potentially use overflow storage.

The slot array makes movement easier because the logical slot can remain associated with the tuple.

---

# 83. Important Design Trade-Offs

Database storage design repeatedly involves trade-offs.

### Larger Pages

```text
+ Better sequential reads
+ More data per I/O
- More data written for small updates
```

### Smaller Pages

```text
+ Smaller write units
+ Potentially better for write-heavy workloads
- More pages to fetch for large scans
```

### Padding

```text
+ Better alignment
- Wasted space
```

### Exact Numeric

```text
+ Exact decimal semantics
- More CPU work
```

### Overflow Storage

```text
+ Keeps normal tuples/pages manageable
- Additional I/O/indirection
```

### Compression

```text
+ Less storage and I/O
- More CPU work
```

### External Storage

```text
+ Useful for huge objects
+ Can use cheaper storage
- Different consistency/durability guarantees
```

---

# 84. The Core Mental Model

If you remember nothing else, remember this:

```text
                 DATABASE
                     │
                     ↓
                   FILES
                     │
                     ↓
                  PAGES
                     │
                     ↓
                  TUPLES
                     │
                     ↓
                ATTRIBUTES
```

And:

```text
Disk
 │
 │ expensive I/O
 ↓
Memory
 │
 │ process pages
 ↓
Execution Engine
```

The database system's job is largely to efficiently manage these movements and representations.

---

# 85. Complete Lecture Cheat Sheet

## Storage

* **Volatile** → loses data when power disappears.
* **Nonvolatile** → persists data without power.
* **DRAM** → volatile memory.
* **SSD/HDD** → nonvolatile storage.
* **Disk** in this course broadly means persistent/block-addressable storage.

---

## I/O

* **Random I/O** → scattered locations.
* **Sequential I/O** → contiguous/nearby locations.
* Sequential I/O is generally much more efficient.
* Minimize unnecessary disk accesses.

---

## Database Files

* A database is fundamentally stored as files.
* Files contain pages.
* DBMS interprets the bytes.
* File formats are often DBMS-specific.
* Portable formats such as Parquet also exist.

---

## Storage Manager

Responsible for:

* Reading pages
* Writing pages
* Managing files
* Tracking pages
* Tracking free space

---

## Page

A fixed-size database storage unit.

Contains:

```text
Page Header
+
Slots / Metadata
+
Tuples
```

---

## Page ID

Identifies a page.

```text
Page ID → Page
```

---

## Page Directory

Maps logical page information to physical storage.

```text
Page ID
 ↓
Page Directory
 ↓
File
 ↓
Offset
```

---

## Heap File

Unordered collection of pages.

Tuples can generally be placed wherever appropriate free space exists.

---

## Slotted Page

Typical conceptual structure:

```text
┌──────────────────────┐
│ Page Header          │
├──────────────────────┤
│ Slot Array           │
├──────────────────────┤
│                      │
│ Free Space           │
│                      │
├──────────────────────┤
│ Tuple Data           │
└──────────────────────┘
```

Slot entries point to tuple locations.

---

## Record ID

Usually identifies a tuple through information such as:

```text
File ID
Page ID
Slot ID
```

---

## Tuple

A row represented as bytes.

Contains:

```text
Tuple Header
+
Attributes
```

---

## NULL

Common row-store method:

```text
NULL bitmap
```

Other possibilities:

* Reserved/special value
* Per-attribute flag

---

## Alignment

Padding may be inserted so values line up correctly with hardware word boundaries.

```text
Value
+
Padding
```

---

## Numeric Types

### Floating Point

* Fast
* IEEE 754
* Approximate

### Numeric / Decimal

* Exact decimal semantics
* More software processing
* Useful for money and precision-sensitive calculations

---

## Variable-Length Data

Small values:

```text
Tuple
└── Length + Value
```

Large values:

```text
Tuple
└── Pointer
      ↓
   Overflow Page
```

---

## Overflow Pages

Used for very large attributes.

Can be:

```text
Tuple
 ↓
Overflow Page 1
 ↓
Overflow Page 2
 ↓
Overflow Page 3
```

---

## External Value Storage

Very large objects may be stored outside the DBMS with a reference kept in the tuple.

---

# 86. Final Memory Diagram

```text
                         SQL QUERY
                            │
                            ↓
                  QUERY PLANNER / OPTIMIZER
                            │
                            ↓
                     EXECUTION ENGINE
                            │
                            ↓
                     BUFFER MANAGER
                            │
                 ┌──────────┴──────────┐
                 ↓                     ↓
              MEMORY                  DISK
              (DRAM)              (Persistent)
                                       │
                                       ↓
                                     FILES
                                       │
                                       ↓
                                     PAGES
                                       │
                          ┌────────────┴────────────┐
                          ↓                         ↓
                    PAGE HEADER               SLOT ARRAY
                                                    │
                                                    ↓
                                                TUPLES
                                                    │
                                                    ↓
                                            TUPLE HEADER
                                                    │
                                                    ↓
                                              ATTRIBUTES
                                                    │
                         ┌──────────────────────────┼───────────────┐
                         ↓                          ↓               ↓
                     INTEGER                    STRING          NUMERIC
                                                    │
                                                    ↓
                                             Overflow Page
```

# 87. Must-Know Definitions

1. **DBMS** — Software that manages storage, retrieval, and manipulation of database data.
2. **Volatile storage** — Storage whose contents are lost when power is removed.
3. **Nonvolatile storage** — Storage that retains data without power.
4. **Page** — Fixed-size unit used by a DBMS to organize database storage.
5. **Page ID** — Identifier for a database page.
6. **Page directory** — Metadata structure used to locate database pages.
7. **Storage manager** — Component responsible for managing persistent database storage.
8. **Heap file** — Unordered collection of database pages.
9. **Tuple** — A database record/row.
10. **Attribute** — A field/column value within a tuple.
11. **Slotted page** — Page layout using slots to indirectly locate tuples.
12. **Record ID** — Identifier used to identify/address a tuple.
13. **Overflow page** — Page used to store data too large for normal tuple/page storage.
14. **NULL bitmap** — Bitmap indicating which tuple attributes are NULL.
15. **Floating point** — Approximate numerical representation based on formats such as IEEE 754.
16. **Fixed-precision decimal** — Database representation designed to preserve exact decimal semantics.
17. **Sequential I/O** — Reading/writing nearby or contiguous data.
18. **Random I/O** — Reading/writing scattered storage locations.
19. **Dirty page** — A memory page modified since it was read from persistent storage.
20. **Buffer manager** — Component responsible for managing pages between memory and disk.

# 88. Must-Know Methods

### Locating a Page

```text
Page ID
 ↓
Page Directory
 ↓
File
 ↓
Offset
 ↓
Read Page
```

### Locating a Tuple

```text
Record ID
 ↓
Page ID
 ↓
Page
 ↓
Slot ID
 ↓
Tuple Offset
 ↓
Tuple
```

### Processing a Page

```text
Read page from disk
        ↓
Place page in memory
        ↓
Read page header
        ↓
Use slot array
        ↓
Locate tuple
        ↓
Interpret tuple using schema
        ↓
Execute operation
        ↓
Mark page dirty if modified
        ↓
Write page back later
```

# 89. Must-Know Formulas / Relationships

### Simple Page Offset

```text
Offset = Starting Offset + (Page ID × Page Size)
```

when pages are fixed-size and sequentially arranged in a single file.

### Page Capacity Concept

```text
Page Space =
	Page Header
	+ Slot Metadata
	+ Tuple Data
	+ Free Space
```

### Slotted Page Growth

```text
Slot Array grows ↓

        FREE SPACE

Tuple Data grows ↑
```

The page becomes full when the available free space between these regions is exhausted.

# 90. Final Exam Memory Sheet

```text
DATABASE STORAGE
================

Database
  ↓
Files
  ↓
Pages
  ↓
Tuples
  ↓
Attributes


DISK VS MEMORY
==============

DRAM:
- Volatile
- Fast
- Random/byte addressable

Disk:
- Nonvolatile
- Slower
- Block/page addressable


I/O
===

Sequential → generally faster
Random     → generally slower

Goal:
Minimize expensive disk I/O.


PAGE
====

Fixed-size DB storage unit.

Contains:
- Header
- Metadata
- Slots
- Tuples


PAGE DIRECTORY
==============

Page ID
   ↓
Directory
   ↓
File
   ↓
Offset
   ↓
Page


HEAP FILE
=========

Unordered collection of pages.


SLOTTED PAGE
============

Header
Slot Array
Free Space
Tuple Data

Slot → Offset → Tuple


WHY SLOTS?
==========

Tuple moves
    ↓
Only slot needs updating
    ↓
Other references can remain stable


RECORD ID
=========

Often:

File ID
+ Page ID
+ Slot ID


TUPLE
======

Tuple Header
+
Attributes


NULL
====

Common row store:
NULL bitmap

Other possibilities:
- Special value
- Per-value flag


NUMBERS
=======

FLOAT/DOUBLE:
- Fast
- IEEE 754
- Approximate

NUMERIC/DECIMAL:
- Exact decimal semantics
- More expensive


VARIABLE DATA
=============

Small:
Tuple → Value

Large:
Tuple → Pointer → Overflow Page


OVERFLOW
========

Tuple
 ↓
Overflow 1
 ↓
Overflow 2
 ↓
Overflow 3


CORE IDEA
=========

The DBMS creates the illusion that it can work
with a database larger than RAM by efficiently
moving fixed-size pages between disk and memory.
```
