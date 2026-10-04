# Database Systems – Optimistic Concurrency Control, Phantom Reads, Predicate/Index Locking, and Isolation Levels

## 1. Concurrency Control Overview

### Definition

**Concurrency control** is the set of techniques a database system uses to control how multiple transactions execute at the same time while preserving correctness.

The main correctness goal discussed throughout the lecture is:

> **Serializability:** The concurrent execution should be equivalent to some serial execution of the transactions.

A **serial execution** means one transaction logically completes before the next transaction begins.

```text
Serial:

T1:  READ → WRITE → COMMIT
                         ↓
T2:                     READ → WRITE → COMMIT
```

A concurrent database does not necessarily execute transactions physically in this order:

```text
Concurrent:

T1:  READ ───── WRITE ───────── COMMIT
           ↘
T2:       READ ───── WRITE ── COMMIT
```

The important requirement is that the final behavior must still be **equivalent to some valid serial ordering**.

---

# 2. Pessimistic vs. Optimistic Concurrency Control

## Pessimistic Concurrency Control

### Definition

A **pessimistic** protocol assumes transactions are likely to conflict.

The database therefore prevents conflicts **before they happen**.

The main example from the previous lectures is:

> **Two-Phase Locking (2PL)**

Transactions acquire locks before accessing data.

```text
Transaction wants data
        ↓
Acquire lock
        ↓
Access data
        ↓
Continue transaction
        ↓
Commit
```

If another transaction already holds an incompatible lock, the transaction must wait or potentially be aborted.

### Advantages

* Conflicts are detected early.
* High-contention workloads can perform well.
* A transaction does not usually perform a large amount of work only to discover at commit time that it cannot commit.

### Disadvantages

* Lock management has overhead.
* Transactions may block each other.
* Deadlocks can occur.
* Locks can reduce parallelism.

---

# 3. Optimistic Concurrency Control

## Definition

**Optimistic Concurrency Control (OCC)** assumes that transactions usually **will not conflict**.

Instead of acquiring locks before doing work, transactions execute independently and check for conflicts **when they attempt to commit**.

Basic idea:

```text
Assume no conflict
        ↓
Execute transaction
        ↓
Check for conflicts
        ↓
   ┌────┴────┐
   ↓         ↓
Success    Conflict
   ↓         ↓
Commit     Abort/Retry
```

### Why use OCC?

Consider short transactions such as web requests:

```text
BEGIN
  ↓
Read a few records
  ↓
Modify something
  ↓
COMMIT
```

If most transactions finish in milliseconds and rarely conflict, constantly acquiring and managing locks may be unnecessary overhead.

OCC instead says:

> "Let transactions run. If a conflict actually occurred, detect it at the end."

---

# 4. Timestamp Ordering

OCC in this lecture is part of a larger family of:

> **Timestamp-ordering concurrency protocols**

Instead of using locks to determine transaction ordering, the database uses **timestamps**.

The goal is to establish a logical ordering equivalent to a serial execution.

For example:

```text
Timestamp 1 → T2
Timestamp 2 → T1

Logical order:

T2 → T1
```

Even if T1 physically started first:

```text
Physical execution:

T1 starts
   ↓
T2 starts
   ↓
T2 commits
   ↓
T1 commits
```

The logical serial order can still be:

```text
T2 → T1
```

This is one of the most important ideas in the lecture.

---

# 5. Transaction Timestamps

### Definition

A transaction timestamp is a value used to establish the transaction's logical position in the serialization order.

The lecture assumes:

* Every timestamp is unique.
* Timestamps increase monotonically.
* A later logical transaction receives a larger timestamp.
* Timestamps do not magically move backward.

For example:

```text
T1 → timestamp 1
T2 → timestamp 2
T3 → timestamp 3
```

### Timestamp Sources

Possible approaches include:

1. Wall-clock time
2. Logical counters
3. Hybrid physical/logical clocks
4. Highly accurate distributed clocks in systems such as Google Spanner

For this lecture, the important assumption is simply:

```text
timestamp values are unique
        +
timestamps increase
        +
timestamps establish logical ordering
```

### UTC

When physical clocks are used, UTC is preferable to local wall-clock time because daylight-saving changes can cause clocks to move backward.

---

# 6. When Does OCC Assign the Timestamp?

This OCC protocol does **not** assign the timestamp when the transaction starts.

Instead:

> The transaction receives its timestamp when it enters the **validation phase**.

```text
BEGIN
 ↓
Read Phase
 ↓
VALIDATION ← timestamp assigned here
 ↓
Write Phase
 ↓
COMMIT
```

### Why assign it at validation?

Because the database does not yet know what the correct logical ordering should be.

Consider:

```text
Physical order:

T1 starts
T2 starts
T2 commits
T1 commits
```

If timestamps were assigned at the beginning:

```text
T1 = 1
T2 = 2
```

That would force the logical ordering:

```text
T1 → T2
```

But T2 actually completed before T1.

Instead, assigning timestamps during validation gives:

```text
T2 validates first → timestamp 1
T1 validates second → timestamp 2
```

Therefore:

```text
Logical order:

T2 → T1
```

This gives the system more flexibility and can improve parallelism.

---

# 7. OCC's Three Phases

The OCC protocol discussed in the lecture has three phases:

```text
┌──────────────┐
│  READ PHASE  │
└──────┬───────┘
       ↓
┌──────────────┐
│ VALIDATION   │
└──────┬───────┘
       ↓
┌──────────────┐
│  WRITE PHASE │
└──────────────┘
```

---

# 8. Phase 1 – Read Phase

### Definition

The **read phase** is where the transaction performs most of its actual work.

The database creates a **private workspace** for the transaction.

```text
Global Database
      │
      ├── A = 123
      │
      ↓
Private Workspace T1
      │
      └── A = 123
```

Other transactions cannot see changes made inside the private workspace.

### Reads

When a transaction reads an object, it can copy that object into its private workspace.

This is particularly important if the transaction wants **repeatable reads**.

### Writes

When a transaction modifies an object:

```text
Global A = 123

T1:
A → 456
```

The global database is not immediately changed.

Instead:

```text
Private Workspace T1:
A = 456
```

The global database remains:

```text
A = 123
```

until the transaction successfully validates.

---

# 9. Read Set and Write Set

OCC tracks the objects accessed by a transaction.

### Read Set

The **read set** contains objects the transaction read.

```text
R(T1) = {A, B, C}
```

### Write Set

The **write set** contains objects the transaction modified.

```text
W(T1) = {A, D}
```

These sets are critical during validation.

---

# 10. Repeatable Reads in the Private Workspace

Suppose:

```text
A = 100
```

T1 reads A:

```text
T1 private workspace:
A = 100
```

Another transaction changes the global database:

```text
Global:
A = 200
```

If T1 reads A again from its private workspace:

```text
T1 sees:
A = 100
```

Therefore, T1 gets the same value it saw previously.

This provides repeatable-read behavior for the objects copied into the workspace.

---

# 11. Phase 2 – Validation

### Definition

The **validation phase** determines whether the transaction is allowed to commit.

This is where the database checks whether the transaction's read/write behavior is compatible with the required serial ordering.

At this point:

```text
Transaction enters validation
        ↓
Assign timestamp
        ↓
Check for conflicts
        ↓
     ┌──┴──┐
     ↓     ↓
   Valid  Invalid
     ↓     ↓
   Write  Abort
```

The validation phase is the "real magic" of OCC.

---

# 12. Phase 3 – Write

If validation succeeds:

1. The transaction enters the write phase.
2. Its private changes are applied to the global database.
3. Appropriate timestamps are installed.
4. The private workspace can be discarded.

```text
Private Workspace
       │
       │ validation succeeds
       ↓
Global Database
```

The write phase must be atomic from the perspective of other transactions.

### Original OCC implementation

The original 1981 protocol could use a global synchronization mechanism around this process.

Modern systems use more sophisticated techniques because a global lock would severely limit parallelism.

---

# 13. OCC Example

Suppose:

```text
A = 123
Write timestamp(A) = 0
```

### T1 begins

T1 creates a private workspace.

```text
T1 workspace = {}
```

T1 reads A:

```text
T1 workspace:
A = 123
```

### T2 begins

T2 also creates a private workspace.

T2 reads A:

```text
T2 workspace:
A = 123
```

### T2 commits first

T2 enters validation.

It receives:

```text
Timestamp(T2) = 1
```

T2 has not modified anything.

Therefore:

```text
Validation succeeds
```

T2 enters the write phase, but has nothing to write.

T2 finishes.

### T1 continues

T1 modifies A:

```text
T1 workspace:
A = new value
```

T1 reads A again.

It sees its own private version.

T1 then enters validation:

```text
Timestamp(T1) = 2
```

No conflicting active transactions remain.

Therefore:

```text
Validation succeeds
```

T1 writes its new version into the global database.

```text
A:
old value → new value

Write timestamp(A) = 2
```

---

# 14. Why the Timestamps Can Look "Backwards"

An important exam concept:

> **Physical execution order does not have to equal logical serialization order.**

Example:

```text
Physical:

T1 starts
      ↓
T2 starts
      ↓
T2 commits
      ↓
T1 commits
```

Validation timestamps:

```text
T2 → 1
T1 → 2
```

Therefore the serial ordering is:

```text
T2 → T1
```

This is valid because T1's changes were private while T2 executed.

---

# 15. Forward vs. Backward Validation

There are two major approaches to OCC validation:

1. **Forward validation**
2. **Backward validation**

The fundamental difference is:

> **Which transactions do you compare against?**

---

## Forward Validation

A transaction about to commit looks at transactions that are **still active**.

```text
T1 wants to commit
       ↓
Look at active transactions
       ↓
Check their read sets
       ↓
Does my write set conflict?
```

The idea is to make sure future transactions do not miss changes that they should have seen.

---

## Backward Validation

A transaction about to commit looks at transactions that **already committed**.

```text
T1 wants to commit
       ↓
Look backward
       ↓
Check previously committed transactions
       ↓
Did I miss a change?
```

The goal is to determine whether the transaction read an outdated state relative to transactions that logically occurred before it.

### Which is more common?

The lecture states that **backward validation is more common** because it is easier to implement and interferes less with transactions that are currently running.

---

# 16. Forward Validation in More Detail

Suppose T1 wants to commit.

We assign:

```text
Timestamp(T1) = 1
```

T2 is still running and does not yet have a timestamp.

For validation purposes:

```text
Timestamp(T2) = ∞
```

This represents the fact that T2 has not yet established its logical position.

The basic question is:

> Does T1's write set conflict with work being performed by active transactions?

---

# 17. Forward Validation – Important Cases

The lecture describes three important conditions under which a transaction can pass validation.

### Case 1: The Other Transaction Has Not Started

If T2 has not started yet:

```text
T1 completes
        ↓
T2 starts
```

There cannot be a conflict because T2 has not read anything yet.

Therefore:

```text
T1 → T2
```

is a valid serial order.

---

### Case 2: No Read/Write Intersection

Suppose:

```text
W(T1) = {A, B}

R(T2) = {C, D}
```

Then:

```text
W(T1) ∩ R(T2) = ∅
```

There is no conflict.

T1 can commit.

The important idea is:

> T1 did not modify anything that T2 read.

---

### Case 3: Conflicting Read/Write Sets

Suppose:

```text
T1:
R = {A}
W = {A}

T2:
R = {A}
```

T1 wants to commit.

But T2 already read A before T1's new version became globally visible.

Therefore:

```text
W(T1) ∩ R(T2) = {A}
```

There is a conflict.

T1 must abort under this validation ordering.

---

# 18. Why Does T1 Abort Instead of T2?

This can initially seem unfair.

Example:

```text
T1:
- did a lot of work
- wants to write A

T2:
- only read A
```

T1 might have done significantly more work.

However, in this OCC example, T1 is the transaction currently trying to establish its logical timestamp.

If:

```text
Timestamp(T1) < Timestamp(T2)
```

then T1 must logically occur before T2.

But T2 already read the old value of A.

Therefore T2's observed state would be inconsistent with T1 occurring before it.

The protocol chooses to abort the transaction currently being validated rather than coordinating a more complicated reordering.

---

# 19. Forward Validation Example

Initial state:

```text
A = old value
```

T1:

```text
Read A
Write A
```

T2:

```text
Read A
```

Timeline:

```text
T1 starts
 ↓
T1 reads A
 ↓
T1 writes A privately
 ↓
T2 starts
 ↓
T2 reads old A
 ↓
T1 validates
```

At validation:

```text
W(T1) = {A}
R(T2) = {A}
```

Therefore:

```text
W(T1) ∩ R(T2) ≠ ∅
```

T1 cannot commit under this ordering.

---

# 20. Changing Validation Order

The same physical operations can sometimes succeed if the validation order changes.

Suppose T2 validates first:

```text
T1 starts
 ↓
T1 modifies A privately
 ↓
T2 starts
 ↓
T2 reads old A
 ↓
T2 validates
 ↓
T2 commits
 ↓
T1 validates
 ↓
T1 commits
```

Logical ordering:

```text
T2 → T1
```

T2 is therefore allowed to read the old value.

T1's later update can then be logically placed after T2.

This demonstrates again:

> OCC separates physical execution from logical serialization order.

---

# 21. Backward Validation

Backward validation looks at transactions that have already committed.

Conceptually:

```text
T1 starts
 ↓
T2 commits
 ↓
T1 validates
 ↓
Check transactions committed since T1 started
```

The question becomes:

> Did T1 miss changes that should have been visible to it?

If so, T1 cannot safely commit.

### Why is backward validation easier?

Because committed transactions are finished.

You do not need to coordinate with transactions that are currently changing their read/write sets.

Therefore:

```text
Backward validation
        ↓
Check completed transactions
        ↓
Less interference
        ↓
Simpler engineering
```

This is why the lecture states that most OCC implementations use backward validation.

---

# 22. Transaction Table

OCC systems can maintain an internal transaction table containing information about transactions currently or recently active.

Conceptually:

```text
Transaction Table

T1 → Read Phase
T2 → Validation Phase
T3 → Write Phase
T4 → Committed
```

This allows the database to determine which transactions need to be considered during validation.

The transaction table can be much cheaper to inspect than repeatedly accessing potentially evicted database pages.

---

# 23. Why Not Just Check Every Tuple?

A natural implementation question is:

> Why not inspect every object that other transactions read or wrote?

That could be expensive.

Suppose a transaction read objects that have been evicted from memory.

Checking them again might require disk I/O.

Instead, keeping transaction metadata in memory can make validation much cheaper.

```text
Transaction metadata
        ↓
Fast in-memory lookup

instead of

Potentially many database objects
        ↓
Possible disk accesses
```

---

# 24. Serial vs. Parallel Validation

### Serial Validation

Only one transaction validates at a time.

```text
T1 → validate
        ↓
T2 → validate
        ↓
T3 → validate
```

This is easier to reason about.

The simplest implementation can effectively "stop the world" during validation.

### Parallel Validation

Multiple transactions may validate concurrently.

```text
T1 ── validation ──┐
T2 ── validation ──┤
T3 ── validation ──┘
```

This is harder because:

* Multiple transactions may modify validation metadata simultaneously.
* Race conditions can occur.
* Latches may be needed.
* Read/write sets may need synchronization.
* Ordering must still be correct.

### Important clarification

The lecture emphasized that a global stop-the-world approach is possible for simple serial validation, but real systems can use more sophisticated synchronization to allow more parallelism.

---

# 25. OCC Performance

OCC works best when conflicts are rare.

### Low Contention

Example:

```text
T1 → reads A
T2 → reads B
T3 → reads C
T4 → reads D
```

Very little conflict exists.

OCC performs well because transactions can execute without waiting for locks.

### High Contention

Example:

```text
T1 → update A
T2 → update A
T3 → update A
T4 → update A
T5 → update A
```

Many transactions may do work and then discover at validation time that they cannot commit.

This creates wasted work.

---

# 26. OCC vs. Two-Phase Locking

| Feature             | OCC                               | Two-Phase Locking              |
| ------------------- | --------------------------------- | ------------------------------ |
| Basic strategy      | Optimistic                        | Pessimistic                    |
| Assumption          | Conflicts are rare                | Conflicts may happen           |
| Locking before work | Generally no                      | Yes                            |
| Conflict detection  | At validation/commit              | During execution               |
| Low contention      | Often excellent                   | Can have unnecessary locking   |
| High contention     | Can waste lots of work            | Often better                   |
| Deadlocks           | Avoids traditional lock deadlocks | Can have deadlocks             |
| Rollback risk       | Can discover conflict late        | Often detects conflict earlier |
| Main overhead       | Validation + copying/workspaces   | Lock management + blocking     |

### Memory trick

```text
Pessimistic:
"Stop and check before doing work."

Optimistic:
"Do the work and check afterward."
```

---

# 27. OCC's Private Workspace Problem

A major disadvantage of the original OCC design is copying data into private workspaces.

Suppose a tuple has:

```text
1000 attributes
```

but the transaction modifies only:

```text
1 attribute
```

A naive private-workspace approach may require copying the entire tuple.

```text
1000 attributes
      ↓
Private copy
      ↓
Modify 1
```

That means unnecessary memory copying.

The lecture identifies this as one reason **MVCC** can be more efficient.

---

# 28. MVCC Connection

**MVCC = Multi-Version Concurrency Control**

The next lecture topic will build on OCC and timestamps.

Instead of keeping all changes in a completely private workspace, MVCC can maintain multiple versions/deltas of objects.

Conceptually:

```text
Original tuple
      ↓
Delta/version 1
      ↓
Delta/version 2
      ↓
Delta/version 3
```

This can reduce copying when only a small portion of an object changes.

### Important distinction

MVCC is not itself the entire concurrency-control policy.

A database can combine:

* MVCC
* timestamps
* 2PL
* OCC
* snapshot isolation
* serializability mechanisms

in different ways.

---

# 29. The Phantom Read Problem

The lecture now moves beyond simple reads and writes.

Consider:

```text
People(id, name, status)
```

T1 runs:

```sql
SELECT COUNT(*)
FROM People
WHERE status = 'paid';
```

Suppose it gets:

```text
99
```

Then T2 inserts:

```text
(id = ..., name = 'DJ Cash', status = 'paid')
```

T2 commits.

T1 runs the exact same query again:

```sql
SELECT COUNT(*)
FROM People
WHERE status = 'paid';
```

Now it gets:

```text
100
```

---

# 30. Definition: Phantom Read

A **phantom read** occurs when a transaction repeats a query over a set/range of rows and finds that rows have appeared or disappeared.

Example:

```text
First query:

status = 'paid'
→ 99 rows


Another transaction inserts a paid row


Second query:

status = 'paid'
→ 100 rows
```

The new row is the **phantom**.

The important distinction is that the transaction did not necessarily reread the same row and get a different value.

Instead:

> The **set of rows matching the query changed**.

---

# 31. Non-Repeatable Read vs. Phantom Read

| Problem             | What changes?        | Example              |
| ------------------- | -------------------- | -------------------- |
| Non-repeatable read | Existing row's value | `balance: 100 → 200` |
| Phantom read        | Set of matching rows | `99 rows → 100 rows` |

### Memory trick

```text
Non-repeatable:
"Same row, different value."

Phantom:
"Same query, different set of rows."
```

---

# 32. Why Ordinary Row Locks Do Not Prevent Phantoms

Suppose T1 reads all rows satisfying:

```sql
WHERE status = 'paid'
```

The problem is:

> You cannot lock a row that does not exist yet.

If T2 wants to insert a new row satisfying:

```text
status = 'paid'
```

there is no existing row for T1 to lock.

Therefore:

```text
T1 locks existing rows
        ↓
T2 inserts a new matching row
        ↓
T1 scans again
        ↓
New row appears
```

This is the fundamental challenge behind phantom protection.

---

# 33. Four General Approaches to Phantom Protection

The lecture describes four broad approaches:

1. Lock everything.
2. Re-execute scans.
3. Predicate/precision locking.
4. Index locking.

---

# 34. Approach 1 – Lock Everything

The simplest solution:

```text
Lock entire table
```

Then other transactions cannot insert/delete/change matching rows.

### Advantage

Very simple.

### Disadvantage

Poor concurrency.

If:

```text
1 billion rows
```

but the query only cares about:

```text
10 rows
```

locking the entire table is excessive.

---

# 35. Approach 2 – Re-Execute the Scan

Another solution is to execute the query again before commit.

For example:

```sql
SELECT COUNT(*)
FROM People
WHERE status = 'paid';
```

First execution:

```text
99
```

Before committing, execute it again.

Second execution:

```text
100
```

The transaction knows something changed.

Therefore:

```text
Validation fails
→ Abort/retry
```

### What must be remembered?

The transaction needs enough information to know what it previously scanned.

The system may track:

* predicates
* scan sets
* fingerprints
* relevant base-table data

It does not necessarily need to save the final aggregation result or every intermediate join result.

---

# 36. Reconnaissance Transactions

The lecture mentions systems such as DynamoDB and Fauna using a related idea.

Conceptually:

### First pass

Run the transaction/query as a reconnaissance operation.

```text
Query
 ↓
Determine what it would read
 ↓
Record scan set
```

### Second pass

Execute the real operation.

```text
Run for real
 ↓
Compare with reconnaissance result
 ↓
If consistent → commit
```

This lets the system verify that the transaction's environment has not changed in a way that violates serializability.

---

# 37. Approach 3 – Predicate Locking

### Definition

**Predicate locking** locks a logical condition rather than individual existing rows.

Example:

```sql
WHERE status = 'paid'
```

Instead of locking:

```text
Row 1
Row 5
Row 7
Row 12
...
```

the system conceptually locks:

```text
status = 'paid'
```

Then an insertion satisfying that predicate conflicts with the lock.

---

# 38. Predicate Locking as a Geometric Idea

The lecture gives a useful conceptual model.

Imagine every predicate maps to a region in a multidimensional space.

For example:

```text
Dimension 1 = status
Dimension 2 = person/name
```

Query 1:

```text
status = paid
```

covers one region.

Another transaction:

```text
name = "DJ Cash"
AND status = "paid"
```

covers another region.

If the regions overlap:

```text
Predicate A
   ┌──────────┐
   │          │
   │    ┌─────┼─────┐
   │    │     │     │
   └────┼─────┘     │
        └───────────┘
          overlap
```

then the predicates potentially conflict.

### Problem

Real databases can have:

* many columns
* complex predicates
* functions
* joins
* large numbers of possible predicates

Therefore exact predicate locking can be extremely expensive and difficult to implement.

---

# 39. Precision Locking

A related technique is **precision locking**.

Instead of reasoning about every possible predicate region, the system uses the actual read/write sets.

Conceptually:

```text
Transaction predicate
        ↓
Check actual rows affected
        ↓
Compare with other transaction's read/write sets
        ↓
Detect overlap
```

This is an approximation/implementation strategy for determining whether predicates overlap.

---

# 40. Approach 4 – Index Locking

The lecture identifies **index locking** as the most common practical approach to phantom protection.

The key insight is:

> Use the index's ordered structure to represent both existing keys and ranges where keys could be inserted.

This solves the problem:

```text
"How do I lock something that doesn't exist?"
```

Answer:

> Lock the **gap/range** in the index where the new value could appear.

---

# 41. Key-Value Locks

The simplest index-locking mechanism is a lock on an existing key.

Suppose the index contains:

```text
12
14
16
20
```

A transaction can lock:

```text
key = 14
```

The lock itself is maintained by the lock manager, not necessarily stored directly inside the B+ tree node.

---

# 42. Virtual Keys

The lecture also mentions boundaries such as:

```text
−∞
+∞
```

These can be represented as virtual keys.

This allows the system to reason about ranges extending beyond the first or last actual key.

---

# 43. Gap Locks

### Definition

A **gap lock** protects a range between existing index keys.

Suppose:

```text
12     14     16     20
       ↑
```

There is a gap between:

```text
14 and 16
```

A transaction can acquire a lock covering:

```text
(14, 16)
```

Then another transaction cannot insert:

```text
15
15.1
15.2
15.3
```

because all of these values fall inside the locked gap.

```text
14 ───────────── 16
       LOCK
       ↑
  15, 15.1, 15.2...
```

This protects values that do not yet exist.

---

# 44. Key-Range Locks

Instead of maintaining individual locks for every possible gap, the system can represent a larger interval.

For example:

```text
[14, 16)
```

means:

```text
14 is included
16 is excluded
```

Any insertion falling into that range conflicts with the lock.

This is much more scalable than maintaining an entry for every possible value.

---

# 45. Why Indexes Are Useful for Phantom Protection

Indexes already maintain keys in sorted order.

For example:

```text
10
14
16
22
30
```

Therefore, the index naturally tells the DBMS:

```text
Gap 1: (-∞, 10)
Gap 2: (10, 14)
Gap 3: (14, 16)
Gap 4: (16, 22)
Gap 5: (22, 30)
Gap 6: (30, +∞)
```

The DBMS can use these ranges to determine where new values could appear.

Without an appropriate index, phantom protection can become much more expensive.

---

# 46. Hierarchical Locking + Index Locking

The lecture combines the earlier concept of hierarchical locking with index-based range locks.

Conceptually:

```text
Database
   ↓
Table
   ↓
Index/Page
   ↓
Key Range
   ↓
Key
```

A transaction can use intention locks at higher levels and more precise locks lower in the hierarchy.

Example:

```text
Table
  │
  └── IX
       │
       └── Index/Page
              │
              └── IX
                   │
                   └── Key Range [14,16)
```

This allows multiple transactions to lock different portions of the index concurrently.

---

# 47. Logical Locks vs. Physical Latches

This distinction is extremely important.

### Logical Lock

Protects the **logical contents** of the database.

Examples:

```text
Row 15
Key 14
Range [14,16)
Table R
```

### Physical Latch

Protects the **physical in-memory data structure**.

For example, if inserting a key causes a B+ tree page split:

```text
Insert 15
   ↓
B+ tree page becomes full
   ↓
Page split
```

The system needs a physical latch to safely modify the page.

Therefore:

```text
Logical lock
    ≠
Physical latch
```

They solve different problems.

### Important example

A transaction may:

1. Acquire a logical lock on a key range.
2. Acquire a physical write latch on a B+ tree page.
3. Modify the page.
4. Release the physical latch according to the B+ tree protocol.
5. Keep the logical lock according to the transaction protocol.

---

# 48. Index Locking Example

Suppose an index contains:

```text
12   14   16   20
```

T1 wants to prevent phantom inserts between 14 and 16.

It obtains:

```text
Key-range lock: [14,16)
```

Now T2 wants to insert:

```text
15
```

T2 must check the index/lock manager.

Because:

```text
15 ∈ [14,16)
```

the operation conflicts with T1's lock.

Therefore T2 must wait or otherwise be handled according to the concurrency-control protocol.

---

# 49. Phantom Protection Comparison

| Technique         | Basic Idea                     | Advantage               | Disadvantage                       |
| ----------------- | ------------------------------ | ----------------------- | ---------------------------------- |
| Lock everything   | Lock table/database            | Simple                  | Very poor concurrency              |
| Re-execute scans  | Run query again                | Relatively simple       | Extra work                         |
| Predicate locking | Lock logical predicates        | Precise conceptually    | Very difficult/expensive           |
| Precision locking | Compare actual read/write sets | More practical          | Requires tracking sets             |
| Index locking     | Lock keys/ranges/gaps          | Efficient and practical | Requires suitable index structures |

### Exam tip

If asked:

> "How can a DBMS prevent phantom reads?"

Think:

```text
Table locks
→ Re-execute scans
→ Predicate/precision locking
→ Index/gap/key-range locking
```

---

# 50. Isolation Levels

The lecture then moves to one of the most important database concepts:

> **Isolation levels**

### Definition

An **isolation level** determines how aggressively the DBMS prevents transaction anomalies.

Higher isolation generally means:

```text
More correctness guarantees
        ↓
More synchronization/work
        ↓
Potentially less concurrency
```

Lower isolation generally allows more anomalies in exchange for potentially better performance.

---

# 51. Major Transaction Anomalies

The lecture discusses:

1. Dirty reads
2. Non-repeatable reads
3. Lost updates
4. Phantom reads

---

## Dirty Read

A transaction reads data written by another transaction that has **not committed yet**.

```text
T1 writes A = 500
       ↓
T2 reads A = 500
       ↓
T1 aborts
```

T2 read a value that should never have become committed.

---

## Non-Repeatable Read

A transaction reads the same existing object twice and gets different values.

```text
T1 reads A → 100

T2 changes A → 200 and commits

T1 reads A → 200
```

Same object, different value.

---

## Lost Update

Two transactions modify the same data and one update overwrites the other.

Conceptually:

```text
Initial A = 100

T1 reads 100
T2 reads 100

T1 writes 150
T2 writes 200

T1's update is effectively lost
```

---

## Phantom Read

A repeated query returns a different set of rows.

```text
First scan → 99 matching rows
T2 inserts a matching row
Second scan → 100 matching rows
```

---

# 52. SQL Standard Isolation Levels

The lecture focuses on the traditional four levels:

```text
SERIALIZABLE
      ↑
REPEATABLE READ
      ↑
READ COMMITTED
      ↑
READ UNCOMMITTED
```

Higher levels provide stronger guarantees.

---

# 53. Serializable

### Definition

**Serializable isolation** guarantees that the concurrent execution is equivalent to a serial execution.

Conceptually:

```text
T1 + T2 + T3 concurrent
        ↓
Must behave like
        ↓
T1 → T2 → T3

or

T2 → T1 → T3

or another valid serial ordering
```

The exact serial order can vary, but the execution must be equivalent to one.

### Guarantees

Under the lecture's traditional 2PL framing:

* No dirty reads
* No non-repeatable reads
* No lost updates
* No phantom reads

---

# 54. Repeatable Read

Repeatable Read prevents changes to rows already read, but traditional SQL isolation-level definitions allow **phantoms**.

Conceptually:

```text
Repeatable Read

Existing rows:
protected

New matching rows:
may appear
```

Therefore:

```text
No dirty reads
No non-repeatable reads
No lost updates

Phantoms:
may occur
```

---

# 55. Read Committed

Under **Read Committed**, a transaction can only read committed data.

However, a later read can see a different committed value.

Therefore:

```text
Dirty reads:
No

Non-repeatable reads:
Possible

Phantoms:
Possible
```

The lecture emphasizes that "possible" does not mean the anomaly always occurs.

It only means the isolation level does not guarantee that it cannot occur.

---

# 56. Read Uncommitted

This is the weakest of the four traditional isolation levels.

It provides the fewest protections against anomalies.

The important conceptual point is:

```text
Lower isolation
→ fewer restrictions
→ potentially more concurrency
→ more possible anomalies
```

---

# 57. Isolation-Level Comparison

| Isolation Level  | Dirty Reads | Non-Repeatable Reads | Phantoms |
| ---------------- | ----------: | -------------------: | -------: |
| Serializable     |          No |                   No |       No |
| Repeatable Read  |          No |                   No | Possible |
| Read Committed   |          No |             Possible | Possible |
| Read Uncommitted |    Possible |             Possible | Possible |

### Important clarification

The exact behavior of specific database systems can differ from this simplified SQL-standard table, especially because modern systems may use MVCC/snapshot-based mechanisms rather than traditional 2PL.

For exams, use the model taught by your instructor unless the question specifically asks about a particular DBMS.

---

# 58. Implementing Isolation Levels with 2PL

The lecture explains that isolation levels can be thought of as turning certain pieces of the concurrency-control machinery on or off.

### Serializable

Use strong locking plus phantom protection.

```text
Strict/strong 2PL
+
Phantom protection
    ↓
Serializable
```

Phantom protection may involve:

* Index locks
* Predicate locks
* Key-range locks
* Other mechanisms

---

### Repeatable Read

Use locking to protect previously read objects, but omit additional phantom protection.

```text
Strict 2PL
+
No additional phantom protection
    ↓
Repeatable Read
```

---

### Read Committed

The lecture describes releasing shared/read locks after the read completes while retaining write protection as needed.

Conceptually:

```text
Read object
 ↓
Acquire S lock
 ↓
Read
 ↓
Release S lock
```

This permits another transaction to modify the object after the read completes.

Therefore, rereading it later may produce a different value.

---

### Read Uncommitted

The system does not require shared locks for reads.

Therefore, reads can potentially observe uncommitted changes.

---

# 59. Isolation Level Is a Tradeoff

The key idea:

```text
Higher isolation
      ↓
More guarantees
      ↓
More synchronization
      ↓
Potentially lower performance
```

versus:

```text
Lower isolation
      ↓
Fewer guarantees
      ↓
Less synchronization
      ↓
Potentially higher performance
```

There is no universally best isolation level.

It depends on the application's requirements.

---

# 60. Why Most Databases Do Not Default to Serializable

The lecture's major practical point is:

> Most production database workloads do not use serializable isolation by default.

Why?

Because guaranteeing full serializability can require expensive mechanisms.

For example:

```text
Serializable query
       ↓
Need phantom protection
       ↓
Need index/predicate/range locking
       ↓
Additional synchronization
       ↓
More overhead
```

If every transaction paid this cost, workloads that do not need serializability could become unnecessarily slow.

Therefore, many systems use weaker defaults such as Read Committed or Repeatable Read.

---

# 61. Database-Specific Defaults

The lecture surveys systems such as:

* SQL Server
* MySQL
* Oracle
* PostgreSQL

and emphasizes that their default isolation levels are generally **not Serializable**.

The exact behavior depends on the database system and whether it uses:

* 2PL
* MVCC
* Snapshot Isolation
* predicate/index locking
* other concurrency-control techniques

### Exam tip

Do not assume:

```text
"SQL database" = "Serializable by default"
```

That is generally false.

---

# 62. Snapshot Isolation

The lecture briefly introduces **Snapshot Isolation (SI)** as a topic that will be explored further.

The basic idea is:

> A transaction reads from a consistent snapshot of data corresponding to an appropriate point in time.

Conceptually:

```text
Database versions:

A@1
A@2
A@3

Transaction starts
      ↓
Uses a snapshot
      ↓
Reads versions visible to it
```

Snapshot Isolation is related to MVCC and is different from traditional 2PL serializability.

The lecture notes that the SQL standard's traditional four-level model did not originally capture all of the behavior associated with multiversion systems.

---

# 63. MVCC + Concurrency Control

An important conceptual distinction:

### MVCC

Determines/maintains **multiple versions** of records.

### Concurrency-control protocol

Determines **which transactions can read/write which versions and when**.

A system can combine MVCC with different concurrency-control mechanisms.

For example:

```text
MVCC
+
2PL
```

or:

```text
MVCC
+
OCC
```

The lecture emphasizes that MVCC is not simply synonymous with OCC.

---

# 64. Strict Serializability / External Consistency

The lecture mentions systems such as Google Spanner.

**Strict serializability**, also called **external consistency**, provides an especially strong ordering guarantee.

The important idea is that the transaction serialization order respects real-world arrival/commit ordering.

Conceptually:

```text
T1 arrives before T2

Therefore:

T1 must be ordered before T2
```

This is stronger than merely finding *some* serial ordering.

---

# 65. Cursor Stability

The lecture briefly mentions **cursor stability**, associated with systems such as IBM DB2.

Conceptually:

```text
Cursor scans rows
      ↓
Read lock held while current/range data is being scanned
      ↓
Scanning finishes
      ↓
Lock released
```

This provides protection while the cursor is actively reading, but does not necessarily guarantee that rereading the same data later will produce the same result.

---

# 66. Overall Concurrency-Control Landscape

The lecture's final conceptual model is:

```text
                 Concurrency Control
                         │
             ┌───────────┴───────────┐
             │                       │
       Pessimistic              Optimistic
             │                       │
            2PL                    OCC
             │                       │
        Lock first             Validate later
             │                       │
       Possible waits          Possible retries
       / deadlocks             / wasted work
```

Then:

```text
                 Multi-Versioning
                       │
          ┌────────────┴────────────┐
          │                         │
        MVCC + 2PL               MVCC + OCC
```

The important point is that these techniques can be combined.

---

# 67. Important Comparisons

## OCC vs. 2PL

| OCC                                      | 2PL                                    |
| ---------------------------------------- | -------------------------------------- |
| Optimistic                               | Pessimistic                            |
| Assume conflicts are rare                | Assume conflicts may occur             |
| Usually no locks during normal execution | Acquire locks before access            |
| Validate at commit                       | Conflicts encountered during execution |
| Excellent for low contention             | Often better for high contention       |
| Can waste completed work                 | Can block early                        |
| No traditional deadlock problem          | Deadlocks possible                     |

---

## Forward vs. Backward Validation

| Forward Validation                     | Backward Validation             |
| -------------------------------------- | ------------------------------- |
| Looks at active transactions           | Looks at committed transactions |
| Checks future transactions             | Checks past transactions        |
| Can interfere with active transactions | Less interference               |
| More complicated                       | Easier                          |
| Less commonly used                     | More commonly used              |

### Memory trick

```text
FORWARD
→ Look forward at active transactions

BACKWARD
→ Look backward at committed transactions
```

---

## Non-Repeatable Read vs. Phantom

| Non-Repeatable Read  | Phantom                       |
| -------------------- | ----------------------------- |
| Same row changes     | Matching row set changes      |
| `A = 100 → 200`      | `99 rows → 100 rows`          |
| Object-level problem | Predicate/range-level problem |

---

## Predicate vs. Index Locking

| Predicate Locking                     | Index Locking                            |
| ------------------------------------- | ---------------------------------------- |
| Locks logical predicate               | Uses index structure to lock keys/ranges |
| Conceptually precise                  | Practical implementation technique       |
| Difficult to implement                | More practical                           |
| Can reason about arbitrary predicates | Works naturally with indexed ranges      |

---

## Logical Locks vs. Latches

| Logical Lock                           | Physical Latch                         |
| -------------------------------------- | -------------------------------------- |
| Protects logical database contents     | Protects physical in-memory structures |
| Transaction-level correctness          | Data-structure correctness             |
| Can cover rows/ranges/tables           | Usually page/node/in-memory structure  |
| Held according to transaction protocol | Often held for short critical sections |
| Prevents logical conflicts             | Prevents physical corruption/races     |

---

# 68. Important SQL Examples

## Basic Phantom-Read Query

```sql
SELECT COUNT(*)
FROM People
WHERE status = 'paid';
```

### Line-by-line

```sql
SELECT COUNT(*)
```

Counts the number of matching rows.

```sql
FROM People
```

Reads the `People` table.

```sql
WHERE status = 'paid';
```

Only rows whose status is `paid` are included.

If the result changes between two executions because another transaction inserts/deletes a matching row, the transaction may experience a phantom.

---

# 69. OCC Conceptual Algorithm

The following is pseudocode rather than SQL:

```text
BEGIN TRANSACTION

1. Create private workspace

2. READ PHASE
   - Read required objects
   - Copy values into workspace
   - Perform updates privately
   - Track read set
   - Track write set

3. VALIDATION PHASE
   - Assign timestamp
   - Check for conflicts
   - If conflict:
       ABORT / RETRY
   - Otherwise:
       continue

4. WRITE PHASE
   - Apply private changes
   - Update metadata/timestamps
   - Make changes visible

5. COMMIT
```

---

# 70. Step-by-Step OCC Problem-Solving Method

When solving an OCC schedule on an exam:

### Step 1: Identify each transaction's operations

Write:

```text
T1:
R(A)
W(A)

T2:
R(A)
```

### Step 2: Build the read/write sets

```text
T1:
R1 = {A}
W1 = {A}

T2:
R2 = {A}
W2 = {}
```

### Step 3: Determine validation order

Who reaches validation first?

That determines timestamp order.

```text
First validation → smaller timestamp
Second validation → larger timestamp
```

### Step 4: Determine which transactions are still active

For forward validation:

```text
Check active transactions.
```

For backward validation:

```text
Check transactions that committed since this transaction began.
```

### Step 5: Check set intersections

Look for conflicts such as:

```text
W1 ∩ R2
W1 ∩ W2
R1 ∩ W2
```

depending on the specific validation rule being taught.

### Step 6: Determine whether the transaction can commit

```text
No conflict
→ Commit

Conflict
→ Abort/retry
```

### Step 7: Explain the logical serial order

Do not only say "T1 aborts."

Explain:

```text
T1 receives timestamp 1
T2 receives timestamp 2

Therefore:
T1 must logically precede T2

But T2 already read an older value
that is inconsistent with T1 preceding it.

Therefore T1 cannot commit under this schedule.
```

That explanation is often what demonstrates actual understanding.

---

# 71. Step-by-Step Phantom-Read Problem Solving

If an exam gives you:

```text
T1:
SELECT ... WHERE predicate
SELECT ... WHERE predicate

T2:
INSERT/DELETE row satisfying predicate
```

follow these steps.

### Step 1

Determine whether T1's query reads a **range/set** of rows.

### Step 2

Check whether T2 changes the set matching the predicate.

### Step 3

If yes, identify:

```text
Phantom read
```

### Step 4

Ask how the DBMS could prevent it.

Possible answers:

```text
Table lock
Index/key-range lock
Predicate lock
Precision locking
Re-execute scan
```

### Step 5

If indexes are available, consider:

```text
Key-range / gap locking
```

because the new row does not exist yet.

---

# 72. Common Mistakes

## Mistake 1: Thinking OCC locks everything first

Incorrect:

```text
OCC → acquire locks → perform work
```

Correct:

```text
OCC → perform work → validate
```

---

## Mistake 2: Assigning the OCC timestamp at BEGIN

For the protocol taught here:

```text
BEGIN
→ no transaction timestamp yet
```

The timestamp is assigned during:

```text
VALIDATION
```

---

## Mistake 3: Assuming physical order equals logical order

Incorrect:

```text
T1 starts first
→ T1 must logically be first
```

Not necessarily.

OCC can produce:

```text
T1 physically starts first
T2 validates first

Logical order:
T2 → T1
```

---

## Mistake 4: Confusing read set and write set

Remember:

```text
Read set = objects I read

Write set = objects I modify
```

---

## Mistake 5: Thinking phantom reads are just non-repeatable reads

They are different.

```text
Non-repeatable:
same row → different value

Phantom:
same query → different matching rows
```

---

## Mistake 6: Thinking you can lock a row that does not exist

You cannot directly lock a nonexistent row.

Instead, the DBMS can lock:

```text
the gap
```

or:

```text
the key range
```

containing the potential new row.

---

## Mistake 7: Confusing locks with latches

```text
Lock = logical transaction correctness

Latch = physical data-structure correctness
```

---

## Mistake 8: Assuming Serializable is the default everywhere

Most major systems do not default to Serializable.

Defaults depend on the DBMS.

---

## Mistake 9: Assuming MVCC = OCC

MVCC is a version-management technique.

OCC is a concurrency-control protocol.

They can be combined.

---

## Mistake 10: Thinking "possible anomaly" means "guaranteed anomaly"

If an isolation-level table says:

```text
Phantom → Possible
```

that means the isolation level does not prevent it.

It does **not** mean every transaction will experience a phantom.

---

# 73. Exam Review

## Must-Know Definitions

* **Concurrency control:** Techniques for coordinating concurrent transactions while preserving correctness.
* **Serializability:** Concurrent execution is equivalent to some serial transaction ordering.
* **Pessimistic concurrency control:** Assumes conflicts are likely and prevents them using mechanisms such as locks.
* **Optimistic concurrency control:** Assumes conflicts are rare and validates transactions before commit.
* **Timestamp:** A value used to establish logical transaction ordering.
* **Read set:** Objects read by a transaction.
* **Write set:** Objects modified by a transaction.
* **Validation phase:** OCC phase where the DBMS determines whether a transaction can commit.
* **Private workspace:** Transaction-local area where OCC stores reads/updates before commit.
* **Phantom read:** A repeated range/predicate query sees a different set of matching rows.
* **Predicate locking:** Locking a logical predicate/range rather than only existing rows.
* **Gap lock:** Lock protecting a gap between existing index keys.
* **Key-range lock:** Lock protecting an interval of index key values.
* **Isolation level:** Defines which transaction anomalies a DBMS permits or prevents.
* **MVCC:** Multi-Version Concurrency Control; maintains multiple versions of database objects.
* **Strict serializability:** Serializability that also respects external/real-time transaction ordering.

---

# 74. Must-Know Methods

### OCC

```text
1. Create private workspace
2. Execute transaction
3. Track read/write sets
4. Enter validation
5. Assign timestamp
6. Check conflicts
7. Abort/retry if conflict
8. Otherwise apply writes
```

### Forward Validation

```text
Transaction wants to commit
        ↓
Look at active transactions
        ↓
Compare write set with relevant read/write sets
        ↓
Conflict?
   ┌────┴────┐
  Yes       No
   ↓         ↓
 Abort      Commit
```

### Backward Validation

```text
Transaction wants to commit
        ↓
Look at transactions that committed
since this transaction began
        ↓
Did transaction miss a change?
   ┌────┴────┐
  Yes       No
   ↓         ↓
 Abort      Commit
```

### Phantom Protection

```text
Range query
    ↓
Need to prevent changes to matching set
    ↓
Choose:
  ├── Table/database lock
  ├── Re-execute scan
  ├── Predicate locking
  ├── Precision locking
  └── Index/key-range locking
```

---

# 75. Must-Know Formulas / Set Relationships

For a transaction:

```text
R(T) = Read Set
W(T) = Write Set
```

A basic conflict check often involves intersections such as:

```text
W(T1) ∩ R(T2)
```

If:

```text
W(T1) ∩ R(T2) ≠ ∅
```

then T1 modified something T2 read.

Similarly:

```text
W(T1) ∩ W(T2) ≠ ∅
```

means both transactions modify the same object.

For a simple no-conflict case:

```text
W(T1) ∩ R(T2) = ∅
```

means T1 did not modify anything T2 read.

Always apply the **specific validation conditions taught by your course** when solving a formal OCC schedule.

---

# 76. Isolation-Level Cheat Table

| Isolation Level  |  Dirty Read | Non-Repeatable Read |     Phantom |
| ---------------- | ----------: | ------------------: | ----------: |
| Read Uncommitted |  ✓ Possible |          ✓ Possible |  ✓ Possible |
| Read Committed   | ✗ Prevented |          ✓ Possible |  ✓ Possible |
| Repeatable Read  | ✗ Prevented |         ✗ Prevented |  ✓ Possible |
| Serializable     | ✗ Prevented |         ✗ Prevented | ✗ Prevented |

Memory pattern:

```text
READ UNCOMMITTED
    ↓
READ COMMITTED
    ↓
REPEATABLE READ
    ↓
SERIALIZABLE

Higher =
more protection
```

---

# 77. Final Cheat Sheet

## OCC

```text
Optimistic = assume low conflict

READ
 ↓
VALIDATE
 ↓
WRITE
```

---

## OCC Timestamp

```text
Timestamp is assigned at VALIDATION,
not necessarily at BEGIN.
```

---

## Private Workspace

```text
Global DB
   ↓
copy
   ↓
Private Workspace
   ↓
modify privately
   ↓
validate
   ↓
write to Global DB
```

---

## Read/Write Sets

```text
R(T) = things T read

W(T) = things T wrote
```

---

## Forward Validation

```text
Look FORWARD
→ active transactions
→ check whether my writes conflict
   with their reads/writes
```

---

## Backward Validation

```text
Look BACKWARD
→ already committed transactions
→ check whether I missed changes
```

### Memory trick

> **Forward = active/future**
> **Backward = committed/past**

---

## OCC Performance

```text
Low contention
→ OCC is good

High contention
→ OCC may waste lots of work
→ 2PL may be better
```

---

## Phantom

```text
Same row, different value
    = Non-repeatable read

Same query, different row set
    = Phantom read
```

---

## Phantom Protection

```text
Lock everything
        OR
Re-execute scans
        OR
Predicate/precision locking
        OR
Index/key-range/gap locking
```

---

## Gap Lock

```text
Index:

14 -------- 16
     GAP

Lock gap
→ prevents insertion such as 15
```

---

## Lock vs. Latch

```text
LOCK
→ logical transaction correctness

LATCH
→ physical in-memory structure correctness
```

---

## Isolation Levels

```text
READ UNCOMMITTED
→ weakest

READ COMMITTED
→ prevents dirty reads

REPEATABLE READ
→ prevents dirty + non-repeatable reads
→ phantoms may remain

SERIALIZABLE
→ strongest traditional level
→ no phantoms
→ execution equivalent to serial order
```

---

# 78. Big-Picture Mental Model

The entire lecture can be reduced to this:

```text
             Multiple Transactions
                      │
                      ↓
             Need Correct Ordering
                      │
          ┌───────────┴───────────┐
          │                       │
    Pessimistic              Optimistic
          │                       │
         2PL                     OCC
          │                       │
    Lock before work       Work before validation
          │                       │
    Block/conflict          Validate at commit
          │                       │
          └───────────┬───────────┘
                      ↓
              Need Serializability
                      │
                      ↓
          ┌───────────────────────┐
          │                       │
      Simple R/W             Range Queries
          │                       │
          │                  Phantom Problem
          │                       │
          │              ┌────────┴─────────┐
          │              │                  │
          │          Re-execute       Index/Predicate
          │             scan              locking
          │                                 │
          └───────────────┬─────────────────┘
                          ↓
                  Isolation Levels
                          │
          ┌───────────────┴───────────────┐
          │                               │
       Lower isolation              Serializable
          │                               │
   More concurrency               More guarantees
   More anomalies                 More overhead
```

## The Most Important Things to Remember

1. **OCC is optimistic:** execute first, validate later.
2. **2PL is pessimistic:** acquire locks before accessing protected data.
3. **OCC uses private workspaces** so uncommitted changes are hidden.
4. **OCC has three phases:** Read → Validate → Write.
5. **The OCC timestamp in this lecture is assigned during validation.**
6. **Physical execution order does not have to equal logical serialization order.**
7. **Forward validation checks active transactions.**
8. **Backward validation checks previously committed transactions and is generally easier to implement.**
9. **OCC is best when contention is low.**
10. **High contention can cause OCC to waste a lot of work.**
11. **A phantom read concerns a changing set/range of rows, not just a changing value in one row.**
12. **You cannot directly lock a row that does not exist.**
13. **Gap locks and key-range locks allow the DBMS to protect nonexistent values.**
14. **Indexes are useful for efficient phantom protection because they organize key ranges.**
15. **Logical locks and physical latches are different mechanisms.**
16. **Isolation levels trade correctness guarantees for concurrency/performance.**
17. **Serializable provides the strongest traditional isolation guarantee.**
18. **Most database systems do not use Serializable as their default isolation level.**
19. **MVCC maintains multiple versions and can be combined with 2PL or OCC.**
20. **Always distinguish:**

* dirty read
* non-repeatable read
* lost update
* phantom read

### One-sentence memory trick

> **2PL prevents conflicts before they happen; OCC lets transactions work independently and checks for conflicts afterward; phantom protection extends this idea from individual rows to ranges of rows.**
