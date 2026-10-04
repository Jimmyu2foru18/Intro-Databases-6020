# Indexes, Filters, Tries, Inverted Indexes, and Vector Indexes

## 1. Indexes vs. Filters

### Definition: Index

An **index** is a data structure used to efficiently find records in a table based on an attribute or key.

Examples:

- Hash tables
- B+ trees
- Skip lists
- Tries / radix trees
- Inverted indexes
- Vector indexes

An index is designed to avoid scanning the entire table.

### Why Do We Need Indexes?

Consider a table containing **1 billion tuples**.

Without an index:

    Query
      |
      v
    Scan 1 billion tuples
      |
      v
    Find matching record

This can be extremely expensive.

With an index:

    Query
      |
      v
    Index
      |
      v
    Find location of record
      |
      v
    Fetch record

The extra memory and computational cost of maintaining an index is often worth it because it avoids expensive sequential scans.

### Definition: Filter

A **filter** is a data structure used to answer a set-membership question:

> "Does this key possibly exist?"

Unlike an index, a filter generally does not tell us where the record is.

### Index vs. Filter

| Feature | Index | Filter |
|---|---|---|
| Tests whether a key exists | Yes | Yes |
| Gives location of record | Yes | No |
| Used to retrieve records | Yes | No |
| Can have false positives | Usually no | Some can |
| Can have false negatives | No | Bloom filters cannot |
| Example | B+ tree | Bloom filter |

### Key Idea

Think of an index as:

    "Does it exist, AND where is it?"

A filter as:

    "Could it exist?"

---

# 2. Bloom Filters

## Definition

A **Bloom filter** is a compact probabilistic data structure used to determine whether a key is possibly contained in a set.

A Bloom filter guarantees:

- **No false negatives**
- **Possible false positives**

Therefore:

    FALSE → definitely does not exist
    TRUE  → possibly exists

### What Does "Probabilistic" Mean?

The Bloom filter can return an incorrect positive result.

Example:

    Key was NOT inserted

but:

    Bloom Filter → TRUE

This is a **false positive**.

However, a standard Bloom filter will never say:

    Bloom Filter → FALSE

for a key that was actually inserted.

That would be a false negative.

---

# 3. Bloom Filter Structure

A Bloom filter consists primarily of:

1. A bit vector / bitmap
2. Multiple hash functions

Example with 8 bits:

    Position:
    0 1 2 3 4 5 6 7

    Bits:
    0 0 0 0 0 0 0 0

Initially, all bits are `0`.

---

# 4. Bloom Filter Insertion

Suppose we have:

- 8 bits
- 2 hash functions

We insert:

    Riza

The hash functions might produce:

    h1(Riza) → 6
    h2(Riza) → 4

Set those positions to `1`.

Before:

    0 0 0 0 0 0 0 0

After setting position 6:

    0 0 0 0 0 0 1 0

After setting position 4:

    0 0 0 0 1 0 1 0

### Step-by-Step Insertion

1. Take the key.
2. Hash the key using hash function 1.
3. Hash the key using hash function 2.
4. Convert the hash results into positions in the bit vector.
5. Set those positions to `1`.

### Multiple Hash Functions

A Bloom filter can use multiple hash functions:

    Key
     |
     +----> Hash 1 ----> Bit 6
     |
     +----> Hash 2 ----> Bit 4
     |
     +----> Hash 3 ----> Bit 1

The same hashing algorithm can be used with different seeds to produce different locations.

---

# 5. Bloom Filter Lookup

To search for a key:

1. Hash the key using the same hash functions.
2. Check every corresponding bit.
3. If **any bit is 0**, the key definitely does not exist.
4. If **all bits are 1**, the key may exist.

### Example: Key Exists

Suppose:

    Riza → positions 6 and 4

and:

    bit 6 = 1
    bit 4 = 1

Then:

    Bloom Filter → TRUE

The key may exist.

### Example: Definitely Does Not Exist

Suppose:

    Raycon → positions 5 and 3

and:

    bit 5 = 1
    bit 3 = 0

Since one required bit is `0`:

    Bloom Filter → FALSE

Therefore Raycon definitely was not inserted.

---

# 6. Why Bloom Filters Have No False Negatives

When a key is inserted, every bit corresponding to its hash functions is set to `1`.

Therefore, when the same key is looked up later, those positions must still be `1`.

If one of them is `0`, the key could never have been inserted.

Therefore:

    One required bit = 0
              |
              v
        Definitely absent

This guarantees no false negatives.

---

# 7. Bloom Filter False Positives

Suppose we did NOT insert:

    ODB

But ODB hashes to:

    h1(ODB) → 2
    h2(ODB) → 6

If both positions already contain `1` because other keys were inserted:

    bit 2 = 1
    bit 6 = 1

then:

    Bloom Filter → TRUE

But ODB is not actually present.

This is a **false positive**.

### Important Rule

Always remember:

    FALSE = definitely not there
    TRUE  = maybe there

---

# 8. Bloom Filter Trade-Offs

Bloom filters allow you to tune the false-positive rate.

Important factors include:

- Size of the bit vector
- Number of inserted keys
- Number of hash functions

### Too Small a Bit Vector

If the bit vector is too small, many bits become `1`.

Eventually it could look like:

    1 1 1 1 1 1 1 1

Now almost every key will appear to exist.

The filter becomes much less useful.

### Too Many Hash Functions

Using more hash functions can improve accuracy up to a point.

However, if there are too many hash functions relative to the size of the bitmap, they will rapidly set many bits to `1`.

Therefore there is a balance between:

    Memory
    Hashing cost
    False-positive rate

Bloom filters are typically very small compared with the data they represent.

---

# 9. Bloom Filters in Database Systems

Bloom filters are useful in many parts of database systems because they are:

- Compact
- Fast
- Memory efficient
- Cheap to query

Possible uses include:

- In-memory caches
- Hash tables
- Hash joins
- Storage engines
- Index structures

---

# 10. Bloom Join / Bloom Hash Join

A Bloom filter can be placed in front of a hash table.

Without a Bloom filter:

    Query
      |
      v
    Hash Table
      |
      v
    Probe

With a Bloom filter:

    Query
      |
      v
    Bloom Filter
      |
      +-------- FALSE --------> Stop
      |
      +-------- TRUE ---------> Hash Table
                                    |
                                    v
                                  Probe

### Why Is This Faster?

If the Bloom filter returns `FALSE`, the key definitely does not exist.

Therefore, we avoid the more expensive hash-table probe.

If the Bloom filter returns `TRUE`, we still have to check the hash table because the result might be a false positive.

---

# 11. Bloom Filter Deletion

### Important Limitation

A standard Bloom filter does **not support deletion**.

### Why?

Suppose:

    Key A → bit 4
    Key B → bit 4

Both keys caused bit 4 to become `1`.

If we delete Key A and change:

    bit 4: 1 → 0

then Key B will also appear to be missing.

That creates a false negative.

Therefore, you cannot safely delete individual keys from a standard Bloom filter.

### Common Mistake

Do not simply change Bloom filter bits from:

    1 → 0

when deleting a key.

You do not know whether another key also depends on that bit.

---

# 12. Counting Bloom Filters

## Definition

A **counting Bloom filter** replaces individual bits with counters.

Instead of:

    0 1 1 0 1

we can have:

    0 2 1 0 3

The counters indicate how many inserted keys contributed to each location.

### Example

Suppose three keys map to the same position:

    Key A → Position 4
    Key B → Position 4
    Key C → Position 4

The counter becomes:

    Position 4 = 3

If Key A is deleted:

    3 → 2

If Key B is deleted:

    2 → 1

If Key C is deleted:

    1 → 0

Now the position can safely become inactive.

### Advantage

Counting Bloom filters support deletion while retaining the basic probabilistic membership behavior.

---

# 13. Cuckoo Filters

A **Cuckoo filter** is another probabilistic membership data structure.

Instead of storing the entire key, it stores a small representation called a **fingerprint**.

Conceptually:

    Full key
       |
       v
    Fingerprint
       |
       v
    Store compact representation

Cuckoo filters support:

- Membership checks
- Deletion
- Compact storage

They can still produce false positives but are designed to avoid false negatives.

---

# 14. SuRF / Succinct Range Filters

A **succinct range filter (SuRF)** is a compact structure that can perform membership-style queries as well as range-related queries.

This gives it functionality beyond a standard Bloom filter.

Conceptually:

    Bloom Filter
        |
        +--> Membership

    SuRF
        |
        +--> Membership
        |
        +--> Range membership

---

# 15. Bloom Filter vs. Count-Min Sketch

These data structures answer different questions.

### Bloom Filter

Question:

> "Does this key exist?"

Purpose:

    Set membership

### Count-Min Sketch

Question:

> "Approximately how many times have I seen this key?"

Purpose:

    Frequency estimation

### Comparison

| Structure | Main Question | Purpose |
|---|---|---|
| Bloom Filter | Does the key exist? | Membership |
| Counting Bloom Filter | Does the key exist, with deletion? | Membership |
| Count-Min Sketch | How frequently did I see this key? | Frequency estimation |

A Count-Min Sketch is not simply a larger Bloom filter. It solves a different problem.

---

# 16. Skip Lists

## Definition

A **skip list** is a multi-level linked list that adds additional pointers allowing the search to skip over many elements.

A normal linked list looks like:

    1 → 2 → 3 → 4 → 5 → 6 → 7 → ...

Searching can require scanning many elements.

A skip list adds higher levels:

    Level 2:       1 --------> 5 --------> ...
                   |           |
    Level 1:       1 ---> 3 ---> 5 ---> 7 ---> ...
                   |     |      |     |
    Level 0:       1 → 2 → 3 → 4 → 5 → 6 → 7 → ...

The upper levels act as shortcuts.

---

# 17. Skip List Construction

The bottom level contains **every key**.

Higher levels contain progressively fewer keys.

For example:

    Level 0:  1 2 3 4 5 6 7 8 9 10
    Level 1:  1   3   5   7   9
    Level 2:  1       5       9
    Level 3:  1               9

The higher we go, the fewer nodes there are.

### Important Idea

A skip list uses randomness to decide which keys get promoted to higher levels.

---

# 18. Skip List Randomization

When inserting a key:

1. Insert it into the bottom level.
2. Flip a coin.
3. If heads, promote it to the next level.
4. Flip again.
5. Continue promoting while the coin keeps coming up heads.
6. Stop when the coin comes up tails.

Conceptually:

    Insert key
        |
        v
    Bottom level
        |
      Coin?
      /   \
    Heads  Tails
      |      |
      v      v
    Promote  Stop
      |
    Coin?
      |
      ...

Therefore, the number of levels is not fixed.

---

# 19. Skip List Complexity

A skip list has **expected / average O(log n)** search behavior.

Unlike a balanced B+ tree, it does not deterministically guarantee O(log n) for every possible construction.

The randomness makes it approximately logarithmic on average.

### Comparison

| Structure | Search | Balancing |
|---|---|---|
| Linked list | O(n) | Not applicable |
| Skip list | Expected O(log n) | Randomized |
| Balanced B+ tree | O(log n) | Explicit balancing |

---

# 20. Skip List Lookup

Suppose we want to find key `3`.

Start at the highest level.

If the next key is too large:

    Search key = 3
    Next key = 5

Since:

    3 < 5

do not move right.

Instead, move down.

If the next key is smaller:

    Search key = 3
    Next key = 2

then:

    3 > 2

so move right.

Continue this process:

    Start at top
        |
        v
    Compare next key
        |
        +---- too large ---> Move down
        |
        +---- smaller -----> Move right
        |
        v
    Eventually reach bottom
        |
        v
    Scan neighboring leaf nodes

### General Search Strategy

At every level:

- If moving right would go too far, move down.
- If moving right is safe, move right.
- Eventually reach the bottom-level linked list.

---

# 21. Skip List Towers

When a key is promoted to multiple levels, it forms a **tower**.

Conceptually:

    Level 3       K
                  |
    Level 2       K
                  |
    Level 1       K
                  |
    Level 0       K

The upper entries point downward to the next level.

At the bottom level, the node participates in the actual linked list.

---

# 22. Skip List Insertion

A simplified insertion process is:

1. Determine the levels for the new key using coin flips.
2. Create the key's tower.
3. Connect the bottom-level node into the linked list.
4. Connect higher-level pointers.
5. Update predecessor pointers to point to the new tower.

The bottom level is the actual data structure that guarantees the key exists in the list.

Higher levels act as guideposts.

---

# 23. Skip List Deletion

Deleting a skip-list key can be expensive if we immediately remove every tower node and modify every pointer.

Instead, a system can use **logical deletion**.

### Logical Deletion

Mark the key:

    deleted = true

The record remains physically present for the moment.

A background process can later clean it up.

This is similar to cleanup/compaction approaches used in log-structured systems.

### Deletion Process

1. Find the key.
2. Mark the bottom-level record as deleted.
3. Future lookups ignore it.
4. A background process eventually removes the tower.
5. Update pointers during cleanup.
6. Physically remove the record.

---

# 24. Skip List vs. B+ Tree

Skip lists and B+ trees have similar high-level goals.

Both provide shortcuts through ordered data.

### Similarity

A B+ tree:

    Upper nodes
         |
         v
    Guideposts
         |
         v
    Leaf nodes

A skip list:

    Upper levels
         |
         v
    Skip pointers
         |
         v
    Bottom linked list

### Differences

| Feature | B+ Tree | Skip List |
|---|---|---|
| Basic structure | Tree | Multi-level linked list |
| Balance | Explicitly balanced | Randomized |
| Search | O(log n) | Expected O(log n) |
| Rebalancing | Yes | No |
| Splits/merges | Yes | No |
| Random construction | No | Yes |
| Common use | On-disk indexes | In-memory structures |
| Range scans | Excellent | Possible |
| Disk I/O efficiency | Excellent | Usually worse |

### Important Point

Skip lists are commonly used for **in-memory** data structures.

They are less attractive for disk-based indexes because the many pointers and node movements can result in more I/O than a B+ tree.

---

# 25. Skip Lists in Database Systems

Skip lists are often used in memory-oriented database components.

Examples discussed in the lecture include:

- Memtables in log-structured merge systems
- RocksDB-style systems
- Other in-memory indexes

The main advantage is that skip lists are relatively simple to implement and do not require complicated tree rebalancing.

---

# 26. Tries

## Definition

A **trie** is a tree-based data structure where each level represents part of a key.

Instead of storing the entire key in every node, a trie breaks the key into pieces such as:

- Characters
- Bytes
- Bits
- Digits

### Example

For strings:

    H
    |
    A
    |
    T

The path itself represents:

    H → A → T

which reconstructs:

    "HAT"

---

# 27. Why Tries Are Different

A B+ tree might store entire keys:

    "APPLE"
    "APPLICATION"
    "BANANA"

A trie stores portions of the keys along paths.

This means the traversal itself reconstructs the key.

### Key Idea

If the required part of a key is not present at some level:

    Search
      |
      v
    Missing character/bit
      |
      v
    Key definitely does not exist

The search can stop immediately.

---

# 28. Tries and Key Length

Trie lookup complexity depends on the length of the key.

If:

    K = length of key

then lookup is approximately:

    O(K)

For example, searching for:

    HELLO

requires traversing the characters/bits that represent:

    H → E → L → L → O

The important point is that lookup depends primarily on the key length rather than the total number of records.

---

# 29. Tries and Determinism

One important property of tries is that their layout depends on the keys rather than the insertion order.

If the same keys are inserted in different orders, the trie structure will still represent the same key paths.

Conceptually:

    Insert:
    A, B, C

or:

    C, A, B

The resulting trie layout is determined by the keys themselves.

This is different from randomized structures such as skip lists.

---

# 30. Trie Span and Fan-Out

### Span

The **span** describes how much of the key is represented at each level.

For example, a one-bit-span trie represents:

    1 bit per level

A byte-oriented trie might represent:

    8 bits per level

### Fan-Out

The **fan-out** describes how many possible branches can come out of a node.

For example, if each node represents a byte:

    256 possible byte values

could theoretically produce up to:

    256 branches

although implementations usually avoid physically storing empty branches.

---

# 31. Example: One-Bit Trie

Suppose we want to store:

    10
    25
    31

Using a one-bit-span trie means:

> Each level represents one bit of the key.

The keys are converted into binary.

Each level examines one bit.

Conceptually:

    Bit 0
      |
      +---- 0
      |
      +---- 1

Then the next level examines the next bit:

    Bit 1
      |
      +---- 0
      |
      +---- 1

Eventually, the paths differentiate the keys.

At the bottom, the path points to the corresponding record.

---

# 32. Trie Compression

A naive trie can contain many unnecessary nodes.

There are two important compression ideas.

## Horizontal Compression

If there is no meaningful branching at a level, there is no need to store every possible branch.

Instead, only store the information that actually occurs.

Example:

    0 → next node
    1 → NULL

may be represented more compactly because there is no real branching choice.

---

## Vertical Compression

If there is a long path where no branching occurs:

    A
    |
    B
    |
    C
    |
    D
    |
    E
    |
    Record

we can compress the entire path.

Instead of storing every intermediate node, we can jump directly toward the record.

This produces a **radix tree**.

---

# 33. Radix Trees

A **radix tree** is a compressed trie.

The compression removes unnecessary paths where there is no branching.

The lecture also referred to related terminology such as:

- Radix tree
- Radix trie
- Patricia tree
- PATRICIA tree

These structures are closely related to compressed tries.

### Important Distinction

The compression itself does not necessarily create false positives.

The **truncation/compression that discards enough key information to require checking the original record** can create a possible false-positive-style situation.

---

# 34. Radix Tree False Positives

Suppose compression causes the index to discard some information from the original key.

The index may lead us to a candidate record.

However, the candidate might not actually contain the complete key we requested.

Therefore:

    Search key
       |
       v
    Radix tree
       |
       v
    Candidate
       |
       v
    Check original record
       |
       +---- Match
       |
       +---- Not a match

This is similar to probing a hash table where the location is occupied but we still have to compare the actual key.

### Important Idea

The index tells us:

> "This is a candidate."

We may still need to verify the original tuple.

---

# 35. Tries and Prefix Keys

A trie can naturally handle situations where one key is a prefix of another.

For example:

    HAT
    H

The path for `H` can terminate at `H`, while another branch continues:

    H
    |
    +---- A
          |
          T

The trie can therefore represent both:

    H

and:

    HAT

A key does not have to be a leaf in order to be a valid key.

---

# 36. Trie Modification

Suppose a trie contains:

    HAT

and we insert:

    HAIR

The existing path:

    H → A

can be shared.

Then the structure branches:

    H
    |
    A
   / \
  T   I
      |
      R

The trie expands only where the new key differs from existing keys.

---

# 37. Trie Deletion and Compression

Suppose we delete a key.

If that deletion leaves a node with only one remaining path, the system may be able to compress the path again.

For example:

Before:

    A
    |
    I
    |
    R

If the structure no longer needs the intermediate nodes, they can potentially be compressed into a shorter representation.

This is one of the ideas behind **adaptive radix trees**.

---

# 38. Adaptive Radix Trees (ART)

An **Adaptive Radix Tree (ART)** is a practical optimized form of a radix tree.

The basic idea is to allow nodes to have different internal representations depending on how many children they actually have.

Instead of every node always having a huge array of possible children, the node representation can adapt to the number of children.

### Benefits

- Space efficiency
- Fast lookups
- Good cache behavior
- Compression
- Dynamic node sizing

The lecture mentioned ART as an important modern implementation of radix-tree-style indexing.

---

# 39. Trie / Radix Tree vs. B+ Tree

### When Is a Radix Tree Better?

Radix trees are particularly attractive when:

- Keys are large
- Keys share prefixes
- Many point lookups are performed
- Many lookups are for keys that do not exist

If the first part of the key immediately fails:

    Search
      |
      v
    First node
      |
      v
    Missing path
      |
      v
    STOP

The search can terminate very early.

### When Is a B+ Tree Better?

B+ trees are generally better for:

- Range scans
- Ordered traversal
- Disk-based indexes
- Traditional table indexes

### Comparison

| Feature | B+ Tree | Radix Tree |
|---|---|---|
| Point lookup | Excellent | Excellent |
| Range scan | Excellent | Usually less convenient |
| Large keys | More expensive | Often better |
| Prefix-based keys | Good | Excellent |
| Missing-key lookup | May require traversal | Can terminate early |
| On-disk use | Very common | Less common |
| In-memory use | Common | Common |

---

# 40. Why We Need Inverted Indexes

Traditional indexes such as B+ trees and tries are excellent for:

- Point queries
- Range queries

Examples:

    Find user with ID = 100

or:

    Find users born between 1990 and 2000

But they are not designed for **keyword searches inside large text values**.

---

# 41. The Problem with Regular Indexes and Text

Suppose a table has:

    Article
    -------------------------
    id
    content

and:

    content = "Pavlo wrote a database paper..."

If we create a B+ tree on `content`, the index treats the entire content value as the key.

It does NOT automatically break it into:

    Pavlo
    wrote
    a
    database
    paper

Therefore, asking:

    Find all articles containing "Pavlo"

cannot be efficiently answered by a normal B+ tree on the entire content column.

It may require a sequential scan.

---

# 42. Inverted Index

## Definition

An **inverted index** is a specialized index that maps individual terms/words to the records containing those terms.

Instead of:

    Record → Entire text

we build:

    Term → Records containing term

### Example

Suppose:

    Record 1:
    "database systems"

    Record 2:
    "database indexes"

    Record 3:
    "database systems and indexes"

The inverted index might look like:

    database → [1, 2, 3]
    systems  → [1, 3]
    indexes  → [2, 3]

The lists are called **posting lists**.

---

# 43. Posting Lists

A **posting list** contains the record IDs associated with a particular term.

Example:

    Term:
    "database"

    Posting list:
    [1, 2, 3, 8, 14, 27]

This means the term occurs in those records.

### General Structure

    Term Dictionary
          |
          v
       "database"
          |
          v
    Posting List
    [1,2,3,8,14,...]

---

# 44. Dictionary + Posting List

An inverted index typically contains two major concepts:

### Dictionary

Maps a term to information about the term.

Example:

    database → ...

### Posting List

Contains the records where that term appears.

Example:

    database → [1, 2, 3, 8, 14]

The dictionary can also maintain information such as term frequency.

---

# 45. Full-Text Search

Inverted indexes are also called:

- Full-text search indexes
- Full-text indexes

They are designed for searching terms inside text.

Historically, similar structures were called **concordances**.

The basic idea is:

    Text
      |
      v
    Tokenize
      |
      v
    Terms
      |
      v
    Dictionary
      |
      v
    Posting Lists
      |
      v
    Search results

---

# 46. Specialized Full-Text Search Systems

Examples mentioned in the lecture include:

- Apache Lucene
- Vespa
- Tantivy
- Elasticsearch
- OpenSearch
- Splunk

These systems specialize in text search and often provide more sophisticated functionality than the built-in full-text capabilities of a general relational database.

---

# 47. Lucene and Finite State Transducers

Lucene uses a specialized structure called a **finite state transducer (FST)** for dictionary-related tasks.

It behaves somewhat like a compressed trie.

Instead of simply storing pointers, edges contain weights.

### Basic Idea

    Search term
        |
        v
    Traverse FST
        |
        v
    Accumulate edge weights
        |
        v
    Compute dictionary offset
        |
        v
    Retrieve term

---

# 48. FST Example

Suppose we want to find:

    PAV

We traverse:

    P → A → V

Suppose the edge weights are:

    P = 2
    A = 1
    V = 0

Then:

    Offset = 2 + 1 + 0
           = 3

The resulting offset tells the system where to find the term in its sorted dictionary.

### Why This Is Useful

The FST can store a compact representation of a large sorted dictionary without repeatedly storing all of the terms.

---

# 49. Why Lucene FSTs Are Immutable

The FST depends on the sorted set of terms and their associated weights.

If a new term is inserted, the weights and structure may change.

For example:

    Existing terms:
    A
    PAV
    RAV

If we insert:

    JELLY

the sorted dictionary changes.

Therefore, Lucene can build an FST in batches and then freeze it.

### General Process

    Build dictionary
         |
         v
    Construct FST
         |
         v
    Freeze FST
         |
         v
    New data arrives
         |
         v
    Build another structure
         |
         v
    Background merge

This is similar to ideas used in log-structured systems.

---

# 50. Compression in Full-Text Indexes

Full-text indexes can use techniques such as:

- Bit packing
- Delta encoding
- Dictionary compression
- Prefix compression

The goal is to reduce the amount of storage required.

---

# 51. PostgreSQL GIN

PostgreSQL provides a structure called a:

**Generalized Inverted Index (GIN)**

The basic structure is:

    B+ Tree dictionary
          |
          v
       Term
          |
          v
    Posting list

The B+ tree provides the dictionary structure.

The leaf nodes point to the posting information.

---

# 52. PostgreSQL Posting Lists

If a term appears in only a small number of records, its posting list can simply be an array of record IDs.

Example:

    term = "database"

    posting list:
    [4, 18, 27, 32]

If the posting list becomes very large, searching through it sequentially becomes expensive.

The system can therefore use another B+ tree to manage the posting IDs.

This can result in a structure resembling:

    B+ Tree
      |
      +---- term A
      |
      +---- term B
      |       |
      |       v
      |    B+ Tree of posting IDs
      |
      +---- term C

This is effectively a **forest of trees**.

---

# 53. Modification of Inverted Indexes

Maintaining a full-text index after every:

- Insert
- Update
- Delete

can be expensive.

A common solution is to use a **modification log (mod log)**.

### Process

    Updates
       |
       v
    Modification Log
       |
       v
    Background process
       |
       v
    Merge / compact
       |
       v
    Main index

This avoids constantly rebuilding the main index for every individual change.

---

# 54. Ranking Search Results

An inverted index can answer:

> "Which records contain this term?"

But search systems often need to answer:

> "Which matching records are most relevant?"

This requires **ranking**.

---

# 55. Term Frequency (TF)

One basic ranking approach is **term frequency (TF)**.

The idea is:

> A term appearing more frequently in a document may indicate that the document is more relevant to that term.

For example:

    Article A:
    "Wang ... Wang ... Wang ..."

    Article B:
    "Wang ..."

Article A may receive a higher score.

### Problem

Very common words can appear everywhere.

For example:

    the
    and
    of

A simple frequency-based ranking could incorrectly give common words too much importance.

---

# 56. BM25

**BM25** is a more sophisticated ranking algorithm used by systems such as Lucene-based search engines.

One important idea is that repeatedly seeing the same term does not increase relevance indefinitely.

In other words:

    More occurrences
          |
          v
    More relevance
          |
          v
    Diminishing returns

This prevents a document containing the same word excessively from automatically dominating search results.

### Comparison

| Ranking | Basic Idea |
|---|---|
| TF | Frequency of term in document |
| BM25 | More sophisticated relevance scoring with diminishing returns and other factors |

---

# 57. Tokenization

Before building an inverted index, text usually needs to be **tokenized**.

Tokenization means converting raw text into searchable terms.

A simplistic tokenizer might split on spaces:

    "hello world database"

becomes:

    hello
    world
    database

Real search systems can perform much more sophisticated processing.

---

# 58. Tokenization Techniques

A tokenizer can potentially:

- Remove punctuation
- Handle hyphens
- Normalize words
- Handle abbreviations
- Handle alternate spellings
- Generate n-grams

For example:

    U.S.

could potentially be normalized to:

    US

A tokenizer may also make:

    word-with-hyphen

searchable as related forms.

---

# 59. N-Grams

An **n-gram** is a sequence of `n` consecutive characters or tokens.

For example, using character trigrams:

    WANG

could produce sequences such as:

    WAN
    ANG

The exact implementation depends on the tokenizer.

### Why Use N-Grams?

N-grams can help with:

- Fuzzy matching
- Misspellings
- Partial matches
- Approximate text searches

Without n-grams, a traditional inverted index may primarily support exact term matching.

---

# 60. Inverted Index vs. Semantic Search

An inverted index is good at:

    "Find documents containing the word X."

But it does not inherently understand the meaning of the text.

For example, a user might search:

    "songs about running from the police"

A traditional inverted index would primarily look for the actual terms.

It does not automatically understand that:

    "fleeing officers"

might have a similar meaning to:

    "running from the police"

This is the limitation that **vector indexes** are designed to address.

---

# 61. Vector Embeddings

## Definition

An **embedding** is a fixed-length array of numbers representing some underlying information, often semantic meaning.

For example:

    Text
      |
      v
    Transformer
      |
      v
    [0.14, -0.82, 0.31, ...]
      |
      v
    Embedding

The numbers are floating-point values.

Humans are not expected to directly interpret the individual numbers.

The model learns a representation in which semantically similar inputs can be located near one another.

---

# 62. Creating Embeddings

Suppose we have song lyrics.

We can take:

    Song lyrics
        |
        v
    Transformer
        |
        v
    Fixed-length embedding
        |
        v
    Vector index

A query can go through the **same transformer**:

    "running from the police"
             |
             v
        Transformer
             |
             v
        Query embedding
             |
             v
        Vector index

The system then searches for vectors close to the query vector.

---

# 63. Vector Search

The goal of vector search is often:

> Find the vectors closest to the query vector.

This is called **nearest-neighbor search**.

For very large datasets, systems commonly perform:

**Approximate Nearest Neighbor (ANN)** search.

### Why Approximate?

With billions or trillions of vectors, comparing the query against every vector would be extremely expensive.

Instead, specialized indexes try to quickly find highly similar vectors without scanning everything.

---

# 64. Semantic Search Example

Suppose a database contains song lyrics.

The query is:

    "songs about running from the police"

The system:

1. Converts the query into an embedding.
2. Searches the vector index.
3. Finds nearby vectors.
4. Returns the corresponding record IDs.
5. Ranks the results by similarity.

Conceptually:

    Query text
        |
        v
    Transformer
        |
        v
    Query embedding
        |
        v
    Vector index
        |
        v
    Nearest vectors
        |
        v
    Record IDs
        |
        v
    Ranked results

The key difference is that the search can be based on **semantic similarity**, not merely matching exact words.

---

# 65. Vector Search with Additional Filters

Vector indexes can also store or work with metadata.

Suppose we want:

> Songs about running from the police released after 2005.

The system can use:

    Semantic condition:
    "running from the police"

and:

    Metadata condition:
    year > 2005

Conceptually:

    Query
      |
      +----> Semantic embedding
      |
      +----> Metadata filter
      |
      v
    Vector index
      |
      v
    Matching results

The exact order of applying the semantic search and metadata filter depends on the implementation and workload.

---

# 66. Vector Index Requirements

Embeddings in a vector index are generally:

- Fixed-length
- Arrays of floating-point values
- High-dimensional

For example:

    Record A → [x1, x2, x3, ..., xn]
    Record B → [y1, y2, y3, ..., yn]

Every vector has the same dimensionality.

The system then uses a distance or similarity function to determine how close vectors are.

---

# 67. Why Vector Search Is Approximate

Semantic search is not guaranteed to return the exact result a human would consider best.

The transformer converts meaning into a numerical representation, but there is no perfect guarantee that the mathematically closest vector corresponds exactly to what a human considers most relevant.

Therefore, vector search often involves:

- Approximation
- Ranking
- Similarity thresholds
- Empirical tuning

The goal is usually to produce results that are **good enough** rather than mathematically perfect.

---

# 68. Vector Databases

Specialized vector systems include examples such as:

- Pinecone
- Weaviate

However, modern relational database systems increasingly provide vector indexes as well.

Examples mentioned in the lecture include:

- PostgreSQL with `pgvector`
- Oracle
- MySQL
- SQL Server

This means a separate vector database is not always required.

---

# 69. Two Major Vector Index Approaches

The lecture discussed two major approaches:

1. **Inverted-index / clustering-based vector indexes**
2. **Graph-based vector indexes**

---

# 70. Vector Index: Clustering Approach

The basic idea is to partition vectors into clusters.

Suppose we have many embeddings:

    • • • •
       • •
                    • • •
                  • •
    
    • •
    
              • • • •
              • • •

We use a clustering algorithm such as **K-means**.

The algorithm creates groups of similar vectors.

Each group has a **centroid**.

Conceptually:

    Cluster 1 → Centroid 1
    Cluster 2 → Centroid 2
    Cluster 3 → Centroid 3
    ...

---

# 71. Building a Cluster-Based Vector Index

### Step 1: Scan the Data

Start with the collection of embeddings.

### Step 2: Run K-Means

Cluster the vectors into groups.

### Step 3: Compute Centroids

For every cluster, determine its center.

### Step 4: Build the Index

Map each centroid to the vectors/records belonging to that cluster.

Conceptually:

    Centroid A → [Record 1, Record 7, Record 13]
    Centroid B → [Record 2, Record 5, Record 9]
    Centroid C → [Record 3, Record 4, Record 10]

---

# 72. Querying a Cluster-Based Vector Index

Suppose a query becomes:

    Query embedding

The system:

1. Takes the query embedding.
2. Determines which cluster(s) are closest.
3. Uses the corresponding posting list.
4. Searches the candidate vectors.
5. Returns the nearest records.

Conceptually:

    Query vector
         |
         v
    Find closest centroid
         |
         v
    Candidate cluster
         |
         v
    Search candidates
         |
         v
    Top results

This avoids comparing the query against every vector in the database.

---

# 73. Maintaining Cluster-Based Vector Indexes

A major challenge is updates.

Suppose many new vectors are inserted.

The original clustering may no longer represent the data accurately.

Possible approaches include:

- Periodically rebuilding/reclustering
- Partitioning data into immutable structures
- Building new structures for new data
- Merging structures in the background

This resembles the immutable-segment approach used by systems such as Lucene.

---

# 74. Graph-Based Vector Indexes

The second major approach is to create a graph of vectors.

Each vector becomes a node.

Nearby vectors are connected by edges.

Conceptually:

    A ----- B
    |     / |
    |    /  |
    C -- D-- E
         |
         F

Edges represent relationships between nearby vectors.

---

# 75. Graph Vector Search

Suppose we want to search for a query vector `Q`.

The system starts from an entry point.

    Entry Point
         |
         v
    Examine neighbors
         |
         v
    Find closer node
         |
         v
    Examine its neighbors
         |
         v
    Continue
         |
         v
    Best matching vectors

At every step, the system compares the current candidates to the query vector.

It moves through the graph toward increasingly similar vectors.

---

# 76. Why Graph Search Needs Optimization

Imagine a graph containing:

    1 trillion vectors

A graph traversal over the entire structure could still be expensive.

The solution is to organize the graph into multiple layers.

This leads to:

**HNSW — Hierarchical Navigable Small World**

---

# 77. HNSW

## Definition

**HNSW** is a multi-layer graph structure designed for efficient approximate nearest-neighbor search.

It combines the idea of graph traversal with a hierarchy of increasingly smaller graphs.

Conceptually:

    Top level:
    
        A -------- D
         \        
          \       
           E


    Middle level:
    
        A --- B --- D
         \   |   /
          \  E--/


    Bottom level:
    
        Many more nodes and connections

The top layers contain fewer nodes.

---

# 78. HNSW Search

The search begins at a high level.

### Step 1

Start at an entry point in the top layer.

### Step 2

Examine nearby nodes.

### Step 3

Move toward the node that is closer to the query.

### Step 4

When no better node can be found at that level, move down.

### Step 5

Repeat the process.

### Step 6

At the bottom level, perform a more detailed search.

Conceptually:

    Top Level
       |
       v
    Quickly approach target
       |
       v
    Middle Level
       |
       v
    Narrow search
       |
       v
    Bottom Level
       |
       v
    Find nearest neighbors

---

# 79. HNSW and Skip Lists

HNSW is conceptually similar to a skip list.

A skip list has:

    Bottom level = all elements
    Upper levels = fewer elements

HNSW has:

    Bottom graph = many nodes
    Upper graphs = fewer nodes

Both allow the search to:

1. Start with a small structure.
2. Quickly move toward the target.
3. Descend into a more detailed structure.

### Key Idea

Many modern AI/database data structures reuse older database ideas.

HNSW's hierarchical structure is conceptually similar to ideas found in skip lists.

---

# 80. Vector Index Comparison

| Approach | Basic Idea | Main Advantage | Main Challenge |
|---|---|---|---|
| Clustering / inverted index | Group vectors into clusters | Fast candidate selection | Maintaining clusters |
| Graph index | Connect nearby vectors | Flexible nearest-neighbor traversal | Graph traversal cost |
| HNSW | Hierarchical graph | Fast ANN search | Memory and maintenance |

---

# 81. Graphs in Relational Databases

A question raised in lecture was:

> How could a graph be represented in a relational database?

A basic relational representation can use:

### Nodes Table

    Nodes
    ----------------
    node_id
    properties

### Edges Table

    Edges
    ----------------
    source
    destination
    properties

The edges describe which nodes are connected.

---

# 82. Graph Databases vs. Relational Databases

The lecture emphasized that graph workloads can potentially be handled inside relational database systems.

A graph can be represented using relational tables and traversed using optimized database algorithms.

Modern SQL standards have also added **property graph queries**, allowing graph-like traversal over relational data.

The key advantage of running graph traversal inside the database is avoiding repeated application/database communication.

Instead of:

    Application
        |
        v
    Database
        |
        v
    Application
        |
        v
    Database
        |
        v
    Application

the traversal logic can execute on the database server.

---

# 83. PostgreSQL pgvector

`pgvector` is a PostgreSQL extension providing vector search functionality.

The lecture mentioned that it supports multiple approaches, including:

- IVFFlat
- HNSW

### General Idea

PostgreSQL can therefore provide:

    Relational data
          +
    Vector embeddings
          +
    Vector index
          |
          v
    Semantic search

For many workloads, this can be sufficient without deploying a separate specialized vector database.

---

# 84. Partial Indexes

Indexes can be made more efficient by indexing only a subset of table rows.

This is called a **partial index**.

Instead of:

    CREATE INDEX
    on every row

we can conceptually create:

    CREATE INDEX ... 
    WHERE condition

The exact syntax varies somewhat by database system.

### Example Concept

Suppose we only care about records where:

    A = 123

Instead of indexing every tuple:

    Entire Table
         |
         v
    Full Index

we can build:

    Only rows where A = 123
         |
         v
    Smaller Index

---

# 85. Why Partial Indexes Are Useful

A partial index can:

- Consume less storage
- Fit more easily in memory
- Reduce maintenance cost
- Make certain queries faster

Suppose the query is:

    SELECT B
    FROM Foo
    WHERE A = 123
      AND C = 'Wang';

If the index itself is defined with a condition guaranteeing:

    A = 123

then the database already knows that every indexed row satisfies that condition.

It does not have to re-check the same predicate for the indexed entries.

Partial Index Example

Conceptually:

```sql
CREATE INDEX idx_foo_a
ON Foo(A)
WHERE A = 123;
```

---

# 86. Vector Search with Additional Filters

Vector indexes can also store or work with metadata.

Suppose we want:

    Songs about running from the police released after 2005.

The system can use:

    Semantic condition:
    "running from the police"

and:

    Metadata condition:
    year > 2005

Conceptually:

    Query
      |
      +----> Semantic embedding
      |
      +----> Metadata filter
      |
      v
    Vector index
      |
      v
    Matching results

The exact order of applying the semantic search and metadata filter depends on the implementation and workload.

---

# 87. Vector Index Requirements

Embeddings in a vector index are generally:

- Fixed-length
- Arrays of floating-point values
- High-dimensional

For example:

    Record A → [x1, x2, x3, ..., xn]
    Record B → [y1, y2, y3, ..., yn]

Every vector has the same dimensionality.

The system then uses a distance or similarity function to determine how close vectors are.

---

# 88. Why Vector Search Is Approximate

Semantic search is not guaranteed to return the exact result a human would consider best.

The transformer converts meaning into a numerical representation, but there is no perfect guarantee that the mathematically closest vector corresponds exactly to what a human considers most relevant.

Therefore, vector search often involves:

- Approximation
- Ranking
- Similarity thresholds
- Empirical tuning

The goal is usually to produce results that are **good enough** rather than mathematically perfect.

---

# 89. Vector Databases

Specialized vector systems mentioned in the lecture include:

- Pinecone
- Weaviate

However, modern relational database systems increasingly provide vector indexes as well.

Examples mentioned in the lecture include:

- PostgreSQL with `pgvector`
- Oracle
- MySQL
- SQL Server

This means a separate vector database is not always required.

---

# 90. Two Major Vector Index Approaches

The lecture discussed two major approaches:

1. **Inverted-index / clustering-based vector indexes**
2. **Graph-based vector indexes**

---

# 91. Vector Index: Clustering Approach

The basic idea is to partition vectors into clusters.

Suppose we have many embeddings:

    • • • •
       • •
                    • • •
                  • •
    
    • •
    
              • • • •
              • • •

We use a clustering algorithm such as **K-means**.

The algorithm creates groups of similar vectors.

Each group has a **centroid**.

Conceptually:

    Cluster 1 → Centroid 1
    Cluster 2 → Centroid 2
    Cluster 3 → Centroid 3
    ...

---

# 92. Building a Cluster-Based Vector Index

### Step 1: Scan the Data

Start with the collection of embeddings.

### Step 2: Run K-Means

Cluster the embeddings into groups.

### Step 3: Compute Centroids

For every cluster, determine its center.

### Step 4: Build the Index

Map each centroid to the vectors/records belonging to that cluster.

Conceptually:

    Centroid A → [Record 1, Record 7, Record 13]
    Centroid B → [Record 2, Record 5, Record 9]
    Centroid C → [Record 3, Record 4, Record 10]

---

# 93. Querying a Cluster-Based Vector Index

Suppose a query becomes:

    Query embedding

The system:

1. Takes the query embedding.
2. Determines which cluster(s) are closest.
3. Uses the corresponding posting list.
4. Searches the candidate vectors.
5. Returns the nearest records.

Conceptually:

    Query vector
         |
         v
    Find closest centroid
         |
         v
    Candidate cluster
         |
         v
    Search candidates
         |
         v
    Top results

This avoids comparing the query against every vector in the database.

---

# 94. Maintaining Cluster-Based Vector Indexes

A major challenge is updates.

Suppose many new vectors are inserted.

The original clustering may no longer represent the data accurately.

Possible approaches include:

- Periodically rebuilding/reclustering
- Partitioning data into immutable structures
- Building new structures for new data
- Merging structures in the background

This resembles the immutable-segment approach used by systems such as Lucene.

---

# 95. Graph-Based Vector Indexes

The second major approach is to create a graph of vectors.

Each vector becomes a node.

Nearby vectors are connected by edges.

Conceptually:

    A ----- B
    |     / |
    |    /  |
    C -- D-- E
         |
         F

Edges represent relationships between nearby vectors.

---

# 96. Graph Vector Search

Suppose we want to search for a query vector `Q`.

The system starts from an entry point.

    Entry Point
         |
         v
    Examine neighbors
         |
         v
    Find closer node
         |
         v
    Examine its neighbors
         |
         v
    Continue
         |
         v
    Best matching vectors

At every step, the system compares the current candidates to the query vector.

It moves through the graph toward increasingly similar vectors.

---

# 97. Why Graph Search Needs Optimization

Imagine a graph containing:

    1 trillion vectors

A graph traversal over the entire structure could still be expensive.

The solution is to organize the graph into multiple layers.

This leads to:

**HNSW — Hierarchical Navigable Small World**

---

# 98. HNSW

## Definition

**HNSW** is a multi-layer graph structure designed for efficient approximate nearest-neighbor search.

It combines graph traversal with a hierarchy of increasingly smaller graphs.

Conceptually:

    Top level:

        A -------- D
         \
          \
           E


    Middle level:

        A --- B --- D
         \   |   /
          \  E--/


    Bottom level:

        Many more nodes and connections

The top layers contain fewer nodes.

---

# 99. HNSW Search

The search begins at a high level.

### Step 1

Start at an entry point in the top layer.

### Step 2

Examine neighboring nodes.

### Step 3

Move toward the node that is closer to the query.

### Step 4

When no better node can be found at that level, move down.

### Step 5

Repeat the process.

### Step 6

At the bottom level, perform a more detailed search.

Conceptually:

    Top Level
       |
       v
    Quickly approach target
       |
       v
    Middle Level
       |
       v
    Narrow search
       |
       v
    Bottom Level
       |
       v
    Find nearest neighbors

---

# 100. HNSW and Skip Lists

HNSW is conceptually similar to a skip list.

A skip list has:

    Bottom level = all elements
    Upper levels = fewer elements

HNSW has:

    Bottom graph = many nodes
    Upper graphs = fewer nodes

Both allow the search to:

1. Start with a smaller structure.
2. Quickly move toward the target.
3. Descend into a more detailed structure.

### Key Idea

Many modern AI/database data structures reuse older database ideas.

HNSW's hierarchical structure is conceptually similar to ideas found in skip lists.

---

# 101. Vector Index Comparison

| Approach | Basic Idea | Main Advantage | Main Challenge |
|---|---|---|---|
| Clustering / inverted index | Group vectors into clusters | Fast candidate selection | Maintaining clusters |
| Graph index | Connect nearby vectors | Flexible nearest-neighbor traversal | Graph traversal cost |
| HNSW | Hierarchical graph | Fast ANN search | Memory and maintenance |

---

# 102. Graphs in Relational Databases

A question raised in the lecture was:

> How could a graph be represented in a relational database?

A basic relational representation can use:

### Nodes Table

    Nodes
    ----------------
    node_id
    properties

### Edges Table

    Edges
    ----------------
    source
    destination
    properties

The edges describe which nodes are connected.

---

# 103. Graph Databases vs. Relational Databases

The lecture emphasized that graph workloads can potentially be handled inside relational database systems.

A graph can be represented using relational tables and traversed using optimized database algorithms.

Modern SQL standards have also added **property graph queries**, allowing graph-like traversal over relational data.

The key advantage of running graph traversal inside the database is avoiding repeated application/database communication.

Instead of:

    Application
        |
        v
    Database
        |
        v
    Application
        |
        v
    Database
        |
        v
    Application

the traversal logic can execute on the database server.

---

# 104. PostgreSQL pgvector

`pgvector` is a PostgreSQL extension providing vector search functionality.

The lecture mentioned that it supports multiple approaches, including:

- IVFFlat
- HNSW

### General Idea

PostgreSQL can therefore provide:

    Relational data
          +
    Vector embeddings
          +
    Vector index
          |
          v
    Semantic search

For many workloads, this can be sufficient without deploying a separate specialized vector database.

---

# 105. Partial Indexes

Indexes can be made more efficient by indexing only a subset of table rows.

This is called a **partial index**.

Instead of:

    CREATE INDEX
    on every row

we can conceptually create:

    CREATE INDEX
    WHERE condition

The exact syntax varies somewhat by database system.

### Example Concept

Suppose we only care about records where:

    A = 123

Instead of indexing every tuple:

    Entire Table
         |
         v
    Full Index

we can build:

    Only rows where A = 123
         |
         v
    Smaller Index

---

# 106. Why Partial Indexes Are Useful

A partial index can:

- Consume less storage
- Fit more easily in memory
- Reduce maintenance cost
- Make certain queries faster

Suppose the query is:

    SELECT B
    FROM Foo
    WHERE A = 123
      AND C = 'Wang';

If the index itself is defined with a condition guaranteeing:

    A = 123

then the database already knows that every indexed row satisfies that condition.

It does not have to re-check the same predicate for the indexed entries.

---

# 107. Partial Index Example

General PostgreSQL-style syntax:

    CREATE INDEX index_name
    ON table_name(column_name)
    WHERE condition;

Example:

    CREATE INDEX idx_foo_a
    ON Foo(A)
    WHERE A = 123;

This index contains only rows satisfying:

    A = 123

The index is therefore much smaller than an index containing every row.

### Common Use Case

Partial indexes can be useful for data partitioned by conditions such as:

- Month
- Year
- Status
- Active/inactive records
- Frequently queried subsets

For example, a system could maintain an index for records from a particular period.

---

# 108. Include Columns

Another index optimization is to store additional columns in the index without making them part of the index key.

General PostgreSQL-style syntax:

    CREATE INDEX index_name
    ON table_name(key_columns)
    INCLUDE (additional_columns);

Example:

    CREATE INDEX idx_foo
    ON Foo(A, B)
    INCLUDE (C);

Here:

- `A` and `B` are the index keys.
- `C` is included in the leaf nodes.
- `C` does not determine the ordering of the index.

---

# 109. Covering Index

An index that contains everything needed to answer a query is called a **covering index**.

Suppose:

    SELECT B
    FROM Foo
    WHERE A = 123
      AND C = 'Wang';

and the index contains:

    Key:
    A, B

    Included:
    C

The database can:

1. Use `A` to locate candidate entries.
2. Get `B` directly from the index.
3. Check `C` directly from the index.
4. Return the result.

It does not need to fetch the original tuple.

---

# 110. Index-Only Scan

A query that can be answered entirely from the index can perform an **index-only scan**.

Normally:

    Index
      |
      v
    Record pointer
      |
      v
    Table
      |
      v
    Record

With a covering index:

    Index
      |
      v
    All required information
      |
      v
    Result

This can be a major performance improvement.

---

# 111. Partial Index vs. Include Columns

These two optimizations solve different problems.

| Feature | Partial Index | INCLUDE Columns |
|---|---|---|
| Reduces number of indexed rows | Yes | No |
| Adds extra data to index | No | Yes |
| Reduces index size | Often | Can increase it |
| Helps avoid table lookup | Not necessarily | Yes |
| Main purpose | Index only relevant rows | Store extra query data |

---

# 112. Covering Index Example

Suppose:

    SELECT B
    FROM Foo
    WHERE A = 123
      AND C = 'Wang';

A useful index might conceptually be:

    CREATE INDEX idx_foo
    ON Foo(A, B)
    INCLUDE (C);

The index contains everything needed:

    A → search
    B → result
    C → filtering

Therefore:

    No table lookup required

This is why it is called a **covering index**.

---

# 113. Important Index Concepts

## Point Query

A query looking for a specific value.

Example:

    SELECT *
    FROM Users
    WHERE user_id = 123;

Indexes such as:

- Hash indexes
- B+ trees
- Tries
- Radix trees

can be useful.

## Range Query

A query looking for a range of values.

Example:

    SELECT *
    FROM Users
    WHERE birth_date BETWEEN '1990-01-01' AND '2000-01-01';

B+ trees are especially useful because their leaves are ordered.

## Keyword Query

A query looking for words inside text.

Example:

    Find articles containing "database".

Use:

    Inverted index

## Semantic Query

A query based on meaning rather than exact words.

Example:

    Find songs about running from the police.

Use:

    Embeddings + Vector Index

---

# 114. Choosing the Right Data Structure

A useful mental model is:

    What am I searching for?
             |
       +-----+-----+
       |           |
     Exact       Text
       |           |
       v           v
   B+ / Hash    Inverted
   / Trie        Index
       |
       |
       +-------------------+
                           |
                     Meaning / Semantics
                           |
                           v
                      Vector Index

### More Detailed Guide

| Problem | Good Data Structure |
|---|---|
| Exact key lookup | Hash table |
| Ordered lookup | B+ tree |
| Range queries | B+ tree |
| In-memory ordered data | Skip list |
| Large/prefix-heavy keys | Radix tree |
| Membership test | Bloom filter |
| Text keyword search | Inverted index |
| Semantic similarity | Vector index |
| Approximate nearest neighbors | HNSW / clustering |

---

# 115. Important Comparison: B+ Tree vs. Skip List vs. Trie

| Feature | B+ Tree | Skip List | Trie |
|---|---|---|---|
| Structure | Tree | Multi-level linked list | Key-character/bit tree |
| Search | O(log n) | Expected O(log n) | O(K) |
| Depends on key length | Less directly | No | Yes |
| Randomized | No | Yes | No |
| Rebalancing | Yes | No | No |
| Great for range scans | Yes | Possible | Less convenient |
| Great for large keys | Not necessarily | Not necessarily | Yes |
| Common use | Disk indexes | In-memory structures | In-memory/key indexes |

Where:

    n = number of keys
    K = length of the key

---

# 116. Important Comparison: Bloom Filter vs. Index

| Question | Bloom Filter | Index |
|---|---|---|
| Is the key definitely absent? | Yes | Yes |
| Is the key possibly present? | Yes | Yes |
| Gives exact location? | No | Yes |
| False positives? | Yes | Generally no |
| False negatives? | No | No |
| Purpose | Quickly eliminate impossible searches | Locate data |

### Best Combination

A database can use both:

    Query
      |
      v
    Bloom Filter
      |
      +---- Definitely absent → Stop
      |
      +---- Possibly present
                |
                v
              Index
                |
                v
              Record

---

# 117. Important Comparison: Inverted Index vs. Vector Index

| Feature | Inverted Index | Vector Index |
|---|---|---|
| Searches exact terms | Excellent | Not the primary goal |
| Understands semantic meaning | No | Yes, approximately |
| Works with embeddings | No | Yes |
| Keyword search | Excellent | Not necessary |
| Fuzzy matching | Can support with tokenization | Naturally similarity-based |
| Approximate nearest-neighbor search | No | Yes |
| Typical structure | Dictionary + posting lists | Clusters or graphs |

### Example

Query:

    "database"

Inverted index:

    Find documents containing "database".

Vector index:

    Find documents semantically similar to the concept represented by the query embedding.

---

# 118. Important Comparison: Trie vs. Radix Tree

| Feature | Trie | Radix Tree |
|---|---|---|
| Stores key pieces | Yes | Yes |
| Compresses paths | No / less | Yes |
| Space efficiency | Lower | Higher |
| Lookup | O(K) | O(K) approximately |
| Can share prefixes | Yes | Yes |
| Common practical implementation | Less common | Very common |

A radix tree is essentially a **compressed trie**.

---

# 119. Common Mistakes

### Mistake 1: Thinking a Bloom Filter Gives a Location

Incorrect:

    "The Bloom filter tells me where the record is."

Correct:

    It only tells me whether the key is definitely absent or possibly present.

---

### Mistake 2: Thinking Bloom Filter TRUE Means Definitely Present

Incorrect:

    TRUE = definitely exists

Correct:

    TRUE = possibly exists

---

### Mistake 3: Thinking Bloom Filters Can Be Normally Deleted

A standard Bloom filter cannot safely delete keys because clearing bits can create false negatives.

Use a structure such as a counting Bloom filter when deletion is needed.

---

### Mistake 4: Confusing Bloom Filters with Count-Min Sketches

Bloom filter:

    Does it exist?

Count-Min Sketch:

    Approximately how many times did it occur?

---

### Mistake 5: Assuming Skip Lists Have a Fixed Number of Levels

They do not.

The number of levels depends on the randomized promotion process.

---

### Mistake 6: Assuming Skip Lists Require Rebalancing

They do not use tree-style balancing, splits, or merges.

They add/remove towers.

---

### Mistake 7: Assuming a B+ Tree's Inner Key Guarantees the Key Exists

An inner-node key is a guidepost.

The actual key must be checked at the leaf level.

---

### Mistake 8: Confusing Trie Compression with False Positives

Compression itself does not necessarily cause false positives.

Discarding enough information through truncation can require checking the original record to determine whether a candidate is actually a match.

---

### Mistake 9: Thinking a Normal B+ Tree Is a Full-Text Search Index

A B+ tree on a text column generally indexes the whole value.

It does not automatically index every individual word.

Use an inverted index for keyword search.

---

### Mistake 10: Thinking Semantic Search Is the Same as Keyword Search

Keyword search:

    "police"

looks for terms.

Semantic search:

    "running from the police"

can retrieve things representing similar meanings even if the exact words differ.

---

### Mistake 11: Assuming Vector Search Is Exact

Vector search is usually approximate.

It attempts to find highly similar vectors efficiently, but there is no guarantee that the mathematical result perfectly matches human judgment.

---

### Mistake 12: Confusing Partial Indexes and Covering Indexes

Partial index:

    Index only rows satisfying a condition.

Covering index:

    Put enough information in the index to answer the query without accessing the table.

---

# 120. Exam Review: Must-Know Definitions

### Index

A data structure that allows a database to efficiently locate records without scanning the entire table.

### Filter

A structure used to determine whether an item may belong to a set.

### Bloom Filter

A probabilistic membership structure with no false negatives but possible false positives.

### False Positive

The structure says something exists when it does not.

### False Negative

The structure says something does not exist when it actually does.

### Counting Bloom Filter

A Bloom-filter variant using counters that supports deletion.

### Cuckoo Filter

A probabilistic membership structure that stores compact fingerprints and supports deletion.

### Skip List

A multi-level linked list with randomized shortcut pointers.

### Trie

A tree where paths represent portions of keys such as characters, bytes, bits, or digits.

### Radix Tree

A compressed trie that removes unnecessary paths.

### Adaptive Radix Tree

A practical radix-tree implementation that adapts node representations based on their number of children.

### Inverted Index

A structure mapping terms to the records containing those terms.

### Posting List

The list of record IDs associated with a particular term.

### Tokenization

The process of breaking text into searchable terms or tokens.

### Embedding

A fixed-length numerical representation of data such as text.

### Vector Index

A specialized structure used to efficiently find vectors that are close to a query vector.

### Approximate Nearest Neighbor

A search method that finds highly similar vectors without exhaustively comparing against every vector.

### HNSW

Hierarchical Navigable Small World, a multi-layer graph structure for approximate nearest-neighbor search.

### Partial Index

An index containing only rows satisfying a specified condition.

### Covering Index

An index containing all information required to answer a query without fetching the original tuple.

### Index-Only Scan

A query execution strategy where the database obtains everything it needs directly from the index.

---

# 121. Exam Review: Must-Know Methods

## Bloom Filter Lookup

1. Hash the key using all hash functions.
2. Find the corresponding bit positions.
3. Check all positions.
4. If any bit is `0`, return definitely absent.
5. If all are `1`, return possibly present.

---

## Skip List Search

1. Start at the highest level.
2. Look at the next key.
3. If the next key is too large, move down.
4. If the next key is smaller than the target, move right.
5. Continue until reaching the bottom.
6. Search the bottom linked list.

---

## Trie Search

1. Start at the root.
2. Read the next portion of the search key.
3. Follow the corresponding branch.
4. If the branch does not exist, stop: the key does not exist.
5. Continue until the complete key has been processed.
6. Follow the final pointer to the record if necessary.

---

## Inverted Index Construction

1. Read the text.
2. Tokenize the text.
3. Extract individual terms.
4. Add each term to the dictionary.
5. Add the record ID to the term's posting list.
6. Optionally store term-frequency information.
7. Compress the resulting structures when possible.

---

## Vector Search

1. Convert stored data into embeddings.
2. Store the embeddings in a vector index.
3. Convert the user's query into an embedding using the same model.
4. Search the vector index.
5. Compute similarity/distance.
6. Retrieve the nearest candidates.
7. Rank the results.
8. Apply additional metadata filters when appropriate.

---

## Cluster-Based Vector Index

1. Generate embeddings.
2. Cluster the embeddings using an algorithm such as K-means.
3. Compute cluster centroids.
4. Build mappings from centroids to records.
5. Convert a query into an embedding.
6. Determine the closest cluster(s).
7. Search candidate vectors.
8. Return the nearest records.

---

## HNSW Search

1. Start at an entry point in the highest layer.
2. Examine neighboring nodes.
3. Move toward a closer node.
4. Stop when no better node is found at that layer.
5. Move down to the next layer.
6. Repeat.
7. Perform a more detailed search at the bottom layer.
8. Return the nearest neighbors.

---

# 122. Must-Know SQL Concepts

## Partial Index

General PostgreSQL-style syntax:

    CREATE INDEX index_name
    ON table_name(column_name)
    WHERE condition;

Example:

    CREATE INDEX idx_foo_a
    ON Foo(A)
    WHERE A = 123;

This indexes only rows satisfying:

    A = 123

---

## Include Columns

General PostgreSQL-style syntax:

    CREATE INDEX index_name
    ON table_name(key_columns)
    INCLUDE (additional_columns);

Example:

    CREATE INDEX idx_foo
    ON Foo(A, B)
    INCLUDE (C);

Here:

- `A, B` are the search/index keys.
- `C` is stored in the index but is not part of the search key.

---

## Covering Index

A covering index contains all information required by a query.

Example query:

    SELECT B
    FROM Foo
    WHERE A = 123
      AND C = 'Wang';

Possible covering index:

    CREATE INDEX idx_foo
    ON Foo(A, B)
    INCLUDE (C);

The database can potentially answer the query without accessing the original table.

---

# 123. The Big Picture

The lecture covered many different structures, but the most important thing is understanding **what problem each one solves**.

                         DATABASE DATA STRUCTURES
                                  |
             +--------------------+--------------------+
             |                    |                    |
          FILTERS               INDEXES             SEARCH
             |                    |                    |
             |          +---------+---------+          |
             |          |         |         |          |
             v          v         v         v          v
        Bloom Filter   B+ Tree  Skip List  Trie    Inverted Index
             |                              |             |
             |                              |             v
             |                              |         Keyword Search
             |                              |
             |                              v
             |                         Radix Tree
             |                              |
             v                              v
      Membership Test                 Large/Prefix Keys
             |
             v
      "Maybe / Definitely Not"


                       SEMANTIC SEARCH
                              |
                              v
                         Embeddings
                              |
                              v
                       Vector Index
                         /       \
                        /         \
                       v           v
                  Clustering     Graph
                      |            |
                      v            v
                   IVF-style      HNSW
                   approaches

---

# 124. The Most Important Mental Model

When deciding which structure to use, first ask:

### Question 1: Do I need to locate an exact record?

Use something like:

    Hash table
    B+ tree
    Trie
    Radix tree

### Question 2: Do I only need to eliminate impossible records?

Use:

    Bloom filter

### Question 3: Do I need ordered/range access?

Use:

    B+ tree

### Question 4: Do I need an in-memory ordered structure?

Consider:

    Skip list

### Question 5: Am I searching for words inside documents?

Use:

    Inverted index

### Question 6: Am I searching by meaning?

Use:

    Embeddings + vector index

### Question 7: Do I need approximate nearest-neighbor search?

Use:

    Vector index
        |
        +---- Clustering / inverted approach
        |
        +---- Graph approach
                  |
                  v
                 HNSW

---

# 125. Final Cheat Sheet

## Filters

    Filter = membership test

    Bloom filter:
        FALSE → definitely absent
        TRUE  → possibly present

    No false negatives.
    False positives are possible.

    Standard Bloom filter:
        INSERT + LOOKUP
        No safe DELETE

    Counting Bloom filter:
        INSERT + LOOKUP + DELETE

---

## Skip Lists

    Multi-level linked list

    Bottom level:
        Every key

    Higher levels:
        Randomly promoted keys

    Search:
        Right when safe
        Down when next key is too large

    Expected:
        O(log n)

    Usually used in memory.

---

## Tries

    Keys are represented one piece at a time.

    Piece can be:
        Bit
        Byte
        Character
        Digit

    Search:
        O(K)

    K = key length

    Layout depends on keys,
    not insertion order.

---

## Radix Trees

    Compressed trie

    Remove unnecessary paths.

    Good for:
        Large keys
        Prefix-heavy keys
        Point lookups

    Less ideal than B+ trees for:
        Range scans

---

## Inverted Index

    Term → Posting List

    Example:

    database → [1, 4, 7, 12]
    index    → [2, 7, 12]
    systems  → [1, 4]

    Used for:
        Full-text search
        Keyword search
        Ranking

---

## Ranking

    TF:
        Term frequency

    BM25:
        More sophisticated relevance ranking
        Includes diminishing returns for repeated terms

---

## Tokenization

    Raw text
       |
       v
    Tokenizer
       |
       v
    Terms
       |
       v
    Inverted Index

    Can support:

    - Normalization
    - Punctuation handling
    - Hyphen handling
    - N-grams
    - Fuzzy matching

---

## Vector Search

    Text
      |
      v
    Transformer
      |
      v
    Embedding
      |
      v
    Vector Index
      |
      v
    Nearest Neighbors

    Used for:

        Semantic similarity
        Approximate nearest-neighbor search
        AI/RAG-style retrieval

---

## Vector Indexes

    Two major approaches:

    1. Clustering / inverted index
           |
           v
        Centroids
           |
           v
        Candidate vectors

    2. Graph
           |
           v
        Neighbor traversal
           |
           v
        HNSW

---

## Index Optimizations

    Partial Index:
        Index only rows satisfying a condition.

    INCLUDE:
        Store additional columns in the index.

    Covering Index:
        Index contains everything needed for query.

    Index-only scan:
        Query can be answered without fetching table tuples.

---

# 126. Final One-Page Memory Summary

| Structure | Main Question | Key Idea | Important Property |
|---|---|---|---|
| Bloom Filter | Could it exist? | Bitmap + hashes | False positives, no false negatives |
| Counting Bloom | Could it exist + delete? | Counters | Supports deletion |
| Cuckoo Filter | Could it exist + delete? | Fingerprints | Compact membership |
| Skip List | Where is this ordered key? | Layered linked list | Expected O(log n) |
| B+ Tree | Where/range is this key? | Balanced tree | Excellent range scans |
| Trie | Does this key exist? | Key represented by path | O(K) |
| Radix Tree | Same, but compressed | Compressed trie | Good for large keys |
| Inverted Index | Which records contain this word? | Term → posting list | Full-text search |
| FST | Where is this term in dictionary? | Weighted trie-like structure | Compact dictionary |
| Vector Index | What is semantically similar? | Embedding similarity | Approximate search |
| HNSW | What vectors are nearest? | Hierarchical graph | Fast ANN search |
| Partial Index | Which rows need indexing? | Conditional index | Smaller index |
| Covering Index | Can query be answered from index? | Include needed columns | Avoid table lookup |

## The Core Idea Behind the Entire Lecture

The database should avoid doing this whenever possible:

    Query
      |
      v
    Scan 1,000,000,000 tuples
      |
      v
    Find matching data

Instead, it builds specialized data structures that reduce the search space:

    Query
      |
      v
    Specialized Data Structure
      |
      v
    Small Candidate Set
      |
      v
    Matching Records

Different structures optimize different kinds of searches:

    Exact key
        → Hash / B+ Tree / Trie / Radix Tree

    Range
        → B+ Tree

    Membership pre-check
        → Bloom Filter

    In-memory ordered data
        → Skip List

    Keyword search
        → Inverted Index

    Semantic search
        → Vector Index

    Approximate nearest neighbors
        → HNSW / Clustering

The overall goal is the same:

    AVOID EXPENSIVE SEQUENTIAL SCANS.