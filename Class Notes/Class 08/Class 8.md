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

## 17. Constraints

Constraints are rules that the database enforces to keep data consistent.
They are the first line of defense against invalid data. Some constraints can
be expressed declaratively (declared in the `CREATE TABLE` statement), while
others require procedural code (triggers and assertions — see Sections 18 and 21).

| Constraint type | Symbol | Meaning |
|---|---|---|
| Primary key | PK | Unique identifier; must be unique + NOT NULL |
| Foreign key | FK | Maintains referential integrity |
| Unique | UNIQUE | Column values must be distinct |
| Not null | NOT NULL | Column value cannot be NULL |
| Check | CHECK | Boolean condition on a row or column |
| Domain | DOMAIN | Data type + constraint on a column |

### Key constraints / primary key

A **primary key** must be both **UNIQUE** (no two rows share the same key
value) and **NOT NULL** (no row may have a NULL key). The database enforces
both automatically.

### Foreign keys

A **foreign key** in one table references the primary key (or a unique key) of
another table. Three referential actions control what happens on delete or
update of the referenced row:

| Action | Description | DB behavior |
|---|---|---|
| CASCADE | Propagate the change | On DELETE: child rows deleted too; On UPDATE: child FK values updated too |
| RESTRICT | Prevent the change | On DELETE/UPDATE: raises error if child rows exist |
| SET NULL | Null out the FK in children | On DELETE/UPDATE: child FK columns set to NULL |
| SET DEFAULT | Set FK to its default | On DELETE/UPDATE: child FK columns set to default value |

### Not null (total participation)

`NOT NULL` enforces that a column always has a value. In ER modeling this
corresponds to total participation: every entity must participate.

### Unique

The `UNIQUE` constraint ensures all values in a column (or set of columns) are
distinct. Unlike `PRIMARY KEY`, multiple NULLs are allowed.

> **Key takeaway:** Primary keys, foreign keys, unique, not-null, check, and
> domain constraints cover most integrity needs declaratively. When they are
> not enough, triggers (Section 18) and assertions (Section 21) fill the gap.

## 18. Creating Tables with Constraints

A well-designed `CREATE TABLE` embeds constraints as early as possible, so the
database — not application code — enforces them.

**Example: Employee table**

```sql
CREATE TABLE Employee(
  id        INT          PRIMARY KEY,
  ssn       CHAR(9)      UNIQUE NOT NULL,
  name      VARCHAR(50),
  salary      DECIMAL(10,2)  CHECK (salary > 0),
  dept_id   INT          REFERENCES Department(id)
                         ON DELETE CASCADE
                         ON UPDATE CASCADE
);
```

- `id` is the PRIMARY KEY → unique + not null (auto-enforced)
- `ssn` must be unique and not null
- `salary` must be positive (CHECK)
- `dept_id` references `Department(id)`; if a department is deleted, all its
  employees are cascade-deleted

**Example: Check constraints with named constraints**

```sql
CREATE TABLE check1(
  name    CHAR(20)    NOT NULL,
  age     INT,
  CONSTRAINT check_age  CHECK (age < 100),
  CONSTRAINT age_unique UNIQUE(age)
);

INSERT INTO check1 VALUES ('Bob Ross', 21);  -- OK
-- INSERT INTO check1 VALUES (21);          -- ERROR: name is NOT NULL
-- INSERT INTO check1 VALUES ('a very long name ...', 21);  -- ERROR: CHAR(20) overflow
-- INSERT INTO check1 VALUES ('Smith', 121); -- ERROR: age >= 100 violates CHECK
-- INSERT INTO check1 VALUES ('Bob Ross', 21); -- ERROR: duplicate age violates UNIQUE
```

> **Key takeaway:** Constraints are declared at table-creation time. `CHECK`
> handles boolean conditions; `UNIQUE` and `NOT NULL` handle value-level
> integrity; `PRIMARY KEY` and `FOREIGN KEY` handle entity and referential
> integrity.

## 19. Triggers — Introduction

Sometimes a constraint cannot be expressed declaratively — for example, "if an
employee's salary exceeds \$200,000, log the change in an audit table." That
rule needs procedural logic. A **trigger** is a stored procedure that runs
automatically when a specified event occurs on a table.

> The application constraint that needs to be captured inside the database.

Some constraints can be captured declaratively by:
- `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, `NOT NULL`, and `CHECK`.
- But others — complex business rules, auditing, derived values — require
  triggers or assertions.

A trigger has **three components**:

| Component | Description |
|---|---|
| Event | The table operation that fires the trigger: INSERT, UPDATE, DELETE |
| Condition | Optional WHEN clause; the trigger body runs only if the condition is true |
| Action | The procedure body (SQL statements) to execute |

**Syntax (conceptual):**

```sql
CREATE TRIGGER <name>
{ BEFORE | AFTER } { INSERT | UPDATE | DELETE }
ON <table_name>
FOR EACH { ROW | STATEMENT }
WHEN (<condition>)
BEGIN
  <action>
END;
```

> **Key takeaway:** A trigger is an automatic procedure tied to a table event.
> It has an event (INSERT/UPDATE/DELETE), an optional condition (WHEN), and an
> action (declarative SQL). Triggers capture logic that simple constraints
> cannot.

## 20. Trigger Granularity — Row vs. Statement

Triggers fire at two granularities:

| Granularity | When it fires | Use case |
|---|---|---|
| Row-level | Once `FOR EACH ROW` affected by the event | Validate or modify each individual row |
| Statement-level | Triggered once per SQL statement | Audit or summary actions (after a batch completes) |

**Row-level triggers:**
- Fire once for every row the event touches.
- Have access to special variables:
  - `NEW` — the new row values (for INSERT and UPDATE)
  - `OLD` — the old row values (for DELETE and UPDATE)
- For an INSERT: only `NEW` is available (the row is brand new).
- For a DELETE: only `OLD` is available (the row no longer exists).
- For an UPDATE: both `NEW` and `OLD` are available (you can compare).

**Statement-level triggers:**
- Fire once, regardless of how many rows the statement affected.
- Do **not** have access to `NEW` / `OLD` (there is no single row).
- Used for logging or aggregate checks after an entire operation.

**NEW / OLD availability:**

| Event | NEW available? | OLD available? |
|---|---|---|
| INSERT | yes | no |
| DELETE | no | yes |
| UPDATE | yes | yes |

**Example (row-level trigger):**

```sql
CREATE TRIGGER audit_salary
AFTER UPDATE OF salary ON Employee
FOR EACH ROW
BEGIN
  INSERT INTO SalaryLog(emp_id, old_salary, new_salary, changed_at)
  VALUES (OLD.id, OLD.salary, NEW.salary, NOW());
END;
```

> **Key takeaway:** Row-level triggers see `NEW` and/or `OLD` row values per row.
> Statement-level triggers fire once per statement and cannot reference `NEW` or
> `OLD`. Pick the granularity that matches your logic: per-row validation vs.
> per-statement auditing.

## 21. Order of Trigger Firing

When a table has multiple triggers for the same event, the database fires them
in a defined order. The typical pipeline is:

```text
Event occurs (e.g., UPDATE on Employee)
    |
    v
[1] BEFORE STATEMENT trigger fires (once)
    |
    v
[2] BEFORE ROW trigger fires (once per affected row)
    |
    v
[3] The actual row modification happens
    |
    v
[4] AFTER ROW trigger fires (once per affected row)
    |
    v
[5] AFTER STATEMENT trigger fires (once)
    |
    v
All triggers complete; locks released on commit
```

```text
BEFORE STATEMENT ──→ BEFORE ROW ──→ Row change ──→ AFTER ROW ──→ AFTER STATEMENT
```

- **BEFORE triggers** are ideal for validation (reject bad changes before they
  happen).
- **AFTER triggers** are ideal for side effects (logging, cascading actions,
  updating derived data).
- If a BEFORE trigger fails (raises an error), the triggering statement is
  aborted and no row change occurs.
- If an AFTER ROW trigger modifies the same table, the DBMS may or may not
  re-fire triggers depending on settings (recursive triggers).

> **Key takeaway:** Triggers fire in a predictable order: statement BEFORE, row
> BEFORE, the change, row AFTER, statement AFTER. Understanding this order lets
> you design validation (BEFORE) and side-effects (AFTER) correctly.

## 22. Creating and Deleting Triggers

Triggers are created with `CREATE TRIGGER` and removed with `DROP TRIGGER`.

```sql
-- Create a trigger
CREATE TRIGGER <name> ...;

-- Delete (drop) a trigger
DROP TRIGGER IF EXISTS <name>;
```

**Notes:**
- Use `IF EXISTS` to avoid an error if the trigger does not exist.
- Triggers persist until dropped; they are part of the database schema.
- Some databases (e.g., MySQL) use a `DELIMITER` change when trigger bodies
  contain semicolons, so the parser can distinguish statement termination from
  in-body statement termination.

**Example with DELIMITER (MySQL-style):**

```sql
DELIMITER //
CREATE TRIGGER before_employee_insert
BEFORE INSERT ON Employee
FOR EACH ROW
BEGIN
  IF NEW.salary < 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Salary must be positive';
  END IF;
END//
DELIMITER ;
```

> **Key takeaway:** `CREATE TRIGGER` defines the trigger; `DROP TRIGGER`
> (optionally with `IF EXISTS`) removes it. Some databases require a
> `DELIMITER` change for bodies containing semicolons.

## 23. Assertions

An **assertion** is a database-wide constraint — a predicate that must always
remain true for the database as a whole (not just for one row or one table).
Assertions check relationships across multiple tables at commit time.

**Syntax:**

```sql
CREATE ASSERTION <name>
CHECK (<predicate>);

DROP ASSERTION <name>;
```

**Example — employee salary cap:**

```sql
CREATE ASSERTION salary_cap
CHECK (
  NOT EXISTS (
    SELECT 1 FROM Employee e
    WHERE e.salary > 200000
  )
);
```

**Example — total department budget:**

```sql
CREATE ASSERTION dept_budget
CHECK (
  NOT EXISTS (
    SELECT d.id
    FROM Department d
    WHERE (
      SELECT SUM(e.salary)
      FROM Employee e
      WHERE e.dept_id = d.id
    ) > d.budget
  )
);
```

**How assertions work:**
- The predicate is evaluated at `COMMIT` time (after the transaction's changes
  are applied to the buffer).
- If the assertion would be violated, the `COMMIT` is rejected and the
  transaction must be rolled back.
- Assertions are checked against the full database state, so they are more
  expensive than row-level `CHECK` constraints.

**Limitations:**
- Not all databases support assertions (e.g., MySQL does not).
- Because they are checked at commit, they can cause unexpected rollbacks if
  other concurrent transactions modify the referenced data.

> **Key takeaway:** Assertions enforce cross-table, database-wide conditions.
> They are checked at commit and rejected if violated. When assertions are not
> available, triggers are the practical substitute.

## 24. Triggers and Assertions — Cheat Sheet

| Constraint / object | Mechanism |
|---|---|
| Column uniqueness | PRIMARY KEY / UNIQUE |
| Non-null requirement | NOT NULL |
| Value range / condition | CHECK |
| Referential integrity | FOREIGN KEY (CASCADE / RESTRICT / SET NULL / SET DEFAULT) |
| Per-row business logic | Row-level TRIGGER (FOR EACH ROW, NEW/OLD) |
| Per-statement side effects | Statement-level TRIGGER (FOR EACH STATEMENT) |
| Cross-table invariant | ASSERTION CHECK (evaluated at COMMIT) |

**Trigger components:**

| Component | Description |
|---|---|
| Event | INSERT \| UPDATE \| DELETE |
| WHEN | optional row condition |
| Action | procedure body |

**Granularity:**

- `FOR EACH ROW` — fires per row, has NEW and/or OLD
- `FOR EACH STATEMENT` — fires once, no NEW/OLD

**Firing order:**

```text
BEFORE STATEMENT → BEFORE ROW → change → AFTER ROW → AFTER STATEMENT
```

**NEW / OLD availability:**

| Event | NEW | OLD |
|---|---|---|
| INSERT | yes | no |
| DELETE | no | yes |
| UPDATE | yes | yes |

> **Key takeaway:** Constraints are the declarative layer (PRIMARY KEY, FOREIGN
> KEY, UNIQUE, NOT NULL, CHECK). Triggers add procedural logic for row-level or
> statement-level rules. Assertions enforce database-wide invariants at commit.
> Choose the simplest mechanism that expresses your rule.

## 25. Triggers vs. Assertions — Comparison and Contrast

Both triggers and assertions are **procedural** mechanisms for enforcing rules
the database cannot express with simple declarative constraints. However, they
differ in key dimensions:

| Dimension | Triggers | Assertions |
|---|---|---|
| Scope | Row-level or statement-level | Database-wide (all tables) |
| Timing | Fires on INSERT/UPDATE/DELETE | Evaluated at `COMMIT` time |
| Granularity | Per-row or per-statement | Whole database state at once |
| NEW / OLD access | Yes (row-level triggers) | No (no specific row context) |
| Action | Arbitrary SQL (INSERT, UPDATE, logging, side-effect tables) | Predicate check only (pass/fail) |
| When evaluated | At the moment the event occurs | At transaction commit |
| Performance | Runs on every matching event | Runs once per commit per TX |
| Error handling | Can signal, modify, or redirect | Rejects the `COMMIT` entirely |

**When to use triggers:**
- You need to audit changes (log old → new values).
- You need to modify other tables as a side effect.
- You need per-row validation or derived values.
- The rule depends on the specific rows being inserted/updated/deleted.

**When to use assertions:**
- The rule spans multiple tables and must always hold.
- You want a single, declarative predicate checked atomically at commit.
- You do not need side effects — just "is the database still valid?"

**Example** — "a student's GPA must never exceed 4.0":

**Trigger approach** (per-row, during INSERT/UPDATE):

```sql
CREATE TRIGGER check_gpa
BEFORE INSERT ON Enrollments
FOR EACH ROW
BEGIN
  IF NEW.gpa > 4.0 THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'GPA cannot exceed 4.0';
  END IF;
END;
```

**Assertion approach** (database-wide, at COMMIT):

```sql
CREATE ASSERTION max_gpa
CHECK (
  NOT EXISTS (
    SELECT 1 FROM Enrollments
    WHERE gpa > 4.0
  )
);
```

The trigger catches the bad row *immediately* (before it is even inserted).
The assertion catches it *at commit* — a batch `INSERT` of 100 rows where one
has `gpa > 4.0` would succeed per-row but fail at `COMMIT`, rolling back all 100
rows.

**Shared characteristics:**
- Both are **procedural extensions** to declarative SQL.
- Both can be expensive: triggers fire on every event; assertions scan the
  database at commit.
- Both enforce rules that simple `CHECK` / `UNIQUE` / `FOREIGN KEY` cannot.
- Both are part of the schema (persist until dropped).

> **Key takeaway:** Triggers react per-event (row or statement), have access to
> `NEW`/`OLD`, and can perform arbitrary actions. Assertions evaluate a
> database-wide predicate at commit time and either accept or reject the entire
> transaction. Use triggers for granular, side-effect-heavy rules; use
> assertions for holistic, always-true invariants.

**Arrow summary — choosing the right tool:**

```text
Rule spans one table?
  |
  Yes v                   No v
  Can a CHECK do it?      Rule spans multiple tables?
  |                        |
  Yes → use CHECK        Yes v
  No  → use TRIGGER       use ASSERTION (if supported)
                          or TRIGGER (as a fallback)
```
