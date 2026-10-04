# Database Concurrency Control and Latching

## 1. Why Concurrency Control Is Needed

### Definition

**Concurrency** means multiple workers—threads or processes—accessing the database system and its data structures at the same time.

A **concurrency control protocol** is a set of rules that determines how multiple workers can safely access shared data structures simultaneously.

Think of it as the **traffic laws for database workers**:

```text
             Multiple Workers
                    |
          +---------+---------+
          |         |         |
         T1        T2        T3
          |         |         |
          +---------+---------+
                    |
             Shared Data
             Structure
                    |
             Must remain
            physically correct
```

### Why concurrency matters

Modern CPUs generally improve performance by providing:

* More CPU cores
* Multiple hardware threads
* Heterogeneous cores with different performance characteristics

Instead of making one CPU core dramatically faster, modern systems can execute more work concurrently.

Concurrency can also hide expensive operations such as disk I/O.

```text
Thread 1:
    Start disk request
         |
         | waiting...
         |
         +--------------------+
                              |
Thread 2:                    |
    Execute useful work      |
         |                    |
         +--------------------+
```

While one worker waits for disk access, another worker can use the CPU.

### Single-threaded systems

Some database systems avoid concurrency problems by having only one execution thread access their internal data structures.

The lecture's example was **Redis**.

If only one worker can modify a data structure:

```text
Worker
  |
  v
Data Structure
```

there is no possibility that two workers simultaneously modify the same structure.

### Advantages of single-threaded execution

* Simpler implementation
* No need for internal latches
* Fewer concurrency bugs
* Easier reasoning about data structures

### Disadvantages

* Cannot directly use multiple CPU cores for concurrent execution
* A worker can become a bottleneck
* Less opportunity to hide stalls using other workers

---

# 2. Physical vs. Logical Correctness

One of the most important distinctions in this lecture is between **physical correctness** and **logical correctness**.

## Physical Correctness

Physical correctness means that the **internal data structure remains valid**.

For example, suppose a B+ tree node contains:

```text
Node A
+----------------+
| key | pointer  |
+----------------+
       |
       v
     Node B
```

The pointer from A must actually point to B.

A concurrency bug could cause:

```text
Node A
   |
   v
Invalid memory
```

This could cause:

* Invalid memory access
* Corrupted data structures
* Segmentation faults
* Following invalid pointers
* Crashes

**Physical correctness is the main concern of this lecture.**

---

## Logical Correctness

Logical correctness asks whether the **data visible to queries is logically what it should be**.

For example:

```text
T1: INSERT ABC

T2: READ ABC
```

Should T2 see `ABC`?

That depends on the higher-level transaction/concurrency rules.

The lecture specifically says that this topic is handled later when discussing transactions.

### Important distinction

| Concept              | Question                                          | Covered Here? |
| -------------------- | ------------------------------------------------- | ------------- |
| Physical correctness | Is the data structure internally valid?           | Yes           |
| Logical correctness  | Does a query see the logically correct data?      | Later         |
| Example              | Does a pointer lead to a valid node?              | Physical      |
| Example              | Should a transaction see a newly inserted record? | Logical       |

### Exam Tip

If the question involves:

> "Could this pointer become invalid?"

think **physical correctness**.

If it involves:

> "Should this transaction see this record?"

think **logical correctness**.

---

# 3. Locks vs. Latches

These two terms are extremely important and easy to confuse.

## Latches

A **latch** is a low-level synchronization mechanism used to protect internal database data structures.

Examples:

* B+ tree nodes
* Hash table pages
* Hash table slots
* Other internal structures

Latches protect **critical sections**.

```text
Worker
   |
   v
Acquire Latch
   |
   v
Critical Section
   |
   v
Modify/Read Structure
   |
   v
Release Latch
```

Latches are normally held for extremely short periods:

* Nanoseconds
* Microseconds

---

## Locks

A **lock** is a higher-level mechanism used primarily for transaction concurrency control.

Locks protect **logical database operations/entities**.

A transaction might execute:

```text
INSERT
UPDATE
UPDATE
DELETE
```

and the database must make sure the operations behave correctly as one logical unit.

Locks may be held for much longer than latches.

---

## Locks vs. Latches Comparison

| Feature           | Latch                        | Lock                                 |
| ----------------- | ---------------------------- | ------------------------------------ |
| Level             | Low-level                    | High-level                           |
| Protects          | Internal data structures     | Transactions/logical entities        |
| Typical duration  | Nanoseconds/microseconds     | Potentially much longer              |
| Main concern      | Physical correctness         | Logical correctness                  |
| Modes             | Read / Write                 | More sophisticated transaction modes |
| Deadlock handling | Programmer/coding discipline | Database transaction system          |
| Example           | B+ tree node                 | Transaction modifying records        |

### Memory Trick

**Latch = Low-level**

**Lock = Logical**

---

# 4. Critical Sections

### Definition

A **critical section** is a portion of code that accesses shared data and therefore must be protected from conflicting concurrent operations.

Example:

```text
Acquire write latch

    Critical Section
    ----------------
    Modify B+ tree node
    Update pointer
    Update key

Release write latch
```

The goal is:

```text
Only compatible workers
can enter simultaneously.
```

---

# 5. Latch Modes

The lecture focuses on two basic latch modes:

1. Read
2. Write

## Read Latch

A **read latch** allows multiple workers to read the same critical section simultaneously.

As long as they are not modifying the data:

```text
        Read
         |
    +----+----+
    |    |    |
   T1   T2   T3
    |    |    |
    +----+----+
       READ
```

Multiple readers can coexist.

---

## Write Latch

A **write latch** provides exclusive access.

Only one worker can hold it.

```text
        Write
          |
          v
         T1
          |
     Critical
      Section

T2 -> WAIT
T3 -> WAIT
T4 -> WAIT
```

No other readers or writers can enter simultaneously.

---

# 6. Latch Compatibility

The compatibility rules are simple:

| Existing | Requested Read | Requested Write |
| -------- | -------------: | --------------: |
| Read     |     Compatible |    Incompatible |
| Write    |   Incompatible |    Incompatible |

Or:

```text
Read + Read     = OK
Read + Write    = NO
Write + Read    = NO
Write + Write   = NO
```

### Why?

Two readers do not modify the structure.

A writer could change:

* Keys
* Pointers
* Node contents
* Slot contents
* Structural information

while another worker is reading them.

That could cause the reader to observe an invalid or inconsistent structure.

---

# 7. Goals of a Good Latch Implementation

The lecture identifies several important goals.

## 1. Small memory footprint

Latches may be stored directly inside data structures.

For example:

```text
B+ Tree Page
+----------------------+
| Latch                |
| Keys                 |
| Values               |
| Pointers             |
+----------------------+
```

If a latch were huge, it would consume valuable storage space that could otherwise hold database records.

---

## 2. Fast uncontended path

If nobody else is using the latch, acquiring it should be extremely fast.

```text
No contention
     |
     v
Acquire immediately
     |
     v
Continue execution
```

There should not be unnecessary overhead.

---

## 3. Decentralized management

The database does not want one giant centralized structure tracking every latch.

A centralized system could become a bottleneck:

```text
T1 ----\
T2 -----\
T3 ------> Central Latch Manager
T4 -----/
T5 ----/
```

Instead, latches are stored near the data they protect:

```text
Page 1 -> its latch
Page 2 -> its latch
Page 3 -> its latch
```

---

## 4. Avoid operating-system calls

System calls are expensive compared with user-space operations.

The general goal is:

```text
User-space operation
        |
        v
Fast
```

rather than:

```text
User space
    |
    v
Kernel
    |
    v
Scheduler
    |
    v
Kernel data structures
    |
    v
User space
```

---

# 8. Spin Latches

One of the simplest latch implementations is a **test-and-set spin latch**.

### Definition

A **spin latch** repeatedly attempts to acquire a latch instead of immediately going to sleep.

Conceptually:

```text
while (latch is unavailable) {
    keep trying
}
```

This is called **spinning**.

---

## Advantages

* Very simple
* Very small
* Extremely fast when contention is low
* Avoids an operating-system call

## Disadvantages

* Burns CPU cycles
* Does not scale well under contention
* Can be problematic on NUMA systems
* A thread may repeatedly execute instructions without doing useful database work

---

# 9. Test-and-Set / Compare-and-Swap

The basic primitive behind many synchronization mechanisms is an **atomic CPU instruction**.

### Problem with normal code

Suppose we tried:

```cpp
if (value == 20) {
    value = 30;
}
```

Another thread could execute between the two operations:

```text
Thread 1:
    Check value == 20

                 Thread 2:
                 Changes value

Thread 1:
    Changes value to 30
```

The operation is not atomic.

---

## Atomic Compare-and-Swap

Compare-and-swap performs the check and update atomically.

Conceptually:

```text
if (memory == expected_value)
    memory = new_value;
```

The CPU guarantees that another worker cannot interfere between the comparison and update.

Example:

```text
Current value = 20

Compare against 20
       |
       v
   Match?
       |
      YES
       |
       v
Change to 30
```

The entire operation is atomic.

---

## C/C++ Intrinsics

The lecture showed the idea using a GCC/x86 intrinsic.

Conceptually:

```cpp
compare_and_swap(address, expected, new_value);
```

Compiler intrinsics provide a C/C++ interface to specialized CPU instructions.

### Important

An intrinsic is essentially a compiler-provided interface to a low-level machine instruction.

---

# 10. Why Spin Latches Can Be Expensive

## CPU Waste

Suppose T1 owns the latch:

```text
T1 -> LATCH

T2:
    try
    fail
    try
    fail
    try
    fail
    try
    fail
```

T2 is consuming CPU cycles even though it cannot make progress.

The operating system may think:

> T2 is actively executing, so it must be doing useful work.

But T2 is really just waiting.

---

# 11. NUMA and Spin Latches

### Definition

**NUMA** = Non-Uniform Memory Access.

In a multi-socket system, different CPU sockets may have their own local memory.

```text
CPU Socket 1              CPU Socket 2
+----------+              +----------+
| CPU      |              | CPU      |
| Local RAM|              | Local RAM|
+----------+              +----------+
       \                    /
        \                  /
          Interconnect
```

If a worker repeatedly spins on memory located on another socket, it repeatedly accesses remote memory.

That can be significantly more expensive than accessing:

* Local memory
* Local cache
* Local L3 cache

### Exam Tip

If you see:

> multi-socket / remote memory / spinning repeatedly

think **NUMA problem**.

---

# 12. Blocking OS Mutexes

Another approach is to use an operating-system mutex.

Conceptually:

```cpp
mutex.lock();

    // Critical section

mutex.unlock();
```

A thread that cannot acquire the mutex can be put to sleep by the OS.

This avoids wasting CPU cycles through indefinite spinning.

---

# 13. Futexes

On Linux, standard mutex implementations can use a **futex** (fast userspace mutex) mechanism.

The important idea is that a futex combines:

1. A fast user-space path
2. An OS-assisted blocking path

Conceptually:

```text
Try user-space acquisition
          |
       Success?
       /      \
     YES       NO
      |         |
    Done     Enter OS
                |
             Sleep
                |
          Latch available
                |
              Wake
```

### Why this is faster than always entering the kernel

If there is no contention:

```text
User Space
    |
    v
Acquire
```

No expensive OS interaction is necessary.

Only when contention occurs does the system need OS support.

---

# 14. Why Database Systems May Avoid OS Mutexes

The lecture emphasizes that database systems often want more control than the OS provides.

The OS must maintain its own metadata:

```text
OS scheduler
    |
    +-- waiting threads
    +-- scheduling information
    +-- synchronization metadata
    +-- internal locks
```

Therefore, an OS-managed mutex can involve additional synchronization and memory accesses.

A database system may know more about:

* How long the operation will take
* What work the worker can perform instead
* Whether the operation is likely to become available soon
* Which other database tasks can run

This allows a database-specific synchronization strategy to make better decisions.

---

# 15. Reader-Writer Latches

A **reader-writer latch** allows:

* Multiple concurrent readers
* Only one writer
* No readers while a writer holds the latch

```text
READ:
T1 ----\
T2 -----+----> Critical Section
T3 ----/

WRITE:
T4 ----------> Critical Section

T1 -> WAIT
T2 -> WAIT
T3 -> WAIT
```

---

## Reader-Writer Example

Suppose T1 reads:

```text
Reader count = 1
```

T2 also wants to read:

```text
Reader count = 2
```

Both can proceed.

Now T3 wants to write:

```text
Reader count = 2

T3 -> WAIT
```

The writer must wait until the readers finish.

---

# 16. Reader-Writer Latch State

A reader-writer latch may maintain information such as:

```text
Mode
Reader count
Waiting workers
```

Example:

```text
Mode: READ
Readers: 2
Waiting writers: 1
```

Once readers finish:

```text
Readers: 0
```

the writer may acquire the latch.

### Important

Reader-writer latches provide more concurrency than a simple exclusive latch, but require more bookkeeping and memory.

---

# 17. Deadlocks with Latches

### Definition

A **deadlock** occurs when workers wait indefinitely for resources held by one another.

Example:

```text
T1 holds A
T1 waits for B

T2 holds B
T2 waits for A
```

```text
T1 ---> B
 ^       |
 |       v
 A <--- T2
```

For latches, the lecture emphasizes that there generally isn't a centralized transaction manager detecting and breaking these deadlocks.

Therefore:

> **Latches rely heavily on coding discipline and avoidance.**

---

# 18. Latching Hash Tables

Hash table latching is relatively straightforward because workers generally move in the same direction when probing.

For example, linear probing:

```text
Hash(key)
   |
   v
Slot 3
   |
   v
Slot 4
   |
   v
Slot 5
   |
   v
Slot 6
```

Workers do not generally traverse backward and forward through the structure in a way that creates complicated latch dependencies.

This makes deadlocks easier to avoid.

---

# 19. Hash Table Latching Strategies

There are three major granularities discussed.

## Strategy 1: Global Latch

One latch protects the entire hash table.

```text
        Hash Table
       +----------+
       |          |
       |          |
       |          |
       +----------+
            ^
            |
        One Latch
```

### Advantage

Very simple.

### Disadvantage

Essentially makes the data structure single-threaded.

```text
T1 -> Hash Table
T2 -> WAIT
T3 -> WAIT
```

---

# 20. Page-Level Latching

Each page/block has its own latch.

```text
Hash Table

Page 1 -> Latch 1
Page 2 -> Latch 2
Page 3 -> Latch 3
```

A worker:

1. Acquires the current page's latch.
2. Searches it.
3. Releases it.
4. Moves to the next page.
5. Acquires the next page's latch.

```text
T1:
Latch Page 1
   |
Search
   |
Release Page 1
   |
Latch Page 2
   |
Search
```

### Advantage

More concurrency than a global latch.

### Disadvantage

Workers accessing different slots in the same page can still block each other.

---

# 21. Slot-Level Latching

The finest-grained approach is to give each slot its own latch.

```text
Page
+----+----+----+----+
| L1 | L2 | L3 | L4 |
+----+----+----+----+
```

Now two workers can operate on different slots simultaneously.

```text
T1 -> Slot 1
T2 -> Slot 4
```

Both can proceed.

### Advantage

Maximum concurrency.

### Disadvantage

More memory overhead.

If each key/value is tiny, the latch metadata could become a significant percentage of the storage.

---

# 22. Hash Table Latch Granularity Comparison

| Strategy | Concurrency | Memory Cost | Complexity   |
| -------- | ----------- | ----------- | ------------ |
| Global   | Low         | Very low    | Simple       |
| Page     | Medium      | Medium      | Moderate     |
| Slot     | High        | High        | More complex |

### Important Trade-off

This is a classic:

> **Storage vs. concurrency/performance trade-off.**

The best approach depends on:

* Workload
* Number of cores
* Entry size
* Contention
* Memory overhead

There is no universally optimal choice.

---

# 23. B+ Tree Latching

B+ tree latching is more complicated than hash table latching.

Why?

Because B+ trees can change their structure.

Operations can cause:

* Splits
* Merges
* Pointer changes
* Guide/separator key changes
* Sibling pointer changes

A worker could otherwise follow a pointer that is no longer valid.

---

# 24. The B+ Tree Concurrency Problem

Imagine:

```text
        A
        |
        B
        |
        D
       / \
      H   I
```

T1 begins traversing the tree looking for a key.

T1 sees:

```text
D -> H
```

Then T1 gets descheduled.

While T1 sleeps, T2 modifies the tree:

```text
H -> I
```

When T1 wakes up, its previous assumptions may no longer be valid.

Potential outcomes include:

```text
Invalid pointer
Segmentation fault
False negative
Incorrect traversal
```

The most dangerous case is following a pointer to invalid memory.

---

# 25. Latch Coupling / Latch Crabbing

### Definition

**Latch coupling**, also called **latch crabbing**, is a protocol for safely traversing a B+ tree concurrently.

The basic rule is:

> Acquire the child latch before releasing the parent latch.

```text
Parent
  |
  | acquire child
  v
Child
  |
  | safe
  v
Release parent
```

This prevents a worker from following a pointer after releasing the protection that guarantees the pointer is valid.

---

# 26. What Is a Safe Node?

A node is **safe** when the operation being performed cannot cause a structural change that requires modifying ancestors.

For an insertion:

```text
Safe = node has room
```

because it will not need to split.

For a deletion:

```text
Safe = node has enough entries
```

so deleting one will not cause a merge.

---

# 27. Search / Read Operation

For a normal B+ tree lookup:

```text
Root
 |
 v
Parent
 |
 v
Child
 |
 v
Leaf
```

Use read latches.

### Protocol

1. Acquire read latch on root.
2. Acquire read latch on child.
3. Release parent's read latch.
4. Continue downward.
5. Repeat.
6. Read the desired key at the leaf.
7. Release the leaf latch.

### Example

```text
A [READ]
 |
 v
B [READ]
 |
 v
D [READ]
 |
 v
H [READ]
```

Once B is safely latched:

```text
Release A
```

Once D is safely latched:

```text
Release B
```

And so on.

---

# 28. Why Acquire Child Before Releasing Parent?

Suppose you did this:

```text
Release Parent
     |
     v
Acquire Child
```

Another worker could modify the tree between those operations.

Instead:

```text
Parent [LOCKED]
     |
     v
Child [LOCKED]
     |
     v
Parent [RELEASED]
```

The parent remains protected until the child is safely protected.

This is the core idea of latch coupling.

---

# 29. Insert and Delete Operations

Insertions and deletions are more difficult because they may modify the tree structure.

Initially, the conservative approach is:

```text
Root: WRITE
  |
  v
Child: WRITE
  |
  v
Child: WRITE
  |
  v
Leaf: WRITE
```

Why write latches?

Because we do not initially know whether the operation will cause:

* A split
* A merge
* An ancestor modification

---

# 30. Conservative B+ Tree Update Protocol

### Insert/Delete

1. Acquire a write latch on the root.
2. Move to the next child.
3. Acquire its write latch.
4. Determine whether the child is safe.
5. If safe, release ancestors.
6. Continue downward.
7. Reach the leaf.
8. Perform the modification.

---

# 31. Delete Example

Suppose we want to delete key `38`.

Start:

```text
A [WRITE]
 |
 v
B [WRITE]
 |
 v
D [WRITE]
 |
 v
H [WRITE]
```

Suppose D and H have enough space that deleting a key will not cause a merge.

Once H is known to be safe:

```text
Release A
Release B
Release D
```

Then:

```text
Modify H
```

---

# 32. Why Release Higher-Level Latches Early?

Holding unnecessary latches reduces concurrency.

Suppose:

```text
A
|
B
|
D
|
H
```

If we know H is safe, we no longer need A, B, and D.

Keeping them would unnecessarily block other workers.

### Important Principle

> **Release latches as soon as it is safe to do so.**

---

# 33. Releasing Latches Top-Down

The lecture points out a performance optimization.

Suppose we hold:

```text
A
 |
 B
  |
  D
```

Once safe, release:

```text
A first
B second
D later
```

Why?

Because A protects a larger portion of the tree.

Releasing A first allows workers to access more of the tree.

### Important

The exact release order does not determine correctness in this example.

It is primarily a **performance optimization**.

---

# 34. Insert That Does Not Require a Split

Suppose we insert `45`.

Traversal:

```text
A [WRITE]
 |
 v
B [WRITE]
 |
 v
D [WRITE]
 |
 v
I [WRITE]
```

If B has room:

```text
Release A
```

If D has room:

```text
Release B
```

If I has room:

```text
Release D
Insert 45
```

The worker does not need to keep the entire path locked.

---

# 35. Insert That Requires a Split

Suppose we insert `25` and the leaf node F is full.

Traversal:

```text
A [WRITE]
 |
 v
B [WRITE]
 |
 v
C [WRITE]
 |
 v
F [WRITE]
```

Suppose:

```text
B = safe
C = safe
F = NOT safe
```

Then:

```text
Release A
Release B
Keep C
Keep F
```

Why keep C?

Because splitting F may require modifying C.

The new child/pointer information needs to be inserted into C.

---

# 36. B+ Tree Splitting

Conceptually:

```text
Before:

C
|
F
+----+----+
| k1 | k2 |
| k3 | k4 |
+----+----+
```

If F becomes too full:

```text
After:

        C
       / \
      F   G

F: k1 k2
G: k3 k4
```

C must be updated with information about the new node.

Therefore C must remain protected.

---

# 37. Optimistic Latching

The conservative method can become a bottleneck because every update starts with:

```text
WRITE latch on root
```

That effectively serializes updates at the root.

The optimization is to be **optimistic**.

### Optimistic idea

Assume the operation will **not** require a split or merge.

Therefore:

```text
Read latch root
      |
      v
Read latch child
      |
      v
Read latch child
      |
      v
Leaf
```

Only once we reach the leaf do we determine whether the assumption was correct.

---

# 38. Optimistic Insert/Delete Algorithm

### Step-by-step

1. Start at the root with a **read latch**.
2. Traverse downward using latch coupling.
3. Release safe parent latches.
4. Reach the leaf.
5. Determine whether the operation requires:

   * Split
   * Merge
6. If no structural change is needed:

   * Acquire write protection on the leaf.
   * Perform the operation.
7. If the assumption was wrong:

   * Release the latches.
   * Restart using the conservative write-latch protocol.

```text
              Start
                |
                v
        Read-latch traversal
                |
                v
             Leaf
                |
       Is split/merge needed?
          /             \
        NO              YES
        |                |
        v                v
    Perform         Restart with
    operation       write latches
```

---

# 39. Why Optimistic Latching Helps

Most operations may not require structural changes.

If most inserts/deletes can happen without:

* Splitting
* Merging
* Updating ancestors

then the optimistic path is much cheaper.

Instead of:

```text
WRITE root
WRITE child
WRITE child
WRITE leaf
```

we can usually do:

```text
READ root
READ child
READ child
WRITE leaf
```

This allows much more concurrency.

---

# 40. Optimistic Algorithm vs. Conservative Algorithm

| Feature             | Conservative               | Optimistic                                      |
| ------------------- | -------------------------- | ----------------------------------------------- |
| Root                | Write latch                | Read latch                                      |
| Assumption          | May need structural change | Probably no structural change                   |
| Typical path        | More restrictive           | More concurrent                                 |
| If assumption fails | Already protected          | Restart                                         |
| Complexity          | Simpler                    | More sophisticated                              |
| Performance         | Can bottleneck             | Usually better when structural changes are rare |

---

# 41. Restarting After Optimistic Failure

Suppose we optimistically reach F:

```text
A [READ]
 |
 B [READ]
 |
 C [READ]
 |
 F [WRITE]
```

Then discover:

```text
F is full
```

and insertion requires a split.

The optimistic assumption was wrong.

Therefore:

```text
Release current latches
       |
       v
Restart traversal
       |
       v
Use WRITE latches
```

This is often simpler than trying to preserve the entire previous traversal.

---

# 42. Why Not Reuse the Previous Traversal?

It might seem possible to remember:

```text
A -> B -> C -> F
```

and simply restart from C.

The problem is that after releasing latches, another worker could modify the tree.

For example:

```text
You saw:

B -> C -> F
```

After you release B and C:

```text
Another worker modifies B/C.
```

When you return, your previous assumptions may no longer be valid.

Therefore:

> The simplest safe solution is often to restart the traversal.

---

# 43. Read-to-Write Latch Upgrade

A natural question is:

> Can a read latch simply be upgraded to a write latch?

Generally, there is no simple atomic upgrade mechanism that lets every reader automatically convert into a writer while safely coordinating all other readers.

You can build more sophisticated mechanisms using:

* Reader counters
* Queues
* Waiting structures

but this adds complexity.

For the B+ tree protocol, restarting is often simpler.

---

# 44. Leaf-Level Scans

Point lookups are easier because traversal is mostly:

```text
Root -> Child -> Leaf
```

Range scans are harder because B+ trees commonly have sibling pointers between leaf nodes.

For example:

```text
Leaf A <-> Leaf B <-> Leaf C <-> Leaf D
```

Now workers can move horizontally.

This introduces new opportunities for deadlocks and conflicting latch acquisition orders.

---

# 45. Why Leaf Scans Are Different

Normal traversal:

```text
Root
 |
 v
Child
 |
 v
Leaf
```

Everybody moves:

```text
TOP
 |
 v
BOTTOM
```

This consistent direction makes deadlocks easier to avoid.

Leaf scanning introduces:

```text
A <-> B <-> C <-> D
```

Now one worker could move:

```text
B -> C
```

while another moves:

```text
C -> B
```

This creates the possibility of circular waiting.

---

# 46. Leaf Scan Latch Protocol

When moving from one leaf to another:

> Acquire the next leaf's latch before releasing the current leaf's latch.

Example:

```text
Current Leaf C [READ]
       |
       | acquire
       v
Next Leaf B [READ]
       |
       v
Release C
```

This ensures the pointer remains protected while it is being followed.

---

# 47. Multiple Readers During Leaf Scans

Suppose:

```text
T1 -> B
T2 -> C
```

Both use read latches.

Now:

```text
T1 wants C
T2 wants B
```

Since both are requesting read latches:

```text
Read + Read = Compatible
```

there is no conflict.

They can safely swap their positions.

---

# 48. Reader vs. Writer During Leaf Scan

Consider:

```text
T1 = Writer
T2 = Reader
```

T1 holds:

```text
C [WRITE]
```

T2 wants:

```text
C [READ]
```

Compatibility:

```text
WRITE + READ = INCOMPATIBLE
```

Therefore T2 cannot acquire the latch.

---

# 49. What Should a Worker Do If It Cannot Acquire a Latch?

The lecture presents three conceptual choices:

1. Wait
2. Kill/restart itself
3. Kill the other worker

For this low-level latching system, the preferred simple strategy is:

> **Do not wait indefinitely; abort/restart your own operation.**

---

# 50. No-Wait Latching

The preferred basic protocol is often called **no-wait mode**.

Conceptually:

```text
Try latch
    |
    v
Success?
 /     \
YES     NO
 |       |
 v       v
Work   Abort/restart
```

Instead of:

```text
Wait forever
```

the worker:

```text
Back out
Retry later
```

---

# 51. Why Kill Yourself Instead of the Other Worker?

Suppose:

```text
T1 holds latch
T2 wants latch
```

T2 generally does not know enough about T1 to safely terminate it.

T1 may have:

* Modified many nodes
* Inserted many keys
* Deleted many keys
* Acquired many latches
* Performed structural changes

Killing T1 could leave a large rollback operation.

T2 can instead abort its own attempt and retry.

```text
T2:
    Cannot acquire latch
         |
         v
    Undo own work
         |
         v
      Restart
```

This is simpler and safer.

---

# 52. Worker-Local Right Set

When performing writes, the worker needs to remember what it changed.

The lecture refers to this as a **write set** / worker-local tracking structure.

Example:

```text
Write Set

Node H
    inserted: key 45

Node I
    deleted: key 38

Node J
    inserted: key 50
```

If the operation cannot continue, the worker can use this information to undo its changes.

---

# 53. Rollback for Leaf Modifications

Suppose:

```text
T1:
Insert A
Insert B
Delete C
```

Then T1 fails to acquire another required latch.

It must undo its changes:

```text
Undo Delete C
Undo Insert B
Undo Insert A
```

This responsibility belongs to the worker performing the operation.

There is not a centralized latch manager that automatically understands every modification the worker made.

---

# 54. Splits and Merges During Rollback

Structural changes are harder to undo.

For example:

```text
Full node
    |
    v
Split
    |
    +---- Node A
    |
    +---- Node B
```

Completely reversing a split may be expensive.

The lecture notes that sometimes a database system can tolerate temporarily being slightly unbalanced rather than performing an expensive full reversal.

The important idea is:

> A failed operation may need a carefully designed cleanup strategy rather than blindly reversing every structural change.

---

# 55. Latch Deadlock Example

A dangerous pattern is:

```text
T1:
Hold B
Wait for C

T2:
Hold C
Wait for B
```

This produces:

```text
T1 ---> C
 ^       |
 |       v
 B <--- T2
```

Neither can proceed.

This is why latch acquisition order is important.

---

# 56. Avoiding Deadlocks Through Ordering

One of the main strategies is to impose a consistent acquisition order.

For B+ tree traversal:

```text
Root
  |
  v
Child
  |
  v
Leaf
```

Workers acquire latches from:

```text
Top -> Bottom
```

They do not simultaneously acquire unrelated nodes in arbitrary orders.

This greatly reduces the possibility of deadlock.

---

# 57. Hash Tables vs. B+ Trees

| Feature              | Hash Table            | B+ Tree                 |
| -------------------- | --------------------- | ----------------------- |
| Traversal            | Usually one direction | Top-down + leaf scans   |
| Structural changes   | Resize                | Splits/merges           |
| Latching complexity  | Relatively simple     | More complicated        |
| Deadlock concerns    | Lower                 | Higher                  |
| Fine-grained options | Page/slot             | Node/path/leaf          |
| Special protocol     | Basic latching        | Latch coupling/crabbing |

---

# 58. Global vs. Fine-Grained Latching

| Granularity | Example           | Concurrency | Overhead |
| ----------- | ----------------- | ----------: | -------: |
| Coarse      | Entire tree/table |         Low |      Low |
| Page/node   | One page/node     |      Medium |   Medium |
| Slot/record | Individual entry  |        High |     High |

### General rule

```text
More fine-grained
       |
       +--> More concurrency
       |
       +--> More metadata
       |
       +--> More complexity
```

---

# 59. Common Mistakes

## Mistake 1: Confusing locks and latches

Remember:

```text
Latch -> internal physical data structure
Lock  -> transaction/logical correctness
```

---

## Mistake 2: Thinking read + read conflicts

It does not.

```text
READ + READ = compatible
```

---

## Mistake 3: Thinking write + read is compatible

It is not.

```text
WRITE + READ = incompatible
```

---

## Mistake 4: Releasing the parent before acquiring the child

Wrong:

```text
Release parent
Acquire child
```

Correct:

```text
Acquire child
Release parent
```

This is the foundation of latch coupling.

---

## Mistake 5: Holding every latch until the operation finishes

This unnecessarily reduces concurrency.

Once a child is known to be safe:

```text
Release unnecessary ancestors.
```

---

## Mistake 6: Assuming every insertion requires write latches all the way down

That is the conservative approach.

The lecture also introduces **optimistic latching**, which starts with read latches and only restarts with write latches if a structural modification is required.

---

## Mistake 7: Thinking latches automatically detect deadlocks

They generally do not.

The programmer/database implementation must design the latch protocol to avoid deadlocks.

---

## Mistake 8: Thinking spinning always wastes CPU

Spinning wastes CPU **when the latch is unavailable for a meaningful amount of time**.

For very short critical sections, spinning can sometimes be faster than sleeping and waking through the OS.

---

## Mistake 9: Assuming killing another worker is easy

It is not.

The other worker may have:

* Acquired multiple latches
* Modified many nodes
* Performed structural changes
* Need rollback

Self-aborting is much simpler.

---

# 60. Query-Solving / Problem-Solving Strategy

When given a concurrency/latching problem on an exam, use this process.

## Step 1: Identify the data structure

Ask:

```text
Hash table?
B+ tree?
Leaf scan?
```

---

## Step 2: Identify the operation

Is it:

* Read/search?
* Insert?
* Delete?
* Range scan?
* Split?
* Merge?

---

## Step 3: Determine latch mode

General rule:

```text
Read/search -> READ
Modification -> WRITE
```

For optimistic updates:

```text
Initially READ
       |
       v
Check whether split/merge is required
       |
       +--> No -> modify leaf
       |
       +--> Yes -> restart with WRITE
```

---

## Step 4: Follow latch coupling

For B+ trees:

```text
Acquire child
      |
      v
Determine child is safe
      |
      v
Release parent
```

Never release the parent before safely acquiring the child.

---

## Step 5: Determine whether the node is safe

For insertion:

```text
Node has room?
    |
   YES -> safe
    |
   NO -> may split
```

For deletion:

```text
Node has enough entries?
    |
   YES -> safe
    |
   NO -> may merge
```

---

## Step 6: Release unnecessary ancestors

Once the child is safe:

```text
Release ancestors
```

This increases concurrency.

---

## Step 7: Check for conflicting latches

Use:

```text
R + R = compatible
R + W = conflict
W + R = conflict
W + W = conflict
```

---

## Step 8: If a latch cannot be acquired

For basic latch protocols:

```text
Abort/restart
```

rather than waiting indefinitely.

---

# 61. Important Syntax / Pseudocode

## Basic Spin Latch

Conceptually:

```cpp
while (latch.test_and_set()) {
	// Keep trying
}
```

Then:

```cpp
latch.clear();
```

The exact implementation may vary, but the important concept is:

```text
Try atomic acquisition
       |
       v
Success?
       |
      NO
       |
       v
Spin/retry
```

---

## Compare-and-Swap

Conceptually:

```cpp
compare_and_swap(address, expected, desired);
```

Meaning:

```text
if *address == expected:
	*address = desired
```

The operation is performed atomically.

---

## Mutex

Conceptually:

```cpp
mutex.lock();

	// Critical section

mutex.unlock();
```

A guard/RAII object can automatically release the mutex when it leaves scope.

---

# 62. B+ Tree Latch-Coupling Pseudocode

### Search

```text
latch READ(root)

while not at leaf:

	latch READ(child)

	release READ(parent)

	parent = child

read leaf

release leaf
```

---

### Conservative Insert/Delete

```text
latch WRITE(root)

while not at leaf:

	latch WRITE(child)

	if child is safe:
		release unnecessary ancestors

	parent = child

modify leaf
```

---

### Optimistic Insert/Delete

```text
latch READ(root)

traverse using latch coupling

reach leaf

if leaf is safe:
	acquire WRITE protection
	modify leaf
else:
	release latches
	restart with WRITE latches
```

---

# 63. Key B+ Tree Rules

Memorize these.

### Rule 1

**Always start B+ tree traversal at the root** under the normal protocol.

### Rule 2

**Acquire the child before releasing the parent.**

### Rule 3

**Read operations use read latches.**

### Rule 4

**Conservative modifications use write latches.**

### Rule 5

**A safe child allows ancestors to be released.**

### Rule 6

**Insertion safety = enough room to avoid a split.**

### Rule 7

**Deletion safety = enough occupancy to avoid a merge.**

### Rule 8

**Optimistic operations assume no split/merge first.**

### Rule 9

**If the optimistic assumption fails, restart.**

### Rule 10

**Leaf scans must protect the current node while acquiring the next node.**

---

# 64. Important Comparisons

| Concept               | Meaning                               | Main Difference                    |
| --------------------- | ------------------------------------- | ---------------------------------- |
| Lock                  | High-level transaction protection     | Logical correctness                |
| Latch                 | Low-level synchronization             | Physical correctness               |
| Read latch            | Shared access                         | Multiple readers allowed           |
| Write latch           | Exclusive access                      | Only one worker                    |
| Spin latch            | Repeatedly tries to acquire           | Burns CPU while waiting            |
| OS mutex              | OS-managed blocking synchronization   | Can put worker to sleep            |
| Reader-writer latch   | Separate reader/writer modes          | Multiple readers                   |
| Global latch          | Protects entire structure             | Simple but low concurrency         |
| Page latch            | Protects one page                     | More concurrency                   |
| Slot latch            | Protects individual slot              | Highest concurrency, more overhead |
| Conservative latching | Assume structural change possible     | Write latches early                |
| Optimistic latching   | Assume no structural change           | Read first, restart if wrong       |
| Latch coupling        | Acquire child before releasing parent | Protects traversal                 |
| Latch crabbing        | Alternative name for latch coupling   | Same basic idea                    |
| Physical correctness  | Internal structure is valid           | Focus of this lecture              |
| Logical correctness   | Query/transaction sees correct data   | Covered later                      |

---

# 65. Exam Review

## Must-Know Definitions

### Concurrency Control

Rules governing how multiple workers safely access shared database structures.

### Critical Section

A section of code accessing shared data that must be synchronized.

### Latch

A low-level synchronization mechanism protecting internal database data structures.

### Lock

A higher-level transaction synchronization mechanism.

### Read Latch

Allows multiple concurrent readers.

### Write Latch

Provides exclusive access to a critical section.

### Spin Latch

A latch where a worker repeatedly attempts acquisition instead of immediately sleeping.

### Compare-and-Swap

An atomic operation that compares a memory location with an expected value and conditionally replaces it.

### NUMA

Non-Uniform Memory Access; memory access costs can differ depending on which CPU/socket owns the memory.

### Latch Coupling

A B+ tree traversal technique where the child is latched before the parent is released.

### Safe Node

A node that cannot require a structural change for the current operation.

### Optimistic Latching

Assumes an operation will not require a split/merge and restarts with stronger latching if that assumption fails.

### Deadlock

A situation where workers wait for resources held by one another indefinitely.

### Write Set

Worker-local information recording modifications so they can be undone if the operation must abort.

---

# 66. Must-Know Methods

## Method 1: Read a B+ Tree

```text
1. READ latch root
2. READ latch child
3. Release parent
4. Continue
5. READ latch leaf
6. Read data
7. Release leaf
```

---

## Method 2: Conservative Insert

```text
1. WRITE latch root
2. WRITE latch child
3. Determine whether child is safe
4. Release safe ancestors
5. Continue
6. WRITE latch leaf
7. Insert
```

---

## Method 3: Conservative Delete

```text
1. WRITE latch root
2. WRITE latch child
3. Determine whether child can absorb deletion
4. Release safe ancestors
5. Continue
6. WRITE latch leaf
7. Delete
```

---

## Method 4: Optimistic Insert/Delete

```text
1. READ latch root
2. Traverse using latch coupling
3. Reach leaf
4. Determine whether split/merge is needed
5. If safe -> perform operation
6. If unsafe -> release/restart
7. Retry with WRITE latches
```

---

## Method 5: Leaf Range Scan

```text
1. Hold current leaf latch
2. Acquire next leaf latch
3. Release current leaf latch
4. Read next leaf
5. Repeat
```

Never blindly:

```text
Release current
      |
      v
Follow pointer
      |
      v
Acquire next
```

---

# 67. Must-Know Latch Compatibility

```text
                 REQUEST
              READ      WRITE

HELD READ      YES        NO

HELD WRITE      NO        NO
```

Memorize:

```text
R + R = OK
R + W = NO
W + R = NO
W + W = NO
```

---

# 68. Must-Know B+ Tree Diagram

### Read

```text
        ROOT
       [READ]
          |
          v
       CHILD
       [READ]
          |
          v
        LEAF
       [READ]

Release ROOT once CHILD is latched.
Release CHILD once LEAF is latched.
```

### Conservative Write

```text
        ROOT
       [WRITE]
          |
          v
       CHILD
       [WRITE]
          |
          v
        LEAF
       [WRITE]
```

Release ancestors once the current child is known to be safe.

---

# 69. Must-Know Optimistic Diagram

```text
             START
               |
               v
        READ-LATCH ROOT
               |
               v
        READ-LATCH CHILD
               |
               v
          Continue down
               |
               v
             LEAF
               |
               v
       Is structural change
             needed?
          /           \
        NO             YES
        |               |
        v               v
    Modify leaf     Release
                    latches
                       |
                       v
                   Restart
                       |
                       v
                 WRITE-LATCH
                   traversal
```

---

# 70. The Big Picture

The entire lecture can be reduced to this progression:

```text
Multiple Workers
       |
       v
Shared Data Structures
       |
       v
Need Concurrency Control
       |
       v
Use Latches
       |
       +----------------------+
       |                      |
       v                      v
   Hash Tables             B+ Trees
       |                      |
       v                      v
Simple latching        Latch coupling
                              |
                              v
                     Safe child nodes
                              |
                              v
                    Release ancestors
                              |
                              v
                    Optimistic updates
                              |
                              v
                 Restart if assumption fails
                              |
                              v
                       Leaf scans
                              |
                              v
                   More complex conflicts
```

---

# 71. Final Cheat Sheet / Memory Sheet

## Core Concepts

```text
Latch = low-level
Lock = high-level

Latch -> physical correctness
Lock  -> logical correctness
```

## Modes

```text
READ  = shared
WRITE = exclusive

R + R = compatible
R + W = incompatible
W + R = incompatible
W + W = incompatible
```

## Spin Latch

```text
Try
 |
 +-- Success -> Continue
 |
 +-- Failure -> Spin/retry
```

Fast but can waste CPU.

---

## OS Mutex / Futex

```text
Try user space
      |
      +-- Success -> Done
      |
      +-- Failure -> OS
                       |
                       v
                     Sleep
                       |
                       v
                     Wake
```

---

## Hash Tables

```text
Global latch
    ↓
Simple / low concurrency

Page latch
    ↓
Medium concurrency

Slot latch
    ↓
High concurrency / higher memory cost
```

---

## B+ Trees

### Search

```text
READ parent
   ↓
READ child
   ↓
Release parent
   ↓
Continue
```

### Insert/Delete

Conservative:

```text
WRITE root
   ↓
WRITE child
   ↓
Check safety
   ↓
Release ancestors when safe
   ↓
Modify leaf
```

Optimistic:

```text
READ root
   ↓
READ downward
   ↓
Reach leaf
   ↓
Check split/merge
   ↓
NO → Modify
YES → Restart with WRITE
```

---

## Safe Node

```text
INSERT:
Enough space?
    YES → SAFE
    NO  → May split

DELETE:
Enough occupancy?
    YES → SAFE
    NO  → May merge
```

---

## Latch Coupling

**Most important rule:**

```text
ACQUIRE CHILD
      ↓
RELEASE PARENT
```

Never reverse that order during traversal.

---

## Leaf Scans

```text
Current leaf [latched]
       |
       v
Acquire next leaf
       |
       v
Release current leaf
       |
       v
Continue
```

This protects sibling pointers while traversing.

---

## Failed Latch Acquisition

Basic low-level strategy:

```text
Can't acquire
     |
     v
Abort/restart yourself
     |
     v
Try again
```

Do not blindly wait forever.

---

## Most Important Exam Questions to Expect

1. **What is the difference between a lock and a latch?**
2. **What is physical vs. logical correctness?**
3. **Which latch combinations are compatible?**
4. **Why can spin locks waste CPU?**
5. **What problem does NUMA create for spin latches?**
6. **What is compare-and-swap?**
7. **What is a reader-writer latch?**
8. **Why is hash table latching easier than B+ tree latching?**
9. **What is latch coupling/latch crabbing?**
10. **When is a B+ tree node considered safe?**
11. **Why acquire a child latch before releasing the parent?**
12. **What is the difference between conservative and optimistic latching?**
13. **What happens when an optimistic B+ tree update discovers a split/merge is necessary?**
14. **Why can leaf-node scans create more complicated deadlock situations?**
15. **Why is restarting yourself generally preferable to killing another worker?**
16. **Why do fine-grained latches improve concurrency but increase storage overhead?**
17. **Why should unnecessary ancestor latches be released as soon as possible?**

---

# 72. One-Minute Review

If you only have one minute before the exam, remember:

```text
LATCHES
↓
Protect internal data structures
↓
Physical correctness

READ
↓
Multiple readers allowed

WRITE
↓
Exclusive

R + R = OK
Everything involving W = conflict

B+ TREE
↓
Latch coupling
↓
Acquire child BEFORE releasing parent
↓
Safe child = can release ancestors

INSERT
↓
Safe if node has room

DELETE
↓
Safe if node can absorb deletion

OPTIMISTIC
↓
Assume no split/merge
↓
Read-latch traversal
↓
If wrong → restart with write latches

LEAF SCANS
↓
Acquire next leaf before releasing current

LATCH CONFLICT
↓
Prefer abort/restart rather than indefinite waiting

HASH TABLE
↓
Global < Page < Slot
in concurrency
but
Global < Page < Slot
in overhead
```

## Final Takeaway

The central idea of the lecture is:

> **Concurrent database workers must be able to operate simultaneously without corrupting the physical structure of the database.**

Latches provide the low-level protection needed to make this possible. Hash tables can use relatively simple latch strategies, while B+ trees require **latch coupling**, **safe-node detection**, and often **optimistic traversal** to achieve high concurrency without allowing workers to follow invalid pointers or corrupt the tree.
