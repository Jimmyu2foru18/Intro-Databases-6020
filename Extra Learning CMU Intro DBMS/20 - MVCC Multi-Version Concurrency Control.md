# Multiversion Concurrency Control (MVCC), Isolation Levels, and Concurrency Control

## 1. Big Picture: Concurrency Control

### Definition

**Concurrency control** is the set of mechanisms a database system uses to allow multiple transactions to execute at the same time while still maintaining the required correctness guarantees.

The major approaches discussed are:

1. **Two-Phase Locking (2PL)** — pessimistic concurrency control
2. **Optimistic Concurrency Control (OCC)** — optimistic concurrency control
3. **Multiversion Concurrency Control (MVCC)** — maintains multiple physical versions of logical records
4. **Timestamp ordering** — uses transaction timestamps to determine visibility/order

### Pessimistic vs. Optimistic

| Approach               | Basic Idea                           | What happens during conflicts?                         |
| ---------------------- | ------------------------------------ | ------------------------------------------------------ |
| **2PL**                | Assume conflicts are likely          | Transactions acquire locks and may wait                |
| **OCC**                | Assume conflicts are rare            | Transactions work independently and validate at commit |
| **MVCC**               | Keep multiple versions of records    | Readers can often read an older visible version        |
| **Timestamp Ordering** | Use timestamps to establish ordering | Operations are allowed/rejected based on timestamps    |

### Important Clarification

**MVCC is not itself a complete concurrency-control protocol.**

MVCC is primarily a **multiversion storage/visibility mechanism**.

You can combine MVCC with:

* 2PL
* OCC
* Timestamp ordering
* Other concurrency-control techniques

Think of MVCC as:

> "How do we store and expose multiple versions?"

while 2PL/OCC/etc. answer:

> "How do we control concurrent transactions?"

---

# 2. Why MVCC Exists

### Definition

**Multiversion Concurrency Control (MVCC)** allows the database to maintain multiple physical versions of the same logical tuple.

A logical tuple is the application-level record identified by something such as a primary key.

For example:

```text
Logical record:
ID = 10
```

Instead of physically overwriting the record every time it changes:

```text
Version 1 → Version 2 → Version 3
```

the database can maintain multiple physical versions.

### Single-Version Database

Traditional single-version storage looks conceptually like:

```text
Record A
   ↓
UPDATE
   ↓
Record A is overwritten
```

### MVCC

MVCC instead does:

```text
Logical A
   │
   ├── A0
   ├── A1
   └── A2
```

Different transactions may see different versions.

### Key Idea

A transaction does **not necessarily read the newest physical version**.

Instead, it determines:

> "Which version is visible to me?"

based on transaction/version metadata.

---

# 3. The Main Benefit of MVCC

## Readers and Writers Do Not Necessarily Block Each Other

One of the most important properties of MVCC is:

> **Writers do not have to block readers, and readers do not have to block writers.**

Consider 2PL.

A reader takes:

```text
S lock
```

A writer needs:

```text
X lock
```

Because:

```text
S × X = incompatible
```

the writer has to wait.

With MVCC:

```text
T1 reads A0

        ↓

T2 creates A1

        ↓

T1 can continue reading A0
```

T1 does not need to wait for T2.

### Comparison

| Situation           | 2PL                         | MVCC                                      |
| ------------------- | --------------------------- | ----------------------------------------- |
| Reader vs writer    | May block                   | Usually can proceed using another version |
| Writer vs reader    | May block                   | Reader can use older version              |
| Multiple versions   | No                          | Yes                                       |
| Storage overhead    | Lower                       | Higher                                    |
| Garbage collection  | Not primarily version-based | Required                                  |
| Historical versions | Usually unavailable         | Can potentially support time travel       |

---

# 4. Logical Tuples vs. Physical Versions

This distinction is extremely important.

### Logical Tuple

The application thinks there is one record:

```text
Customer ID = 42
```

### Physical Versions

The database may actually store:

```text
Customer 42
    │
    ├── Version A
    ├── Version B
    └── Version C
```

The application sees:

```text
Customer 42
```

The DBMS internally manages:

```text
Multiple physical versions of Customer 42
```

### Key Point

MVCC avoids overwriting old physical versions immediately.

That creates:

* Better read concurrency
* Historical versions
* More complicated storage management
* Garbage collection requirements
* More complicated index management

---

# 5. Version Visibility

Every physical version needs metadata that tells the DBMS when it is visible.

A simplified representation is:

```text
Version A0
Begin = 0
End   = 2
```

This means:

```text
Visible from timestamp 0
up to, but not including, timestamp 2
```

So:

```text
0 ≤ transaction timestamp < 2
```

can see the version.

A newer version might be:

```text
Version A1
Begin = 2
End   = ∞
```

Meaning:

```text
2 ≤ transaction timestamp < ∞
```

can see it.

---

# 6. Begin and End Timestamps

### Why Do We Need Both?

Suppose the database starts with:

```text
A0:
begin = 0
end   = ∞
```

Transaction T2 has timestamp 2 and updates A.

Instead of overwriting A0:

```text
A0 → A1
```

the database creates:

```text
A0:
begin = 0
end   = 2

A1:
begin = 2
end   = ∞
```

The end timestamp tells the DBMS when the old version stops being visible.

### Visibility Diagram

```text
Timestamp:

0 ----------- 2 -------------------->

A0: [0, 2)
A1:       [2, ∞)
```

Therefore:

```text
Transaction timestamp = 1 → sees A0
Transaction timestamp = 2 → sees A1
Transaction timestamp = 10 → sees A1
```

---

# 7. Transaction Status Table

Begin/end timestamps alone are not enough.

The DBMS also needs to know whether the transaction that created a version:

* Is still active
* Committed
* Aborted

Therefore, MVCC systems maintain a **transaction status table**.

Conceptually:

| Transaction | Timestamp | Status    |
| ----------- | --------: | --------- |
| T1          |         1 | Active    |
| T2          |         2 | Active    |
| T3          |         3 | Committed |
| T4          |         4 | Aborted   |

This is typically an in-memory global structure.

### Why Is This Needed?

Suppose:

```text
A0:
begin = 0
end = 2

A1:
begin = 2
end = ∞
```

If T2 created A1 but has **not committed**, another transaction cannot simply treat A1 as a committed version.

The transaction status table lets the DBMS determine:

```text
Who created this version?
Did that transaction commit?
```

---

# 8. MVCC Example

Suppose the database starts with:

```text
A0
begin = 0
end   = ∞
```

## Step 1: T1 Starts

```text
T1 timestamp = 1
```

T1 reads A.

Since:

```text
0 ≤ 1 < ∞
```

T1 sees:

```text
A0
```

---

## Step 2: T2 Starts

```text
T2 timestamp = 2
```

T2 writes A.

Instead of changing A0:

```text
A0
```

T2 creates:

```text
A1
```

and updates:

```text
A0.end = 2
A1.begin = 2
A1.end = ∞
```

---

## Step 3: T1 Reads A Again

T1 still has timestamp 1.

Therefore:

```text
A0:
0 ≤ 1 < 2
```

is true.

So T1 sees:

```text
A0
```

again.

### Result

T1 gets a **repeatable view** of A.

Even though T2 created a newer version, T1 continues seeing the version appropriate for its snapshot.

---

# 9. Why MVCC Needs Garbage Collection

MVCC continuously creates versions.

For example:

```text
A0
 ↓
A1
 ↓
A2
 ↓
A3
 ↓
A4
 ↓
A5
```

Eventually, no active transaction needs the older versions.

At that point, keeping them wastes storage.

Therefore MVCC requires **garbage collection (GC)**.

### Goal

Determine:

> Which versions can no longer be visible to any active transaction?

Then:

```text
Old version
     ↓
No transaction can see it
     ↓
Safe to reclaim
```

---

# 10. Time-Travel Queries

Keeping historical versions can provide another feature:

**time-travel queries**

The idea is that a query can ask:

```sql
SELECT *
FROM table
AT TIMESTAMP xyz;
```

Conceptually, this means:

> "Show me what the database looked like at this earlier point in time."

### Why Useful?

This is especially useful for:

* Auditing
* Financial systems
* Historical analysis
* Recovering previous database states

### Tradeoff

Keeping historical versions requires additional storage.

If old versions are never garbage collected:

```text
Storage usage ↑
```

The database can become extremely large.

---

# 11. MVCC and Indexes

MVCC makes indexes more complicated.

The DBMS must answer:

> "Which physical version should this index entry point to?"

### Primary Key Index

Primary key indexes are relatively straightforward.

They generally point toward the **head of the version chain**.

```text
Primary Key Index
      |
      v
   A3
   |
   v
   A2
   |
   v
   A1
```

### Secondary Indexes

Secondary indexes are more complicated because the physical location of the current version can change.

Suppose:

```text
Secondary Index
     |
     v
Physical A2
```

Then a new version is created:

```text
A3
```

Now the head changed:

```text
A3
 ↓
A2
 ↓
A1
```

If the secondary index points directly to the physical location, it may need to be updated.

---

# 12. Version Chains

### Definition

A **version chain** is a linked sequence of physical versions belonging to the same logical tuple.

Example:

```text
A3 → A2 → A1 → A0
```

Each version contains information allowing the DBMS to determine:

* What version came before/after it
* When it became visible
* When it stopped being visible
* Whether the creating transaction committed

### Why Use a Version Chain?

Without a chain, a transaction might have to scan the entire table looking for the correct version.

Instead:

```text
Index
  ↓
Head of version chain
  ↓
Next version
  ↓
Next version
  ↓
...
```

---

# 13. Version Storage Strategies

Three major approaches were discussed:

1. Append-only storage
2. Time-travel storage
3. Delta storage

---

## 13.1 Append-Only Storage

### Definition

When a tuple changes, create a complete copy and append it to the table storage.

Example:

```text
A0

UPDATE A

A0
A1
```

Another update:

```text
A0
A1
A2
```

### Advantage

Simple to implement.

### Disadvantage

Copies the entire tuple even if only one attribute changes.

Suppose:

```text
Tuple = 1,000 attributes
```

but only:

```text
1 attribute changes
```

Append-only storage may copy all 1,000 attributes.

That is expensive.

### PostgreSQL

The lecture identifies PostgreSQL as using an append-only-style MVCC implementation.

---

# 14. Append-Only: Oldest-to-Newest

A version chain might be:

```text
A0 → A1 → A2 → A3
```

The index points to:

```text
A0
```

To find the latest version:

```text
A0
 ↓
A1
 ↓
A2
 ↓
A3
```

The DBMS may need to traverse the chain.

### Problem

If the chain is long:

```text
A0 → A1 → A2 → A3 → ... → A999999
```

finding the current version can become expensive.

---

# 15. Append-Only: Newest-to-Oldest

An alternative is:

```text
A3 → A2 → A1 → A0
```

The index points directly to:

```text
A3
```

This is efficient when most transactions want the newest version.

### Problem

Every time a new version is added:

```text
A3
 ↓
A2
```

becomes:

```text
A4
 ↓
A3
 ↓
A2
```

The index must now point to A4.

If many secondary indexes directly point to physical versions, they may all need updating.

---

# 16. Time-Travel Storage

### Definition

Time-travel storage keeps older versions in a separate storage area.

Conceptually:

```text
Main Table
-----------
Current versions


Time-Travel Table
-----------------
Old versions
```

When updating a tuple:

1. Copy the old version to the time-travel area.
2. Update the current tuple.
3. Maintain the version chain.

### Advantage

Garbage collection can focus on the old-version storage without interfering as much with the main table.

The lecture associated this approach with systems such as SQL Server.

---

# 17. Delta Storage

### Definition

**Delta storage** stores only the changes between versions instead of copying the entire tuple.

Suppose:

```text
Original:

A = 10
B = 20
C = 30
D = 40
```

Only B changes:

```text
B = 25
```

Instead of storing:

```text
A = 10
B = 25
C = 30
D = 40
```

the system stores a delta such as:

```text
B: 20 → 25
```

### Why Delta Storage Is Efficient

If a tuple has:

```text
1,000 attributes
```

and only one changes, the system only needs to store the changed information.

### Lecture Takeaway

Delta storage was presented as the preferred approach for modern MVCC systems.

The lecture associated this style with systems such as:

* MySQL
* Oracle

---

# 18. Delta Storage Example

Suppose the current tuple is:

```text
A3:
x = 10
y = 20
z = 30
```

An update changes:

```text
y = 25
```

The delta storage might record:

```text
A3 → Delta
      y: 20 → 25
```

To reconstruct an older version:

```text
Current version
      ↓
Apply reverse delta
      ↓
Previous version
```

Conceptually:

```text
A3
 ↓
apply delta
 ↓
A2
```

This is similar to applying a patch/diff.

---

# 19. Append-Only vs. Time-Travel vs. Delta Storage

| Feature                   | Append-Only    | Time-Travel                | Delta        |
| ------------------------- | -------------- | -------------------------- | ------------ |
| Full tuple copies         | Yes            | Yes                        | No           |
| Old versions separated    | No             | Yes                        | Usually      |
| Storage efficiency        | Lower          | Better organization        | High         |
| Implementation simplicity | High           | Moderate                   | More complex |
| Garbage collection        | More intrusive | Easier to isolate old data | Efficient    |
| Modern preference         | Less common    | Less common                | Common       |
| Lecture example           | PostgreSQL     | SQL Server                 | MySQL/Oracle |

### Exam Tip

Remember:

```text
Append-only = copy whole tuple

Time-travel = old copies in separate storage

Delta = store only changes
```

---

# 20. Garbage Collection in MVCC

### Goal

Remove versions that cannot possibly be observed by any active transaction.

MVCC tracks transaction timestamps and statuses to determine a **visibility threshold/watermark**.

Conceptually:

```text
Oldest active transaction timestamp
             |
             v
        Watermark
             |
             v
Versions older than this may be reclaimable
```

---

# 21. Garbage Collection Example

Suppose active transactions are:

```text
T1 = timestamp 12
T2 = timestamp 25
```

The oldest active timestamp is:

```text
12
```

Suppose we have old versions:

```text
A100: begin = 1
B100: begin = 5
C100: begin = 8
D100: begin = 15
```

Transactions with timestamps:

```text
12 and 25
```

cannot see versions that are already outside their visibility requirements.

Therefore versions older than the relevant watermark can potentially be reclaimed.

### Important

The actual decision depends on:

* Version begin/end timestamps
* Transaction status
* Active transaction timestamps
* Whether an older transaction could still need the version

---

# 22. Garbage Collection Strategies

Three approaches were discussed:

1. Tuple-level garbage collection
2. Cooperative garbage collection
3. Transaction-level garbage collection

---

## 22.1 Dedicated Vacuum / Tuple-Level GC

A background worker scans storage and removes obsolete versions.

Conceptually:

```text
Background worker
       ↓
Scan pages
       ↓
Find obsolete versions
       ↓
Delete/reclaim them
```

### Problem

Scanning the entire database is expensive.

You might bring many pages into memory just to discover:

> "Nothing here needs cleaning."

This can pollute the buffer pool.

---

# 23. PostgreSQL Vacuum Optimization

PostgreSQL maintains information indicating which pages have been modified since the previous vacuum.

Conceptually:

```text
Modified-page bitmap

Page 1 → unchanged
Page 2 → modified
Page 3 → unchanged
Page 4 → modified
```

Vacuum can focus on:

```text
Page 2
Page 4
```

instead of scanning everything.

### Benefit

Less unnecessary disk I/O and less buffer-pool pollution.

---

# 24. Cooperative Garbage Collection

Instead of a dedicated worker doing all cleanup, transactions can clean obsolete versions while they are already traversing version chains.

Example:

```text
Transaction reads A
      ↓
Follows version chain
      ↓
Finds obsolete version
      ↓
Cleans it up
```

### Advantage

The transaction is already accessing the data.

### Disadvantage

A read operation may now physically modify database structures.

Logically:

```text
SELECT
```

is read-only.

Physically:

```text
SELECT
```

may perform cleanup work.

Therefore it may need **physical latches**, even though it does not acquire logical transaction locks for the data being read.

---

# 25. Logical Locks vs. Physical Latches

This distinction is extremely important.

### Logical Lock

Protects:

```text
Transaction-level database semantics
```

Examples:

```text
S lock
X lock
IS
IX
SIX
```

### Physical Latch

Protects:

```text
In-memory data structures
```

Examples:

* B+ tree pages
* Tuple headers
* Version-chain pointers
* Buffer frames

### Example

A SELECT may clean an old version.

It does not logically modify the user's database state.

But it may physically update:

```text
Version pointer
```

Therefore:

```text
Logical lock → not necessarily required
Physical latch → required
```

### Common Exam Mistake

Do **not** treat locks and latches as the same thing.

---

# 26. Transaction-Level Garbage Collection

Transactions can track the versions they invalidate.

Example:

```text
T1 creates A3

A3 invalidates A2
```

The transaction records:

```text
T1:
invalidated = {A2}
```

If T1 commits, the garbage collector already knows where A2 is.

### Advantage

Instead of:

```text
Search entire database
```

the system can do:

```text
Transaction metadata
      ↓
Known invalidated versions
      ↓
Check visibility
      ↓
Reclaim
```

---

# 27. "Dusty Corners"

Cooperative garbage collection can miss versions that nobody happens to read.

For example:

```text
Page B
  ↓
Old versions
  ↓
Nobody reads B
```

If cleanup only happens during reads, those versions remain.

These unused areas were described in the lecture as **"dusty corners."**

Therefore, systems may still need periodic background cleanup.

### Practical Strategy

Use both:

```text
Cooperative cleanup
+
Periodic vacuum
```

---

# 28. Deadlock Detection

MVCC does not eliminate every need for locking.

When MVCC is combined with 2PL, locks can still create deadlocks.

### Example

```text
T1:
X-lock(A)
wait for B

T2:
X-lock(B)
wait for A
```

This creates:

```text
T1 → waiting for T2
T2 → waiting for T1
```

Therefore:

```text
Deadlock
```

---

# 29. Deadlock Victim Selection

When a deadlock is detected, the DBMS chooses one transaction to abort.

Possible factors include:

* Transaction age
* Amount of work already completed
* Number of locks held
* Cost of rolling back
* Potential cascading effects

### Goal

Choose a victim whose abortion minimizes wasted work and cleanup cost.

The lecture mentioned a simple "newest transaction" policy as a possible strategy in some systems.

---

# 30. Savepoints

### Definition

A **savepoint** is an application-defined checkpoint inside a transaction.

Instead of rolling back the entire transaction:

```text
BEGIN

Operation 1
Operation 2

SAVEPOINT S

Operation 3
Operation 4

ROLLBACK TO S
```

only the work after S is undone.

### Important

Savepoints are **not the same thing as lock granularity**.

They control rollback scope, not whether locks are on:

* Database
* Table
* Page
* Tuple
* Attribute

---

# 31. Deadlock Prevention

Two timestamp-based approaches were discussed:

1. Wait-die
2. Wound-wait

Transactions receive timestamps when they start.

Smaller timestamp:

```text
Older transaction
```

Larger timestamp:

```text
Younger transaction
```

---

# 32. Wait-Die

### Rule

```text
Old requests lock held by young
→ Old waits

Young requests lock held by old
→ Young aborts
```

Mnemonic:

> **Old waits; young dies.**

### Example

```text
T1 = old
T2 = young
```

If T1 wants T2's lock:

```text
T1 waits
```

If T2 wants T1's lock:

```text
T2 aborts
```

---

# 33. Wound-Wait

### Rule

```text
Old requests lock held by young
→ Old aborts/wounds young

Young requests lock held by old
→ Young waits
```

Mnemonic:

> **Old wounds; young waits.**

### Comparison

| Situation   | Wait-Die                | Wound-Wait                       |
| ----------- | ----------------------- | -------------------------------- |
| Old → Young | Old waits               | Young aborts                     |
| Young → Old | Young aborts            | Young waits                      |
| Principle   | Older transactions wait | Older transactions have priority |

Both prevent deadlock by enforcing an ordering based on transaction age.

---

# 34. Avoiding Starvation

When a transaction aborts and restarts, it should retain its original timestamp.

Otherwise:

```text
Abort
 ↓
Restart
 ↓
Gets new timestamp
 ↓
Always becomes "young"
 ↓
Repeatedly dies
```

Keeping the original timestamp helps prevent starvation.

---

# 35. Lock Granularity

Locks can exist at different levels:

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

### Fine-Grained Locks

Example:

```text
One tuple
```

Advantages:

* More concurrency

Disadvantages:

* More lock metadata
* More lock-management overhead

### Coarse-Grained Locks

Example:

```text
Entire table
```

Advantages:

* Fewer locks
* Simpler management

Disadvantages:

* Less concurrency

---

# 36. Intention Locks

Intention locks allow a DBMS to combine hierarchical locking with fine-grained locks.

Main types:

```text
IS = Intention Shared
IX = Intention Exclusive
SIX = Shared + Intention Exclusive
```

### Meaning

**IS**

> "I intend to acquire shared locks somewhere below this node."

**IX**

> "I intend to acquire exclusive locks somewhere below this node."

**SIX**

> "I have a shared lock at this level and intend to acquire exclusive locks below."

---

# 37. Intention Lock Example

Suppose T1 wants to read one tuple.

It can acquire:

```text
IS on table
S on tuple
```

T2 wants to update a different tuple:

```text
IX on table
X on tuple
```

The table-level locks:

```text
IS
IX
```

are compatible.

Therefore both transactions can operate concurrently.

---

# 38. SIX Example

Suppose T1 wants to:

1. Read an entire table
2. Update one tuple

It can use:

```text
SIX(table)
X(tuple)
```

Another transaction wanting to read one tuple can use:

```text
IS(table)
S(tuple)
```

These can be compatible.

But another transaction wanting:

```text
S(table)
```

would conflict with SIX.

---

# 39. Lock Escalation

If a transaction acquires a huge number of fine-grained locks, the DBMS may replace them with a coarse-grained lock.

Example:

```text
IS(table)
+
100,000 S(tuple) locks
```

could become:

```text
S(table)
```

This is called **lock escalation**.

---

# 40. SQL Locking Hints

A common example is:

```sql
SELECT *
FROM Accounts
WHERE id = 10
FOR UPDATE;
```

### Meaning

Read the row and acquire the appropriate lock so another transaction cannot modify it before the current transaction performs its update.

Useful for:

```text
Read
 ↓
Modify
 ↓
Write
```

workflows.

### PostgreSQL Lock Modes

Examples include:

```sql
FOR UPDATE
FOR NO KEY UPDATE
FOR SHARE
FOR KEY SHARE
```

### SKIP LOCKED

Example:

```sql
SELECT *
FROM Jobs
WHERE status = 'pending'
FOR UPDATE SKIP LOCKED;
```

Conceptually:

> "Give me rows I can lock immediately; skip rows currently locked by another transaction."

Useful for:

* Job queues
* Worker systems
* Concurrent task processing

### Warning

`SKIP LOCKED` can produce an incomplete or changing view of available rows.

---

# 41. Optimistic Concurrency Control Review

### Definition

**Optimistic Concurrency Control (OCC)** assumes conflicts are relatively uncommon.

Transactions perform work privately and validate before committing.

Conceptually:

```text
Transaction
    ↓
Read
    ↓
Private changes
    ↓
Validation
    ↓
Commit or Abort
```

### Compared with 2PL

```text
2PL:
Acquire locks
    ↓
Do work
    ↓
Wait if necessary


OCC:
Do work
    ↓
Validate later
    ↓
Abort if conflict exists
```

---

# 42. OCC Validation

The simplest serial validation approach may briefly stop other validation activity while checking a transaction.

This does **not necessarily mean stopping the entire database for a long period**.

If:

* Transactions are short
* Read/write sets are small
* Metadata is in memory

the critical validation section can be extremely short.

### Problem

If transactions run for hours and have huge read/write sets:

```text
Validation
    ↓
Large amount of work
    ↓
More serialization
    ↓
Reduced concurrency
```

---

# 43. Backward vs. Forward Validation

### Backward Validation

When validating transaction T:

> Check transactions that committed after T started.

Example:

```text
T starts
 ↓
T does work
 ↓
Other transactions commit
 ↓
T validates
 ↓
Check those completed transactions
```

### Forward Validation

When a transaction commits:

> Check active transactions that may conflict with the transaction committing.

### Comparison

| Feature            | Backward Validation               | Forward Validation             |
| ------------------ | --------------------------------- | ------------------------------ |
| Checks             | Previously committed transactions | Currently active transactions  |
| Timing             | During validation                 | During commit                  |
| Engineering        | Often simpler                     | More complicated               |
| Interference       | Less with active work             | Can affect active transactions |
| Lecture preference | Often favored                     | More complicated               |

---

# 44. Transaction Status Table and OCC

A transaction table can track:

```text
Waiting
Read Phase
Validation Phase
Write Phase
Committed
Aborted
```

This can be faster than repeatedly inspecting every tuple involved in the transaction.

### Why?

Suppose a read set contains millions of tuples.

Checking every tuple individually may require:

```text
Disk I/O
```

Some tuples may have already been evicted from memory.

A transaction status table can remain in memory.

---

# 45. OCC Strengths and Weaknesses

### OCC Works Well When

* Conflicts are rare
* Transactions are mostly read-only
* Transactions are short
* Read/write sets are small

### OCC Performs Poorly When

* Contention is high
* Transactions do large amounts of work
* Conflicts are discovered only near commit

Example:

```text
1,000,000 operations
       ↓
Validation
       ↓
Conflict
       ↓
Abort
```

All that work was wasted.

### 2PL Alternative

2PL may detect the conflict earlier:

```text
Need lock
   ↓
Blocked
   ↓
Wait
```

instead of:

```text
Do huge amount of work
   ↓
Discover conflict
   ↓
Abort
```

---

# 46. OCC Private Workspace Problem

OCC may require copying tuples into a private workspace.

Suppose:

```text
Tuple = 1,000 attributes
```

but the transaction changes:

```text
1 attribute
```

Copying the entire tuple is wasteful.

MVCC can instead use delta-style storage:

```text
Only changed attribute
```

This is one reason multiversion systems can be attractive.

---

# 47. Phantom Reads

### Definition

A **phantom read** occurs when a transaction executes the same range/query more than once and sees a different set of matching rows because another transaction inserted or deleted rows.

### Example

Table:

```text
People
-------------------
id | name | status
```

T1:

```sql
SELECT COUNT(*)
FROM People
WHERE status = 'paid';
```

Result:

```text
99
```

T2 inserts:

```text
status = 'paid'
```

and commits.

T1 runs the same query again:

```text
SELECT COUNT(*)
FROM People
WHERE status = 'paid';
```

Result:

```text
100
```

The additional row is the **phantom**.

---

# 48. Why Row Locks Alone Cannot Prevent Phantoms

Suppose T1 reads:

```text
status = 'paid'
```

Existing rows can be locked.

But what about a row that does not exist yet?

You cannot lock:

```text
ID = 5000
```

if that row does not exist.

Therefore:

```text
Row locks
```

alone cannot prevent a new matching row from appearing.

---

# 49. Four Approaches to Phantom Protection

## Approach 1: Coarse Locking

Lock:

```text
Entire table
```

Then no other transaction can insert/delete conflicting rows.

### Advantage

Simple.

### Disadvantage

Very poor concurrency.

---

## Approach 2: Re-Execute Scans

Record the predicate:

```sql
WHERE status = 'paid'
```

Then re-run the scan during validation.

Conceptually:

```text
Initial scan
    ↓
Remember what matched
    ↓
Transaction work
    ↓
Re-run scan
    ↓
Compare
    ↓
Commit / Abort
```

This approach was associated with systems such as **Hekaton**.

---

## Approach 3: Predicate Locking

Conceptually lock the **predicate itself**.

For:

```sql
WHERE status = 'paid'
```

the system locks the set:

```text
All rows where status = paid
```

This includes potential future rows.

### Problem

Predicates can be extremely complex.

Think of each predicate as a region in a multidimensional space:

```text
status
  ↑
  |
paid|       █████
    |       █████
    |______________→ other attributes
```

Two predicates may overlap in complicated ways.

Exact predicate locking is difficult and expensive.

---

## Approach 4: Index Locking

Use the database's indexes to represent:

* Existing keys
* Gaps
* Key ranges

This is a practical approximation of predicate locking and is common in real systems.

---

# 50. Gap Locks

Suppose an index contains:

```text
14
16
```

There is a gap:

```text
(14, 16)
```

A **gap lock** protects that range.

Therefore another transaction cannot insert:

```text
15
```

or:

```text
15.1
```

while the gap is protected.

---

# 51. Key-Range Locks

A **key-range lock** protects an explicit range.

For example:

```text
[14,16)
```

Depending on the system, the endpoints can have different inclusion rules.

The lock manager tracks:

```text
Start key
End key
Inclusivity
```

This lets the system protect ranges even when some values do not currently exist.

---

# 52. Index Locking and Hierarchical Locks

Index locking can be combined with intention locks.

For example:

```text
Index/page
   IX
    |
    +---- X on key/range
```

Another transaction can potentially operate on a different range:

```text
Index/page
   IX
    |
    +---- X on different key/range
```

Because:

```text
IX + IX
```

can be compatible.

This provides concurrency while still protecting the relevant ranges.

---

# 53. Precision Locking

A practical approximation of predicate locking is sometimes called **precision locking**.

Instead of reasoning about every possible value in the entire predicate space, the system compares the transaction's read/write sets.

The lecture mentioned systems such as:

* CedarDB
* Umbra
* HyPer

as examples of systems exploring this style.

### Key Idea

Determine whether the actual rows touched by two transactions overlap in a way that would violate serializability.

---

# 54. Re-Execution / Reconnaissance

Some systems use a two-stage approach.

### Phase 1: Reconnaissance

Execute a query to determine what data it would touch.

```text
Query
 ↓
Record scan set
```

### Phase 2: Actual Execution

Perform the actual changes.

```text
Actual execution
 ↓
Compare against reconnaissance
 ↓
If consistent → commit
If different → abort
```

The lecture associated this idea with systems such as:

* DynamoDB
* Fauna

---

# 55. Dirty Reads

A dirty read occurs when:

```text
T1 writes data
 ↓
T1 has not committed
 ↓
T2 reads T1's uncommitted data
```

If T1 later aborts:

```text
T2 read something that never officially existed
```

Under serializable execution, T2 generally cannot commit based on such an invalid dependency.

---

# 56. Isolation Levels

An **isolation level** specifies how strongly the DBMS protects transactions from interference caused by concurrent transactions.

The classic four SQL isolation levels are:

1. Serializable
2. Repeatable Read
3. Read Committed
4. Read Uncommitted

---

# 57. Classic Isolation-Level Comparison

| Isolation Level      | Dirty Reads | Non-Repeatable Reads | Phantoms  |
| -------------------- | ----------- | -------------------- | --------- |
| **Serializable**     | No          | No                   | No        |
| **Repeatable Read**  | No          | No                   | May occur |
| **Read Committed**   | No          | May occur            | May occur |
| **Read Uncommitted** | May occur   | May occur            | May occur |

### Important

"May occur" does **not** mean the anomaly always occurs.

The transactions must actually execute in a conflicting way for the anomaly to appear.

---

# 58. Serializable

### Definition

Transactions behave as though they executed in some serial order.

Conceptually:

```text
T1
 ↓
T2
 ↓
T3
```

or:

```text
T2
 ↓
T1
 ↓
T3
```

even if the actual execution was concurrent.

### Prevents

* Dirty reads
* Non-repeatable reads
* Phantoms
* Lost updates

---

# 59. Repeatable Read

Guarantees that data already read does not change underneath the transaction in the classic 2PL framing.

Prevents:

* Dirty reads
* Non-repeatable reads

But classic repeatable read can allow:

* Phantoms

unless additional mechanisms are used.

---

# 60. Read Committed

A transaction only sees committed data.

Prevents:

```text
Dirty reads
```

But can allow:

```text
Non-repeatable reads
Phantoms
```

Example:

```text
T1 reads A = 100

T2 changes A = 200
T2 commits

T1 reads A again

→ 200
```

---

# 61. Read Uncommitted

The weakest classic isolation level.

A transaction may read uncommitted changes.

Potential anomalies include:

* Dirty reads
* Non-repeatable reads
* Phantoms

---

# 62. Implementing Isolation Levels with 2PL

The lecture presented the following conceptual implementation.

### Serializable

Use strong/strict 2PL plus phantom protection:

```text
2PL
+
Predicate/index/range protection
```

---

### Repeatable Read

Use locking to maintain repeatable reads but omit additional phantom protection.

---

### Read Committed

Shared locks can be released after the read completes.

Conceptually:

```text
Acquire S lock
    ↓
Read
    ↓
Release S lock
```

Exclusive locks are held longer to prevent lost updates.

---

### Read Uncommitted

Reads generally do not acquire shared locks.

Writes still require appropriate protection.

---

# 63. Snapshot Isolation

### Definition

**Snapshot Isolation (SI)** gives each transaction a consistent snapshot of committed data.

A transaction sees:

> The state produced by transactions committed before its snapshot began.

### Important

Snapshot isolation is **not simply another point on the classic isolation-level ladder**.

The lecture described it as a separate/orthogonal track.

Conceptually:

```text
Classic locking isolation:

Read Uncommitted
       ↓
Read Committed
       ↓
Repeatable Read
       ↓
Serializable


Multiversion track:

Snapshot Isolation
       ↓
different guarantees/anomalies
```

---

# 64. Snapshot Isolation and Consistent Snapshots

Suppose:

```text
T1 updates A
T1 updates B
```

T2 cannot see:

```text
New A
Old B
```

if both changes are part of the same committed transaction.

Instead, T2 sees a consistent committed state.

This prevents **torn reads**.

---

# 65. First-Writer-Wins

A basic snapshot-isolation rule is:

> **First writer wins.**

Suppose:

```text
T1 writes A
T2 later tries to write A
```

If T1's version was established first, T2 cannot simply overwrite it.

T2 must abort.

Conceptually:

```text
T1 writes A
   ↓
T2 attempts write A
   ↓
Conflict
   ↓
T2 aborts
```

This differs from "last writer wins."

---

# 66. Write Skew

Snapshot isolation has an important anomaly called **write skew**.

### Definition

**Write skew** occurs when two transactions read a consistent snapshot, make decisions based on that snapshot, and then update different records in a way that would be impossible under a truly serial execution.

---

# 67. Marble Example of Write Skew

Suppose there are four marbles:

```text
Black Black White White
```

T1:

> Change every white marble to black.

T2:

> Change every black marble to white.

Both transactions start at the same time.

Each sees:

```text
2 black
2 white
```

T1 decides:

```text
White → Black
```

T2 decides:

```text
Black → White
```

Because snapshot isolation allows both to read the same snapshot and then modify different records, the final state can be:

```text
White White Black Black
```

instead of what would happen under serial execution.

---

# 68. Why 2PL Prevents This Write Skew

Under 2PL:

T1 reads the relevant rows:

```text
S locks
```

T2 also wants to modify those rows:

```text
X locks
```

The locks conflict.

Therefore one transaction must wait.

Snapshot isolation does not necessarily create that reader/writer blocking because readers can use versions.

---

# 69. Snapshot Isolation vs. Serializable

| Property                             | Snapshot Isolation | Serializable              |
| ------------------------------------ | ------------------ | ------------------------- |
| Consistent snapshot                  | Yes                | Yes                       |
| Dirty reads                          | No                 | No                        |
| First-writer-wins                    | Yes                | Depends on implementation |
| Readers block writers                | Usually no         | Depends on implementation |
| Write skew                           | Can occur          | No                        |
| Guarantees serial execution behavior | No                 | Yes                       |

### Exam Tip

The biggest distinction to remember:

> **Snapshot isolation is not necessarily serializable because write skew can occur.**

---

# 70. PostgreSQL MVCC Example

PostgreSQL physically stores MVCC metadata in tuples.

Important fields include:

```text
xmin
xmax
ctid
```

---

# 71. PostgreSQL `xmin`

`xmin` identifies the transaction associated with creating the tuple version.

Example:

```text
xmin = 1396
```

Conceptually:

```text
Transaction 1396 created this version.
```

---

# 72. PostgreSQL `xmax`

`xmax` identifies the transaction that invalidated/deleted the version.

A value of:

```text
xmax = 0
```

can indicate that there is currently no transaction recorded as ending that version.

Conceptually:

```text
xmin = creator
xmax = transaction that invalidates it
```

---

# 73. PostgreSQL `ctid`

`ctid` identifies the physical location of a tuple.

Conceptually:

```text
(page number, slot number)
```

Example:

```text
(0, 2)
```

means approximately:

```text
Page 0
Slot 2
```

Unlike transaction timestamps, this is a physical-location identifier.

### Important

A tuple's physical location can change.

Therefore, applications should not treat `ctid` as a permanent logical identifier.

---

# 74. PostgreSQL MVCC Example

Suppose a tuple initially has:

```text
xmin = 1396
xmax = 0
```

A transaction updates it.

The old version may now show:

```text
xmin = 1396
xmax = 1397
```

while a new version is created with:

```text
xmin = 1397
xmax = 0
```

Conceptually:

```text
Old version
xmin=1396
xmax=1397

       ↓

New version
xmin=1397
xmax=0
```

This demonstrates how PostgreSQL implements tuple versioning.

---

# 75. PostgreSQL Read Committed Example

Suppose:

```text
Initial value = 100
```

T1 starts and updates:

```text
100 → 101
```

but has not committed.

T2 reads the value.

T2 sees:

```text
100
```

because T1's update is uncommitted.

Now T1 commits.

Under PostgreSQL's default **Read Committed** behavior, T2 can subsequently see the newly committed value when it performs a new statement.

Therefore:

```text
First read → 100
After T1 commits
Second read → 101
```

This demonstrates why Read Committed does not guarantee repeatable reads.

---

# 76. MySQL Repeatable Read Example

The lecture contrasted this with MySQL.

Suppose:

```text
Initial value = 100
```

T1 updates:

```text
100 → 101
```

but does not commit.

T2 starts and reads:

```text
100
```

T1 commits.

T2 reads again.

Under MySQL's default repeatable-read behavior, T2 continues to see:

```text
100
```

because its snapshot remains consistent.

---

# 77. PostgreSQL vs. MySQL Isolation Behavior

| Feature                                                            | PostgreSQL               | MySQL                             |
| ------------------------------------------------------------------ | ------------------------ | --------------------------------- |
| MVCC                                                               | Yes                      | Yes                               |
| Lecture's default                                                  | Read Committed           | Repeatable Read                   |
| Uncommitted changes visible normally                               | No                       | No                                |
| New committed data visible to later statements in same transaction | Yes under Read Committed | Snapshot behavior differs         |
| MVCC metadata discussed                                            | `xmin`, `xmax`, `ctid`   | Different internal implementation |

### Exam Tip

Do not assume:

> "MVCC means repeatable read."

MVCC can support different isolation behaviors depending on the database system and protocol.

---

# 78. PostgreSQL and Read Uncommitted

The lecture demonstrated that PostgreSQL does not provide truly weaker-than-Read-Committed behavior when `READ UNCOMMITTED` is requested.

Conceptually:

```sql
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
```

PostgreSQL effectively behaves as:

```text
Read Committed
```

rather than exposing uncommitted versions.

### Important

This is a DBMS-specific implementation detail.

---

# 79. PostgreSQL Serializable Example

A transaction can explicitly request serializable isolation:

```sql
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SELECT *
FROM transaction_demo;

COMMIT;
```

At this isolation level, PostgreSQL uses stronger concurrency-control mechanisms to detect/prevent serialization anomalies.

---

# 80. Deadlock Detection in PostgreSQL

A deadlock can occur even with MVCC because logical locks are still used.

Example:

```text
T1:
X-lock A
 ↓
tries X-lock B

T2:
X-lock B
 ↓
tries X-lock A
```

Result:

```text
T1 waits for T2
T2 waits for T1
```

The deadlock detector eventually chooses one transaction to abort.

Once it aborts:

```text
Locks released
     ↓
Other transaction continues
```

---

# 81. MVCC with 2PL

MVCC and 2PL can coexist.

Suppose:

```text
T1 reads A
T1 writes A
```

T1 creates a new version.

T2 can potentially read an older committed version:

```text
T2 → A0
T1 → A1
```

But when T2 tries to **write** A, 2PL can require an exclusive logical lock.

If T1 already has that lock:

```text
T2 waits
```

After T1 commits:

```text
T1 releases X lock
       ↓
T2 acquires X lock
       ↓
T2 creates new version
```

### Important

MVCC changes **what versions readers can see**.

2PL still controls **logical write conflicts**.

---

# 82. MVCC and Write Conflicts

Suppose:

```text
A0
```

T1 creates:

```text
A1
```

T2 wants to create:

```text
A2
```

If T1 has not committed, T2 cannot simply overwrite/continue from T1's uncommitted version.

The system must detect the conflict.

Possible result:

```text
T2 aborts
```

or, under 2PL:

```text
T2 waits
```

depending on the concurrency-control protocol.

---

# 83. Secondary Index Challenges

Secondary indexes are one of the hardest parts of MVCC implementation.

Suppose:

```text
Secondary index
     |
     v
Physical record location
```

If the record's current version moves:

```text
A1 → A2
```

the index may need to be updated.

If there are many secondary indexes:

```text
Index 1
Index 2
Index 3
Index 4
...
```

one tuple update can cause many physical index changes.

---

# 84. Logical Pointers

One solution is to use a **logical pointer** instead of a direct physical pointer.

Conceptually:

```text
Secondary Index
      |
      v
Logical ID
      |
      v
Primary Key Index
      |
      v
Current version
```

This adds an extra lookup.

### Advantage

Updating the head of the version chain does not require updating every secondary index.

---

# 85. MySQL's Logical-Reference Strategy

The lecture explained that MySQL uses the primary key as the value referenced by secondary indexes.

Conceptually:

```text
Secondary Index
      |
      v
Primary Key = 42
      |
      v
Primary Key Index
      |
      v
Version chain
```

Therefore, if the physical version changes:

```text
A1 → A2
```

the secondary index can continue pointing to:

```text
Primary Key = 42
```

without needing to know the physical location of the current version.

### Major Advantage

Many secondary indexes do not need to be updated when the physical head changes.

---

# 86. PostgreSQL Secondary Indexes

PostgreSQL's append-only MVCC design creates additional index-management work.

Because version chains can span multiple pages, PostgreSQL may maintain multiple index references to different versions/locations to make version-chain traversal faster.

### Tradeoff

```text
More index references
       ↓
Faster reads/scans
       ↓
More cleanup work
       ↓
Slower/more complicated deletes
```

Therefore:

> Faster scans can come at the cost of more complicated garbage collection and index maintenance.

---

# 87. Duplicate Keys in Versioned Indexes

MVCC can create situations where logically the same key exists in multiple physical versions.

For example:

```text
A old version
A new version
```

The index may need to physically distinguish them.

One approach is to augment the index key with additional information such as:

```text
Logical key + record/version ID
```

So physically:

```text
(A, version1)
(A, version2)
```

are different keys even though logically they represent the same key.

---

# 88. Deletes in MVCC

Deleting a tuple is more complicated than simply physically erasing it.

Why?

Because an active transaction may still need to see the old version.

Therefore, deletion usually happens in two conceptual stages:

```text
Logical delete
       ↓
Version becomes invisible to appropriate transactions
       ↓
Garbage collection
       ↓
Physical deletion
```

---

# 89. Tombstones

One method for representing deletion is a **tombstone**.

A tombstone is a special version indicating:

> "This logical tuple has been deleted."

Conceptually:

```text
A2
 ↓
A1
 ↓
TOMBSTONE
```

When a transaction encounters the tombstone, it knows the logical record has been deleted.

---

# 90. Delete Flag

Another approach is to store a deletion indicator in the tuple/version metadata.

For example:

```text
deleted = true
```

Then the DBMS uses transaction visibility rules to determine whether a transaction should see the tuple.

---

# 91. Primary-Key Updates

If a primary key changes:

```text
ID = 1
```

to:

```text
ID = 2
```

the lecture's conceptual approach is:

```text
DELETE ID=1
+
INSERT ID=2
```

This simplifies index handling.

### Why?

The primary key identifies the logical tuple.

Changing it effectively changes the identity represented by the index.

---

# 92. Special Case: Delete Then Reinsert Same Key

Suppose:

```text
T1 deletes A
T1 commits
```

Then:

```text
T2 inserts A
```

Physically, multiple versions involving key A may still exist.

Logically, however:

```text
Old A
```

and:

```text
New A
```

can represent different logical lifetimes.

The index/versioning system must distinguish these cases correctly so older transactions can still see the appropriate historical version.

---

# 93. Why MVCC Affects the Entire DBMS

Choosing MVCC is not an isolated storage decision.

It affects:

```text
Storage
   ↓
Tuple format
   ↓
Version chains
   ↓
Indexes
   ↓
Query execution
   ↓
Garbage collection
   ↓
Transaction management
   ↓
Concurrency control
```

Therefore:

> MVCC is a system-wide design choice.

---

# 94. 2PL vs. OCC vs. MVCC

| Feature                | 2PL                          | OCC                          | MVCC                              |
| ---------------------- | ---------------------------- | ---------------------------- | --------------------------------- |
| Main idea              | Lock before conflicting work | Validate after work          | Store multiple versions           |
| Type                   | Concurrency-control protocol | Concurrency-control protocol | Storage/visibility technique      |
| Readers block writers? | Often                        | Depends                      | Usually not                       |
| Writers block readers? | Often                        | Depends                      | Usually not                       |
| Multiple versions      | No requirement               | Private copies may exist     | Yes                               |
| Deadlocks              | Possible                     | Generally not lock-based     | Possible if combined with locking |
| High contention        | Can perform better           | Can perform poorly           | Depends on protocol               |
| Low contention         | Can work well                | Very good                    | Good                              |
| Storage overhead       | Lower                        | Private workspace            | Higher                            |
| Garbage collection     | Not version-based            | Private workspace cleanup    | Essential                         |

---

# 95. Pessimistic vs. Optimistic Concurrency

### Pessimistic

Assume:

```text
Conflicts are likely
```

Therefore:

```text
Lock early
↓
Block conflicting work
```

Example:

```text
2PL
```

### Optimistic

Assume:

```text
Conflicts are rare
```

Therefore:

```text
Do work
↓
Validate
↓
Abort if necessary
```

Example:

```text
OCC
```

### MVCC

MVCC changes the storage model:

```text
Multiple versions
↓
Different transactions can see different versions
```

It can support either style of concurrency control.

---

# 96. Four Classic Isolation Levels — Memory Table

| Isolation        | Dirty Read | Non-Repeatable Read | Phantom |
| ---------------- | ---------- | ------------------- | ------- |
| Read Uncommitted | ✓          | ✓                   | ✓       |
| Read Committed   | ✗          | ✓                   | ✓       |
| Repeatable Read  | ✗          | ✗                   | ✓*      |
| Serializable     | ✗          | ✗                   | ✗       |

`*` Classic 2PL interpretation.

### Memory Pattern

As isolation becomes stronger:

```text
Read Uncommitted
       ↓
Read Committed
       ↓
Repeatable Read
       ↓
Serializable
```

you generally get:

```text
More correctness
Less concurrency
More overhead
```

---

# 97. Cursor Stability

The lecture also discussed **Cursor Stability**, associated with systems such as IBM DB2.

A cursor scans records.

The DBMS can hold a shared/read lock on the current row or range while the cursor is using it.

Conceptually:

```text
Cursor
 ↓
Row 1 → locked
 ↓
Move
 ↓
Row 1 → unlock
Row 2 → locked
```

### Purpose

Prevent problematic modifications while the cursor is actively using a row/range.

### Important

Cursor Stability does not necessarily guarantee that a later complete rescan will return exactly the same result.

---

# 98. Strict Serializability

### Definition

**Strict serializability** is stronger than ordinary serializability.

Transactions must appear to execute:

1. In a serial order
2. Consistently with real-time ordering

Conceptually:

```text
T1 completes before T2 starts
```

Then the serial history must respect:

```text
T1 → T2
```

The lecture connected this concept with systems such as:

* Google Spanner
* CockroachDB
* Other systems designed around strong serializable guarantees

---

# 99. Isolation-Level Defaults

Most production systems do not necessarily use full serializable isolation by default.

Why?

Because stronger isolation can introduce:

* More locking
* More waiting
* More validation
* More index/range protection
* More overhead

A DBMS that always performed expensive serializable checks could become unnecessarily slow for workloads that do not require them.

### Important

The appropriate isolation level depends on the workload.

---

# 100. Main MVCC Design Decisions

When building an MVCC database, you must decide:

### 1. Concurrency-Control Protocol

Will the system use:

```text
2PL?
OCC?
Timestamp ordering?
Combination?
```

### 2. Version Storage

Will versions use:

```text
Append-only?
Time-travel storage?
Delta storage?
```

### 3. Version Ordering

Will the chain be:

```text
Oldest → Newest
```

or:

```text
Newest → Oldest
```

### 4. Garbage Collection

How will obsolete versions be removed?

```text
Background vacuum?
Cooperative cleanup?
Transaction-level tracking?
```

### 5. Index Management

How do:

```text
Primary indexes
Secondary indexes
```

reference version chains?

### 6. Deletes

How are deletions represented?

```text
Delete flag?
Tombstone?
```

---

# 101. Complete MVCC Architecture

A simplified MVCC system can be visualized as:

```text
                  Transaction
                       |
                       v
              Transaction Timestamp
                       |
                       v
                Query Executor
                       |
                       v
                    Index
                       |
                       v
              Version Chain Head
                       |
          +------------+------------+
          |            |            |
          v            v            v
         A3           A2           A1
          |            |            |
       metadata     metadata     metadata
          |            |            |
          +------------+------------+
                       |
                       v
              Visibility Check
                       |
                       v
             Transaction Status
                  Table
                       |
                       v
              Visible Version
```

---

# 102. Full MVCC Read Process

When a transaction reads a tuple:

### Step 1

Use an index to find the logical tuple.

```text
Index
 ↓
Logical key
```

### Step 2

Find the version-chain head.

```text
A3
 ↓
A2
 ↓
A1
```

### Step 3

Inspect version metadata.

Check:

```text
Begin timestamp
End timestamp
Creating transaction
Transaction status
```

### Step 4

Determine whether the version is visible.

Conceptually:

```text
Is this version within my snapshot?
+
Did its creating transaction commit?
```

### Step 5

If not visible:

```text
Follow version chain
```

### Step 6

Return the first visible version.

---

# 103. Full MVCC Update Process

When updating a tuple:

### Step 1

Find the logical tuple.

### Step 2

Determine the version relevant to the transaction.

### Step 3

Check for write conflicts.

### Step 4

Create/update the appropriate new version.

### Step 5

Maintain version-chain metadata.

### Step 6

Update index information if required.

### Step 7

Eventually garbage collect obsolete versions.

---

# 104. Full Garbage Collection Process

```text
Find active transactions
        ↓
Determine oldest active timestamp
        ↓
Determine versions that can still be visible
        ↓
Find obsolete versions
        ↓
Reclaim storage
        ↓
Clean associated index entries
```

### Important

Garbage collection cannot simply delete old-looking versions.

It must prove:

> No active transaction can still need the version.

---

# 105. Important Comparison: Lock vs. Version

| Concept                          | Lock                      | Version                  |
| -------------------------------- | ------------------------- | ------------------------ |
| Purpose                          | Control concurrent access | Represent database state |
| Protects                         | Logical data access       | Historical/current state |
| Associated with                  | Transactions/resources    | Tuple versions           |
| Prevents reader/writer blocking? | No                        | Can enable it            |
| Requires cleanup?                | Eventually released       | Requires GC              |
| Physical or logical?             | Logical                   | Physical storage         |

---

# 106. Important Comparison: Snapshot Isolation vs. Repeatable Read

| Feature              | Snapshot Isolation | Classic Repeatable Read   |
| -------------------- | ------------------ | ------------------------- |
| Consistent snapshot  | Yes                | Depends on implementation |
| Dirty reads          | No                 | No                        |
| Non-repeatable reads | Prevented          | Prevented                 |
| Phantoms             | Different handling | May occur                 |
| Write skew           | Possible           | Not under proper 2PL      |
| Serializability      | Not guaranteed     | Not necessarily           |
| Multiple versions    | Common             | Not required              |

### Key Idea

Do not automatically equate:

```text
Snapshot Isolation = Repeatable Read
```

They can provide different guarantees.

---

# 107. Important Comparison: Logical Locks vs. Physical Latches

|          | Logical Lock                        | Physical Latch                            |
| -------- | ----------------------------------- | ----------------------------------------- |
| Protects | Transaction semantics               | In-memory data structures                 |
| Duration | Transaction-related                 | Usually very short                        |
| Example  | X lock on tuple                     | Latch on B+ tree page                     |
| Purpose  | Isolation                           | Physical correctness                      |
| Used for | Preventing conflicting transactions | Preventing simultaneous memory corruption |

### Exam Rule

> **Locks protect logical database contents; latches protect physical data structures.**

---

# 108. Common Mistakes

* Thinking **MVCC is itself a concurrency-control protocol**.
* Thinking MVCC means transactions never need locks.
* Thinking multiple physical versions means every transaction sees the newest version.
* Forgetting the **transaction status table**.
* Forgetting that MVCC requires **garbage collection**.
* Confusing `xmin`/`xmax` with permanent logical identifiers.
* Treating `ctid` as a permanent tuple identity.
* Assuming Snapshot Isolation is automatically Serializable.
* Forgetting **write skew**.
* Assuming row locks alone prevent phantom reads.
* Confusing **gap locks** with ordinary row locks.
* Confusing logical locks with physical latches.
* Assuming OCC is always better than 2PL.
* Assuming OCC is good under high contention.
* Forgetting that OCC can waste substantial work before discovering a conflict.
* Assuming Read Committed gives repeatable reads.
* Assuming Repeatable Read is always Serializable.
* Assuming every database implements isolation levels identically.
* Assuming PostgreSQL's `READ UNCOMMITTED` actually exposes dirty reads.
* Forgetting that secondary indexes are especially complicated under MVCC.
* Forgetting that garbage collection must also account for indexes.
* Assuming deleting a tuple immediately removes its physical storage.
* Forgetting that a transaction can still need an old version after a newer version exists.
* Thinking a SELECT that performs cooperative cleanup is logically a write; it may be physically modifying structures while remaining logically read-only.

---

# 109. Exam and Homework Tips

## Tip 1: Identify the Protocol First

When given a concurrency problem, determine whether it is using:

```text
2PL
OCC
MVCC
Snapshot Isolation
Timestamp Ordering
```

Do not mix their rules.

---

## Tip 2: Draw Version Chains

For MVCC questions, immediately draw:

```text
A3
↓
A2
↓
A1
↓
A0
```

Then write:

```text
Begin
End
Transaction
Status
```

next to each version.

---

## Tip 3: Track Transaction Timestamps

Write:

```text
T1 = 10
T2 = 20
T3 = 30
```

Then determine which version is visible.

---

## Tip 4: Check Commit Status

A version created by an uncommitted transaction generally cannot simply be treated as committed data for another transaction's snapshot.

Ask:

```text
Who created this version?
Did that transaction commit?
```

---

## Tip 5: For Phantom Questions

Ask:

> "Can another transaction create/delete a row that matches this predicate?"

If yes, ordinary row locking may not be enough.

Think:

```text
Predicate
↓
Range
↓
Index / gap / key-range locking
```

---

## Tip 6: For Write Skew

Look for:

```text
T1 reads X and Y
T2 reads X and Y

T1 modifies X
T2 modifies Y
```

Both make decisions from the same snapshot.

That is a classic pattern for **write skew**.

---

## Tip 7: For Deadlock Problems

Draw the wait-for graph.

Example:

```text
T1 → T2
T2 → T1
```

Cycle = deadlock.

---

## Tip 8: For Wait-Die

Remember:

> **Old waits, young dies.**

---

## Tip 9: For Wound-Wait

Remember:

> **Old wounds, young waits.**

---

## Tip 10: For Isolation Levels

Memorize the anomaly table:

```text
                         Dirty   Non-repeatable   Phantom
Read Uncommitted           YES        YES            YES
Read Committed              NO        YES            YES
Repeatable Read             NO         NO            YES*
Serializable                NO         NO             NO
```

---

# 110. Must-Know Definitions

### MVCC

A database technique that maintains multiple physical versions of logical tuples so transactions can see appropriate versions without always blocking one another.

### Version Chain

A linked sequence of physical versions representing the history of one logical tuple.

### Snapshot Isolation

An isolation mechanism in which a transaction reads from a consistent snapshot of committed data.

### Write Skew

An anomaly where concurrent transactions make decisions based on the same snapshot and update different records in a way that cannot occur under serial execution.

### Phantom Read

A repeated range query sees a different set of matching rows because another transaction inserted or deleted matching rows.

### Gap Lock

A lock protecting the space between existing index keys, preventing conflicting inserts into the gap.

### Key-Range Lock

A lock protecting a range of index keys, including potentially nonexistent values.

### Predicate Lock

A conceptual lock on all records satisfying a predicate, including records that may be inserted later.

### Garbage Collection

The process of reclaiming obsolete MVCC versions that no active transaction can see.

### Delta Storage

A version-storage strategy that records only the changes between tuple versions.

### Append-Only Storage

A strategy where every tuple update creates and stores a complete new tuple version.

### Time-Travel Storage

A strategy where older tuple versions are stored separately from the current/main table.

### OCC

Optimistic concurrency control that allows transactions to work independently and validates them before commit.

### 2PL

Two-Phase Locking, a pessimistic concurrency-control protocol that controls access through locks.

### Intention Lock

A hierarchical lock indicating that a transaction intends to acquire locks on lower-level objects.

### Logical Lock

A transaction-level lock protecting logical database operations.

### Physical Latch

A short-duration synchronization mechanism protecting physical in-memory structures.

### `xmin`

PostgreSQL metadata identifying the transaction associated with creating a tuple version.

### `xmax`

PostgreSQL metadata identifying the transaction associated with ending/invalidating a tuple version.

### `ctid`

PostgreSQL physical tuple-location identifier consisting conceptually of page and slot information.

### Tombstone

A special marker/version indicating that a logical tuple has been deleted.

---

# 111. Must-Know Methods

## MVCC Visibility

1. Find the logical tuple.
2. Find its version chain.
3. Examine begin/end timestamps.
4. Check the creating transaction's status.
5. Determine whether the version belongs to the transaction's snapshot.
6. If not visible, follow the version chain.
7. Return the appropriate visible version.

---

## Deadlock Detection

1. Identify transactions waiting for locks.
2. Construct the wait-for relationships.
3. Look for a cycle.
4. If a cycle exists, select a victim.
5. Abort the victim.
6. Release its locks.
7. Allow surviving transactions to continue.

---

## Phantom Detection

1. Identify the query predicate.
2. Determine which rows/ranges it covers.
3. Ask whether another transaction can insert/delete a matching row.
4. If yes, row-level locking alone is insufficient.
5. Use:

   * Table/range locks
   * Predicate locking
   * Index/gap/key-range locking
   * Re-execution/validation
6. Verify serializable behavior.

---

## OCC Validation

1. Transaction performs reads.
2. Transaction records its read/write sets.
3. Transaction performs private work.
4. At commit, validate conflicts.
5. If validation succeeds:

   ```text
   Write changes
   Commit
   ```
6. If validation fails:

   ```text
   Abort
   ```

---

# 112. Must-Know SQL Syntax

## Start a Transaction

```sql
BEGIN;
```

---

## PostgreSQL Serializable Transaction

```sql
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;

SELECT *
FROM transaction_demo;

COMMIT;
```

---

## Lock Rows for Update

```sql
SELECT *
FROM Accounts
WHERE id = 10
FOR UPDATE;
```

---

## PostgreSQL Lock Modes

```sql
SELECT *
FROM table_name
FOR UPDATE;

SELECT *
FROM table_name
FOR NO KEY UPDATE;

SELECT *
FROM table_name
FOR SHARE;

SELECT *
FROM table_name
FOR KEY SHARE;
```

---

## Skip Locked Rows

```sql
SELECT *
FROM Jobs
WHERE status = 'pending'
FOR UPDATE SKIP LOCKED;
```

---

# 113. Important PostgreSQL MVCC Metadata

Conceptually:

```text
Tuple
+-----------------------+
| xmin                  |
| xmax                  |
| ctid                  |
| user data             |
+-----------------------+
```

Where:

```text
xmin = creating transaction
xmax = invalidating/deleting transaction
ctid = physical location
```

---

# 114. Master MVCC Diagram

```text
                       TRANSACTION
                            |
                            v
                   Transaction Timestamp
                            |
                            v
                         QUERY
                            |
                            v
                          INDEX
                            |
                            v
                  Version Chain Head
                            |
                +-----------+-----------+
                |           |           |
                v           v           v
               A3          A2          A1
            Begin/End   Begin/End   Begin/End
                |           |           |
                +-----------+-----------+
                            |
                            v
                  Transaction Status
                         Table
                            |
                            v
                    Visibility Check
                            |
                            v
                    Visible Version
```

---

# 115. Master Concurrency-Control Diagram

```text
                    CONCURRENCY CONTROL
                           |
          +----------------+----------------+
          |                |                |
          v                v                v
         2PL              OCC             MVCC
          |                |                |
      Lock first       Work first      Store versions
          |                |                |
      May wait          Validate        Visibility
          |                |                |
      Deadlocks?       Abort on         Garbage
       possible        conflict        collection
```

Remember:

```text
2PL = control through locks

OCC = validate after doing work

MVCC = maintain multiple versions
```

MVCC can be combined with 2PL or OCC.

---

# 116. Master Version-Storage Diagram

### Append-Only

```text
Main Table

A0
A1
A2
A3
```

Whole tuples are copied.

---

### Time-Travel

```text
Main Table             Old-Version Storage

A3                     A2
                       A1
                       A0
```

---

### Delta

```text
Main Table             Delta Storage

A3                     Changes:
                       A3 → A2
                       A2 → A1
```

Only changes are stored.

---

# 117. Master Isolation Diagram

```text
Weakest
   |
   v
Read Uncommitted
   |
   | prevents dirty reads
   v
Read Committed
   |
   | prevents non-repeatable reads
   v
Repeatable Read
   |
   | prevents phantoms
   v
Serializable
   |
   v
Strongest classic isolation
```

But remember:

```text
Snapshot Isolation
```

is not simply another point on this exact ladder.

---

# 118. Final Cheat Sheet / Memory Sheet

## MVCC

```text
Multiple physical versions
        ↓
Readers find visible version
        ↓
Readers and writers can overlap
        ↓
Old versions accumulate
        ↓
Garbage collection required
```

---

## Version Metadata

```text
Begin timestamp
End timestamp
Creating transaction
Transaction status
```

---

## Version Chain

```text
A3 → A2 → A1 → A0
```

---

## Storage Strategies

```text
Append-only = copy whole tuple

Time-travel = old copies in separate storage

Delta = store only changes
```

---

## Garbage Collection

```text
Find oldest active transaction
        ↓
Determine versions still visible
        ↓
Remove obsolete versions
```

Methods:

```text
Vacuum
Cooperative cleanup
Transaction-level tracking
```

---

## Deadlocks

```text
T1 waits for T2
T2 waits for T1
       ↓
    DEADLOCK
```

Victim selection considers:

* Age
* Work done
* Locks held
* Rollback cost

---

## Deadlock Prevention

```text
WAIT-DIE:
Old waits
Young dies

WOUND-WAIT:
Old wounds
Young waits
```

---

## Lock Hierarchy

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

---

## Intention Locks

```text
IS = Intention Shared
IX = Intention Exclusive
SIX = Shared + Intention Exclusive
```

---

## Phantom Protection

```text
Table lock
     OR
Re-execute scan
     OR
Predicate locking
     OR
Index/gap/key-range locking
```

Most practical systems use index-based approaches rather than trying to represent every possible predicate exactly.

---

## Isolation Levels

```text
                    Dirty   Nonrepeatable   Phantom
Read Uncommitted      YES        YES           YES
Read Committed         NO        YES           YES
Repeatable Read        NO         NO           YES*
Serializable           NO         NO            NO
```

---

## Snapshot Isolation

```text
Consistent snapshot
        +
First writer wins
        +
Readers don't block writers
        ↓
But:
        ↓
Write skew can occur
```

Therefore:

```text
Snapshot Isolation ≠ Serializable
```

---

## PostgreSQL

```text
xmin = creating transaction
xmax = invalidating transaction
ctid = physical location
```

Lecture behavior:

```text
Default → Read Committed

READ UNCOMMITTED
        ↓
effectively Read Committed

Serializable
        ↓
stronger isolation
```

---

## Indexes Under MVCC

Primary index:

```text
Primary key
    ↓
Head of version chain
```

Secondary index challenge:

```text
Secondary index
    ↓
Physical version
```

can become expensive when the version head moves.

Solution:

```text
Secondary index
    ↓
Logical/primary key
    ↓
Primary index
    ↓
Version chain
```

---

# 119. Most Important Things to Know for the Exam

If you are short on study time, prioritize these:

### 1. MVCC

Know what it is and why multiple versions improve concurrency.

### 2. Version Visibility

Understand:

```text
Begin timestamp
End timestamp
Transaction status
```

### 3. Snapshot Isolation

Know:

```text
Consistent snapshot
First writer wins
Write skew is possible
```

### 4. Write Skew

Be able to explain the marble example and why 2PL prevents it.

### 5. Garbage Collection

Know why old versions must eventually be reclaimed.

### 6. Storage Strategies

Memorize:

```text
Append-only
Time-travel
Delta
```

and why delta storage is generally more space-efficient.

### 7. Phantom Reads

Know why row locks alone cannot protect nonexistent rows.

### 8. Gap/Key-Range Locks

Understand how indexes can protect ranges and prevent phantom inserts.

### 9. Isolation Levels

Know the anomaly table.

### 10. 2PL vs. OCC vs. MVCC

```text
2PL = lock
OCC = validate
MVCC = versions
```

### 11. Deadlock Prevention

```text
Wait-die:
Old waits, young dies.

Wound-wait:
Old wounds, young waits.
```

### 12. Locks vs. Latches

```text
Lock = logical transaction protection
Latch = physical data-structure protection
```

### 13. PostgreSQL MVCC

Know:

```text
xmin
xmax
ctid
```

and the basic idea of how PostgreSQL stores tuple versions.

### 14. Secondary Indexes

Understand why physical pointers are difficult under MVCC and why logical indirection can help.

---

# 120. One-Minute Review

```text
MVCC
│
├── Multiple versions of logical tuples
│
├── Readers can read older versions
│
├── Readers/writers often do not block each other
│
├── Versions have visibility metadata
│
├── Transaction status matters
│
├── Old versions require garbage collection
│
├── Version storage:
│     ├── Append-only
│     ├── Time-travel
│     └── Delta
│
├── Indexes become more complicated
│
├── Deletes require logical + physical handling
│
└── MVCC can be combined with:
      ├── 2PL
      ├── OCC
      └── Timestamp ordering


2PL
│
├── Pessimistic
├── Locks first
├── May wait
├── Can deadlock
└── Prevents write skew through conflicting locks


OCC
│
├── Optimistic
├── Work first
├── Validate later
├── Good with low contention
└── Can waste work under high contention


Snapshot Isolation
│
├── Consistent snapshot
├── First writer wins
├── No dirty reads
├── Readers don't necessarily block writers
└── Write skew possible


Serializable
│
├── No dirty reads
├── No non-repeatable reads
├── No phantoms
└── Equivalent to some serial execution order
```

## Final Memory Rules

> **MVCC = multiple versions.**

> **2PL = locks before conflicting work.**

> **OCC = validate after doing work.**

> **Snapshot Isolation = consistent snapshot, but not necessarily serializable.**

> **First writer wins under basic snapshot isolation.**

> **Write skew is the major snapshot-isolation anomaly to remember.**

> **Phantoms require protecting ranges/predicates, not just existing rows.**

> **Gap locks protect spaces between keys.**

> **Key-range locks protect ranges.**

> **Locks protect logical state; latches protect physical structures.**

> **Old versions must eventually be garbage collected.**

> **Append-only copies tuples; delta storage copies changes.**

> **PostgreSQL MVCC uses `xmin`, `xmax`, and `ctid` metadata.**

> **Wait-die: old waits, young dies.**

> **Wound-wait: old wounds, young waits.**

> **Read Uncommitted < Read Committed < Repeatable Read < Serializable** in the classic isolation hierarchy, but **Snapshot Isolation is a separate set of guarantees rather than simply another level in that ladder.**
