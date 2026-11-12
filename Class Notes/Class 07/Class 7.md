# Day 7: Transactions and Concurrency Control

Today's class introduces **transactions**, the fundamental unit of work in database
systems. A transaction is a programming abstraction that lets the DBMS guarantee
**recovery** and **concurrency** even when hardware failures or multiple users are
involved. We cover the storage hierarchy and latency numbers that motivate efficient
transaction design, the four **ACID** properties, **RAID** storage, **write-ahead
logging** for durability, and the basics of **concurrency control**.

## 1. What is a Transaction

A **transaction** is a sequence of one or more database operations — reads and/or
writes — that together reflect a single real-world transition. The database system
treats the entire sequence as an **indivisible unit**: either every operation in the
transaction completes successfully, or none of them do.

**Notation / SQL structure:**

```sql
START TRANSACTION;
-- one or more reads and/or writes
UPDATE Products
SET price = price - 1.99
WHERE price > 10.00;
COMMIT;
```

- `START TRANSACTION` begins the transaction.
- `COMMIT` makes all changes permanent.
- `ROLLBACK` undoes all changes since the last `START TRANSACTION`.

**Real-world example — bank transfer:**

Transfer $100 from Bob to Joe. This requires two writes:

1. Debit Bob: `UPDATE Accounts SET balance = balance - 100 WHERE name = 'Bob';`
2. Credit Joe: `UPDATE Accounts SET balance = balance + 100 WHERE name = 'Joe';`

These two writes must happen **together**. If the system crashes after debiting Bob
but before crediting Joe, $100 vanishes. Transactions prevent this.

> **Key takeaway:** A transaction is a single logical unit of work. The DBMS
guarantees that transactions are applied atomically — either completely or not at all.

## 2. Why Transactions Matter

Transactions exist to solve two hard problems simultaneously:

1. **Recovery and durability** — if the system crashes, committed data is not lost and
   uncommitted changes do not leak into the database.
2. **Concurrency** — many users can execute transactions at the same time without
   corrupting each other's data.

**Crash example — products under $1:**

```sql
-- Step 1: find cheap products
SELECT * FROM Products WHERE price < 1.00;

-- Step 2: delete them
DELETE FROM Products WHERE price < 1.00;
```

**What if the system crashes between Step 1 and Step 2?**

- On restart, we do not know whether the delete happened.
- The database may be left with some sub-$1 products still present.
- Without transactions, application code must clean up this mess manually.

Transactions solve this: the DBMS tracks whether the delete was **committed** before
the crash. If not, the DBMS rolls it back automatically on recovery.

> **Key takeaway:** Transactions protect against crashes and simplify application
logic. The DBMS — not the application — ensures consistency after failures.

## 3. Storage Hierarchy and Latency

Understanding **why** transactions need careful design requires understanding the
storage hierarchy. CPU caches, main memory, and disk differ in speed by orders of
magnitude.

### Moore's Law and the Memory Wall

Moore's Law observed that transistor density doubles roughly every two years. CPU
speed improved faster than disk speed, creating the **memory wall**: waiting for disk
I/O dominates execution time.

### Disk vs. Main Memory

A spinning hard drive stores data on rotating platters. A **read/write head** moves
across the platter to the correct track, then the system waits for the desired sector
to rotate under the head.

Two components of disk access time:

- **Seek time** — moving the head to the right track.
- **Rotational delay** — waiting for the sector to arrive under the head.

Typical drives rotate at **10,000–15,000 RPM**. At 15,000 RPM, one full rotation
takes 4 ms; average rotational delay is about 2 ms.

### Latency Numbers Every Engineer Should Know (Jeff Dean)

The gap between memory and disk is enormous:

| Operation | Approximate latency |
|---|---|
| L1 cache reference | ~1 ns |
| L2 cache reference | ~4 ns |
| Main memory reference | ~100 ns |
| SSD random read | ~100 µs |
| HDD seek + rotational delay | ~10 ms |

**Rule of thumb:** a single disk I/O is roughly the cost of **100,000** main-memory
accesses.

**Arrow summary — the storage pyramid:**

```text
Registers / L1/L2 cache  (nanoseconds)
        |
        v
Main memory / RAM        (tens of nanoseconds)
        |
        v
SSD                      (tens of microseconds)
        |
        v
HDD / spinning disk      (milliseconds)
```

> **Key takeaway:** Disk I/O is the bottleneck. Transactions and buffer management
exist to minimize expensive disk accesses.

## 4. ACID Properties

ACID is the contract a transaction manager provides to applications. Each letter is
a guarantee:

| Property | Symbol | Meaning |
|---|---|---|
| Atomicity | A | All-or-nothing execution |
| Consistency | C | Database transforms from one valid state to another |
| Isolation | I | Concurrent transactions do not interfere |
| Durability | D | Committed changes survive crashes |

### Atomicity (A)

A transaction's operations either **all complete** or **none complete**. There is no
intermediate state visible to other transactions.

- If a transaction crashes or is canceled, the DBMS **undoes** all its writes.
- Example: the $100 bank transfer either completes both the debit and credit, or
  neither. The account balances never pass through an invalid intermediate state.

### Consistency (C)

A transaction transforms the database from one **consistent state** to another. Any
integrity constraints — primary keys, foreign keys, check constraints — must hold
after the transaction commits.

- Example: the sum of all account balances should remain constant during a transfer.
  A consistent transfer keeps the total unchanged.

### Isolation (I)

Concurrent transactions execute **as if they were serial** — one after another — even
though the DBMS may interleave their operations for performance.

- Without isolation, two concurrent transfers could overdraw an account or lose an
  update.
- Isolation is achieved through **locking**, **timestamp ordering**, or **multiversion**
  concurrency control.

### Durability (D)

Once a transaction **commits**, its effects survive any subsequent failures. The DBMS
writes enough information to stable storage (typically via the **write-ahead log**)
before acknowledging the commit.

- Example: after Bob receives a "transfer complete" receipt, the $100 credit must
  still be present even if the power fails immediately afterward.

**Arrow summary — ACID in action:**

```text
Bank transfer transaction
  |
  | [Atomicity] both debit and credit happen together
  | [Consistency] total money in system stays the same
  | [Isolation] concurrent transfers do not corrupt balances
  | [Durability] committed transfer survives power failure
  v
Correct account balances guaranteed
```

> **Key takeaway:** ACID is the bedrock reliability contract. Atomicity prevents
half-completed work; consistency enforces rules; isolation hides concurrency;
durability survives crashes.

## 5. Recovery and Durability

**Recovery** is the process of restoring the database to a consistent state after a
crash. **Durability** is the guarantee that committed transactions survive that crash.

### The Problem

A transaction may modify many data pages in memory. If the system crashes before
those modifications reach disk, the changes are lost. On restart, the database must
know which transactions to redo and which to undo.

### Write-Ahead Logging (WAL)

The standard solution is a **log** (also called the write-ahead log or WAL):

- The log is a sequential file on disk that records **every modification** the
  database makes.
- Before a data page is written to disk, the corresponding log record is **forced**
  to stable storage.
- On recovery, the DBMS replays the log to redo committed work and undo incomplete
  work.

**Log record fields:**

| Field | Purpose |
|---|---|
| Transaction ID | Which transaction made the change |
| Data item ID | Which row/page was modified |
| Before image | Value before the change (for undo) |
| After image | Value after the change (for redo) |
| Timestamp / LSN | Ordering for recovery |

**Arrow summary — recovery flow:**

```text
Transaction T1 commits
  |
  | [Log write] commit record forced to disk
  | [Ack] client receives "committed"
  | [Async] data pages flushed to disk later (buffered)
  v
Crash occurs before data pages hit disk
  |
  | [Recovery] read log from disk
  | [Redo] replay T1's after-images
  | [Undo] discard any uncommitted transactions' before-images
  v
Database reflects T1 as committed; all others rolled back
```

> **Key takeaway:** Durability is achieved by writing the log to stable storage
before acknowledging commit. Recovery replays the log: redo committed work, undo
uncommitted work.

## 6. Concurrency Control

**Concurrency** allows multiple transactions to execute at the same time, improving
throughput and reducing average response time. Without concurrency control, the DBMS
would serialize all transactions, and users would take turns — unacceptable for
high-traffic systems.

### Why Concurrency Is Hard

When transactions overlap, their operations interleave. Without protection, this
causes **anomalies**:

| Anomaly | Description | Example |
|---|---|---|
| Lost update | T1 overwrites T1's work | Two transfers to the same account lose one credit |
| Dirty read | T2 reads T1's uncommitted write | T1 aborts; T2 used invalid data |
| Non-repeatable read | T2 reads a value T1 changed and committed | Balance changes between two reads by T2 |
| Phantom read | T2 sees a row T1 inserted and committed | A new product appears in a second query |

### Locking

The most common concurrency control mechanism is **two-phase locking (2PL)**:

- **Shared lock (S)** — for reads; multiple transactions can hold S locks on the
  same item.
- **Exclusive lock (X)** — for writes; only one transaction can hold an X lock, and
  no S locks coexist with it.

Rules:

1. A transaction must acquire an X lock before writing.
2. A transaction must acquire an S lock before reading.
3. A transaction holds all locks until it commits or aborts (**rigid 2PL**).

**Arrow summary — serializability:**

```text
Schedule of interleaved operations
  |
  | [Conflict serializability] transform schedule into equivalent serial order
  | [2PL] if every transaction follows 2PL, the schedule is conflict-serializable
  v
Anomaly-free concurrent execution guaranteed
```

> **Key takeaway:** Concurrency control lets many users access the database at once
without anomalies. Two-phase locking is the classic mechanism; multiversion schemes
and timestamp ordering are alternatives.

## 7. RAID Storage

Databases store data on disk. To improve performance, capacity, or reliability, DBMSs
use **RAID** (Redundant Array of Independent Disks). RAID combines multiple physical
disks into a single logical unit.

| RAID level | Description | Database relevance |
|---|---|---|
| RAID 0 | Striping across disks; no redundancy | High throughput, no fault tolerance |
| RAID 1 | Mirroring; exact copies on two disks | Reads scale; survives one disk failure |
| RAID 5 | Block-level striping with distributed parity | Good capacity; survives one disk failure |
| RAID 6 | Like RAID 5, but with two parity blocks | Survives two simultaneous failures |
| RAID 10 | Mirroring + striping | High performance + fault tolerance |

### Definitions and Database Relevance

- **Redundancy** — extra copies or parity data allow the system to **reconstruct**
  data after a disk failure.
- **Array** — multiple disks act as a team rather than isolated devices.
- **Independent** — each disk has its own controller and data path; a failure on one
  does not block access to others.
- **Inexpensive** — commodity disks are cheaper than a single high-end disk of the
  same aggregate capacity.

**Arrow summary — RAID tradeoffs:**

```text
Performance: RAID 0 / RAID 10  >  RAID 5  >  RAID 1
Reliability: RAID 6 / RAID 10  >  RAID 5 / RAID 1  >  RAID 0
Cost:       RAID 5 / RAID 6     <  RAID 10           <  RAID 1 (pure mirror)
```

> **Key takeaway:** RAID improves disk performance and reliability. Databases prefer
RAID levels that balance fast writes, fast recovery, and tolerance to disk failures.

## 8. Write-Ahead Logging (WAL) in Detail

The **write-ahead log** is the mechanism that makes durability concrete.

### Log Properties

1. **Sequential writes** — the log is append-only, so writing it is fast even on
   spinning disks.
2. **Duplexed and archived** — log records are mirrored to stable storage (disk or
   SSD) and often archived for disaster recovery.
3. **Force write** — before `COMMIT` returns to the client, the DBMS forces the log
   record to stable storage (`fsync` or equivalent).

### Recovery Using the Log

On restart after a crash, the recovery manager scans the log:

- **Redo phase** — replay every **committed** transaction's after-images. Bring the
  database up to date as if the crash never happened.
- **Undo phase** — roll back every **uncommitted** transaction using before-images.
  Remove their partial effects so the database reflects only committed work.

**Arrow summary — WAL write path:**

```text
Transaction modifies buffer pool page
  |
  | [Log force] log record written + fsync to stable storage
  | [Buffer dirty] data page marked dirty in memory
  | [Async flush] background writer eventually flushes dirty page to disk
  v
COMMIT returned to client only after log is durable
```

> **Key takeaway:** WAL turns durability into a simple invariant — the log is on
stable storage before the commit acknowledgment. Recovery is then a mechanical replay
of that log.

## 9. Transaction Architecture and Plan Execution

Relational algebra defines the **logical operators**; the transaction layer attaches
the **reliability guarantees** around them. A query plan executes inside a transaction
boundary.

**Typical execution flow:**

```text
BEGIN TRANSACTION
       |
       v
[Query]  -- relational algebra expression tree (?, ?, ?, ...)
       |
       v
[Buffer pool]  -- data pages cached in memory
       |
       | [WAL] every change logged + fsync before commit
       v
COMMIT / ROLLBACK
       |
       v
[Recovery] if crash -- replay log, redo committed, undo uncommitted
```

### Transaction Isolation Levels

SQL standard defines four isolation levels, trading off consistency for performance:

| Isolation level | Dirty reads | Non-repeatable reads | Phantoms |
|---|---|---|---|
| READ UNCOMMITTED | allowed | allowed | allowed |
| READ COMMITTED | prevented | allowed | allowed |
| REPEATABLE READ | prevented | prevented | allowed |
| SERIALIZABLE | prevented | prevented | prevented |

Higher isolation requires more locking or multiversion overhead.

> **Key takeaway:** Transactions wrap query execution. The buffer pool, WAL, and
recovery manager together ensure that logical RA plans execute reliably and survive
crashes.

## 10. Practical Example: Bank Transfer with Recovery

Walk through a $100 transfer from Bob to Joe, including what the log looks like.

**Schema:** `Accounts(holder, balance)`

```text
Accounts:
holder  balance
Bob     500
Joe     200
```

**Transaction:**

```sql
START TRANSACTION;
UPDATE Accounts SET balance = balance - 100 WHERE holder = 'Bob';
UPDATE Accounts SET balance = balance + 100 WHERE holder = 'Joe';
COMMIT;
```

**Log records written (in order):**

| LSN | Transaction | Operation | Before | After |
|---|---|---|---|---|
| 1 | T1 | update Bob | 500 | 400 |
| 2 | T1 | update Joe | 200 | 300 |
| 3 | T1 | commit | — | — |

The DBMS forces LSN 3 to disk before returning "committed."

**Scenario 1 — crash before COMMIT (after LSN 2 written but before LSN 3):**

- On recovery: log shows T1 has no commit record.
- **Undo** T1: restore Bob to 500, restore Joe to 200.
- Database returns to exact pre-crash state.

**Scenario 2 — crash after COMMIT (LSN 3 forced, data pages still dirty):**

- On recovery: log shows T1 committed.
- **Redo** T1: apply after-images. Bob = 400, Joe = 300.
- Database reflects the transfer even though data pages never hit disk.

**Arrow summary:**

```text
Transfer $100 from Bob to Joe
  |
  | [Log LSN 1] Bob 500 -> 400
  | [Log LSN 2] Joe 200 -> 300
  | [Log LSN 3] COMMIT (forced to disk)
  v
Crash occurs
  |
  | [Recovery] sees COMMIT -> REDO both updates
  v
Bob = 400, Joe = 300 (transfer survived)
```

> **Key takeaway:** The log is the source of truth. If the commit record is on disk,
the transfer is permanent. If not, the DBMS undoes the partial work.

## 11. Commit Protocol: Forcing the Log to Disk

The moment a client calls `COMMIT`, the DBMS must guarantee that the transaction's
effects survive a crash. This guarantee is only as strong as the **commit protocol**.

### The ARIES Commit Protocol (Steal/No-Force)

Most modern DBMSs use a **steal/no-force** policy:

- **Steal** — the buffer manager may write dirty data pages to disk *before* the
  transaction commits (a page can be "stolen" by an eviction).
- **No-force** — the DBMS does **not** need to flush all dirty data pages to disk
  before returning from `COMMIT`.

This combination is safe **only** because of WAL. The log must reach stable storage
*before* any dirty page is written to disk.

### The Commit Sequence

When the DBMS processes a `COMMIT` request:

1. **Append a commit log record** to the in-memory log buffer.
2. **Force the log record to stable storage** — issue a physical write (`fsync` or
   equivalent) to ensure the log record is on disk.
3. **Return `COMMIT` success** to the client.
4. **Release locks** and allow the transaction's resources to be reclaimed.
5. **Flush dirty pages asynchronously** — the background writer eventually writes
   modified data pages to disk.

Only after step 2 completes does the DBMS tell the client "committed." If the system
crashes between step 2 and step 5, recovery replays the log and redoes the changes.

### Why `fsync` Matters

Operating systems and disk controllers **cache** writes. A `write()` system call may
return before the data actually reaches the physical platter or SSD NAND cells.

- Without `fsync`, a power failure after `write()` but before the disk caches flush
  can lose the log record.
- `fsync` forces the OS to flush all buffered data for that file descriptor to the
  underlying storage device.
- Database logs are typically opened with `O_DSYNC` or `O_DIRECT` to bypass OS
  caches and guarantee durability.

### Group Commit

`fsync` is expensive — roughly one disk rotation (~4–10 ms). Issuing one per
transaction kills throughput. **Group commit** amortizes the cost:

- Instead of flushing immediately after each transaction, the DBMS batches multiple
  commit log records together.
- A timer or log-buffer-full signal triggers a single `fsync` covering all pending
  commits in the batch.
- All transactions in the batch are acknowledged as committed together.

Group commit trades a tiny increase in commit latency for a large gain in throughput.

### Log Sequence Numbers (LSNs)

Every log record carries a **Log Sequence Number (LSN)**, a monotonically increasing
counter. LSNs serve multiple purposes:

- **Recovery ordering** — the DBMS replays the log in LSN order.
- **Dirty-page tracking** — the buffer pool records the highest LSN written to each
  dirty page. During recovery, the DBMS starts redo from the **last checkpoint**,
  not from the beginning of the log.
- **Transaction status** — the DBMS maintains a "last LSN" per transaction in memory,
  allowing it to find all log records for a given transaction during undo.

### Checkpoints

A **checkpoint** is a periodic barrier in the log that limits how far recovery must
scan backward.

- At a checkpoint, the DBMS writes a special record listing all **active**
  (uncommitted) transactions and the set of dirty pages in the buffer pool.
- After the checkpoint record is forced to disk, the DBMS may truncate old log
  segments that are no longer needed for recovery.

Checkpoints shrink recovery time and allow the DBMS to reclaim log space.

**Arrow summary — commit protocol:**

```text
Client calls COMMIT
  |
  | [1] Append commit record to in-memory log buffer
  | [2] fsync log buffer -> stable storage (physical disk)
  | [3] Return "committed" to client
  | [4] Release locks
  | [5] Background writer flushes dirty pages asynchronously
  v
Transaction effects durable; recovery possible even after crash
```

> **Key takeaway:** Durability is not about flushing data pages. It is about
forcing the log record to stable storage before acknowledging commit. `fsync`,
group commit, LSNs, and checkpoints are the mechanisms that make this both fast
and correct.

## 12. Transaction Cheat Sheet

| Concept | Rule / Formula |
|---|---|
| Atomicity | All operations complete, or none do |
| Consistency | Constraints hold before and after each committed transaction |
| Isolation | Concurrent schedule must be equivalent to some serial schedule |
| Durability | Committed changes survive crashes via WAL |
| Write-Ahead Rule | Log record must reach stable storage before the corresponding data page is written |
| ARIES steal/no-force | Dirty pages may be written early; log must be on disk before data pages |
| fsync | Forces OS to flush buffered log writes to physical storage |
| Group commit | Batches multiple commit log records into a single fsync for throughput |
| LSN | Monotonically increasing log sequence number for ordering and recovery |
| Checkpoint | Periodic barrier in the log that limits recovery scan range |
| RAID 0 | Striping, no redundancy |
| RAID 1 | Mirroring, survives one failure |
| RAID 5 | Striping + distributed parity, survives one failure |
| RAID 6 | Double parity, survives two failures |
| RAID 10 | Mirroring + striping, best performance + reliability |

**Three rules to remember:**

1. Every transaction is atomic, consistent, isolated, and durable — ACID is not
   optional for the DBMS, only for the specific isolation level chosen.
2. The write-ahead log must be on stable storage before the data page; this is the
   core durability invariant.
3. Concurrency control and recovery are two sides of the same coin: locking prevents
   anomalies during normal execution; logging repairs the database after a crash.

> **Key takeaway:** Transactions are the DBMS's answer to unreliable hardware and
concurrent users. ACID defines the contract; WAL and locking implement it. Master
the log format, the redo/undo recovery protocol, and the ACID guarantees, and you
can reason about any database failure mode.

