# Database Systems — Query Optimization

## 1. Where Query Optimization Fits

A database system takes a SQL query from an application and turns it into something the execution engine can actually run.

### High-Level Query Processing Pipeline

```text
Application
    ↓
SQL Query
    ↓
Parser
    ↓
Abstract Syntax Tree (AST)
    ↓
Binder
    ↓
Logical Query Plan
    ↓
Optimizer
    ↓
Physical Query Plan
    ↓
Query / Execution Engine
    ↓
Results
```

### Main Components

| Component         | Main Job                                               |
| ----------------- | ------------------------------------------------------ |
| **Parser**        | Reads SQL and creates an Abstract Syntax Tree          |
| **Binder**        | Resolves table/column/function names using the catalog |
| **Logical Plan**  | Describes what the query wants to do                   |
| **Optimizer**     | Finds an efficient equivalent plan                     |
| **Cost Model**    | Estimates how expensive different plans are            |
| **Physical Plan** | Specifies the actual algorithms/operators              |
| **Query Engine**  | Executes the physical plan                             |

---

# 2. SQL Parsing

The first step is to parse the SQL query.

For example:

```sql
SELECT *
FROM Employee
WHERE department = 'Toy';
```

The parser breaks the SQL into tokens and constructs an:

## Abstract Syntax Tree (AST)

An AST is a tree representation of the structure of the SQL query.

It represents things such as:

* Tables
* Columns
* Predicates
* Functions
* Filters
* Joins
* Aggregations
* Sorting
* Projections

The parser is similar to what is done in a traditional compiler.

### Important

The parser understands the **structure** of the query, but it does not necessarily know what the names refer to yet.

---

# 3. The Binder

After parsing, the AST is passed to the **binder**.

The binder resolves names in the SQL query.

For example:

```sql
SELECT Employee.name
FROM Employee;
```

The binder needs to determine:

* Does `Employee` actually exist?
* Does the `name` column exist?
* What is the internal ID of the table?
* What is the internal ID of the column?
* What are their data types?
* What schema do they belong to?

The binder consults the **catalog**.

### Catalog

The catalog contains metadata about database objects, such as:

* Tables
* Columns
* Data types
* Primary keys
* Indexes
* Constraints
* Object identifiers
* Statistics

PostgreSQL uses internal object identifiers called **OIDs**.

### Why Binding Is Necessary

If someone writes:

```sql
SELECT *
FROM DoesNotExist;
```

the database needs to detect that the referenced table does not exist.

The binder performs this name resolution.

### Binder Difficulty

Simple queries are easy:

```sql
SELECT *
FROM Employee;
```

Binding becomes much more complicated with:

* Nested queries
* Duplicate names
* Table aliases
* Self joins
* Correlated subqueries
* Multiple scopes

---

# 4. Logical Query Plan

After binding, the database has a **logical plan**.

A logical plan describes:

> **What the query wants to do, but not exactly how to execute it.**

For example:

```text
Scan Employee
      ↓
Filter department = 'Toy'
      ↓
Projection name
```

The logical plan might say:

> Join Employee and Department.

It does **not** yet say:

> Use a hash join.

or:

> Use a nested-loop join.

Those decisions come later.

---

# 5. Physical Query Plan

A **physical plan** specifies exactly how the database will execute the logical operations.

For example:

```text
Logical:
    Employee JOIN Department

Physical:
    Hash Join
        ↓
    Sequential Scan Employee
        +
    Index Scan Department
```

Possible physical operators include:

* Sequential scan
* Index scan
* Multi-index scan
* Nested-loop join
* Hash join
* Sort-merge join
* Sort
* Aggregation
* Projection

### Logical vs. Physical

| Logical Plan             | Physical Plan        |
| ------------------------ | -------------------- |
| What to do               | How to do it         |
| High-level               | Implementation-level |
| `JOIN(A,B)`              | `Hash Join(A,B)`     |
| `SCAN(A)`                | `Index Scan(A)`      |
| Doesn't choose algorithm | Chooses algorithm    |

---

# 6. What the Optimizer Does

The optimizer takes the logical plan and searches for an efficient **equivalent physical plan**.

```text
Logical Plan
     ↓
Generate Alternatives
     ↓
Evaluate Alternatives
     ↓
Choose Plan
     ↓
Physical Plan
```

The optimizer can change:

* Join order
* Join algorithm
* Scan method
* Predicate placement
* Projection placement
* Operator ordering
* Other physical implementation choices

### Most Important Requirement

Every transformation must preserve **correctness**.

A faster plan that produces the wrong answer is useless.

Therefore:

> **Optimized plans must be semantically equivalent to the original query.**

---

# 7. Why Optimization Matters

A literal translation of SQL into relational algebra can be extremely inefficient.

Consider:

```sql
SELECT DISTINCT e.name
FROM Employee e
JOIN Department d
    ON e.department_id = d.id
WHERE d.name = 'Toy';
```

A naive implementation might:

1. Scan Employee
2. Scan Department
3. Produce a Cartesian product
4. Filter the matching department IDs
5. Filter for `Toy`
6. Project the employee name
7. Remove duplicates

This can generate a huge amount of unnecessary I/O.

Instead, the optimizer can transform the plan.

---

# 8. Example: Improving a Query Plan

The lecture example demonstrated several levels of optimization.

### Naive Plan

```text
Employee Scan
      +
Department Scan
      ↓
Cartesian Product
      ↓
Filter
      ↓
Filter
      ↓
Projection
```

This can produce an enormous number of intermediate tuples.

### Better: Use an Inner Join

Instead of:

```text
Cartesian Product
      ↓
Filter matching IDs
```

use:

```text
Inner Join
```

The database can match tuples directly instead of creating every possible combination.

---

## 8.1 Better Join Algorithm

The optimizer can then choose a better join algorithm.

Possible choices:

* Nested-loop join
* Hash join
* Sort-merge join

The appropriate choice depends on:

* Data size
* Available indexes
* Sort order
* Number of buffers
* Selectivity
* Statistics
* Other physical properties

---

# 9. Materialization vs. Pipelining

The lecture compared two execution models.

## Materialization

One operator completely finishes its work, writes its result to a temporary file, and the next operator reads it.

```text
Operator A
   ↓
Temp File
   ↓
Operator B
   ↓
Temp File
   ↓
Operator C
```

This can produce many additional:

* Reads
* Writes
* I/O operations
* Temporary files

---

## Pipelining / Vectorized Execution

Instead of writing everything to disk between operators, tuples can flow directly between operators.

```text
Operator A
    ↓
Operator B
    ↓
Operator C
    ↓
Result
```

This can dramatically reduce unnecessary I/O.

### Key Idea

> Avoid materializing intermediate results when the execution model allows operators to pipeline data.

---

# 10. Predicate Pushdown

One of the most important optimizations is **predicate pushdown**.

Suppose:

```sql
SELECT ...
FROM Employee e
JOIN Department d
    ON e.department_id = d.id
WHERE d.name = 'Toy';
```

Instead of joining every department and filtering afterward:

```text
Employee
   +
Department
   ↓
Join
   ↓
Filter name = 'Toy'
```

push the filter closer to the Department scan:

```text
Employee
   +
Filter Department = 'Toy'
   ↓
Join
```

### Why?

The filter reduces the number of tuples before the join.

Fewer tuples entering the join means:

* Less CPU
* Less memory
* Less I/O
* Smaller intermediate results
* Faster joins

---

# 11. Projection Pushdown

A **projection** chooses which columns are needed.

Suppose the final result only needs:

```text
artist.name
```

There may be dozens of other columns that are unnecessary.

Instead of carrying all columns through the entire query:

```text
Large rows
   ↓
Join
   ↓
Projection
```

the optimizer can push projections downward:

```text
Only required columns
   ↓
Join
   ↓
Result
```

### Why?

Smaller tuples mean:

* Less memory
* Less I/O
* Less data movement
* Smaller intermediate results

---

# 12. Join Ordering

Join order can have a huge effect on performance.

For example:

```text
A JOIN B JOIN C
```

could be executed as:

```text
(A JOIN B) JOIN C
```

or:

```text
A JOIN (B JOIN C)
```

These can produce very different amounts of intermediate data.

The optimizer uses statistics and the cost model to determine which alternatives are preferable.

### Important

The order written in the SQL query does **not necessarily determine the physical join order**.

---

# 13. Why Join Ordering Is Difficult

The number of possible join orders grows very quickly as the number of tables increases.

For an N-way binary join, the search space can become enormous.

Join ordering is known to be **NP-hard**.

Therefore, an optimizer cannot simply examine every possible plan for large queries.

It needs techniques to:

* Reduce the search space
* Eliminate obviously bad alternatives
* Search intelligently
* Stop searching at an appropriate point

---

# 14. The Query Optimizer's Three Major Components

The lecture describes three major concepts/design decisions.

## 1. Transformation Rules

Determine how one plan can be transformed into another equivalent plan.

## 2. Search Algorithm

Determines which alternatives to explore and in what order.

## 3. Cost Model

Determines which plan is expected to be better.

```text
Transformation Rules
        ↓
Generate Alternatives
        ↓
Search Algorithm
        ↓
Cost Model
        ↓
Best Plan Found
```

The detailed cost model is covered in the following lecture.

---

# 15. Transformation Rules

A **transformation rule** changes a query plan into an equivalent alternative.

These rules are based heavily on **relational algebra equivalences**.

The key requirement is:

```text
Original Plan ≡ Transformed Plan
```

Both must produce the same logical result.

---

# 16. Splitting Conjunctive Predicates

Suppose we have:

```sql
WHERE P1
  AND P2
  AND P3
```

A naive plan might have:

```text
Filter(P1 AND P2 AND P3)
```

This can be transformed into:

```text
Filter(P1)
    ↓
Filter(P2)
    ↓
Filter(P3)
```

### Why?

Once predicates are separated, the optimizer can move them independently.

For example:

```text
Filter(P1)
Filter(P2)
Filter(P3)
```

may allow:

```text
Filter(P2)
      ↓
Scan Table A
```

while another predicate can be pushed toward another table.

---

# 17. Predicate Reordering

If two predicates are independent:

```text
Filter(P1)
    ↓
Filter(P2)
```

can often become:

```text
Filter(P2)
    ↓
Filter(P1)
```

because the final logical result can remain the same.

The optimizer may prefer a predicate that:

* Is cheaper to evaluate
* Is more selective
* Reduces the amount of data earlier

---

# 18. Cartesian Product → Inner Join

Suppose the logical plan contains:

```text
Filter(A.id = B.id)
        ↓
Cartesian Product(A,B)
```

The optimizer can recognize this pattern and transform it into:

```text
Inner Join(A.id = B.id)
```

This is a major optimization.

### Important Rule

> Avoid Cartesian products unless the query explicitly asks for a CROSS JOIN.

A Cartesian product produces:

$$
|A| \times |B|
$$

tuples before filtering.

That can be enormous.

---

# 19. Join Commutativity

For appropriate inner joins:

$$
R \bowtie S \equiv S \bowtie R
$$

This means the order can be swapped without changing the logical result.

This gives the optimizer additional alternatives.

### Why Useful?

The physical join algorithm may benefit from having one relation on a particular side.

For example, a nested-loop join may benefit from having a smaller relation as the outer/input side.

---

# 20. Join Associativity

For appropriate inner joins:

$$
(R \bowtie S) \bowtie T
\equiv
R \bowtie (S \bowtie T)
$$

This means the grouping of joins can be changed.

This is extremely important because different join orders can produce very different intermediate result sizes.

---

# 21. Constant Folding

The optimizer can evaluate expressions that are known at optimization time.

Example:

```text
x = 1 + 1
```

can become:

```text
x = 2
```

Instead of calculating:

```text
1 + 1
```

for every tuple, the database calculates it once.

---

# 22. Constant Propagation

Suppose:

```text
x = 3
AND
y = x
```

The optimizer can infer:

```text
x = 3
AND
y = 3
```

This can make the predicate easier and cheaper to evaluate.

---

# 23. Partial Evaluation

If a function does not depend on each individual tuple, the optimizer may be able to evaluate it once instead of repeatedly.

For example, instead of repeatedly calculating a constant expression for billions of tuples:

```text
function(...)
function(...)
function(...)
...
```

the system can calculate the constant once and reuse it.

---

# 24. Physical Properties

Optimizers may track properties of intermediate data.

One important example is **sort order**.

Suppose a query requires:

```sql
ORDER BY value;
```

The optimizer may recognize that:

* An index already produces sorted data.
* A previous operator already produces sorted data.
* A sort-merge join may preserve useful ordering.
* Another operator may destroy ordering.

Therefore, physical properties can influence which plan is chosen.

---

# 25. Logical Operators Do Not Always Map 1-to-1 to Physical Operators

A logical operation does not necessarily become exactly one physical operation.

For example:

```text
Logical Join
```

could become:

```text
Hash Join
```

or:

```text
Sort-Merge Join
```

or:

```text
Nested-Loop Join
```

Transformations can also:

* Combine operators
* Split operators
* Move operators
* Remove unnecessary operators
* Introduce multiple operators

---

# 26. Single-Query Optimization

Most production database systems optimize one SQL query at a time.

```text
Query 1 → Plan 1

Query 2 → Plan 2

Query 3 → Plan 3
```

The optimizer generally does not simultaneously optimize all queries running on the system.

### Multi-Query Optimization

In theory, the database could consider multiple queries together and exploit:

* Shared scans
* Shared intermediate results
* Overlapping work

This exists in research/specialized systems, but the lecture emphasized that ordinary production systems generally perform **single-query optimization**.

---

# 27. Rule-Based / Heuristic Optimization

One approach is to use predefined rules without a sophisticated cost model.

Examples:

```text
Push predicates down
Push projections down
Eliminate unnecessary Cartesian products
Use an index for an obvious primary-key lookup
Apply simple transformations
```

The optimizer keeps applying rules until:

* No more rules apply
* A search limit is reached
* The optimizer runs out of its allowed budget

---

# 28. Why Rule-Based Optimization Is Popular

It is relatively:

* Simple
* Easy to implement
* Easy to debug
* Predictable

A developer can trace the query and see:

```text
Rule 1
 ↓
Rule 2
 ↓
Rule 3
 ↓
Final Plan
```

This is one reason early database systems commonly used heuristic/rule-based approaches.

---

# 29. Problems with Pure Heuristics

The biggest problem is that heuristics may rely on **hard-coded assumptions** or "magic constants."

For example:

> Is an index scan faster than a sequential scan?

For:

```sql
WHERE id = 5
```

where `id` is a primary key, an index lookup is often an obvious choice.

But for:

```sql
WHERE value > 100
```

the answer depends on:

* How many rows match?
* How selective is the predicate?
* How large is the table?
* How expensive is random I/O?
* How expensive is sequential I/O?
* What hardware is being used?
* How much memory is available?

At this point, you need a **cost model**.

---

# 30. Rule-Based vs. Cost-Based Optimization

| Rule-Based / Heuristic           | Cost-Based                     |
| -------------------------------- | ------------------------------ |
| Uses predefined rules            | Estimates plan costs           |
| Usually simpler                  | More sophisticated             |
| Easier to debug                  | More complex                   |
| Good for obvious optimizations   | Handles more alternatives      |
| Can use hard-coded assumptions   | Uses statistics/cost estimates |
| Poorer for complex join ordering | Better suited to complex plans |

### Important

These approaches are **not mutually exclusive**.

A system can:

1. Apply guaranteed logical transformations first.
2. Then use cost-based optimization for remaining choices.

---

# 31. Prepared Statements

A prepared statement can be planned before the query is actually executed.

Example conceptually:

```sql
PREPARE query AS
SELECT *
FROM Employee
WHERE id = ?;
```

The system may generate and store a physical plan.

Later:

```text
Parameter = 10
Parameter = 500
Parameter = 9000
```

can reuse that plan.

### Problem

What if the optimizer does not know the parameter value when planning?

For example:

```text
WHERE age = ?
```

Different values could have very different selectivities.

The optimizer may have to make decisions using:

* Statistics
* Average values
* Assumptions
* Generic plans

This is an example of **optimization under incomplete information**.

---

# 32. Cost-Based Search

A cost-based optimizer generates alternative plans and uses a cost model to compare them.

Conceptually:

```text
Plan A → Cost = 500
Plan B → Cost = 200
Plan C → Cost = 900
```

The optimizer can prefer the plan with the lower estimated cost when minimizing cost.

The cost model can consider things such as:

* I/O
* CPU
* Memory
* Network I/O
* Intermediate result sizes
* Other execution costs

The lecture emphasizes that **I/O has historically been very important**, although CPU and other resources can become bottlenecks depending on the system and hardware.

---

# 33. What Does "Better Plan" Mean?

Usually, databases optimize for **performance**.

A human typically experiences performance as:

> **Wall-clock execution time**

However, directly predicting:

```text
Estimated I/O → exact milliseconds
```

is difficult.

Therefore, database systems generally use **synthetic cost units** rather than claiming:

> "This plan will take exactly 17.4 milliseconds."

The next lecture goes deeper into cost models.

---

# 34. Search Termination

A cost-based optimizer cannot search forever.

It needs a stopping condition.

### Method 1: Time Limit

Example:

```text
Optimize for 500 ms
↓
Stop
↓
Use best plan found
```

### Method 2: Cost Threshold

Stop once a plan reaches a sufficiently good estimated cost.

### Method 3: No Improvement

If the optimizer has not found a better plan for some period/search budget, stop.

### Method 4: Exhaust Search Space

For simple queries, the optimizer may be able to examine all relevant alternatives.

---

# 35. Transformation Count vs. Wall-Clock Time

A system can limit optimization by counting the number of transformations rather than measuring time.

For example:

```text
Maximum = 100,000 transformations
```

Once that number is reached:

```text
Stop optimization
↓
Use best plan found
```

### Why?

Wall-clock time can vary depending on system load.

Suppose two identical machines run the same query:

```text
Machine A: lightly loaded
Machine B: heavily loaded
```

If both have a 1-second optimization limit, they might perform different numbers of transformations.

A transformation-count limit can make optimization more deterministic.

### Important Benefit

Given the same input and rules, the optimizer can perform approximately the same search regardless of temporary CPU load.

---

# 36. Access Method Selection

The optimizer must decide how to access each table.

A logical scan such as:

```text
Scan(Employee)
```

can potentially become:

```text
Sequential Scan
```

or:

```text
Index Scan
```

or:

```text
Multi-Index Scan
```

The optimizer examines:

* Catalog information
* Available indexes
* Predicates
* Statistics
* Physical properties

---

# 37. Sequential Scan as the Fallback

If no useful index exists, the database can always use a sequential scan.

```text
Logical Scan
      ↓
Sequential Scan
```

This is the fundamental fallback access method.

It may not be the fastest choice, but it is generally available.

---

# 38. SARGable Predicates

**SARGable** means:

> **Search ARGument able**

It is a database term describing predicates that can be used effectively with an index.

For example:

```sql
WHERE id = 123
```

If `id` has an index, the optimizer can potentially turn this into an index lookup.

A predicate that matches the indexed expression directly is generally easier for the optimizer to exploit.

---

# 39. Example: Index Selection

Suppose a table has:

```text
10 million rows
```

and an index on:

```text
value
```

Query:

```sql
SELECT *
FROM T
WHERE value >= 123
  AND value < 456;
```

The optimizer can recognize that the predicate matches the indexed column and consider an index scan.

Conceptually:

```text
Logical Scan
      ↓
Index Scan(value)
```

instead of:

```text
Logical Scan
      ↓
Sequential Scan
```

---

# 40. Why an Index Is Not Always Better

Having an index does **not** mean the optimizer should always use it.

Suppose a query returns a very large fraction of the table.

It may be cheaper to simply scan the entire table sequentially.

Therefore:

```text
Index exists
      ≠
Always use index
```

The optimizer needs to estimate the relative costs.

This is where the **cost model** becomes important.

---

# 41. Expressions Can Prevent Index Usage

Consider:

```sql
ORDER BY value;
```

versus:

```sql
ORDER BY value + 0;
```

A human may recognize that, for ordinary integer values:

```text
value + 0 = value
```

But an optimizer may not always recognize that the expression is equivalent to the indexed column.

Therefore it may fail to exploit the index.

This demonstrates an important point:

> Query optimizers do not always recognize transformations that seem obvious to humans.

Different database systems can behave differently.

---

# 42. Query Hints

Some database systems allow users to provide **optimizer hints**.

A hint can tell the database things such as:

* Use a particular index
* Prefer a particular join order
* Use a particular join algorithm

Conceptually:

```text
SQL Query
   +
Optimizer Hint
   ↓
Constrained Plan Search
```

### Why Use Hints?

They can be useful when the optimizer consistently chooses an undesirable plan for a known workload.

### Problem With Hints

Hints can become stale.

Suppose:

```text
2026:
Data distribution → Plan A is good
        ↓
Hint forces Plan A
        ↓
2036:
Data distribution changes
        ↓
Plan A is now poor
```

The hint may now force a bad plan.

The same problem can occur if:

* Hardware changes
* Data grows
* Data distribution changes
* Indexes change
* The original developer leaves
* The code is maintained years later

### Key Idea

> Hints can provide control, but they can also lock an application into assumptions about the data and system.

---

# 43. Cost-Based Search and Local Improvements

A cost-based search may compare a new plan with the best plan found so far.

For example:

```text
Current Plan
Cost = 1000

New Plan
Cost = 700
```

The new plan is promising.

However, not every individual transformation must immediately reduce cost.

A search strategy may temporarily accept a worse intermediate state if it could eventually lead to a better plan.

This is similar conceptually to search methods such as gradient descent or other optimization strategies.

---

# 44. Optimization in Phases

Some optimizers may organize optimization into phases.

For example:

```text
Phase 1:
Optimize individual table access

        ↓

Phase 2:
Optimize joins

        ↓

Phase 3:
Optimize nested queries

        ↓

Final Physical Plan
```

Other systems may use a more holistic approach.

---

# 45. Bottom-Up vs. Top-Down Optimization

There are two major ways to organize cost-based search.

## Bottom-Up

Start at the leaf nodes and build the plan upward.

```text
Tables
  ↓
Access Methods
  ↓
Joins
  ↓
More Operators
  ↓
Final Result
```

This is similar to **forward chaining**.

---

## Top-Down

Start with the desired final result and work downward toward the leaves.

```text
Final Result
     ↓
Required Operators
     ↓
Required Subplans
     ↓
Table Access
```

This is similar to **backward chaining**.

---

# 46. Bottom-Up Example

Suppose we need:

```text
Artist JOIN Appears JOIN Album
```

A bottom-up optimizer starts with:

```text
Scan Artist
Scan Appears
Scan Album
```

Then it considers possible ways to combine them.

For example:

```text
Artist + Appears
```

could use:

```text
Hash Join
Merge Join
Nested-Loop Join
```

The optimizer estimates the cost of the alternatives.

Then it continues upward.

---

# 47. Top-Down Example

A top-down optimizer begins with:

```text
Desired final result
```

and asks:

> What operators do I need to produce this result?

Then it recursively works downward until it reaches the table scans.

It can search different possible alternatives along the way.

---

# 48. Dynamic Programming

The lecture introduces **dynamic programming** for bottom-up optimization.

Dynamic programming is essentially:

> **Divide the problem into smaller subproblems, solve those subproblems, and reuse the best solutions.**

Instead of examining every possible complete plan independently, the optimizer can reuse information about smaller subplans.

---

# 49. System R

IBM's **System R** was one of the earliest relational database systems and introduced an important cost-based query optimization approach.

Its optimizer used dynamic programming to explore join alternatives.

Because hardware was extremely limited at the time, System R needed to aggressively reduce the search space.

---

# 50. Left-Deep Join Trees

One major simplification was considering **left-deep join trees**.

Example:

```text
((A JOIN B) JOIN C) JOIN D
```

The result of each join becomes the input to the next join.

Graphically:

```text
        JOIN D
       /
    JOIN C
   /
 JOIN B
 /   \
A     B
```

The important characteristic is that the tree grows along the left side.

---

# 51. Right-Deep Join Trees

A right-deep structure might look like:

```text
A JOIN (B JOIN (C JOIN D))
```

System R's early approach did not consider these alternatives.

---

# 52. Bushy Join Trees

A bushy tree allows independent joins to happen first:

```text
       JOIN
      /    \
   JOIN    JOIN
   /  \    /  \
  A    B  C    D
```

For example:

```text
(A JOIN B)
        +
(C JOIN D)
        ↓
      JOIN
```

This provides additional possibilities but dramatically increases the search space.

---

# 53. Why Restrict Join Trees?

If an optimizer considered:

* Left-deep trees
* Right-deep trees
* Bushy trees
* Every join algorithm
* Every access method

the search space would become enormous.

Restricting the possible tree structures reduces optimization time.

### Tradeoff

You may eliminate the true optimal plan.

So:

```text
Smaller search space
        ↓
Faster optimization

BUT

Fewer plans considered
        ↓
Potentially miss the globally optimal plan
```

---

# 54. System R Dynamic Programming Process

Conceptually:

### Step 1 — Find Access Methods

For each table:

```text
Sequential Scan
Index Scan
Other Access Methods
```

Choose promising alternatives.

### Step 2 — Consider Two-Table Joins

For example:

```text
Artist JOIN Appears
```

Consider:

```text
Hash Join
Merge Join
Nested-Loop Join
```

### Step 3 — Keep the Best Subplan

Use the cost model to identify the best alternative.

### Step 4 — Add Another Relation

For example:

```text
(Artist JOIN Appears) JOIN Album
```

Again consider different join algorithms.

### Step 5 — Continue

Build larger subplans from previously optimized smaller subplans.

---

# 55. Dynamic Programming Search

The general idea is:

```text
      Final Plan
          ↑
     Best Subplans
          ↑
    Smaller Subplans
          ↑
      Base Tables
```

Instead of solving the entire problem from scratch every time, the optimizer reuses the best known solutions to smaller pieces.

---

# 56. Physical Properties and Early Optimizers

Early optimization approaches did not always track physical properties such as sort order directly.

For example:

```sql
ORDER BY name
```

requires sorted output.

A hash join generally destroys useful ordering.

An index scan might naturally produce sorted data.

Modern optimizers can track these properties more directly.

Early systems could instead incorporate penalties into their cost calculations for plans that failed to preserve useful properties.

---

# 57. Search-Space Reduction

Optimization is fundamentally a search problem.

The optimizer wants:

```text
Best Plan
```

but has potentially:

```text
Huge Number of Alternatives
```

Therefore it uses:

* Transformation rules
* Heuristics
* Dynamic programming
* Search pruning
* Restricted join trees
* Cost thresholds
* Time/transformation budgets

to reduce the search space.

---

# 58. Important Relationship: Optimization + Cost Model

The optimizer determines:

> **What plans should I consider?**

The cost model determines:

> **Which plan appears cheaper?**

Together:

```text
Transformation Rules
        ↓
Possible Plans
        ↓
Search Algorithm
        ↓
Cost Model
        ↓
Best Estimated Plan
```

The cost model is therefore critical to cost-based optimization.

---

# 59. Connection to Video 2: Cardinality Estimation

The next lecture continues directly from this topic.

The optimizer needs statistics to estimate things such as:

* Number of tuples
* Number of distinct values
* Selectivity
* Join output size
* Predicate result sizes

Those estimates feed into the cost model.

Therefore:

```text
Database Statistics
        ↓
Cardinality Estimation
        ↓
Cost Model
        ↓
Query Optimization
        ↓
Physical Plan
```

### This is extremely important.

A bad cardinality estimate can cause the optimizer to choose a bad physical plan.

---

# 60. Full Query Optimization Pipeline

Putting everything together:

```text
                  SQL Query
                      │
                      ▼
                   Parser
                      │
                      ▼
                    AST
                      │
                      ▼
                   Binder
                      │
               ┌──────┴──────┐
               │   Catalog   │
               └─────────────┘
                      │
                      ▼
               Logical Plan
                      │
                      ▼
              Transformation
                  Rules
                      │
                      ▼
             Plan Alternatives
                      │
                      ▼
               Search Algorithm
                      │
             ┌────────┴────────┐
             │                 │
             ▼                 ▼
      Cardinality          Cost Model
       Estimates
             │                 │
             └────────┬────────┘
                      ▼
                Best Plan Found
                      │
                      ▼
              Physical Plan
                      │
                      ▼
               Query Engine
                      │
                      ▼
                   Results
```

---

# 61. Key Definitions

### Parser

Converts SQL text into a structured representation such as an AST.

### Abstract Syntax Tree (AST)

Tree representation of the structure of a SQL statement.

### Binder

Resolves names such as tables and columns to actual database objects.

### Catalog

Stores metadata about database objects.

### Logical Plan

Describes what operations the query needs without specifying implementation details.

### Physical Plan

Specifies the actual algorithms used to execute the query.

### Query Optimizer

Searches for an efficient physical plan that is logically equivalent to the original query.

### Transformation Rule

A rule that converts one query-plan representation into an equivalent alternative.

### Heuristic Optimization

Uses predefined rules and assumptions to transform queries.

### Cost-Based Optimization

Uses estimated costs to compare alternative query plans.

### Cost Model

A model used to estimate the relative cost of executing different plans.

### Cardinality

The number of tuples produced by a relation or operator.

### Selectivity

The fraction of tuples expected to satisfy a predicate.

### Predicate Pushdown

Moving filters closer to the data source so fewer tuples are processed.

### Projection Pushdown

Moving column selection closer to the data source so fewer columns are carried through the plan.

### SARGable

"Search ARGument able"; a predicate that can be effectively used with an index/access path.

### Dynamic Programming

An optimization technique that solves and reuses smaller subproblems to build larger solutions.

### Left-Deep Join Tree

A join tree where each new relation is joined with the result of the previous joins.

---

# 62. Important Rules to Remember

### Predicate Decomposition

```text
Filter(P1 AND P2)
```

can become:

```text
Filter(P1)
    ↓
Filter(P2)
```

---

### Predicate Pushdown

```text
Join
 ↓
Filter
```

can often become:

```text
Filter
 ↓
Join
```

when the predicate applies to one side.

---

### Projection Pushdown

```text
Join
 ↓
Projection
```

can often become:

```text
Projection
 ↓
Join
```

when only a subset of columns is required.

---

### Join Commutativity

$$
R \bowtie S = S \bowtie R
$$

for appropriate inner joins.

---

### Join Associativity

$$
(R \bowtie S) \bowtie T
=
R \bowtie (S \bowtie T)
$$

for appropriate inner joins.

---

### Cartesian Product

$$
|R \times S| = |R| \times |S|
$$

This is why unnecessary Cartesian products can become extremely expensive.

---

# 63. Heuristic vs. Cost-Based — Exam Comparison

| Feature              | Heuristic / Rule-Based           | Cost-Based                     |
| -------------------- | -------------------------------- | ------------------------------ |
| Main idea            | Apply predefined rules           | Compare estimated costs        |
| Cost model required? | Not necessarily                  | Yes                            |
| Complexity           | Lower                            | Higher                         |
| Debugging            | Easier                           | Harder                         |
| Join ordering        | Limited                          | Extensive search               |
| Statistics           | Less important                   | Very important                 |
| Search space         | Usually smaller                  | Potentially huge               |
| Optimization quality | Can degrade on complex queries   | Can consider more alternatives |
| Common use           | Early/simple optimization stages | Sophisticated database systems |

---

# 64. Bottom-Up vs. Top-Down

| Bottom-Up                         | Top-Down                              |
| --------------------------------- | ------------------------------------- |
| Starts at tables                  | Starts at desired result              |
| Builds upward                     | Searches downward                     |
| Forward chaining                  | Backward chaining                     |
| Dynamic programming commonly used | Can use depth-first/search strategies |
| Builds subplans                   | Decomposes required result            |

---

# 65. Materialization vs. Pipelining

| Materialization           | Pipelining               |
| ------------------------- | ------------------------ |
| Write intermediate result | Pass tuples directly     |
| Read intermediate result  | Avoid intermediate reads |
| More I/O                  | Less I/O                 |
| More temporary data       | Less temporary data      |
| Can be simpler            | Can be more efficient    |

---

# 66. The Most Important Ideas for the Exam

### 1. SQL does not directly become executable code.

It goes through:

```text
SQL
→ Parser
→ Binder
→ Logical Plan
→ Optimizer
→ Physical Plan
→ Execution
```

---

### 2. Logical and physical plans are different.

**Logical:**

> What should happen?

**Physical:**

> How should it happen?

---

### 3. Optimization must preserve correctness.

Every transformation should produce an equivalent result.

---

### 4. The optimizer searches a huge space.

Especially when many tables are joined.

---

### 5. Join ordering is a major optimization problem.

Different join orders can produce dramatically different intermediate results.

---

### 6. Transformation rules reduce the search space.

Examples:

* Predicate pushdown
* Projection pushdown
* Join reordering
* Predicate decomposition
* Cartesian-product elimination
* Constant folding
* Constant propagation

---

### 7. Rule-based optimization is simpler.

It applies known rules without necessarily calculating a detailed cost for every decision.

---

### 8. Cost-based optimization is more sophisticated.

It generates alternatives and uses a cost model to compare them.

---

### 9. Statistics matter.

The optimizer needs information about the data to estimate which plans are likely to be efficient.

---

### 10. Cardinality estimation connects Video 1 and Video 2.

```text
Statistics
    ↓
Cardinality Estimates
    ↓
Cost Model
    ↓
Plan Selection
```

Bad statistics → bad cardinality estimates → bad cost estimates → potentially bad query plans.

---

# 67. Quick Study Cheat Sheet

```text
SQL
 ↓
Parser
 ↓
AST
 ↓
Binder + Catalog
 ↓
Logical Plan
 ↓
Transformation Rules
 ↓
Plan Alternatives
 ↓
Search Algorithm
 ↓
Cardinality Estimation
 ↓
Cost Model
 ↓
Best Estimated Plan
 ↓
Physical Plan
 ↓
Query Engine
```

### Remember:

```text
Logical Plan = WHAT

Physical Plan = HOW

Optimizer = FINDS A GOOD WAY

Transformation Rules = GENERATE ALTERNATIVES

Search Algorithm = DECIDES WHAT TO EXPLORE

Cost Model = ESTIMATES WHICH IS BETTER

Cardinality Estimation = ESTIMATES HOW MUCH DATA FLOWS THROUGH
```

### Major Optimizations

```text
Predicate Pushdown
Projection Pushdown
Join Reordering
Join Algorithm Selection
Index Selection
Constant Folding
Constant Propagation
Cartesian Product → Inner Join
Pipelining
```

### Major Search Strategies

```text
Rule-Based / Heuristic
        vs.
Cost-Based

Bottom-Up
        vs.
Top-Down
```

### Major Search-Space Techniques

```text
Dynamic Programming
Search Pruning
Left-Deep Trees
Transformation Limits
Cost Thresholds
Time/Rule Budgets
```

---

# 68. Final Takeaway

The central idea of this lecture is that **query optimization is a search problem**.

A SQL query can have an enormous number of logically equivalent ways to execute. The optimizer uses relational-algebra transformations to generate alternatives, search algorithms to explore those alternatives, and cost/cardinality estimates to determine which alternatives appear efficient.

The goal is not to change **what** the query means.

The goal is to change **how** it is executed while preserving the exact same result.

```text
Same Result
    +
Different Execution Strategies
    ↓
Find the Efficient Plan
```

And this leads directly into the next topic:

```text
How do we estimate the cost of each plan?
             ↓
How do we estimate how many tuples
each operator will produce?
             ↓
Cardinality Estimation + Cost Models
```
