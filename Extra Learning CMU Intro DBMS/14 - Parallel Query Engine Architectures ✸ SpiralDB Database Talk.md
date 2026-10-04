# Parallel Query Execution and Database System Architecture

## 1. Why Parallel Query Execution Matters

### Definition

**Parallel query execution** is the process of using multiple computational resources—such as CPU cores, threads, processes, memory regions, or storage devices—to execute database work simultaneously.

Instead of having one worker perform all of the work:

```text
Query
  ↓
One worker
  ↓
All computation
  ↓
Result
```

the database can divide the work:

```text
                    Query
                      ↓
             ┌────────┼────────┐
             ↓        ↓        ↓
          Worker 1  Worker 2  Worker 3
             ↓        ↓        ↓
             └────────┼────────┘
                      ↓
                   Result
```

### Explanation

Modern machines have many CPU cores and often multiple storage devices. A database system needs to take advantage of those resources.

Parallelism can improve:

* Query performance
* CPU utilization
* Storage bandwidth
* Throughput
* Ability to process large datasets
* Fault tolerance when data is replicated

The important idea is that **SQL remains declarative**.

A user writes:

```sql
SELECT name
FROM Students
WHERE gpa > 3.0;
```

The user does not specify:

```text
Use CPU 1
Read disk 2
Send these rows to worker 4
Join these partitions
```

Instead, the database determines the physical execution strategy.

### Key Point

The same logical SQL query can theoretically run on:

* One CPU core
* Multiple CPU cores
* Multiple disks
* Multiple machines
* A distributed database system

without requiring the application to rewrite the SQL.

---

# 2. Parallel Databases vs. Distributed Databases

## Definition: Parallel Database

A **parallel database** uses multiple computational or storage resources that are physically close together.

For this lecture, assume:

```text
                Single Machine
        ┌─────────────────────────┐
        │ CPU  CPU  CPU  CPU      │
        │  │    │    │    │       │
        │ Disk Disk Disk Disk     │
        └─────────────────────────┘
```

Communication between resources is assumed to be:

* Fast
* Reliable
* Relatively inexpensive

## Definition: Distributed Database

A **distributed database** has resources that may be physically far apart.

For example:

```text
Data Center A       Data Center B       Data Center C
     │                   │                   │
   Node 1              Node 2              Node 3
```

Communication may have:

* Higher latency
* Network failures
* Message loss
* Variable performance
* Greater coordination costs

### Important Comparison

| Concept             | Parallel Database               | Distributed Database      |
| ------------------- | ------------------------------- | ------------------------- |
| Physical location   | Usually close together          | Potentially far apart     |
| Communication       | Fast/reliable                   | Slower/less predictable   |
| Failure assumptions | Simpler                         | Must account for failures |
| Main goal           | Use local resources efficiently | Scale across machines     |
| Lecture focus       | Today's topic                   | Later in semester         |

### Important Idea

The techniques learned for parallel execution on one machine become useful later when the database scales across multiple machines.

---

# 3. Query Plans and Operators

### Definition

A **query plan** is the sequence/tree of physical operations that the database uses to execute a SQL query.

For example:

```text
        Projection
            ↓
           Join
         /     \
      Filter   Filter
        ↓        ↓
      Table A  Table B
```

Each operator implements a common interface/API.

A common execution model is a `GetNext()`-style interface where operators request tuples from their children.

### Why a Common API Matters

Because operators follow the same general interface, they can be composed:

```text
Operator A
    ↓
Operator B
    ↓
Operator C
    ↓
Result
```

The database can change the physical arrangement of operators without changing the SQL query itself.

### Important Warning

Changing operator order does **not automatically preserve correctness**.

Some operations can be reordered safely, while others cannot.

The database optimizer must determine which transformations are valid.

---

# 4. Process Models

### Definition

A **process model** describes how a database creates and manages the workers that execute database operations.

A **worker** is a computational unit capable of executing database tasks.

Workers can perform:

* Query execution
* Background maintenance
* Compaction
* Other database tasks

For this lecture, workers primarily execute queries.

---

# 5. Process Per Worker

### Definition

In the **process-per-worker** model, every worker is a separate operating-system process.

```text
Database
   │
   ├── Process / Worker 1
   ├── Process / Worker 2
   ├── Process / Worker 3
   └── Process / Worker 4
```

Each process has its own:

* Address space
* Memory
* Code
* OS-managed execution state

### Example: PostgreSQL

PostgreSQL historically uses the process-based architecture.

A front-end dispatcher receives connections and assigns work to database processes.

Conceptually:

```text
Application
     ↓
Dispatcher
     ↓
Process Pool
 ┌───┼───┬───┐
 ↓   ↓   ↓   ↓
 W1  W2  W3  W4
```

### Communication

Because workers are separate processes, communication requires mechanisms such as:

* Shared memory
* Pipes
* Signals
* Other inter-process communication mechanisms

### Why Was This Historically Popular?

Older database systems were designed when threading APIs were less standardized across operating systems.

Using OS processes provided a more portable abstraction.

---

# 6. Thread Per Worker

### Definition

In the **thread-per-worker** model, one database process contains multiple worker threads.

```text
              One Process
        ┌─────────────────────┐
        │                     │
        │ Thread 1            │
        │ Thread 2            │
        │ Thread 3            │
        │ Thread 4            │
        │                     │
        └─────────────────────┘
```

All threads share the same process address space.

### Advantages

Threads generally have lower overhead than processes.

Workers can communicate through shared memory directly.

This makes it easier to:

* Share data
* Communicate
* Coordinate work
* Build thread pools

### Disadvantage

Because threads share the same process, a serious failure in one thread can crash the entire process.

```text
Thread 2
   ↓
Segmentation fault
   ↓
Process crashes
   ↓
All threads terminate
```

With separate processes:

```text
Worker 2 crashes
     ↓
Other workers continue
     ↓
Dispatcher can create replacement
```

### Why Modern Systems Prefer Threads

Modern systems generally favor threads because:

* Threading APIs are standardized
* CPUs have many cores
* Threads have lower overhead
* Shared memory makes communication easier
* Managing many processes is more expensive

---

# 7. Embedded Database Systems

### Definition

An **embedded database system** does not necessarily create and manage its own workers.

Instead, the application provides the computational context.

Examples discussed include:

* SQLite
* DuckDB
* Berkeley DB
* LevelDB
* RocksDB

### Example

A normal database server:

```text
Application
     ↓
Database Server
     ↓
Database Workers
```

An embedded database:

```text
Application
     │
     ├── Application Thread
     │
     └── Embedded Database Library
              ↓
          Database Work
```

The database is effectively a library inside the application.

### SQLite Example

An application may call SQLite:

```text
Web application
      ↓
Application thread
      ↓
SQLite library
      ↓
Read/write database
      ↓
Return result
```

SQLite itself does not need to maintain a traditional database-server worker pool.

---

# 8. Process Model Comparison

| Model              | Worker Type                 | Communication          | Main Advantage            | Main Disadvantage            |
| ------------------ | --------------------------- | ---------------------- | ------------------------- | ---------------------------- |
| Process per worker | OS process                  | IPC/shared memory      | Isolation/fault tolerance | Higher overhead              |
| Thread per worker  | Thread                      | Shared memory          | Efficient communication   | One crash can affect process |
| Embedded           | Application-provided worker | Function/library calls | Simple integration        | Application controls workers |

### Exam Tip

Remember:

```text
Process = separate address spaces
Thread  = shared address space
Embedded = application provides execution context
```

---

# 9. Database Scheduling

### Definition

**Scheduling** determines:

1. Which worker performs a task
2. When the task runs
3. How many workers should be assigned
4. Which resources should be used

The database knows information that the operating system does not necessarily know, such as:

* Query structure
* Data location
* Query dependencies
* Available workers
* Number of concurrent queries
* Disk performance
* Degree of parallelism

Therefore, a sophisticated database can make better scheduling decisions.

### Degree of Parallelism

The **degree of parallelism** is the number of workers assigned to execute some work.

Example:

```text
Degree = 1

Query
 ↓
Worker 1
```

versus:

```text
Degree = 4

        Query
          ↓
 ┌────────┼────────┐
 ↓        ↓        ↓        ↓
 W1       W2       W3       W4
```

### Important Trade-Off

More workers do not always mean better performance.

More workers can introduce:

* Communication overhead
* Coordination overhead
* Memory consumption
* Scheduling overhead
* Contention for resources

---

# 10. Interquery Parallelism

### Definition

**Interquery parallelism** means executing multiple different queries at the same time.

Example:

```text
Worker 1 → Query A
Worker 2 → Query B
Worker 3 → Query C
Worker 4 → Query D
```

The queries may not need to communicate with one another.

### Example

Suppose three users submit:

```sql
SELECT * FROM Students;
```

```sql
SELECT * FROM Courses;
```

```sql
SELECT * FROM Enrollments;
```

The database can execute them concurrently.

### Scheduling

A simple scheduling strategy is:

**First Come, First Serve (FCFS)**

The query that arrives first gets scheduled first.

More sophisticated systems may consider:

* Transaction priority
* Amount of previous work
* Resource availability
* Query cost

### Read-Only Queries

Read-only workloads are relatively easy to parallelize because queries do not modify shared data.

Updates introduce additional coordination problems.

---

# 11. Intraquery Parallelism

### Definition

**Intraquery parallelism** means using multiple workers to execute **one query**.

Example:

```text
One Query
   ↓
 ┌─┼─┐
 ↓ ↓ ↓
W1 W2 W3
```

This is different from interquery parallelism.

### Example

Suppose:

```sql
SELECT *
FROM Students
WHERE gpa > 3.0;
```

Instead of one worker scanning the entire table:

```text
Worker 1
 ↓
Entire table
```

the database can divide the table:

```text
Worker 1 → Pages 1–100
Worker 2 → Pages 101–200
Worker 3 → Pages 201–300
```

---

# 12. Interquery vs. Intraquery Parallelism

| Concept       | Interquery             | Intraquery              |
| ------------- | ---------------------- | ----------------------- |
| Parallelizes  | Different queries      | One query               |
| Example       | W1 runs Q1, W2 runs Q2 | W1/W2/W3 run Q1         |
| Goal          | Higher throughput      | Faster individual query |
| Communication | Often minimal          | Often required          |
| Complexity    | Lower                  | Higher                  |

### Important Point

These are **not mutually exclusive**.

A database can do both:

```text
Query A → Worker 1 + Worker 2
Query B → Worker 3 + Worker 4
```

PostgreSQL can support both forms.

---

# 13. Producer-Consumer Model

Parallel query execution often follows a **producer-consumer** model.

One operator produces tuples:

```text
Producer
   ↓
Tuples
   ↓
Consumer
```

Multiple workers can participate:

```text
Producer W1 ──┐
Producer W2 ──┼──> Consumer
Producer W3 ──┘
```

The exact structure depends on where the database introduces parallelism.

---

# 14. Intraoperator Parallelism

### Definition

**Intraoperator parallelism** means multiple workers execute the same operator or pipeline, but each worker handles a different portion of the data.

It is also called **horizontal parallelism**.

```text
             Same operator
                  │
       ┌──────────┼──────────┐
       ↓          ↓          ↓
     Worker 1   Worker 2   Worker 3
       ↓          ↓          ↓
    Data A      Data B      Data C
```

### Example

Suppose table `A` is divided into three disjoint subsets:

```text
A
├── A1
├── A2
└── A3
```

Then:

```text
Worker 1 → A1
Worker 2 → A2
Worker 3 → A3
```

Each worker can independently perform:

```text
Scan
 ↓
Filter
 ↓
Join preparation
```

---

# 15. Partitioning Data for Parallelism

The database can divide data using different strategies.

Possible approaches include:

* Page ranges
* File ranges
* Value ranges
* Hash partitioning
* Other physical partitions

The important requirement is that the workers can operate on independent portions of the data.

### Example

```text
Table A

┌────────┬────────┬────────┐
│ A1     │ A2     │ A3     │
└────────┴────────┴────────┘
   ↓        ↓        ↓
  W1       W2       W3
```

---

# 16. Exchange Operators

### Definition

An **exchange operator** is an implementation-level operator used to coordinate and redistribute data between parallel workers.

It is not a relational algebra operator.

Its purpose is to allow the database execution engine to introduce parallelism.

### Main Functions

An exchange can:

* Gather results
* Distribute results
* Repartition results
* Coordinate workers
* Create synchronization points

---

# 17. Gather Exchange

### Definition

A **gather** combines multiple worker outputs into one output stream.

```text
Worker 1 ──┐
Worker 2 ──┼──> Gather ──> One stream
Worker 3 ──┘
```

This is useful when several workers have independently processed data and the query plan needs one stream going forward.

### Example

```text
A1 → Filter → W1 ──┐
A2 → Filter → W2 ──┼──> Gather → Next Operator
A3 → Filter → W3 ──┘
```

---

# 18. Blocking Exchange / Barrier

### Definition

A **barrier** prevents the next stage from proceeding until required work has completed.

```text
Worker 1 ──┐
Worker 2 ──┼──> BARRIER ──> Next Stage
Worker 3 ──┘
```

### Why Is a Barrier Sometimes Necessary?

Consider a parallel hash join.

First, workers build a hash table from table A:

```text
A1 → Worker 1 ──┐
A2 → Worker 2 ──┼──> Hash Table
A3 → Worker 3 ──┘
```

Only after all workers finish building the hash table should workers begin probing it with table B.

Otherwise:

```text
Worker B
   ↓
Probe hash table
   ↓
"No match"
```

could occur before another worker has inserted the matching tuple.

That would produce an incorrect result.

### Important Idea

A barrier is needed when the next stage depends on **all results from the previous stage**.

---

# 19. Non-Blocking Exchange

A barrier is not always necessary.

If results can be processed as they arrive:

```text
Worker 1 ──→ Result ──→ Consumer
Worker 2 ──→ Result ──→ Consumer
Worker 3 ──→ Result ──→ Consumer
```

the consumer may begin immediately.

This enables more pipeline parallelism.

### Rule

Use a blocking exchange when:

```text
Next stage requires ALL previous results.
```

Use streaming/non-blocking behavior when:

```text
Next stage can process results as they arrive.
```

---

# 20. Distribute Exchange

### Definition

A **distribute** exchange takes one input stream and distributes it among multiple workers.

```text
                 Input
                   ↓
              Distribute
             /     |     \
            ↓      ↓      ↓
           W1     W2     W3
```

This is useful when a single producer needs to feed multiple workers.

---

# 21. Repartition Exchange

### Definition

A **repartition** exchange takes multiple input streams and redistributes them into multiple output streams.

```text
W1 ──┐
W2 ──┼──> Repartition ──┬──> W4
W3 ──┘                  └──> W5
```

The number of inputs and outputs does not have to be the same.

### Example

Suppose:

```text
3 workers below
```

produce data, but only:

```text
2 workers
```

are needed above.

The exchange can coalesce:

```text
3 input streams → 2 output streams
```

### Important Trade-Off

More parallelism can improve computation but increase communication costs.

Therefore:

```text
More workers
     ↓
More parallelism
     ↓
Potentially more communication
```

The database must balance these costs.

---

# 22. Exchange Operator Summary

| Exchange    |    Input |   Output | Purpose                    |
| ----------- | -------: | -------: | -------------------------- |
| Gather      | Multiple |      One | Combine results            |
| Distribute  |      One | Multiple | Split one stream           |
| Repartition | Multiple | Multiple | Redistribute/coalesce data |

---

# 23. Interoperator Parallelism

### Definition

**Interoperator parallelism** means different operators in a query plan execute simultaneously.

It is also called **vertical parallelism**.

Instead of:

```text
Join
 ↓
Projection
```

waiting for the entire join to finish, the projection may begin processing tuples as soon as the join produces them.

```text
Join Worker
     ↓
tuples
     ↓
Projection Worker
     ↓
results
```

### Benefit

This can reduce waiting and avoid materializing intermediate results.

### Cost

Workers must communicate.

```text
Join
 ↓
Copy/send tuples
 ↓
Projection
```

Communication and copying are not free.

---

# 24. Streaming Execution

Interoperator parallelism is particularly useful in **streaming systems**.

A traditional query often works on a finite dataset:

```text
Input
 ↓
Process everything
 ↓
Final result
```

A streaming system may receive data continuously:

```text
Data → Data → Data → Data → Data → ...
```

The query may run continuously.

### Example

Suppose a system continuously monitors stock prices.

If:

```text
stock price > $100
```

the system could immediately produce an output instead of waiting for the entire dataset.

### Key Point

Streaming systems benefit from operators that can process data incrementally as it arrives.

---

# 25. Example: Parallel Join + Expensive UDF

Suppose a query performs:

```text
Join
 ↓
Expensive Function
```

The expensive function could run on a separate worker.

```text
Worker 1
Join
 ↓
Tuples
 ↓
Worker 2
Expensive UDF
 ↓
Output
```

Instead of waiting for the entire join to finish, Worker 2 can process tuples as they arrive.

### Trade-Off

**Benefit:**

* More parallelism
* Better resource utilization

**Cost:**

* Communication
* Data copying
* Synchronization

Sometimes it is faster to fuse the operators into one loop rather than split them apart.

---

# 26. Bushy Parallelism

### Definition

**Bushy parallelism** combines:

* Intraoperator/horizontal parallelism
* Interoperator/vertical parallelism

```text
        Operator C
        /        \
     Worker     Worker
       ↓          ↓
   Operator A  Operator B
```

Different portions of the query plan can execute simultaneously while each portion may itself use multiple workers.

### Important Clarification

Bushy parallelism is not necessarily a separate fundamental type of parallelism.

It is essentially a combination of horizontal and vertical parallelism.

---

# 27. Bushy Query Plans vs. Left-Deep Query Plans

A **bushy join plan** can join separate branches independently.

Example:

```text
      Final Join
       /      \
     Join     Join
    /   \     /   \
   A     B   C     D
```

A **left-deep join plan** is more like:

```text
(((A JOIN B) JOIN C) JOIN D)
```

### Why Left-Deep Plans Are Common

The number of possible join orders grows very quickly as the number of tables increases.

Searching every possible bushy plan can be computationally expensive.

Therefore, many optimizers restrict the search space.

### Important

The best plan depends on:

* Data size
* Selectivity
* Join conditions
* Available indexes
* Statistics
* Memory
* Hardware

There is no universally optimal join tree.

---

# 28. I/O Parallelism

### Definition

**I/O parallelism** uses multiple storage devices to increase available storage bandwidth.

Even if there are many CPU workers, the query may still be limited by storage.

```text
CPU Workers
    ↓
Need data
    ↓
       Disk
        ↓
      Bottleneck
```

Instead:

```text
             Query
               ↓
      ┌────────┼────────┐
      ↓        ↓        ↓
    Disk 1   Disk 2   Disk 3
```

multiple workers can access different devices concurrently.

---

# 29. Ways to Organize Data Across Disks

A database can distribute physical data in several ways:

* Multiple databases per disk
* One table per disk
* Parts of one table across disks
* Log on one disk and table data on another
* Partitioned data across disks

High-end database systems may provide detailed control over these layouts.

---

# 30. RAID and Storage Parallelism

RAID stands for:

**Redundant Array of Independent Disks**

The lecture focused on two extremes:

* RAID 0: striping
* RAID 1: mirroring

---

# 31. RAID 0 — Striping

### Definition

**Striping** spreads data across multiple disks.

Suppose there are three disks:

```text
Page 1 → Disk 1
Page 2 → Disk 2
Page 3 → Disk 3
Page 4 → Disk 1
Page 5 → Disk 2
Page 6 → Disk 3
```

### Advantage

Excellent parallelism.

Different workers can access different disks:

```text
Worker 1 → Disk 1
Worker 2 → Disk 2
Worker 3 → Disk 3
```

### Major Disadvantage

There is no redundancy.

If Disk 2 fails:

```text
Disk 2 lost
   ↓
Pages stored there lost
   ↓
Part of database unavailable/lost
```

### Memory Trick

```text
RAID 0 = Speed
```

Think:

> Zero redundancy.

---

# 32. RAID 1 — Mirroring

### Definition

**Mirroring** stores a complete copy of the data on multiple disks.

```text
Original page
   ├──> Disk 1
   ├──> Disk 2
   └──> Disk 3
```

### Advantage

Excellent redundancy.

If one disk fails:

```text
Disk 1 fails
    ↓
Disk 2 still has the data
    ↓
Database can continue
```

Reads can also be distributed among disks.

### Disadvantage

Writes are more expensive.

A write must be performed on all copies.

Conceptually:

```text
Write
 ↓
Disk 1
Disk 2
Disk 3
 ↓
Wait for successful persistence
 ↓
Report success
```

### Memory Trick

```text
RAID 1 = One complete copy mirrored
```

---

# 33. RAID 0 vs. RAID 1

| Feature            | RAID 0           | RAID 1                |
| ------------------ | ---------------- | --------------------- |
| Main idea          | Striping         | Mirroring             |
| Performance        | High parallelism | Good read parallelism |
| Write cost         | Lower            | Higher                |
| Redundancy         | None             | High                  |
| Storage efficiency | High             | Lower                 |
| Failure tolerance  | Poor             | Good                  |

### Important Trade-Off

Database storage design balances:

```text
Performance
     ↕
Durability
     ↕
Capacity
```

You generally cannot maximize everything simultaneously without additional cost.

---

# 34. Hardware vs. Software Storage Management

### Hardware Approach

A storage controller can hide the physical layout from the database.

The database sees:

```text
One logical disk
```

while the controller manages:

```text
Disk 1
Disk 2
Disk 3
```

### Software Approach

The database itself understands the physical layout.

This gives it more control over:

* Where data is stored
* Which disk contains what
* How data is replicated
* How failures are handled
* How I/O is scheduled

High-end systems may use sophisticated software-level storage management.

---

# 35. Partitioning

### Definition

**Partitioning** divides a logical table or dataset into disjoint subsets.

```text
Logical Table
      ↓
 ┌────┼────┐
 ↓    ↓    ↓
 P1   P2   P3
```

The database can then route those partitions to different:

* Workers
* Disks
* Machines

### Partitioning Strategies

The lecture referenced:

* Page-based partitioning
* Range partitioning
* Hash partitioning

### Why Partition?

Partitioning enables:

* Parallel execution
* Parallel storage
* Better data locality
* Reduced coordination
* Distribution across resources

---

# 36. Horizontal vs. Vertical Partitioning

The lecture connects partitioning to the earlier discussion of row stores and column stores.

### Horizontal Partitioning

Split rows:

```text
Table
├── Rows 1–100
├── Rows 101–200
└── Rows 201–300
```

### Vertical Partitioning

Split columns:

```text
Table
├── Student ID
├── Name
├── GPA
└── Major
```

A column store effectively stores columns separately.

```text
Column A → Storage
Column B → Storage
Column C → Storage
```

### Important Comparison

| Partitioning | Splits             |
| ------------ | ------------------ |
| Horizontal   | Rows/tuples        |
| Vertical     | Columns/attributes |

---

# 37. Logical vs. Physical Database Design

A major theme of the lecture is **abstraction**.

The application sees:

```text
Logical Table
```

The database may physically store it as:

```text
        Table
          ↓
 ┌────────┼─────────┐
 ↓        ↓         ↓
Disk 1   Disk 2    Disk 3
```

The application still uses:

```sql
SELECT *
FROM Students;
```

It does not need to know:

* Which disk contains the rows
* Which worker processes them
* How partitions are organized
* Whether the query uses multiple CPU cores

This is one of the major benefits of declarative SQL.

---

# 38. Why Parallelism Is Important

Modern hardware provides enormous computational resources.

Compared with older systems, modern devices have:

* More CPU cores
* More threads
* Faster storage
* More memory
* GPUs
* High-bandwidth networks
* Specialized accelerators

A database that uses only one worker cannot take full advantage of modern hardware.

Parallel execution allows the database to:

```text
Use more CPU
     +
Use more memory
     +
Use more storage devices
     +
Use more bandwidth
     ↓
Better overall performance
```

---

# 39. Parallelism Can Hide Latency

Suppose Worker 1 waits for disk I/O:

```text
Worker 1 → waiting for disk
```

Other workers can continue:

```text
Worker 1 → WAIT
Worker 2 → COMPUTE
Worker 3 → COMPUTE
Worker 4 → COMPUTE
```

Therefore, parallelism can keep the machine busy while another worker waits.

This concept also becomes important when dealing with:

* Network latency
* Storage latency
* Concurrent queries
* Transactions

---

# 40. Parallel Execution and Transactions

Parallel workers also give the database more control over concurrent operations.

For example:

```text
Query A wants to modify X
Query B wants to modify X
```

The database can coordinate the workers so that operations occur in a safe order.

Transaction processing and concurrency control are covered separately later, but the important idea is:

> Multiple workers allow the database system to control concurrent work rather than simply letting the operating system schedule everything without understanding database dependencies.

---

# 41. Historical Evolution of Hardware

The guest speaker explained how database architecture has been influenced by hardware changes.

### Around 2005

Dennard scaling largely ended.

CPU clock speeds stopped increasing as dramatically.

Instead of:

```text
One core
   ↓
Much faster
```

hardware shifted toward:

```text
Many cores
   ↓
Parallel computation
```

### Consequence for Databases

Database systems had to become better at:

* Parallelism
* Multiple CPUs
* Distributed computation
* Large-scale data processing

---

# 42. Resource Hierarchy Has Changed

Historically, systems often thought of resources roughly as:

```text
RAM
 ↓
Disk
 ↓
Network
```

where each level had significant differences in speed.

Modern hardware is more heterogeneous.

The lecture highlighted:

* GPUs
* NVMe
* Object storage
* High-bandwidth networks
* Multicloud systems

### Important Clarification

Latency and bandwidth are not the same thing.

A resource may have higher latency but extremely high throughput.

Therefore, modern database systems must optimize for both:

* Latency
* Bandwidth/throughput

---

# 43. Machine-Scale Data

Traditional applications often have:

```text
Small input
   ↓
Small output
```

For example:

```text
Look up user profile
Update email
```

This resembles a typical transactional application database.

Modern analytical and AI workloads can look more like:

```text
Huge input
   ↓
Massive processing
   ↓
Huge output
```

The guest speaker referred to this as a **machine consumer** era.

For example, GPUs may consume data at extremely high throughput.

---

# 44. Row-Oriented vs. Column-Oriented Systems

### Row Store

A row store keeps the attributes of a tuple together.

```text
Row 1: ID | Name | GPA | Major
Row 2: ID | Name | GPA | Major
Row 3: ID | Name | GPA | Major
```

This is useful for many application/transactional workloads.

### Column Store

A column store stores values from the same column together.

```text
IDs:     1  2  3
Names:   A  B  C
GPA:     3  4  3
Major:  CS EE CS
```

This can be beneficial for analytical workloads that read only selected columns.

---

# 45. Spiral DB and Vortex

The guest speaker introduced **Spiral** and **Vortex** as examples of modern database/file-format engineering.

### Vortex

Vortex is a **file format**.

Its job is primarily:

> How should data be represented and stored as bytes?

### Spiral DB

Spiral DB is a **database product/system built around Vortex**.

It includes additional database functionality such as:

* Transactions
* Indexes
* Query planning
* Database orchestration

### Important Comparison

| Vortex                         | Spiral DB                       |
| ------------------------------ | ------------------------------- |
| File format                    | Database system/product         |
| Stores data                    | Uses Vortex to store data       |
| Open-source project            | Hosted/database product         |
| Focuses on data representation | Includes database functionality |

---

# 46. Why File Formats Matter

A file format controls how data is physically represented.

This affects:

* Scan speed
* Random access
* Compression
* Storage size
* Query performance
* GPU/CPU processing
* Data transfer

The guest speaker discussed Vortex as a format designed for high-throughput workloads.

### Important Lecture Point

The exact benchmark numbers presented for Vortex were **vendor/guest-speaker claims and examples**, not universal database performance laws.

Do not memorize them as guaranteed performance results.

Instead, understand the architectural lesson:

> File format design can have a major effect on database execution performance.

---

# 47. Object Storage and GPU Workloads

Modern systems may use object storage such as S3.

The guest speaker emphasized that object storage can provide very high aggregate throughput.

A modern pipeline may look like:

```text
Object Storage
      ↓
Network
      ↓
CPU / GPU
      ↓
Machine Learning Workload
```

The challenge is keeping the GPU fed with enough data.

If the GPU consumes data faster than the database can provide it, the GPU becomes underutilized.

---

# 48. Query Execution on GPUs

The guest speaker emphasized that many database concepts remain the same across hardware.

The high-level concepts still include:

* Operators
* Pipelines
* Query plans
* Data dependencies
* Pipeline breakers
* Vectorized execution

What changes is the hardware implementation.

```text
Same query concepts
        ↓
Different hardware
        ↓
Different implementation
```

Possible hardware includes:

* CPU
* GPU
* FPGA
* Future accelerators

---

# 49. GPU-Specific Constraints

One challenge when designing execution for GPUs is that GPUs benefit from predictable execution and known output sizes.

The guest speaker explained that GPU execution can impose additional constraints around:

* Known output size
* Data dependencies
* Pipeline structure
* Operator execution

This can influence how query operators are designed.

### Key Idea

The database concepts do not disappear when moving to a GPU.

Instead, the hardware constraints change the optimal implementation.

---

# 50. General Architecture Principle

A major takeaway from the guest lecture is:

> Database ideas often remain conceptually stable while hardware changes the optimal implementation.

For example:

```text
Operators
Pipelines
Indexes
Query Plans
Partitioning
Parallelism
```

can exist across different hardware architectures.

What changes is:

```text
How they are implemented
How data moves
How much parallelism is available
What the bottlenecks are
```

---

# 51. Query Execution vs. Query Optimization

This lecture focused on **how a physical query plan can be executed in parallel**.

The next topic is **query optimization**.

The optimizer must determine:

* Which tables to join first
* Which join algorithm to use
* Which indexes to use
* How to arrange operators
* How many workers to use
* What physical plan is likely to be cheapest

Example:

```text
Option A:
((A JOIN B) JOIN C) JOIN D
```

versus:

```text
Option B:

       JOIN
      /    \
   A JOIN B C JOIN D
```

The optimizer must determine which is better.

---

# 52. Why Query Optimization Is Difficult

The optimizer must make decisions **before executing the query**.

But it cannot know the exact execution behavior until the query actually runs.

Therefore, it uses:

* Statistics
* Cardinality estimates
* Data distributions
* Cost models

These estimates can be wrong.

### Core Problem

```text
Need plan
   ↓
Before execution
   ↓
But exact runtime behavior is unknown
   ↓
Must estimate
```

This is why query optimization is difficult.

---

# Important Comparisons

## Process vs. Thread

| Concept             | Process        | Thread      |
| ------------------- | -------------- | ----------- |
| Address space       | Separate       | Shared      |
| Communication       | More expensive | Easier      |
| Creation/management | Heavier        | Lighter     |
| Fault isolation     | Better         | Worse       |
| Modern database use | Less common    | More common |

---

## Interquery vs. Intraquery

| Concept    | Meaning                                  | Example          |
| ---------- | ---------------------------------------- | ---------------- |
| Interquery | Different queries execute simultaneously | W1 → Q1, W2 → Q2 |
| Intraquery | One query uses multiple workers          | W1/W2/W3 → Q1    |

---

## Intraoperator vs. Interoperator

| Concept       | Also called | Meaning                                            |
| ------------- | ----------- | -------------------------------------------------- |
| Intraoperator | Horizontal  | Same operator processes different data in parallel |
| Interoperator | Vertical    | Different operators execute simultaneously         |

---

## Horizontal vs. Vertical Parallelism

```text
Horizontal:

Operator
 ├── Worker 1
 ├── Worker 2
 └── Worker 3
```

```text
Vertical:

Operator A
    ↓
Operator B
    ↓
Operator C
```

Horizontal = multiple workers on the same stage.

Vertical = multiple stages operating simultaneously.

---

## Gather vs. Distribute vs. Repartition

| Exchange    | Direction   | Purpose           |
| ----------- | ----------- | ----------------- |
| Gather      | Many → One  | Combine streams   |
| Distribute  | One → Many  | Split a stream    |
| Repartition | Many → Many | Redistribute data |

---

## RAID 0 vs. RAID 1

| RAID 0                  | RAID 1                    |
| ----------------------- | ------------------------- |
| Striping                | Mirroring                 |
| Performance             | Redundancy                |
| No redundancy           | High redundancy           |
| Data split across disks | Data copied across disks  |
| Failure can lose data   | Can tolerate disk failure |

---

## Parallel vs. Distributed

| Parallel                       | Distributed                               |
| ------------------------------ | ----------------------------------------- |
| Resources physically close     | Resources may be geographically separated |
| Fast communication             | Network communication                     |
| Simplified failure assumptions | Must handle failures                      |
| Usually one machine            | Multiple machines                         |

---

## Row Store vs. Column Store

| Row Store                             | Column Store              |
| ------------------------------------- | ------------------------- |
| Stores complete tuples together       | Stores columns together   |
| Good for many row-oriented operations | Good for analytical scans |
| Often useful for OLTP                 | Often useful for OLAP     |

---

## Vortex vs. Spiral DB

| Vortex                      | Spiral DB                       |
| --------------------------- | ------------------------------- |
| File format                 | Database system                 |
| Defines data representation | Provides database functionality |
| Open-source project         | Built using Vortex              |

---

# Common Mistakes

* Assuming parallelism means every query automatically uses every CPU core.
* Confusing **interquery** parallelism with **intraquery** parallelism.
* Assuming a database using threads cannot also run multiple queries.
* Assuming more workers always means better performance.
* Forgetting communication costs between workers.
* Forgetting that synchronization can create barriers.
* Assuming every exchange operator must be blocking.
* Confusing gather, distribute, and repartition.
* Thinking horizontal parallelism and vertical parallelism are the same thing.
* Assuming bushy parallelism is completely separate from the other forms.
* Assuming RAID 0 provides redundancy.
* Assuming RAID 1 improves write performance.
* Forgetting that RAID 1 requires additional storage capacity.
* Assuming CPU parallelism solves an I/O bottleneck.
* Forgetting that storage bandwidth can limit query performance.
* Assuming partitioning requires application changes.
* Confusing horizontal partitioning with vertical partitioning.
* Assuming a parallel database must be distributed across multiple machines.
* Assuming SQL needs to specify which worker or disk should process each row.
* Assuming the operating system understands database-specific scheduling decisions.
* Assuming a query optimizer knows the exact runtime behavior before executing a query.
* Treating benchmark numbers from one system as universal performance guarantees.
* Confusing Vortex, a file format, with Spiral DB, a database system.
* Assuming GPU execution requires completely different database concepts.
* Forgetting that hardware changes can change which implementation is optimal.

---

# Exam Review

## Must-Know Definitions

* **Parallel query execution** — executing database work using multiple computational or storage resources.
* **Parallel database** — database system using multiple nearby resources to execute work concurrently.
* **Distributed database** — database system whose resources may be physically separated across machines or locations.
* **Worker** — computational unit that executes database tasks.
* **Process-per-worker** — each worker is a separate OS process.
* **Thread-per-worker** — workers are threads within one process.
* **Embedded database** — database functionality integrated into an application rather than operating as a separate database server.
* **Interquery parallelism** — executing multiple different queries simultaneously.
* **Intraquery parallelism** — executing one query using multiple workers.
* **Intraoperator parallelism** — multiple workers execute the same operator on different data subsets.
* **Interoperator parallelism** — different operators execute simultaneously.
* **Horizontal parallelism** — another term for intraoperator parallelism.
* **Vertical parallelism** — another term for interoperator parallelism.
* **Bushy parallelism** — combination of horizontal and vertical parallelism.
* **Exchange operator** — implementation operator used to coordinate and redistribute work between parallel workers.
* **Gather** — combines multiple streams into one.
* **Distribute** — splits one input stream among multiple workers.
* **Repartition** — redistributes multiple input streams into multiple output streams.
* **Barrier** — synchronization point requiring required previous work to finish before proceeding.
* **Partitioning** — dividing a logical dataset into disjoint subsets.
* **Horizontal partitioning** — partitioning rows.
* **Vertical partitioning** — partitioning columns.
* **RAID 0** — disk striping without redundancy.
* **RAID 1** — disk mirroring with redundancy.
* **I/O parallelism** — using multiple storage devices concurrently.
* **Row store** — storage organization where tuple attributes are stored together.
* **Column store** — storage organization where values from the same column are stored together.
* **Vortex** — file format introduced by the guest speaker.
* **Spiral DB** — database system/product built around Vortex.
* **Query optimization** — selecting an efficient physical execution plan for a SQL query.
* **Degree of parallelism** — number of workers assigned to a piece of work.

---

# Must-Know Methods

## 1. Determine the Type of Parallelism

Ask:

### Are multiple different queries running?

```text
Q1 → Worker 1
Q2 → Worker 2
```

Answer:

**Interquery parallelism**

### Is one query split across workers?

```text
Q1
├── Worker 1
├── Worker 2
└── Worker 3
```

Answer:

**Intraquery parallelism**

### Are workers executing the same operator on different data?

Answer:

**Intraoperator / horizontal parallelism**

### Are different operators executing simultaneously?

Answer:

**Interoperator / vertical parallelism**

### Are both happening?

Answer:

**Bushy parallelism**

---

## 2. Determine Whether an Exchange Should Block

Ask:

### Does the next operation require every previous result?

If yes:

```text
Workers
   ↓
Barrier
   ↓
Next stage
```

Use a blocking exchange.

### Can the next operator process tuples immediately?

If yes:

```text
Producer
   ↓
Tuple
   ↓
Consumer
```

Use streaming/non-blocking execution.

---

## 3. Analyze a Parallel Hash Join

For a parallel hash join:

### Step 1

Partition the build-side table.

```text
A → A1, A2, A3
```

### Step 2

Assign partitions to workers.

```text
A1 → W1
A2 → W2
A3 → W3
```

### Step 3

Each worker performs filtering and hash-table construction.

### Step 4

Use an exchange/barrier if the entire hash table must be ready.

### Step 5

Process the probe side.

```text
B1 → W1
B2 → W2
B3 → W3
```

### Step 6

Workers probe the hash table independently.

### Step 7

Gather final results.

```text
W1 ──┐
W2 ──┼──> Gather → Final Result
W3 ──┘
```

---

# 4. Analyze an I/O Bottleneck

If CPU resources are available but the query is still slow:

```text
CPU available
     ↓
Waiting for storage
     ↓
I/O bottleneck
```

Consider:

* Multiple disks
* Data striping
* Partitioning
* Parallel reads
* Caching
* Storage bandwidth

---

# 5. Analyze a Storage Layout

Ask:

### Do we prioritize speed?

Consider striping:

```text
Page 1 → Disk 1
Page 2 → Disk 2
Page 3 → Disk 3
```

### Do we prioritize redundancy?

Consider mirroring:

```text
Page 1 → Disk 1
       → Disk 2
       → Disk 3
```

### Do we need both?

Real systems often use designs combining performance and redundancy.

---

# 6. Analyze a Query Plan for Parallelism

Given:

```text
Projection
    ↓
Join
  /   \
Filter Filter
 ↓      ↓
 A      B
```

Ask:

1. Can A be partitioned?
2. Can B be partitioned?
3. Can filters run independently?
4. Does the join require a barrier?
5. Can the join and projection pipeline?
6. How many workers should each stage use?
7. Is communication worth the additional parallelism?
8. Is the bottleneck CPU or I/O?

---

# Must-Know Syntax / Pseudocode

## Parallel Worker Structure

```text
Query
  ↓
Partition input
  ↓
┌─────────┬─────────┬─────────┐
│ Worker 1│ Worker 2│ Worker 3│
└─────────┴─────────┴─────────┘
  ↓           ↓           ↓
Process     Process     Process
  └───────────┼───────────┘
              ↓
           Exchange
              ↓
         Next Operator
```

## Gather

```text
Worker 1 ──┐
Worker 2 ──┼──> Gather ──> Output
Worker 3 ──┘
```

## Distribute

```text
Input
  ↓
Distribute
  ├──> Worker 1
  ├──> Worker 2
  └──> Worker 3
```

## Repartition

```text
Worker 1 ──┐
Worker 2 ──┼──> Repartition
Worker 3 ──┘
                ├──> Worker 4
                └──> Worker 5
```

## Horizontal Parallelism

```text
              Operator
                 ↓
       ┌─────────┼─────────┐
       ↓         ↓         ↓
      W1        W2        W3
       ↓         ↓         ↓
      D1        D2        D3
```

## Vertical Parallelism

```text
Operator A
    ↓
Operator B
    ↓
Operator C
```

with different workers operating on the stages simultaneously.

## Bushy Parallelism

```text
             Final
            /     \
         Join      Join
        /   \     /   \
       A     B   C     D

Different branches can execute
in parallel, and each branch
can itself use multiple workers.
```

---

# Final Cheat Sheet / Memory Sheet

## The Big Picture

```text
                    SQL
                     ↓
              Logical Query
                     ↓
              Physical Plan
                     ↓
          ┌──────────┴──────────┐
          ↓                     ↓
     Single Worker        Parallel Workers
                                ↓
                  ┌─────────────┼─────────────┐
                  ↓             ↓             ↓
              Worker 1      Worker 2      Worker 3
                  └─────────────┼─────────────┘
                                ↓
                           Exchange
                                ↓
                              Result
```

## Remember These Five

### 1. Interquery

```text
Different queries
Q1 → W1
Q2 → W2
```

### 2. Intraquery

```text
One query
Q1 → W1 + W2 + W3
```

### 3. Intraoperator

```text
Same operator
     ↓
W1 + W2 + W3
```

**Horizontal**

### 4. Interoperator

```text
Operator A
    ↓
Operator B
```

running simultaneously.

**Vertical**

### 5. Bushy

```text
Horizontal + Vertical
```

---

# Exchange Memory Trick

```text
GATHER
Many → One

DISTRIBUTE
One → Many

REPARTITION
Many → Many
```

---

# Storage Memory Trick

```text
RAID 0 → STRIPE → SPEED
RAID 1 → MIRROR → SAFETY
```

---

# Process Model Memory Trick

```text
Process → Separate memory
Thread  → Shared memory
Embedded → Application provides worker
```

---

# Parallelism Trade-Off

More workers can mean:

```text
+ More CPU utilization
+ More throughput
+ Faster queries
```

but also:

```text
- More communication
- More synchronization
- More memory usage
- More coordination
```

Therefore:

> **More parallelism is not automatically better.**

---

# Barrier Rule

Ask:

> "Can the next operator start before ALL previous results exist?"

If **NO**:

```text
Use barrier / blocking exchange
```

If **YES**:

```text
Stream results as they arrive
```

---

# Partitioning Rule

```text
Horizontal → rows
Vertical   → columns
```

---

# Query Execution Rule

SQL tells the database **what** result is wanted.

The database decides:

```text
Which operators?
Which order?
Which workers?
How many workers?
Which storage?
How to partition?
How to exchange data?
```

---

# Hardware Rule

The same database concepts can run on:

```text
CPU
GPU
FPGA
Multiple CPUs
Multiple machines
```

The **concepts remain similar**, but the optimal implementation changes because the hardware changes.

---

# Final Exam Checklist

Before an exam, make sure you can explain without notes:

* [ ] What parallel query execution is
* [ ] Parallel vs. distributed databases
* [ ] What a worker is
* [ ] Process-per-worker
* [ ] Thread-per-worker
* [ ] Embedded database systems
* [ ] Why modern systems favor threads
* [ ] Interquery parallelism
* [ ] Intraquery parallelism
* [ ] Intraoperator/horizontal parallelism
* [ ] Interoperator/vertical parallelism
* [ ] Bushy parallelism
* [ ] Producer-consumer execution
* [ ] Why partitioning enables parallelism
* [ ] What an exchange operator does
* [ ] Gather exchange
* [ ] Distribute exchange
* [ ] Repartition exchange
* [ ] Blocking exchanges/barriers
* [ ] Streaming/non-blocking execution
* [ ] Why hash join may require a barrier
* [ ] Why communication costs matter
* [ ] I/O parallelism
* [ ] RAID 0
* [ ] RAID 1
* [ ] Striping vs. mirroring
* [ ] Horizontal vs. vertical partitioning
* [ ] Row stores vs. column stores
* [ ] Why modern hardware changed database architecture
* [ ] Why query optimization is difficult
* [ ] Vortex vs. Spiral DB
* [ ] Why file formats affect query performance
* [ ] Why database abstractions allow the same SQL to run on different physical architectures
* [ ] Why more workers do not automatically mean better performance
* [ ] How to identify the bottleneck: CPU, I/O, communication, or synchronization
