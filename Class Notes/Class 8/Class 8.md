# Day 8: Isolation Levels and Concurrency Control

Today's class covers **isolation levels**, the guarantees the database makes
about how concurrent transactions see each other's changes. We work through the
four SQL isolation levels, the three classic read anomalies (dirty reads,
non-repeatable reads, phantom reads), and the mechanisms that enforce
isolation: **conflict serializability**, the **conflict graph**, **topological
ordering**, **two-phase locking (2PL)**, shared and exclusive locks, **strict
2PL**, **lock hierarchies**, **deadlocks**, **deadlock handling & prevention**,
and the **wait-for graph**. Each concept is illustrated with concrete schedules,
tables, and equivalent SQL.

> **Assignment:** A short presentation (10 minutes) is due in 2 weeks. Topics
> will be announced separately.

---

## 1. What Are Isolation Levels

When multiple transactions execute concurrently, the database must decide how
much they are allowed to "see" of each other's intermediate changes. An
**isolation level** is a guarantee about how — and when — a transaction's
writes become visible to others. Higher levels give stronger guarantees but
lower concurrency (more locking overhead); lower levels allow more parallelism
but risk anomalies.

The SQL standard defines four isolation levels, ordered from weakest to
strongest:

| Isolation level | Dirty reads | Non-repeatable reads | Phantom reads |
|---|---|---|---|
| READ UNCOMMITTED | allowed | allowed | allowed |
| READ COMMITTED | prevented | allowed | allowed |
| REPEATABLE READ | prevented | prevented | allowed |
| SERIALIZABLE | prevented | prevented | prevented |

> **Key takeaway:** Isolation levels are a trade-off. The weaker the level,
> the more concurrency the database allows — but the more anomalies can appear
> in your results. Choose the weakest level that still prevents your
> application's anomalies.

## 2. The Three Read Anomalies

The three classic concurrency anomalies that isolation levels exist to prevent
are:

### Dirty Read

Transaction T2 reads data written by T1 that has not yet been committed. If T1
later rolls back, T2 has read a value that never existed.

```sql
-- T1
BEGIN;
UPDATE Accounts
SET balance = 0
WHERE holder = 'Bob';
-- T1 NOT committed yet

-- T2
SELECT balance FROM Accounts WHERE holder = 'Bob';  -- reads 0
ROLLBACK;  -- restores 500
```

**SQL equivalent (what T2 saw was invalid):**

```sql
-- T2 saw 0, but real balance is 500 after T1 rolled back
```

### Non-Repeatable Read

T2 reads the same row twice and gets different values because T1 modified
(and committed) that row in between the two reads.

```sql
-- T2
BEGIN;
SELECT balance FROM Accounts WHERE holder = 'Bob';  -- reads 500

-- T1 (in between T2's reads)
BEGIN;
UPDATE Accounts SET balance = 300 WHERE holder = 'Bob';
COMMIT;

-- T2 (second read)
SELECT balance FROM Accounts WHERE holder = 'Bob';  -- reads 300 (!)
COMMIT;
```

### Phantom Read

T2 re-executes a query returning a set of rows and finds that the set has
changed because T1 inserted or deleted rows that match T2's predicate.

```sql
-- T2
BEGIN;
SELECT * FROM Orders WHERE amount > 100;  -- returns 3 rows

-- T1 (inserts matching row)
BEGIN;
INSERT INTO Orders VALUES (...);
COMMIT;

-- T2 (re-run query)
SELECT * FROM Orders WHERE amount > 100;  -- now returns 4 rows
COMMIT;
```

**Arrow summary — anomaly causes:**

```text
T1 writes uncommitted data
    |
    | T1 aborts -> data was invalid
    v
Dirty read (T2 read uncommitted write)

T1 commits a change between T2's two reads
    |
    v
Non-repeatable read (same row, different value)

T1 inserts/deletes a row matching T2's predicate
    |
    v
Phantom read (set of rows changed)
```

> **Key takeaway:** Each anomaly corresponds to a gap in isolation.
> SERIALIZABLE closes all three gaps; weaker levels leave one or more open.

## 3. SERIALIZABLE — The Strongest Level

**Serializable** means the database guarantees that concurrent transactions
produce the same result as if they had run one after another in some serial
order. From the application's perspective, transactions execute as if no
concurrency existed.

This is the "gold standard" of isolation. It means:
- No dirty reads, no non-repeatable reads, no phantom reads.
- The final state of the database is identical to some serial interleaving of
  all transactions.
- The scheduler (DBMS) is free to interleave operations however it likes, as
  long as the end result is equivalent to a serial schedule.

Two techniques are commonly used to achieve serializability:
1. **Conflict serializability** — check whether the schedule can be reordered
   into a serial schedule by swapping non-conflicting operations.
2. **Two-phase locking (2PL)** — enforce a locking discipline that guarantees
   serializability by construction.

> **Key takeaway:** SERIALIZABLE means "concurrent executions look like some
> serial execution." It is the strongest isolation guarantee but costs the
> most in locking overhead.

## 4. Conflict Serializability

A schedule is **conflict serializable** if it can be transformed into a serial
schedule by swapping the order of non-conflicting operations. Two operations
**conflict** if they operate on the same data item and at least one of them is
a write.

| Conflict type | Operations | Example |
|---|---|---|
| Read-Write (RW) | Read after write | W1(A) → R2(A) |
| Write-Read (WR) | Write after read | R1(A) → W2(A) |
| Write-Write (WW) | Write after write | W1(A) → W2(A) |

If two operations are on different data items, or both are reads, they do **not**
conflict and their order can be swapped freely.

**Example** — two transactions on item A:

```text
T1: R1(A) W1(A) C1
T2:               R2(A) W2(A) C2
```

The interleaved schedule: `R1(A) W2(A) W1(A) R2(A) C2 C1`

**Step-by-step analysis:**

1. `W1(A)` and `W2(A)` conflict (write-write) — cannot swap, so W1 must precede W2.
2. `R2(A)` reads what `W2(A)` wrote — swapping `R2(A)` before `W2(A)` would
   change the data read, so illegal.
3. `R1(A)` and `R2(A)` are both reads — no conflict, freely reorderable.
4. After reordering (only legal swaps), the schedule is equivalent to:
   `T1 → T2` (serial).

The schedule is **conflict serializable**.

> **Key takeaway:** Conflict serializability asks "can we reorder this schedule
> into a serial one by swapping only non-conflicting operations?" If yes, the
> schedule is safe.

## 5. Conflict Graph (Precedence Graph)

The **conflict graph** (also called the precedence graph) is a formal tool for
checking conflict serializability. It encodes all the conflict relationships
between transactions as a directed graph.

### Construction rules

- Each transaction becomes a node (vertex) in the graph.
- For every conflicting operation pair (Oi from Ti and Oj from Tj), draw a
  directed edge from Ti to Tj **if an operation of Ti precedes the conflicting
  operation of Tj**.

The edge type depends on the conflict:
- **WW conflict** → edge Ti → Tj
- **RW conflict** → edge Ti → Tj (Ti wrote, Tj read after)
- **WR conflict** → edge Ti → Tj (Ti read, Tj wrote after)

### Example

```text
T1: R1(A) W1(A)       T2: R2(B) W2(B)
T3:             R3(A) W3(A) C3
```

Schedule: `R1(A) R2(B) R3(A) W1(A) W3(A) W2(B) C1 C3 C2`

**Conflicting pairs:**
- `W1(A) → R3(A)` → edge T1 → T3 (WR)
- `W1(A) → W3(A)` → edge T1 → T3 (WW)

**Conflict graph:**

```text
T1 ───> T3
T2
```

Is the graph acyclic? **Yes** — T2 has no edges, and `T1 → T3` is a single
edge with no cycle. Since the conflict graph is acyclic, the schedule is
conflict serializable. The acyclicity tells us which serial order is valid:
topological sort gives `T1, T3, T2` (T1 before T3).

> **Key takeaway:** Conflict serializability = conflict graph is acyclic. The
> graph compacts all ordering constraints.

## 6. Topological Ordering and Acyclicity

A **topological ordering** of a directed acyclic graph (DAG) is a linear
ordering of its vertices such that for every directed edge u → v, vertex u
appears before v in the ordering. In other words, all edges "point forward."

- A graph has a topological ordering **if and only if** it is acyclic.
- A cycle means there is no valid topological ordering: the edges contradict
  each other, creating a "chicken and egg" situation where no vertex can come
  first.

**Decision logic:**

```text
If graph is acyclic → there exists a topological ordering → the schedule
is conflict serializable.

If graph has a cycle → there is NO topological ordering → the schedule
is NOT conflict serializable.
```

### Kahn's algorithm (in words)

1. Find all nodes with no incoming edges (in-degree 0).
2. Remove them and add to the ordering.
3. Repeat until all nodes are placed. If nodes remain that all have incoming
   edges, a cycle exists.

### Example — checking two conflict graphs

**Graph A (acyclic):**

```text
T1 ──→ T2 ──→ T3
```

Topological order: `T1, T2, T3` — **Conflict serializable.** Valid serial
order: `T1; T2; T3`.

**Graph B (cyclic):**

```text
T1 ──→ T2
^        |
|        v
T3 <──── (edges: T1→T2, T2→T3, T3→T1)
```

Every node has an incoming edge → **No topological ordering exists** →
**NOT conflict serializable.**

**Arrow summary:**

```text
         Cycle in graph?
            |
        Yes v  No
        ┌─────┐  ┌──────┐
        │ Not │  │ Has  │
        │serializable│  │topo  │
        └─────┘  └──────┘
```

> **Key takeaway:** Acyclicity of the conflict graph is both necessary and
> sufficient for conflict serializability. Topological ordering gives you the
> actual serial order that the schedule is equivalent to.

## 7. Two-Phase Locking (2PL)

**Two-phase locking (2PL)** is a protocol that guarantees conflict
serializability. Every transaction goes through two phases:

- **Phase 1 — Growing:** The transaction acquires locks. It may also release
  nothing. Locks accumulate; no lock is released.
- **Phase 2 — Shrinking:** The transaction releases locks. It may no longer
  acquire new locks.

The name "two-phase" comes from the fact that the lock-acquisition /
lock-release timeline of each transaction has two distinct halves: it only
grows, then only shrinks.

### Visualizing the two phases

```text
Time ──────────────────────────────→

Locks held by T1:
  S(A)       acquired
  S(A) X(B)  growing (acquiring more)
  X(B)       shrink starts — X(B) released
  (none)     all locks released

   Growing phase  →  Shrinking phase  (one transition only)
```

### Why 2PL guarantees serializability

Because locks serialize conflicting operations (only one writer or any number
of readers at a time), the resulting schedule is conflict equivalent to a
serial schedule.

> **Key takeaway:** 2PL is a simple, enforceable rule — grow, then shrink, in
> only two phases — that guarantees the schedule is conflict serializable.

## 8. Shared and Exclusive Locks

Two-phase locking uses two kinds of locks on data items:

| Lock type | Symbol | Used for | Compatibility |
|---|---|---|---|
| Shared lock | S | Reading | S + S: allowed |
| Exclusive lock | X | Writing | S + X: blocked |

Rules:
1. A transaction must hold an **S (shared) lock** before **reading** an item.
2. A transaction must hold an **X (exclusive) lock** before **writing** an item.
3. If a transaction holds an X lock on an object, **no other** transaction can
   acquire any lock (S or X) on that object.
4. Shared locks are compatible with other shared locks.
5. Exclusive locks are compatible with nothing.

### Lock compatibility matrix

| Held \ Requested | S | X |
|---|---|---|
| S | OK | BLOCK |
| X | BLOCK | BLOCK |
| None | OK | OK |

**Example:**

```sql
-- T1:
BEGIN;
SELECT balance FROM Accounts WHERE holder = 'Bob';  -- acquires S(A)
UPDATE Accounts SET balance = 400 WHERE holder = 'Bob';  -- upgrades to X(A)

-- T2 (concurrent):
BEGIN;
SELECT balance FROM Accounts WHERE holder = 'Bob';  -- tries S(A), BLOCKED by X(A)
```

T2 cannot read while T1 holds the exclusive write lock.

> **Key takeaway:** Shared locks protect reads (multiple readers OK); exclusive
> locks protect writes (one writer only, no readers). Lock incompatibility is
> what enforces isolation.

## 9. Lock Compatibility

The **lock compatibility matrix** determines whether a lock request can be
granted immediately or must wait. The rule is simple:

- **S and S**: compatible — both transactions can read.
- **S and X**: incompatible — a writer excludes everyone else.
- **X and X**: incompatible — only one writer at a time.

```text
Held lock    Requested: S    Requested: X
----------   ------------    ------------
S            Granted        Blocked
X            Blocked        Blocked
None         Granted        Granted
```

When a lock request is **blocked**, the requesting transaction **waits**. The
lock manager maintains a queue of pending lock requests for each data item. If
the waiting forms a cycle, we have a **deadlock** (see Section 12).

### Lock escalation (bonus)

Some databases escalate many fine-grained locks (row-level) into fewer
coarse-grained locks (table-level) to reduce lock-table overhead.

> **Key takeaway:** Lock compatibility is the mechanism by which the DBMS
> serializes access. If a request conflicts with a held lock, the requester
> waits.

## 10. Strict 2PL

**Strict 2PL** is a refinement of two-phase locking: a transaction holds **all**
its locks until it commits (or aborts). No locks are released in the shrinking
phase until the commit point.

**Strict 2PL rule:** All locks (S and X) are held until COMMIT or ROLLBACK.

### Comparison

| Scheme | When locks released | Guarantees |
|---|---|---|
| 2PL | Released during run | Conflict serializable |
| Strict 2PL | Held until commit | Reversible + serializable |

### Why strict 2PL matters

- It makes recovery simpler: a transaction's writes are not visible to others
  (no cascading aborts) until it commits.
- If a transaction aborts, no other transaction has read its intermediate
  uncommitted data, so no cascading rollback is needed.
- **Strict 2PL allows only schedules whose dependency graph is acyclic.**
- Regular 2PL also allows conflict serializable schedules (acyclic graph), but
  strict 2PL is preferred in practice because of its recovery benefits.
- **If graph is acyclic → conflict serializable.**

**Arrow summary — strict 2PL:**

```text
Transaction T1
  |
  | [Growing] acquires S(A), then X(A)
  |           all locks held
  |           through entire execution
  | [Commit] releases ALL locks at once
  v
No cascading aborts; schedule conflict serializable
```

> **Key takeaway:** Strict 2PL = hold all locks until commit. It prevents
> cascading rollbacks and still guarantees conflict serializability (acyclic
> graph).

## 11. Lock Hierarchy

A **lock hierarchy** is a tree structure of lockable items, from coarse to fine
granularity. For example:

```text
Database
  └── Table
        └── Page (block on disk)
              └── Row (tuple)
```

Locking at a higher level (e.g., table) is cheaper (one lock protects many
items) but reduces concurrency. Locking at a lower level (e.g., row) maximizes
concurrency but requires more lock table entries.

### Intention locks

**Intention locks** are used to coordinate locking across the hierarchy:

| Intention lock | Symbol | Meaning |
|---|---|---|
| Intention Shared | IS | "I intend to take S locks on children" |
| Intention Exclusive | IX | "I intend to take X locks on children" |
| Shared Intention Exclusive | SIX | "I hold S on this + IX on children" |
| Exclusive | X | "I own this exclusively" |

### Visual example

```text
Database
  |
  +-- Table(Accounts)  -- IS lock
      |
      +-- Page(3)      -- IS lock
          |
          +-- Row(5)   -- S lock (held by T1 reading)
          +-- Row(6)   -- S lock (held by T2 reading)
          +-- Row(7)   -- X lock (held by T3 writing)
```

The IS locks on the higher levels signal to other transactions that locks are
being acquired deeper in the tree. This prevents a transaction from grabbing a
conflicting table-level lock while another is already holding row-level locks.

**Lock compatibility for intention locks:**

| Held \ Requested | IS | IX | S | SIX | X |
|---|---|---|---|---|---|
| IS | ✓ | ✓ | ✓ | ✓ | ✗ |
| IX | ✓ | ✓ | ✗ | ✓ | ✗ |
| S | ✓ | ✗ | ✓ | ✗ | ✗ |
| SIX | ✓ | ✓ | ✗ | ✗ | ✗ |
| X | ✗ | ✗ | ✗ | ✗ | ✗ |

(`✓` = compatible, `✗` = incompatible)

> **Key takeaway:** Lock hierarchies let you lock at multiple granularities.
> Intention locks at parent levels coordinate with fine-grained locks at child
> levels, avoiding deadlocks and enabling lock escalation.

## 12. Deadlock

A **deadlock** occurs when two or more transactions are each waiting for a lock
held by another, forming a circular chain of dependencies. No transaction can
proceed — each is blocked waiting for a lock that will never be released.

### Example with two transactions

```sql
-- T1
BEGIN;
LOCK Accounts;        -- OK, T1 holds Table A
                      -- (T2 doesn't have B yet)

-- T2
BEGIN;
LOCK Orders;          -- OK, T2 holds Table B
LOCK Accounts;        -- BLOCKED! T1 holds Accounts
                      -- T2 waits for T1

-- Back to T1 (trying to lock B)
LOCK Orders;          -- BLOCKED! T2 holds Orders
                      -- T1 waits for T2
```

**Visual representation:**

```text
T1 ───(waits for B)──> T2
T2 ───(waits for A)──> T1
↑_____________________↓
        (cycle)
```

### Deadlock vs. just waiting

- **Blocked** (not a deadlock): T2 waits for T1, but T1 is not waiting on
  anything — T1 will eventually finish and release the lock. T2 just waits.
- **Deadlocked**: a cycle exists in the wait-for graph. If nobody intervenes,
  all transactions in the cycle will wait forever.

> **Key takeaway:** Deadlock = circular wait. Each transaction in the cycle
> holds something the next one needs. The DBMS must detect and resolve it.

## 13. Deadlock Handling and Prevention

There are two strategies for dealing with deadlocks:

### Strategy 1 — Deadlock Detection (reactive)

The DBMS periodically builds a **wait-for graph** (see Section 14) and checks
for cycles. If a cycle is found, the DBMS picks a "victim" transaction,
aborts it, and rolls back its lock. The other transactions can then proceed.

- **Advantages:** allows maximum concurrency; no unnecessary abortions.
- **Disadvantages:** some work is wasted when a victim is chosen.

### Strategy 2 — Deadlock Prevention (proactive)

Assign each transaction a timestamp (or priority) at the start. When a
conflict arises, the DBMS uses the timestamp to decide who waits and who dies.
Two common schemes:

**Wait-Die scheme:**

- Older transaction waits for younger one.
- Younger transaction is aborted ("dies") and restarted later (with a new
  timestamp).

**Rule:** If `T_old < T_young` and they conflict, `T_young` dies.

**Wound-Wait scheme:**

- Older transaction wounds (aborts) the younger one.
- Younger transaction waits for the older one.

**Rule:** If `T_old < T_young` and they conflict, `T_young` waits.

### Arrow summary — deadlock handling

```text
Deadlock detected?
  |
  | Yes → Detect (wait-for graph cycle)
  |        |
  |        v
  |      Abort victim (rollback + release locks)
  |        |
  |        v
  |      Winner proceeds
  |
  No  → continue (prevention: use timestamps)
```

> **Key takeaway:** Deadlock handling is either reactive (detect and kill a
> victim) or proactive (prevent by timestamp ordering). Both are valid;
> detection is simpler and more common in modern systems.

## 14. Wait-For Graph

The **wait-for graph** is a directed graph used to **detect** deadlocks.

### Construction

- Nodes = transactions currently in the system.
- An edge `T_i → T_j` means "T_i is waiting for a lock held by T_j."

### If the wait-for graph contains a cycle → deadlock

```text
T1 waits for lock held by T2 → edge T1 → T2
T2 waits for lock held by T3 → edge T2 → T3
T3 waits for lock held by T1 → edge T3 → T1
```

**Cyclic wait-for graph:**

```text
T1 ─→ T2 ─→ T3
↑              |
└──────────────┘
```

Cycle: `T1 → T2 → T3 → T1` → **deadlock detected.**

**Acyclic wait-for graph:**

```text
T1 ─→ T2 ─→ T3
```

No cycle → no deadlock → let them wait.

### What happens when a deadlock is detected

The DBMS:
1. Breaks the cycle by aborting one transaction (the "victim").
2. Rolls back the victim's changes.
3. Releases the victim's locks.
4. The transactions in the cycle can now proceed one by one.

**Selection of the victim:** Typically the transaction with the smallest cost
(least work done, fewest locks held, youngest, or chosen by priority/age).

> **Key takeaway:** Wait-for graph = deadlock detector. Edges represent "waits
> for" relationships. A cycle means deadlock. The DBMS breaks cycles by
> aborting one transaction.

## 15. Practical Example: Conflict Serializability Check

Walk through a full schedule and determine whether it is conflict serializable.

**Two transactions:**

```text
T1: R1(X) W1(X) R1(Y) W1(Y) C1
T2: R2(X) R2(Y) W2(Y) C2
```

**Interleaved schedule S (10 steps):**

```text
Step  Op     Trans  Item   Notes
----  ------ -----  -----  --------------------------------
1     R1(X)  T1     X      reads X (no conflict)
2     R2(Y)  T2     Y      reads Y (no conflict)
3     W1(X)  T1     X      writes X
4     W2(Y)  T2     Y      writes Y (WW conflict with R2(Y) → same T, no edge)
5     W1(Y)  T1     Y      WW conflict with W2(Y) → edge T2 → T1
                              RW conflict R2(Y)→W1(Y) → edge T2 → T1
6     R2(X)  T2     X      RW conflict W1(X)→R2(X) → edge T1 → T2
7     W2(X)  T2     X      WW conflict W1(X)→W2(X) → edge T1 → T2 (dup)
8     C1     —      —      —
9     C2     —      —      —
```

**Conflict graph:**

```text
T1 ──→ T2   (from R2(X) after W1(X), W2(X))
T2 ──→ T1   (from W1(Y) after R2(Y), W2(Y))
```

Cycle: `T1 → T2 → T1` → **NOT conflict serializable.**

If we removed the cycle-causing edge (say `W2(X)` at step 7, which isn't
possible but hypothetically), the graph would be acyclic (only `T2→T1`), and
the schedule would be conflict serializable with serial order `T2 → T1`.

> **Key takeaway:** Build the conflict graph by tracing each operation, add
> edges for conflicts, then check for cycles. A cycle means the schedule is
> not conflict serializable.

## 16. Isolation Levels Cheat Sheet

| Isolation level | Dirty read prevented? | Non-repeatable read prevented? | Phantom read prevented? |
|---|---|---|---|
| READ UNCOMMITTED | No | No | No |
| READ COMMITTED | Yes | No | No |
| REPEATABLE READ | Yes | Yes | No |
| SERIALIZABLE | Yes | Yes | Yes |

**Lock / protocol summary:**

| Lock / protocol | Guarantees |
|---|---|
| 2PL | Schedule is conflict serializable |
| Strict 2PL | Conflict serializable + no cascading aborts |
| Lock hierarchy (IS/IX) | Multi-granularity locking with intention locks |
| Deadlock detection | Wait-for graph cycle detection |
| Deadlock prevention | Wait-die or wound-wait by timestamp |

**Concept reference:**

| Concept | Rule / Formula |
|---|---|
| Conflict | Two ops on same item, at least one is a write |
| Conflict graph | Nodes = transactions; edge Ti→Tj if conflicting op of Ti precedes conflicting op of Tj |
| Topological order | Exists iff graph is acyclic → serializable |
| 2PL | Grow (acquire) then shrink (release), 2 phases |
| Strict 2PL | Hold all locks until COMMIT/ROLLBACK |
| Lock compatibility | S+S = OK, S+X = BLOCK, X+X = BLOCK |
| Wait-for graph | Ti→Tj if Ti waits for lock held by Tj |
| Deadlock | Cycle in wait-for graph |

> **Key takeaway:** Isolation levels, 2PL, conflict graphs, lock hierarchies,
> and deadlock handling form a coherent system. Serializability (via conflict
> graph acyclicity or 2PL) is the gold standard for correctness; isolation
> levels trade correctness for concurrency; deadlocks are detected via the
> wait-for graph and resolved by aborting a victim. Master these, and you can
> reason about any concurrency scenario.
