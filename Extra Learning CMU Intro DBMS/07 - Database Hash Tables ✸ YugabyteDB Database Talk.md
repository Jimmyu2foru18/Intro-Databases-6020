# Database Systems Study Guide
## Hash Tables, Dynamic Hashing, and Distributed Databases

> Complete study guide combining both parts of the lecture transcript.
> Organized by concept so you can study without rewatching the lecture.

---

# 1. Where Hash Tables Fit in a Database

A database system can be viewed as several layers:

    SQL Query
        ↓
    Query Parser / Planner / Optimizer
        ↓
    Execution Engine
        ↓
    Access Methods / Data Structures
        ↓
    Buffer Pool
        ↓
    Disk / SSD

The lecture focuses on the access methods and data structures that operate on top of the buffer pool.

Important database data structures include:

- Hash tables
- Trees
- Index structures
- Page directories
- Temporary hash tables

Hash tables are especially useful for unordered access.

They can be used for:

- Table indexes
- Catalog metadata
- Page directories
- Index-organized storage
- Temporary hash tables for hash joins

---

# 2. Why Databases Don't Just Use a Normal Hash Map

A normal programming-language hash map generally allocates memory directly from the operating system.

    Program
        ↓
    malloc()
        ↓
    Operating System Memory

A database instead wants its data structures to interact with the buffer pool.

    Database
        ↓
    Buffer Pool Manager
        ↓
    Pages
        ↓
    Disk / SSD

The database needs control over:

- Which pages are in memory
- Which pages are written to disk
- How pages are organized
- How I/O is performed
- How data survives crashes
- How data is persisted
- How sequential and random I/O are handled

A normal in-memory hash table is temporary.

    Program crashes
        ↓
    Hash table disappears

A database needs persistent data.

The database also wants to control its own I/O behavior rather than letting the operating system make every storage decision.

---

# 3. Concurrency Is Deferred

The data structures in this portion of the lecture are initially treated as single-threaded.

Concurrency will be covered later.

Important future concepts include:

- Latches
- Synchronization
- Concurrent access
- Thread safety

There is also a distinction between:

## Physical Correctness

The data structure itself remains internally correct.

## Logical Correctness

The overall database operation follows higher-level database rules such as transactions and isolation.

For now, the focus is primarily on physical correctness.

---

# 4. What Is a Hash Table?

A hash table is an unordered associative data structure.

It maps:

    Key → Value

Examples:

    Student ID → Student Record

    Username → Record ID

    Course ID → Course Information

Hash tables are designed to make lookup, insertion, and deletion very fast on average.

---

# 5. Hash Functions

A hash function converts a key into an integer.

Conceptually:

    Key
      ↓
    Hash Function
      ↓
    Integer

For example:

    "student123"
          ↓
      Hash Function
          ↓
       18472931

The resulting integer is then used to determine where the key should be stored.

A good database hash function should generally have:

1. Fast execution
2. Good distribution
3. Low collision rates

---

# 6. Hash Table Complexity

For a well-designed hash table:

| Operation | Average Case | Worst Case |
|---|---:|---:|
| Insert | O(1) | O(n) |
| Lookup | O(1) | O(n) |
| Delete | O(1) | O(n) |

The goal is approximately constant-time access.

However, database systems care about more than asymptotic complexity.

## Constants Matter

Suppose a hash function takes slightly longer than another.

For 100 operations, the difference may be irrelevant.

For billions of operations, the difference can become significant.

This can affect:

- CPU usage
- Server requirements
- Energy consumption
- Overall database cost

---

# 7. What Makes Up a Hash Table?

A hash table can be thought of as three major components:

    Hash Table
    ├── Hash Function
    ├── Collision / Hashing Scheme
    └── Storage

## Hash Function

Determines the initial location.

## Collision Resolution Scheme

Determines what happens when multiple keys want the same location.

## Storage

Contains the keys and values or references to them.

---

# 8. Simple Static Hash Table

The simplest possible hash table is a fixed array.

    [ ][ ][ ][ ][ ][ ][ ][ ][ ][ ]

Suppose there are n slots.

For an integer key:

    slot = key mod n

Example:

    key = 37
    number of slots = 10

    37 mod 10 = 7

Therefore, key 37 initially maps to slot 7.

---

# 9. Why the Simple Hash Table Isn't Enough

The basic fixed-array approach has several problems.

## Problem 1: Unknown Size

You may not know how many records the table will eventually contain.

## Problem 2: Collisions

Two keys can map to the same slot.

Example:

    A → slot 4
    B → slot 4

Both cannot occupy the same slot.

## Problem 3: Duplicate Keys

Some database operations may allow multiple records with the same search key.

Example:

    Age = 20
    Age = 20
    Age = 20

The hash table therefore needs a strategy for collisions and duplicate values.

---

# 10. Perfect Hashing

A perfect hash function produces no collisions for a known set of keys.

Conceptually:

    Key A → Slot 1
    Key B → Slot 2
    Key C → Slot 3
    Key D → Slot 4

No two keys map to the same location.

The problem is that perfect hashing generally requires knowing the key set in advance.

It can also require expensive preprocessing.

Therefore, it is usually not the general-purpose solution for a dynamic database table.

---

# 11. Hash Function Design

A hash function maps arbitrary input data to a fixed-size integer.

For example:

    Arbitrary Key
        ↓
    Byte Representation
        ↓
    Hash Function
        ↓
    32-bit or 64-bit Integer

Database hash functions prioritize:

- Speed
- Good distribution
- Low collision rates

The hash function does not need to be cryptographically secure.

---

# 12. Cryptographic Hashing Is Not Required

Database hash tables generally do not need cryptographic properties.

A cryptographic hash function is designed for properties such as:

- Security
- Resistance to attacks
- One-way computation
- Collision resistance for security purposes

A database hash table primarily needs:

    Fast + Well Distributed

The lecture mentioned hash functions such as:

- MurmurHash
- XXHash / XXHash3
- RapidHash

The important concept is not memorizing these names.

The important idea is:

    Database hash functions are optimized for fast internal data-structure operations.

---

# 13. Static vs Dynamic Hashing

There are two major categories discussed in the lecture.

## Static Hashing

The number of slots is fixed.

Example:

    100 slots forever

If the table fills up, resizing may require expensive work.

## Dynamic Hashing

The hash structure can grow as needed.

Examples:

- Extendible hashing
- Linear hashing

Dynamic hashing exists to avoid rebuilding the entire table every time it grows.

---

# 14. Open Addressing

In open addressing, a key does not necessarily have one permanent slot.

The hash function gives the initial location.

If that location is occupied, another location is searched.

Conceptually:

    Key
      ↓
    Hash
      ↓
    Starting Position
      ↓
    Collision?
      ↓
    Search for Another Position

The collision-resolution algorithm determines where to look next.

Two important open-addressing approaches discussed are:

- Linear probing
- Cuckoo hashing

---

# 15. Linear Probing

Linear probing is one of the simplest collision-resolution strategies.

Suppose the hash function says:

    Key A → slot 4

If slot 4 is empty:

    Put A in slot 4

If slot 4 is occupied:

    Check slot 5

If slot 5 is occupied:

    Check slot 6

Continue until an appropriate slot is found.

Conceptually:

    hash(key) → 4
                  ↓
              [4] occupied
                  ↓
              [5] occupied
                  ↓
              [6] empty
                  ↓
              Insert here

The key idea:

> If a collision occurs, keep scanning forward one slot at a time.

---

# 16. Linear Probing: Insert

Insertion process:

1. Compute the hash value.
2. Convert the hash value into an initial slot.
3. Check whether the slot is available.
4. If available, insert the key.
5. If occupied, move to the next slot.
6. Continue until an available position is found.
7. Wrap around if necessary.

Example:

    Hash(A) = 3

Initial table:

    Slot:  0  1  2  3  4  5  6
           -  -  -  X  -  -  -

If A hashes to slot 3:

    Slot 3 is occupied.

Check slot 4.

If slot 4 is free:

    Insert A into slot 4.

---

# 17. Linear Probing: Lookup

Lookup follows the same path that insertion would have used.

Steps:

1. Hash the key.
2. Go to the starting slot.
3. Compare the key.
4. If it matches, return the value.
5. If it does not match, move to the next slot.
6. Continue until:
   - The key is found, or
   - A truly empty slot is reached.

Why can an empty slot stop the search?

Suppose a key was originally hashed to slot 3.

If insertion could not find slot 3, it would have continued to later slots.

Therefore, if we encounter a slot that has never been used, the key could not have been inserted farther beyond it.

---

# 18. Wraparound

Linear probing must handle the end of the array.

Example:

    Slots:
    0 1 2 3 4 5

If the search reaches slot 5:

    5 → 0 → 1 → 2 → ...

This is called wraparound.

The array can be treated as circular.

A lookup should stop if it has searched the entire table and returned to its starting position.

---

# 19. Load Factor

The load factor measures how full a hash table is.

The basic formula is:

    Load Factor = Number of Occupied Slots / Total Number of Slots

Usually written as:

    α = n / m

where:

- n = number of stored entries
- m = total number of slots

Example:

    70 occupied slots
    100 total slots

    α = 70 / 100
      = 0.70

The load factor is 70%.

---

# 20. Why Load Factor Matters

Linear probing becomes increasingly expensive as the table fills.

Low load factor:

    [A][ ][ ][B][ ][ ][C][ ]

High load factor:

    [A][B][C][D][E][F][ ][ ]

When the table is crowded, collisions become more common.

This causes longer probe sequences.

Therefore:

> Higher load factor generally means slower hash-table operations.

---

# 21. Why Rehashing Is Expensive

When a static hash table becomes too full, a common strategy is:

1. Allocate a larger table.
2. Usually make it approximately twice as large.
3. Recalculate the location of every existing key.
4. Insert every key into the new table.
5. Replace the old table.

Example:

    Old table:
    100 slots

    New table:
    200 slots

Every key may need to be rehashed because:

    key mod 100

is not necessarily equal to:

    key mod 200

Therefore, resizing can require O(n) work.

This is why databases try to avoid resizing too frequently.

---

# 22. Storing Values in a Hash Table

A hash table does not necessarily need to store the entire database record inside each slot.

For example:

    Key → Record ID

instead of:

    Key → Entire Tuple

This can save substantial space.

---

# 23. Fixed-Length vs Variable-Length Values

Fixed-length values can sometimes be stored directly inside a hash-table slot.

Examples:

- Integer
- Fixed-size identifier
- Fixed-size hash value

Variable-length values can be much larger.

Examples:

- Strings
- Text
- Large objects

Putting large variable-length values directly into every hash slot can waste memory and space.

A better approach is often:

    Hash Table
        ↓
    Record ID / Pointer
        ↓
    Actual Record

---

# 24. Record IDs / Pointers

A record ID can identify where the actual tuple is stored.

For a table index:

    Hash Table
        ↓
    Key
        ↓
    Record ID
        ↓
    Original Tuple

This keeps the index relatively small.

For temporary structures such as a hash join, the pointer may instead refer to temporary pages.

---

# 25. Storing the Hash Value

A database can store the computed hash value along with the key or record reference.

Example:

    Hash Value
    Key
    Record ID

Why?

Suppose the database needs to compare many keys.

It can first compare the hash values.

If the hash values differ:

    Different hash
        ↓
    Definitely different key

If the hash values match:

    Possible match
        ↓
    Compare the actual key

This can save expensive key comparisons.

The tradeoff is:

    More Space
        vs.
    Less Computation

---

# 26. Variable-Length Keys

Variable-length keys can be expensive to compare.

A common optimization is to store:

- A hash value or prefix
- A record ID

Conceptually:

    Hash Table Entry
    ├── Hash / Prefix
    └── Record ID
             ↓
        Full Key

The hash or prefix can quickly eliminate obvious mismatches.

The complete value can then be checked only when necessary.

---

# 27. Deletion in Linear Probing

Deletion creates an important problem.

Suppose the table contains:

    A → slot 3
    B → slot 4
    C → slot 5

Now delete A.

If slot 3 becomes completely empty:

    [ ][B][C]

A lookup for B can still find B.

But suppose B originally hashed to slot 3.

The lookup would do:

    Hash(B) → slot 3

It sees an empty slot.

It would incorrectly conclude:

    "B does not exist."

But B actually exists at slot 4.

Therefore, simply clearing deleted entries is incorrect.

---

# 28. Tombstones

The standard solution is a tombstone.

A tombstone means:

> Something used to be stored here, but it has been deleted.

Conceptually:

    [TOMBSTONE][B][C]

A tombstone is:

- Not an active entry
- Not a truly empty slot

During lookup:

    Tombstone → keep searching

During insertion:

    Tombstone → can potentially be reused

---

# 29. Tombstone Behavior

Consider:

    [A][B][C][ ][ ]

Delete A:

    [T][B][C][ ][ ]

Search for B:

    Start at A's location
        ↓
    Tombstone
        ↓
    Continue
        ↓
    B found

Search for D:

    Start
        ↓
    Tombstone
        ↓
    B
        ↓
    C
        ↓
    Empty slot
        ↓
    D does not exist

The truly empty slot is what tells lookup that the key cannot exist farther along the probe sequence.

---

# 30. Tombstone Tradeoff

Tombstones solve correctness problems, but they introduce another issue.

If many entries are deleted:

    [T][T][A][T][B][T][C][ ]

Searches can become slower because the table contains many tombstones.

A database may eventually need to:

- Rebuild the table
- Rehash entries
- Clean up tombstones
- Perform background maintenance

However, such maintenance can be expensive.

The lecture emphasized that database engineers must consider whether the added complexity is worth the performance benefit.

---

# 31. Duplicate / Non-Unique Keys

Hash tables do not necessarily require unique keys.

For example:

    Key = 10
    Key = 10
    Key = 10

Multiple entries can exist.

One common strategy is to store duplicate keys separately.

For lookup:

1. Hash the key.
2. Search the probe sequence.
3. Return matching entries.
4. Continue searching until a truly empty slot is encountered.

Why continue?

Because another duplicate key may appear later in the probe sequence.

---

# 32. Specialized Hash Tables

Database systems can implement specialized hash tables depending on the data type.

Examples:

- Integer keys
- String keys
- Large strings
- Fixed-size keys
- Variable-size keys

Specialization can improve:

- Speed
- Memory efficiency
- Cache behavior
- Comparison cost

There is no requirement that one generic hash-table implementation be used for everything.

---

# 33. Cuckoo Hashing

Cuckoo hashing is another open-addressing technique.

Instead of giving a key only one possible location, it gives the key multiple possible locations.

For example:

    Hash 1(key) → Location A

    Hash 2(key) → Location B

A key can therefore live in either location.

Lookup only needs to check a small number of possible locations.

---

# 34. Cuckoo Hashing Lookup

Suppose a key has two possible locations:

    h1(key) → slot 4
    h2(key) → slot 9

Lookup checks:

    Slot 4
       ↓
    If not found
       ↓
    Slot 9

Because the number of possible locations is bounded, lookup can remain very fast.

Conceptually:

    Lookup = O(1)

with a small constant number of checks.

---

# 35. Cuckoo Hashing Insert

Insertion is more complicated.

Suppose:

    A → slot 4

Now B wants slot 4.

Instead of simply moving linearly forward, B can use its second hash location.

    B:
    h1(B) → slot 4
    h2(B) → slot 8

If slot 8 is free:

    Put B in slot 8.

Now suppose C can only use locations that are already occupied.

C may displace another key.

Example:

    C displaces B
    B moves to another location
    That key may then be displaced
    Continue

This creates a chain of evictions.

---

# 36. Cuckoo Hashing Cycles

Cuckoo insertion can encounter a cycle.

Example:

    A displaces B
    B displaces C
    C displaces A
    A displaces B
    ...

The algorithm cannot find a free location.

The solution may be to:

1. Detect the cycle.
2. Allocate a larger table.
3. Rehash the keys.
4. Rebuild the structure.

Therefore, cuckoo hashing can have expensive insertion operations even though lookup is very fast.

---

# 37. Linear Probing vs Cuckoo Hashing

| Feature | Linear Probing | Cuckoo Hashing |
|---|---|---|
| Number of candidate locations | Many during scan | Small fixed number |
| Lookup | Very fast when table isn't full | Very predictable |
| Insert | Simple | More complicated |
| Collision handling | Scan forward | Evict/reposition keys |
| Cycles | No explicit eviction cycle | Possible |
| Resize | Required when too full | Required when placement fails |
| Typical implementation complexity | Lower | Higher |

Linear probing is simple and often fast in practice.

Cuckoo hashing provides very predictable lookup but has more complicated insertion behavior.

---

# 38. Why Dynamic Hashing?

Static hashing has a major problem:

> What happens when the table grows?

Suppose the table starts with:

    1,000 slots

Then eventually contains:

    100,000 records

A static table cannot simply continue growing forever.

One option is to rebuild the entire table.

That can be expensive.

Dynamic hashing attempts to grow the structure incrementally.

Important dynamic hashing methods:

- Chain hashing
- Extendible hashing
- Linear hashing

---

# 39. Chain Hashing

Chain hashing uses a set of bucket pointers.

Conceptually:

    Directory
    ┌─────┐
    │  0  │ ───→ Bucket
    ├─────┤
    │  1  │ ───→ Bucket
    ├─────┤
    │  2  │ ───→ Bucket
    └─────┘

Each bucket can contain multiple records.

If a bucket becomes full, another bucket can be allocated and linked to it.

---

# 40. Chain Hashing Example

Suppose:

    hash(key) mod 4

produces bucket numbers:

    0
    1
    2
    3

The directory contains:

    Bucket 0 → Page
    Bucket 1 → Page
    Bucket 2 → Page
    Bucket 3 → Page

Suppose bucket 2 fills.

A new bucket can be allocated:

    Bucket 2 → Bucket 4

Now the chain can contain more entries.

---

# 41. Chain Hashing Lookup

Lookup process:

1. Hash the key.
2. Determine the bucket.
3. Follow the bucket pointer.
4. Search the bucket.
5. If necessary, follow the overflow pointer.
6. Continue until the key is found or the chain ends.

Conceptually:

    Key
      ↓
    Hash
      ↓
    Bucket Pointer
      ↓
    Bucket
      ↓
    Overflow Bucket
      ↓
    Overflow Bucket

---

# 42. Bucket Overflow

When a bucket becomes full:

    Bucket
    [A][B][C]

A new key arrives:

    D

Instead of moving all existing keys:

    Allocate another bucket

    [A][B][C] → [D][ ][ ]

This is simpler than rebuilding the entire hash table.

---

# 43. Problem with Chain Hashing

The problem is that a chain can become very long.

In a pathological case:

    Bucket 0
       ↓
    Bucket 1
       ↓
    Bucket 2
       ↓
    Bucket 3
       ↓
    Bucket 4
       ↓
       ...

A lookup could become very expensive.

A good hash function should distribute keys evenly.

However, even with a good hash function, the database may want additional techniques to avoid long chains.

---

# 44. Bloom Filter Optimization

A Bloom filter can be used as a quick test before searching a bucket chain.

A Bloom filter answers:

> Could this key exist?

It has two possible answers:

    Definitely not

or:

    Maybe

Important property:

- No false negatives
- False positives are possible

Example:

    Bloom Filter
        ↓
    "Definitely not"
        ↓
    Skip bucket search

But:

    Bloom Filter
        ↓
    "Maybe"
        ↓
    Search actual bucket

This can reduce unnecessary bucket scans.

---

# 45. Extendible Hashing

Extendible hashing is a more sophisticated dynamic hashing technique.

Instead of allowing overflow chains to grow indefinitely, buckets can be split.

Conceptually:

    Directory
       ↓
    Bucket
       ↓
    Full
       ↓
    Split Bucket
       ↓
    Redistribute Keys

The directory contains pointers to buckets.

Multiple directory entries may point to the same bucket.

---

# 46. Important Idea in Extendible Hashing

Extendible hashing uses bits from the hash value.

Suppose the hash function produces a 32-bit value:

    101101011010...

The system does not necessarily use all 32 bits.

It may initially use only a small number.

For example:

    First 1 bit

Then:

    0 → Bucket A
    1 → Bucket B

As the table grows, more bits can be used.

---

# 47. Global Depth

The global depth tells us how many hash bits are currently being used by the directory.

If:

    Global Depth = 2

then the directory has:

    2² = 4 entries

Possible prefixes:

    00
    01
    10
    11

If:

    Global Depth = 3

then:

    2³ = 8 directory entries

Possible prefixes:

    000
    001
    010
    011
    100
    101
    110
    111

Formula:

    Directory Size = 2^GlobalDepth

---

# 48. Local Depth

Each individual bucket has its own local depth.

Local depth tells us how many hash bits are necessary to distinguish that bucket from other buckets.

Example:

    Global Depth = 3

But a particular bucket might have:

    Local Depth = 2

That means multiple directory entries may still point to the same bucket.

---

# 49. Why Global and Local Depth Are Needed

Global depth describes the directory.

Local depth describes an individual bucket.

Example:

    Directory entries:

    00 ──┐
         ├──→ Bucket A
    01 ──┘

    10 ─────→ Bucket B

    11 ─────→ Bucket C

Bucket A can have two directory entries pointing to it.

This is possible because the bucket does not yet need to be distinguished using every bit represented by the directory.

---

# 50. Extendible Hashing Lookup

Lookup process:

1. Hash the key.
2. Take the required number of hash bits.
3. Use those bits as a directory index.
4. Follow the directory pointer.
5. Search the corresponding bucket.

Example:

    Hash:
    101011...

    Global depth = 2

Use:

    10

Then:

    Directory[10]
        ↓
    Bucket
        ↓
    Search bucket

---

# 51. Extendible Hashing Insert

Insertion:

1. Hash the key.
2. Use the global depth to find the directory entry.
3. Follow the pointer to the bucket.
4. If the bucket has space, insert.
5. If the bucket is full, split it.

If necessary, increase the global depth.

---

# 52. Extendible Hashing Bucket Overflow

Suppose a bucket is full.

Example:

    Bucket A
    [A][B][C]

Insert D.

The bucket needs to split.

If the directory needs more entries:

    Global Depth increases

The directory may double in size.

Then:

    Old Bucket
       ↓
    Split into
       ↓
    Bucket A
    Bucket B

The keys are redistributed according to an additional hash bit.

---

# 53. Example of Extendible Hashing Split

Suppose a bucket contains keys whose relevant hash bits are:

    000
    001
    010
    011

Suppose the bucket needs to split.

The next hash bit can distinguish the records.

For example:

    000 → Bucket A
    001 → Bucket A
    010 → Bucket B
    011 → Bucket B

The exact distribution depends on which bits are being used.

The key idea is:

> Splitting uses additional hash information to divide one bucket into multiple buckets.

---

# 54. Why Extendible Hashing Is Dynamic

Extendible hashing does not necessarily rebuild the entire table when it grows.

Instead, it can:

1. Increase directory size when necessary.
2. Split only the bucket that needs splitting.
3. Redistribute only the records affected by that split.

This makes growth more incremental.

---

# 55. Pathological Case

Dynamic hashing does not magically solve every possible workload.

Suppose every record has exactly the same value:

    1
    1
    1
    1
    1
    1
    ...

A hash function could repeatedly produce the same pattern.

The structure may repeatedly attempt to split without achieving useful distribution.

This is an example of a pathological input.

Good hash functions are important because they attempt to distribute keys uniformly.

---

# 56. Extendible Hashing vs Chain Hashing

| Feature | Chain Hashing | Extendible Hashing |
|---|---|---|
| Overflow handling | Add overflow bucket | Split bucket |
| Long chains possible | Yes | Reduced |
| Directory | Basic bucket pointers | Uses directory and depth |
| Dynamic | Yes | Yes |
| Uses hash bits | Basic hashing | Explicit directory bits |
| Bucket splitting | No | Yes |

The major idea:

    Chain Hashing:
    "Keep adding overflow buckets."

    Extendible Hashing:
    "Split buckets and expand the directory when needed."

---

# 57. Linear Hashing

Linear hashing is another dynamic hashing technique.

IMPORTANT:

    Linear Hashing ≠ Linear Probing

They are completely different concepts.

## Linear Probing

- Static hash-table collision resolution
- Scan to the next available slot

## Linear Hashing

- Dynamic hashing
- Gradually expands the number of buckets
- Uses a split pointer

---

# 58. Why Linear Hashing Exists

Linear hashing attempts to grow a hash table without rebuilding the entire table at once.

Instead of:

    Rebuild Everything

it does:

    Split One Bucket
        ↓
    Split Another Bucket
        ↓
    Split Another Bucket
        ↓
    Continue Gradually

This spreads resizing work over time.

---

# 59. Linear Hashing Components

Important components include:

- Bucket array
- Bucket pointers
- Split pointer
- Hash functions
- Overflow chains

The split pointer tells the database which bucket should be split next.

---

# 60. Split Pointer

The split pointer indicates:

> This is the next bucket that will be split.

Suppose the buckets are:

    0
    1
    2
    3

and:

    Split Pointer = 0

Then bucket 0 is the next bucket scheduled for splitting.

After it is split:

    Split Pointer = 1

Then:

    Split Pointer = 2

and so on.

---

# 61. Linear Hashing Initial State

Suppose we start with four buckets:

    Bucket 0
    Bucket 1
    Bucket 2
    Bucket 3

The initial hash function might be:

    h1(k) = k mod 4

The split pointer starts at:

    0

This gives:

    Split Pointer
          ↓
    [0] [1] [2] [3]

---

# 62. Linear Hashing Example

Suppose we insert:

    6

Using:

    h1(k) = k mod 4

we get:

    6 mod 4 = 2

So 6 goes to bucket 2.

Now suppose we insert:

    17

Then:

    17 mod 4 = 1

So 17 maps to bucket 1.

If bucket 1 is full, an overflow bucket may temporarily be added.

However, the split pointer may still be pointing somewhere else.

This is one of the key ideas of linear hashing.

---

# 63. Linear Hashing Overflow

Suppose:

    17 mod 4 = 1

and bucket 1 is full.

The database may temporarily create:

    Bucket 1 → Overflow Bucket

But suppose:

    Split Pointer = 0

The database does not necessarily split bucket 1 immediately.

Instead, it splits bucket 0 because that is the bucket indicated by the split pointer.

This makes the resizing work occur incrementally and predictably.

---

# 64. Adding a New Bucket

Suppose the current buckets are:

    0
    1
    2
    3

and the split pointer says:

    Split bucket 0

A new bucket is added:

    4

Now bucket 0 is redistributed between:

    Bucket 0
    Bucket 4

The new bucket is paired with the bucket being split.

---

# 65. Multiple Hash Functions in Linear Hashing

Linear hashing can use different hash functions depending on the current expansion phase.

For example:

    h1(k) = k mod n

and:

    h2(k) = k mod 2n

Suppose:

    n = 4

Then:

    h1(k) = k mod 4

and:

    h2(k) = k mod 8

The second hash function becomes useful for buckets that have already been split.

---

# 66. Why Two Hash Functions?

The purpose is to gradually expand the table.

Initially:

    h1(k) = k mod 4

Later:

    h2(k) = k mod 8

This gives the system more possible bucket locations.

Example:

    key = 8

Using h1:

    8 mod 4 = 0

Using h2:

    8 mod 8 = 0

It stays in bucket 0.

Example:

    key = 20

Using h1:

    20 mod 4 = 0

Using h2:

    20 mod 8 = 4

So after bucket 0 is split, key 20 can move to bucket 4.

---

# 67. Moving the Split Pointer

After a bucket is split:

    Split Pointer
          ↓
    Moves forward

Example:

    Split Pointer = 0

After splitting bucket 0:

    Split Pointer = 1

Then:

    Split Pointer = 2

Then:

    Split Pointer = 3

Eventually, the split pointer cycles through all existing buckets.

This distributes the cost of resizing over time.

---

# 68. Linear Hashing Lookup

Lookup needs to determine which hash function should be used.

General idea:

1. Compute the original hash location.
2. Check whether that bucket has already been split.
3. If it has not been split, use the original bucket.
4. If it has been split, use the newer hash function.
5. Search the resulting bucket.

Conceptually:

    Hash key
       ↓
    h1(key)
       ↓
    Has this bucket been split?
       ↓
      Yes
       ↓
    h2(key)
       ↓
    Correct bucket

---

# 69. Why Lookup Needs This Check

Suppose:

    h1(k) = k mod 4

Initially:

    20 mod 4 = 0

So 20 belongs in bucket 0.

Later bucket 0 is split.

Now:

    h2(20) = 20 mod 8 = 4

So 20 may have moved to bucket 4.

Lookup therefore needs to know whether bucket 0 has already been split.

If it has:

    Recalculate using h2

If it has not:

    Use h1

---

# 70. Linear Hashing Big Idea

Linear hashing provides incremental growth.

Instead of:

    Allocate Huge Table
        ↓
    Rehash Everything

it does:

    Split Bucket 0
        ↓
    Split Bucket 1
        ↓
    Split Bucket 2
        ↓
    Split Bucket 3
        ↓
    Continue

The split pointer controls the order.

---

# 71. Extendible Hashing vs Linear Hashing

| Feature | Extendible Hashing | Linear Hashing |
|---|---|---|
| Dynamic | Yes | Yes |
| Directory | Yes | Bucket structure |
| Uses depth | Global/local depth | Split pointer / expansion phase |
| Bucket splitting | Overflowing bucket | Bucket indicated by split pointer |
| Directory doubling | Possible | Not the main mechanism |
| Growth strategy | Directory-driven | Incremental sequential splitting |
| Main idea | Use more hash bits | Split buckets gradually |

A major exam distinction:

> Extendible hashing generally splits the bucket that needs splitting.

> Linear hashing splits the bucket indicated by the split pointer.

---

# 72. Why Would Linear Hashing Split a Different Bucket?

This can seem strange.

Suppose:

    Bucket 1 overflows

but:

    Split Pointer = 0

Why split bucket 0 instead of bucket 1?

Because linear hashing is designed to distribute resizing work.

If the database always split the bucket that overflowed, certain workloads could cause repeated expensive work in the same area.

The split pointer guarantees that the buckets are eventually split in an orderly cycle.

Therefore:

    Overflowing Bucket
        ↓
    May temporarily use overflow storage

while:

    Split Pointer
        ↓
    Determines the next bucket to permanently split

---

# 73. Database Engineering: Don't Assume Everything Is in Memory

A major lesson throughout the lecture is:

> Database data structures must account for persistent storage.

A normal programmer might assume:

    Memory is fast
    Memory is available
    malloc() is enough

A database system must think about:

- Pages
- Buffer pools
- Disk
- SSDs
- I/O cost
- Persistence
- Eviction
- Temporary storage
- Data movement

Even a hash table may need to interact with the buffer manager.

---

# 74. Access-Method Big Picture

The major progression is:

    Buffer Pool
        ↓
    Access Methods
        ↓
    Hash Tables
        ↓
    Static Hashing
        ↓
    Linear Probing
        ↓
    Cuckoo Hashing
        ↓
    Dynamic Hashing
        ↓
    Chain Hashing
        ↓
    Extendible Hashing
        ↓
    Linear Hashing

The overall goal is fast data access while accounting for database storage constraints.

---

# 75. Guest Lecture: YugabyteDB

The second major portion of the lecture was a guest lecture about YugabyteDB.

YugabyteDB was presented as a:

- Distributed database
- Cloud-native database
- PostgreSQL-compatible database
- Open-source database
- Distributed transactional database

The speaker discussed the challenges of combining PostgreSQL compatibility with distributed database architecture.

---

# 76. What Is YugabyteDB?

YugabyteDB aims to provide PostgreSQL compatibility while operating as a distributed system.

The major idea is:

    PostgreSQL-compatible query processing
                 +
    Distributed transactional storage

This allows applications to use PostgreSQL-style functionality while gaining distributed-system capabilities.

---

# 77. YugabyteDB Main Goals

The lecture discussed several major goals:

- Scalability
- Resilience
- High availability
- Distributed transactions
- Multi-region operation
- Cloud-native deployment
- PostgreSQL compatibility
- Horizontal scaling
- Disaster recovery
- Security
- Observability
- AI workloads

The major theme is:

> Keep the useful PostgreSQL programming model while changing the underlying architecture to support distributed systems.

---

# 78. Why PostgreSQL Compatibility Matters

PostgreSQL is widely used.

Applications already depend on:

- SQL behavior
- Transaction semantics
- Isolation levels
- Extensions
- Stored procedures
- Triggers
- PostgreSQL-compatible tools
- PostgreSQL client libraries

If a new distributed database can preserve these features, applications may be able to migrate without being completely rewritten.

---

# 79. Relaxing PostgreSQL Architectural Constraints

Traditional PostgreSQL has architectural assumptions that work very well for a single-node database.

However, distributed environments introduce additional challenges.

The guest lecture discussed issues involving:

- Scalability
- Availability
- Disaster recovery
- Multi-region deployments
- Connection pooling
- Security
- Observability
- Performance tuning

The challenge is to preserve PostgreSQL semantics while changing the physical architecture.

---

# 80. Yugabyte Architecture

A simplified traditional PostgreSQL architecture looks like:

    PostgreSQL
    ┌──────────────────────┐
    │ Query Processing     │
    ├──────────────────────┤
    │ Storage               │
    └──────────────────────┘

Yugabyte separates these responsibilities.

Conceptually:

    Query Processing Layer
             ↓
    Distributed Storage Layer
             ↓
    Replicated Data

The query-processing layer can become more stateless.

The distributed storage layer handles:

- Data placement
- Replication
- Persistence
- Distributed access

---

# 81. Making PostgreSQL Query Processing Stateless

In a traditional database architecture, the query-processing component can be tightly connected to local storage.

Yugabyte aims to make query processing more stateless.

Conceptually:

    Query Node A
         \
          \
           → Distributed Storage
          /
         /
    Query Node B

Because storage is distributed separately, different query-processing nodes can access the distributed data.

This improves flexibility and allows the system to scale horizontally.

---

# 82. Why Simply Distributing Storage Isn't Enough

Suppose the database distributes data across ten machines.

A naive query strategy might be:

    Query Node
        ↓
    Ask every machine for data
        ↓
    Transfer lots of rows
        ↓
    Process everything on one node

This can be very inefficient.

The problem is not necessarily disk speed.

The problem can be:

    Network Data Transfer

---

# 83. Network vs Local Access

Consider a query that ultimately returns only one row.

The database might have to examine thousands of rows to determine which one matches.

On a single machine:

    Disk / Memory
        ↓
    Process locally
        ↓
    Return 1 row

In a distributed database:

    Node A
       ↓
    Thousands of rows
       ↓
    Network
       ↓
    Node B
       ↓
    Filter down to 1 row

Moving thousands of rows across the network can be much more expensive than filtering them locally.

Therefore:

> Network transfer is a major cost in distributed query processing.

---

# 84. Push Computation Toward Data

One of the most important distributed-database principles from the lecture is:

> Move computation toward the data whenever possible.

Instead of:

    Data
      ↓
    Network
      ↓
    Query Node
      ↓
    Filter

Prefer:

    Data
      ↓
    Filter Locally
      ↓
    Small Result
      ↓
    Network
      ↓
    Query Node

This minimizes data movement.

---

# 85. Distributed Query Optimization

A traditional PostgreSQL query optimizer primarily considers costs such as:

- CPU
- Local disk I/O
- Memory

A distributed database also needs to consider:

- Network traffic
- Number of nodes involved
- Data movement
- Remote execution
- Distribution of data
- Replication

Therefore, the query optimizer must understand the distributed environment.

---

# 86. Sharding

Sharding means distributing data across multiple machines or partitions.

Example:

    Node 1 → Records A-D
    Node 2 → Records E-H
    Node 3 → Records I-L

Instead of storing all data on one machine:

    One Large Database

the system can use:

    Multiple Database Nodes

Sharding enables horizontal scaling.

---

# 87. Small-Query Problem

A query may return only one row but still require work across many nodes.

Example:

    SELECT ...
    WHERE id = 100

If the database knows exactly where ID 100 is stored:

    Query
      ↓
    Correct Node
      ↓
    One Lookup

This can be very fast.

But if the system has to contact many nodes:

    Query
      ↓
    Node A
    Node B
    Node C
    Node D
    ...
      ↓
    Combine Results

The network overhead can dominate the query cost.

---

# 88. Adaptive Behavior

A distributed database needs to behave intelligently at different scales.

At low scale, users may expect:

    PostgreSQL-like performance

At high scale, users want:

    Automatic distribution
    +
    Horizontal scaling
    +
    Resilience

The system therefore needs to choose plans based on the environment.

A query plan that is excellent on one machine may be poor in a distributed environment.

---

# 89. Storage Engine Differences

The lecture contrasted storage approaches.

Traditional PostgreSQL uses important B-tree-based structures.

Yugabyte uses a log-structured storage architecture.

Log-structured designs can have advantages for modern SSD-based systems.

The important concept is not simply:

    B-tree = good
    Log-structured = good

Instead:

> The storage architecture affects how queries should be optimized.

---

# 90. Why Storage Design Affects Query Optimization

The query optimizer needs to understand the cost of accessing data.

Suppose storage behaves like:

    Random Access = Cheap
    Sequential Access = Expensive

A query planner would make certain choices.

If the storage system has different cost characteristics:

    Sequential Writes = Efficient
    Random Updates = Expensive

the optimizer should account for that.

Therefore:

    Storage Design
          ↓
    Access Costs
          ↓
    Query Plan Choices

---

# 91. Cost-Based Optimization

A cost-based optimizer estimates the cost of possible query plans.

For example:

    Plan A
    Cost = 10

    Plan B
    Cost = 50

The optimizer would normally choose Plan A.

In a distributed database, the cost model must include additional factors.

Conceptually:

    Total Cost =
        CPU Cost
        +
        Storage Cost
        +
        Network Cost
        +
        Distributed Coordination Cost

The exact formula varies by database.

---

# 92. Distributed vs Single-Node Query Planning

A query can have very different optimal plans depending on the environment.

## Single Node

    Table
      ↓
    Local Scan
      ↓
    Filter
      ↓
    Result

## Distributed

    Node A ──┐
    Node B ──┼──→ Network → Query Node
    Node C ──┘

The distributed plan should try to:

- Reduce network traffic
- Filter data early
- Perform operations near the data
- Minimize unnecessary node communication

---

# 93. Resilience and Availability

Distributed databases use replication to improve resilience.

Suppose:

    Node A
    Node B
    Node C

contain replicated data.

If Node A fails:

    Node A → FAILED

the system may still have:

    Node B
    Node C

This allows the system to continue operating.

Replication therefore improves:

- Availability
- Fault tolerance
- Disaster recovery

---

# 94. Multi-Region Databases

Distributed databases can place data in multiple geographic regions.

Example:

    New York
       ↓
    Europe
       ↓
    Asia

Advantages:

- Disaster resilience
- Lower latency for geographically distributed users
- Regional availability

Challenges:

- Network latency
- Consistency
- Replication cost
- Coordination overhead

The farther apart the regions are, the more network latency can matter.

---

# 95. Cloud-Native Architecture

Cloud-native distributed databases are designed around:

- Horizontal scaling
- Shared-nothing architecture
- Replication
- Fault tolerance
- Elastic resource usage
- Distributed storage
- Stateless services where possible

Instead of relying on:

    One Huge Machine

the system can use:

    Many Machines
        +
    Distributed Storage
        +
    Replication

---

# 96. PostgreSQL + Distributed Storage

The Yugabyte approach can be summarized as:

    PostgreSQL-Compatible Query Layer
                 +
    Distributed Transactional Storage

The query layer provides PostgreSQL-compatible behavior.

The storage layer provides:

- Distribution
- Replication
- Scalability
- Persistence
- Fault tolerance

This separation allows the system to preserve a familiar interface while changing how data is physically stored.

---

# 97. Important Systems Lesson: Data Movement Is Expensive

This is one of the most important concepts from the guest lecture.

In a distributed system:

    Moving computation
    can be cheaper than
    moving large amounts of data.

Therefore:

> Process data near where it is stored whenever possible.

Bad approach:

    Node A
       ↓
    Huge Dataset
       ↓
    Network
       ↓
    Node B
       ↓
    Filter

Better approach:

    Node A
       ↓
    Filter
       ↓
    Small Result
       ↓
    Network
       ↓
    Node B

This principle appears throughout distributed database design.

---

# 98. Major Exam Comparisons

## Static vs Dynamic Hashing

| Static Hashing | Dynamic Hashing |
|---|---|
| Fixed number of slots | Can grow |
| Resizing can be expensive | Growth is incremental |
| Examples: linear probing, cuckoo hashing | Extendible hashing, linear hashing |
| Good when size is predictable | Better when size changes |

---

## Linear Probing vs Linear Hashing

These are NOT the same.

### Linear Probing

- Collision resolution
- Open addressing
- Search forward through slots
- Usually static
- Example:

    Hash → slot 4
            ↓
          occupied
            ↓
          slot 5

### Linear Hashing

- Dynamic hashing
- Uses bucket splitting
- Uses a split pointer
- Grows incrementally

---

## Linear Probing vs Cuckoo Hashing

### Linear Probing

    Hash → Start
             ↓
          Scan forward

### Cuckoo Hashing

    Hash 1 → Possible Location 1
    Hash 2 → Possible Location 2

Linear probing generally has simpler insertion.

Cuckoo hashing provides very predictable lookup.

---

## Chain Hashing vs Extendible Hashing

### Chain Hashing

    Bucket
      ↓
    Overflow Bucket
      ↓
    Overflow Bucket

### Extendible Hashing

    Directory
       ↓
    Bucket
       ↓
    Split when full
       ↓
    More buckets

---

## Extendible Hashing vs Linear Hashing

### Extendible Hashing

- Uses directory
- Uses global depth
- Uses local depth
- Splits overflowing buckets
- Directory can double

### Linear Hashing

- Uses split pointer
- Gradually splits buckets
- May use multiple hash functions
- Does not simply split whichever bucket overflowed

---

# 99. Hash Table Complexity Cheat Sheet

| Structure / Operation | Lookup | Insert | Delete |
|---|---:|---:|---:|
| Hash table average | O(1) | O(1) | O(1) |
| Hash table worst case | O(n) | O(n) | O(n) |
| Linear probing | O(1) avg. | O(1) avg. | O(1) avg. |
| Cuckoo hashing | O(1) | O(1) expected / can require rebuild | O(1) |
| Chain hashing | O(1) avg. | O(1) avg. | O(1) avg. |

Remember:

> Big-O does not tell the entire performance story.

Database systems also care about:

- Cache behavior
- Memory usage
- CPU cost
- I/O
- Network cost
- Constants

---

# 100. Key Formulas

## Hash Slot

For a simple integer hash:

    slot = key mod number_of_slots

---

## Load Factor

    α = number_of_occupied_slots / total_number_of_slots

or:

    α = n / m

where:

- n = number of entries
- m = number of slots

---

## Extendible Hashing Directory Size

    Directory Size = 2^GlobalDepth

Example:

    GlobalDepth = 3

    Directory Size = 2^3
                   = 8

---

## Example Linear Hashing Functions

Initial:

    h1(k) = k mod n

After expansion:

    h2(k) = k mod 2n

Example:

    n = 4

    h1(k) = k mod 4
    h2(k) = k mod 8

---

# 101. How to Identify the Hashing Scheme From a Question

## If the question says:

"Check the next slot."

Think:

    Linear Probing

---

## If the question says:

"Use two or more possible locations and move an existing key."

Think:

    Cuckoo Hashing

---

## If the question says:

"Use a bucket and add overflow buckets."

Think:

    Chain Hashing

---

## If the question says:

"Directory, global depth, local depth, split bucket."

Think:

    Extendible Hashing

---

## If the question says:

"Split pointer, gradually split buckets."

Think:

    Linear Hashing

---

## If the question says:

"Fixed number of slots."

Think:

    Static Hashing

---

## If the question says:

"Grow incrementally."

Think:

    Dynamic Hashing

---

# 102. Most Important Definitions

## Hash Table

An unordered data structure that maps keys to values.

## Hash Function

A function that maps a key to an integer used to determine a location.

## Collision

When two different keys map to the same location.

## Static Hashing

Hashing with a fixed number of slots or buckets.

## Dynamic Hashing

Hashing that can grow as data increases.

## Open Addressing

A collision-resolution strategy where entries are stored directly in the table and alternative locations are searched when collisions occur.

## Linear Probing

An open-addressing technique that searches sequentially for another available slot.

## Tombstone

A marker representing a previously occupied slot that has been deleted.

## Cuckoo Hashing

A hashing technique where a key has multiple possible locations and insertion may evict existing keys.

## Chain Hashing

A hashing technique where collisions are handled using linked or chained buckets.

## Bloom Filter

A probabilistic structure that can determine that a key is definitely absent or possibly present.

## Extendible Hashing

Dynamic hashing that uses a directory and bucket splitting.

## Global Depth

The number of hash bits currently used by the extendible-hashing directory.

## Local Depth

The number of hash bits associated with a particular bucket.

## Linear Hashing

Dynamic hashing that gradually splits buckets using a split pointer.

## Split Pointer

The pointer identifying the next bucket to be split in linear hashing.

## Sharding

Distributing data across multiple machines or partitions.

## Replication

Maintaining copies of data on multiple nodes.

## Distributed Database

A database whose data and/or processing is distributed across multiple machines.

## Stateless Query Processing

A query-processing layer that does not depend on a particular local storage location and can access distributed storage.

---

# 103. Questions You Should Be Able to Answer

## Hash Tables

### 1. What is a hash table?

An unordered associative data structure mapping keys to values.

### 2. What does a hash function do?

It maps a key to an integer used to determine a starting location.

### 3. What is a collision?

When multiple keys map to the same location.

### 4. What is the average lookup complexity?

Approximately:

    O(1)

### 5. What is the worst-case lookup complexity?

Potentially:

    O(n)

---

# Linear Probing

### 6. How does linear probing resolve collisions?

It scans forward through the table until it finds an available position.

### 7. Why can't deleted slots simply become empty?

Because an empty slot can incorrectly terminate a lookup for a key that was displaced farther down the probe sequence.

### 8. What solves the deletion problem?

Tombstones.

### 9. What happens when the load factor becomes too high?

The table may need to be resized and rehashed.

---

# Cuckoo Hashing

### 10. What is special about cuckoo hashing?

Each key has multiple possible locations.

### 11. What happens during an insertion collision?

An existing key may be evicted and moved to one of its other possible locations.

### 12. What happens if the process enters a cycle?

The table may need to be rebuilt or resized.

---

# Chain Hashing

### 13. How does chain hashing handle collisions?

It stores colliding entries in a bucket chain.

### 14. What happens if a bucket fills?

An additional overflow bucket can be allocated.

### 15. What is the problem with long chains?

Lookup becomes slower.

### 16. How can a Bloom filter help?

It can quickly determine that a key is definitely absent and avoid scanning the chain.

---

# Extendible Hashing

### 17. What is global depth?

The number of hash bits used by the directory.

### 18. What is local depth?

The number of hash bits needed to identify a particular bucket.

### 19. What happens when a bucket overflows?

The bucket can be split and the directory may need to grow.

### 20. What is the directory size?

    2^GlobalDepth

---

# Linear Hashing

### 21. What is the purpose of the split pointer?

It identifies the next bucket that should be split.

### 22. Does linear hashing always split the bucket that overflowed?

No.

The split pointer determines which bucket is split.

### 23. Why?

To distribute resizing work gradually.

### 24. What is the difference between linear probing and linear hashing?

Linear probing resolves collisions.

Linear hashing dynamically grows a bucket-based hash structure.

---

# Distributed Databases

### 25. Why is network communication expensive?

Moving large amounts of data between machines can cost much more than processing data locally.

### 26. What is sharding?

Distributing data across nodes.

### 27. Why is replication useful?

It improves availability and fault tolerance.

### 28. Why push computation toward data?

To reduce network traffic.

### 29. Why does storage architecture matter to the optimizer?

Because the cost of accessing data depends on how the storage engine organizes and retrieves it.

### 30. What is the main YugabyteDB idea?

Combine PostgreSQL compatibility with distributed, cloud-native transactional storage.

---

# 104. Final Mental Model

The entire lecture can be understood as a progression.

## Part 1: Hash Tables

Start with:

    Key
     ↓
    Hash Function
     ↓
    Location

Then ask:

> What happens when two keys want the same location?

This leads to collision-resolution techniques.

---

## Static Hashing

### Linear Probing

    Hash
      ↓
    Slot
      ↓
    Collision?
      ↓
    Scan Forward

### Cuckoo Hashing

    Hash 1 ──→ Location 1
    Hash 2 ──→ Location 2

If both are occupied, keys can be displaced.

---

# Dynamic Hashing

Static tables have difficulty growing.

Dynamic techniques solve this.

## Chain Hashing

    Bucket
      ↓
    Overflow Bucket
      ↓
    Overflow Bucket

## Extendible Hashing

    Directory
        ↓
    Bucket
        ↓
    Full
        ↓
    Split
        ↓
    Redistribute

Uses:

- Global depth
- Local depth

## Linear Hashing

    Bucket 0 ← Split Pointer
    Bucket 1
    Bucket 2
    Bucket 3

Split the bucket indicated by the split pointer.

Then:

    Split Pointer → Next Bucket

This gradually expands the structure.

---

# Distributed Databases

The second half moves from individual data structures to distributed database architecture.

Traditional idea:

    Query Processing
          ↓
       Storage
          ↓
        Disk

Distributed idea:

    Query Processing Nodes
          ↓
    Distributed Storage
          ↓
    Replicated Data
          ↓
    Multiple Machines / Regions

The major new cost is:

    NETWORK COMMUNICATION

Therefore:

> Move computation toward the data.

Instead of:

    Move lots of data
          ↓
    Then process it

Prefer:

    Process data locally
          ↓
    Send only necessary results

---

# The Most Important Concepts to Memorize

If you are studying for a test, prioritize these:

1. Hash table = key → value.
2. Hash function = key → integer.
3. Collision = two keys want the same location.
4. Average hash lookup = O(1).
5. Worst-case hash lookup = O(n).
6. Load factor = occupied slots / total slots.
7. Linear probing = scan forward after a collision.
8. Tombstones are needed for correct deletion in linear probing.
9. Cuckoo hashing uses multiple possible locations.
10. Chain hashing uses overflow buckets/chains.
11. Bloom filters can say "definitely not" but can produce false positives.
12. Extendible hashing uses a directory.
13. Global depth describes the directory.
14. Local depth describes an individual bucket.
15. Extendible hashing splits buckets and may double the directory.
16. Linear hashing uses a split pointer.
17. Linear hashing grows gradually.
18. Linear probing and linear hashing are completely different.
19. Database data structures must work with the buffer pool.
20. Database systems cannot assume everything fits in memory.
21. Distributed databases use sharding to distribute data.
22. Replication improves resilience and availability.
23. Network communication can be more expensive than local processing.
24. Distributed query plans should minimize data movement.
25. YugabyteDB combines PostgreSQL compatibility with distributed storage.
26. Storage architecture affects query optimization.
27. Cost-based optimization must account for distributed costs.
28. Multi-region systems introduce latency and consistency tradeoffs.

---

# Quick Exam Cheat Sheet

    HASH TABLE
    Key → Hash Function → Location

    COLLISION
    Two keys → Same location

    LOAD FACTOR
    α = n / m

    LINEAR PROBING
    Collision → Check next slot

    TOMBSTONE
    Deleted entry that still allows lookup to continue

    CUCKOO HASHING
    Multiple possible locations
    Collision → Evict and relocate

    CHAIN HASHING
    Collision → Overflow bucket / chain

    BLOOM FILTER
    "Definitely not" or "Maybe"

    EXTENDIBLE HASHING
    Directory
    Global depth
    Local depth
    Split buckets
    Directory can double

    LINEAR HASHING
    Split pointer
    Gradual bucket splitting
    Multiple hash functions

    SHARDING
    Data distributed across nodes

    REPLICATION
    Copies of data on multiple nodes

    DISTRIBUTED QUERY OPTIMIZATION
    Minimize network data movement

    YUGABYTE
    PostgreSQL compatibility
    +
    Distributed cloud-native storage

---

# Final Comparison Table

| Concept | Main Idea | Key Feature |
|---|---|---|
| Static Hashing | Fixed-size hash table | Size does not automatically grow |
| Linear Probing | Scan for another slot | Simple open addressing |
| Cuckoo Hashing | Multiple possible locations | Eviction |
| Chain Hashing | Overflow chains | Bucket pointers |
| Extendible Hashing | Split buckets | Global/local depth |
| Linear Hashing | Gradual splitting | Split pointer |
| Bloom Filter | Fast membership check | No false negatives |
| Sharding | Distribute data | Horizontal scaling |
| Replication | Copy data | Fault tolerance |
| Distributed Query Processing | Process across nodes | Minimize network traffic |
| YugabyteDB | PostgreSQL + distributed storage | Cloud-native distributed database |

---

# One-Sentence Summary of the Lecture

The lecture explains how database systems use specialized hash-based access methods that integrate with the buffer pool, how static and dynamic hashing techniques handle collisions and growth, and how distributed databases such as YugabyteDB extend these ideas to multiple machines while minimizing expensive data movement across the network.