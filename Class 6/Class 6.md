# Day 6: Relational Algebra

Today's class introduces **relational algebra**, the procedural, mathematical
foundation of relational query languages. Relational algebra defines a small set
of operators that take one or more relations as input and produce a single relation
as output. We cover the core operators — selection, projection, cross product,
renaming, and natural join — the idea that operators are **compositional**. We also
explain derived operators that can be built from the core ones. Each operator is
illustrated with concrete relational instances, relational-algebra notation, and
equivalent SQL.


## 1. What is Relational Algebra

Relational algebra is a **procedural** language: you describe *how* to get the
answer by composing operators. Every operator takes relation(s) in and returns a
relation out. This **closure property** means you can always chain operators together
— the result of one operation feeds directly into the next.

The five core relational-algebra operators are:

| Operator | Symbol | Purpose | Operates on |
|---|---|---|---|
| Selection | σ (sigma) | Pick matching rows | Rows (tuples) |
| Projection | π (pi) | Pick specific columns | Columns (attributes) |
| Cross product | × | Pair every tuple | Two relations |
| Renaming | ρ (rho) | Change names | Schema only |
| Natural join | ⋈ | Join on common attrs | Two relations |

Because every operator returns a relation, relational algebra expressions are
**compositional** (Section 4). This is what lets you build complex queries from simple
building blocks.

> **Key takeaway:** Relational algebra has a handful of simple operators that combine
to express any relational query. The fact that operators output relations (closure)
is what makes composition possible.

## 2. Selection (Sigma, σ)

**Selection** filters rows. It returns only the tuples (rows) that satisfy a
predicate condition. Selection never changes the schema — the output has exactly the
same columns as the input.

**Notation:** `σ_condition(R)` — "the tuples of R for which *condition* is true."

- The result always contains the full schema of R (all attributes).
- Selection never removes duplicate rows — each matching tuple is kept as-is.
- Selection is unary: it takes one relation as input.

**Relational instance:** `Employees(ssn, name, salary)`

```text
ssn      name      salary
-------- --------- --------
111-22   Alice     68000
222-33   Bob       72000
333-44   Carol     68000
444-55   Dan       54000
```

**Selection: employees earning more than 65000.**

Relational algebra:
```
σ_salary > 65000(Employees)
```

SQL equivalent:
```sql
SELECT * FROM Employees WHERE salary > 65000;
```

Result (full schema retained, only matching rows, duplicates kept):
```text
ssn      name      salary
-------- --------- --------
111-22   Alice     68000
222-33   Bob       72000
333-44   Carol     68000
```

> **Key takeaway:** Selection is a row filter (σ). It keeps full rows and the full
schema; it only reduces the number of tuples, not the number of attributes.

## 3. Projection (Pi, π)

**Projection** picks specific columns and discards the rest. Unlike selection,
projection operates on **attributes (columns)**, not rows.

**Notation:** `π_attribute-list(R)` — "the values of the listed attributes from R."

Two important behaviors distinguish projection from selection:

1. **It eliminates columns** — the output schema contains only the listed attributes.
2. **It removes duplicates** — because the result is a relation (a set of tuples),
   if two rows collapse to identical values on the projected columns, only one
   survives.

**Relational instance:** `Employees(ssn, name, salary)`

```text
ssn      name      salary
-------- --------- --------
111-22   Alice     68000
222-33   Bob       72000
333-44   Carol     68000
444-55   Alice     54000
```

**Projection: list only the `name` and `salary` columns.**

Relational algebra:
```
π_name, salary(Employees)
```

SQL equivalent:
```sql
SELECT name, salary FROM Employees;
```

Step-by-step:
1. Extract `name` and `salary` from each row.
2. Remove duplicate tuples.

Result (note: `Alice` appears once even though salary differs — the two rows
`(Alice, 68000)` and `(Alice, 54000)` are distinct tuples and both survive):
```text
name      salary
--------- --------
Alice     68000
Bob       72000
Carol     68000
Alice     54000
```

Now project just `salary`:
```
π_salary(Employees)
```
```text
salary
--------
68000
72000
54000
```

The three employees earning 68000 (Alice and Carol) collapse to a single `68000` row.

> **Key takeaway:** Projection is a column selector (π). It narrows the schema and
always removes duplicate rows, leaving only distinct tuples.

## 4. Compositional Operators

Relational algebra operators are **compositional**, meaning the output of one operator
can be used as the input to another, just like arithmetic operators. You can nest
expressions to express multi-step logic.

**Relational instance:** `Students(sid, name, gpa)`

```text
sid  name      gpa
---- --------- ----
1    Alice     3.7
2    Bob       3.2
3    Carol     3.9
4    Dan       2.8
```

**Query:** "Find the names of students with GPA above 3.5."

This requires two steps: first filter (selection), then pick a column (projection).
In relational algebra you write it as a nested expression:

```
π_name( σ_gpa > 3.5(Students) )
```

Read inside-out: select students with GPA > 3.5, then project to name. The result:
```text
name
---------
Alice
Carol
```

**Relational diagram of composition:**

```text
+----------------------------------+
| Students                         |
| sid (PK)                         |
| name                             |
| gpa                              |
+----------------------------------+
        |
        |  σ_gpa > 3.5   (filter rows)
        v
+----------------------------------+
| Students (filtered)              |
| sid  name      gpa                |
| 1    Alice     3.7                |
| 3    Carol     3.9                |
+----------------------------------+
        |
        |  π_name   (narrow columns)
        v
+----------------------------------+
| Result                           |
| name                             |
| Alice                            |
| Carol                            |
+----------------------------------+
```

### Does order matter? σ then π vs π then σ

A natural question: what is the difference between applying **selection after
projection** versus **projection after selection**?

Consider the two expressions:
- `π_name(σ_gpa > 3.5(Students))` — selection first, then projection
- `σ_gpa > 3.5(π_name,gpa(Students))` — projection first, then selection

These differ because **projection discards columns**. If the selection condition
references an attribute that projection removes, the second form is either
impossible (the column no longer exists) or means something different.

**Rule of thumb:**

- **σ then π is always safe** — you filter on all columns, then drop what you don't
  need. All attributes needed for the condition are still available.
- **π then σ is safe only if π keeps every attribute the σ condition references.**
  If π drops a column that σ needs, the expression is invalid.

**Example: students above 3.5 GPA, showing name and GPA.**

`π_name,gpa(σ_gpa > 3.5(Students))` — safe and correct:
```text
name      gpa
--------- ----
Alice     3.7
Carol     3.9
```

`σ_gpa > 3.5(π_name(Students))` — invalid, because π_name drops `gpa`, so σ cannot
reference it.

However, if the projected columns **include** everything σ needs, the final result
is the same either way (though intermediate duplicates differ).

**Arrow summary — when both orders are valid:**

```text
Students  --π_name,gpa-->  Students'  --σ_gpa>3.5-->  name | gpa
Students  --σ_gpa>3.5-->  Students''  --π_name,gpa-->  name | gpa
```

Both paths produce the same final relation when the projection preserves the
attributes referenced by σ.

> **Key takeaway:** Relational algebra is compositional — operators nest freely.
> Selection (σ) is always safe to apply first; projection (π) first is only safe when
> it keeps the columns the selection needs. Order matters when projected attributes
> overlap with selection conditions.

## 5. Cross Product (×)

The **cross product** (also called Cartesian product) pairs every tuple in the first
relation with every tuple in the second. If R has m rows and S has n rows, the result
has **m × n** rows.

**Notation:** `R × S`

- The result schema is the concatenation of both schemas: all attributes of R
  followed by all attributes of S.
- If R and S happen to have attributes with the same name, the result disambiguates
  them (e.g., by prefixing with the relation name).
- Cross products are **rarely useful on their own** because the result ignores
  meaning — it pairs everything with everything. They are mainly a building block for
  joins.

**Relational instances:**

`SSNs(ssn, name, address)`

```text
ssn      name      address
-------- --------- ----------------
111-22   Alice     123 Main St
222-33   Bob       456 Oak Ave
```

`Enrollments(sid, pname, gpa)`

```text
sid  pname   gpa
---- ------- ----
1    Alice   3.7
2    Bob     3.2
```

**Cross product `SSNs × Enrollments`** pairs each SSN row with each Enrollments row:

```text
ssn      name      address         sid  pname   gpa
-------- --------- ---------------- ---- ------- ----
111-22   Alice     123 Main St       1    Alice   3.7
111-22   Alice     123 Main St       2    Bob     3.2
222-33   Bob       456 Oak Ave       1    Alice   3.7
222-33   Bob       456 Oak Ave       2    Bob     3.2
```

2 rows × 2 rows = 4 rows. Notice the pairing is blind — "Alice from SSNs" is paired
with "Bob from Enrollments," which has no real-world meaning.

**Arrow summary:**

```text
SSNs                Enrollments
(ssn,name,address) x (sid,pname,gpa)
     2 rows          x  2 rows
              = 4 rows (all combinations)
```

SQL equivalent:
```sql
SELECT * FROM SSNs CROSS JOIN Enrollments;
```

> **Key takeaway:** Cross product (×) pairs every tuple with every other tuple,
producing m × n rows. It is rarely used directly because it ignores meaning; it is
primarily a building block for joins.

## 6. Renaming (Rho, ρ)

**Renaming** changes the **name** of a relation or one of its attributes. It
changes the **schema** without altering the **instance** (the data stays the same).

**Notation:**

- `ρ_newName(R)` — rename the whole relation R to *newName*.
- `ρ_newName(attr1, attr2, ...)(R)` — rename the relation to *newName* and rename
  its attributes to *attr1, attr2, ...* in order.
- `ρ_newName[attr1, attr2](R)` — a shorthand that renames only specific attributes.

**Relational instance:** `Students(sid, sname, gpa)`

```text
sid  sname   gpa  ptavg
---- ------- ---- -----
1    Alice   3.7  3.9
2    Bob     3.2  3.1
```

**Rename the table and its columns** to make output more readable:

Relational algebra:
```
ρHonors(sid, name, gpa, ptavg)(Students)
```

SQL equivalent:
```sql
SELECT sid AS student_id,
       sname AS name,
       gpa,
       ptavg
FROM Students;
```

Result (rename `Students` to `Honors`, alias `sname` to `name`):
```text
sid  name    gpa  ptavg
---- ------- ---- -----
1    Alice   3.7  3.9
2    Bob     3.2  3.1
```

Renaming is especially useful when you need the same relation multiple times in a
query (e.g., comparing a table to itself — a "self-join"). Without renaming, you
cannot refer to two copies of the same table unambiguously.

> **Key takeaway:** Renaming (ρ) changes names, not data. It modifies the schema
(relation name or attribute names) while leaving the instance untouched. It is
essential for self-joins and for producing human-readable output.

## 7. Natural Join (⋈)

The **natural join** combines two relations by matching tuples that share equal
values on all attributes with the **same name**. Unlike the cross product, it
actually pairs meaningful rows.

**Notation:** `R ⋈ S` — the natural join of R and S.

Formal definition: `R ⋈ S = σ_R ⋈_condition S` where the condition is "all
same-named attributes are equal," followed by removing the duplicate columns.
Equivalently, the natural join is a cross product **restricted** to matching rows and
**deduplicated** on common attributes:

```
R ⋈ S = π_schema(R) ∪ schema(S) ( σ_matching_condition ( R × S ) )
```

**Relational instances:**

`SSNs(ssn, name, address)`

```text
ssn      name      address
-------- --------- ----------------
111-22   Alice     123 Main St
222-33   Bob       456 Oak Ave
```

`Enrollments(sid, pname, gpa)` — note: `name` and `pname` are different attribute
names, so they are **not** a natural join column.

```text
sid  pname   gpa
---- ------- ----
1    Alice   3.7
2    Bob     3.2
```

Because the two relations share no common attribute **names**, the natural join here
reduces to a cross product with all 4 rows. But typically, the relations share at
least one key attribute.

**Natural join on shared key — `Orders` and `Customers`:**

`Orders(order_id, customer_id, amount)`

```text
order_id  customer_id  amount
--------  -----------  -------
1001      501          45.00
1002      501          30.00
1003      502          12.50
```

`Customers(customer_id, customer_name, city)`

```text
customer_id  customer_name  city
-----------  --------------- --------
501          Alice          Chicago
502          Bob            Denver
```

Both tables share `customer_id`. The natural join matches on it and merges:

`Orders ⋈ Customers`
```text
order_id  customer_id  amount   customer_name  city
--------  -----------  -------  --------------- --------
1001      501          45.00    Alice          Chicago
1002      501          30.00    Alice          Chicago
1003      502          12.50    Bob            Denver
```

Notice:
- Only rows where `customer_id` matches survive (no "lost" unmatched rows here, but
  unmatched rows would be dropped).
- `customer_id` appears once in the output (common column deduplicated).

SQL equivalent:
```sql
SELECT *
FROM Orders
NATURAL JOIN Customers;
```

**Arrow summary:**

```text
Orders   ─── join on customer_id ───►  Orders ⋈ Customers
(order_id,  (shared: customer_id)          (order_id, customer_id,
 customer_id,                            amount, customer_name, city)
 amount)
```

### Natural Join on a shared Name attribute: Student ⋈ People

Now consider a natural join where **Name** is the common attribute between two
relations of different entity types:

`Student(sid, Name, gpa)`

```text
sid  Name   gpa
---- ------ ----
1    Alice   3.7
2    Bob     3.2
3    Carol   3.9
4    Eve     3.5
```

`People(Name, address, phone)`

```text
Name   address            phone
------ ------------------ --------
Alice  123 Main St        555-0101
Bob    456 Oak Ave        455-0102
Carol  789 Pine Rd        555-0103
Dave   321 Elm St         555-0104
```

Both tables share the attribute `Name`. The natural join matches rows where `Name`
is equal across both tables, and `Name` appears once in the output:

`Student ⋈ People`

```text
sid  Name   gpa   address            phone
---- ------ ---- ------------------ --------
1    Alice   3.7 123 Main St        555-0101
2    Bob     3.2 456 Oak Ave        555-0102
3    Carol   3.9 789 Pine Rd        555-0103
```

This is an **inner** natural join: unmatched tuples are dropped.
- **Eve** is dropped because there is no person named "Eve."
- **Dave** is dropped because there is no student named "Dave."

The resulting schema merges both tables and deduplicates `Name`:

```text
(sid, Name, gpa, address, phone)
```

SQL equivalent:
```sql
SELECT *
FROM Student
NATURAL JOIN People;
```

**Arrow summary:**

```text
Student ──── join on Name ───►  Student ⋈ People
(sid, Name,                    (sid, Name, gpa,
  gpa)                          address, phone)
```

> **Key takeaway:** Natural join (⋈) pairs tuples from two relations on all
attributes with matching names. It is a cross product **restricted** to matching
rows, with the shared columns appearing once in the output. Unmatched tuples on
either side are dropped (inner join semantics).

## 8. Derived Relational Algebra Operators

The five core operators above are called **basic** or **primitive**. Every other
relational operator can be expressed as a combination of them. These additional
operators are called **derived operators**.

The most common derived operators are:

| Derived operator | Symbol | Definition (built from core operators) |
|---|---|---|
| Set union | ∪ | R ∪ S (adds matching tuples) |
| Set difference | − | R − S (tuples in R not in S) |
| Set intersection | ∩ | R ∩ S = R − (R − S) |
| Assignment | ← | temp ← R (stores a result under a name) |
| Renaming | ρ | (already covered — can also be derived) |
| Dividend (÷) | ÷ | R ÷ S = π_other(R) − π_other((π_other(R) × S) − R) |

Important constraints on the **set operators** (union, intersection, difference):
both operands must have the **same number of attributes** (same arity) and
**compatible domains** (types must match column-by-column).

### Derived example: Set Difference (R − S)

Using our two tables again:

`SSNs(ssn, name, address)`

```text
ssn      name      address
-------- --------- ----------------
111-22   Alice     123 Main St
222-33   Bob       456 Oak Ave
```

`Enrollments(sid, pname, gpa)`

```text
sid  pname   gpa
---- ------- ----
1    Alice   3.7
2    Bob     3.2
```

Direct difference `SSNs − Enrollments` is **invalid** because the schemas differ
(3 attributes vs 3 attributes, but names/types differ). Derived operators require
**union compatibility**. So we project both to the same schema first:

```
π_name(SSNs) − π_pname(Enrollments)
```

- `π_name(SSNs)` = `{Alice, Bob}`
- `π_pname(Enrollments)` = `{Alice, Bob}`
- Difference = `{}` (empty — both sets are identical)

If we had an employee "Carol" in `SSNs` who was not enrolled:

```
π_name(SSNs) − π_pname(Enrollments)  =  {Carol}
```

SQL equivalent:
```sql
(SELECT name FROM SSNs)
MINUS
(SELECT pname FROM Enrollments);
```

### Derived example: Set Intersection via Difference

`R ∩ S` can always be written as `R − (R − S)`:
- `R − S` = tuples in R but not in S.
- `R − (R − S)` = tuples in R that ARE in S = `R ∩ S`.

**Arrow summary:**

```text
R ∩ S  =  R − (R − S)
(tuples  (tuples   (tuples in R       (tuples in both
in both   in R      not in S)          R and S)
R and S)          removed)
```

### Derived example: Assignment

The **assignment operator** lets you name an intermediate result so you can reuse it:

```
temp ← σ_gpa > 3.0(Students)
TopStudents ← π_name(temp)
```

This is analogous to a CTE (common table expression) or subquery in SQL:

```sql
WITH temp AS (
    SELECT * FROM Students WHERE gpa > 3.0
)
SELECT name FROM temp;
```

### Derived example: Set Union (R ∪ S)

**Set union** combines the tuples of two relations into a single relation. Because
relations are sets, the result contains each tuple only once — duplicates are
removed.

**Formal notation:** `R ∪ S` — "the set of all tuples that are in R, in S, or in
both."

**Definition (relational algebra):**

```
R ∪ S = { t | t ∈ R  or  t ∈ S }
```

The same constraints that govern difference and intersection apply to union:

- Both R and S must be **union-compatible**: the same number of attributes (same
  arity), and corresponding attributes must have compatible domains (types).
- The schema of the result is the schema of R (the first operand).
- Duplicate tuples are eliminated — union operates on sets, not multisets.

**Relational instances:**

`CS_Students(Name)` — students majoring in Computer Science

```text
Name
------
Alice
Bob
Carol
```

`Math_Students(Name)` — students majoring in Math

```text
Name
------
Bob
Dave
Eve
```

**Union: all students majoring in CS or Math.**

Relational algebra:
```
CS_Students ∪ Math_Students
```

Step-by-step:
1. Combine all tuples from both relations.
2. Remove duplicates (Bob appears in both — kept once).

Result:
```text
Name
------
Alice
Bob
Carol
Dave
Eve
```

SQL equivalent:
```sql
SELECT Name FROM CS_Students
UNION
SELECT Name FROM Math_Students;
```

> **Note:** `UNION ALL` in SQL is the multiset version — it keeps duplicates.
Standard relational algebra (and `UNION`) always removes duplicates.

**Arrow summary:**

```text
CS_Students  ──∪──►  CS_Students ∪ Math_Students
                     (duplicates: Bob merged)
Math_Students
```

> **Key takeaway:** Set union (∪) combines tuples from two relations into one,
removing duplicates. It requires union-compatible operands (same arity and
compatible types), and the result inherits the schema of the first operand.

> **Key takeaway:** Derived operators (union, difference, intersection, assignment,
> division) are all expressible as combinations of the core operators. The set
operators require union-compatible schemas (same arity and compatible types), and
the assignment operator lets you name intermediate results for reuse — just like
CTEs and subqueries in SQL.

## 9. Relational Algebra Architecture and Plan Execution

Relational algebra is not just a mathematical notation — it is the foundation for
how database systems actually execute queries. The **query-processing architecture**
turns a high-level query into an efficient execution plan in three stages:

```text
User query (SQL)
      |
      v
[1. Parsing & Translation]  ->  algebraic expression tree (RA operators)
      |
      v
[2. Query Optimization]       ->  optimized plan (logical + physical)
      |
      v
[3. Query Execution]          ->  results
```

### Stage 1 — Parsing and Translation

The query is parsed into a syntactic tree and then translated into a **relational
algebra expression tree**. Each node in the tree is an operator (σ, π, ⋈, etc.). For
example, `SELECT name FROM Students WHERE gpa > 3.5` becomes:

```
π_name(σ_gpa > 3.5(Students))
            |
            v
    [π_name] ← [σ_gpa > 3.5] ← [Students]
```

### Stage 2 — Query Optimization

The optimizer transforms the expression tree into an **equivalent but more efficient
plan** in two layers:

1. **Logical optimization** — rewrite the expression using algebraic equivalences:
   - Push selections down (apply σ as early as possible to reduce tuple count).
   - Project early (apply π as early as possible to reduce column count).
   - Reorder joins to minimize intermediate results.

2. **Physical optimization** — choose concrete implementations for each logical
   operator:
   - Which access method (full scan vs index scan)?
   - Which join algorithm (nested-loop, hash join, sort-merge join)?
   - Which operator variant (e.g., index-based selection vs. sequential scan)?

The optimizer uses **statistics** (row counts, index availability, data
distributions) to estimate the cost of each candidate plan and picks the cheapest.

### Stage 3 — Query Execution

The optimized plan is evaluated against the actual data. At this stage the logical
operators from relational algebra get **physical implementations** that decide *how*
to access and process data. The next three subsections cover the key physical
strategies for large tables: index access, projection-based hashing, and sort-based
processing.

### RA Plan Execution: Index-Based Access for Large Tables

When a table is large, a **full table scan** (reading every tuple) can be expensive.
An **index** allows the system to jump directly to relevant tuples.

Two common access patterns:

| Access pattern | Condition | Index type | Complexity | RA notation |
|---|---|---|---|---|
| Point query | `WHERE id = 5` | Hash index | O(1) | `IndexSelect_{id=5}(R)` |
| Range query | `WHERE salary > 65000` | B+ tree | O(log n + k) | `IndexSelect_{salary>65000}(R)` |

**Example:** `Employees(ssn, name, salary)` with a B+ tree index on `salary`.

```text
                   B+ Tree Index on salary
                   (leaf nodes point to tuple locations)

   60K  65K  68K  70K  72K  75K
   |     |    |     |    |    |
   v     v    v     v    v    v
  Dan   Alice Carol Bob  ...

  σ_salary > 65000  ->  IndexSelect jumps to 65K+ leaf,
                       scans right: Alice(68K), Bob(72K), ...
```

The index lets the system find matching tuples **without reading the whole table** —
critical for large tables. In the execution plan, this is a **physical selection**
(`IndexSelect`) instead of a logical `Scan` operator.

### RA Plan Execution: Projection for Hashing

When a query projects only a few columns from a large table, the system can use
**hash-based projection** to reduce memory and enable fast downstream processing:

1. **Reduce data volume** — load and hash only the projected columns, not the entire
   tuple. With many wide columns, this can cut I/O dramatically.
2. **Hash-based deduplication** — build a hash table on the projected columns; tuples
   with the same hash bucket collapse to one (implements π's duplicate removal).
3. **Feed hash-based algorithms** — the hashed projection directly feeds:
   - **Hash joins** — build a hash table on one relation's join key, probe with the other.
   - **Hash aggregation** — GROUP BY uses the same hashing principle.

**Example:** `π_ssn, name(Employees)` on a 10-million-row table with 10 columns.

```text
Logical plan:
  π_ssn, name(Employees)

Physical plan with hashing:
  [Full Scan or Index Scan on Employees]
        |
        v
  [Hash Project: ssn, name]  -- hash on (ssn, name)
        |
        v
  [Hash Table]  -- duplicates removed
        |
        v
  Result (distinct ssn/name pairs)
```

Instead of materializing full tuples (all 10 columns), the system hashes tuples on
just `(ssn, name)`, keeping only distinct hash buckets in memory.

> **Key takeaway:** Projection is not just about dropping columns — when implemented
physically, hashing the projected columns enables efficient duplicate elimination and
feeds hash-based join and aggregation algorithms.

### RA Plan Execution: Sort-Based Strategies

**Sorting** a relation on specific attributes enables several physical optimizations:

1. **Sort-merge join** — sort both inputs by the join key, then merge them in a
   single pass. Cost is O(n log n + m log m), which beats nested-loop O(n × m) for
   large inputs.

2. **Sort-based duplicate elimination** — sort tuples on all projected attributes,
   then scan once, removing adjacent duplicates. This implements π's set semantics
   efficiently without a hash table.

3. **Sorted output / ORDER BY** — if the query requires ordering, sorting early lets
   the system skip a final sort pass.

4. **Sorted index access** — an index scan on a B+ tree already returns tuples in
   sorted order, avoiding an explicit sort operator.

**Example:** `σ_gpa > 3.5(Students)` followed by `ORDER BY name`.

```text
Logical plan:
  π_name(σ_gpa > 3.5(Students))  -- ordered by name

Physical plan with sort:
  [Scan Students]
        |
        v
  [Filter: gpa > 3.5]         -- selection pushed early
        |
        v
  [Hash Project: name]        -- or sort project
        |
        v
  [Sort on name]              -- enables sorted output
        |
        v
  Result
```

**Arrow summary:**

```text
Logical:      π_name,gpa  ←  σ_gpa>3.5  ←  Students
                          (push selection down)

Physical:    [Scan] → [Select via Index] → [Hash Project] → [Sort] → [Output]
```

> **Key takeaway:** Sort-based strategies leverage existing order (from an index or
an explicit Sort operator) to enable merge joins, duplicate elimination, and sorted
output — often cheaper than hash-based alternatives when data is already ordered or
when the query requires sorted results.

### Putting It Together: Physical Plan Example

Consider: `SELECT DISTINCT name FROM Students WHERE gpa > 3.5;`

Logical RA: `π_name(σ_gpa > 3.5(Students))`

A physical plan might choose:

```text
Students
  |
  | [IndexSelect on gpa > 3.5 using B+ tree index on gpa]
  v
FilteredStudents (fewer rows, full schema)
  |
  | [Project: name only — reduce columns; use hashing for dedup]
  v
Result (distinct names, sorted if needed)
```

The optimizer picks **index selection** (because gpa has an index and the filter is
selective), **hash projection** (because we need distinct values on a few columns),
and optionally a **sort** (if the query had ORDER BY name). All three strategies
work together in one plan.

> **Key takeaway:** Relational algebra provides the logical operators; the
query-processing architecture attaches physical implementations. For large tables,
indexes replace scans for selective conditions, hashing accelerates projection and
deduplication, and sorting enables merge joins and ordered output — all chosen by the
optimizer to minimize cost.

## 10. Set Operations in Relational Algebra

The set-based operators treat relations as sets (rather than multi-row tables with
meaningful column relationships) and combine the tuples of two relations into a
result. The four set operations require their operands to be **union-compatible**:
the same number of attributes and compatible types in each position.

| Set operator | Symbol | Result |
|---|---|---|
| Set union | R ∪ S | Tuples in R, in S, or in both (duplicates removed) |
| Set intersection | R ∩ S | Tuples in both R and S |
| Set difference | R − S | Tuples in R but not in S |
| Cross product | R × S | All pairs (m × n rows) |

**Relational instances** (union-compatible — both have schema A, B):

`R(A, B)`:
```text
A   B
1   10
2   20
3   30
```

`S(A, B)`:
```text
A   B
2   20
4   40
5   50
```

### Set Union (R ∪ S)

All tuples in R, in S, or in both — duplicates removed.

```text
A   B
1   10
2   20
3   30
4   40
5   50
```

SQL: `SELECT * FROM R UNION SELECT * FROM S;`

### Set Difference (R − S)

Tuples in R that are **not** in S.

```text
A   B
1   10
3   30
```

SQL: `SELECT * FROM R EXCEPT SELECT * FROM S;` (PostgreSQL) or `MINUS` (Oracle)

### Set Intersection (R ∩ S)

Tuples in **both** R and S.

```text
A   B
2   20
```

SQL: `SELECT * FROM R INTERSECT SELECT * FROM S;`

Note: intersection can also be expressed using difference: `R ∩ S = R − (R − S)`.

**Arrow summary:**

```text
R(A,B)    S(A,B)
1,10     2,20        R ∪ S = 5 tuples (1,10; 2,20; 3,30; 4,40; 5,50)
2,20     4,40        R ∩ S = 1 tuple  (2,20)
3,30     5,50        R − S = 2 tuples (1,10; 3,30)
```

> **Key takeaway:** Set operators combine whole relations, not tuples within a
relation. They require union-compatible operands and treat results as sets
(duplicates removed).

## 11. Advanced Join Types

The natural join (⋈) is one member of a family of join operators. "Getting fancier"
means understanding all the variants — theta joins, equi-joins, outer joins,
semi-joins, and anti-joins.

### Theta Join (θ-join)

The most general form of join. A **theta join** pairs tuples from two relations
based on an arbitrary condition θ that can use any comparison operator
(`=`, `<`, `>`, `≤`, `≥`, `≠`) and reference attributes from either relation.

**Notation:** `R ⋈_θ S`

**Definition:** `R ⋈_θ S = σ_θ(R × S)` — a cross product followed by a selection on θ.

**Relational instances** (no shared attribute names):

`R(A, B)`:
```text
A   B
1   10
2   20
3   30
```

`S(C, D)`:
```text
C   D
10  50
20  60
30  70
```

**Theta join:** `R ⋈_{B < C} S` — pair tuples where R.B < S.C:

```text
A   B    C   D
1   10   20  60
1   10   30  70
2   20   30  70
```

(6 comparisons match out of 9 possible pairs; the 3 equal-value pairs where
B = C are excluded by the strict `<`.)

SQL: `SELECT * FROM R JOIN S ON R.B < S.C;`

### Equi-Join

An **equi-join** is a theta join where the condition θ is a conjunction of
equality comparisons (`=`).

**Notation:** `R ⋈_{R.a = S.b} S`

**Definition:** `R ⋈_{a=b} S = σ_{a=b}(R × S)`

Key distinction from natural join: in a general equi-join, the joined columns
**both appear** in the output. A natural join deduplicates them.

**Equi-join** `R ⋈_{B = C} S` (using the same R and S above):

```text
A   B    C   D
1   10   10  50
2   20   20  60
3   30   30  70
```

Note: **both** B and C columns appear in the result, even though they hold the
same values. SQL:
```sql
SELECT * FROM R JOIN S ON R.B = S.C;
```

### Natural Join (recall)

**Natural join** `R ⋈ S` is a special equi-join:
- The condition is implicit: equality on **all** attributes with the same name.
- The shared columns appear **once** in the output (deduplicated).

> The hierarchy is: theta-join ⊃ equi-join ⊃ natural join. A natural join is
an equi-join on all shared attribute names; an equi-join is a theta-join using
only `=`.

### Semi-Join (⋉)

A **semi-join** returns tuples from the **left** relation (R) that have at least
one matching tuple in the right relation (S), but **only projects R's
attributes** — the S columns are not included.

**Notation:** `R ⋉ S`

**Relational instances** (R and S share attribute B):

`R(A, B)`:
```text
A   B
1   10
2   20
3   30
```

`S(B, C)`:
```text
B    C
10   x
20   y
40   z
```

**Semi-join:** `R ⋉ S` — R tuples that have a match in S (on B), R columns only:

```text
A   B
1   10
2   20
```

Tuple (3, 30) is excluded because there is no S tuple with B = 30. SQL:
```sql
-- No direct semi-join syntax in standard SQL; use EXISTS or IN
SELECT A, B FROM R
WHERE EXISTS (SELECT 1 FROM S WHERE S.B = R.B);
```

### Anti-Join (▷)

An **anti-join** returns tuples from R that have **no** matching tuple in S.

**Notation:** `R ▷ S`  (equivalently: `R − (R ⋈ S)` or `R − π_R(R ⋈ S)`)

**Example** `R ▷ S` — R tuples with no match in S:

```text
A   B
3   30
```

SQL:
```sql
SELECT A, B FROM R
WHERE NOT EXISTS (SELECT 1 FROM S WHERE S.B = R.B);
```

### Outer Joins

Outer joins include **unmatched** tuples, padding missing attributes with NULL.

Using the same R(A, B) and S(B, C):

**Left outer join** `R ⟕ S` — all tuples from R; unmatched S columns are NULL:

```text
A   B    C
1   10   x
2   20   y
3   30   NULL
```

**Right outer join** `R ⟖ S` — all tuples from S; unmatched R columns are NULL:

```text
A     B    C
1     10   x
2     20   y
NULL  40   z
```

**Full outer join** `R ⟗ S` — all tuples from both R and S, NULLs for unmatched:

```text
A     B    C
1     10   x
2     20   y
3     30   NULL
NULL  40   z
```

SQL:
```sql
SELECT * FROM R LEFT OUTER JOIN S USING (B);   -- ⟕
SELECT * FROM R RIGHT OUTER JOIN S USING (B);  -- ⟖
SELECT * FROM R FULL OUTER JOIN S USING (B);   -- ⟗
```

**Arrow summary — the join family:**

```text
Theta-join (⋈_θ)  ⊃  Equi-join (⋈_{a=b})  ⊃  Natural join (⋈)
                     also includes  Semi-join (⋉), Anti-join (▷)
                                     Outer joins (⟕, ⟖, ⟗)
```

> **Key takeaway:** Joins exist on a spectrum from the general (theta: any
condition) to the specific (natural: equality on all shared names). Semi-joins and
anti-joins let you test for existence/non-existence. Outer joins preserve
unmatched tuples with NULL padding. The hierarchy is: theta-join ⊃ equi-join ⊃
natural join.

## 12. Division (÷) — The "For All" Operator

**Division** answers "for all" queries: "Find A-values that are paired with **every**
B-value." It is the relational algebra operator for **universal quantification**.

**Notation:** `R ÷ S`

**Setup:** R has attributes `A, B` (or more precisely, A-attributes plus B-attributes).
S has only B-attributes (a subset of R's attributes). The result contains A-tuples
such that, for **every** B-tuple in S, the combination of that A-tuple and B-tuple
appears in R.

**Formal definition:**

```
R ÷ S = { t_R[A] | for all t_S in S, the tuple (t_R[A], t_S[B]) is in R }
```

**Expressed using basic operators** (division is a derived operator):

```
R ÷ S = π_A(R) − π_A( (π_A(R) × S) − R )
```

Intuition:
1. `(π_A(R) × S)` — every A-combination cross-joined with every B-tuple in S.
2. Subtract R: what's left is the (A, B) pairs that are **missing** from R.
3. Project to A: the A-values that are missing some B-tuple.
4. Subtract from π_A(R): the A-values that have **no missing** B-tuple = all B-tuples.

### Division Example — Students Who Take All Subjects

`Enrollments(sid, subject)`:

```text
sid  subject
----  -------
1     DB
1     OS
1     Networks
2     DB
2     OS
3     DB
3     OS
3     Networks
```

`AllSubjects(subject)`:

```text
subject
-------
DB
OS
Networks
```

**Query:** Find students enrolled in **all** subjects.

Relational algebra:
```
Enrollments ÷ AllSubjects
```

Step-by-step:
1. A-values: {1, 2, 3} (distinct sids in Enrollments)
2. B-tuples in S: {DB, OS, Networks}
3. Student 1: has DB ✓, OS ✓, Networks ✓ → all present → **included**
4. Student 2: has DB ✓, OS ✓, Networks ✗ → **excluded**
5. Student 3: has DB ✓, OS ✓, Networks ✓ → **included**

Result:
```text
sid
1
3
```

**SQL equivalent** (no native ÷ operator — use double NOT EXISTS or GROUP BY):

```sql
-- Method 1: double NOT EXISTS
SELECT DISTINCT e1.sid
FROM Enrollments e1
WHERE NOT EXISTS (
    SELECT 1 FROM AllSubjects s
    WHERE NOT EXISTS (
        SELECT 1 FROM Enrollments e2
        WHERE e2.sid = e1.sid AND e2.subject = s.subject
    )
);

-- Method 2: GROUP BY with COUNT
SELECT sid
FROM Enrollments
GROUP BY sid
HAVING COUNT(DISTINCT subject) = (SELECT COUNT(*) FROM AllSubjects);
```

**Arrow summary:**

```text
Enrollments(sid, subject)  ÷  AllSubjects(subject)
  sid=1 → DB,OS,Networks     (all 3) ✓
  sid=2 → DB,OS              (missing Networks) ✗
  sid=3 → DB,OS,Networks     (all 3) ✓
Result: sid ∈ {1, 3}
```

> **Key takeaway:** Division (÷) answers "for all" queries. It is not a core
primitive — it can be expressed using projection, cross product, and difference —
but it is conceptually essential for universal quantification.

## 13. Unified Example: Students and Subjects

A running example that demonstrates every relational algebra operator. Three
tables:

`Students(sid, name, major)`:

```text
sid  name    major
---- ------- ------
1    Alice   CS
2    Bob     CS
3    Carol   Math
4    Dan     CS
```

`Enrollments(sid, subject, grade)`:

```text
sid  subject    grade
---- ---------- -----
1    DB         92
1    OS         88
1    Networks   90
2    DB         78
2    OS         85
3    DB         95
3    Networks   87
```

`Subjects(subject, credits)`:

```text
subject     credits
----------  -------
DB          3
OS          4
Networks    3
```

### Selection (σ)

`σ_grade > 90(Enrollments)` — find high-scoring enrollments:

```text
sid  subject    grade
---- ---------- -----
1    DB         92
3    DB         95
```

### Projection (π)

`π_name(σ_grade > 90(Enrollments ⋈ Students))` — names of students with grade > 90:

```text
name
------
Alice
Carol
```

### Cross product (×)

`Students × Subjects` — every student paired with every subject (4 × 3 = 12 rows).
Rarely useful directly; shown here only to illustrate the operator.

### Natural join (⋈)

`Enrollments ⋈ Students` — join on shared attribute `sid`:

```text
sid  name    major   subject    grade
---- ------- ------ ---------- -----
1    Alice   CS      DB         92
1    Alice   CS      OS         88
1    Alice   CS      Networks   90
2    Bob     CS      DB         78
2    Bob     CS      OS         85
3    Carol   Math    DB         95
3    Carol   Math    Networks   87
```

### Theta join (⋈_θ)

`Enrollments ⋈_{grade > 85} Students` — well, this is a selection not a join
condition. Let's use `Students ⋈_{major = 'CS'} Subjects` instead (a selection-based
theta join on a constant, which is unusual). A more meaningful theta join:

`π_sid,subject,credits(σ_grade > 85(Enrollments ⋈ Students))` — students with
grade > 85, showing their credits from Subjects:

First join Enrollments ⋈ Students on sid (as above), filter grade > 85, then join
with Subjects on subject:

```text
sid  name    subject    grade  credits
---- ------- ---------- -----  -------
1    Alice   DB         92     3
1    Alice   Networks   90     3
3    Carol   DB         95     3
```

### Equi-join (⋈_{a=b})

`Enrollments ⋈_{student_id = eid} Students` — if the attribute names differed,
both columns would appear:

```text
sid  subject    grade  sid  name    major
---- ---------- -----  ---- ------- ------
1    DB         92     1    Alice   CS
1    OS         88     1    Alice   CS
...
```

### Renaming (ρ)

`ρCS_Majors(sid, name, major)(σ_major = 'CS'(Students))` — rename result to
CS_Majors:

```text
sid  name    major
---- ------- ------
1    Alice   CS
2    Bob     CS
4    Dan     CS
```

### Semi-join (⋉)

`Students ⋉ π_sid(Enrollments)` — students who are enrolled in at least one subject:

```text
sid  name    major
---- ------- ------
1    Alice   CS
2    Bob     CS
3    Carol   Math
```

(Dan is excluded — no enrollment records.)

### Anti-join (▷)

`Students ▷ π_sid(Enrollments)` — students with NO enrollments:

```text
sid  name    major
---- ------- ------
4    Dan     CS
```

### Outer join (⟕)

`Students ⟕ Enrollments` — left outer join: all students, NULL for those not enrolled:

```text
sid  name    major   subject    grade
---- ------- ------ ---------- -----
1    Alice   CS      DB         92
1    Alice   CS      OS         88
1    Alice   CS      Networks   90
2    Bob     CS      DB         78
2    Bob     CS      OS         85
3    Carol   Math    DB         95
3    Carol   Math    Networks   87
4    Dan     CS      NULL       NULL
```

### Division (÷)

`Enrollments ÷ π_subject(Subjects)` — students taking ALL subjects:

```text
sid
1
```

(Only Alice is enrolled in DB, OS, and Networks. Carol is missing OS. Bob is
missing Networks.)

### Set operations (union, intersection, difference)

`CS_majors = σ_major = 'CS'(Students)` and `Math_majors = σ_major = 'Math'(Students)`:

**Union** `CS_majors ∪ Math_majors`:
```text
sid  name    major
---- ------- ------
1    Alice   CS
2    Bob     CS
3    Carol   Math
4    Dan     CS
```

**Intersection** `CS_majors ∩ Math_majors`:
```text
(empty — no student is in both majors)
```

**Difference** `CS_majors − Math_majors`:
```text
sid  name    major
---- ------- ------
1    Alice   CS
2    Bob     CS
4    Dan     CS
```

> **Key takeaway:** This single student/subject dataset demonstrates every
relational algebra operator — selection, projection, join (all types), renaming,
semi-join, anti-join, outer join, division, and set operations — showing how they
compose to express complex queries.

## 14. Limitations of Relational Algebra and Relational Completeness

Relational algebra is expressive, but it has well-known boundaries.

### What RA cannot express

1. **Transitive closure / recursion.** RA cannot express queries about paths of
   arbitrary length in a graph. Example: "find all employees who report (directly
   or indirectly) to manager M." This requires repeated self-joins — unbounded
   recursion — which core RA cannot express. Modern SQL adds `WITH RECURSIVE`.

2. **No aggregation in core RA.** The five core operators have no `SUM`, `COUNT`,
   `AVG`, `MIN`, or `MAX`. Aggregation is an extension ("extended relational
   algebra").

3. **No ordering.** RA relations are sets — unordered. `ORDER BY` is a post-
   processing step, not a core RA operator.

4. **No duplicate bags.** Core RA uses set semantics (no duplicate rows). SQL uses
   bags/multisets, which is a superset.

### Transitive closure example

Given an edge relation `Edges(from, to)` representing a directed graph:

```text
from  to
----  ----
1     2
2     3
3     4
```

The **transitive closure** is all pairs (a, b) where b is reachable from a.

```text
Reachable(from, to):
from  to
1     2   (direct edge)
1     3   (path: 1→2→3)
1     4   (path: 1→2→3→4)
2     3   (direct edge)
2     4   (path: 2→3→4)
3     4   (direct edge)
```

Core RA can express "reachable in exactly 1 step" (just Edges itself), "in exactly
2 steps" (Edges ⋈ Edges), and "in exactly k steps" for any fixed k — but **not**
"reachable in any number of steps." This requires recursion.

SQL's recursive CTE handles it:
```sql
WITH RECURSIVE Reach(a, b) AS (
    SELECT from, to FROM Edges
    UNION
    SELECT r.a, e.to
    FROM Reach r, Edges e
    WHERE r.b = e.from
)
SELECT * FROM Reach;
```

### Relational completeness

A query language is **relationally complete** if it can express every query that
relational algebra (and equivalently, relational tuple-domain relational calculus)
can express. Standard SQL (without `WITH RECURSIVE`) is relationally complete.

The key point: RA is relationally complete but **not Turing complete**. It sits at
a fixed level of expressive power — it can express all "relational" queries (joins,
selections, projections, set operations) but cannot express recursion, transitive
closure, or iterative fixpoint computations.

**Expressive power hierarchy:**

```text
Relational Algebra  =  Relational Calculus  =  Standard SQL (no recursion)
       <
SQL WITH RECURSIVE  (adds transitive closure / recursion)
       <
Full PL/polyglot programming  (Turing complete)
```

> **Key takeaway:** Relational algebra is relationally complete — it can express
exactly what standard SQL (minus recursion) can express. Its main limitation is that
it cannot compute transitive closure or any recursive query. This is by design: RA
gives us a clean, finite, mathematically tractable query language, at the cost of
not being able to express unbounded recursion directly.

## 15. Relational Algebra Cheat Sheet

| Concept | Notation | Description |
|---|---|---|
| Selection | `σ_condition(R)` | Filter rows by a predicate; keeps full schema |
| Projection | `π_attrs(R)` | Keep only listed columns; removes duplicates |
| Cross product | `R × S` | Pair every tuple with every tuple; m × n rows |
| Renaming | `ρ_name(attrs)(R)` | Rename relation/columns; no data change |
| Natural join | `R ⋈ S` | Join on all shared attribute names; dedup columns |
| Theta join | `R ⋈_θ S` | Join on any condition θ (=, <, >, ≠, …) |
| Equi-join | `R ⋈_{a=b} S` | Theta join using only equality (=); keeps both columns |
| Semi-join | `R ⋉ S` | Left rows with a match in right; left columns only |
| Anti-join | `R ▷ S` | Left rows with NO match in right |
| Left outer join | `R ⟕ S` | All R rows; NULL for unmatched S |
| Right outer join | `R ⟖ S` | All S rows; NULL for unmatched R |
| Full outer join | `R ⟗ S` | All rows from both; NULL for unmatched |
| Union | `R ∪ S` | Tuples in R or S (requires compatible schemas) |
| Difference | `R − S` | Tuples in R but not S (requires compatible schemas) |
| Intersection | `R ∩ S` | Tuples in both R and S |
| Assignment | `name ← expr` | Store a result for reuse |
| Division | `R ÷ S` | "For all" query: A-tuples paired with every B-tuple in S |

**Three rules to remember:**
1. Every operator returns a relation, so you can always compose them.
2. Set operators (∪, −, ∩) require union-compatible operands: the same number of
   attributes with compatible types.
3. Relational algebra is relationally complete (equivalent to relational calculus
   and standard SQL without recursion) but cannot express transitive closure or
   recursion — use `WITH RECURSIVE` for those.

> **Key takeaway:** Relational algebra is a small, compositional toolkit. Master the
five core operators plus the set-derived ones, and you can express any relational
query. Selection filters rows, projection narrows columns, joins and products
combine relations, and renaming improves readability — all while preserving the
closure property that makes composition possible.
