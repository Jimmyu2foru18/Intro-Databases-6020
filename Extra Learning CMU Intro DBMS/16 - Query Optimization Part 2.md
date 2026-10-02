# Query Optimization — Cardinality Estimation, Statistics, and Cost Models

## 1. Cardinality Estimation

**Cardinality estimation** is the process of predicting how many tuples (rows) an operation in a query will produce.

The optimizer needs this information to decide:

* Which indexes to use
* Which join algorithm to use
* The order of joins
* How much memory to allocate
* How much I/O will be required
* Which query plan is expected to be cheapest

### Main things we need to estimate

There are three major estimation problems:

1. **Selection**

   * How many tuples satisfy a `WHERE` condition?

2. **Join**

   * How many tuples will two relations produce when joined?

3. **Distinct values**

   * How many unique values will remain after operations such as `GROUP BY` or `DISTINCT`?

These estimates become the foundation for estimating more complicated query plans.

---

# 2. Statistics Used by the Optimizer

A database cannot normally keep the complete distribution of every column because doing so would require too much storage.

Instead, database systems maintain **statistical summaries** of the data.

The major approaches are:

1. Histograms
2. Sketches
3. Sampling
4. Machine-learning-based methods

---

# 3. Histograms

A **histogram** summarizes how frequently values occur in a column.

Think of it as:

```text
Value → Number of occurrences
```

### Example

Suppose we have an `age` column:

| Age | Count |
| --: | ----: |
|   1 |     2 |
|   2 |     4 |
|   3 |     7 |
|   4 |     3 |
|   5 |     8 |

The histogram records the number of occurrences of each value.

This allows the optimizer to estimate questions such as:

```sql
WHERE age = 3
```

because it knows approximately how many rows contain `age = 3`.

---

# 4. Problem With Exact Histograms

An exact histogram stores every distinct value.

This can become extremely expensive for large tables.

Suppose a column contains:

```text
1 billion values
```

and each value requires a 32-bit integer.

Since:

```text
32 bits = 4 bytes
```

the values alone require approximately:

```text
1,000,000,000 × 4 bytes
= 4,000,000,000 bytes
≈ 4 GB
```

And this is only the statistics for **one column**.

If a table has hundreds of columns, storing exact statistics for every distinct value becomes very expensive.

Therefore, databases need compressed approximations.

---

# 5. Equi-Width Histograms

An **equi-width histogram** divides the range of values into buckets with equal-width ranges.

### Example

Suppose the values are divided into:

```text
1–4
5–8
9–12
13–16
```

Each bucket has the same numerical width.

The database stores something like:

| Bucket | Count |
| ------ | ----: |
| 1–4    |    10 |
| 5–8    |    15 |
| 9–12   |    20 |
| 13–16  |     5 |

Instead of storing every individual value, we store a range and the number of values in that range.

### Advantage

Much smaller than an exact histogram.

### Disadvantage

We lose information about the individual values inside each bucket.

---

# 6. Estimating an Equality Predicate Using an Equi-Width Histogram

Suppose we have:

```text
Bucket: 9–13
Count: 9
```

There are:

```text
13 - 9 + 1 = 5
```

possible values in the bucket.

If we assume a **uniform distribution**, then each value is estimated to occur equally often.

Therefore:

$$
EstimatedCount =
\frac{BucketCount}{NumberOfValuesInBucket}
$$

So:

$$
\frac{9}{5}=1.8
$$

Therefore:

```text
Estimated count for age = 9 ≈ 1.8 tuples
```

The optimizer is allowed to produce fractional estimates because these are predictions, not actual row counts.

---

# 7. Equi-Depth Histograms

An **equi-depth histogram** attempts to put approximately the same number of tuples into each bucket.

Unlike equi-width:

### Equi-width

```text
Same WIDTH
Different HEIGHT
```

### Equi-depth

```text
Different WIDTH
Same/approximately same HEIGHT
```

Example:

```text
Bucket 1 → values 1–3
Bucket 2 → values 4–8
Bucket 3 → values 9–13
Bucket 4 → values 14–15
```

The ranges are different sizes because the database is trying to put approximately the same number of tuples in each bucket.

---

# 8. Why Equi-Depth Can Be Better

Equi-depth histograms can represent **heavy hitters** better.

A **heavy hitter** is a value that occurs much more frequently than other values.

For example:

```text
Honda → 50,000
Toyota → 20,000
Ford → 15,000
Other values → much smaller counts
```

If Honda is placed in a large bucket with thousands of low-frequency values, its importance may be hidden.

Equi-depth histograms can create narrower buckets around areas with many occurrences.

This gives the optimizer more accurate information about frequently occurring values.

---

# 9. N-Bucket / N-Bias Histogram

Another technique is to reserve buckets for the most frequent values.

The basic idea:

```text
N - 1 buckets → exact counts for frequent values
1 bucket      → everything else
```

For example:

| Value  |            Count |
| ------ | ---------------: |
| Honda  |           50,000 |
| Toyota |           30,000 |
| Ford   |           20,000 |
| Other  | remaining values |

The frequent values are stored exactly.

Everything else is grouped into a remaining bucket.

### Why?

Because accurate statistics are most valuable for values that occur frequently.

---

# 10. What Happens When the Data Changes?

The distribution of a column can change over time.

For example:

Initially:

```text
Honda → 50,000
Toyota → 40,000
```

Later:

```text
Honda → 50,000
Toyota → 100,000
```

Toyota may now become a heavy hitter.

Therefore, the histogram may need to be rebuilt or updated.

Database systems can use commands such as:

```sql
ANALYZE
```

to collect/recompute statistics.

---

# 11. Sketches

A **sketch** is a compact probabilistic data structure used to approximately answer statistical questions.

Sketches use much less memory than storing exact information.

Different sketches answer different questions.

### Examples

| Question                           | Example structure   |
| ---------------------------------- | ------------------- |
| What are the most frequent values? | Count-Min Sketch    |
| How many distinct values exist?    | HyperLogLog         |
| General statistical summaries      | Apache DataSketches |

---

# 12. Count-Min Sketch

A **Count-Min Sketch** is useful for estimating the frequency of values.

For example:

```text
How many times does "Honda" occur?
```

Instead of storing an exact counter for every value, the sketch uses hash functions and a compact table.

### Important idea

```text
Exact histogram
    ↓
Stores individual values

Count-Min Sketch
    ↓
Stores approximate frequencies
```

The advantage is much lower memory usage.

The disadvantage is that the result is approximate.

---

# 13. HyperLogLog

**HyperLogLog** is used to estimate the number of **distinct values** in a dataset.

For example:

```sql
SELECT COUNT(DISTINCT student_id)
FROM Students;
```

If the table is extremely large, maintaining every unique value can be expensive.

HyperLogLog provides an approximate distinct count using very little memory.

---

# 14. Sampling

**Sampling** means examining only a subset of the original data and using that subset to estimate properties of the entire dataset.

Instead of analyzing:

```text
1,000,000,000 rows
```

we might analyze:

```text
1,000,000 sampled rows
```

and assume the sample represents the larger table.

---

# 15. Sampling Example

Suppose we want:

```sql
WHERE age > 50
```

Suppose our sample contains:

| Person | Age |
| ------ | --: |
| Obama  |  60 |
| Tupac  |  21 |
| DJ     |  23 |

Only one of three people satisfies:

```text
age > 50
```

Therefore:

$$
Selectivity = \frac{1}{3}
$$

So we estimate that approximately:

```text
33.3%
```

of the complete table satisfies the condition.

---

# 16. Machine Learning for Statistics

Another approach is to use **machine-learning models** to learn properties of the data.

The model attempts to learn:

```text
Data distribution
       ↓
ML model
       ↓
Cardinality estimates
```

This is an active research area.

The lecture notes that traditional histograms remain much more common in production systems, while ML-based approaches are still relatively early compared with traditional techniques.

---

# 17. Comparison of Statistics Techniques

| Technique            | Main Idea                           | Advantage                          | Disadvantage                          |
| -------------------- | ----------------------------------- | ---------------------------------- | ------------------------------------- |
| Exact histogram      | Store every value/count             | Accurate                           | Large storage                         |
| Equi-width histogram | Equal-width buckets                 | Simple                             | Can lose distribution details         |
| Equi-depth histogram | Similar number of tuples per bucket | Better distribution representation | More complex                          |
| N-bias histogram     | Exact heavy hitters + remainder     | Good for frequent values           | Approximation for remaining values    |
| Sketch               | Probabilistic summary               | Very compact                       | Approximate                           |
| Sampling             | Analyze subset                      | Can represent real data            | Sample may not represent entire table |
| ML                   | Learn data distribution             | Potentially powerful               | Still developing                      |

---

# 18. Selectivity

**Selectivity** is the fraction/probability of tuples that satisfy a predicate.

$$
Selectivity =
\frac{\text{Number of matching tuples}}
{\text{Total number of tuples}}
$$

Therefore:

$$
0 \leq Selectivity \leq 1
$$

### Example

Suppose a table contains:

```text
45 tuples
```

and:

```text
4 tuples satisfy age = 9
```

Then:

$$
Selectivity =
\frac{4}{45}
$$

$$
Selectivity \approx 0.0889
$$

or approximately:

```text
8.89%
```

---

# 19. Cardinality

**Cardinality** is the estimated number of tuples produced by an operation.

For a selection:

$$
EstimatedCardinality =
N \times Selectivity
$$

where:

* \(N\) = number of tuples in the input relation
* Selectivity = fraction of tuples satisfying the predicate

### Example

Suppose:

```text
N = 45
Selectivity = 0.0889
```

Then:

$$
45(0.0889)\approx4
$$

So the estimated cardinality is approximately:

```text
4 tuples
```

---

# 20. Number of Distinct Values

A common notation is:

$$
V(R,A)
$$

which represents the number of **distinct values** of attribute \(A\) in relation \(R\).

Example:

```text
Student IDs:

1
2
3
3
4
4
4
```

There are four distinct values:

```text
1, 2, 3, 4
```

Therefore:

$$
V(R,StudentID)=4
$$

---

# 21. Equality Predicate

An equality predicate looks like:

```sql
WHERE age = 9
```

If we know the exact frequency of the value:

$$
Selectivity(age=9)
=
\frac{Count(age=9)}{N}
$$

### Example

If:

```text
N = 45
age = 9 occurs 4 times
```

then:

$$
Selectivity =
\frac{4}{45}
=
0.0889
$$

Estimated cardinality:

$$
45(0.0889)=4
$$

---

# 22. Equality Using a Bucket

Suppose the histogram contains:

```text
Age 9–13
Count = 9
```

Assuming a uniform distribution:

```text
Number of possible values = 5
```

Therefore:

$$
EstimatedCount =
\frac{9}{5}
=
1.8
$$

And:

$$
Selectivity =
\frac{1.8}{N}
$$

The important assumption is:

> Every value within the bucket is assumed to occur with approximately equal frequency.

---

# 23. The Uniformity Assumption

The **uniformity assumption** says that values within a histogram bucket are assumed to have approximately equal probability.

For example:

```text
Bucket: 9–13
```

The optimizer assumes:

```text
9 ≈ 10 ≈ 11 ≈ 12 ≈ 13
```

in terms of frequency.

### Problem

Real data is often not uniform.

For example:

```text
Age 9  → 2 people
Age 10 → 3 people
Age 11 → 50 people
Age 12 → 4 people
Age 13 → 2 people
```

A uniform estimate would be inaccurate.

---

# 24. Continuous-Value Assumption

Range estimates may also assume values are continuous.

For example:

```text
1–1,000,000
```

The optimizer may assume values exist throughout the range.

But real data could contain gaps:

```text
1
2
3
1000000
```

The database may not know about all of those gaps from a small statistical summary.

Therefore, range estimates can include values that do not actually exist.

---

# 25. Range Predicates

A range predicate looks like:

```sql
WHERE age >= 7
```

Suppose the histogram contains:

```text
6–8 → 12 tuples
9–13 → 9 tuples
14–15 → 12 tuples
```

For:

```text
age >= 7
```

we know that the entire buckets after `6–8` qualify.

Therefore:

```text
9–13 → 9
14–15 → 12
```

The difficult part is the bucket:

```text
6–8
```

because only:

```text
7 and 8
```

qualify.

Assuming uniformity:

$$
\frac{12}{3}=4
$$

tuples per value.

Two values qualify:

$$
4(2)=8
$$

Therefore:

$$
EstimatedCardinality =
8+9+12
$$

$$
=29
$$

The important point is that this is an **estimate**, not necessarily the exact answer.

---

# 26. Problems With Range Estimates

Range estimation can be inaccurate because:

1. Values may not be uniformly distributed.
2. Values may not be continuous.
3. There may be gaps.
4. Heavy hitters can distort the distribution.
5. Histogram buckets hide individual values.

---

# 27. NOT EQUAL Predicates

For:

```sql
WHERE age <> 2
```

we can estimate:

```text
age = 2
```

first.

Then:

$$
Selectivity(age\neq2)
=
1-Selectivity(age=2)
$$

### Example

If:

$$
Selectivity(age=2)=0.10
$$

then:

$$
Selectivity(age\neq2)
=
1-0.10
=
0.90
$$

So approximately 90% of tuples qualify.

---

# 28. Selectivity Is a Probability

A useful way to think about selectivity is:

> **Selectivity is the probability that a randomly selected tuple satisfies the predicate.**

For example:

```text
Selectivity = 0.20
```

means:

```text
Approximately 20% of tuples are expected to match.
```

This interpretation becomes especially important when combining multiple predicates.

---

# 29. Multiple Predicates

Consider:

```sql
SELECT *
FROM People
WHERE age = 2
  AND name LIKE 'A%';
```

We can estimate each predicate independently:

$$
P(age=2)
$$

and:

$$
P(name\ LIKE\ 'A\%')
$$

But we still need to estimate:

$$
P(age=2\ AND\ name\ LIKE\ 'A\%')
$$

---

# 30. Independence Assumption

A common assumption is that predicates are **independent**.

If:

$$
P(A\ AND\ B)
=
P(A)P(B)
$$

then the optimizer can multiply their selectivities.

### Example

Suppose:

$$
P(A)=0.10
$$

and:

$$
P(B)=0.20
$$

Then:

$$
P(A\ AND\ B)
=
0.10(0.20)
=
0.02
$$

So the estimated selectivity is:

```text
2%
```

---

# 31. AND Predicates

For:

```sql
WHERE A AND B
```

under the independence assumption:

$$
Sel(A\ AND\ B)
=
Sel(A)\times Sel(B)
$$

For three predicates:

$$
Sel(A\ AND\ B\ AND\ C)
=
Sel(A)Sel(B)Sel(C)
$$

### Important

This can become extremely small very quickly.

That is one reason cardinality estimates can become severely inaccurate.

---

# 32. OR Predicates

For:

```sql
WHERE A OR B
```

the basic probability relationship is:

$$
P(A\cup B)
=
P(A)+P(B)-P(A\cap B)
$$

If independence is assumed:

$$
P(A\cap B)=P(A)P(B)
$$

Therefore:

$$
P(A\cup B)
=
P(A)+P(B)-P(A)P(B)
$$

### Example

Suppose:

$$
P(A)=0.2
$$

$$
P(B)=0.3
$$

Then:

$$
P(A\cup B)
=
0.2+0.3-(0.2)(0.3)
$$

$$
=0.5-0.06
$$

$$
=0.44
$$

Estimated selectivity:

```text
44%
```

---

# 33. Correlated Attributes

The independence assumption can fail badly when two attributes are related.

### Example

Consider a car database:

```text
Make
Model
```

Suppose:

```text
Make = Honda
Model = Accord
```

There might be:

```text
10 different makes
100 different models
```

The optimizer might estimate:

$$
P(Make=Honda)=\frac{1}{10}
$$

and:

$$
P(Model=Accord)=\frac{1}{100}
$$

Under independence:

$$
\frac{1}{10}\times\frac{1}{100}
=
\frac{1}{1000}
$$

But this is incorrect because:

```text
Accord → Honda
```

The attributes are **correlated**.

If 1 out of 100 cars is an Accord, then:

$$
P(Honda\ AND\ Accord)
\approx
\frac{1}{100}
$$

rather than:

$$
\frac{1}{1000}
$$

---

# 34. Why Correlation Matters

Incorrect independence assumptions can cause estimates to be off by an **order of magnitude or more**.

For example:

```text
Actual:
1 / 100

Estimated:
1 / 1000
```

The optimizer believes there will be 10 times fewer rows than there actually are.

For a huge database, this can dramatically affect the query plan.

---

# 35. SQL Server's Approach to Multiple Predicates

The lecture discusses SQL Server's approach to dealing with multiple conjunctive predicates.

Rather than simply multiplying every selectivity equally, SQL Server can:

1. Rank predicates by selectivity.
2. Apply the most selective predicates first.
3. Reduce the influence of subsequent predicates using weighting factors.

The goal is to avoid estimates becoming unrealistically small.

This is a practical heuristic rather than a guarantee of statistical correctness.

---

# 36. Join Cardinality Estimation

Join estimation is one of the hardest parts of cardinality estimation.

Suppose:

```text
R ⋈ S
```

The optimizer needs to estimate:

```text
How many tuples will the join produce?
```

This is much harder than estimating a filter on one table because now values from **two relations** must be compared.

---

# 37. Join Difficulty

Join estimation becomes particularly difficult with:

### Primary key → Primary key

Usually easier.

### Primary key → Foreign key

More predictable because relationships are known.

### Many-to-many

Much harder.

Multiple tuples in `R` can match multiple tuples in `S`.

For example:

```text
R:
A
A

S:
A
A
```

The join can produce:

```text
4 tuples
```

because each `A` in `R` can match each `A` in `S`.

---

# 38. Containment Principle

The **containment principle** is an assumption used for join cardinality estimation.

The basic idea is:

> The values in one relation are assumed to be contained in the values of the other relation so that matching join values can be estimated.

This simplifies the problem.

Without assumptions like containment, the optimizer would have to know exactly which values exist in both relations.

---

# 39. Basic Join Cardinality Formula

A commonly used approximation for an equijoin is based on:

$$
|R\bowtie S|
\approx
\frac{|R|\times|S|}
{\max(V(R,A),V(S,B))}
$$

where:

* \(|R|\) = number of tuples in relation R
* \(|S|\) = number of tuples in relation S
* \(V(R,A)\) = number of distinct values of join attribute A in R
* \(V(S,B)\) = number of distinct values of join attribute B in S

Therefore:

$$
JoinCardinality
\approx
\frac{|R||S|}
{\max(V(R,A),V(S,B))}
$$

---

# 40. Join Cardinality Example

Suppose:

```text
R has 1,000 tuples
S has 500 tuples

V(R,A) = 100
V(S,B) = 50
```

Then:

$$
|R\bowtie S|
\approx
\frac{1000\times500}
{\max(100,50)}
$$

$$
=
\frac{500,000}{100}
$$

$$
=5,000
$$

Estimated join cardinality:

```text
5,000 tuples
```

Again, this is an approximation based on assumptions.

---

# 41. Query Plan Cardinality Estimation

Suppose the query plan looks conceptually like:

```text
        Join
       /    \
    Join     C
   /   \
  A     B
```

And suppose:

```text
B has a filter:
B.id > 100
```

The optimizer must estimate:

```text
A
↓
number of tuples

B
↓
filter
↓
number of tuples

A ⋈ B
↓
number of tuples

(A ⋈ B) ⋈ C
↓
final number of tuples
```

Each estimate becomes the input to the next operation.

---

# 42. Error Propagation

This is one of the most important concepts.

Suppose the optimizer underestimates:

```text
Join 1
```

That incorrect estimate becomes an input to:

```text
Join 2
```

Then the incorrect result becomes an input to:

```text
Join 3
```

and so on.

Therefore:

```text
Small error
    ↓
Join 1
    ↓
Larger error
    ↓
Join 2
    ↓
Even larger error
    ↓
Join 3
```

Errors can compound as the query plan gets deeper.

---

# 43. Why Bad Estimates Cause Bad Query Plans

The optimizer chooses physical operators based on estimated cardinalities.

For example:

```text
Estimated rows = 10
```

The optimizer might choose:

```text
Nested Loop Join
```

because a nested loop can be efficient for small inputs.

But suppose the actual result is:

```text
1,000,000 rows
```

Now the chosen join algorithm may perform very poorly.

The problem was not necessarily the join algorithm itself.

The problem was the **incorrect cardinality estimate**.

---

# 44. Nested Loop vs Hash Join

### Nested Loop Join

Generally useful when one input is relatively small.

Conceptually:

```text
For each tuple in outer table:
    search matching tuples in inner table
```

If the outer relation is tiny, this can be efficient.

---

### Hash Join

Generally useful when joining larger relations.

Conceptually:

```text
Build hash table
       ↓
Probe hash table
```

It can handle large inputs efficiently when sufficient memory is available.

---

# 45. Underestimating Cardinality

Suppose:

```text
Estimated = 10 rows
Actual = 1,000,000 rows
```

The optimizer might choose:

```text
Nested Loop Join
```

when a hash join would have been more appropriate.

Other problems can occur:

* Insufficient memory allocation
* Hash tables may need to grow
* Data may need to be copied
* More I/O may be required
* Execution may become much slower

---

# 46. Overestimating Cardinality

Overestimation causes different problems.

Suppose:

```text
Estimated = 1,000,000 rows
Actual = 10 rows
```

The optimizer may choose a hash join when a nested loop would have been cheaper.

It may also:

* Allocate more memory than necessary
* Build unnecessarily large structures
* Choose more expensive operators

Therefore, both underestimation and overestimation are problematic.

---

# 47. Adaptive Query Processing

**Adaptive Query Processing (AQP)** allows a database system to react when actual execution behavior differs significantly from the optimizer's estimates.

Conceptually:

```text
Optimizer
   ↓
Estimated 10 rows
   ↓
Start execution
   ↓
Actually seeing 1,000,000 rows
   ↓
Detect large error
   ↓
Adapt execution
```

---

# 48. Adaptive Join

One example is an **adaptive join**.

The optimizer might initially choose a nested loop because it expects:

```text
10 rows
```

But during execution:

```text
Actual rows > threshold
```

The system can switch toward a hash join strategy.

Conceptually:

```text
              Start
                ↓
        Estimate = small
                ↓
          Begin execution
                ↓
       ┌────────┴────────┐
       ↓                 ↓
Rows below threshold   Rows above threshold
       ↓                 ↓
Nested Loop             Hash Join
```

Systems such as SQL Server support forms of adaptive query processing.

---

# 49. Re-Optimization

Another possible strategy is:

```text
Start query
    ↓
Observe actual cardinalities
    ↓
Estimates are extremely wrong
    ↓
Stop execution
    ↓
Send information back to optimizer
    ↓
Generate a new query plan
    ↓
Restart
```

The advantage is that the optimizer gets better information.

The disadvantage is that work already completed may be thrown away.

Therefore, the system must determine whether the cost of re-optimization is worth it.

---

# 50. Thresholds for Adaptation

A database should not necessarily adapt every time an estimate is slightly wrong.

For example:

```text
Estimated = 100
Actual = 110
```

The difference may not matter.

But:

```text
Estimated = 100
Actual = 10,000,000
```

is a much more serious problem.

Therefore, adaptive systems can use thresholds based on things such as:

* Difference between estimated and actual cardinality
* Operator type
* Position in the query plan
* Amount of work already completed
* Amount of data being processed

---

# 51. Cost Models

A **cost model** uses estimated cardinalities to predict how expensive a query plan will be.

The optimizer is ultimately trying to estimate things such as:

```text
CPU work
I/O
Memory requirements
Data movement
Execution time
```

The basic chain is:

```text
Statistics
    ↓
Selectivity
    ↓
Cardinality
    ↓
Operator cost
    ↓
Query plan cost
    ↓
Choose plan
```

---

# 52. Why Cardinality Is So Important

Cardinality affects almost every major optimizer decision.

For example:

```text
Cardinality
    ↓
Join algorithm
    ↓
Memory requirements
    ↓
I/O requirements
    ↓
Execution cost
```

If cardinality is wrong, many downstream decisions can also be wrong.

---

# 53. Why Cost Models Are Difficult

Cost models must make assumptions because databases generally cannot store perfect information about every possible combination of values.

Common assumptions include:

### Uniformity

Values in a bucket occur approximately equally often.

### Independence

Predicates/attributes are assumed to be independent.

### Continuity

Values within a range are assumed to exist continuously.

### Containment

Join values are assumed to overlap sufficiently for the join estimation formula.

These assumptions make estimation tractable, but they can introduce errors.

---

# 54. The Fundamental Trade-Off

There is a trade-off between:

```text
Accuracy
      ↕
Storage + computation
```

Perfect statistics would be expensive.

Small statistical summaries are cheap but less accurate.

Therefore:

```text
More statistics
→ more storage/work
→ potentially better estimates

Less statistics
→ less storage/work
→ potentially worse estimates
```

---

# 55. Why Histograms Are So Common

Histograms are popular because they provide a practical balance:

```text
Reasonable accuracy
+
Low storage cost
+
Fast estimation
```

They are much cheaper than maintaining complete information about every value.

---

# 56. Why Sampling Can Be Powerful

Sampling has an important advantage:

> It directly examines actual data rather than relying entirely on assumptions about its distribution.

If the sample is representative, it can capture complicated relationships that a simple histogram may miss.

However:

```text
Bad / unrepresentative sample
        ↓
Bad estimate
```

Sampling also has a cost because the database must inspect data to obtain the sample.

---

# 57. Why ML-Based Cardinality Estimation Is Interesting

Traditional estimators often assume:

```text
Uniformity
Independence
Containment
```

Machine-learning models can potentially learn relationships directly from data.

For example:

```text
Make → Model
Age → Salary
City → ZIP Code
```

The model could learn that certain attributes are correlated.

However, according to the lecture, ML-based cardinality estimation is still relatively early compared with traditional production techniques.

---

# 58. Benchmarking Cardinality Estimators

Researchers can evaluate database systems using benchmark workloads.

The lecture discusses a benchmark based on the **IMDb database** and queries containing many joins.

The goal is to compare:

```text
Estimated cardinality
vs.
Actual cardinality
```

As more joins are added, estimation errors can become increasingly significant.

---

# 59. Underestimation Across Multiple Joins

A common pattern observed in research is that systems can increasingly underestimate cardinality as joins are added.

Conceptually:

```text
1 table
↓
small error

2 joins
↓
larger error

5 joins
↓
larger error

10+ joins
↓
potentially very large error
```

This occurs because estimates from earlier operators become inputs to later operators.

---

# 60. Main Takeaway From Cardinality Estimation

The optimizer does **not** know exactly how many tuples an operation will produce before running it.

Instead:

```text
Statistics
+
Assumptions
+
Formulas
=
Estimated Cardinality
```

Then:

```text
Estimated Cardinality
        ↓
Cost Model
        ↓
Query Plan
```

Therefore, bad statistics can lead to bad cardinality estimates, which can lead to bad query plans.

---

# 61. Important Formulas

### Selectivity

$$
Sel(P)=
\frac{\text{Matching tuples}}
{\text{Total tuples}}
$$

---

### Estimated Cardinality

$$
Cardinality =
N\times Sel(P)
$$

---

### Equality

$$
Sel(A=x)
=
\frac{Count(A=x)}{N}
$$

---

### NOT EQUAL

$$
Sel(A\neq x)
=
1-Sel(A=x)
$$

---

### AND

Under independence:

$$
Sel(A\land B)
=
Sel(A)Sel(B)
$$

---

### OR

Under independence:

$$
Sel(A\lor B)
=
Sel(A)+Sel(B)-Sel(A)Sel(B)
$$

---

### Join

A common simplified equijoin estimate:

$$
|R\bowtie S|
\approx
\frac{|R||S|}
{\max(V(R,A),V(S,B))}
$$

---

# 62. Important Assumptions to Memorize

| Assumption       | Meaning                                                           |
| ---------------- | ----------------------------------------------------------------- |
| **Uniformity**   | Values in a bucket are assumed to occur with similar frequency    |
| **Independence** | Predicates/attributes are assumed not to influence each other     |
| **Continuity**   | Values throughout a range are assumed to exist                    |
| **Containment**  | Join values are assumed to overlap sufficiently between relations |

These assumptions make the formulas manageable but can reduce accuracy.

---

# 63. Common Exam Question: Why Are Histograms Needed?

### Answer

Exact statistics for every distinct value can require too much storage.

Histograms compress the distribution into buckets so the optimizer can estimate selectivity and cardinality using much less storage.

---

# 64. Common Exam Question: Equi-Width vs Equi-Depth

### Equi-Width

```text
Same range width
Different number of tuples per bucket
```

### Equi-Depth

```text
Different range widths
Approximately same number of tuples per bucket
```

### Remember

```text
WIDTH → numerical range
DEPTH → number of tuples
```

---

# 65. Common Exam Question: What Is Selectivity?

**Selectivity** is the fraction/probability of tuples that satisfy a predicate.

Example:

```text
100 total rows
20 matching rows
```

$$
Selectivity=\frac{20}{100}=0.20
$$

Therefore:

```text
Selectivity = 20%
```

---

# 66. Common Exam Question: What Is Cardinality?

Cardinality is the number of tuples produced by an operation.

Example:

```text
1,000 input rows
Selectivity = 0.10
```

Then:

$$
Cardinality=1000(0.10)=100
$$

Estimated output:

```text
100 rows
```

---

# 67. Common Exam Question: Why Is Independence Dangerous?

Suppose:

```text
Make = Honda
Model = Accord
```

The two attributes are correlated because an Accord is associated with Honda.

Multiplying:

$$
P(Honda)P(Accord)
$$

treats them as unrelated and can dramatically underestimate the true number of matching tuples.

---

# 68. Common Exam Question: Why Do Errors Get Worse With More Joins?

Because the estimated output of one operator becomes the estimated input of the next operator.

```text
Bad estimate
    ↓
Join
    ↓
Bad estimate
    ↓
Another join
    ↓
Even worse estimate
```

Therefore, errors can compound as the query plan grows.

---

# 69. Common Exam Question: What Happens if Cardinality Is Underestimated?

Possible consequences:

* Choosing nested loop instead of hash join
* Allocating too little memory
* Hash table growth
* Additional copying
* Increased I/O
* Poor execution performance

---

# 70. Common Exam Question: What Happens if Cardinality Is Overestimated?

Possible consequences:

* Choosing hash join instead of nested loop
* Allocating too much memory
* Building unnecessarily large structures
* Choosing an unnecessarily expensive query plan

---

# 71. Big Picture

The entire process can be summarized as:

```text
                 TABLE DATA
                     │
                     ▼
              Collect Statistics
                     │
       ┌─────────────┼─────────────┐
       ▼             ▼             ▼
   Histograms      Sketches     Sampling
       │             │             │
       └─────────────┼─────────────┘
                     ▼
              Estimate Selectivity
                     │
                     ▼
             Estimate Cardinality
                     │
                     ▼
              Estimate Operator
                   Costs
                     │
                     ▼
              Compare Query Plans
                     │
                     ▼
             Choose Query Plan
                     │
                     ▼
                 Execute
```

---

# 72. Final Study Summary

### Know these terms

* **Cardinality** → number of tuples
* **Selectivity** → fraction/probability of tuples matching a predicate
* **Histogram** → summary of value frequencies
* **Equi-width** → equal bucket widths
* **Equi-depth** → approximately equal tuple counts
* **Heavy hitter** → very frequent value
* **Sketch** → compact probabilistic data structure
* **Count-Min Sketch** → frequency estimation
* **HyperLogLog** → distinct-value estimation
* **Sampling** → estimate statistics from a subset
* **Uniformity** → values in a bucket assumed equally likely
* **Independence** → predicates assumed unrelated
* **Containment** → join values assumed to overlap
* **Adaptive Query Processing** → adjust execution when actual data differs from estimates

### Know these formulas

$$
Selectivity=
\frac{Matching}{Total}
$$

$$
Cardinality=N\times Selectivity
$$

$$
Sel(A\neq x)=1-Sel(A=x)
$$

$$
Sel(A\land B)=Sel(A)Sel(B)
$$

$$
Sel(A\lor B)
=
Sel(A)+Sel(B)-Sel(A)Sel(B)
$$

$$
|R\bowtie S|
\approx
\frac{|R||S|}
{\max(V(R,A),V(S,B))}
$$

### Most important concept

The optimizer is making **educated estimates**, not knowing the exact future result.

```text
Statistics
     ↓
Assumptions
     ↓
Cardinality Estimates
     ↓
Cost Estimates
     ↓
Query Plan
```

If the estimates are wrong, the optimizer can choose the wrong plan. As more joins are added, those errors can compound and potentially produce very poor query performance.
