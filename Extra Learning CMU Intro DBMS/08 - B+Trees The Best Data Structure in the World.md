# B+ Trees — Data Structures

## 1. B+ Tree Insertions and Node Splitting

A B+ tree is a balanced tree structure used heavily in database indexes.

The main goals are:

- Keep the tree balanced.
- Keep data sorted.
- Allow efficient searches.
- Allow efficient insertions and deletions.
- Minimize expensive disk I/O.
- Keep the tree's height small.

When inserting a key, we follow the tree from the root down to the appropriate leaf node.

If the leaf has room:

1. Insert the key.
2. Keep the keys sorted.
3. Done.

If the leaf is full:

1. Insert the new key conceptually.
2. Split the overflowing node.
3. Divide the keys between the original node and a new node.
4. Copy/promote a discriminator key into the parent.
5. Update the parent to point to the new node.
6. If the parent is also full, recursively split the parent.
7. Continue upward until the tree is fixed.

---

# 2. Example of a Split Propagating Upward

Suppose we insert `16`.

The leaf node becomes too full, so we split it.

The keys are divided so that:

- Values `< 16` stay in the original node.
- Values `>= 16` go into the new node.

The parent must now know about the new node.

Therefore, we insert `16` into the parent as a discriminator key.

Conceptually:

    Before:

              [9]
             /   \
        [5, 9]  [19, 20]

    Insert 16:

              [9]
             /   \
        [5, 9]  [16, 19, 20]

If the parent is full, we cannot simply stop.

We must split the parent too.

This process can continue recursively all the way to the root.

---

# 3. Splitting the Root

The root is special because splitting it can increase the height of the tree.

For example:

    Before:

                 [5, 9, 13, 19]
                       |
                  overflowing

If the root overflows, we split it.

A middle discriminator such as `13` can be promoted to a new root:

                    [13]
                   /    \
             [5, 9]    [16, 19]

The tree has now become taller.

## Important Rule

When splitting a node:

- The overflowing node is reorganized.
- The parent is updated.
- If the parent overflows, split the parent.
- Continue upward.
- Do NOT reorganize already-correct subtrees below the level being fixed.

Once a lower-level split has been handled, those lower levels are already balanced.

---

# 4. Why Can't We Just Stop After Splitting One Node?

Suppose a node overflows and we create another node.

It may appear that the tree is locally correct.

However, the parent still needs to correctly represent the new structure.

The parent must contain a discriminator key and pointer that allows searches to reach the new node.

If we fail to update the parent, a search may follow the wrong path.

More importantly, if the parent itself becomes unbalanced or overflows, the B+ tree's structural rules are violated.

Therefore:

    Leaf split
        ↓
    Update parent
        ↓
    Parent split if necessary
        ↓
    Update grandparent
        ↓
    Continue upward
        ↓
    Stop at a valid root

---

# 5. Optimization: Redistribute Before Splitting

A node does not necessarily have to be split immediately.

Suppose a leaf is full but one of its neighboring sibling nodes has extra space.

We could potentially redistribute keys between the siblings.

Example:

    Node A: [9, 11]
    Node B: [13, 14, 15]

Suppose inserting `16` would overflow Node B.

Instead of splitting Node B, we could potentially move keys between the siblings.

For example:

    Node A: [9, 11, 13]
    Node B: [14, 15, 16]

This avoids creating a new node.

## Why Isn't This Always Done?

Because it requires additional work:

- Find the sibling.
- Potentially latch additional nodes.
- Move keys.
- Update parent discriminator keys.
- Maintain sibling relationships.

The simple implementation is:

    Overflow → Split

The optimized implementation may be:

    Overflow
       ↓
    Check sibling
       ↓
    Redistribute if possible
       ↓
    Otherwise split

The lecture emphasizes learning the basic protocol first because the optimization adds machinery.

---

# 6. Why the Tree Must Remain Balanced

A B+ tree is balanced because all leaf nodes should exist at the same depth.

For example:

    Correct:

                 [13]
                /    \
             [5,9] [16,19]
               |      |
             leaves  leaves

All leaves are at the same level.

If we allowed one side of the tree to grow differently from the other, the structure would no longer satisfy the B+ tree's balance requirements.

The tree might still sometimes produce correct answers, but its performance guarantees and structural properties would be compromised.

---

# 7. Database Pages Make B+ Tree Reorganization Efficient

B+ tree nodes are backed by database pages.

This is important.

Suppose part of the tree is currently on disk.

When reorganizing another portion of the tree, we do not necessarily have to load the entire tree into memory.

Instead, we can update:

- Page IDs
- Pointers
- Parent relationships
- Discriminator keys

The database buffer pool loads only the pages needed for the operation.

This is one reason B+ trees work well in database systems.

Large portions of the tree can remain on disk without interfering with operations occurring elsewhere.

---

# 8. B+ Tree Deletions

Deletion is essentially the opposite of insertion.

When deleting a key:

1. Find the appropriate leaf.
2. Remove the key.
3. Check whether the node is still sufficiently full.

If the node is still at least half full:

    Done.

If the node becomes less than half full:

    Try to redistribute from a sibling.

If redistribution is impossible:

    Merge with a sibling.

If the merge causes the parent to become underfull:

    Recursively fix the parent.

This process can continue all the way to the root.

---

# 9. Deletion Case 1: Node Remains at Least Half Full

Suppose a node contains enough keys after deletion.

Example:

    Before:
    [5, 6, 9, 11]

Delete `6`:

    [5, 9, 11]

If the node still satisfies the minimum occupancy requirement:

    No restructuring is necessary.

The operation is finished.

---

# 10. Deletion Case 2: Borrow From a Sibling

If deleting a key makes a node less than half full, first try to borrow a key from a sibling.

The sibling is sometimes called a "rich sibling" if it has enough keys to give one away while remaining valid.

Example:

    Node A: [5, 6]
    Node B: [9, 11, 12]

Delete `6`:

    Node A: [5]

Node A is now underfull.

If Node B can give up a key:

    Node A: [5, 9]
    Node B: [11, 12]

The tree can remain balanced without a merge.

However, the parent discriminator may need to be updated.

---

# 11. Updating Parent Discriminator Keys

This is extremely important.

Suppose the parent uses a discriminator key to decide which child to follow.

If keys move between children, the discriminator may become incorrect.

Example:

    Before:

                  [12]
                 /    \
             [5, 9] [12, 17]

Suppose `9` moves into the left/right arrangement and the smallest key in the right child changes.

The parent must be updated so searches still follow the correct path.

The parent discriminator is not necessarily actual stored table data.

It is a guidepost telling the search where to go.

---

# 12. Only Check Nearby Siblings

In a simple implementation, when a node becomes underfull, you generally check nearby siblings rather than searching the entire tree for a node that can donate a key.

Why?

Because looking at many siblings means:

- More pages may need to be accessed.
- More latches may need to be acquired.
- More concurrency overhead occurs.
- The implementation becomes more complicated.

Therefore, a common strategy is:

    Underfull node
        ↓
    Check adjacent sibling
        ↓
    Can sibling donate?
       / \
     Yes  No
      ↓    ↓
    Steal  Merge

---

# 13. Deletion Case 3: Merge

If the node is underfull and none of its siblings can donate a key, we must merge.

Example:

    Node A: [13, 17]
    Node B: [21, 23]

Suppose deleting `19` leaves another node underfull and neither neighbor can donate.

We merge nodes.

For example:

    [20] + [21, 23]

becomes:

    [20, 21, 23]

The node that disappears no longer needs to be referenced by the parent.

Therefore, we must remove the corresponding discriminator key/pointer from the parent.

---

# 14. Merge Can Propagate Upward

This is the deletion equivalent of recursive splitting.

Example:

    Leaf becomes underfull
          ↓
    Cannot borrow
          ↓
    Merge leaves
          ↓
    Parent loses a pointer/key
          ↓
    Parent becomes underfull
          ↓
    Parent must merge/redistribute
          ↓
    Continue upward

Therefore, one deletion can potentially affect several levels of the tree.

---

# 15. Root Shrinking

The root has special rules.

If merging causes the root to have only one meaningful child, the tree can shrink.

For example:

    Before:

                 [13]
                /    \
             [5,9] [16,19]

After merging:

                 [13]
                    \
                 [5,9,16,19]

The root is no longer necessary as a separate level.

The child can become the new root.

The tree's height decreases.

So:

    Insertions can increase tree height.

    Deletions can decrease tree height.

---

# 16. Root Occupancy Is Special

The root is generally allowed to be less than half full.

The normal minimum-occupancy rule applies differently to the root.

This is necessary because otherwise the tree could become unnecessarily difficult to maintain.

The root can temporarily have fewer keys while still maintaining a valid B+ tree.

---

# 17. Discriminator Keys Are Not Necessarily Real Data

This is one of the most important B+ tree concepts.

Inner nodes contain discriminator/search keys.

These keys tell the database where to search.

The actual data is stored in the leaf nodes.

Therefore, an inner node can contain a key that no longer exists as an actual record.

Example:

    Inner node:
    [19]

    Leaf nodes:
    [13, 17]    [21, 23]

Even if the actual record `19` is deleted, the inner node may still contain `19` temporarily as a guidepost.

Searching for `19` does NOT mean:

    "I found 19 in the inner node."

Instead:

    "The inner node tells me which leaf to search."

Then the leaf determines whether the actual key exists.

---

# 18. Composite Indexes

B+ trees can support composite indexes.

A composite index uses multiple attributes as the index key.

Example:

    CREATE INDEX idx_abc
    ON table(A, B, C);

The index key is conceptually:

    (A, B, C)

The database stores these components in order.

For example:

    Key = (A=1, B=2, C=7)

The database knows the data types and sizes of A, B, and C from the catalog.

Therefore, it knows how to interpret the bytes making up the composite key.

---

# 19. Why B+ Trees Work Well for Composite Keys

Because B+ trees maintain sorted order.

Suppose the index is:

    (A, B, C)

The keys are sorted primarily by A.

Within the same A value, they are sorted by B.

Within the same A and B values, they are sorted by C.

Conceptually:

    A=1
       B=1
          C=1,2,3
       B=2
          C=1,2,3
    A=2
       B=1
          C=1,2,3

This ordering enables several types of searches.

---

# 20. Full Composite-Key Lookup

Suppose the index is:

    (A, B)

and the query is:

    A = 1
    AND B = 2

The B+ tree can directly navigate using both components.

It compares:

1. A first.
2. Then B within matching A values.

This gives a very efficient lookup.

---

# 21. Prefix Lookup

Suppose the index is:

    (A, B)

but the query only specifies:

    A = 1

This is still efficient.

The tree can navigate to the first location where:

    A = 1

Then scan through the leaf nodes until the A value changes.

Example:

    (1,1)
    (1,2)
    (1,3)
    (1,7)
    (2,1)
    (2,4)

For:

    A = 1

we can scan:

    (1,1)
    (1,2)
    (1,3)
    (1,7)

Then stop when we reach:

    (2,1)

because A is no longer `1`.

This is called a prefix lookup.

---

# 22. Suffix / Skip Scan

Suppose the index is:

    (A, B)

but the query only specifies:

    B = 2

This is much harder.

The index is primarily sorted by A.

So all of the values of B are not grouped together globally.

Conceptually:

    A=1: B=1, B=2, B=3
    A=2: B=1, B=2, B=5
    A=3: B=2, B=4, B=7

Searching only for:

    B=2

may require examining many leaf nodes.

Some database systems have optimizations called:

    Skip scans
    Suffix searches
    Partial-key searches

But these require additional machinery.

---

# 23. Order of Predicates in SQL

The SQL query does NOT necessarily need to list conditions in the same order as the index.

Suppose the index is:

    (A, B)

These can be semantically equivalent:

    WHERE A = 1 AND B = 2

and:

    WHERE B = 2 AND A = 1

SQL is declarative.

The database optimizer decides how to execute the query.

The written order of predicates does not necessarily determine execution order.

---

# 24. Query Optimization and Join Ordering

Database systems can reorder operations to improve performance.

For example, when joining several tables, the order in which joins are performed can make an enormous difference.

A good optimizer attempts to find an efficient execution plan.

This is especially important because:

    (A JOIN B) JOIN C

can have dramatically different costs from:

    A JOIN (B JOIN C)

The database optimizer tries to choose a good plan rather than blindly following the order written by the programmer.

---

# 25. Duplicate Keys

Primary keys are normally unique.

However, secondary indexes can contain duplicate values.

Example:

    ZIP Code

Many people can have:

    15213

Therefore, an index on ZIP code cannot assume every index key is unique.

Another example is multi-versioning, where multiple physical versions of a tuple may have the same logical key.

The database therefore needs a way to distinguish physical records.

---

# 26. Best Way to Handle Duplicate Index Keys

The preferred approach is to append a hidden unique identifier to the index key.

That identifier is typically the record ID (RID).

A record ID can be thought of as:

    RID = page ID + slot/offset

The logical key might be:

    ZIP = 15213

But internally the index key becomes something conceptually like:

    (15213, RID)

For example:

    (15213, RID1)
    (15213, RID2)
    (15213, RID3)

Now every physical index entry is unique.

---

# 27. Why the RID Trick Works With B+ Trees

Suppose the index is:

    (ZIP, RID)

A query may only know:

    ZIP = 15213

It does not know the RID.

But because ZIP is the prefix of the composite key, the B+ tree can find the beginning of the ZIP range and scan all matching entries.

Conceptually:

    (15213, RID1)
    (15213, RID2)
    (15213, RID3)
    (15214, RID4)

The database scans all entries beginning with:

    15213

Then stops once it reaches:

    15214

---

# 28. Bad Approach: Overflow Leaf Nodes for Duplicate Keys

Another possible approach is to create overflow nodes for duplicate keys.

Example:

    [6]
      |
      v
    overflow
      |
      v
    overflow

This resembles chained buckets in a hash table.

The lecture strongly discourages using this approach for duplicate keys.

Why?

Because it creates additional chains that the database must follow.

This can hurt lookup performance.

More importantly, it creates problems when the B+ tree eventually needs to split.

---

# 29. Why Duplicate-Key Overflow Nodes Are Bad During Splits

Suppose:

    [7, 7, 7, 7, 7, 8]

and several `7` entries are stored in overflow nodes.

Now a new key such as `7.5` needs to be inserted.

The tree needs to split around the appropriate location.

The database may have to:

1. Follow the overflow chain.
2. Load all overflow pages.
3. Bring the entries into memory.
4. Reorganize them.
5. Determine where they belong.
6. Split them between the new nodes.

This creates unnecessary work.

Appending the RID directly to the key avoids this problem.

---

# 30. Clustered Indexes

A clustered index means the table's physical data is organized according to the ordering of an index.

Think:

    Index order
        ↓
    Physical table order

This can make range queries much faster.

A hash index cannot provide this ordering because hashing intentionally destroys ordering.

B+ trees can provide clustered ordering because their keys are sorted.

---

# 31. Index-Organized Storage

In an index-organized table, the leaf nodes of the B+ tree contain the actual tuples rather than simply RIDs.

The data is therefore physically organized according to the B+ tree's ordering.

This can make range scans very efficient.

For example:

    WHERE primary_key BETWEEN 100 AND 200

The database can:

1. Find key 100.
2. Follow the leaf sibling pointers.
3. Continue scanning.
4. Stop after key 200.

The records are already stored in the appropriate order.

---

# 32. Clustered vs. Unclustered Index

## Clustered

The table data is physically organized according to the index.

Example:

    Index order:
    1, 2, 3, 4, 5, 6

    Table pages:
    1, 2, 3, 4, 5, 6

Range scans can be efficient.

## Unclustered

The index is sorted, but the actual table records are scattered across pages.

Example:

    Index:
    1 → Page 100
    2 → Page 7
    3 → Page 84
    4 → Page 12

A range scan through the index may cause many random page accesses.

---

# 33. Random I/O Problem

Suppose an index scan produces these record IDs:

    Page 102
    Page 103
    Page 104
    Page 102
    Page 105
    Page 104

A naive implementation might fetch pages repeatedly.

If the buffer pool is small, it might do:

    Read Page 102
    Throw it away
    Read Page 103
    Throw it away
    Read Page 104
    Throw it away
    Read Page 102 again

This is inefficient.

---

# 34. Optimization: Sort Record IDs by Page ID

A database can first scan the index and collect the required RIDs.

Then it can sort those RIDs by page ID.

Example:

    Original order:

    Page 102
    Page 103
    Page 104
    Page 102
    Page 105
    Page 104

Reorder:

    Page 102
    Page 102
    Page 103
    Page 104
    Page 104
    Page 105

Now each page can be fetched once.

This reduces random I/O.

The database still maintains the information necessary to reconstruct the logical result order if needed.

---

# 35. Bitmap Heap Scan

Some database systems use bitmap techniques for this purpose.

PostgreSQL calls one related technique a:

    Bitmap Heap Scan

The general idea is:

1. Scan an index.
2. Determine which table pages contain matching records.
3. Build a bitmap or equivalent structure.
4. Retrieve the required pages efficiently.
5. Avoid unnecessary random I/O.

This is especially useful when many records match a query.

---

# 36. Combining Multiple Indexes

Suppose we have:

    Index 1: A
    Index 2: B

And the query is:

    WHERE A = 1
      AND B = 2

The database can potentially:

1. Scan index A.
2. Collect matching page IDs.
3. Scan index B.
4. Collect matching page IDs.
5. Intersect the page-ID sets.
6. Retrieve only the pages that are needed.

This is another example of using indexes to reduce unnecessary disk I/O.

---

# 37. B+ Tree Node Size

B+ tree node size is an important design decision.

Different systems may use different node/page sizes.

The optimal size depends on the hardware.

---

# 38. Larger Nodes

Larger nodes mean:

- More keys per node.
- Higher fan-out.
- Fewer tree levels.
- Potentially fewer page accesses.

This can be useful for slower storage.

For example, on a spinning hard disk, larger nodes can reduce expensive disk accesses.

The lecture mentions node sizes potentially reaching around megabytes on slower storage.

---

# 39. Smaller Nodes

Smaller nodes can be better when storage is extremely fast, such as in-memory systems.

The idea is:

    Small node
       ↓
    Acquire latch
       ↓
    Search node
       ↓
    Release latch quickly

Smaller nodes can reduce the amount of work required while holding a latch.

---

# 40. Inner Node vs. Leaf Node Size

Inner nodes and leaf nodes do not necessarily need the same size.

If inner nodes store only:

    discriminator keys + pointers

they can fit many entries.

A high fan-out means the tree can remain shallow.

For example:

    Root
      ↓
    hundreds of children
      ↓
    thousands of leaf nodes

A high fan-out is one reason B+ trees have relatively small heights.

---

# 41. Hardware Determines Node Size

There is no universal optimal node size.

Factors include:

- HDDs
- SSDs
- NVMe
- RAM
- Cache sizes
- CPU speed
- Memory latency
- Buffer pool behavior
- Latch overhead

Fast hardware may favor smaller nodes.

Slower storage may favor larger nodes.

---

# 42. Merge Threshold

The basic B+ tree rule says that a node should generally remain at least approximately half full.

If it drops below the threshold:

    Try redistribution
          ↓
    Otherwise merge

This maintains balance.

However, always immediately merging can cause unnecessary work.

---

# 43. Delayed Merging

Suppose a node becomes slightly underfull.

If we immediately merge it, the database performs extra work.

Then, shortly afterward, if a new insertion arrives, the merged node may fill up and require a split.

This creates:

    Merge
      ↓
    Split
      ↓
    Merge
      ↓
    Split

This is undesirable.

A system can therefore relax the occupancy requirement and delay merges.

The goal is to reduce unnecessary disk I/O and restructuring.

---

# 44. Occupancy Rate

With the traditional half-full rule, the average occupancy is roughly around:

    69–70%

The exact behavior depends on workload and implementation.

Relaxing the merge policy can sometimes improve performance because it avoids constant splitting and merging.

The resulting structure may not be perfectly balanced in terms of occupancy, even though the tree remains structurally balanced.

---

# 45. Non-Balanced / Relaxed B+ Trees

The lecture refers to a PostgreSQL implementation as a type of relaxed/non-balanced B+ tree.

The important idea is:

The tree remains balanced structurally, but occupancy rules may be relaxed.

In other words:

    Structural balance:
        Maintained

    Exact occupancy:
        May be relaxed

This is an optimization.

---

# 46. Variable-Length Keys

B+ trees also need to handle variable-length keys.

Examples:

    VARCHAR
    TEXT
    Variable-length strings

A fixed-size key is easy:

    [key][pointer]
    [key][pointer]
    [key][pointer]

Variable-length keys are more complicated.

---

# 47. Option 1: Store Pointers to the Actual Keys

Instead of storing the complete variable-length key inside the index, the index could store a pointer/RID to the actual tuple.

Conceptually:

    Index:

    key pointer
         ↓
    table tuple
         ↓
    actual key

The advantage is reduced duplication.

The disadvantage is that searching requires following another pointer to retrieve the actual key.

That means additional memory or disk accesses.

---

# 48. Why Pointer-Only Storage Is Usually Not Ideal

Even in memory, random accesses are not free.

Following a pointer can cause:

- Cache misses
- Additional memory accesses
- Worse locality

On disk, the problem is much worse.

Therefore, storing pointers instead of keys is generally not the preferred approach for normal B+ tree implementations.

---

# 49. Option 2: Variable-Sized Nodes

Another approach is to allow nodes to have different sizes.

For example:

    1 KB node
    2 KB node
    4 KB node
    8 KB node

This allows the system to fit variable-length keys efficiently.

However, it makes memory management more complicated.

The buffer pool now needs to manage variable-sized frames.

The database is effectively taking on some of the responsibilities normally handled by memory allocators such as malloc.

This approach is mostly seen in academic/research systems.

---

# 50. Option 3: Padding

A simpler solution is to reserve enough space for the maximum possible key.

For example:

    Maximum key size = 32 bytes

Even if the actual key is:

    "Cat"

the database reserves 32 bytes.

Unused space can be padded.

Advantages:

- Simple.
- Fixed-size slots.
- Easy implementation.

Disadvantage:

- Can waste significant space.

---

# 51. Option 4: Offset Array

A common practical approach is similar to a slotted page.

The page contains:

- Key data.
- An array of offsets.

The offset tells the database where a particular variable-length key begins.

Conceptually:

    Page
    ┌─────────────────────┐
    │ key data            │
    │                     │
    │ variable keys       │
    │                     │
    ├─────────────────────┤
    │ offset array        │
    │ offset → key        │
    └─────────────────────┘

This allows variable-length keys without requiring every key to occupy the same amount of space.

---

# 52. Very Large Keys

If a key is too large to fit comfortably inside the node, the database can use overflow storage.

The key is stored across additional pages.

This is similar to how large variable-length values can be handled elsewhere in database storage.

---

# 53. Searching Within a B+ Tree Node

Once we reach a node, we need to determine which key/pointer to use.

There are several possibilities:

1. Linear search.
2. Binary search.
3. SIMD/vectorized search.
4. Interpolation search.

---

# 54. Linear Search

The simplest method is a linear scan.

Example:

    [4, 5, 6, 7, 8, 9, 10]

Searching for `8`:

    Check 4
    Check 5
    Check 6
    Check 7
    Check 8
    Found

This is:

    O(n)

within the node.

But the number of keys in a single node is relatively small, and the node is already in memory.

Therefore, linear search can be perfectly reasonable.

---

# 55. Binary Search

Because B+ tree keys are sorted, binary search is possible.

Example:

    [1, 3, 5, 7, 8, 10, 12, 15]

Searching for `8`:

1. Check middle.
2. Determine whether 8 is larger or smaller.
3. Eliminate half of the remaining keys.
4. Repeat.

Complexity:

    O(log n)

Binary search is a natural optimization for sorted nodes.

---

# 56. SIMD Search

SIMD stands for:

    Single Instruction, Multiple Data

Instead of comparing one key at a time, the CPU can compare several keys simultaneously.

For example, suppose a node contains:

    [4, 5, 6, 7]

and we are searching for:

    8

A SIMD instruction can compare the target against multiple values in one operation.

The result can be represented as a bit mask.

Conceptually:

    Keys:    [4, 5, 6, 7]
    Target:  [8, 8, 8, 8]

    Result:  [0, 0, 0, 0]

Then another group can be checked.

If we find:

    [4, 5, 6, 8]

the result could indicate:

    [0, 0, 0, 1]

The CPU can then determine that key 8 was found.

---

# 57. SIMD Requirements

SIMD works especially well for:

- Fixed-size integers.
- Fixed-size values.
- Other data that can be compared in parallel.

It is less useful for variable-length strings because the values do not have uniform sizes.

Modern processors provide vector instructions.

Examples include:

- x86 SIMD instructions.
- ARM vector instructions.
- RISC-V vector instructions.

---

# 58. Interpolation Search

Interpolation search attempts to predict where a key should be located.

For example:

    [4, 5, 6, 7, 8, 9, 10]

If searching for:

    8

and the keys are densely packed, the system can calculate approximately where 8 should be.

This can be extremely efficient in the right circumstances.

---

# 59. Why Interpolation Search Is Rare

Interpolation search works best when keys are:

- Dense.
- Uniformly distributed.
- Predictable.

If the keys are sparse:

    [1, 100, 5000, 90000]

the mathematical prediction becomes much less useful.

Therefore, interpolation search is generally not used in commercial database systems.

---

# 60. Pointer Swizzling

Normally, B+ tree pointers stored on disk are page IDs.

For example:

    Child pointer → Page 42

When traversing the tree, the database must:

1. Read the page ID.
2. Ask the buffer pool for the page.
3. Receive a memory address/frame.
4. Continue traversal.

This introduces overhead.

---

# 61. Pointer Swizzling Optimization

Pointer swizzling replaces a disk-style page ID with a direct in-memory pointer when the page is already loaded.

Instead of:

    Page ID → Buffer Pool → Memory Address

we can have:

    Direct Memory Pointer

This makes traversal faster.

Conceptually:

    Normal:

    Parent
      ↓
    Page ID 42
      ↓
    Buffer Pool
      ↓
    Memory address


    Swizzled:

    Parent
      ↓
    Direct memory pointer
      ↓
    Child

---

# 62. Why Pointer Swizzling Is Fast

Following a direct pointer avoids repeatedly asking the buffer pool manager to resolve page IDs.

This can significantly reduce overhead during repeated B+ tree traversals.

However, there is an important problem.

A memory pointer becomes invalid if the page is evicted.

Therefore, swizzled pages must be carefully managed.

---

# 63. Pinning Swizzled Pages

If a page contains a direct pointer to another page in memory, the referenced page cannot simply disappear.

Otherwise:

    Parent pointer
         ↓
    invalid memory address

This would be dangerous.

Therefore, the system can pin pages or enforce rules about which pages may be evicted.

---

# 64. Hierarchical Eviction Rules

The hierarchical structure of a B+ tree provides useful guarantees.

For example, the system can avoid evicting a parent while one of its children has an active swizzled pointer relationship.

The goal is to prevent:

    Valid pointer
        ↓
    Evicted page
        ↓
    Invalid pointer

Pointer swizzling can therefore provide significant performance improvements, but requires careful buffer-pool integration.

---

# 65. Why B+ Tree Updates Can Be Expensive

Most insertions and deletions are cheap.

For example:

    Insert into node with free space
        ↓
    Insert key
        ↓
    Done

But the worst case is:

    Insert
       ↓
    Node full
       ↓
    Split
       ↓
    Parent full
       ↓
    Split parent
       ↓
    Grandparent full
       ↓
    Continue upward

Similarly:

    Delete
       ↓
    Node underfull
       ↓
    Merge
       ↓
    Parent underfull
       ↓
    Merge
       ↓
    Continue upward

These operations can require significant restructuring.

---

# 66. Right-Optimized Trees

One idea is to avoid immediately applying every update to the bottom of the tree.

Instead, accumulate updates and apply them in batches.

These structures are often called:

    Bε-trees

or:

    Fractal trees

"Fractal tree" was associated with a particular implementation/brand, while Bε-tree is the more general academic terminology.

---

# 67. Modification Logs

A Bε-tree can associate a modification log with each node.

Instead of immediately traversing to the leaf, an operation can be stored in a modification log.

For example:

    Insert 7

Instead of:

    Root
      ↓
    Internal node
      ↓
    Leaf
      ↓
    Insert 7

we can temporarily do:

    Root
    ┌───────────────┐
    │ Mod Log       │
    │ Insert 7      │
    └───────────────┘

The update can be propagated downward later.

---

# 68. Example: Insert and Delete in a Modification Log

Suppose:

    Insert 7
    Delete 10

Instead of immediately modifying the leaves, the root's modification log contains:

    INSERT 7
    DELETE 10

This allows multiple operations to accumulate.

Eventually, the database propagates the modifications downward in batches.

---

# 69. Lookup With a Modification Log

Suppose we want to find key `10`.

Normally we would traverse:

    Root
      ↓
    Internal nodes
      ↓
    Leaf

But if the root's modification log contains:

    DELETE 10

we already know the most recent operation affecting key 10.

Therefore, the search may be able to stop earlier.

The system must carefully account for pending modifications when performing scans and range operations.

---

# 70. What Happens When the Modification Log Is Full?

Eventually the modification log fills up.

For example:

    Root modification log:

    INSERT 7
    DELETE 10
    INSERT 40
    INSERT 50
    ...

If there is no more space, the updates must be propagated downward.

Conceptually:

    Root log
       ↓
    Push modifications
       ↓
    Child log
       ↓
    Push later
       ↓
    Leaf

Depending on the implementation, updates may be pushed one level at a time or farther down.

---

# 71. Why Bε-Trees Can Be Faster for Writes

Normal B+ tree:

    Every update
         ↓
    Traverse tree
         ↓
    Modify leaf

Bε-tree:

    Accumulate updates
         ↓
    Batch them
         ↓
    Push them downward together

Batching can reduce the number of expensive page accesses and reorganizations.

This is particularly useful for workloads with many writes.

---

# 72. Relationship to Log-Structured Storage

The idea is related to log-structured storage.

Instead of immediately applying every change to its final location:

    Store changes
         ↓
    Accumulate
         ↓
    Apply later

This can improve write efficiency.

Bε-trees therefore combine ideas from:

- B+ trees
- Buffered modifications
- Log-structured approaches

---

# 73. Why Bε-Trees Are Not Everywhere

They are complicated to implement.

The database must correctly handle:

- Pending updates.
- Point lookups.
- Range scans.
- Deletes.
- Modification-log propagation.
- Ordering.
- Concurrency.
- Crash recovery.

This additional complexity means ordinary B+ trees remain much more common.

---

# 74. B+ Tree Concurrency

The basic B+ tree algorithms are already complicated.

Concurrency makes them significantly harder.

Imagine:

    Thread 1:
    Insert key → causes split

    Thread 2:
    Search same area

    Thread 3:
    Delete key → causes merge

All of these operations may occur simultaneously.

The database must use latches and careful synchronization to prevent corruption.

---

# 75. Physical vs. Logical Correctness

A B+ tree can be physically correct while still requiring additional database-level logic.

Physical correctness means:

- Pointers are valid.
- Pages are not corrupted.
- Tree structure remains consistent.
- Splits and merges are correctly performed.

Logical correctness means the operations produce the correct result according to database semantics.

Concurrency control adds another layer of complexity.

---

# 76. Key B+ Tree Insertion Algorithm

Memorize this sequence:

    1. Start at root.
    2. Compare search key with discriminator keys.
    3. Follow the correct child pointer.
    4. Continue until reaching a leaf.
    5. Insert the key into sorted order.
    6. If the node fits:
           Done.
    7. If the node overflows:
           Split it.
    8. Propagate a discriminator to the parent.
    9. If the parent overflows:
           Split the parent.
    10. Continue upward.
    11. If the root splits:
           Create a new root.
           Increase tree height.

---

# 77. Key B+ Tree Deletion Algorithm

Memorize this sequence:

    1. Start at root.
    2. Traverse to the appropriate leaf.
    3. Delete the key.
    4. Check occupancy.
    5. If still sufficiently full:
           Done.
    6. If underfull:
           Try to borrow from a sibling.
    7. If borrowing works:
           Update parent discriminator.
           Done.
    8. If borrowing does not work:
           Merge with a sibling.
    9. Remove the obsolete parent discriminator/pointer.
    10. If the parent becomes underfull:
           Recursively fix the parent.
    11. If the root can collapse:
           Shrink the tree.

---

# 78. Insert vs. Delete

| Operation | Problem | First Response | If That Fails |
|---|---|---|---|
| Insert | Node too full | Split | Propagate split upward |
| Delete | Node too empty | Borrow/redistribute | Merge |
| Root insert | Root too full | Split root | Increase height |
| Root delete | Root too empty | Collapse root | Decrease height |

---

# 79. Important Terminology

## B+ Tree

A balanced, sorted tree used for efficient database indexing.

## Inner Node

A node containing discriminator/search keys and pointers to children.

## Leaf Node

The bottom-level node containing actual index entries or records.

## Discriminator Key

A key in an inner node used to determine which child to follow.

## Fan-Out

The number of child pointers an inner node can contain.

Higher fan-out generally means a shorter tree.

## Split

Dividing an overflowing node into multiple nodes.

## Merge

Combining underfull neighboring nodes.

## Redistribution

Moving keys between siblings to avoid a split or merge.

## Sibling

A nearby node with the same parent.

## RID

Record ID, typically identifying a physical record using a page ID and slot/offset.

## Clustered Index

An index whose ordering corresponds to the physical organization of table data.

## Composite Index

An index built from multiple attributes.

## Prefix Search

Searching using the first portion of a composite key.

## Skip Scan

An optimization that can allow searches using a later portion of a composite key without specifying the prefix.

## Pointer Swizzling

Replacing page-ID references with direct in-memory pointers when pages are resident.

## Bε-Tree

A write-optimized variation of B-tree/B+ tree structures that buffers modifications.

---

# 80. High-Level Picture

The most important concept is that B+ trees are designed around three goals:

    1. Keep data sorted.
    2. Keep the tree balanced.
    3. Minimize expensive storage accesses.

The basic structure is:

                    ROOT
                     |
              +------+------+
              |             |
           INNER          INNER
           NODE           NODE
          /    \          /    \
        LEAF  LEAF      LEAF  LEAF
         |     |          |     |
        DATA  DATA       DATA  DATA

Searching:

    Root
      ↓
    Inner node
      ↓
    Inner node
      ↓
    Leaf
      ↓
    Record

Because the tree remains balanced, the number of levels remains small.

---

# 81. Big Picture: Why B+ Trees Are So Important

B+ trees are one of the fundamental data structures in database systems because they provide:

- Sorted access.
- Efficient point lookups.
- Efficient range lookups.
- Ordered iteration.
- Composite-key support.
- Duplicate-key support.
- Efficient insertion.
- Efficient deletion.
- High fan-out.
- Low tree height.
- Disk-friendly organization.

They are especially useful when queries need ordering or ranges.

For example:

    WHERE id = 100

    WHERE id > 100

    WHERE id BETWEEN 100 AND 200

    ORDER BY id

A hash table is excellent for equality lookup, but a B+ tree additionally supports ordering and range operations.

---

# 82. Most Important Exam Concepts

Know these especially well:

### Insert

    Overflow → split → update parent → recursively split upward

### Delete

    Underflow → borrow → if impossible, merge → recursively fix parent

### Root

    Root split → tree gets taller

    Root collapse → tree gets shorter

### Discriminator Keys

    Inner-node keys are guides, not necessarily actual records.

### Composite Index

    `(A, B, C)` is sorted by A first, then B, then C.

### Prefix Search

    Index `(A, B)` can efficiently search `A`.

### Suffix Search

    Searching only `B` is harder because the tree is primarily ordered by A.

### Duplicate Keys

    Prefer:

    `(logical_key, RID)`

    rather than chained overflow leaf nodes.

### Clustered Index

    Physical data follows the index ordering.

### Unclustered Index

    Index is ordered but table records may be scattered across pages.

### Node Search

    Possible approaches:

    - Linear search
    - Binary search
    - SIMD
    - Rarely interpolation search

### Pointer Swizzling

    Page ID → direct memory pointer

### Bε-Tree

    Buffer modifications → batch updates → reduce write/reorganization cost

---

# 83. Simple Mental Model

Think of a B+ tree as a sorted filing cabinet.

The inner nodes are labels telling you:

    "If you're looking for something smaller than this,
     go left."

    "If you're looking for something larger,
     go right."

The leaves contain the actual index entries.

When a drawer becomes too full:

    Split it.

When a drawer becomes too empty:

    Borrow from a neighbor.

If the neighbors cannot help:

    Merge drawers.

If the parent becomes full or empty as a result:

    Fix the parent too.

This process continues upward until the tree is valid again.

That is the core idea behind B+ tree maintenance.