# Two-Phase Locking, Deadlocks, Hierarchical Locking, and Query Optimizer Cardinality Estimates

## 1. Concurrency Control and Serializability

### Definition

**Concurrency control** is the set of techniques a database system uses to allow multiple transactions to execute concurrently while maintaining correctness.

The previous lecture focused on **ACID**, especially:

* **Atomicity** — a transaction happens completely or not at all.
* **Consistency** — transactions preserve database constraints.
* **Isolation** — concurrent transactions should behave according to the isolation/serializability guarantees provided.
* **Durability** — committed changes survive failures.

This lecture focuses heavily on **isolation** and how database systems enforce serializable execution when the system does **not know the complete transaction schedule ahead of time**.

### Conflict Serializability

A schedule is **conflict serializable** if its conflicting operations can be rearranged into a serial schedule without changing the result.

A common way to test this is with a **precedence/dependency graph**.

#### Conflict-serializability test

1. Create one node for each transaction.
2. Add an edge `Ti → Tj` when:

   * `Ti` performs an operation before `Tj`,
   * the operations conflict,
   * and both operate on the same object.
3. Look for cycles.

```text
No cycle
   ↓
Conflict serializable

Cycle
   ↓
Not conflict serializable
```

### View Serializability

**View serializability** is a more general notion of serializability.

It allows some schedules that conflict serializability rejects, provided the schedule has the same relevant read/write behavior as some serial schedule.

The important distinction is that view serializability can require understanding the **meaning of the data and operations in the application**.

A database system cannot necessarily determine that meaning just by looking at:

```text
READ(A)
WRITE(A)
```

It may need to understand the application's semantics.

### Important Comparison

| Concept                  | Main idea                                                      | Automatically determined from reads/writes? |
| ------------------------ | -------------------------------------------------------------- | ------------------------------------------- |
| Conflict serializability | Based on conflicting operations                                | Yes                                         |
| View serializability     | Based on equivalent read/write views and application semantics | Much harder                                 |
| Serial schedule          | Transactions execute one after another                         | Yes                                         |

### Key Point

The course focuses primarily on **conflict serializability** because it can be checked and enforced using database-system mechanisms.

---

# 2. Static vs. Dynamic Transaction Schedules

### Static Schedule

A **static schedule** is one where the database knows all of the operations a transaction will perform ahead of time.

For example:

```text
T1:
READ(A)
WRITE(A)
READ(B)

T2:
READ(A)
WRITE(A)
```

The entire schedule can be examined beforehand.

### Dynamic Schedule

Real database systems generally cannot assume that they know every operation a transaction will perform.

A transaction may do:

```text
BEGIN

SELECT ...

-- application decides what to do next

UPDATE ...

-- application makes another decision

SELECT ...

COMMIT
```

The database therefore has to enforce correctness **while the transaction is running**.

### Why This Matters

The database needs a mechanism that can enforce serializability even when:

* transactions start at different times,
* queries arrive dynamically,
* future operations are unknown,
* transactions interleave unpredictably.

The solution introduced in this lecture is **locking**.

---

# 3. Locks vs. Latches

Locks and latches are related concepts, but they operate at different levels.

### Locks

**Locks** protect higher-level database objects and are associated with transactions.

Examples include:

* databases
* tables
* pages
* tuples/rows
* attributes/columns

Transactions may hold locks for a significant portion of their lifetime.

### Latches

**Latches** protect in-memory data structures and are generally held for a very short period.

They were previously discussed in the context of:

* indexes
* B+ trees
* buffer pool structures
* individual pages/nodes

### Comparison

| Property          | Lock                           | Latch                                          |
| ----------------- | ------------------------------ | ---------------------------------------------- |
| Protects          | Database objects               | In-memory data structures                      |
| Associated with   | Transactions                   | Threads/operations                             |
| Typical duration  | Potentially entire transaction | Very short                                     |
| Used for          | Transaction concurrency        | Internal DBMS concurrency                      |
| Deadlock handling | Detection/prevention protocols | Usually avoided through careful implementation |
| Managed by        | Lock manager                   | Embedded in protected structure                |

### Important Mental Model

```text
Database transaction
        │
        ▼
      LOCK
        │
        ▼
Table / Page / Tuple / etc.


DBMS internal operation
        │
        ▼
     LATCH
        │
        ▼
Memory structure / index node / page
```

### Lock Manager

Locks are managed by a centralized **lock manager**.

The lock manager tracks:

* which transactions hold which locks,
* which transactions are waiting,
* which lock requests are compatible,
* queues of transactions waiting for locks.

Conceptually:

```text
                 Lock Manager
                      │
       ┌──────────────┼──────────────┐
       ▼              ▼              ▼
     Lock A         Lock B         Lock C
       │              │              │
      T1             T2             T3
       │
    T4 waiting
```

The lock manager therefore provides the DBMS with a global view of transaction lock dependencies.

---

# 4. Basic Lock Types

The two fundamental lock modes introduced are:

1. **Shared lock (S)**
2. **Exclusive lock (X)**

They are analogous to read/write modes for latches, but database locking uses the terminology **shared** and **exclusive**.

## Shared Lock

A **shared lock** allows a transaction to read an object.

Multiple transactions can hold shared locks on the same object simultaneously.

```text
T1: S(A) ✓
T2: S(A) ✓
T3: S(A) ✓
```

## Exclusive Lock

An **exclusive lock** allows a transaction to modify an object.

No other shared or exclusive lock can coexist with an exclusive lock.

```text
T1: X(A) ✓

T2: S(A) ✗
T3: S(A) ✗
T4: X(A) ✗
```

## Basic Compatibility Matrix

| Requested / Existing |  S |  X |
| -------------------- | -: | -: |
| **S**                |  ✓ |  ✗ |
| **X**                |  ✗ |  ✗ |

### Important Rule

> Shared + Shared = compatible
> Shared + Exclusive = incompatible
> Exclusive + Exclusive = incompatible

---

# 5. Lock Acquisition and Release

Before a transaction reads or writes a protected object, it must obtain the appropriate lock.

Conceptually:

```text
Request lock
     ↓
Lock Manager
     ↓
Compatible?
  ↙       ↘
YES       NO
 ↓         ↓
Grant    Wait
 ↓
Perform operation
```

If another transaction currently holds an incompatible lock, the requesting transaction must wait.

### Example

Suppose:

```text
T1:
X(A)
READ(A)
WRITE(A)

T2:
X(A)
WRITE(A)
```

Execution:

```text
T1 → requests X(A)
   → granted

T1 → READ(A)
T1 → WRITE(A)

T2 → requests X(A)
   → denied because T1 owns X(A)
   → T2 waits

T1 → releases/commits

Lock manager → grants X(A) to T2

T2 → WRITE(A)
```

### Lock Upgrades

A transaction may initially obtain:

```text
S(A)
```

and later request:

```text
S(A) → X(A)
```

This is called a **lock upgrade**.

The lock manager must determine whether the upgrade is safe.

For example, if:

```text
T1: S(A)
T2: S(A)
```

T1 cannot immediately upgrade to `X(A)` because T2 still holds a shared lock.

---

# 6. Why Locks Alone Are Not Enough

Simply having locks does **not** automatically guarantee serializability.

Consider:

```text
T1:
X(A)
READ(A)
WRITE(A)
UNLOCK(A)

T2:
X(A)
WRITE(A)
UNLOCK(A)

T1:
S(A)
READ(A)
```

Possible execution:

```text
T1 locks A
T1 reads A
T1 writes A
T1 unlocks A

T2 locks A
T2 writes A
T2 unlocks A

T1 locks A again
T1 reads A
```

T1 sees a different value when it reads `A` the second time.

This is a **non-repeatable read**.

### Why?

T1 released the lock and then later reacquired it.

Therefore, another transaction was able to modify the object between T1's two reads.

### Key Lesson

> Locks need a protocol that determines **when transactions are allowed to acquire and release them**.

That protocol is **Two-Phase Locking (2PL)**.

---

# 7. Two-Phase Locking (2PL)

### Definition

**Two-Phase Locking (2PL)** is a locking protocol that guarantees **conflict serializability**.

It divides the lifetime of a transaction into two phases:

1. **Growing phase**
2. **Shrinking phase**

---

## Growing Phase

During the growing phase, a transaction may:

* acquire locks,
* upgrade locks.

It may not release locks.

```text
Acquire
Acquire
Acquire
Acquire
```

The transaction is "growing" its collection of locks.

---

## Shrinking Phase

Once a transaction releases its first lock, it enters the shrinking phase.

During the shrinking phase:

* locks may be released,
* new locks may **not** be acquired.

```text
Release
Release
Release
```

### Critical Rule

> **The first lock release permanently ends the growing phase.**

You cannot do:

```text
Acquire
Acquire
Release
Acquire   ← NOT ALLOWED
```

Correct 2PL behavior:

```text
Acquire
Acquire
Acquire
Release
Release
Release
```

### Visual Model

```text
Number
of
Locks
 ^
 |              /\
 |             /  \
 |            /    \
 |           /      \
 |          /        \
 |_________/__________\______> Time
          Growing     Shrinking
             ↑
        First release
```

More accurately, after the first release the number of held locks can only decrease.

---

# 8. 2PL Solving Strategy

When analyzing a schedule:

### Step 1: Track every lock

Write down which locks each transaction currently holds.

### Step 2: Identify the phase

Each transaction independently has a phase:

```text
Growing → Shrinking
```

### Step 3: Watch for the first release

The first `UNLOCK` is the critical transition.

### Step 4: Check later lock requests

After a transaction releases any lock:

```text
NEW LOCK REQUEST = VIOLATION
```

### Step 5: Check serializability

If the schedule follows 2PL, the resulting schedule is guaranteed to be **conflict serializable**.

---

# 9. 2PL Fixes the Non-Repeatable Read Example

Previously:

```text
T1:
X(A)
READ(A)
WRITE(A)
UNLOCK(A)
...
S(A)
READ(A)
```

Under 2PL:

```text
T1:
X(A)
READ(A)
WRITE(A)
...
S(A)  ← cannot acquire new lock after releasing
```

More importantly, T1 would simply keep its lock on `A` until it is finished using it.

Therefore:

```text
T1 locks A
     ↓
T2 requests A
     ↓
T2 waits
     ↓
T1 finishes
     ↓
T1 releases A
     ↓
T2 gets A
```

This prevents T2 from modifying `A` between T1's operations.

---

# 10. Cascading Aborts

Although basic 2PL guarantees conflict serializability, it can still allow **cascading aborts**.

### Definition

A **cascading abort** occurs when one transaction aborts and causes other transactions that depended on its uncommitted changes to also abort.

### Example

```text
T1:
X(A)
WRITE(A)
UNLOCK(A)

T2:
X(A)
READ(A)
WRITE(A)

T1:
ABORT
```

T2 read a value produced by T1 before T1 committed.

Therefore, T2 depended on an uncommitted transaction.

If T1 aborts:

```text
T1 aborts
   ↓
T1's changes are undone
   ↓
T2 used those changes
   ↓
T2 must also abort
```

This can continue through many transactions.

```text
T1
 ↓
T2
 ↓
T3
 ↓
T4
 ↓
T5
```

If T1 aborts, potentially all of them must roll back.

### Why This Is Bad

Cascading aborts can waste:

* CPU time
* I/O
* transaction work
* locks
* system resources

A large transaction dependency chain can cause enormous amounts of wasted work.

---

# 11. Strong/Strict Two-Phase Locking

The lecture distinguishes stronger forms of 2PL that restrict when locks can be released.

### Strong Strict 2PL

Under **strong strict 2PL**, transactions hold their locks until commit/abort.

Conceptually:

```text
BEGIN
  ↓
Acquire locks
  ↓
Read / Write
  ↓
Acquire more locks
  ↓
COMMIT
  ↓
Release all locks
```

There is effectively no meaningful shrinking period until the transaction finishes.

### Why It Prevents Cascading Aborts

Suppose T1 modifies `A`.

Under strong strict 2PL:

```text
T1:
X(A)
WRITE(A)

T2:
S(A) → WAIT
```

T2 cannot read T1's uncommitted value.

Only after:

```text
T1 COMMIT
```

does T2 get access.

Therefore:

```text
No dirty read
        ↓
No dependency on uncommitted data
        ↓
No cascading abort
```

### Strong Strict 2PL and Recovery

Strong strict 2PL also simplifies rollback.

If an aborted transaction's changes were never exposed to other transactions, the DBMS does not have to chase a dependency chain of transactions that consumed those values.

---

# 12. Strict 2PL vs. Strong/Rigorous 2PL

The lecture distinguishes stronger and weaker variants.

### Important clarification

The lecturer explicitly expressed uncertainty about the exact ordering/terminology of **strict vs. strong strict vs. rigorous 2PL** and said the textbook terminology should be followed.

The key distinction taught was:

| Protocol            | Lock behavior                                                   |
| ------------------- | --------------------------------------------------------------- |
| Basic 2PL           | Locks can be released during shrinking phase                    |
| Strict 2PL          | Exclusive/write locks are retained until commit/abort           |
| Strong/Rigorous 2PL | Both shared and exclusive locks are retained until commit/abort |

The important concept for this lecture is:

> **Holding locks until commit prevents other transactions from observing uncommitted changes.**

For exam terminology, use the definitions provided by the course textbook if they differ from this lecture's wording.

---

# 13. Serializability vs. Cascading Aborts

These are different problems.

| Problem             | What it means                                                       |
| ------------------- | ------------------------------------------------------------------- |
| Non-repeatable read | A transaction reads the same object twice and gets different values |
| Dirty read          | A transaction reads another transaction's uncommitted data          |
| Loss of update      | Concurrent updates overwrite each other incorrectly                 |
| Cascading abort     | One transaction's abort forces dependent transactions to abort      |
| Deadlock            | Transactions wait forever for each other's locks                    |

### Key distinction

**2PL solves conflict serializability.**

**Strong/strict variants address exposure to uncommitted data and cascading aborts.**

**Deadlock handling is a separate issue.**

---

# 14. Pessimistic Concurrency Control

2PL is a **pessimistic** concurrency-control protocol.

### Meaning

The system assumes that conflicts may happen and therefore prevents them ahead of time using locks.

```text
Potential conflict
       ↓
Acquire lock
       ↓
Wait if necessary
       ↓
Perform operation
```

This can reduce parallelism because transactions may wait even when their operations could theoretically have completed safely.

### Trade-off

```text
More locking
    ↓
More safety / predictability
    ↓
Potentially less parallelism
```

The lecture emphasizes that transactional systems often choose correctness over maximum performance.

---

# 15. Deadlocks

### Definition

A **deadlock** occurs when transactions wait for each other in a cycle.

Example:

```text
T1 holds A
T2 holds B

T1 wants B
T2 wants A
```

Therefore:

```text
T1 ──waits for──> T2
 ^                 |
 |                 |
 └──── waits ──────┘
```

Neither transaction can proceed.

### Classic Example

```text
T1:
X(A)

T2:
S(B)

T2:
S(A) → waits for T1

T1:
S(B) → waits for T2
```

Result:

```text
T1 → T2 → T1
```

Cycle = deadlock.

---

# 16. Deadlock Detection

### Definition

**Deadlock detection** periodically examines the system for cycles in transaction dependencies.

The lock manager maintains a **wait-for graph**.

### Wait-For Graph

Each node represents a transaction.

An edge:

```text
Ti → Tj
```

means:

> Ti is waiting for a lock currently held by Tj.

### Example

```text
T2 wants C
T3 holds C

T2 → T3
```

If:

```text
T2 → T3
T3 → T1
T1 → T2
```

then:

```text
T2 → T3 → T1 → T2
```

There is a cycle, so there is a deadlock.

---

# 17. Deadlock Detection Trade-Off

The system must decide how frequently to run cycle detection.

### Too Frequently

```text
Check every millisecond
```

Problem:

* expensive,
* consumes CPU,
* resources are spent detecting deadlocks instead of executing transactions.

### Too Infrequently

```text
Check every 5 minutes
```

Problem:

* deadlocked transactions may wait for several minutes,
* resources remain tied up,
* latency becomes very high.

### Trade-off

```text
Frequent detection
        ↕
Detection cost

Infrequent detection
        ↕
Longer deadlock duration
```

Database systems can tune this behavior according to workload.

---

# 18. Deadlock Victims

Once a deadlock is detected, the DBMS must choose a **victim transaction** to abort.

Aborting one transaction breaks the cycle.

### Possible Victim Selection Factors

The system may consider:

* transaction age,
* amount of work already completed,
* number of records modified,
* number of locks held,
* amount of data processed,
* number of other transactions dependent on it,
* rollback cost.

### Example

Suppose:

```text
T1 modified 1 billion records
T2 modified 1 record
```

If either can be aborted, it may be cheaper to abort T2 because undoing T1 would be much more expensive.

### Important Principle

> The best victim is not necessarily simply the newest or oldest transaction; the DBMS can consider the cost of aborting it.

---

# 19. Transaction Rollback and Savepoints

A deadlock victim does not necessarily have to roll back the entire transaction.

### Savepoint

A **savepoint** is a checkpoint inside a transaction.

Example:

```sql
BEGIN;

UPDATE ...;

SAVEPOINT sp1;

UPDATE ...;

-- Something goes wrong

ROLLBACK TO SAVEPOINT sp1;

COMMIT;
```

Conceptually:

```text
BEGIN
  ↓
Work 1
  ↓
SAVEPOINT
  ↓
Work 2
  ↓
Problem
  ↓
ROLLBACK TO SAVEPOINT
  ↓
Continue
```

Instead of undoing the entire transaction, the DBMS can potentially roll back only part of its work.

### Important

Savepoints are generally established by the application/transaction logic rather than automatically chosen at arbitrary points.

---

# 20. Deadlock Prevention

Instead of detecting deadlocks after they occur, **deadlock prevention** attempts to ensure that deadlocks cannot form.

The DBMS uses transaction priorities, usually based on **timestamps**.

Suppose:

```text
T1 timestamp = 1
T2 timestamp = 2
```

Then:

```text
T1 = older
T2 = younger
```

Two important protocols are:

* **Wait-Die**
* **Wound-Wait**

---

# 21. Wait-Die

### Rule

**Older waits for younger.**

If the requesting transaction is older:

```text
Older requests lock held by younger
        ↓
Older waits
```

If the requesting transaction is younger:

```text
Younger requests lock held by older
        ↓
Younger aborts ("dies")
```

### Memory Trick

> **Wait-Die = Old waits, Young dies.**

### Example

```text
T1 = old
T2 = young

T2 holds A

T1 requests A
```

T1 is older, so:

```text
T1 waits
```

But:

```text
T1 holds A

T2 requests A
```

T2 is younger, so:

```text
T2 aborts
```

---

# 22. Wound-Wait

### Rule

**Older wounds younger. Younger waits for older.**

If the requesting transaction is older:

```text
Older requests lock held by younger
        ↓
Abort younger
```

If the requesting transaction is younger:

```text
Younger requests lock held by older
        ↓
Younger waits
```

### Memory Trick

> **Wound-Wait = Old wounds young; young waits.**

### Example

```text
T1 = old
T2 = young

T2 holds A

T1 requests A
```

T1 is older:

```text
T1 "wounds" T2
T2 aborts
T1 gets A
```

But:

```text
T1 holds A

T2 requests A
```

T2 is younger:

```text
T2 waits
```

---

# 23. Wait-Die vs. Wound-Wait

| Protocol       | Older requests younger's lock | Younger requests older's lock |
| -------------- | ----------------------------- | ----------------------------- |
| **Wait-Die**   | Older waits                   | Younger aborts                |
| **Wound-Wait** | Younger aborts                | Younger waits                 |

### Memory

```text
WAIT-DIE
Old → WAIT
Young → DIE


WOUND-WAIT
Old → WOUND
Young → WAIT
```

### Why They Prevent Deadlocks

Both protocols impose an ordering on who can wait.

Waiting cannot form an arbitrary cycle because transactions can only wait according to the timestamp ordering.

Therefore:

```text
Ordered waiting
      ↓
No circular wait
      ↓
No deadlock
```

---

# 24. Transaction Restart and Starvation

When an aborted transaction restarts, it keeps its **original timestamp/priority**.

Why?

Suppose a transaction repeatedly loses conflicts:

```text
T1 starts
↓
aborts
↓
restarts
↓
aborts
↓
restarts
```

If it received a completely new timestamp every time, it could continually be treated as a young transaction.

Keeping its original timestamp eventually makes it old enough to receive priority.

This helps prevent **starvation**.

---

# 25. Lock Granularity

A major problem with one-lock-per-object is scalability.

Suppose a transaction wants to update:

```text
1 billion tuples
```

If the DBMS requires:

```text
1 billion tuple locks
```

the lock manager itself becomes expensive.

The DBMS therefore supports different **lock granularities**.

### Possible Levels

```text
Database
   ↓
Table
   ↓
Page
   ↓
Tuple / Row
   ↓
Attribute / Column
```

### Fine-Grained Locking

Example:

```text
Lock 3 individual rows
```

Advantages:

* high concurrency,
* unrelated transactions can operate elsewhere.

Disadvantages:

* many locks,
* more lock-manager overhead,
* more metadata.

### Coarse-Grained Locking

Example:

```text
Lock entire table
```

Advantages:

* fewer locks,
* less lock-management overhead.

Disadvantages:

* reduces concurrency,
* blocks more transactions than necessary.

---

# 26. Lock Granularity Trade-Off

| Fine-grained                 | Coarse-grained                |
| ---------------------------- | ----------------------------- |
| More locks                   | Fewer locks                   |
| Higher concurrency           | Lower concurrency             |
| More metadata                | Less metadata                 |
| More lock-manager operations | Fewer lock-manager operations |
| More complicated             | Simpler                       |

### General Principle

> Use the smallest number of locks necessary while preserving enough concurrency.

The optimal choice depends on the workload.

---

# 27. Lock Hierarchies

A **lock hierarchy** organizes database objects into a tree.

Example:

```text
Database
   │
   ├── Table A
   │      ├── Page 1
   │      │     ├── Tuple 1
   │      │     └── Tuple 2
   │      └── Page 2
   │
   └── Table B
```

A lock at a higher level can implicitly cover objects below it.

For example:

```text
X(Table A)
```

effectively protects the objects within Table A.

This avoids acquiring potentially millions or billions of individual tuple locks.

---

# 28. Intention Locks

Once hierarchical locking exists, the DBMS needs a way to communicate:

> "I am going to acquire locks somewhere below this object."

This is the purpose of **intention locks**.

They provide information about locks that will exist lower in the hierarchy.

The three basic intention-related modes discussed are:

* **IS — Intention Shared**
* **IX — Intention Exclusive**
* **SIX — Shared + Intention Exclusive**

---

# 29. Intention Shared (IS)

**IS** means:

> "Somewhere below this object, I intend to acquire shared locks."

Example:

```text
IS(Table)
   ↓
S(Tuple)
```

The table-level IS lock tells other transactions that shared locking will occur somewhere below.

---

# 30. Intention Exclusive (IX)

**IX** means:

> "Somewhere below this object, I intend to acquire exclusive locks."

Example:

```text
IX(Table)
   ↓
X(Tuple)
```

The table itself is not necessarily exclusively locked.

Only some lower-level objects may be.

---

# 31. Shared Intention Exclusive (SIX)

**SIX** combines shared and intention-exclusive behavior.

Conceptually:

> "I am taking a shared lock at this level, and I may take exclusive locks on some objects below it."

Example:

```text
SIX(Table)
   │
   ├── S(Tuple 1)
   ├── S(Tuple 2)
   ├── S(Tuple 3)
   └── X(Tuple 4)
```

This is useful when a transaction wants to read a large portion of a table but modify a smaller portion.

---

# 32. Intention Lock Compatibility

The compatibility matrix becomes more complicated when intention locks are introduced.

The fundamental idea is:

```text
X
↓
blocks everything incompatible with exclusive access

IS
↓
generally compatible with other intention locks

IX
↓
signals exclusive activity below

SIX
↓
combines shared access with intention-exclusive access below
```

### Core Principle

Intention locks are primarily **signals/hints about lower-level locks**.

They prevent another transaction from incorrectly assuming that a higher-level lock is safe to acquire without considering locks lower in the hierarchy.

---

# 33. Hierarchical Locking Example: Read One Tuple

Suppose:

```text
T1 wants to read Tuple 1.
```

Instead of taking an S lock on the entire table:

```text
S(Table)
```

T1 can do:

```text
IS(Table)
   ↓
S(Tuple 1)
```

This allows another transaction to work on a different tuple.

---

# 34. Hierarchical Locking Example: Update One Tuple

Suppose:

```text
T2 wants to modify Tuple 2.
```

T2 can use:

```text
IX(Table)
   ↓
X(Tuple 2)
```

Meanwhile:

```text
T1:
IS(Table)
S(Tuple 1)
```

can coexist with T2.

Therefore:

```text
T1 → reading Tuple 1
T2 → modifying Tuple 2
```

can execute concurrently.

---

# 35. SIX Example

Suppose T1 wants to:

* read every tuple,
* update only one tuple.

Using individual locks for every tuple would be expensive.

Instead:

```text
T1:
SIX(Table)
   │
   ├── S(Tuple 1)
   ├── S(Tuple 2)
   ├── S(Tuple 3)
   └── X(Tuple 4)
```

The shared portion is represented by the table-level shared lock, while the specific modification is represented by an explicit exclusive lock.

### Why SIX?

Because T1 is doing both:

```text
READ lots of data
+
WRITE some data
```

---

# 36. Hierarchical Locking Example with Three Transactions

Suppose:

* T1 scans all tuples and updates one.
* T2 reads one tuple.
* T3 reads all tuples.

### T1

T1 can take:

```text
SIX(R)
   ↓
X(Tuple)
```

This communicates:

> "I am reading the table and will exclusively modify one tuple."

### T2

T2 only wants to read one tuple:

```text
IS(R)
   ↓
S(Tuple)
```

This can coexist with T1's hierarchy locks when the specific tuples are compatible.

### T3

T3 wants to read the entire table.

Rather than obtaining a shared lock on every tuple:

```text
S(R)
```

is more efficient.

However, T3's table-level S lock conflicts with T1's SIX lock.

Therefore:

```text
T3 → waits
```

until T1 commits/releases its locks.

---

# 37. When to Use Coarser Locks

A transaction may start acquiring fine-grained locks and realize:

> "There are far too many objects to lock individually."

It can potentially move toward a coarser lock.

For example:

```text
IS(Table)
 ↓
S(Tuple 1)
S(Tuple 2)
S(Tuple 3)
...
```

If the transaction discovers there are billions of tuples, a table-level lock may be more efficient.

---

# 38. Database Examples Mentioned

The lecture briefly discussed how different database systems use different locking granularities.

Examples mentioned include:

* MySQL
* PostgreSQL
* Oracle
* SQLite
* MongoDB
* Yugabyte

### MongoDB

The lecture noted that early MongoDB versions used database-level locking.

### SQLite

The lecture described SQLite as allowing multiple readers but restricting writers, with a coarse-grained locking model.

### Yugabyte

The lecture mentioned Yugabyte as an example of a system supporting very fine-grained/attribute-level locking.

### Important

These systems have different implementations and lock modes. The lecture's goal was to illustrate that **lock granularity and lock types vary between database systems**.

---

# 39. SQL and Explicit Locking

Normally, application code does not manually write:

```text
LOCK(A)
READ(A)
UNLOCK(A)
```

Instead, the DBMS determines what locks are needed from the SQL statement and transaction context.

For example:

```sql
SELECT *
FROM accounts
WHERE id = 1;
```

The DBMS handles the necessary locking according to the transaction's isolation and locking implementation.

### Important

The exact locking behavior depends on the database system and isolation level.

---

# 40. `FOR UPDATE`

A common SQL locking hint is:

```sql
SELECT *
FROM accounts
WHERE id = 1
FOR UPDATE;
```

### Meaning

Conceptually:

> "I am reading this row because I intend to modify it."

Instead of initially taking a shared lock and later trying to upgrade it, the DBMS can acquire the appropriate exclusive/update-oriented lock immediately.

### Typical Read-Modify-Write Pattern

Without a locking hint:

```text
SELECT
 ↓
S lock
 ↓
Application decides to update
 ↓
Upgrade to X
 ↓
UPDATE
```

With `FOR UPDATE`:

```text
SELECT ... FOR UPDATE
 ↓
Appropriate write-oriented lock
 ↓
UPDATE
```

This can avoid unnecessary lock upgrades and reduce certain concurrency problems.

### Common Use Case

```sql
BEGIN;

SELECT balance
FROM accounts
WHERE id = 1
FOR UPDATE;

UPDATE accounts
SET balance = balance - 100
WHERE id = 1;

COMMIT;
```

The row is read with the intention that it will be modified.

---

# 41. `SKIP LOCKED`

Another useful database feature is:

```sql
SELECT *
FROM jobs
WHERE status = 'ready'
FOR UPDATE SKIP LOCKED;
```

Conceptually:

> If a row cannot be locked because another transaction currently holds the necessary lock, skip that row instead of waiting.

### Why This Is Useful

A common use case is a **work queue**.

Imagine:

```text
Jobs:
1
2
3
4
5
```

Workers independently pull jobs.

If:

```text
Worker 1 → Job 1
Worker 2 → Job 2
```

then another worker does not necessarily need to wait for Job 1.

It can skip locked jobs and obtain another available job.

### Important Trade-Off

The same query can return different results at different times.

Therefore:

> `SKIP LOCKED` is useful when missing temporarily locked rows is acceptable.

It should not generally be used when the application requires a complete, consistent result set.

---

# 42. `FOR UPDATE` vs. `SKIP LOCKED`

| Feature          | `FOR UPDATE`                          | `SKIP LOCKED`                 |
| ---------------- | ------------------------------------- | ----------------------------- |
| Main purpose     | Lock rows for later modification      | Avoid waiting for locked rows |
| Locked row       | Wait/lock according to DBMS semantics | Skip unavailable row          |
| Common use       | Read-modify-write                     | Work queues                   |
| Result stability | More restrictive                      | Can vary between executions   |

---

# 43. Overall Concurrency-Control Picture

The lecture's concurrency-control concepts fit together like this:

```text
Need concurrent transactions
          ↓
Need isolation / serializability
          ↓
Transactions are dynamic
          ↓
Use locks
          ↓
Two-Phase Locking
          ↓
Conflict serializability
          │
          ├───────────────┐
          ↓               ↓
Cascading aborts       Deadlocks
          ↓               ↓
Strong/strict 2PL     Detection /
                      Prevention
                          ↓
                  Wait-Die /
                  Wound-Wait
                          ↓
                  Lock hierarchy
                          ↓
                 Intention locks
```

---

# 44. Firebolt Industry Talk: Query Optimizers

The final part of the lecture transitioned to an industry talk about **query planners/optimizers** and especially **cardinality estimates**.

The central message was:

> A query optimizer can produce enormous performance improvements, but incorrect estimates can also make query performance unpredictable.

---

# 45. Firebolt Workload Characteristics

Firebolt was described as an:

* analytical database,
* scale-out system,
* PostgreSQL-compatible system,
* system operating on terabytes to petabytes of data.

The workloads discussed have:

* very large datasets,
* high concurrency,
* latency-sensitive queries,
* predictable/repetitive query patterns,
* mission-critical applications.

Example:

```text
Same dashboard
      ↓
Many customers
      ↓
Same query patterns repeated many times
      ↓
Predictable query performance is important
```

---

# 46. What Can Make Query Performance Unpredictable?

The talk considered several possibilities.

### 1. More Data

Maybe ingestion increases dramatically.

However, production systems often carefully control ingestion rates.

### 2. Query Patterns Change

Traditional production workloads may have highly repetitive query patterns.

### 3. Load Spikes

A sudden increase in users can create a workload spike.

Potential solutions include:

* queueing,
* autoscaling,
* provisioning additional compute.

### 4. Overengineering

The speaker's major concern was that a sophisticated optimization feature may improve many queries but make performance unpredictable in certain cases.

This is particularly important for query optimizers.

---

# 47. Query Optimizers Have Huge Potential

A good query plan can sometimes produce:

```text
100× improvement
```

or even:

```text
1000× improvement
```

compared with a poor plan.

Therefore, query optimization can have a much larger impact than simply making the execution engine faster.

However:

```text
More optimizer power
        ↓
More potential benefit
        +
More potential harm when wrong
```

---

# 48. Cardinality Estimates

### Definition

**Cardinality** is the number of rows produced by an operation.

A **cardinality estimate** is the optimizer's prediction of how many rows an operation will produce.

For example:

```sql
SELECT *
FROM Events
WHERE tracker = 'RB080';
```

The optimizer may need to estimate:

```text
How many rows will satisfy tracker = 'RB080'?
```

It might estimate:

```text
70,000 rows
```

even though the actual result might be very different.

---

# 49. Why Cardinality Estimates Matter

The optimizer uses cardinality estimates to make decisions such as:

* join order,
* join algorithms,
* build side of a hash join,
* aggregation strategy,
* execution plan selection.

If the estimate is wrong:

```text
Bad estimate
    ↓
Bad cost calculation
    ↓
Bad plan
    ↓
Poor performance
```

---

# 50. Firebolt's Optimizer

The speaker described Firebolt's optimizer as:

* PostgreSQL-compatible at the SQL dialect level,
* built from scratch in C++,
* not containing PostgreSQL's actual optimizer code.

It includes more than 170 rule-based optimization rules, including examples such as:

* filter pushdown,
* expression optimization,
* removing redundant aggregates,
* removing redundant joins,
* eliminating redundancy in machine-generated queries.

It also uses **cost-based join reordering**.

---

# 51. Rule-Based vs. Cost-Based Optimization

### Rule-Based Optimization

Uses known transformation rules.

Examples:

```text
Push filter closer to table
Remove redundant operation
Simplify expression
Remove redundant join
```

### Cost-Based Optimization

Considers different possible plans and estimates their costs.

For example:

```text
Plan A → estimated cost 100
Plan B → estimated cost 50
Plan C → estimated cost 200

Choose Plan B
```

The lecture described Firebolt's join reordering as:

```text
Join graph
    ↓
Bottom-up optimization
    ↓
Dynamic programming
    ↓
Cost-based join ordering
```

---

# 52. Predictability vs. Perfect Optimization

One of the most important ideas from the industry talk:

> **Predictable query plans can be more valuable than finding the theoretically perfect plan.**

A system may prefer:

```text
Consistently good performance
```

over:

```text
Usually excellent performance
but occasionally terrible performance
```

### Why?

Production users need predictable behavior.

For example:

```text
Query normally → 50 ms

Occasionally → 50 seconds
```

can be much worse operationally than:

```text
Query → 100 ms consistently
```

depending on the application.

---

# 53. Giving Users Control

Because an optimizer may not always choose the desired plan, Firebolt provides users with controls to influence optimization.

The talk mentioned controls for:

* specific join ordering,
* distributed aggregation strategy,
* pre-aggregation,
* other plan choices.

This gives users a way to force predictable behavior when necessary.

---

# 54. "Avoid Cardinality Estimates at All Cost"

The speaker's stated design philosophy was essentially:

> Avoid using cardinality estimates unless the potential benefit is large enough to justify the risk.

The major exception discussed was:

### Join Ordering

Cardinality estimates can be extremely valuable for join ordering because choosing the correct join order can produce enormous performance improvements.

Therefore:

```text
Cardinality estimates
       ↓
Primarily valuable for
       ↓
Join ordering
```

But using unreliable estimates in many other optimizer decisions may introduce unnecessary unpredictability.

---

# 55. Iceberg Tables and Limited Statistics

The talk discussed **Apache Iceberg** tables.

A major challenge is that the optimizer may have much less statistical information available than it would like.

For example, it might know:

```text
Table row count = 5 billion
```

but not have detailed statistics describing the distribution of values.

This makes filtering estimates difficult.

---

# 56. Cardinality Example

Consider two tables.

### Large Events Table

```text
5 billion rows
```

### Smaller Table

```text
70,000 rows
```

The large table contains:

```text
tracker
```

and the query filters:

```sql
WHERE tracker = 'RB080'
```

The optimizer needs to estimate:

```text
How many of the 5 billion rows have tracker = 'RB080'?
```

Suppose it only knows:

```text
Events = 5 billion rows
```

and does not know the actual distribution of `tracker`.

This becomes difficult.

---

# 57. Selectivity

### Definition

**Selectivity** describes how much a predicate reduces a relation.

For example:

```sql
WHERE tracker = 'RB080'
```

If only 1% of rows satisfy it:

```text
5,000,000,000 × 0.01
=
50,000,000 rows
```

The optimizer needs a reasonable estimate of that fraction to estimate the output cardinality.

Conceptually:

```text
Input cardinality
        ×
Estimated selectivity
        =
Estimated output cardinality
```

---

# 58. The Problem with a Poor Estimate

The talk described applying a known SQL Server-style estimation formula to the example.

It produced an estimate of approximately:

```text
70,000 rows
```

for the filtered 5-billion-row table.

That is problematic because:

```text
Actual table = 5 billion rows
Estimated filtered result = 70,000 rows
```

The estimate could dramatically influence the optimizer's join decision.

---

# 59. Plan Flapping

A particularly important problem is **plan instability** or "plan flapping."

Suppose:

```text
Table A = 70,000 rows
Table B = estimated 70,000 rows
```

The optimizer may choose one table as the build side.

Then a small data change occurs:

```text
Insert a few rows into A
```

Now perhaps:

```text
A = 70,001
B = 70,000
```

The optimizer might suddenly switch the plan.

Another tiny change could switch it back.

Conceptually:

```text
Tiny data change
      ↓
Estimate changes
      ↓
Cost changes
      ↓
Different plan
      ↓
Different performance
```

This is undesirable for predictable production workloads.

---

# 60. Estimation Bounds

Firebolt described a strategy of carrying **lower and upper bounds** through the query plan.

Instead of pretending the estimate is exact:

```text
Estimated rows = 70,000
```

the optimizer can track:

```text
Lower bound ≤ actual cardinality ≤ Upper bound
```

### Example

For the base table:

```text
5 billion ≤ rows ≤ 5 billion
```

because the metadata gives the exact row count.

After filtering:

```text
0 ≤ rows ≤ 5 billion
```

The optimizer may still have an expected estimate, but it also knows the possible range.

---

# 61. Expected Estimate vs. Guaranteed Bounds

This is an important distinction.

Suppose:

```text
Expected cardinality = 70,000
```

But the guaranteed range is:

```text
0 to 5 billion
```

The optimizer can say:

```text
Expected value:
70,000

Guaranteed range:
0 ≤ cardinality ≤ 5 billion
```

This avoids treating an uncertain estimate as if it were guaranteed to be accurate.

---

# 62. Risk Minimization in Join Ordering

Firebolt described adding a **risk-minimization pass** after cost-based join ordering.

Conceptually:

```text
Query
 ↓
Cost-based join ordering
 ↓
Candidate plan
 ↓
Check cardinality bounds
 ↓
Risk minimization
 ↓
Final plan
```

If the optimizer can guarantee that one side is smaller, it can use that information to make safer decisions.

---

# 63. Build Side of a Join

For a hash join, one side is generally used as the **build side**.

The optimizer wants to choose a side that is appropriately sized.

In the example:

```text
Small table = 70,000 rows
Large table = 5 billion rows
```

A safe strategy is to put the smaller table on the build side.

The point of the Firebolt approach is:

> Even if the filter cardinality estimate is unreliable, guaranteed bounds can help the optimizer avoid obviously risky choices.

---

# 64. Cardinality Estimation Flow

```text
Base table
   ↓
Known row count
   ↓
Apply filter
   ↓
Expected cardinality
   +
Guaranteed lower/upper bounds
   ↓
Join ordering
   ↓
Cost-based candidate
   ↓
Risk minimization
   ↓
Safer query plan
```

---

# 65. Major Concepts to Connect

The lecture actually covers two major database-system areas.

## Part A: Concurrency Control

```text
Transactions
     ↓
Locks
     ↓
2PL
     ↓
Conflict serializability
     ↓
Deadlock handling
     ↓
Lock granularity
     ↓
Hierarchical locking
     ↓
Intention locks
```

## Part B: Query Optimization

```text
SQL
 ↓
Query optimizer
 ↓
Rules + cost model
 ↓
Cardinality estimates
 ↓
Join ordering
 ↓
Execution plan
```

---

# Important Comparisons

## Locks vs. Latches

| Feature           | Locks                   | Latches                     |
| ----------------- | ----------------------- | --------------------------- |
| Purpose           | Transaction concurrency | Internal DBMS concurrency   |
| Protects          | Database objects        | In-memory structures        |
| Duration          | Potentially long        | Usually very short          |
| Managed by        | Lock manager            | Data structure/DBMS code    |
| Deadlock strategy | Detection/prevention    | Generally avoided by design |

## Shared vs. Exclusive Locks

| Lock | Read                          | Write | Compatible with S? | Compatible with X? |
| ---- | ----------------------------- | ----- | ------------------ | ------------------ |
| S    | Yes                           | No    | Yes                | No                 |
| X    | Yes/No depending on operation | Yes   | No                 | No                 |

## Basic 2PL vs. Strong Strict 2PL

| Property                   | Basic 2PL               | Strong/Rigorous 2PL            |
| -------------------------- | ----------------------- | ------------------------------ |
| Growing phase              | Yes                     | Yes                            |
| Shrinking phase            | Can occur before commit | Essentially at transaction end |
| Can release locks early?   | Yes                     | No                             |
| Cascading aborts possible? | Yes                     | No                             |
| Conflict serializable?     | Yes                     | Yes                            |
| Deadlocks possible?        | Yes                     | Yes                            |

## Deadlock Detection vs. Prevention

| Detection                       | Prevention                               |
| ------------------------------- | ---------------------------------------- |
| Allows deadlock to form         | Prevents deadlock from forming           |
| Detects cycles                  | Uses transaction ordering                |
| Uses wait-for graph             | Uses timestamps/priorities               |
| Aborts a victim after detection | Decides immediately when conflict occurs |
| Requires cycle detection        | Avoids cycles by restricting waiting     |

## Wait-Die vs. Wound-Wait

|                               | Wait-Die              | Wound-Wait              |
| ----------------------------- | --------------------- | ----------------------- |
| Older requests younger's lock | Wait                  | Abort younger           |
| Younger requests older's lock | Abort                 | Wait                    |
| Memory trick                  | Old waits, young dies | Old wounds, young waits |

## Fine vs. Coarse Locking

| Fine             | Coarse                  |
| ---------------- | ----------------------- |
| More locks       | Fewer locks             |
| More concurrency | Less concurrency        |
| More metadata    | Less metadata           |
| More overhead    | Less overhead           |
| Example: tuple   | Example: table/database |

## IS vs. IX vs. SIX

| Mode | Meaning                                    |
| ---- | ------------------------------------------ |
| IS   | Intend to take S locks below               |
| IX   | Intend to take X locks below               |
| SIX  | S lock here + intend to take X locks below |

---

# Common Mistakes

* Assuming that **having locks automatically guarantees serializability**.
* Forgetting that 2PL restricts **when locks can be released**.
* Forgetting that the **first release starts the shrinking phase**.
* Acquiring a new lock after entering the shrinking phase.
* Confusing **locks** with **latches**.
* Confusing **conflict serializability** with **view serializability**.
* Assuming basic 2PL automatically prevents cascading aborts.
* Confusing **cascading aborts** with deadlocks.
* Thinking a deadlock is simply "a transaction waiting." A deadlock requires a **cycle**.
* Forgetting that deadlock prevention makes decisions when a lock request occurs.
* Mixing up Wait-Die and Wound-Wait.
* Forgetting that older transactions have higher priority in the timestamp schemes discussed.
* Assuming fine-grained locking is always better.
* Assuming coarse-grained locking is always better.
* Forgetting that intention locks communicate information about **lower levels of the hierarchy**.
* Confusing `FOR UPDATE` with `SKIP LOCKED`.
* Assuming `SKIP LOCKED` returns the same rows every time.
* Assuming cardinality estimates are guaranteed to be accurate.
* Forgetting that bad cardinality estimates can produce bad join orders.
* Treating an expected cardinality as if it were a guaranteed bound.

---

# Exam Review

## Must-Know Definitions

* **Concurrency control** — mechanisms for safely executing transactions concurrently.
* **Conflict serializability** — a schedule can be rearranged into a serial schedule while preserving conflicting operations.
* **Lock** — mechanism used to control transaction access to database objects.
* **Shared lock (S)** — permits compatible shared access, generally for reading.
* **Exclusive lock (X)** — prevents other incompatible access, generally for writing.
* **Lock manager** — centralized component tracking held and requested locks.
* **Two-Phase Locking** — locking protocol with a growing phase and shrinking phase.
* **Growing phase** — locks may be acquired, but none released.
* **Shrinking phase** — locks may be released, but no new locks acquired.
* **Cascading abort** — abort of one transaction causes dependent transactions to abort.
* **Deadlock** — circular waiting among transactions.
* **Wait-for graph** — graph showing which transactions are waiting for others.
* **Deadlock detection** — finding cycles in the wait-for graph.
* **Deadlock prevention** — preventing cycles using transaction priorities/orderings.
* **Savepoint** — checkpoint allowing partial rollback.
* **Lock granularity** — size/scope of the object protected by a lock.
* **Intention lock** — indicates that locks will be acquired at lower levels of a hierarchy.
* **Cardinality** — number of rows in a relation/result.
* **Selectivity** — degree to which a predicate filters rows.
* **Cardinality estimate** — optimizer's prediction of output row count.
* **Plan flapping** — query plan changing due to small changes in estimates/data.

---

# Must-Know Methods

## Method 1: Determine Whether a Schedule Follows 2PL

1. Track every lock acquired by each transaction.
2. Track every lock released.
3. Identify the first release by each transaction.
4. Mark that transaction as entering shrinking phase.
5. Check every subsequent lock acquisition.
6. If a new lock is acquired after the first release, the transaction violates 2PL.

---

## Method 2: Detect a Deadlock

1. Create one node for every active transaction.
2. If `Ti` waits for a lock held by `Tj`, add:

```text
Ti → Tj
```

3. Look for a cycle.
4. If a cycle exists, there is a deadlock.
5. Choose a victim transaction.
6. Abort/rollback the victim.
7. Release its locks.
8. Allow other transactions to continue.

---

## Method 3: Apply Wait-Die

Ask:

```text
Who is requesting?
Who owns the lock?
Who is older?
```

Then:

```text
Older requests younger → WAIT
Younger requests older → DIE/ABORT
```

Memory:

```text
WAIT-DIE
OLD = WAIT
YOUNG = DIE
```

---

## Method 4: Apply Wound-Wait

```text
Older requests younger → WOUND/ABORT younger
Younger requests older → WAIT
```

Memory:

```text
WOUND-WAIT
OLD = WOUND
YOUNG = WAIT
```

---

## Method 5: Choose Lock Granularity

Ask:

```text
How many objects am I accessing?
```

If very few:

```text
Tuple-level locks
```

If many:

```text
Page/table-level locks
```

Trade-off:

```text
Smaller locks
→ more concurrency
→ more overhead

Larger locks
→ less overhead
→ less concurrency
```

---

# Must-Know SQL Syntax

## Basic Transaction

```sql
BEGIN;

-- SQL operations

COMMIT;
```

Or:

```sql
BEGIN;

-- SQL operations

ROLLBACK;
```

---

## Lock a Row for Update

```sql
SELECT *
FROM accounts
WHERE id = 1
FOR UPDATE;
```

Conceptually:

```text
Read row
+
Acquire write-oriented lock
+
Prepare to modify
```

---

## Skip Locked Rows

```sql
SELECT *
FROM jobs
WHERE status = 'ready'
FOR UPDATE SKIP LOCKED;
```

Conceptually:

```text
Find eligible rows
      ↓
Try to lock
      ↓
Locked by another transaction?
      ↓
YES → skip
NO  → return it
```

---

## Savepoint

```sql
BEGIN;

UPDATE accounts
SET balance = balance - 100
WHERE id = 1;

SAVEPOINT before_second_update;

UPDATE accounts
SET balance = balance + 100
WHERE id = 2;

ROLLBACK TO SAVEPOINT before_second_update;

COMMIT;
```

---

# Must-Know Formulas / Relationships

## Cardinality Estimate

```text
Estimated output cardinality
=
Input cardinality × Estimated selectivity
```

Example:

```text
5,000,000,000 × 0.01
=
50,000,000
```

---

## Cardinality Bounds

Instead of:

```text
Estimated cardinality = 70,000
```

the optimizer may track:

```text
0 ≤ cardinality ≤ 5,000,000,000
```

while still maintaining an expected estimate.

---

# Quick Deadlock Example

```text
T1:
X(A)

T2:
X(B)

T1:
X(B) → waits for T2

T2:
X(A) → waits for T1
```

Wait-for graph:

```text
T1 ─────→ T2
 ↑         │
 │         ↓
 └─────────┘
```

Cycle:

```text
T1 → T2 → T1
```

Therefore:

```text
DEADLOCK
```

---

# Quick 2PL Example

Valid:

```text
T1:
S(A)
X(B)
X(C)
COMMIT
release A/B/C
```

Invalid under basic 2PL:

```text
T1:
S(A)
X(B)
UNLOCK(A)
X(C)    ← invalid: new lock after release
```

The moment `A` is released:

```text
Growing → Shrinking
```

---

# Quick Hierarchical Locking Example

## Read One Tuple

```text
IS(Table)
   ↓
S(Tuple)
```

## Update One Tuple

```text
IX(Table)
   ↓
X(Tuple)
```

## Read Everything and Update One Tuple

```text
SIX(Table)
   ↓
X(Tuple)
```

---

# Final Cheat Sheet / Memory Sheet

## Serializability

```text
Conflict serializable
        ↓
Precedence graph has NO cycle
```

---

## Locks

```text
S + S = compatible
S + X = incompatible
X + S = incompatible
X + X = incompatible
```

---

## 2PL

```text
GROWING
Acquire locks
Upgrade locks
       ↓
First release
       ↓
SHRINKING
Release locks
No new locks
```

**2PL → conflict serializability**

---

## Strong/Rigorous 2PL

```text
Acquire locks
      ↓
Perform transaction
      ↓
COMMIT/ABORT
      ↓
Release locks
```

Main benefit:

```text
No dirty reads
↓
No cascading aborts
```

---

## Deadlock

```text
T1 waits for T2
T2 waits for T1

→ cycle
→ deadlock
```

---

## Deadlock Detection

```text
Lock Manager
     ↓
Wait-for graph
     ↓
Cycle?
  ↙    ↘
YES    NO
 ↓      ↓
Abort  Continue
victim
```

---

## Wait-Die

```text
OLD → WAIT
YOUNG → DIE
```

## Wound-Wait

```text
OLD → WOUND
YOUNG → WAIT
```

Both prevent deadlocks through ordered waiting.

---

## Lock Granularity

```text
Database
   ↓
Table
   ↓
Page
   ↓
Tuple
   ↓
Attribute
```

```text
Fine-grained
= more concurrency
= more overhead

Coarse-grained
= less concurrency
= less overhead
```

---

## Intention Locks

```text
IS  = intention shared below
IX  = intention exclusive below
SIX = shared here + intention exclusive below
```

Examples:

```text
Read one tuple:
IS(Table) → S(Tuple)

Write one tuple:
IX(Table) → X(Tuple)

Read all + write one:
SIX(Table) → X(Tuple)
```

---

## SQL Locking

```sql
SELECT *
FROM accounts
WHERE id = 1
FOR UPDATE;
```

Means approximately:

```text
Read this row
+
I intend to modify it
+
Lock appropriately
```

```sql
SELECT *
FROM jobs
FOR UPDATE SKIP LOCKED;
```

Means:

```text
Try to lock rows
↓
If unavailable
↓
Skip them instead of waiting
```

Useful for:

```text
Work queues
```

---

## Query Optimization

```text
SQL
 ↓
Query optimizer
 ↓
Rules + cost model
 ↓
Cardinality estimates
 ↓
Join ordering
 ↓
Execution plan
```

---

## Cardinality

```text
Cardinality = number of rows
```

```text
Estimated output
=
Input rows × estimated selectivity
```

---

## Cardinality Problem

```text
Bad statistics
      ↓
Bad cardinality estimate
      ↓
Bad cost estimate
      ↓
Bad query plan
      ↓
Poor/unpredictable performance
```

---

## Firebolt Strategy

Main ideas:

```text
Predictable plans
        >
Perfect plans
```

and:

```text
Avoid cardinality estimates
when they do not provide enough benefit.
```

But:

```text
Join ordering
      ↓
Potentially huge performance impact
      ↓
Cardinality estimates can be worth the risk
```

Firebolt's additional idea:

```text
Expected estimate
       +
Guaranteed lower/upper bounds
       ↓
Risk-aware optimization
       ↓
More predictable plans
```

---

# What You Should Be Able to Answer on an Exam

### 1. What does 2PL guarantee?

**Conflict serializability.**

### 2. What happens when a transaction releases its first lock?

It enters the **shrinking phase** and cannot acquire any new locks.

### 3. Why doesn't basic 2PL completely solve all concurrency problems?

It can still allow **cascading aborts** and **deadlocks**.

### 4. What does strong/rigorous 2PL solve?

Holding locks until commit prevents transactions from observing uncommitted changes and therefore prevents cascading aborts.

### 5. How do you detect a deadlock?

Construct a **wait-for graph** and look for a **cycle**.

### 6. How does deadlock prevention work?

Use transaction priorities/timestamps to restrict which transactions may wait.

### 7. What is Wait-Die?

**Old waits; young dies.**

### 8. What is Wound-Wait?

**Old wounds; young waits.**

### 9. Why use lock hierarchies?

To avoid maintaining enormous numbers of individual locks.

### 10. What are intention locks?

Locks that communicate intended lower-level locking activity.

### 11. What does `FOR UPDATE` do?

It requests a lock appropriate for a row that the transaction intends to modify.

### 12. What does `SKIP LOCKED` do?

It skips rows that cannot currently be locked instead of waiting.

### 13. What is cardinality?

The number of rows in a relation/result.

### 14. Why are cardinality estimates important?

They influence optimizer decisions such as join ordering.

### 15. Why can bad cardinality estimates be dangerous?

They can cause poor and unpredictable query plans.

### 16. Why use cardinality bounds?

They allow the optimizer to reason about uncertainty instead of treating an uncertain estimate as exact.

---

# One-Page Mental Model

```text
                    CONCURRENCY CONTROL
                           │
                           ▼
                    Multiple Transactions
                           │
                           ▼
                         LOCKS
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
             S / X                Lock Manager
                                      │
                                      ▼
                             Two-Phase Locking
                                      │
                     ┌────────────────┴───────────────┐
                     ▼                                ▼
             Growing Phase                     Shrinking Phase
             acquire locks                     release locks
                     │                         no new locks
                     └────────────┬───────────────────┘
                                  ▼
                         Conflict Serializable
                                  │
                    ┌─────────────┴─────────────┐
                    ▼                           ▼
             Cascading Abort                 Deadlock
                    │                           │
                    ▼                           ▼
             Strong/Strict 2PL          Detection / Prevention
                                                │
                                ┌───────────────┴──────────────┐
                                ▼                              ▼
                            Wait-Die                      Wound-Wait
                                │                              │
                                └───────────────┬──────────────┘
                                                ▼
                                        Lock Hierarchy
                                                │
                                                ▼
                                         Intention Locks
                                    IS / IX / SIX


                    QUERY OPTIMIZATION
                           │
                           ▼
                     Query Planner
                           │
                 ┌─────────┴─────────┐
                 ▼                   ▼
           Rule-Based           Cost-Based
                 │                   │
                 │                   ▼
                 │            Cardinality Estimates
                 │                   │
                 │                   ▼
                 │             Join Ordering
                 │                   │
                 └─────────┬─────────┘
                           ▼
                     Query Plan
                           │
                           ▼
                   Predictable Performance
```

## Final Memory Tricks

```text
2PL:
Grow → Release → Shrink

First release = no more new locks.

S:
Shared = readers can share.

X:
Exclusive = nobody else gets an incompatible lock.

Deadlock:
Cycle in wait-for graph.

Wait-Die:
Old waits.
Young dies.

Wound-Wait:
Old wounds.
Young waits.

IS:
"I intend to share below."

IX:
"I intend to exclusively lock below."

SIX:
"Share everything here, exclusively modify some things below."

FOR UPDATE:
"I'm reading because I'm about to modify."

SKIP LOCKED:
"If I can't lock it, skip it."

Cardinality:
"How many rows?"

Selectivity:
"How much does my filter reduce the rows?"

Bad cardinality estimate:
Bad cost → bad plan → unpredictable performance.

Firebolt:
Prefer predictable plans over theoretically perfect but unstable plans.
Use cardinality estimates primarily where their potential payoff is very large, especially join ordering.
Use bounds to reason about uncertainty.
```
