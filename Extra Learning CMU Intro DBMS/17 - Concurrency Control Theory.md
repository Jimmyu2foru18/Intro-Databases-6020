# Transactions, ACID, Serializability, and Concurrency Control

## 1. Why Transactions and Concurrency Control Are Needed

### Definition

A **transaction** is a sequence of database operations that should be treated as one logical unit of work.

A transaction may contain operations such as:

* `READ(A)`
* `WRITE(A)`
* `READ(B)`
* `WRITE(B)`

A transaction eventually either:

* **COMMITs** — all of its changes become permanent.
* **ABORTs / ROLLBACKs** — its changes are undone as if the transaction never happened.

### Explanation

Earlier in the course, the database system was built from the bottom up:

```text
SQL Query
    ↓
Query Optimizer
    ↓
Query Execution Engine
    ↓
Buffer Pool / Storage Manager
    ↓
Disk
```

However, the earlier system was missing two major correctness problems:

1. **What happens if the database crashes during a transaction?**
2. **What happens if multiple transactions access the same data simultaneously?**

These lead to two major areas:

```text
Transaction Processing
       │
       ├── Concurrency Control
       │      └── Multiple transactions safely execute together
       │
       └── Recovery
              └── Database safely recovers after crashes
```

### Example: Bank Transfer

Suppose account A contains `$100`.

A transaction wants to transfer `$25` to another account.

Conceptually:

```text
READ(A)          → $100
CHECK balance    → enough money
WRITE(A)         → $75
WRITE(B)         → B + $25
COMMIT
```

The database must make sure that these operations are treated as one logical action.

### Problem 1: Crash During a Transaction

Suppose:

```text
A = $100
B = $100

Transfer $25

A → $75
B → crash before receiving $25
```

After recovery, the database would incorrectly contain:

```text
A = $75
B = $100
```

The `$25` has effectively disappeared.

### Problem 2: Concurrent Transactions

Suppose two transactions simultaneously transfer `$25` from an account containing `$100`.

Both might execute:

```text
T1: READ A → $100
T2: READ A → $100

T1: calculate → $75
T2: calculate → $75

T1: WRITE A → $75
T2: WRITE A → $75
```

The correct balance should be:

```text
$100 - $25 - $25 = $50
```

But the database ends with:

```text
$75
```

One update was effectively lost.

### Key Points

* Transactions provide a unit of correctness.
* Recovery handles crashes.
* Concurrency control handles simultaneous transactions.
* A database must prioritize **correctness before performance**.
* Transactions are intertwined with many parts of a database system, including:

  * Buffer management
  * Storage
  * Query execution
  * Logging
  * Recovery
  * Concurrency control

---

# 2. Shadow Paging

### Definition

**Shadow paging** is a transaction technique where modified pages are copied rather than modifying the original pages directly.

The transaction modifies the copies. When the transaction commits, the database atomically switches to the new versions.

### Explanation

Suppose a transaction needs to modify pages A and B.

Instead of:

```text
Original Page A → modify
Original Page B → modify
```

we do:

```text
Original Page A ──→ Shadow Page A
Original Page B ──→ Shadow Page B

Transaction modifies Shadow A and Shadow B
```

At commit:

```text
Old page directory
       ↓
New page directory
       ↓
Shadow A + Shadow B
```

The database can atomically change the pointer/page directory to reference the new pages.

### Text Diagram

```text
Before transaction:

Page Directory
     │
     ├──> Page A
     └──> Page B


During transaction:

Page Directory
     │
     ├──> Original Page A
     └──> Original Page B

Transaction:
     │
     ├──> Shadow Page A
     └──> Shadow Page B


After COMMIT:

Page Directory
     │
     ├──> Shadow Page A
     └──> Shadow Page B
```

If the transaction aborts:

```text
Ignore Shadow A
Ignore Shadow B

Continue using original pages
```

### Why Is It Correct?

If a crash occurs before commit:

```text
Original pages remain unchanged
```

Therefore the database can simply ignore the uncommitted shadow pages.

If commit occurs:

```text
The page directory switches to the new pages.
```

### Advantages

* Very simple recovery concept.
* Uncommitted changes do not overwrite original data.
* Crash recovery can be extremely fast.
* Only committed page versions need to become visible.

### Disadvantages

The major problem is **performance**.

Pages must be copied before modification.

It also makes concurrent transactions difficult because the commit operation must atomically switch the database to the new page versions.

### Important Trade-Off

| Approach            | Normal Runtime | Crash Recovery     |
| ------------------- | -------------- | ------------------ |
| Shadow Paging       | Slower         | Very fast          |
| Write-Ahead Logging | Usually faster | Potentially slower |

### Key Point

Shadow paging is correct, but it does not provide the level of concurrency and performance desired from modern database systems.

---

# 3. Why We Need Concurrent Transactions

### Explanation

A simple database could process only one transaction at a time:

```text
T1 → finish
     ↓
T2 → finish
     ↓
T3 → finish
```

This would be easy to reason about.

But modern hardware provides:

* Multiple CPU cores
* Multiple threads
* Multiple disks
* Distributed machines

We want:

```text
T1 ────────────────┐
T2 ────────────────┼──> Execute concurrently
T3 ────────────────┘
```

This improves performance and responsiveness.

### The Goal

We want transactions to execute concurrently **while still producing a result equivalent to correct serial execution**.

That is the fundamental idea behind **serializability**.

---

# 4. Temporary Inconsistency During a Transaction

### Important Idea

A database may temporarily be in an inconsistent state while a transaction is executing.

That is acceptable as long as the inconsistency does not remain after the transaction commits or aborts.

### Example

Suppose:

```text
Account A = $100
Account B = $100
```

Transfer `$25` from A to B.

During execution:

```text
A = $75
B = $100
```

There appears to be `$25` missing.

Then:

```text
A = $75
B = $125
```

The final state is correct.

The database does not need every intermediate operation to produce a globally correct state.

### Important Distinction

```text
During transaction:
Temporary inconsistency → potentially acceptable

After COMMIT:
Incorrect state → NOT acceptable

After ABORT:
Changes remaining → NOT acceptable
```

---

# 5. Transactions Only Control Database Data

### Explanation

The database system controls the data that it manages.

For example:

```text
Transaction
   │
   ├── READ database object
   ├── WRITE database object
   └── COMMIT
```

But suppose application code does:

```text
UPDATE database
SEND EMAIL
LAUNCH EXTERNAL ACTION
COMMIT
```

If the transaction aborts, the database can undo its database changes.

It cannot necessarily undo an external action such as an email.

### Key Point

**Transaction guarantees apply to operations under the database system's control.**

---

# 6. Transaction Model Used in This Lecture

For the lecture's simplified model, transactions operate on abstract database objects.

The objects might represent:

* Tuples
* Rows
* Pages
* Tables
* Other database objects

The lecture uses:

```text
A
B
C
D
```

### Fixed-Size Database Assumption

For this lecture:

* Objects already exist.
* Transactions can read them.
* Transactions can write them.
* No inserts.
* No deletes.

This simplifies the discussion.

### Transaction Syntax

Conceptually:

```text
BEGIN

READ(A)
WRITE(A)
READ(B)
WRITE(B)

COMMIT
```

or:

```text
BEGIN

READ(A)
WRITE(A)

ROLLBACK
```

### SQL Example

```sql
BEGIN;

UPDATE Accounts
SET balance = balance - 25
WHERE account_id = 1;

UPDATE Accounts
SET balance = balance + 25
WHERE account_id = 2;

COMMIT;
```

If the transaction must be canceled:

```sql
ROLLBACK;
```

### Important Terms

| Term       | Meaning                                          |
| ---------- | ------------------------------------------------ |
| `BEGIN`    | Starts a transaction                             |
| `COMMIT`   | Makes changes permanent                          |
| `ROLLBACK` | Undoes transaction changes                       |
| `ABORT`    | Transaction is terminated and changes are undone |

### Autocommit

Many database systems use **autocommit** by default.

This means a standalone statement can effectively behave like:

```text
BEGIN
    SQL statement
COMMIT
```

For example:

```sql
UPDATE Accounts
SET balance = balance - 25
WHERE account_id = 1;
```

can effectively be treated as its own transaction.

If autocommit is disabled, multiple statements can be grouped:

```sql
BEGIN;

UPDATE ...
UPDATE ...
UPDATE ...

COMMIT;
```

---

# 7. ACID Properties

### Definition

**ACID** is the standard set of properties used to describe transaction correctness.

```text
A = Atomicity
C = Consistency
I = Isolation
D = Durability
```

---

## 7.1 Atomicity

### Definition

**Atomicity** means a transaction is all-or-nothing.

Either:

```text
ALL operations happen
```

or:

```text
NONE of them happen
```

### Example

A bank transfer:

```text
1. Remove $25 from A
2. Add $25 to B
```

Cannot result in:

```text
A loses $25
B does not receive $25
```

If the transaction aborts:

```text
A unchanged
B unchanged
```

### Memory Trick

> **Atomicity = All or Nothing**

---

# 8. Consistency

### Definition

**Consistency** means transactions must preserve the database's defined correctness rules.

Suppose:

```text
Age >= 0
```

is an integrity constraint.

A transaction cannot successfully change:

```text
Age = 25
```

to:

```text
Age = -100
```

if the constraint prohibits it.

### SQL Example

```sql
CREATE TABLE People (
    id INT,
    age INT CHECK (age >= 0)
);
```

The database now has an explicit rule:

```text
age must be >= 0
```

### Integrity Constraints

Examples include:

```sql
NOT NULL
CHECK
PRIMARY KEY
FOREIGN KEY
UNIQUE
```

The database system needs the constraints to know what constitutes a valid state.

### Important Clarification

Consistency does **not** mean "the database always magically knows what is correct."

The application/database designer must define the rules.

For example, the database sees:

```text
age = -100
```

as an integer unless a constraint says otherwise.

---

# 9. Isolation

### Definition

**Isolation** means transactions should behave as though they are executing independently.

Ideally:

```text
T1
↓
T2
```

or:

```text
T2
↓
T1
```

even though the database may physically interleave their operations.

### Example

Physically:

```text
T1 operation
T2 operation
T1 operation
T2 operation
```

But logically, the result should be equivalent to:

```text
T1 → T2
```

or:

```text
T2 → T1
```

### Why Isolation Matters

Without isolation, application programmers would need to reason about every possible interleaving of transactions.

With isolation:

```text
Application programmer
        ↓
"Assume my transaction runs alone."
```

The database system handles the complicated coordination.

---

# 10. Durability

### Definition

**Durability** means that once a transaction commits, its changes survive a database crash.

Conceptually:

```text
COMMIT
   ↓
Crash
   ↓
Recovery
   ↓
Committed changes still exist
```

Durability is usually implemented through mechanisms such as:

* Write-ahead logging
* Recovery
* Checkpoints
* Replication for machine-level failures

### Important Clarification

Durability on a single machine does not magically protect against destruction of the physical machine.

If the machine and its disk are destroyed, replication to another machine is required for stronger protection.

---

# 11. ACID Summary

| Property    | Meaning                                          | Memory Trick   |
| ----------- | ------------------------------------------------ | -------------- |
| Atomicity   | All operations or none                           | All-or-nothing |
| Consistency | Valid database state according to constraints    | Correct state  |
| Isolation   | Transactions behave as if executed independently | Looks serial   |
| Durability  | Committed changes survive crashes                | Permanent      |

### Memory Trick

```text
A = All or nothing
C = Correct state
I = Independent-looking execution
D = Doesn't disappear after commit
```

---

# 12. Atomicity: Commit vs Abort

A transaction has two important outcomes:

```text
              Transaction
                  │
           ┌──────┴──────┐
           ↓             ↓
        COMMIT         ABORT
           │             │
           ↓             ↓
     Keep changes     Undo changes
```

### Application-Initiated Abort

The application can decide:

```sql
ROLLBACK;
```

### Database-Initiated Abort

The database can also abort a transaction.

For example, a transaction may:

* Conflict with another transaction.
* Become deadlocked.
* Violate a constraint.
* Time out.

The application must be prepared to handle an abort.

### Important Point

Even a single SQL statement can be treated as a transaction.

---

# 13. Logging and Write-Ahead Logging

### Definition

A **log** records information about database operations so the system can recover after a crash.

The log acts somewhat like a database "black box."

```text
Transaction
    ↓
Operations
    ↓
Log records
    ↓
Disk
```

If the database crashes:

```text
Crash
 ↓
Read log
 ↓
Determine what happened
 ↓
Redo / Undo as necessary
 ↓
Restore correct state
```

---

# 14. Write-Ahead Logging (WAL)

### Definition

**Write-Ahead Logging (WAL)** means the log record describing a database modification must be safely written before the corresponding modified database page is written to disk.

### Fundamental Rule

```text
LOG RECORD
    ↓
must reach stable storage
    ↓
BEFORE
    ↓
modified DATABASE PAGE
```

### Example

Suppose a transaction changes page P.

```text
Transaction
    ↓
Modify P
    ↓
Create log record
    ↓
Write log record to disk
    ↓
Write P to disk
```

If the system crashes after the log reaches disk but before P reaches disk, recovery can use the log to reconstruct what happened.

### Why WAL Is Useful

Writing a log sequentially is often cheaper than repeatedly performing random writes to database pages.

This connects to earlier course material about sequential vs random I/O.

---

# 15. Undo and Redo Information

A recovery system may need information for:

### Undo

Reverse an operation.

Example:

```text
Before:  $100
After:   $75
```

Undo information can tell recovery:

```text
Restore $100
```

### Redo

Repeat an operation.

Example:

```text
Set balance to $75
```

If the database page did not reach disk before the crash, recovery can redo the operation.

### Conceptual Diagram

```text
              LOG
               │
       ┌───────┴───────┐
       ↓               ↓
      UNDO            REDO
       │               │
Reverse changes    Reapply changes
```

---

# 16. Physical vs Logical Logging

### Physical / Physiological Logging

The lecture discussed logging changes at a lower level, such as the actual changes/differences made to database structures.

Conceptually:

```text
Page X
  ↓
change bytes/records
  ↓
record what changed
```

This can be thought of similarly to a `diff`.

### Logical Logging

Logical logging records higher-level operations.

For example:

```text
UPDATE Accounts
SET balance = balance + 25
WHERE account_id = 10;
```

Recovery can replay the logical operation.

### Comparison

| Type                   | Records                 | Recovery Idea            |
| ---------------------- | ----------------------- | ------------------------ |
| Physical/Physiological | Lower-level changes     | Reapply/reverse changes  |
| Logical                | Higher-level operations | Execute operations again |

### Trade-Off

Logical replay may require expensive operations again.

For example, if a query originally took one hour, replaying that query may also take a long time.

---

# 17. Why Logging Usually Beats Shadow Paging

### Write-Ahead Logging

Normal execution:

```text
Append log
     ↓
Continue transaction
```

Usually efficient because logs can be written sequentially.

Recovery:

```text
Crash
 ↓
Replay/process log
 ↓
Restore database
```

Potentially expensive.

### Shadow Paging

Normal execution:

```text
Copy pages
 ↓
Modify copies
 ↓
Switch page references
```

More expensive during normal operation.

Recovery:

```text
Crash
 ↓
Ignore uncommitted shadow pages
 ↓
Database is already correct
```

Very fast.

### Comparison

|                         | WAL            | Shadow Paging  |
| ----------------------- | -------------- | -------------- |
| Normal execution        | Usually faster | Usually slower |
| Recovery                | Can be slower  | Very fast      |
| Concurrent transactions | Better suited  | More difficult |
| Storage overhead        | Log            | Page copies    |
| Common modern approach  | Yes            | Less common    |

---

# 18. Checkpoints

### Problem

Suppose the log grows for years.

```text
Log:
-------------------------------------------->
Oldest transaction                    Current
```

A crash could theoretically require processing a huge amount of history.

### Solution

Use **checkpoints** or snapshots.

Conceptually:

```text
LOG
───────────────────────────────
        CHECKPOINT
             │
             ↓
Older history can eventually be discarded
```

The database does not necessarily need to replay everything from the beginning.

### Challenge

Transactions may span checkpoints.

For example:

```text
T1 starts
       ↓
CHECKPOINT
       ↓
T1 commits
```

The recovery system still has to correctly handle T1.

### Fuzzy Checkpoints

A **fuzzy checkpoint** allows normal transactions to continue while the checkpoint is occurring.

This avoids stopping the database for the entire checkpoint process.

---

# 19. Recovery and ARIES

The lecture mentioned **ARIES** as a major recovery algorithm.

ARIES is associated with:

* Logging
* Recovery
* Redo
* Undo
* Checkpoints

The important conceptual idea is that recovery is a carefully designed process for determining what must be redone and what must be undone after a crash.

### Exam Tip

You do not need to confuse:

```text
Concurrency Control
```

with:

```text
Recovery
```

They solve different problems.

```text
Concurrency Control → "Can transactions safely run together?"

Recovery → "What happens if the system crashes?"
```

---

# 20. Consistency vs Eventual Consistency

### Stronger Consistency Idea

Suppose a transaction commits a change on machine A.

If another machine has a copy of the same data, a strong consistency model may require:

```text
Commit on A
   ↓
Read on B
   ↓
See the committed value
```

### Eventual Consistency

With **eventual consistency**:

```text
Machine A:
new value

Machine B:
old value
```

temporarily.

Eventually:

```text
Machine B
    ↓
updated
```

### Timeline

```text
T0: A = old, B = old

T1: Write A

T2: Commit A

T3: Read B → still old

T4: Replication occurs

T5: Read B → new value
```

### Important Distinction

Eventual consistency is mainly relevant to distributed/replicated systems.

It allows temporary disagreement between copies.

---

# 21. Isolation and Serial Execution

### Definition: Serial Schedule

A **serial schedule** executes transactions one at a time without interleaving.

For two transactions:

```text
T1 → T2
```

or:

```text
T2 → T1
```

### Definition: Interleaved Schedule

An interleaved schedule mixes operations from multiple transactions.

Example:

```text
T1 operation
T1 operation
T2 operation
T1 operation
T2 operation
```

### Goal

We want to permit interleaving for performance while maintaining correctness.

```text
Physical execution:
T1 → T2 → T1 → T2

Logical result:
T1 → T2
```

If the final behavior is equivalent to a serial execution, the schedule is **serializable**.

---

# 22. Serializability

### Definition

A schedule is **serializable** if its outcome is equivalent to some serial ordering of the transactions.

### Critical Point

The transactions do **not** necessarily have to execute in the order they arrived.

For example:

```text
Application submits T1
Application submits T2
```

The database might logically execute:

```text
T2 → T1
```

and still be correct.

### Unless External/Strict Ordering Is Required

Some systems provide stronger guarantees concerning the order in which transactions are submitted/committed.

The lecture mentioned Google Spanner as an example of a system supporting strong external ordering semantics.

For this lecture's simplified model:

> We care about equivalence to **some** serial ordering, not necessarily arrival order.

---

# 23. Bank Account Serializability Example

Initially:

```text
A = $1,000
B = $1,000

Total = $2,000
```

T1:

```text
Transfer $100 from A → B
```

T2:

```text
Apply 6% interest
```

The final total should be:

```text
$2,120
```

There are two possible serial orderings:

```text
T1 → T2
```

or:

```text
T2 → T1
```

Either can be correct if the final state is equivalent to one of these serial executions.

### Important Principle

The database does not necessarily care which serial order is selected.

It cares that:

```text
Interleaved execution
        ↓
Equivalent to
        ↓
At least one serial execution
```

---

# 24. Why Interleaving Happens

Transactions often have to wait.

For example:

```text
T1:
READ A
   ↓
Disk I/O
   ↓
WAIT
```

Instead of letting the CPU sit idle:

```text
T2:
READ B
UPDATE B
...
```

The database can execute T2 while T1 is waiting.

This improves resource utilization.

### Example

```text
T1: READ A
T1: WAIT FOR DISK

T2: READ A
T2: UPDATE A
T2: UPDATE B
T2: COMMIT

T1: continue
```

The problem is determining whether the resulting interleaving is correct.

---

# 25. Conflict Operations

### Definition

Two operations **conflict** when:

1. They belong to different transactions.
2. They access the same database object.
3. At least one operation is a write.

### The Three Basic Conflict Types

```text
READ-WRITE
WRITE-READ
WRITE-WRITE
```

### Why READ-READ Does Not Conflict

Suppose:

```text
T1: READ A
T2: READ A
```

Neither transaction changes A.

There is no problem with both reading the same value.

Therefore:

```text
READ + READ = No conflict
```

### Conflict Table

| T1      | T2      | Conflict? |
| ------- | ------- | --------- |
| READ A  | READ A  | No        |
| READ A  | WRITE A | Yes       |
| WRITE A | READ A  | Yes       |
| WRITE A | WRITE A | Yes       |
| READ A  | WRITE B | No        |
| WRITE A | READ B  | No        |

---

# 26. Three Major Anomalies

The lecture focuses on three basic anomalies:

1. Non-repeatable reads
2. Dirty reads
3. Lost updates

Other anomalies, including phantom reads and write skew, are discussed later.

---

# 27. Non-Repeatable Read

### Definition

A **non-repeatable read** occurs when a transaction reads the same object twice but gets different values because another transaction modified it between the reads.

### Example

Initial:

```text
A = $10
```

Execution:

```text
T1: READ A → $10

T2: WRITE A → $19
T2: COMMIT

T1: READ A → $19
```

T1 saw:

```text
First read:  $10
Second read: $19
```

### Why Is This a Problem?

If T1 were executing alone, it would not see the value change in the middle.

Therefore, the interleaving is not equivalent to the expected serial behavior.

### Memory Trick

> **Non-repeatable read = Same read, different answer.**

---

# 28. Dirty Read

### Definition

A **dirty read** occurs when one transaction reads changes made by another transaction before those changes have committed.

### Example

Initial:

```text
A = $10
```

Execution:

```text
T1: READ A → $10
T1: WRITE A → $12

T2: READ A → $12

T2: COMMIT

T1: ABORT
```

T2 read a value that came from a transaction that eventually aborted.

Therefore, T2 used data that should never have become part of the committed database state.

### Memory Trick

> **Dirty read = Reading uncommitted data.**

---

# 29. Lost Update

### Definition

A **lost update** occurs when concurrent writes cause one transaction's update to overwrite another transaction's update.

### Example

Initial:

```text
A = ?
B = ?
```

Suppose:

```text
T1: WRITE A = $10

T2: WRITE A = $19

T2: WRITE B = Bob

T1: WRITE B = Alice
```

The final state may become:

```text
A = $19
B = Alice
```

But neither serial ordering produces this combination.

If:

```text
T1 → T2
```

we expect:

```text
A = $19
B = Bob
```

If:

```text
T2 → T1
```

we expect:

```text
A = $10
B = Alice
```

Therefore:

```text
A = $19
B = Alice
```

is invalid for serializability.

### Blind Write

A **blind write** is a write that occurs without first reading the value.

Example:

```text
WRITE(A, 19)
```

The transaction does not need to know what A currently contains.

---

# 30. Other Anomalies

The lecture mentioned two additional anomalies that will be covered later.

### Phantom Read

A transaction scans a range, then another transaction inserts/deletes something in that range.

Example:

```text
T1: SELECT all accounts where balance > 100
    → 5 rows

T2: INSERT account with balance = 200
T2: COMMIT

T1: Run same query again
    → 6 rows
```

The new row is a **phantom**.

### Write Skew

Write skew is a more complicated anomaly involving transactions reading overlapping state and then making conflicting updates.

The lecture indicated this will be covered later with multiversioning/isolation-level material.

---

# 31. Conflict Serializability

### Definition

**Conflict serializability** determines whether a schedule can be transformed into a serial schedule by considering conflicting operations.

It is the most common practical notion discussed in the lecture.

### Why It Is Useful

Instead of manually examining every possible final state, we can construct a graph.

That graph is called a:

* Dependency graph
* Precedence graph

---

# 32. Dependency / Precedence Graph

### Definition

A dependency graph contains:

* One node for each transaction.
* Directed edges representing conflicts.

### Rule

If:

```text
T1 operation
```

conflicts with:

```text
T2 operation
```

and T1's operation occurs first, create:

```text
T1 → T2
```

### Most Important Rule

```text
NO CYCLE
    ↓
Conflict Serializable

CYCLE
    ↓
NOT Conflict Serializable
```

---

# 33. Building a Dependency Graph

### Step-by-Step Method

Given a schedule:

### Step 1: Create One Node per Transaction

If you have:

```text
T1
T2
T3
```

create:

```text
T1     T2     T3
```

### Step 2: Look for Conflicting Operations

Find pairs that:

* Access the same object.
* Belong to different transactions.
* Include at least one write.

### Step 3: Determine Which Operation Comes First

If:

```text
T1: WRITE(A)
T2: READ(A)
```

then:

```text
T1 → T2
```

### Step 4: Add Every Required Edge

Do this for all conflicts.

### Step 5: Look for Cycles

If:

```text
T1 → T2 → T3
```

and:

```text
T3 → T1
```

then:

```text
T1 → T2 → T3 → T1
```

is a cycle.

Therefore:

```text
NOT conflict serializable
```

---

# 34. Dependency Graph Example

Suppose:

```text
T1: R(A), W(A), R(B), W(B)

T2: R(A), W(A), R(B), W(B)
```

Suppose T1's operations on A occur before T2's corresponding operations.

We get:

```text
T1 ─────→ T2
```

But suppose operations involving B create:

```text
T2 ─────→ T1
```

Now:

```text
T1 ─────→ T2
 ↑         │
 └─────────┘
```

There is a cycle.

Therefore:

```text
NOT conflict serializable
```

### Important Observation

Multiple conflicts can produce redundant edges.

You only need to know whether the graph contains a cycle.

---

# 35. Three-Transaction Dependency Graphs

For multiple transactions:

```text
T1
 ↓
T2
 ↓
T3
```

If there is no path back to an earlier transaction:

```text
No cycle
```

Therefore the schedule is conflict serializable.

A valid serial ordering can be obtained from the dependency relationships.

For example:

```text
T2 → T1 → T3
```

may be the logical serial ordering even if the transactions physically started or committed in a different order.

### Important Point

**Physical execution order and logical serial order are not necessarily the same.**

---

# 36. Topological Ordering

A useful way to think about a dependency graph with no cycles is that its dependencies can be arranged into a serial order.

For example:

```text
T2 → T1
T1 → T3
```

means:

```text
T2 → T1 → T3
```

is a valid serial ordering.

If the graph has a cycle:

```text
T1 → T2
T2 → T1
```

there is no valid ordering that satisfies both dependencies.

---

# 37. Conflict Serializability vs View Serializability

### Conflict Serializability

Looks only at the read/write conflicts.

It does **not** need to understand the application's high-level meaning.

### View Serializability

Allows some schedules that conflict serializability rejects if the final behavior is still equivalent from the application's point of view.

This requires understanding what the application actually cares about.

### Comparison

| Concept                              | Conflict Serializability | View Serializability |
| ------------------------------------ | ------------------------ | -------------------- |
| Uses read/write conflicts            | Yes                      | Not only             |
| Needs application semantics          | No                       | Yes                  |
| Easier to test                       | Yes                      | More difficult       |
| Allows more schedules                | Fewer                    | More                 |
| Practical for DB concurrency control | Common                   | More difficult       |

---

# 38. Why View Serializability Is More Difficult

Suppose a transaction does:

```text
READ(A)
READ(B)
COMPUTE A + B
```

Maybe the application cares about the exact sum.

But another transaction might instead care only about:

```text
COUNT(accounts)
```

An interleaving that changes the sum might not matter if the only thing the application cares about is the count.

Therefore, determining correctness requires understanding:

```text
"What does the application actually consider correct?"
```

A database system generally does not want to inspect arbitrary application semantics.

That is why conflict serializability is much more practical.

---

# 39. Relationship Between Serial, Conflict-Serializable, and View-Serializable Schedules

Think of the sets as nested regions:

```text
All Possible Schedules
┌─────────────────────────────────────────┐
│                                         │
│   View-Serializable Schedules           │
│   ┌───────────────────────────────┐     │
│   │                               │     │
│   │ Conflict-Serializable         │     │
│   │ ┌─────────────────────────┐   │     │
│   │ │                         │   │     │
│   │ │ Serial Schedules        │   │     │
│   │ │                         │   │     │
│   │ └─────────────────────────┘   │     │
│   └───────────────────────────────┘     │
└─────────────────────────────────────────┘
```

Conceptually:

```text
Serial
   ⊂
Conflict Serializable
   ⊂
View Serializable
   ⊂
All Schedules
```

### Meaning

Every serial schedule is conflict serializable.

Every conflict-serializable schedule is view serializable.

But some view-serializable schedules are not conflict serializable.

---

# 40. Why the Database Uses Conflict Serializability

The database typically does not know:

```text
"What does this application logically care about?"
```

It sees operations such as:

```text
READ(A)
WRITE(A)
READ(B)
WRITE(B)
```

It cannot reliably infer whether:

```text
A + B
```

or:

```text
COUNT(A,B)
```

is the actual business requirement.

Therefore, conflict serializability provides a practical, general rule.

### Trade-Off

```text
Conflict serializability
        ↓
Easier to enforce
        ↓
May reject some schedules that could actually be safe
```

---

# 41. Deterministic Scheduling

The lecture briefly mentioned **deterministic scheduling**.

The basic idea is to know enough about a transaction's operations to determine how transactions can safely be ordered.

Conceptually:

```text
Run transaction logically
        ↓
Record what it reads/writes
        ↓
Determine dependencies
        ↓
Schedule/replay safely
```

Some systems can execute work in a speculative/pretend mode and later validate whether the transaction's observed results remain valid.

### Key Idea

The more information the system has about the complete transaction, the more intelligently it may be able to schedule transactions.

---

# 42. Escrow Transactions

### Definition

**Escrow transactions** are a higher-level technique for safely dividing limited resources among independent participants.

### Example

Suppose there are:

```text
100 tickets
```

Instead of making every transaction coordinate globally:

```text
East Coast → 50 tickets
West Coast → 50 tickets
```

Each side can sell from its allocated amount.

Only when one side runs out does it need to coordinate for more.

### Benefit

Less communication and contention.

### Conceptual Diagram

```text
                  100 tickets
                      │
              ┌───────┴───────┐
              ↓               ↓
        East Coast         West Coast
          50 seats           50 seats
              │               │
              ↓               ↓
         Local sales      Local sales
```

### Important Point

Escrow is an application/system design technique rather than a replacement for general database transaction semantics.

---

# 43. Pessimistic vs Optimistic Concurrency Control

There are two broad approaches.

## Pessimistic

### Definition

Assume conflicts are likely.

Prevent potentially conflicting operations before they cause problems.

Conceptually:

```text
Transaction wants access
        ↓
Check/obtain protection
        ↓
Execute safely
```

### Philosophy

> "Prevent the conflict before it happens."

---

## Optimistic

### Definition

Assume conflicts are relatively rare.

Allow transactions to execute and check for conflicts later.

Conceptually:

```text
Execute
   ↓
Track operations
   ↓
Validate
   ↓
       ┌── No conflict → COMMIT
       │
       └── Conflict → ABORT/RETRY
```

### Philosophy

> "Let it run, then check whether it was safe."

### Comparison

|                 | Pessimistic           | Optimistic              |
| --------------- | --------------------- | ----------------------- |
| Assumption      | Conflicts common      | Conflicts rare          |
| Strategy        | Prevent conflicts     | Detect conflicts        |
| Cost            | Blocking/coordination | Possible rollback/retry |
| Example concept | Locking               | Validation              |

---

# 44. Important Difference: Concurrency Control vs Recovery

These concepts are easy to confuse.

| Problem                                        | Mechanism           |
| ---------------------------------------------- | ------------------- |
| Two transactions interfere                     | Concurrency control |
| Database crashes                               | Recovery            |
| Transaction partially executes                 | Atomicity/recovery  |
| Transaction sees another's uncommitted changes | Isolation           |
| Committed changes disappear after crash        | Durability/recovery |
| Transactions execute concurrently but safely   | Serializability     |

### Memory Trick

```text
Concurrency = "Can these run together?"

Recovery = "What happens if we crash?"
```

---

# 45. Full Transaction Architecture

A simplified view:

```text
                 APPLICATION
                      │
                      ↓
                 BEGIN
                      │
                      ↓
              ┌───────────────┐
              │  TRANSACTION  │
              └───────────────┘
                 │    │    │
                 ↓    ↓    ↓
               READ WRITE READ
                 │    │    │
                 └────┼────┘
                      ↓
             CONCURRENCY CONTROL
                      │
                      ↓
               QUERY EXECUTION
                      │
                      ↓
                 BUFFER POOL
                      │
             ┌────────┴────────┐
             ↓                 ↓
            LOG              DATA
             │                 │
             ↓                 ↓
            DISK              DISK
```

The transaction system has to coordinate all of these pieces.

---

# 46. Common Mistakes

* **Mistake:** Thinking a transaction must execute physically from beginning to end without interruption.

  * **Correction:** Transactions can be interleaved as long as the result is correct.

* **Mistake:** Thinking serializable means transactions must execute in submission order.

  * **Correction:** The result only needs to be equivalent to some valid serial ordering unless a stronger ordering guarantee is required.

* **Mistake:** Thinking every temporary inconsistent state is automatically an error.

  * **Correction:** Temporary inconsistency during execution can be acceptable; incorrect committed state is not.

* **Mistake:** Thinking READ-READ is a conflict.

  * **Correction:** Two reads of the same object do not conflict.

* **Mistake:** Forgetting that WRITE-WRITE conflicts.

  * **Correction:** Two writes to the same object conflict.

* **Mistake:** Forgetting that READ-WRITE and WRITE-READ conflict.

  * **Correction:** At least one operation must be a write.

* **Mistake:** Thinking a dirty read means the database is permanently corrupted.

  * **Correction:** It means a transaction read another transaction's uncommitted changes.

* **Mistake:** Confusing a dirty read with a non-repeatable read.

  * **Dirty:** Reads uncommitted data.
  * **Non-repeatable:** Reads the same committed object twice and gets different values.

* **Mistake:** Thinking a dependency graph with an edge is automatically invalid.

  * **Correction:** A cycle is the problem.

* **Mistake:** Thinking T1 → T2 means T1 physically ran completely before T2.

  * **Correction:** It represents a dependency that constrains the equivalent serial ordering.

* **Mistake:** Forgetting that one redundant edge does not matter.

  * **Correction:** You mainly care whether the graph contains a cycle.

* **Mistake:** Assuming conflict serializability and view serializability are identical.

  * **Correction:** View serializability is broader.

* **Mistake:** Thinking shadow paging and WAL have the same runtime behavior.

  * **Correction:** WAL generally favors faster normal execution; shadow paging favors simpler/faster recovery.

* **Mistake:** Thinking WAL means data pages are always written before logs.

  * **Correction:** WAL requires relevant log records to be safely written before the corresponding dirty page is written.

* **Mistake:** Thinking COMMIT only matters when the application receives its response.

  * **Correction:** A transaction may already be committed internally even if the acknowledgement is lost because of a crash.

* **Mistake:** Confusing ACID consistency with distributed eventual consistency.

  * **Correction:** They refer to different concepts.

---

# 47. Exam Strategy: Identifying Conflicts

When given a transaction schedule, use this checklist.

### Step 1: Identify Transactions

```text
T1, T2, T3, ...
```

### Step 2: Identify Objects

```text
A, B, C, ...
```

### Step 3: Mark Every Operation

For example:

```text
T1: R(A), W(A), R(B)
T2: R(A), W(B)
```

### Step 4: Find Same-Object Pairs

Only compare operations touching the same object.

### Step 5: Ignore READ-READ

```text
R(A) + R(A) → no edge
```

### Step 6: Add Edges for Conflicts

If T1's conflicting operation happens first:

```text
T1 → T2
```

### Step 7: Find Cycles

```text
Cycle → NOT conflict serializable
No cycle → conflict serializable
```

---

# 48. Example: Determining Conflict Serializability

Suppose:

```text
T1: R(A)
T2: W(A)
T1: W(B)
T2: R(B)
```

### Analyze A

```text
T1: R(A)
T2: W(A)
```

Conflict:

```text
T1 → T2
```

### Analyze B

```text
T1: W(B)
T2: R(B)
```

Conflict:

```text
T1 → T2
```

Graph:

```text
T1 ─────────→ T2
```

No cycle.

Therefore:

```text
Conflict Serializable
```

---

# 49. Example: Non-Serializable Schedule

Suppose:

```text
T1: R(A)
T2: W(A)
T2: R(B)
T1: W(B)
```

A gives:

```text
T1 → T2
```

B gives:

```text
T2 → T1
```

Graph:

```text
T1 ─────→ T2
↑          │
└──────────┘
```

Cycle exists.

Therefore:

```text
NOT conflict serializable
```

---

# 50. Example: No Conflict

Suppose:

```text
T1: R(A)
T1: W(A)

T2: R(B)
T2: W(B)
```

They operate on different objects.

Therefore:

```text
No conflicts
```

The schedule is conflict serializable.

---

# 51. Logging vs Concurrency Control

These mechanisms solve different dimensions of correctness.

```text
                   TRANSACTIONS
                        │
             ┌──────────┴──────────┐
             ↓                     ↓
       Concurrency              Recovery
         Control
             │                     │
             ↓                     ↓
       Safe execution        Crash handling
       together
             │                     │
             ↓                     ↓
       Serializability       WAL / Logging
                             Shadow Paging
                             Checkpoints
```

---

# 52. Database Correctness as a Whole

The database needs several guarantees simultaneously.

```text
                   DATABASE
                      │
        ┌─────────────┼─────────────┐
        ↓             ↓             ↓
   Atomicity      Isolation      Durability
        │             │             │
        ↓             ↓             ↓
  All or nothing   Appears       Survives
                   serial        crashes

                      +
                      ↓

                 Consistency
                      │
                      ↓
             Valid application state
```

---

# 53. Important Comparisons

## Transaction Outcomes

| Concept  | Meaning                           |
| -------- | --------------------------------- |
| Commit   | Keep transaction changes          |
| Abort    | Stop transaction and undo changes |
| Rollback | Undo transaction changes          |

## Consistency Concepts

| Concept                          | Meaning                                                          |
| -------------------------------- | ---------------------------------------------------------------- |
| Database consistency             | Database satisfies defined integrity rules                       |
| Isolation                        | Concurrent transactions appear appropriately separated           |
| Stronger distributed consistency | Replicas reflect committed changes according to the chosen model |
| Eventual consistency             | Replicas may temporarily disagree but converge later             |

## Scheduling

| Concept               | Meaning                                                              |
| --------------------- | -------------------------------------------------------------------- |
| Serial schedule       | Transactions execute one after another                               |
| Interleaved schedule  | Operations from transactions are mixed                               |
| Serializable          | Interleaved execution equivalent to some serial execution            |
| Conflict serializable | Serializable based on read/write conflicts                           |
| View serializable     | Broader equivalence based on observed behavior/application semantics |

## Anomalies

| Anomaly             | Basic Problem                                                                 |
| ------------------- | ----------------------------------------------------------------------------- |
| Non-repeatable read | Same transaction reads different values at different times                    |
| Dirty read          | Reads uncommitted data                                                        |
| Lost update         | One write effectively overwrites another                                      |
| Phantom read        | Repeated range query sees inserted/deleted rows                               |
| Write skew          | Transactions independently read overlapping state and make conflicting writes |

## Logging vs Shadow Paging

|                | Write-Ahead Logging         | Shadow Paging       |
| -------------- | --------------------------- | ------------------- |
| Basic idea     | Record changes in log first | Modify copied pages |
| Normal runtime | Generally faster            | Generally slower    |
| Recovery       | More work                   | Very fast           |
| Concurrency    | Better suited               | More limited        |
| Main cost      | Log/recovery management     | Page copying        |

## Pessimistic vs Optimistic

|                     | Pessimistic             | Optimistic             |
| ------------------- | ----------------------- | ---------------------- |
| Assumption          | Conflicts likely        | Conflicts rare         |
| Strategy            | Prevent conflicts       | Detect conflicts       |
| Typical consequence | Blocking                | Abort/retry            |
| Goal                | Avoid invalid execution | Allow more concurrency |

---

# 54. Important SQL Syntax

### Begin a Transaction

```sql
BEGIN;
```

### Commit

```sql
COMMIT;
```

### Roll Back

```sql
ROLLBACK;
```

### Example Bank Transfer

```sql
BEGIN;

UPDATE Accounts
SET balance = balance - 25
WHERE account_id = 1;

UPDATE Accounts
SET balance = balance + 25
WHERE account_id = 2;

COMMIT;
```

### Line-by-Line

```sql
BEGIN;
```

Starts the transaction.

```sql
UPDATE Accounts
SET balance = balance - 25
WHERE account_id = 1;
```

Subtracts `$25` from account 1.

```sql
UPDATE Accounts
SET balance = balance + 25
WHERE account_id = 2;
```

Adds `$25` to account 2.

```sql
COMMIT;
```

Makes the transaction's changes permanent.

If something goes wrong:

```sql
ROLLBACK;
```

undoes the transaction's changes.

---

# 55. Integrity Constraint Example

```sql
CREATE TABLE People (
    id INT PRIMARY KEY,
    age INT CHECK (age >= 0)
);
```

### Explanation

```sql
PRIMARY KEY
```

ensures each row has a unique identifier.

```sql
CHECK (age >= 0)
```

defines a consistency rule.

The database system can reject:

```sql
INSERT INTO People
VALUES (1, -50);
```

because it violates the defined constraint.

---

# 56. Must-Know Formulas / Rules

### Conflict Rule

Two operations conflict when:

```text
Different transactions
+
Same object
+
At least one WRITE
```

### No Conflict

```text
READ(A)
READ(A)
```

### Conflict Types

```text
READ-WRITE
WRITE-READ
WRITE-WRITE
```

### Dependency Graph

```text
No cycle
    ↓
Conflict Serializable

Cycle
    ↓
Not Conflict Serializable
```

### Serializability

```text
Interleaved schedule
        ↓
Equivalent to some
serial schedule?
        ↓
YES → Serializable
NO  → Not Serializable
```

### ACID

```text
A = Atomicity
C = Consistency
I = Isolation
D = Durability
```

### WAL

```text
LOG RECORD → DISK
       BEFORE
DATA PAGE → DISK
```

---

# 57. Exam Review

## Must-Know Definitions

* **Transaction** — A sequence of database operations treated as one logical unit.
* **Commit** — Permanently accept transaction changes.
* **Abort** — Terminate a transaction and undo its changes.
* **Rollback** — Reverse transaction changes.
* **Atomicity** — All-or-nothing execution.
* **Consistency** — Transactions preserve defined database correctness constraints.
* **Isolation** — Transactions behave as though they execute independently/serially according to the isolation guarantee.
* **Durability** — Committed changes survive crashes.
* **Shadow paging** — Modify copied pages and atomically switch to them at commit.
* **Write-Ahead Logging** — Write log records before the corresponding database pages.
* **WAL** — Write-Ahead Logging.
* **Checkpoint** — Recovery mechanism that limits how far back recovery must process.
* **Fuzzy checkpoint** — Checkpoint that can occur while transactions continue.
* **Serial schedule** — Transactions execute completely one after another.
* **Interleaved schedule** — Operations from multiple transactions are mixed.
* **Serializable schedule** — Equivalent to some serial execution.
* **Conflict serializable** — Serializable based on conflicting read/write operations.
* **View serializable** — Broader serializability notion based on equivalent observed behavior.
* **Conflict** — Same object, different transactions, and at least one write.
* **Dependency graph** — Graph representing transaction dependencies caused by conflicts.
* **Dirty read** — Reading uncommitted data.
* **Non-repeatable read** — Same transaction reads an object twice and sees different values.
* **Lost update** — One transaction's write overwrites another's effective update.
* **Phantom read** — Repeated range access sees different rows because another transaction inserted/deleted rows.
* **Blind write** — Writing without first reading the existing value.
* **Pessimistic concurrency control** — Assume conflicts are likely and prevent them.
* **Optimistic concurrency control** — Assume conflicts are rare and validate later.
* **Eventual consistency** — Replicas may temporarily disagree before converging.

---

# 58. Must-Know Methods

## Method 1: Determine Whether Operations Conflict

1. Are the operations from different transactions?
2. Do they access the same object?
3. Is at least one a write?
4. If yes → conflict.
5. If both are reads → no conflict.

---

## Method 2: Build a Dependency Graph

1. Create one node for each transaction.
2. Examine all operations.
3. Find conflicting operations.
4. Determine which conflicting operation occurs first.
5. Add an edge from the earlier transaction to the later transaction.
6. Repeat for all conflicts.
7. Search for cycles.
8. No cycle → conflict serializable.
9. Cycle → not conflict serializable.

---

## Method 3: Find a Serial Ordering

Given a dependency graph:

```text
T2 → T1
T1 → T3
```

Read the dependency direction:

```text
T2 must come before T1
T1 must come before T3
```

Therefore:

```text
T2 → T1 → T3
```

is a valid serial ordering.

---

## Method 4: Identify a Dirty Read

Look for:

```text
T1 WRITE(A)
T2 READ(A)
T1 has NOT committed
```

If T2 sees T1's value:

```text
DIRTY READ
```

---

## Method 5: Identify a Non-Repeatable Read

Look for:

```text
T1 READ(A) → X

T2 WRITE(A)
T2 COMMIT

T1 READ(A) → Y
```

where:

```text
X ≠ Y
```

---

## Method 6: Identify a Lost Update

Look for two transactions writing the same object where one effective update overwrites another.

```text
T1 WRITE(A)
T2 WRITE(A)
```

Analyze the dependency graph to determine whether the resulting schedule is serializable.

---

# 59. Exam Problem Checklist

When you see a schedule question, immediately ask:

```text
1. What are the transactions?

2. What objects are accessed?

3. Which operations are reads?

4. Which operations are writes?

5. Which operations conflict?

6. What dependency edges exist?

7. Does the graph contain a cycle?

8. If no cycle:
      What serial ordering is possible?

9. If there is a cycle:
      Not conflict serializable.

10. Is the question asking about:
      dirty reads?
      non-repeatable reads?
      lost updates?
      serializability?
      ACID?
      recovery?
```

---

# 60. Final Cheat Sheet / Memory Sheet

## ACID

```text
A — Atomicity
    ALL or NOTHING

C — Consistency
    Preserve defined correctness rules

I — Isolation
    Concurrent execution appears appropriately serial

D — Durability
    COMMITTED changes survive crashes
```

---

## Transactions

```text
BEGIN
   ↓
READ / WRITE
   ↓
COMMIT
   OR
ROLLBACK
```

---

## WAL

```text
CHANGE
  ↓
LOG RECORD
  ↓
DISK
  ↓
DATABASE PAGE
  ↓
DISK
```

**Log first. Data page second.**

---

## Shadow Paging

```text
Original pages
      ↓
Copy pages
      ↓
Modify copies
      ↓
COMMIT
      ↓
Atomically switch page directory
```

Crash before commit:

```text
Ignore shadow pages
```

---

## Conflict Rule

```text
Different transactions
        +
Same object
        +
At least one WRITE
        =
CONFLICT
```

Remember:

```text
R-R → NO conflict

R-W → conflict
W-R → conflict
W-W → conflict
```

---

## Dependency Graph

```text
Conflict:
T1 operation happens before T2 operation

        ↓

T1 → T2
```

Then:

```text
NO CYCLE
    ↓
Conflict Serializable

CYCLE
    ↓
NOT Conflict Serializable
```

---

## Serializability

```text
Physical execution:
T1 → T2 → T1 → T2

                  ↓

Logical result must equal:

T1 → T2

OR:

T2 → T1
```

The database does **not** necessarily need to execute transactions serially.

It needs the result to be equivalent to a valid serial ordering.

---

## Three Main Anomalies

```text
Non-repeatable read
    ↓
Read same thing twice
    ↓
Different values


Dirty read
    ↓
Read another transaction's
UNCOMMITTED change


Lost update
    ↓
One transaction's write
overwrites another's effective update
```

---

## Serializability Sets

```text
ALL SCHEDULES
      │
      └── VIEW SERIALIZABLE
                │
                └── CONFLICT SERIALIZABLE
                            │
                            └── SERIAL
```

Think:

```text
Serial
   = safest/simplest

Conflict Serializable
   = allows useful interleaving

View Serializable
   = broader, but requires application semantics
```

---

## Concurrency Control

```text
                 CONCURRENCY
                     │
             ┌───────┴───────┐
             ↓               ↓
       Pessimistic       Optimistic
             │               │
       Prevent first     Detect later
             │               │
          Blocking       Validation
                         / Abort
```

---

## Recovery

```text
Crash
  ↓
Read log/checkpoint information
  ↓
Determine committed/uncommitted work
  ↓
REDO necessary changes
  ↓
UNDO necessary changes
  ↓
Restore correct database state
```

---

## The Most Important Mental Model

```text
                    TRANSACTION
                         │
          ┌──────────────┼──────────────┐
          ↓              ↓              ↓
      Atomicity      Isolation      Durability
          │              │              │
          ↓              ↓              ↓
      All or none     Safe           Survives
                      concurrency     crashes
                         │
                         ↓
                  Serializability
                         │
              ┌──────────┴──────────┐
              ↓                     ↓
       Conflict Graph          View Semantics
              │
              ↓
        Cycle? ──────────────┐
          │                  │
         YES                 NO
          ↓                  ↓
    Not Conflict          Conflict
    Serializable          Serializable
```

## The 10 Things to Memorize Before the Exam

1. **ACID = Atomicity, Consistency, Isolation, Durability.**
2. **Atomicity = all or nothing.**
3. **WAL = write the log before writing the corresponding data page.**
4. **Shadow paging = modify copies and switch to them at commit.**
5. **A conflict requires same object + different transactions + at least one write.**
6. **READ-READ does not conflict.**
7. **A dependency graph with a cycle is not conflict serializable.**
8. **A dependency graph without a cycle is conflict serializable.**
9. **Serializable means equivalent to some serial ordering, not necessarily the submission order.**
10. **Concurrency control handles transactions running together; recovery handles crashes.**

# What Comes Next

The next lectures build directly on these concepts.

The key progression is:

```text
Transactions
     ↓
ACID
     ↓
Isolation
     ↓
Conflicting operations
     ↓
Serializability
     ↓
Dependency graphs
     ↓
Concurrency-control protocols
     ↓
Two-Phase Locking
     ↓
Isolation Levels
     ↓
Deadlocks
     ↓
Multiversioning
     ↓
Recovery
```

The major question changes from:

> **"Is this schedule correct?"**

to:

> **"How can the database system enforce a correct schedule while transactions are actually running?"**

That is the purpose of the concurrency-control mechanisms covered next.
