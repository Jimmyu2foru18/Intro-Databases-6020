# Query Nesting and Unnesting

## What Is Query Nesting?

SQL allows you to write queries inside other queries. When an inner subquery references columns or values from the outer query, it creates a correlation.

**Example:** A query might inspect a customer record and then run a separate count query specifically for that single customer's orders.

## Problem Statement: Performance

Database engines handle correlated subqueries by executing a dependent join. A dependent join evaluates the right-hand side of the query separately for every single row produced on the left-hand side. This functions like a nested loop.

The runtime complexity for this approach is quadratic, meaning execution time grows exponentially as the data size increases. On large databases containing hundreds of thousands of rows, this causes query execution times to blow up from milliseconds to many minutes.

## Optimization Through Unnesting

**Query unnesting process:** Using a program to optimize the database to rewrite a query containing dependent joins into an equivalent query that is a regular join statement.

**Optimization steps:**

- The optimizer identifies non-trivial dependent joins where an inner expression accesses outer attributes.
- It determines the distinct domain of the free variables required from the outer query.
- It transforms the dependent join into a combination of regular joins and domain evaluations.
- It pushes the operations down the relational algebra tree until the inner expression no longer depends on the outer query.
- Once correlation is eliminated, the database executes the query using fast standard join algorithms instead of nested loops, dropping the complexity and speeding up execution by orders of magnitude.

## Relational Algebra

**Example:** Find all employees who earn more than the average salary of their respective departments.

In a subquery, the inner expression compares the average salary using an outer reference to the department ID:

- `SELECT * FROM employees e WHERE salary > (SELECT AVG(salary) FROM employees WHERE d_id = e.d_id)`

This is represented by using a dependent join operator:

- `employees ⟕ (π AVG(salary) (σ d_id = e.d_id (employees)))`

To unnest this, the optimizer rewrites the inner aggregation into a separate pre-aggregated relation:

- `grouped_salaries = γ d_id, AVG(salary) AS avg_sal (employees)`

The query then replaces the dependent join with a standard equi-join:

- `employees ⨝ (employees.d_id = grouped_salaries.d_id AND employees.salary > grouped_salaries.avg_sal)`

This eliminates the row-by-row dependency, allowing the database to execute a hash join or merge join instead of a nested loop.

## Join Order Benchmark (JOB)

The Join Order Benchmark (JOB) is a standardized test suite used to evaluate how efficiently a database query optimizer determines the execution order for queries involving many tables. It uses a complex, real-world dataset derived from IMDb, containing dense networks of foreign key relationships.

### The Performance Problem

When a query joins ten or more tables, the number of possible join order permutations grows factorially. Database optimizers rely on cost estimation models to pick the fastest execution plan. With complex schemas, optimizers frequently miscalculate statistics, choose poor join paths, and lock up execution for minutes or hours.

We can use the JOB to test the LLM-unnested queries, improve speed and execution, and lower plan costs compared to the native database optimizer running the original nested queries.

## Prompt Engineering

Prompt engineering is the practice of designing, structuring, and refining text inputs to guide a large language model to produce precise, reliable, and structurally valid outputs.

### The Reliability Problem

Large language models are probabilistic text predictors. If you ask an LLM to rewrite a complex SQL query without constraints, it might introduce syntax errors, alter business logic, or hallucinate non-existent table columns.

### How It Works for SQL Unnesting

To make an LLM act as a reliable query optimizer, your prompts enforce strict constraints:

**What needs to be done:**

- Define rules requiring the model to follow relational algebra principles, like converting dependent joins into explicit inner joins with pre-aggregation.
- Restrict output so the model returns only valid SQL code without conversational filler, allowing automated parsers to validate the syntax immediately before DB execution.

## Project Plan: LLM SQL Query Nesting and Unnesting Optimization

### TODO

**Part 1: LLM Prompt Engineering and Rewriting Pipeline**

- [x] Write system prompts for unnesting dependent joins into explicit joins with pre-aggregation
- [x] Add syntax and semantic validation before database execution

**Part 2: Benchmarking**

- [ ] Run original and LLM-generated queries against the benchmark database
- [ ] Collect execution time and memory metrics
- [ ] Log results

**Part 3: Find the Stats**

- [ ] Correctness rate
- [ ] Performance speedup
- [ ] Cost efficiency

## Benchmarking the Two Query Forms

`benchmark_queries.py` runs every query in `nested_queries.sql` and its generated partner in
`unnested_queries.sql` against the same database and reports which structure is cheaper.

### Metrics

| Metric | Source | Meaning |
|---|---|---|
| Execution time | `Execution Time` from the plan | Server-side cost, excluding result transfer |
| Buffers | `Shared Hit Blocks` + `Shared Read Blocks` | I/O and cache traffic |
| Rescans | largest `Actual Loops` in the plan | Above 1 signals a surviving dependent join |

Timing is taken from the server rather than the client, so transferring a large result set does not
distort the comparison. The first of `--runs` executions is discarded as cache warm-up and the
median of the rest is reported.

### Running

```bash
pip install -r requirements.txt

# once, to point at your local copy of the IMDb database:
# add DATABASE_URL to .env, or pass --dsn

python benchmark_queries.py
python benchmark_queries.py --runs 10
```

The IMDb dump (`imdb.sql`) uses MySQL syntax; load it into PostgreSQL with the `USE imdb;`,
`SET FOREIGN_KEY_CHECKS=0;` and `START TRANSACTION;` lines removed.

### Reading the output

```
QID    nested ms  unnested ms  speedup   buffers n/u  u.loops
Q01        240.0         16.0   15.00x       220/220        1
Q11            -            -        -             -        -  relation "movie_directors" does not exist

15 queries | unnested faster: 11 | errors: 2 | 5 runs each
```

`speedup` is nested time divided by unnested time, so above `1.00x` means the rewrite won.
`u.loops` is the dependent-join signal: a correctly unnested plan scans each side once. A row
reporting an error failed at the database, which is itself a finding — several generated rewrites
reference tables or columns that do not exist in the schema.
