# Database Systems — Buffer Pool, Replacement Policies, and I/O

## 1. Big Picture: What Is a Database System Doing?

At the lowest level, a database is ultimately **files stored on disk**.

The operating system sees the database as files. The database system adds layers of organization and management on top of those files so it can:

* Store data efficiently
* Find pages quickly
* Bring data from disk into memory
* Execute queries
* Decide what data should remain in memory
* Write modified data back to disk safely

### Main idea of this lecture

The focus is **moving data between disk and memory**.

```text
Disk
  ↓
Database files
  ↓
Pages
  ↓
Buffer Pool
  ↓
Memory Frames
  ↓
Execution Engine
  ↓
Query processing
```

The database system wants to control this process itself rather than letting the operating system make all the decisions.

---

# 2. Disk vs. Memory

## Disk

Disk is:

* Nonvolatile
* Persistent
* Much larger
* Slower

The database permanently stores its files here.

## Memory

Memory/RAM is:

* Volatile
* Much faster
* Limited in size

The database brings pages from disk into memory when they are needed.

### Why?

The CPU cannot efficiently process data directly from disk.

Therefore:

> **Bring data into memory → process it → possibly write changes back to disk.**

---

# 3. Spatial Control

### Definition

**Spatial control** means organizing data on disk so that data that is likely to be used together is stored close together.

The goal is to maximize **sequential I/O** and minimize **random I/O**.

### Why?

Sequential access is generally faster than random access, especially on traditional spinning disks.

### Example

Suppose a query frequently needs:

```text
Page 10
Page 11
Page 12
Page 13
```

It is better if those pages are physically close together on disk.

Instead of:

```text
Page 10 → Page 900 → Page 42 → Page 700
```

### Key idea

> **Put related data close together so it can be read efficiently.**

Modern SSDs reduce the difference between sequential and random access, but the principle remains important.

---

# 4. Temporal Control

### Definition

**Temporal control** means maximizing the amount of useful work performed on data after bringing it into memory.

Disk I/O is expensive, so we do not want to repeatedly:

```text
Read page
↓
Use it
↓
Throw it away
↓
Read same page again
↓
Use it again
```

Instead:

```text
Read page
↓
Do as much work as possible
↓
Keep/use it while needed
↓
Eventually release it
```

### Example

Bad:

```text
Read Page A
Process A
Evict A

Read Page B
Process B
Evict B

Read Page A again
```

Better:

```text
Read Page A
Do all possible work involving A
Keep A available
```

### Exam takeaway

**Spatial control = WHERE data is stored.**

**Temporal control = WHEN/how long data stays useful in memory.**

---

# 5. Database Storage Architecture

A simplified database architecture looks like:

```text
             Execution Engine
                    ↓
             Buffer Pool Manager
                    ↓
               Buffer Pool
                    ↓
                  Disk
                    ↓
             Database Files
                    ↓
                  Pages
```

The database file is divided into fixed-size **pages**.

---

# 6. Page Directory

The database needs a way to determine where pages are located on disk.

This is handled by the **page directory**.

### Page Directory

A page directory keeps information about pages stored on disk.

Conceptually:

```text
Page ID → Location on Disk
```

For example:

```text
Page 0 → disk offset X
Page 1 → disk offset Y
Page 2 → disk offset Z
```

### Important

The page directory is associated with **persistent storage**.

It helps locate pages that exist on disk.

---

# 7. Buffer Pool

The **buffer pool** is a region of memory allocated by the database system for storing pages fetched from disk.

Think of it as:

> **The database's working area in RAM.**

Example:

```text
Disk:

[Page 0] [Page 1] [Page 2] [Page 3]
                ↓
             fetch
                ↓

Memory / Buffer Pool:

[Frame 0] [Frame 1] [Frame 2] [Frame 3]
   ↑
 Page 1
```

---

# 8. Frames

A **frame** is a location in the buffer pool where a disk page can be stored.

### Important relationship

```text
1 Page on disk
      ↓
1 Frame in memory
```

For a particular buffer pool:

> **Page size = Frame size**

If database pages are 4 KB, the corresponding frames are 4 KB.

### Important distinction

**Page**

= unit of storage on disk.

**Frame**

= memory location capable of holding a page.

Think:

```text
PAGE = thing

FRAME = place where the thing goes
```

---

# 9. Buffer Pool Manager

The **buffer pool manager** manages the movement of pages between disk and memory.

When the execution engine says:

> "I need Page 2."

The buffer pool manager:

1. Checks whether Page 2 is already in memory.
2. If yes → return its memory address.
3. If no → find a free frame.
4. If no free frame exists → choose a page to evict.
5. Read the requested page from disk.
6. Place it into the selected frame.
7. Return a pointer to the page.

---

# 10. Page Table

The buffer pool needs another data structure to keep track of which pages are currently in memory.

This is the **page table**.

Conceptually:

```text
Page ID → Frame
```

Example:

```text
Page 1 → Frame 0
Page 3 → Frame 2
Page 7 → Frame 1
```

### Page Table vs. Page Directory

This distinction is extremely important.

| Structure          | Purpose                                 | Location                |
| ------------------ | --------------------------------------- | ----------------------- |
| **Page Directory** | Finds pages on disk                     | Persistent/disk-related |
| **Page Table**     | Finds pages currently in memory         | Memory                  |
| **Buffer Pool**    | Actually stores pages in memory         | RAM                     |
| **Frames**         | Individual locations inside buffer pool | RAM                     |

### Easy way to remember

**Directory = Disk**

**Table = RAM**

---

# 11. Page Table Is Not Durable

The page table generally does **not** need to be stored permanently on disk.

Why?

If the database crashes:

```text
RAM disappears
```

So the contents of the page table are lost anyway.

The database can rebuild the page table as pages are brought back into memory.

Some systems may preserve or preload information for optimization, but durability is not the normal purpose of the page table.

---

# 12. Pointer Guarantee

When the buffer pool manager gives the execution engine a pointer to a page, there is a contract:

> The pointer remains valid while the page is being used.

The execution engine must eventually tell the buffer manager:

> "I'm done with this page."

Only then can the buffer manager safely consider removing it from memory.

---

# 13. Pin Count / Reference Count

A **pin count** tracks how many users currently have a page pinned in memory.

Example:

```text
Page 5
Pin Count = 2
```

This means two parts of the database system currently have references to the page.

### Why is this necessary?

Suppose:

```text
Execution Engine → Page 5
```

If the buffer manager evicted Page 5 while the execution engine was still using it, the frame might become:

```text
Page 5 → replaced by Page 9
```

The execution engine would still have a pointer to that frame but would now see incorrect data.

### Rule

> **A page with a nonzero pin count cannot be evicted.**

---

# 14. Latches

A **latch** protects internal database data structures from concurrent access.

For example, multiple threads might simultaneously modify the page table.

A latch prevents race conditions.

Conceptually:

```text
Thread A
   ↓
Acquire latch
   ↓
Modify page table
   ↓
Release latch
```

Another thread must wait while the protected critical section is being modified.

---

# 15. Latches vs. Locks

This is a very important distinction.

### Latch

Protects:

> **Internal database data structures**

Examples:

* Page table
* Buffer manager structures
* Internal queues

A latch is similar to a low-level mutex.

### Lock

Protects:

> **Logical database objects**

Examples:

* Tuple
* Page
* Table
* Index

Locks are associated with transactions and concurrency control.

### Comparison

| Latch                           | Lock                              |
| ------------------------------- | --------------------------------- |
| Low-level                       | Higher-level                      |
| Protects internal structures    | Protects logical database objects |
| Short duration                  | Can last much longer              |
| Database implementation concern | Transaction/concurrency concern   |
| Similar to mutex                | Database locking mechanism        |

### Memory trick

**Latch = implementation**

**Lock = transaction/data**

---

# 16. Virtual Memory

The database system is trying to provide the illusion that it has more memory available than physically exists.

This is similar to **virtual memory** in an operating system.

The OS can use `mmap()` to map a file into a process's virtual address space.

Conceptually:

```text
File on Disk
     ↓
mmap()
     ↓
Virtual Address Space
     ↓
Physical RAM
```

If the required page is not currently in RAM, a **major page fault** can occur.

The OS then:

1. Blocks the process/thread.
2. Finds the requested page on disk.
3. Loads it into physical memory.
4. Updates the virtual-memory mapping.
5. Resumes the process.

---

# 17. Why Database Systems Don't Want the OS Managing Their Pages

At first, OS virtual memory seems like exactly what a database needs.

However, the OS does not understand the database's workload.

The OS doesn't know:

* SQL queries
* Transactions
* Query priorities
* Page dependencies
* Which pages are important
* Which pages are frequently used together
* Database logging requirements

Therefore, the database can often make better decisions.

---

# 18. Problem #1: OS Controls Eviction

The OS may decide to evict a page whenever it wants.

The database does not necessarily know:

* What was evicted
* When it was evicted
* Why it was evicted

This reduces database control.

---

# 19. Problem #2: Dirty Pages

A **dirty page** is a page that has been modified in memory since it was read from disk.

Example:

```text
Disk:
Page A = old data

↓ read

Memory:
Page A = old data

↓ modify

Memory:
Page A = NEW data
Dirty = true
```

The database cannot simply throw away the page.

It must eventually write the modified version back to disk.

---

# 20. Problem #3: Write-Ahead Logging

Database systems may have dependencies between writes.

For example:

```text
Log record
     ↓
Data page
```

The log record may need to reach durable storage **before** the modified data page.

The OS does not understand these database-specific dependencies.

Therefore, allowing the OS to freely write dirty pages can interfere with database durability mechanisms.

---

# 21. Problem #4: Stalling

With OS-managed virtual memory, a thread may access a page that isn't currently in physical memory.

The thread then blocks while the OS retrieves the page.

That means:

```text
Query worker
     ↓
Memory access
     ↓
Page fault
     ↓
BLOCK
     ↓
Disk I/O
     ↓
Resume
```

The database would prefer to control I/O itself and potentially perform useful work while another page is being fetched.

---

# 22. Problem #5: Error Handling

With `mmap`, a memory access can unexpectedly cause an OS-level fault or interruption.

The database has less direct control over where I/O errors occur.

With explicit database I/O:

```text
Database requests page
        ↓
Disk read
        ↓
Error?
        ↓
Handle error here
```

This gives the database a more controlled error-handling model.

---

# 23. Problem #6: Extra Overhead

The OS has its own:

* Page tables
* Latches
* Memory-management metadata
* Page cache
* Replacement mechanisms

The database then has similar structures.

This can mean duplicated work.

---

# 24. Database Buffer Pool vs. OS Virtual Memory

| Database Buffer Pool                   | OS Virtual Memory                   |
| -------------------------------------- | ----------------------------------- |
| Database controls replacement          | OS controls replacement             |
| Knows query workload                   | Does not know SQL workload          |
| Knows transactions                     | Does not know transactions          |
| Knows page dependencies                | Does not know database dependencies |
| Can prioritize database I/O            | Limited application-level knowledge |
| Designed specifically for DB workloads | General-purpose                     |

### Main idea

> The database has more information about its workload, so it can make more informed memory-management decisions.

---

# 25. Buffer Replacement Policy

Eventually:

```text
Buffer Pool
↓
No free frames
```

The database needs to decide:

> **Which page should we remove?**

This is called the **buffer replacement policy**.

The ideal policy would evict the page that is least likely to be needed in the future.

But the future is unknown.

Therefore, systems use approximations.

---

# 26. Requirements for a Replacement Algorithm

A good replacement algorithm should:

### 1. Make good decisions

Avoid removing pages likely to be needed soon.

### 2. Be fast

The replacement algorithm itself cannot be expensive.

If disk I/O takes 1 ms but replacement takes 10 ms, the replacement algorithm defeats the purpose.

### 3. Use little metadata

Memory used for replacement metadata cannot be used for actual database pages.

---

# 27. LRU — Least Recently Used

**LRU** means:

> Evict the page that has not been accessed for the longest amount of time.

Example:

```text
Page A → accessed recently
Page B → accessed 10 seconds ago
Page C → accessed 1 minute ago
```

LRU chooses:

```text
Page C
```

because it was least recently used.

---

# 28. LRU Using a Linked List

One way to implement LRU is with a linked list.

Example:

```text
Most Recent
     ↓
[A] → [B] → [C]
              ↑
          Least Recent
```

If Page C is accessed:

```text
[C] → [A] → [B]
```

If a page needs to be evicted:

```text
Evict B
```

depending on the current ordering.

---

# 29. LRU Using Timestamps

Another implementation can store an access timestamp.

Example:

| Page | Last Access |
| ---- | ----------: |
| A    |          10 |
| B    |          25 |
| C    |           4 |

The smallest timestamp is oldest.

Therefore:

```text
Evict C
```

The lecture emphasized that these are different representations of essentially the same idea.

---

# 30. Clock Algorithm

LRU can require more metadata and maintenance.

The **Clock algorithm** provides an approximation of LRU.

Instead of maintaining the exact access order, each page has a **reference bit**.

```text
Reference bit = 0
```

means:

> Page has not been accessed since the algorithm last checked.

```text
Reference bit = 1
```

means:

> Page has been accessed.

---

# 31. Clock Hand

The clock algorithm uses a pointer called the **clock hand**.

Conceptually:

```text
       Page A
      /      \
 Page D      Page B
      \      /
       Page C
```

The clock hand moves through the pages.

When eviction is needed:

### If reference bit = 1

Set it to:

```text
0
```

and continue.

### If reference bit = 0

Evict that page.

---

# 32. Clock Example

Suppose:

```text
A = 1
B = 1
C = 0
D = 1
```

The clock hand starts at A.

### Step 1

A = 1

Change to:

```text
A = 0
```

Move forward.

### Step 2

B = 1

Change to:

```text
B = 0
```

Move forward.

### Step 3

C = 0

Evict C.

---

# 33. Important Clock Detail

The clock hand does **not** restart from the beginning every time.

It resumes where it previously stopped.

Otherwise, the same pages near the beginning would continually receive special treatment.

---

# 34. Reference Bit vs. Pin Count

These are different!

### Pin Count

Answers:

> **How many users currently have this page?**

Used to determine whether the page can be evicted.

### Reference Bit

Answers:

> **Has this page been accessed since the replacement algorithm last checked?**

Used by Clock to approximate recency.

---

# 35. Sequential Flooding

LRU and Clock have an important weakness called **sequential flooding**.

Suppose the database performs:

```text
Page 1
Page 2
Page 3
Page 4
Page 5
Page 6
Page 7
...
```

A sequential scan can fill the buffer pool with pages that were only needed temporarily.

This can push out pages that were actually very important.

### Example

Suppose Page A is accessed constantly:

```text
A A A A A A
```

Then a large table scan occurs:

```text
B C D E F G H I J
```

LRU may conclude that A is old because the scan touched many other pages.

Eventually:

```text
A → evicted
```

even though A is actually a very popular page.

---

# 36. LRU vs. LFU

Another idea is **LFU — Least Frequently Used**.

Instead of asking:

> When was this page last accessed?

LFU asks:

> How many times has this page been accessed?

Example:

| Page | Access Count |
| ---- | -----------: |
| A    |          100 |
| B    |           20 |
| C    |            2 |

LFU would choose:

```text
C
```

because it has the lowest frequency.

---

# 37. Problem With LFU

Frequency does not contain time information.

Suppose:

```text
Page C
Access count = 1,000,000
```

but all those accesses happened yesterday.

Today nobody uses Page C.

Its huge count could prevent it from being evicted.

So LFU can retain pages that were historically popular but are no longer useful.

---

# 38. LRU-K

**LRU-K** combines information about multiple accesses.

Instead of only looking at the most recent access, it considers multiple historical accesses.

For example:

```text
K = 2
```

means the system tracks information about the two most recent relevant accesses.

This gives the algorithm more historical information than basic LRU.

---

# 39. Logical Timestamps

The lecture uses a monotonically increasing logical counter:

```text
1
2
3
4
5
6
...
```

rather than wall-clock time.

### Why?

Real clock time can change.

For example:

* Daylight saving time
* System clock adjustments
* Clock synchronization

A logical counter always moves forward.

---

# 40. Ghost Cache

A **ghost cache** remembers information about pages that have already been evicted.

Important:

> The ghost cache does not contain the actual page data.

Instead, it stores information such as:

* Page identity
* Previous access history
* Timestamps

### Why?

Suppose:

```text
Page A
↓
evicted
↓
later brought back
```

Without a ghost cache, the system would have to learn from scratch that Page A is frequently used.

With a ghost cache:

```text
Page A returns
↓
Historical information is restored
↓
Replacement algorithm learns faster
```

---

# 41. Approximate LRU-K

Some systems simplify LRU-K.

The lecture describes a system with:

```text
Young region
Old region
```

When a page first enters memory:

```text
Old region
```

If it gets accessed again:

```text
Young region
```

This helps distinguish:

* Pages accessed once
* Pages that are repeatedly accessed

A page that enters the old region and is never accessed again can eventually disappear.

---

# 42. ARC — Adaptive Replacement Cache

**ARC** stands for:

> **Adaptive Replacement Cache**

The lecture describes ARC as a sophisticated replacement strategy that attempts to combine benefits of:

* LRU
* LFU-like frequency information

The key feature is that ARC dynamically adjusts itself based on the workload.

---

# 43. ARC's Adaptive Parameter

ARC maintains a parameter often represented as:

```text
P
```

This controls how much the cache favors different types of history.

Conceptually:

```text
Recent behavior
        ↕
Frequent behavior
```

If the workload changes, ARC can adjust.

Therefore, it does not require the database administrator to manually decide a permanent balance.

---

# 44. Why ARC Uses Ghost Lists

ARC also uses ghost information.

A page can be removed from the actual cache while its history is retained.

This lets ARC determine:

> "Was removing this type of page a mistake?"

It can then adapt its future replacement behavior.

---

# 45. Special Buffer Pool Techniques

Replacement algorithms can use additional information from the query engine.

The database knows things the OS does not know.

For example:

> "This query is doing a sequential scan."

The database can respond differently.

---

# 46. Separate Buffer Region for Sequential Scans

A sequential scan can pollute the global buffer pool.

Instead, the database can allocate a small separate region.

Conceptually:

```text
Global Buffer Pool
┌───────────────────────┐
│ Important Pages       │
│ Index Pages           │
│ Frequently Used Data  │
└───────────────────────┘

Separate Scan Buffer
┌───────────────────────┐
│ Page A                │
│ Page B                │
│ Page C                │
│ Page D                │
└───────────────────────┘
```

This prevents a large scan from destroying useful cache contents.

---

# 47. PostgreSQL Ring Buffer

PostgreSQL can use a circular/ring buffer for certain sequential scans.

Conceptually:

```text
A → B → C → D
↑           ↓
└───────────┘
```

When the end is reached, it wraps around.

This limits the effect of sequential flooding.

---

# 48. Priority Hints

The execution engine can provide the buffer manager with information about how important pages are.

For example, consider a B+ tree.

The root page is extremely important because many operations must start there.

```text
          ROOT
         /    \
       ...    ...
```

A database could give the root page a high priority.

That tells the replacement system:

> Avoid evicting this page if possible.

---

# 49. Transaction-Level Hints

The database can also understand that multiple accesses may belong to the same transaction.

For example:

```text
Transaction
   ↓
Read record
   ↓
Update record
```

Those accesses may not mean that two independent users are interested in the page.

The buffer manager can use transaction/query information to interpret access patterns more accurately.

---

# 50. Enterprise vs. Simpler Systems

The lecture emphasizes that sophisticated commercial database systems can use much more information when managing buffers.

Examples discussed include:

* Oracle
* IBM DB2
* Microsoft SQL Server
* Teradata

Open-source systems also implement sophisticated techniques, but commercial systems may invest heavily in additional optimization and tuning.

---

# 51. Dirty Pages

A page becomes **dirty** when it is modified in memory.

Example:

```text
Disk:
Page 5 = X

↓ read

Memory:
Page 5 = X

↓ update

Memory:
Page 5 = Y
Dirty = TRUE
```

The disk still contains:

```text
X
```

while memory contains:

```text
Y
```

Therefore, the database cannot simply throw away the memory version.

---

# 52. Evicting a Clean Page

A clean page has not been modified.

```text
Dirty = FALSE
```

It can be discarded:

```text
Remove page
↓
Free frame
↓
Load new page
```

No disk write is required.

---

# 53. Evicting a Dirty Page

A dirty page requires:

```text
Dirty page
    ↓
Write to disk
    ↓
Wait for I/O
    ↓
Mark clean
    ↓
Free frame
    ↓
Load replacement page
```

This is slower.

---

# 54. Page Cleaning / Buffer Flushing

To avoid waiting when an eviction is urgently needed, the database can write dirty pages in the background.

This is called:

* **Page cleaning**
* **Buffer flushing**

Conceptually:

```text
Background thread
       ↓
Find dirty pages
       ↓
Write them to disk
       ↓
Dirty = FALSE
```

Then, when the replacement algorithm needs a page:

```text
Clean page
↓
Evict immediately
```

---

# 55. Why Background Cleaning Helps

Without background cleaning:

```text
Need frame
↓
Selected page is dirty
↓
WRITE TO DISK
↓
Wait
↓
Evict
```

With background cleaning:

```text
Background:
Dirty → Clean

Later:
Need frame
↓
Select clean page
↓
Evict immediately
```

This reduces stalls.

---

# 56. Problem With Excessive Background Cleaning

Background cleaning itself uses I/O bandwidth.

If the system writes too aggressively:

```text
Too much background writing
↓
Disk bandwidth consumed
↓
Queries compete for I/O
↓
Performance decreases
```

Therefore, database systems use thresholds and policies to determine how aggressively pages should be flushed.

---

# 57. Disk I/O Throughput

The database wants to maximize:

> **How much useful data can be transferred between disk and memory over time.**

This is called **throughput/bandwidth**.

Modern storage devices can perform many operations in parallel.

---

# 58. I/O Scheduling

Suppose multiple workers request:

```text
Page 100
Page 4
Page 101
Page 5
Page 102
```

The database system knows where those pages are.

It may reorder requests:

```text
Page 4
Page 5
Page 100
Page 101
Page 102
```

This can improve sequential access and overall throughput.

---

# 59. Why Database-Level I/O Scheduling Helps

The OS does not necessarily know why an I/O request is happening.

The database does.

For example:

```text
Request A = mission-critical query
Request B = background maintenance
```

The database can prioritize A.

The OS may only see:

```text
Process → I/O request
```

It does not understand the database's internal workload.

---

# 60. Database I/O Queue

A database can maintain its own queue:

```text
Execution Engine
       ↓
I/O Requests
       ↓
Database I/O Queue
       ↓
Reorder / prioritize
       ↓
Disk
```

It can use information such as:

* Page location
* Query priority
* Transaction importance
* Sequential vs. random access
* Logging requirements

---

# 61. OS Page Cache

Normally, when an application reads a file, the OS may place the file's data into the **OS page cache**.

Conceptually:

```text
Disk
 ↓
OS Page Cache
 ↓
Database Memory
```

This can create duplicate copies.

Example:

```text
OS page cache
     ↓
Copy 1

Database buffer pool
     ↓
Copy 2
```

The same database page may therefore exist twice in memory.

---

# 62. Why Duplicate Copies Are Bad

If a database has 100 GB available:

```text
OS cache → some of the data
Database buffer pool → same data
```

Some memory is wasted storing duplicate copies.

The database also loses control over what the OS decides to cache.

---

# 63. Direct I/O

**Direct I/O** allows the database to bypass the OS page cache.

Conceptually:

```text
Normal:

Disk
 ↓
OS Page Cache
 ↓
Database
```

With Direct I/O:

```text
Disk
 ↓
Database Buffer Pool
```

This reduces duplicate buffering.

---

# 64. Why Direct I/O Is Useful

Direct I/O can provide:

* Less memory duplication
* More database control
* Fewer unnecessary copies
* Better coordination with database buffer management

Many database systems prefer this approach.

---

# 65. PostgreSQL and OS Page Cache

The lecture discussed PostgreSQL as an example of a system that historically relied more heavily on the OS page cache than many other database systems.

The lecture's broader point was:

> Depending heavily on the OS page cache can create duplication and reduce database control over memory.

The lecture also discussed ongoing work toward more direct/asynchronous I/O approaches.

---

# 66. Asynchronous I/O

With synchronous I/O:

```text
Request I/O
↓
WAIT
↓
I/O completes
↓
Continue
```

With asynchronous I/O:

```text
Request I/O
↓
Continue doing other work
↓
I/O completes later
```

This can allow the database to keep workers productive while I/O is occurring.

---

# 67. `fsync()`

Writing data using a normal file write does not necessarily mean the data has reached durable storage.

The operating system may temporarily hold data in buffers.

`fsync()` is used to request that changes be flushed toward durable storage.

Conceptually:

```text
Database
   ↓
write()
   ↓
OS buffer
   ↓
fsync()
   ↓
Storage
```

The database can wait for confirmation that the flush completed.

---

# 68. Storage Hardware Can Also Buffer Data

Even after `fsync()`, hardware may have its own caching mechanisms.

For example:

```text
OS
 ↓
Storage controller
 ↓
Device cache
 ↓
Persistent storage
```

Some storage hardware uses battery-backed or otherwise protected cache mechanisms.

The broader database concern is:

> Durability is more complicated than simply calling a write function.

---

# 69. Historical `fsync` Problem

The lecture discussed a historical Linux behavior involving failed `fsync()` operations and dirty-page state.

The concern was that a failed synchronization could result in pages being treated as clean even though the data had not actually been safely persisted.

Some database systems then retried `fsync()` and could receive a misleading successful result.

This was discussed in the lecture as the historical **"fsyncgate"** issue.

The important lesson is not the specific historical bug, but:

> Database systems must be extremely careful about relying on OS behavior for durability.

The lecture stated that this behavior has since been addressed in relevant systems.

---

# 70. Overall Buffer Manager Workflow

When a query requests a page:

```text
1. Query requests Page X
          ↓
2. Buffer Manager checks Page Table
          ↓
3. Is Page X already in memory?
       /          \
     YES           NO
      ↓             ↓
Return pointer   Find free frame
                    ↓
              Free frame exists?
                 /       \
               YES        NO
                ↓          ↓
           Read page    Run replacement
                            ↓
                       Find victim
                            ↓
                     Is victim dirty?
                       /       \
                     NO         YES
                     ↓           ↓
                  Evict      Flush to disk
                                ↓
                              Evict
                                ↓
                         Read requested page
                                ↓
                         Put into frame
                                ↓
                         Update page table
                                ↓
                         Return pointer
```

---

# 71. The Most Important Concepts to Know

## Page

Fixed-size unit of database storage.

## Frame

A memory location capable of holding one page.

## Buffer Pool

Memory reserved by the database for storing pages.

## Buffer Pool Manager

Manages pages moving between disk and memory.

## Page Directory

Helps locate pages on disk.

## Page Table

Tracks pages currently stored in memory.

## Pin Count

Tracks how many users currently hold/use a page.

## Dirty Bit

Indicates whether a page has been modified in memory.

## Latch

Protects internal database data structures.

## Lock

Protects logical database resources for concurrency control.

## Buffer Replacement Policy

Determines which page should be evicted when memory is full.

## LRU

Evict the least recently used page.

## Clock

Approximate LRU using a reference/access bit.

## LFU

Evict the least frequently used page.

## LRU-K

Uses multiple historical accesses to make replacement decisions.

## Ghost Cache

Stores historical information about evicted pages.

## ARC

Adaptive replacement algorithm that dynamically balances recency and frequency.

## Sequential Flooding

A sequential scan can pollute the buffer pool and evict useful pages.

## Page Cleaning

Background writing of dirty pages to disk.

## Direct I/O

Allows database I/O to bypass the OS page cache.

## `fsync()`

Requests that buffered writes be flushed toward durable storage.

---

# 72. Critical Comparisons

### Page vs. Frame

```text
Page  = storage unit
Frame = memory location
```

### Page Directory vs. Page Table

```text
Page Directory = where pages are on disk
Page Table     = where pages are in memory
```

### Latch vs. Lock

```text
Latch = internal data structure protection
Lock  = logical database/transaction protection
```

### Pin Count vs. Reference Bit

```text
Pin Count
→ How many users currently hold the page?

Reference Bit
→ Has the page been accessed since the last check?
```

### LRU vs. LFU

```text
LRU = When was it last used?

LFU = How often was it used?
```

### Clean vs. Dirty

```text
Clean = no modifications since disk read
Dirty = modified in memory
```

### Normal I/O vs. Direct I/O

```text
Normal:
Disk → OS Page Cache → Database

Direct:
Disk → Database Buffer Pool
```

---

# 73. Practice Questions

## Question 1

What is the purpose of a buffer pool?

### Answer

A buffer pool is a region of memory used by the database system to store pages fetched from disk so that queries can access them efficiently.

---

## Question 2

What is a frame?

### Answer

A frame is a fixed-size location in the buffer pool capable of holding one database page.

---

## Question 3

What is the relationship between a page and a frame?

### Answer

A page is the storage unit on disk, while a frame is the corresponding memory location that can hold that page.

---

## Question 4

What is spatial control?

### Answer

Spatial control is organizing data on disk so that data likely to be accessed together is physically close, improving sequential I/O.

---

## Question 5

What is temporal control?

### Answer

Temporal control means maximizing the useful work performed on data after it has been loaded into memory so that expensive disk reads are minimized.

---

## Question 6

What does the page directory do?

### Answer

It helps the database locate pages on persistent storage.

---

## Question 7

What does the page table do?

### Answer

It maps pages currently in memory to the frames containing them.

---

## Question 8

Why doesn't the page table normally need to be durable?

### Answer

Because it describes volatile memory contents. If the system crashes, the buffer pool contents are lost anyway, so the page table can be rebuilt.

---

## Question 9

Why is a pin count necessary?

### Answer

It prevents the buffer manager from evicting a page while another part of the database system is still using it.

---

## Question 10

What happens if a page has a pin count greater than zero?

### Answer

The page cannot safely be evicted because another component still has a reference to it.

---

## Question 11

What is a latch?

### Answer

A latch is a low-level synchronization mechanism used to protect internal database data structures from concurrent access.

---

## Question 12

What is the difference between a latch and a lock?

### Answer

A latch protects internal implementation structures, while a database lock protects logical database objects such as tuples, pages, or indexes for transaction/concurrency purposes.

---

## Question 13

What happens when the buffer pool has no free frames?

### Answer

The buffer manager runs a replacement policy to select a page to evict.

---

## Question 14

What is LRU?

### Answer

LRU means Least Recently Used. It selects the page that has not been accessed for the longest amount of time.

---

## Question 15

What is the main problem with basic LRU during a sequential scan?

### Answer

A sequential scan can flood the buffer pool with pages that are only temporarily needed, causing frequently used pages to be evicted.

---

## Question 16

What is LFU?

### Answer

LFU means Least Frequently Used. It evicts the page with the lowest access count.

---

## Question 17

Why can LFU make a poor decision?

### Answer

It does not account for when accesses happened. A page that was extremely popular in the past can have a high count even if it is no longer being used.

---

## Question 18

What does Clock approximate?

### Answer

Clock approximates LRU.

---

## Question 19

What does a Clock reference bit indicate?

### Answer

It indicates whether a page has been accessed since the clock algorithm last checked it.

---

## Question 20

What happens when Clock encounters a page with reference bit 1?

### Answer

It changes the bit to 0 and continues scanning.

---

## Question 21

What happens when Clock encounters a page with reference bit 0?

### Answer

That page becomes a candidate for eviction.

---

## Question 22

Where does the Clock hand resume?

### Answer

It resumes from where the previous sweep stopped rather than restarting from the beginning.

---

## Question 23

What is LRU-K trying to improve?

### Answer

It improves on basic LRU by considering multiple historical accesses rather than only the most recent access.

---

## Question 24

What is a ghost cache?

### Answer

A ghost cache stores historical information about pages that have been evicted, without storing their actual page contents.

---

## Question 25

Why is a ghost cache useful?

### Answer

It allows the replacement algorithm to remember the behavior of pages after they are evicted rather than learning their access patterns from scratch.

---

## Question 26

What does ARC stand for?

### Answer

Adaptive Replacement Cache.

---

## Question 27

What is ARC designed to combine?

### Answer

ARC attempts to obtain benefits from both recency-based and frequency-based replacement while dynamically adapting to workload changes.

---

## Question 28

What is a dirty page?

### Answer

A dirty page is a page that has been modified in memory after being loaded from disk.

---

## Question 29

Can a clean page be immediately discarded?

### Answer

Yes. If it has not been modified, there is no new data that needs to be written to disk.

---

## Question 30

Can a dirty page simply be discarded?

### Answer

No. Its modifications must be written to disk before the frame can safely be reused.

---

## Question 31

What is page cleaning?

### Answer

Page cleaning is writing dirty pages to disk in the background so they become clean and can later be evicted quickly.

---

## Question 32

Why shouldn't a database clean every dirty page immediately?

### Answer

Excessive background writing consumes I/O bandwidth that could otherwise be used for query processing.

---

## Question 33

What is sequential flooding?

### Answer

Sequential flooding occurs when a sequential scan fills the buffer pool with temporary pages and pushes out pages that are more valuable to other queries.

---

## Question 34

Why can the database make better replacement decisions than the OS?

### Answer

The database understands SQL queries, transactions, access patterns, page dependencies, priorities, and database structure, while the OS generally does not.

---

## Question 35

What is the purpose of Direct I/O?

### Answer

Direct I/O allows database data to bypass the OS page cache, reducing duplicate copies and giving the database greater control over its own buffer pool.

---

## Question 36

What problem can the OS page cache create?

### Answer

The same database page can exist in both the OS page cache and the database buffer pool, wasting memory and potentially causing unnecessary copies.

---

## Question 37

What does `fsync()` attempt to accomplish?

### Answer

It requests that buffered writes be flushed toward durable storage and waits for the operating system to report completion.

---

## Question 38

Why is durability more complicated than simply calling `write()`?

### Answer

A write may initially remain in OS or hardware buffers rather than being safely persisted to the physical storage medium.

---

# 74. Exam-Style Scenario Questions

## Scenario 1

A query requests Page 10. Page 10 is already in the buffer pool.

### What happens?

The buffer manager finds Page 10 in the page table and returns a pointer to its frame. No disk read is necessary.

---

## Scenario 2

Page 10 is not in memory, but there is a free frame.

### What happens?

```text
Page 10
↓
Read from disk
↓
Free frame
↓
Update page table
↓
Return pointer
```

---

## Scenario 3

Page 10 is not in memory and there are no free frames.

### What happens?

The buffer manager:

1. Runs the replacement policy.
2. Selects a victim.
3. Checks whether the victim is pinned.
4. Checks whether it is dirty.
5. If clean → evict.
6. If dirty → write it to disk.
7. Reuse the frame for Page 10.

---

## Scenario 4

A page has:

```text
Pin Count = 3
Dirty = TRUE
```

Can it be immediately evicted?

### Answer

No.

The nonzero pin count means other parts of the system are still using it.

The database must wait until its pin count becomes zero.

---

## Scenario 5

A page has:

```text
Pin Count = 0
Dirty = FALSE
```

Can it be evicted?

### Answer

Yes. It is not being used and has no modifications that need to be written to disk.

---

## Scenario 6

A page has:

```text
Pin Count = 0
Dirty = TRUE
```

Can it be evicted immediately?

### Answer

No.

It is not being used, but its modifications must first be written to disk.

---

# 75. Replacement Policy Cheat Sheet

| Policy    | Main Idea                          | Major Issue              |
| --------- | ---------------------------------- | ------------------------ |
| **LRU**   | Remove least recently used         | Sequential flooding      |
| **Clock** | Approximate LRU with reference bit | Less precise             |
| **LFU**   | Remove least frequently used       | Old popularity remains   |
| **LRU-K** | Track multiple accesses            | More metadata/complexity |
| **ARC**   | Adapt between recency/frequency    | More complex             |

---

# 76. Buffer Manager Cheat Sheet

Memorize this sequence:

```text
REQUEST PAGE
     ↓
Page in buffer?
   /       \
 YES        NO
 ↓           ↓
Return    Find frame
pointer      ↓
          Free frame?
          /       \
        YES        NO
         ↓          ↓
      Read page   Evict page
                     ↓
                Dirty?
                /   \
              NO     YES
               ↓       ↓
             Drop    Flush
                       ↓
                    Evict
                       ↓
                 Read new page
                       ↓
                Update page table
                       ↓
                 Return pointer
```

---

# 77. High-Yield Exam Facts

### Remember these:

**1. Page ≠ Frame**

Page = disk.

Frame = memory.

---

**2. Page Directory ≠ Page Table**

Directory → disk.

Table → memory.

---

**3. Pin count ≠ Reference bit**

Pin count → current users.

Reference bit → recent access.

---

**4. Dirty ≠ Pinned**

Dirty means modified.

Pinned means currently being used.

A page can be:

```text
Pinned + Clean
Pinned + Dirty
Unpinned + Clean
Unpinned + Dirty
```

---

**5. LRU ≠ LFU**

LRU asks:

> When was it last used?

LFU asks:

> How often was it used?

---

**6. Clock is an approximation of LRU**

It uses a reference/access bit rather than maintaining the exact access ordering.

---

**7. Ghost cache does not store the actual page**

It stores historical information about an evicted page.

---

**8. Dirty pages need to be flushed**

Clean pages can simply be discarded.

---

**9. Sequential scans can cause buffer-pool pollution**

This is called **sequential flooding**.

---

**10. Database systems want control**

The overall theme is:

> The database knows more about its workload than the operating system, so the database can make more informed decisions about memory and I/O.

---

# 78. One-Page Mental Model

Think of the entire lecture as this:

```text
                    DATABASE
                        │
                 Execution Engine
                        │
                 "I need Page X"
                        │
                        ▼
              ┌──────────────────┐
              │ Buffer Manager    │
              └──────────────────┘
                        │
                 Check Page Table
                        │
              ┌─────────┴─────────┐
              │                   │
          Page exists          Page missing
              │                   │
              ▼                   ▼
        Return pointer       Find frame
                                  │
                         ┌────────┴────────┐
                         │                 │
                    Free frame        No free frame
                         │                 │
                         │          Replacement Policy
                         │                 │
                         │          Find victim page
                         │                 │
                         │          ┌──────┴──────┐
                         │          │             │
                         │        Clean         Dirty
                         │          │             │
                         │        Evict        Flush
                         │          │             │
                         └──────────┴─────────────┘
                                      │
                                      ▼
                              Read page from disk
                                      │
                                      ▼
                                  Put in frame
                                      │
                                      ▼
                              Update page table
                                      │
                                      ▼
                                Return pointer
```

The buffer manager is essentially the component that controls this entire **disk ↔ memory** movement.

# 79. Final Takeaways

If you understand these ideas, you understand the core of the lecture:

1. Databases store persistent data on disk.
2. Queries need pages in memory to process them efficiently.
3. The buffer pool is the database's memory workspace.
4. Frames are the locations where pages are stored in the buffer pool.
5. The page table tracks which disk pages are currently in memory.
6. Pin counts prevent pages from being evicted while they are being used.
7. Latches protect internal database structures.
8. When memory is full, a replacement policy chooses a victim.
9. LRU uses recency.
10. LFU uses frequency.
11. Clock approximates LRU.
12. LRU-K tracks multiple accesses.
13. Ghost caches preserve historical information after eviction.
14. ARC dynamically balances recency and frequency.
15. Sequential scans can cause sequential flooding.
16. Dirty pages must be written back before eviction.
17. Background page cleaning reduces eviction stalls.
18. Direct I/O avoids unnecessary OS page-cache duplication.
19. Database-level I/O scheduling can use information unavailable to the OS.
20. `fsync()` and durability require careful handling.
21. The overarching goal is to let the database control memory and I/O because it understands the workload better than the general-purpose operating system.
