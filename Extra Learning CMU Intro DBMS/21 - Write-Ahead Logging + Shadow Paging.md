# Database Crash Recovery — Shadow Paging, Write-Ahead Logging, Checkpoints & ARIES

## 1. Big Picture: Why Database Recovery Is Necessary

### Definition

**Crash recovery** is the set of algorithms and mechanisms a DBMS uses to restore the database to a correct state after a system failure.

The key requirement is:

> Once the DBMS tells the application that a transaction has committed, its effects must survive a crash.

This is the **durability** property of ACID.

### ACID Connection

The course has now covered:

| ACID Property   | Meaning                                                                       |
| --------------- | ----------------------------------------------------------------------------- |
| **Atomicity**   | A transaction happens completely or not at all                                |
| **Consistency** | A transaction preserves database correctness/invariants                       |
| **Isolation**   | Concurrent transactions behave according to the selected isolation guarantees |
| **Durability**  | Committed changes survive system failures                                     |

This lecture focuses primarily on **durability** and how recovery also preserves **atomicity after crashes**.

---

## 2. The Buffer Pool Creates the Recovery Problem

### Basic Database Architecture

Database data primarily resides on **nonvolatile storage**:

* SSD
* HDD
* Network storage
* Object storage such as S3

However, the DBMS normally cannot efficiently modify database pages directly on storage.

Instead:

```text
             NONVOLATILE STORAGE
             -------------------
                  Database
                     |
                     | Read page
                     v
             +---------------+
             |   Buffer Pool |
             |     DRAM      |
             +---------------+
                     |
                     | Modify
                     v
                  Dirty Page
                     |
                     | Eventually write
                     v
             NONVOLATILE STORAGE
```

### Important Terms

**Buffer pool**

: Memory managed by the DBMS that temporarily stores database pages.

**Dirty page**

: A page in memory that has been modified since it was read from disk.

**Nonvolatile storage**

: Storage whose contents survive a power failure, such as an SSD.

**Volatile storage**

: Memory such as DRAM whose contents disappear when power is lost.

---

### The Problem

Suppose:

```text
T1:
    READ A
    WRITE A
    COMMIT
```

The DBMS modifies `A` in the buffer pool:

```text
Disk:
A = 1

        |
        | read
        v

Buffer Pool:
A = 1

        |
        | UPDATE
        v

Buffer Pool:
A = 2
```

The DBMS then tells the application:

```text
COMMIT SUCCESSFUL
```

But suppose the system crashes before the dirty page reaches disk:

```text
Buffer Pool disappears!

Disk still contains:

A = 1
```

After recovery, the committed transaction appears to have never happened.

That violates **durability**.

---

## 3. What Does a Commit Actually Mean?

When the DBMS acknowledges:

```text
COMMIT SUCCESSFUL
```

the application should be able to assume:

> The committed transaction's effects will not be lost because of a system crash.

There can technically be a race such as:

```text
Transaction safely persisted
        |
        v
System crashes
        |
        X
Commit acknowledgement never reaches application
```

In this situation, the database may have committed even though the client did not receive the acknowledgement.

The application should therefore be designed to determine whether the transaction actually committed rather than assuming that a missing acknowledgement means the transaction definitely did not commit.

---

# 4. Crash Recovery Has Two Phases

The recovery system has two major responsibilities.

### During Normal Execution

The DBMS records enough information so that it can recover later.

```text
Normal Execution
       |
       v
Record recovery information
       |
       v
System Crash
       |
       v
Recovery
       |
       v
Reconstruct correct database state
```

### During Recovery

After the crash, the DBMS examines the information created during normal execution and determines:

* What transactions committed?
* What transactions were incomplete?
* What changes need to be redone?
* What changes need to be undone?

---

# 5. Undo and Redo

Two fundamental recovery operations are:

## Undo

**Undo** removes the effects of a transaction that should not remain in the database.

Undo is needed for:

* Explicit transaction aborts
* Transactions killed by concurrency control
* Transactions that were still running when the system crashed
* Other incomplete transactions

Conceptually:

```text
Before:
A = 10

Transaction changes:
A = 20

Transaction aborts:

UNDO

A = 10
```

---

## Redo

**Redo** reapplies the effects of a transaction that committed but whose changes may not have reached persistent storage.

Example:

```text
Before crash:

Disk:
A = 10

Committed transaction:
A = 20

Crash occurs before A reaches disk

Recovery:

REDO

A = 20
```

---

## Undo vs. Redo

| Operation | Purpose                   | Applies To                       |
| --------- | ------------------------- | -------------------------------- |
| **UNDO**  | Remove unwanted effects   | Uncommitted/aborted transactions |
| **REDO**  | Reapply committed effects | Committed transactions           |

### Memory Trick

```text
UNDO = "You shouldn't have done this."

REDO = "You committed this, so make sure it happened."
```

---

# 6. Buffer Pool Policies: STEAL and FORCE

Two important policies determine when dirty pages can be written to disk.

These are independent decisions.

```text
                 Buffer Pool Policy
                       |
             +---------+---------+
             |                   |
           STEAL                FORCE
             |                   |
      Can uncommitted       Must committed
      data reach disk?      data reach disk
                             before commit?
```

---

# 7. STEAL Policy

### Definition

**STEAL** determines whether the DBMS can write a dirty page containing changes from an **uncommitted transaction** to disk.

### STEAL = Allowed

If STEAL is enabled:

```text
Uncommitted transaction
        |
        v
Dirty page
        |
        v
Can be evicted
        |
        v
Written to disk
```

This is useful because the buffer pool does not need to hold every dirty page until its transaction commits.

### Why STEAL Is Useful

Imagine a transaction modifies a billion pages.

It is impossible to require all billion modified pages to remain in memory until commit.

Therefore, STEAL allows the DBMS to evict dirty pages before their transactions commit.

### But There Is a Problem

If an uncommitted change reaches disk and the transaction later aborts:

```text
Disk contains uncommitted data
        |
        v
Transaction aborts
        |
        v
Must UNDO that change
```

Therefore:

> **STEAL requires UNDO capability.**

---

# 8. NO-STEAL Policy

### Definition

**NO-STEAL** means a dirty page containing uncommitted changes cannot be written to disk.

Therefore:

```text
Uncommitted change
        |
        X
Cannot reach disk
```

If the transaction aborts:

```text
Discard in-memory changes
```

No disk cleanup is required.

### Advantage

Rollback becomes much easier.

### Disadvantage

The DBMS may need enough memory to hold all uncommitted changes.

That does not scale well for huge transactions.

---

# 9. FORCE Policy

### Definition

**FORCE** determines whether the DBMS must write all pages modified by a transaction to disk before acknowledging its commit.

With FORCE:

```text
COMMIT requested
       |
       v
Flush all modified pages
       |
       v
Everything reaches disk
       |
       v
COMMIT SUCCESSFUL
```

### Advantage

Recovery is simpler because committed transactions are already on disk.

### Disadvantage

Committing can be expensive because the DBMS may need to perform many random page writes.

---

# 10. NO-FORCE Policy

With **NO-FORCE**, the DBMS does not have to flush every modified database page when a transaction commits.

Example:

```text
T1 modifies 1,000 pages

COMMIT

Only recovery information must be durable.
The 1,000 pages can remain dirty in memory.
```

This greatly improves normal execution performance.

However:

> The DBMS now needs REDO information so that committed changes can be reconstructed after a crash.

---

# 11. STEAL/NO-STEAL and FORCE/NO-FORCE

These policies produce four combinations.

| Policy                  | Uncommitted pages can reach disk? | Must all committed pages reach disk at commit? | Recovery implication  |
| ----------------------- | --------------------------------: | ---------------------------------------------: | --------------------- |
| **NO-STEAL + FORCE**    |                                No |                                            Yes | Very easy recovery    |
| **NO-STEAL + NO-FORCE** |                                No |                                             No | Need REDO             |
| **STEAL + FORCE**       |                               Yes |                                            Yes | Need UNDO             |
| **STEAL + NO-FORCE**    |                               Yes |                                             No | Need both UNDO + REDO |

The important combination used by most modern systems is:

> **STEAL + NO-FORCE + Write-Ahead Logging**

This provides good performance while still supporting recovery.

---

# 12. Example: Why STEAL and FORCE Conflict

Suppose:

```text
Page P:
+---------+---------+
| A       | B       |
+---------+---------+

T1 modifies A
T2 modifies B
```

Suppose:

```text
T1 = uncommitted
T2 = ready to commit
```

T2 uses FORCE, so its modified page needs to be flushed.

But the page also contains T1's uncommitted modification.

If we simply write the whole page:

```text
Disk:
A = T1's uncommitted value
B = T2's committed value
```

we have accidentally persisted T1's uncommitted data.

A naive solution would create a copy of the page containing only T2's change.

But this becomes extremely expensive for large databases.

This motivates more sophisticated recovery mechanisms.

---

# 13. Shadow Paging

## Definition

**Shadow paging** maintains separate versions of database pages so that committed data and uncommitted changes do not overwrite each other.

The basic idea:

```text
                Database
                   |
          +--------+--------+
          |                 |
       MASTER             SHADOW
          |                 |
   Committed data     Uncommitted data
```

The master version contains only committed data.

The shadow version contains changes being made by active transactions.

---

# 14. Master Page Directory

Shadow paging maintains a **master pointer** that identifies the current committed page directory.

Conceptually:

```text
Master Pointer
      |
      v
+-------------+
| Master Page |
|  Directory  |
+-------------+
      |
      +------> Page A
      |
      +------> Page B
      |
      +------> Page C
```

The important property is:

> The master directory only points to a consistent committed version of the database.

---

# 15. How Shadow Paging Works

Suppose T1 starts.

Initially:

```text
Master Directory
       |
       +----> Page A
       +----> Page B
       +----> Page C
```

T1 creates a shadow page directory:

```text
Master Directory        Shadow Directory
       |                       |
       +----> Page A           +----> Page A
       |                       |
       +----> Page B           +----> Page B
       |                       |
       +----> Page C           +----> Page C
```

T1 modifies Page B.

Instead of overwriting the master Page B:

```text
Copy Page B
     |
     v
Modify copy
     |
     v
Shadow Page B
```

Now:

```text
Master Directory
       |
       +----> Old Page B

Shadow Directory
       |
       +----> New Page B
```

Readers using the master directory still see the old committed data.

---

# 16. Shadow Paging Commit

Suppose T1 modified three pages:

```text
Page A'
Page B'
Page C'
```

The DBMS first writes these pages safely to storage.

Then it atomically changes the master pointer:

```text
Before:

Master Pointer
      |
      v
Old Page Directory


After:

Master Pointer
      |
      v
New Page Directory
      |
      +--> A'
      +--> B'
      +--> C'
```

This is the critical operation.

### Why Is This Atomic?

The DBMS cannot necessarily atomically write three pages.

But it can arrange for the **single master pointer update** to be atomic.

Therefore:

```text
Either:

Master -> Old Directory

OR:

Master -> New Directory
```

There is no partially installed transaction from the perspective of the master directory.

---

# 17. Shadow Paging Abort

If T1 aborts:

```text
Throw away shadow pages
```

The master pointer never changes.

Therefore readers continue seeing:

```text
Committed Master Version
```

The aborted transaction's changes were never made visible.

---

# 18. Shadow Paging Crash Recovery

Suppose:

```text
Master Directory -> Committed Version
Shadow Directory -> Uncommitted Version
```

The system crashes.

During recovery:

```text
Read Master Pointer
       |
       v
Find committed page directory
       |
       v
Ignore shadow pages
       |
       v
Database is consistent
```

This makes recovery extremely simple.

---

# 19. Shadow Paging Advantages

### Advantages

* Simple recovery
* Easy rollback
* No need to undo uncommitted changes in the master database
* Atomic commit through a single pointer change
* Committed database remains consistent

### Disadvantages

#### 1. Copying Cost

Large page directories or data structures may need to be copied.

```text
Huge Database
     |
     v
Copy Page Directory
     |
     v
Expensive
```

LMDB reduces this cost through **copy-on-write paths through B+ trees** rather than copying the entire tree.

#### 2. Fragmentation

Repeated copying creates unused/old pages:

```text
Page Page Page [unused] Page [unused] Page
```

Over time the database becomes fragmented.

#### 3. Garbage Collection

Old pages eventually need to be reclaimed.

#### 4. Random I/O

Pages may become scattered throughout storage.

Sequential I/O is generally preferable to random I/O.

---

# 20. Why Fragmentation Hurts

Database systems prefer sequential access:

```text
Page 1 -> Page 2 -> Page 3 -> Page 4
```

Fragmentation can turn this into:

```text
Page 1 -> Page 918 -> Page 47 -> Page 1203
```

This increases random I/O.

Even with SSDs, sequential access can still provide important performance benefits.

---

# 21. Systems Mentioned with Shadow Paging

The lecture mentioned systems/approaches including:

| System           | Shadow Paging Context                        |
| ---------------- | -------------------------------------------- |
| **IBM System R** | Historical early use                         |
| **LMDB**         | Well-known modern example                    |
| **CouchDB**      | Uses related append/copy techniques          |
| **SQLite**       | Historically used rollback/shadow-style mode |
| **FastDB**       | Mentioned as an example                      |
| **GemStone**     | Mentioned as an older system                 |

SQLite's old **rollback journal mode** was later replaced by **WAL mode as the default**.

---

# 22. SQLite Rollback Journal

SQLite historically used a journal-based approach related to shadow paging.

Suppose Page 2 will be modified.

Before changing it:

```text
Original Page 2
      |
      v
Write original to journal
      |
      v
Modify Page 2 in memory
```

Then Page 3:

```text
Original Page 3
      |
      v
Write original to journal
      |
      v
Modify Page 3
```

The journal contains the **before-images**.

---

## Crash Example

Suppose:

```text
Page 2 -> successfully written to database
Page 3 -> NOT written
Crash
```

The journal still contains:

```text
Original Page 2
Original Page 3
```

Recovery restores those original pages.

```text
Journal
  |
  +--> Original Page 2
  |
  +--> Original Page 3
          |
          v
      Restore database
```

This is effectively an **UNDO-oriented** recovery mechanism.

---

# 23. Why Write-Ahead Logging Is Preferred

Shadow paging and rollback journals have major performance problems:

* Copying entire pages
* Random I/O
* Fragmentation
* Garbage collection
* Expensive page writes

The alternative is:

> **Write-Ahead Logging (WAL)**

WAL is the dominant approach for durable transactional databases.

---

# 24. Write-Ahead Logging (WAL)

## Definition

A **write-ahead log** is a separate sequential log containing enough information about database modifications to recover the database after a crash.

The central WAL rule is:

> **The log record describing a change must reach stable storage before the modified database page is allowed to reach stable storage.**

In other words:

```text
LOG FIRST
   |
   v
DATABASE PAGE SECOND
```

Hence:

**Write-Ahead Logging**

---

# 25. The Fundamental WAL Rule

Suppose:

```text
T1 changes A
```

The DBMS does:

```text
1. Create log record
2. Store log record in log buffer
3. Eventually flush log record to stable storage
4. Modify/write database page
```

Never:

```text
Modify database page
        |
        v
Crash
        |
        v
Log record doesn't exist
```

Without the log, recovery may have no way to determine what happened.

---

# 26. Why WAL Enables STEAL + NO-FORCE

WAL allows:

### STEAL

Uncommitted dirty pages can be written to disk.

Why is that safe?

Because the log contains enough information to **UNDO** them.

### NO-FORCE

Committed database pages do not have to be flushed immediately.

Why is that safe?

Because the log contains enough information to **REDO** committed changes.

Therefore:

```text
          WAL
           |
     +-----+-----+
     |           |
   STEAL       NO-FORCE
     |           |
   UNDO         REDO
```

This is the key design combination used in many DBMSs.

---

# 27. WAL Example

Suppose:

```text
Initial:
A = 1
B = 5
```

Transaction T1 executes:

```sql
UPDATE A SET value = 3;
UPDATE B SET value = 8;
```

Conceptually the log contains:

```text
BEGIN T1

T1, A, before=1, after=3

T1, B, before=5, after=8

COMMIT T1
```

The database pages can remain in memory.

At commit:

```text
COMMIT T1
   |
   v
Flush WAL records
   |
   v
Stable storage confirms
   |
   v
Tell application:
"COMMIT SUCCESSFUL"
```

---

# 28. WAL Log Records

A simplified log record can contain:

| Field                    | Purpose                                 |
| ------------------------ | --------------------------------------- |
| Transaction ID           | Which transaction made the change       |
| Object/Page ID           | What was modified                       |
| Before value             | Needed for UNDO                         |
| After value              | Needed for REDO                         |
| Log sequence information | Identifies ordering/location in the log |

A transaction normally has records such as:

```text
BEGIN
UPDATE
UPDATE
UPDATE
COMMIT
```

---

# 29. Why Log Uncommitted Transactions?

This is completely valid.

Suppose:

```text
T1:
BEGIN
UPDATE A
UPDATE B
```

The log may already contain:

```text
T1 UPDATE A
T1 UPDATE B
```

but there is no:

```text
T1 COMMIT
```

After a crash:

```text
Changes exist in log
       |
       v
No COMMIT record
       |
       v
Transaction did not commit
       |
       v
UNDO
```

The existence of a log record does **not** mean the transaction committed.

---

# 30. WAL Commit Sequence

A simplified sequence is:

```text
Transaction begins
       |
       v
Write BEGIN record
       |
       v
Modify object
       |
       v
Append UPDATE log record
       |
       v
Modify buffer-pool page
       |
       v
More updates...
       |
       v
Append COMMIT record
       |
       v
Flush log to stable storage
       |
       v
Acknowledge COMMIT
```

The database page itself does not necessarily need to be flushed at commit.

---

# 31. Fsync / Stable Storage

An operation such as:

```text
fsync()
```

is used to request that buffered data be flushed so the system can treat it as durable.

Conceptually:

```text
Log Buffer
    |
    | fsync
    v
Stable Storage
```

Only after the DBMS has sufficient confirmation that the required WAL records are durable should it acknowledge the transaction's commit.

---

# 32. Group Commit

## Problem

Suppose every transaction requires its own disk flush.

If one flush takes approximately 1 ms:

```text
1 transaction / 1 ms
=
~1,000 transactions/sec
```

That becomes a bottleneck for high-throughput systems.

---

## Solution: Group Commit

**Group commit** batches multiple transactions' log records into one flush.

Example:

```text
T1 wants commit ----\
T2 wants commit -----\
T3 wants commit ------> LOG BUFFER
T4 wants commit -----/
T5 wants commit ----/

          |
          | one flush
          v

       Disk
```

Instead of:

```text
T1 -> flush
T2 -> flush
T3 -> flush
T4 -> flush
```

the DBMS can do:

```text
T1
T2
T3
T4
   |
   v
ONE GROUP FLUSH
```

This significantly improves throughput.

---

# 33. Double Log Buffers

A DBMS can maintain multiple log buffers so one buffer can be flushed while another receives new log records.

Conceptually:

```text
              +----------------+
Transactions ->| Log Buffer A   |----> Disk
              +----------------+

              +----------------+
New writes -->| Log Buffer B   |
              +----------------+
```

Then they can switch:

```text
Buffer A flushing
       |
       v
Buffer B accepts writes

then

Buffer B flushing
       |
       v
Buffer A accepts writes
```

This allows log generation and disk I/O to overlap.

---

# 34. Why WAL Is Efficient

The database pages may be scattered:

```text
Page 10
Page 700
Page 42
Page 991
...
```

Writing all those pages can require random I/O.

The WAL is instead appended sequentially:

```text
Log:
[Record][Record][Record][Record][Record][Record]
                         ^
                         |
                     append here
```

Therefore, a transaction modifying many pages can generate sequential log writes rather than many random database-page writes.

---

# 35. Physical, Logical, and Physiological Logging

There are three major ways to represent changes in the log.

```text
Logging
   |
   +-------------------+
   |         |         |
Physical  Logical  Physiological
```

---

# 36. Physical Logging

### Definition

Physical logging records low-level changes to specific bytes/locations in database pages.

Conceptually:

```text
Page ID: 100
Offset: 512
Before: ABC
After:  XYZ
```

It is similar to a binary diff/patch.

### Advantages

* Precise
* Fast recovery
* Easy to apply directly to pages

### Disadvantages

* Can generate many log records
* Tightly tied to physical page organization

---

# 37. Logical Logging

### Definition

Logical logging records the operation that changed the database.

For example:

```sql
UPDATE Foo
SET value = 'XYZ'
WHERE id = 1;
```

Instead of logging every physical change, the system could record the operation itself.

### Advantage

A single logical operation could represent millions of tuple modifications.

For example:

```sql
UPDATE Foo
SET value = 'XYZ'
WHERE status = 'active';
```

might update a billion tuples but potentially require only one logical log record.

---

## Problems with Logical Logging

### 1. Non-deterministic Operations

Suppose:

```sql
UPDATE Foo
SET timestamp = CURRENT_TIMESTAMP;
```

If the query is replayed later, `CURRENT_TIMESTAMP` may return a different value.

Therefore recovery would produce different results.

### 2. Execution Time

Suppose the original query took:

```text
1 hour
```

Recovery may have to execute the query again.

Therefore:

```text
Crash
  |
  v
Replay query
  |
  v
Potentially another 1 hour
```

### 3. Transaction Ordering

If transactions ran concurrently, recovery must preserve the necessary execution ordering.

Because of these problems, most systems do not use pure logical logging for normal crash recovery.

---

# 38. Physiological Logging

### Definition

**Physiological logging** combines physical and logical ideas.

The log identifies:

* The page being modified
* A logical location within the page
* The nature of the modification

Conceptually:

```text
Page 100
   |
   +--> Slot 5
         |
         +--> Change tuple here
```

The exact physical organization can be changed while still allowing recovery to locate the appropriate logical tuple/page position.

### Why It Is Useful

It provides a balance:

```text
Physical logging
      |
      | precise but potentially large
      v
Physiological logging
      ^
      | compact and flexible
      |
Logical logging
```

Most production DBMS recovery systems use approaches closer to **physiological logging**.

---

# 39. Indexes Must Also Be Recovered

The database does not only contain table data.

It also contains:

* B+ trees
* Hash indexes
* Other access structures

Indexes are effectively additional copies/representations of database information.

Therefore recovery must account for index changes too.

Otherwise:

```text
Table recovered
     |
     v
Index incorrect
     |
     v
Database inconsistent
```

An alternative for some in-memory systems is to rebuild indexes after a crash rather than logging every index modification.

---

# 40. WAL Can Be Used for Replication

The write-ahead log is useful beyond crash recovery.

Suppose:

```text
Primary Database
       |
       | WAL records
       v
Replica Database
```

The replica can replay the WAL as though it were recovering from a crash.

Conceptually:

```text
Primary:
UPDATE A
UPDATE B
COMMIT

        |
        | WAL stream
        v

Replica:
Replay UPDATE A
Replay UPDATE B
Replay COMMIT
```

This is a major foundation of database replication.

---

# 41. Change Data Capture

**Change Data Capture (CDC)** uses database changes to propagate information to other systems.

Conceptually:

```text
Database
   |
   v
Write-Ahead Log
   |
   v
CDC Tool
   |
   +------> Kafka
   |
   +------> Data Warehouse
   |
   +------> Analytics System
   |
   +------> Other Database
```

The lecture mentioned:

* PostgreSQL WAL
* Debezium
* Kafka
* Oracle GoldenGate

The exact architecture varies by system.

---

# 42. Log-Structured Storage and WAL

Log-structured systems may look similar to WAL because both append changes sequentially.

However, they are not necessarily the same thing.

For example, a log-structured database can still maintain a separate WAL for its in-memory **memtable**.

Conceptually:

```text
Writes
  |
  +----> WAL
  |
  +----> Memtable
            |
            | full
            v
          SSTable
            |
            v
       Durable storage
```

Once the memtable has safely become an SSTable, older WAL records may be truncated.

---

# 43. Why the WAL Cannot Grow Forever

Suppose a database has been running for one year.

Without additional mechanisms:

```text
WAL:
Day 1
Day 2
Day 3
...
Day 365
```

After a crash, the DBMS might need to replay an enormous amount of history.

Therefore we need:

> **Checkpoints**

---

# 44. Checkpoints

## Definition

A **checkpoint** establishes a known point in the log from which recovery can begin instead of processing the entire history of the database.

The basic concept:

```text
Old WAL
------------------------------->
          ^
          |
      CHECKPOINT
          |
          v
Only recent log needs attention
```

A checkpoint records that enough database state has been persisted to establish a recovery boundary.

---

# 45. Naive Blocking Checkpoint

The lecture first presents a simple checkpoint scheme.

### Procedure

1. Stop query execution.
2. Prevent new transactions from starting.
3. Flush log records from memory to disk.
4. Flush dirty buffer-pool pages to disk.
5. Write a checkpoint record to the log.
6. Flush the checkpoint record.
7. Resume query execution.

Flow:

```text
STOP TRANSACTIONS
       |
       v
Flush Log
       |
       v
Flush Dirty Pages
       |
       v
Write Checkpoint Record
       |
       v
Flush Checkpoint
       |
       v
RESUME TRANSACTIONS
```

---

# 46. Recovery with a Blocking Checkpoint

Suppose the log looks like:

```text
Older
 |
 | T1
 | T1
 | T2
 | T3
 | CHECKPOINT
 | T2
 | T3
 | T2 COMMIT
 | T3 incomplete
 |
 v
Crash
```

Recovery can work backward from the newest records until it reaches the checkpoint.

The checkpoint tells the DBMS:

> The relevant dirty state before this point has already been persisted.

Therefore older log records do not need to be processed for normal crash recovery.

---

# 47. REDO and UNDO After a Checkpoint

Suppose after the checkpoint:

```text
T2:
UPDATE
COMMIT

T3:
UPDATE
(no COMMIT)
```

Recovery determines:

```text
T2 committed
    |
    v
REDO T2 if necessary

T3 did not commit
    |
    v
UNDO T3
```

So:

```text
Checkpoint
     |
     +----> T2 committed -> REDO
     |
     +----> T3 incomplete -> UNDO
```

---

# 48. Problems with Blocking Checkpoints

Blocking checkpoints are simple but impractical.

## Problem 1: Stop-the-World

All queries must stop.

```text
Normal workload
      |
      v
CHECKPOINT
      |
      X
Queries blocked
      |
      v
Flush everything
      |
      v
Resume
```

---

## Problem 2: Huge Buffer Pools

Suppose:

```text
Buffer Pool = 100 TB
```

and much of it is dirty.

A checkpoint may need to write enormous amounts of data before allowing queries to continue.

This can create a huge pause.

---

## Problem 3: Checkpoint Frequency

Frequent checkpoints:

```text
+ Faster recovery
- More runtime overhead
```

Infrequent checkpoints:

```text
+ Less runtime overhead
- Longer recovery
```

There is a tradeoff.

---

# 49. Checkpoint Frequency

Checkpoints can be triggered by different policies.

### Time-Based

Example:

```text
Every 5 minutes
```

### Log-Size-Based

Example:

```text
After 512 MB of WAL
       |
       v
Take checkpoint
```

Log-size-based checkpointing avoids taking unnecessary checkpoints when the system is mostly idle.

The appropriate policy depends on application requirements.

---

# 50. Recovery Performance vs. Normal Execution

Checkpointing illustrates a general DBMS tradeoff:

```text
More checkpointing
       |
       +--> More runtime overhead
       |
       +--> Faster recovery
```

versus:

```text
Less checkpointing
       |
       +--> Better normal performance
       |
       +--> More work after crash
```

There is no universally correct checkpoint interval.

---

# 51. WAL Retention

Checkpoints can allow old WAL records to be removed because the database no longer needs them for ordinary crash recovery.

However, external requirements may require retaining logs.

For example:

* Auditing
* Regulatory requirements
* Replication
* Historical analysis

So:

> "Not needed for crash recovery" does not necessarily mean "safe to delete."

---

# 52. Synchronous Commit

Some systems support a mode where the DBMS waits for durable storage before acknowledging a commit.

Conceptually:

```text
COMMIT
  |
  v
Flush WAL
  |
  v
Storage confirms
  |
  v
ACKNOWLEDGE COMMIT
```

The lecture noted that synchronous commit is not necessarily enabled by default in systems such as PostgreSQL and MySQL, depending on configuration.

### Important Clarification

Whether a specific database configuration provides full synchronous durability depends on the DBMS and its durability settings.

For an application where losing a recently acknowledged transaction is unacceptable, the durability configuration must be explicitly verified.

---

# 53. Shadow Paging vs. WAL

| Feature             | Shadow Paging                       | Write-Ahead Logging          |
| ------------------- | ----------------------------------- | ---------------------------- |
| Basic idea          | Maintain old/new page versions      | Maintain separate change log |
| Uncommitted changes | Separate shadow pages               | Can reach disk with STEAL    |
| Commit              | Atomic pointer switch               | Durable commit log record    |
| Undo                | Often simple/discard shadow pages   | Required with STEAL          |
| Redo                | Usually unnecessary in basic design | Required with NO-FORCE       |
| I/O                 | Can require random page writes      | Mostly sequential log writes |
| Fragmentation       | Major concern                       | Less fundamental             |
| Copying             | Can be expensive                    | Logs changes instead         |
| Recovery            | Simple                              | More complex                 |
| Modern usage        | Limited                             | Dominant approach            |

---

# 54. STEAL vs. NO-STEAL

|                                  | STEAL                           | NO-STEAL                      |
| -------------------------------- | ------------------------------- | ----------------------------- |
| Uncommitted page can reach disk? | Yes                             | No                            |
| Requires UNDO?                   | Yes                             | Generally no                  |
| Memory requirements              | Lower                           | Higher                        |
| Runtime flexibility              | High                            | Lower                         |
| Used with WAL?                   | Yes                             | Possible                      |
| Main problem                     | Must remove uncommitted changes | Must retain uncommitted pages |

### Memory Trick

**STEAL = "Steal dirty pages before commit."**

---

# 55. FORCE vs. NO-FORCE

|                                        | FORCE        | NO-FORCE |
| -------------------------------------- | ------------ | -------- |
| Flush all transaction pages at commit? | Yes          | No       |
| Commit can be slower?                  | Yes          | No       |
| Requires REDO?                         | Generally no | Yes      |
| Runtime performance                    | Worse        | Better   |
| Common modern choice                   | Less common  | Common   |

### Memory Trick

**FORCE = "Force pages to disk at commit."**

---

# 56. Physical vs. Logical vs. Physiological Logging

| Logging Type      | Stores                         | Advantage              | Major Problem                             |
| ----------------- | ------------------------------ | ---------------------- | ----------------------------------------- |
| **Physical**      | Byte/page-level changes        | Fast, precise recovery | Large logs                                |
| **Logical**       | Operations/queries             | Small log              | Replay may be expensive/non-deterministic |
| **Physiological** | Page + logical location/change | Good balance           | More complex                              |

---

# 57. Undo vs. Redo vs. Both

| Buffer Policy | Why?                                |
| ------------- | ----------------------------------- |
| **NO-STEAL**  | Uncommitted data never reached disk |
| **STEAL**     | Uncommitted data may need UNDO      |
| **FORCE**     | Committed pages already on disk     |
| **NO-FORCE**  | Committed changes may need REDO     |

Therefore:

```text
STEAL + NO-FORCE
       |
       +------> UNDO
       |
       +------> REDO
```

This is one of the most important relationships in the lecture.

---

# 58. Overall Recovery Architecture

A useful mental model is:

```text
                 TRANSACTIONS
                      |
                      v
              +---------------+
              |  Buffer Pool  |
              +---------------+
                |           |
        dirty pages          |
                |             |
                v             v
         Database File     WAL Buffer
                              |
                              v
                         WAL on Disk
                              |
                              v
                           Crash
                              |
                              v
                         RECOVERY
                              |
                 +------------+------------+
                 |                         |
               REDO                      UNDO
                 |                         |
                 +------------+------------+
                              |
                              v
                     Correct Database
```

---

# 59. Crash Recovery Step-by-Step

A simplified recovery strategy is:

### Step 1: Determine the recovery boundary

Use checkpoints and log metadata to determine how far back the system needs to inspect.

### Step 2: Identify committed transactions

Find transactions that have durable commit records.

### Step 3: REDO committed changes

Ensure changes from committed transactions are present.

### Step 4: UNDO incomplete transactions

Remove effects from transactions that did not commit.

### Step 5: Restore a consistent state

After recovery:

```text
Committed transactions
       |
       v
Present

Uncommitted transactions
       |
       v
Removed
```

---

# 60. Important Distinction: Database Page vs. Log Page

The database and WAL have different roles.

### Database Page

Contains the current materialized database state.

### Log

Contains historical information about changes.

```text
Database:
"What is the current state?"

WAL:
"How did we get here, and what changes must be replayed/undone?"
```

The WAL provides the information necessary to recover when the materialized database state is incomplete.

---

# 61. Important Distinction: Logging vs. Multi-Versioning

Both may maintain multiple representations of data, but they solve different problems.

### MVCC

Primarily provides:

* Concurrent visibility
* Consistent snapshots
* Multiple versions of logical tuples

### WAL

Primarily provides:

* Durability
* Crash recovery
* UNDO/REDO

Conceptually:

```text
MVCC
 |
 +--> "Which version should this transaction see?"

WAL
 |
 +--> "How do I recover after a crash?"
```

A database can use both.

---

# 62. Important Distinction: WAL vs. Log-Structured Storage

They are related but not identical.

### WAL

A recovery log:

```text
Change -> WAL -> database
```

### Log-Structured Storage

A storage organization in which data itself is written in an append-oriented/log-structured manner.

A log-structured system can still use a WAL.

---

# 63. Important Distinction: Logical Locks vs. Recovery Information

Concurrency control and crash recovery solve different problems.

### Concurrency Control

Determines:

> What can concurrent transactions do?

Examples:

* 2PL
* OCC
* MVCC
* Locks
* Timestamps

### Recovery

Determines:

> What happens if the system crashes?

Examples:

* WAL
* Shadow paging
* Checkpoints
* UNDO
* REDO

They interact, but they are not the same mechanism.

---

# 64. Why Indexes Need Logging

Suppose:

```text
Table:
id = 10
value = ABC
```

and an index points to that tuple.

After an update:

```text
Table:
id = 10
value = XYZ
```

the index may also need modification.

If the table change is recovered but the index change is not:

```text
Table = correct
Index = stale
```

Queries can return incorrect results.

Therefore recovery must maintain consistency between:

```text
Table pages
+
Index pages
```

---

# 65. Important System Examples

| System                | Lecture Context                                                                  |
| --------------------- | -------------------------------------------------------------------------------- |
| **IBM System R**      | Historical database/recovery research; shadow paging mentioned                   |
| **LMDB**              | Shadow/copy-on-write style                                                       |
| **SQLite**            | Historically rollback journal; now WAL is default                                |
| **PostgreSQL**        | WAL-based recovery                                                               |
| **MySQL**             | WAL/recovery mechanisms; lecture uses it for examples                            |
| **Oracle**            | Uses logging-based recovery rather than the historical shadow approach discussed |
| **Debezium**          | CDC/WAL-based change extraction                                                  |
| **Kafka**             | Can receive database change streams                                              |
| **Oracle GoldenGate** | Commercial replication/CDC technology                                            |

---

# 66. ARIES

## Definition

**ARIES** stands for:

> **Algorithms for Recovery and Isolation Exploiting Semantics**

It is a foundational database recovery algorithm developed at IBM.

The lecture described ARIES as a major reference point for modern crash recovery.

The paper was published in **1992**.

---

## Core ARIES Ideas

The lecture previewed the major recovery ideas:

```text
Checkpoint
    |
    v
ANALYZE
    |
    v
REDO
    |
    v
UNDO
```

The exact implementation differs among modern database systems, but these high-level ideas are widely important.

### Important Note

Do not assume every modern DBMS implements ARIES literally line-for-line.

Instead, remember:

> ARIES is a foundational model for WAL-based crash recovery using analysis, redo, and undo.

---

# 67. Why Recovery Is Hard

Recovery must handle all of these simultaneously:

```text
Transactions
     |
     +--> Concurrent execution
     |
     +--> Dirty pages
     |
     +--> Partial writes
     |
     +--> Uncommitted data on disk
     |
     +--> Committed data still in memory
     |
     +--> Crashes during recovery
     |
     +--> Index modifications
     |
     +--> Large databases
```

A good recovery system therefore needs to guarantee:

```text
Committed work survives
+
Uncommitted work disappears
+
Database remains internally consistent
```

---

# Important Comparisons

## Shadow Paging vs. WAL

| Concept            | Shadow Paging                                         | WAL                          |
| ------------------ | ----------------------------------------------------- | ---------------------------- |
| Main recovery idea | Keep committed and uncommitted page versions separate | Record changes in a log      |
| Commit             | Switch master pointer                                 | Durable commit record        |
| Rollback           | Discard shadow changes                                | UNDO                         |
| Crash              | Ignore shadow state                                   | Analyze log + REDO/UNDO      |
| Runtime I/O        | Potentially random                                    | Mostly sequential log writes |
| Fragmentation      | Significant issue                                     | Less fundamental             |
| Modern popularity  | Low                                                   | Very high                    |

---

## STEAL vs. NO-STEAL

| Question                         | STEAL                     | NO-STEAL                     |
| -------------------------------- | ------------------------- | ---------------------------- |
| Can uncommitted data reach disk? | Yes                       | No                           |
| What does recovery need?         | UNDO                      | Less/no UNDO for those pages |
| Memory pressure                  | Lower                     | Higher                       |
| Main benefit                     | Better buffer utilization | Easier rollback              |

---

## FORCE vs. NO-FORCE

| Question                                  | FORCE      | NO-FORCE |
| ----------------------------------------- | ---------- | -------- |
| Must modified pages be flushed at commit? | Yes        | No       |
| Need REDO?                                | Usually no | Yes      |
| Commit cost                               | Higher     | Lower    |
| Normal execution                          | Slower     | Faster   |

---

## UNDO vs. REDO

|           | UNDO                             | REDO                   |
| --------- | -------------------------------- | ---------------------- |
| Purpose   | Remove invalid changes           | Reapply valid changes  |
| Used for  | Uncommitted/aborted transactions | Committed transactions |
| Direction | Reverse                          | Reapply                |
| Example   | `A=20 → A=10`                    | `A=10 → A=20`          |

---

## Physical vs. Logical vs. Physiological Logging

|                            | Physical          | Logical           | Physiological            |
| -------------------------- | ----------------- | ----------------- | ------------------------ |
| Granularity                | Bytes/pages       | Operations        | Page + logical operation |
| Log size                   | Potentially large | Small             | Moderate                 |
| Recovery speed             | Fast              | Potentially slow  | Fast                     |
| Determinism concerns       | Low               | High              | Lower                    |
| Flexibility                | Lower             | Higher            | Balanced                 |
| Common production approach | Sometimes         | Rare for recovery | Common                   |

---

# Common Mistakes

* **Thinking COMMIT means the database page itself must immediately be written to disk.**
  With NO-FORCE + WAL, the WAL must be durable, but the database page can remain dirty.

* **Thinking WAL means only committed transactions appear in the log.**
  Uncommitted transactions can absolutely have log records.

* **Thinking an UPDATE log record means the transaction committed.**
  You need the durable COMMIT record.

* **Confusing STEAL with FORCE.**
  STEAL asks whether uncommitted pages can reach disk. FORCE asks whether committed transaction pages must be flushed at commit.

* **Forgetting why STEAL requires UNDO.**
  If uncommitted data reaches disk, recovery must be able to remove it.

* **Forgetting why NO-FORCE requires REDO.**
  A committed change may exist only in memory when the crash occurs.

* **Thinking shadow paging and WAL are the same thing.**
  They solve the same overall durability/recovery problem using very different mechanisms.

* **Thinking the WAL is the database itself.**
  The WAL is recovery information; the database pages contain the materialized database state.

* **Assuming logical logging is always better because it creates fewer records.**
  Replay can be slow and non-deterministic.

* **Ignoring indexes during recovery.**
  Index structures must also remain consistent with table data.

* **Assuming checkpoints eliminate the need for WAL.**
  Checkpoints reduce how much WAL must be examined; they do not replace WAL.

* **Assuming more frequent checkpoints are always better.**
  They improve recovery time but can hurt normal execution.

* **Assuming sequential I/O is irrelevant on SSDs.**
  The lecture emphasized that sequential access can still be substantially preferable.

---

# Exam Review

## Must-Know Definitions

### Durability

Once a transaction commits, its changes survive a system crash.

### Crash Recovery

Mechanisms used to restore the database to a correct state after failure.

### Dirty Page

A buffer-pool page modified since being read from storage.

### STEAL

Allows dirty pages containing uncommitted changes to be written to disk.

### NO-STEAL

Prevents uncommitted dirty pages from reaching disk.

### FORCE

Requires all pages modified by a transaction to be flushed before acknowledging commit.

### NO-FORCE

Does not require transaction-modified pages to be flushed at commit.

### WAL

A separate log that records changes before the corresponding database pages are written to disk.

### UNDO

Removes effects of transactions that should not remain.

### REDO

Reapplies committed changes that may not have reached persistent storage.

### Shadow Paging

Maintains separate committed and uncommitted page versions and atomically switches a master pointer at commit.

### Checkpoint

A recovery boundary that reduces the amount of log that must be processed after a crash.

### Group Commit

Batches multiple transactions' commit log flushes into one disk operation.

### Physical Logging

Logs low-level page/byte modifications.

### Logical Logging

Logs high-level operations or queries.

### Physiological Logging

Logs a page plus a logical change within that page.

---

# Must-Know Methods

## Method 1: Determine Whether UNDO Is Required

Ask:

> Can an uncommitted transaction's dirty page reach disk?

```text
YES
 |
 v
STEAL
 |
 v
UNDO required
```

```text
NO
 |
 v
NO-STEAL
 |
 v
Uncommitted changes stay in memory
```

---

## Method 2: Determine Whether REDO Is Required

Ask:

> Can a transaction commit without all of its database pages being flushed?

```text
YES
 |
 v
NO-FORCE
 |
 v
REDO required
```

```text
NO
 |
 v
FORCE
 |
 v
Committed pages are already durable
```

---

## Method 3: Analyze STEAL + NO-FORCE

If you see:

```text
STEAL + NO-FORCE
```

immediately think:

```text
STEAL
  -> UNDO

NO-FORCE
  -> REDO

Therefore:
  -> UNDO + REDO
```

This is the classic WAL recovery configuration.

---

## Method 4: Determine WAL Ordering

For every modified page:

```text
1. Generate log record
2. Ensure log record is durable
3. Then allow database page to reach disk
```

Never reverse these:

```text
WRONG:

Database page
     |
     v
Disk
     |
     v
Log
```

Correct:

```text
Log
 |
 v
Disk
 |
 v
Database page
 |
 v
Disk
```

---

# Must-Know WAL Example

Suppose:

```text
Initial:
A = 10
```

Transaction:

```sql
UPDATE A
SET value = 20;
```

Conceptual log:

```text
BEGIN T1

T1:
A
before = 10
after  = 20

COMMIT T1
```

Correct commit ordering:

```text
Append UPDATE record
        |
        v
Modify A in memory
        |
        v
Append COMMIT record
        |
        v
Flush WAL
        |
        v
Acknowledge COMMIT
```

The database page containing `A=20` can be flushed later.

---

# Must-Know Shadow Paging Example

Initial:

```text
Master Directory
      |
      +--> A
      +--> B
      +--> C
```

T1 modifies B:

```text
Master Directory
      |
      +--> B

Shadow Directory
      |
      +--> B'
```

T1 commits:

```text
Write B'
   |
   v
Write all new pages
   |
   v
Atomically update Master Pointer
   |
   v
New committed version
```

T1 aborts:

```text
Discard B'
Keep Master Pointer unchanged
```

Crash:

```text
Use Master Pointer
Ignore shadow pages
```

---

# Must-Know Checkpoint Example

Before checkpoint:

```text
WAL:
T1
T1
T2
T3
CHECKPOINT
T2
T3
T2 COMMIT
CRASH
```

Recovery conceptually determines:

```text
T2 committed
   |
   v
REDO T2 if needed

T3 incomplete
   |
   v
UNDO T3

Older records
   |
   v
Mostly outside recovery boundary
```

---

# Important SQL / Syntax

This lecture is primarily about storage and recovery rather than SQL query construction, so there is relatively little SQL syntax to memorize.

The important SQL-like operation from the lecture is the conceptual example:

```sql
UPDATE Foo
SET value = 'XYZ'
WHERE id = 1;
```

### Line-by-Line

```sql
UPDATE Foo
```

Modify rows in the `Foo` table.

```sql
SET value = 'XYZ'
```

Set the `value` column to `XYZ`.

```sql
WHERE id = 1;
```

Restrict the modification to the row whose `id` is `1`.

Under **logical logging**, the entire operation could conceptually be represented as one logical log record.

Under **physical logging**, the DBMS would instead record the low-level page/byte changes resulting from this operation.

---

# Simple Recovery Flowchart

```text
              TRANSACTION
                   |
                   v
             Modify Pages
                   |
                   v
             Create WAL
                   |
                   v
        +----------------------+
        | Is transaction       |
        | committing?          |
        +----------------------+
             |            |
            NO           YES
             |            |
             v            v
       Continue work   COMMIT record
                          |
                          v
                    Flush WAL
                          |
                          v
                    ACK COMMIT
                          |
                          v
                       Normal
                          |
                       CRASH
                          |
                          v
                    RECOVERY
                          |
              +-----------+-----------+
              |                       |
              v                       v
            REDO                    UNDO
              |                       |
       Committed work          Uncommitted work
              |                       |
              +-----------+-----------+
                          |
                          v
                  Correct Database
```

---

# Big Picture Diagram

```text
                    APPLICATION
                         |
                    BEGIN/COMMIT
                         |
                         v
              +----------------------+
              |      DBMS            |
              |                      |
              |  Concurrency Control |
              |          |           |
              |          v           |
              |    Buffer Pool       |
              +----------+-----------+
                         |
              +----------+----------+
              |                     |
              v                     v
        Database Pages         WAL Buffer
              |                     |
              |                     v
              |                WAL on Disk
              |                     |
              v                     |
        Database on Disk <----------+
              |
              |
            CRASH
              |
              v
        +-------------+
        |  RECOVERY   |
        +-------------+
              |
       +------+------+ 
       |             |
      REDO          UNDO
       |             |
       +------+------+
              |
              v
      Consistent Database
```

---

# Final Cheat Sheet / Memory Sheet

## The 5 Things to Know First

### 1. Durability

```text
COMMIT acknowledged
        =
Changes survive crash
```

---

### 2. STEAL

```text
STEAL = Can uncommitted dirty pages reach disk?

YES -> need UNDO
```

---

### 3. FORCE

```text
FORCE = Must all transaction pages reach disk at commit?

YES -> REDO generally unnecessary
NO  -> need REDO
```

---

### 4. WAL

```text
LOG MUST BE DURABLE
BEFORE
CORRESPONDING DATABASE PAGE
```

**Write the log ahead of the data.**

---

### 5. Checkpoints

```text
WAL gets huge
     |
     v
Checkpoint
     |
     v
Recovery starts from a more recent point
```

---

## Core Relationship

```text
             STEAL
               |
               v
              UNDO

           NO-FORCE
               |
               v
              REDO

       STEAL + NO-FORCE
               |
               v
          UNDO + REDO
               |
               v
              WAL
```

---

## Shadow Paging in One Sentence

> Keep committed and uncommitted page versions separate and atomically switch a master pointer when committing.

---

## WAL in One Sentence

> Record a change in the durable log before allowing the corresponding database page to reach disk.

---

## Checkpoint in One Sentence

> Establish a recovery boundary so the DBMS does not have to process the entire lifetime of the WAL after a crash.

---

## Undo in One Sentence

> Remove effects of transactions that did not successfully commit.

---

## Redo in One Sentence

> Reapply effects of transactions that committed but whose database pages were not yet durable.

---

## Group Commit in One Sentence

> Flush the WAL for many committing transactions together instead of performing a separate flush for every transaction.

---

## Logging Types

```text
PHYSICAL
  = exact low-level change

LOGICAL
  = operation/query

PHYSIOLOGICAL
  = page + logical change
```

Remember:

> **Most systems prefer physiological-style logging for recovery.**

---

## Shadow Paging vs. WAL Memory Trick

```text
SHADOW PAGING
    "Copy pages, then SWAP POINTER"

WAL
    "Record changes, then RECOVER"
```

---

## Recovery Mental Model

When a crash occurs, ask:

### Question 1

**Who committed?**

### Question 2

**Who did not commit?**

### Question 3

**Which committed changes might be missing from disk?**

→ **REDO**

### Question 4

**Which uncommitted changes might have reached disk?**

→ **UNDO**

Final state:

```text
Committed   -> KEEP
Uncommitted -> REMOVE
```

---

# Exam Checklist

Before an exam, make sure you can explain all of these without notes:

* [ ] Why buffer pools create a durability problem
* [ ] ACID durability
* [ ] Dirty pages
* [ ] STEAL
* [ ] NO-STEAL
* [ ] FORCE
* [ ] NO-FORCE
* [ ] Why STEAL requires UNDO
* [ ] Why NO-FORCE requires REDO
* [ ] Why STEAL + NO-FORCE is useful
* [ ] Shadow paging
* [ ] Master pointer
* [ ] Atomic pointer switch
* [ ] Shadow paging rollback
* [ ] Shadow paging fragmentation
* [ ] SQLite rollback journal
* [ ] Why WAL is preferred
* [ ] The WAL rule
* [ ] WAL commit ordering
* [ ] `fsync`
* [ ] Group commit
* [ ] Double log buffers
* [ ] Physical logging
* [ ] Logical logging
* [ ] Physiological logging
* [ ] Why logical logging can be non-deterministic
* [ ] Why indexes need recovery information
* [ ] WAL-based replication
* [ ] Change Data Capture
* [ ] Why WAL cannot grow forever
* [ ] Checkpoints
* [ ] Blocking checkpoints
* [ ] Checkpoint tradeoffs
* [ ] Why blocking checkpoints do not scale
* [ ] ARIES
* [ ] Analyze / Redo / Undo
* [ ] Difference between concurrency control and crash recovery

## One Final Mental Model

```text
                    DATABASE RECOVERY
                           |
             +-------------+-------------+
             |                           |
       NORMAL EXECUTION              CRASH
             |                           |
             v                           v
       Buffer Pool                    WAL
             |                           |
             +-------> WAL <-------------+
                         |
                         v
                    CHECKPOINT
                         |
                         v
                       CRASH
                         |
                         v
                    RECOVERY
                         |
                +--------+--------+
                |                 |
               REDO              UNDO
                |                 |
        Committed work      Uncommitted work
                |                 |
                v                 v
             KEEP              REMOVE
                \                 /
                 \               /
                  +------v------+
                         |
                         v
                CONSISTENT DATABASE
```

**The single most important takeaway from the lecture:**

> **WAL + STEAL + NO-FORCE gives high-performance normal execution, while UNDO and REDO provide the information needed to reconstruct the correct database after a crash.**
